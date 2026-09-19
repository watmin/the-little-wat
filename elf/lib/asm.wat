;; elf/lib/asm.wat — the bytes-and-ELF layer that elf/hello.wat and elf/compile.wat share.
;;
;; Everything here is a String of hex digits, because F-118 says that is the only way a wat
;; program can author a byte: an integer literal is an `i64`, there is no `to-u8`, and the one
;; verb that can invent a byte is `:wat::core::Bytes::from-hex`. So the whole toolchain assembles
;; to hex and decodes once, at the moment of writing the file.

;; ---------------------------------------------------------------- hex

(:wat::core::defn :asm::nibble [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::subs "0123456789abcdef" n (:wat::core::+ n 1)))

(:wat::core::defn :asm::u8 [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:asm::nibble (:wat::core::/ n 16))
                        (:asm::nibble (:wat::core::rem n 16))))

(:wat::core::defn :asm::le-pos [n <- :wat::core::i64 width <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= width 0) acc
    (:asm::le-pos (:wat::core::/ n 256) (:wat::core::- width 1)
      (:wat::string::concat acc (:asm::u8 (:wat::core::rem n 256))))))

;; two's complement, stepped with FLOOR division rather than by complementing a magnitude.
;;
;; The obvious route -- negate, complement each byte, carry -- needs the magnitude, and **the
;; magnitude of the most negative i64 does not exist**: `(- 0 -9223372036854775808)` has no
;; answer. That was a trap waiting for the first program to write the literal, and it waited
;; from C-116 until one did; the compiler's own read-back check is what caught it, comparing the
;; bytes it wrote against the bytes on disk.
;;
;; So the bytes come out of the number directly. wat's `rem` takes the sign of its dividend, so
;; a negative byte is brought into range by adding 256 and borrowing one from the next step --
;; which is floor division, spelled out, because `/` truncates toward zero. Nothing here ever
;; holds a value the range cannot represent.
(:wat::core::defn :asm::le-neg [n <- :wat::core::i64 width <- :wat::core::i64
                                acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= width 0) acc
    (:wat::core::let [r (:wat::core::rem n 256)
                      b (:wat::core::if (:wat::core::< r 0) (:wat::core::+ r 256) r)
                      q (:wat::core::if (:wat::core::< r 0)
                          (:wat::core::- (:wat::core::/ n 256) 1)
                          (:wat::core::/ n 256))]
      (:asm::le-neg q (:wat::core::- width 1)
        (:wat::string::concat acc (:asm::u8 b))))))

;; little-endian, `width` bytes, signed
(:wat::core::defn :asm::le [n <- :wat::core::i64 width <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= n 0) (:asm::le-pos n width "")
    (:asm::le-neg n width "")))

;; ---------------------------------------------------------------- ASCII, without a char type
;;
;; wat has no character-to-integer verb, so a character's code is its INDEX in the printable
;; range, which starts at 32 (F-062 wearing a different hat). Nothing unescapes: a string literal
;; is compiled as its SOURCE TEXT, because that is what `println` renders (see elf/compile.wat).

(:wat::core::defn :asm::printable [] -> :wat::core::String
  " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(:wat::core::defn :asm::scan [c <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::string::length (:asm::printable)))
      (:wat::kernel::assertion-failed! :message (:wat::string::concat "not encodable: " c)))
    ((:wat::core::= (:wat::string::subs (:asm::printable) i (:wat::core::+ i 1)) c)
      (:wat::core::+ i 32))
    (:else (:asm::scan c (:wat::core::+ i 1)))))

(:wat::core::defn :asm::code-of [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= c "\n") 10)
    ((:wat::core::= c "\t") 9)
    ((:wat::core::= c "\r") 13)
    (:else (:asm::scan c 0))))

(:wat::core::defn :asm::ascii [s <- :wat::core::String i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:asm::ascii s (:wat::core::+ i 1)
      (:wat::string::concat acc
        (:asm::u8 (:asm::code-of (:wat::string::subs s i (:wat::core::+ i 1))))))))

;; ---------------------------------------------------------------- the ELF container

(:wat::core::defn :asm::base [] -> :wat::core::i64 4194304)   ;; 0x400000
(:wat::core::defn :asm::hdrs [] -> :wat::core::i64 120)       ;; 64 + 56, where the text begins
(:wat::core::defn :asm::entry [] -> :wat::core::i64
  (:wat::core::+ (:asm::base) (:asm::hdrs)))

(:wat::core::defn :asm::ehdr [entry <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    "7f454c46" "02"
    (:wat::string::concat "01" "01" "00" (:asm::le 0 8))
    (:wat::string::concat (:asm::le 2 2) (:asm::le 62 2) (:asm::le 1 4))
    (:wat::string::concat (:asm::le entry 8) (:asm::le 64 8) (:asm::le 0 8))
    (:wat::string::concat (:asm::le 0 4) (:asm::le 64 2) (:asm::le 56 2) (:asm::le 1 2))
    (:wat::string::concat (:asm::le 0 2) (:asm::le 0 2) (:asm::le 0 2))))

(:wat::core::defn :asm::phdr [vaddr <- :wat::core::i64 filesz <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:wat::string::concat (:asm::le 1 4) (:asm::le 5 4))
    (:asm::le 0 8)
    (:wat::string::concat (:asm::le vaddr 8) (:asm::le vaddr 8))
    (:wat::string::concat (:asm::le filesz 8) (:asm::le filesz 8))
    (:asm::le 4096 8)))

;; ---------------------------------------------------------------- writing and checking

;; the two verbs that reach the disk. Their definitions live in elf/lib/prim.wat for the
;; interpreter; elf/compile.wat implements them natively for a compiled program. Same meaning,
;; two implementations -- F-119's contract, in the only two places elf/ needs it.
(:wat::core::defn :asm::write-bytes [path <- :wat::core::String hex <- :wat::core::String] -> :wat::core::i64
  (:prim::write-hex path hex))

(:wat::core::defn :asm::read-hex [path <- :wat::core::String] -> :wat::core::String
  (:prim::read-hex path))

;; wrap a finished text section in headers, write it, and read it back to check
(:wat::core::defn :asm::link [path <- :wat::core::String text <- :wat::core::String tail <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let
    [filesz (:wat::core::+ (:asm::hdrs)
              (:wat::core::/ (:wat::core::+ (:wat::string::length text) (:wat::string::length tail)) 2))
     blob (:wat::string::concat (:asm::ehdr (:asm::entry)) (:asm::phdr (:asm::base) filesz) text tail)
     written (:asm::write-bytes path blob)]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::/ (:wat::string::length blob) 2) filesz)
      (:wat::test::assert-eq written filesz)
      (:wat::test::assert-eq (:asm::read-hex path) blob)
      written)))

(:wat::core::defn :asm::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:asm::pad (:wat::string::concat s " ") n)))
