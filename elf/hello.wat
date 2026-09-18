;; elf/hello.wat — a wat program that emits a native x86-64 Linux executable.
;;
;; Not a wat program that CALLS a compiler. A wat program that computes the bytes of an ELF file,
;; writes them, and reads them back to check. The result runs on the kernel with no interpreter,
;; no runtime and no libc: 166 bytes, one `PT_LOAD`, two syscalls.
;;
;; ## Why this is possible at all
;;
;; wat has no byte literal. An integer literal is an `i64`, there is no `to-u8`, and
;; `(:wat::core::Vector :- [:wat::core::u8] 127)` is refused -- *"parameter #1 expects
;; :wat::core::u8; got :wat::core::i64"*. The only things in the language that produce a
;; `Vector<u8>` are `IOReader/read-all` (bytes that already exist in a file), `IOWriter/to-bytes`
;; (bytes already written), and **`:wat::core::Bytes::from-hex`**, which turns a String of hex
;; digits into bytes. That last one is the whole door: a wat program can compute a hex string --
;; which is ordinary string work -- and hand it to `from-hex` to become arbitrary binary,
;; including every byte above 0x7f that a String could never carry as UTF-8.
;;
;; So the shape of the program is: **assemble to hex, then decode once at the end.**
;;
;; ## What it actually does
;;
;; It is a two-pass assembler, for the reason every assembler is: the code contains the address
;; of the message, and the address depends on how long the code is. Pass one emits the text with
;; the address left at zero and measures it; pass two emits it again with the real address. The
;; program asserts the two passes are the same length, which is the invariant that makes the
;; technique sound.
;;
;; Then it lays out an ELF by hand:
;;
;;   0x00  ELF header, 64 bytes      -- ET_EXEC, EM_X86_64, entry = 0x400078
;;   0x40  program header, 56 bytes  -- one PT_LOAD, R+X, the whole file at 0x400000
;;   0x78  text, 31 bytes            -- write(1, msg, len); exit(0)
;;   0x97  the message
;;
;; Every offset, address and size above is COMPUTED from the lengths of the pieces, not written
;; down -- change the message and the file re-lays itself.
;;
;; ## What wat cannot do, and what that costs
;;
;; It cannot set the executable bit: `:wat::io::` has `open-file`, `read-file` and `list-dir`, and
;; no `chmod`. Nor can it run the result -- `:wat::kernel::spawn-process` forks a wat child that
;; evaluates a source string, not an arbitrary program. So the last two steps belong to the
;; shell, and `tools/elf-run.sh` does them. That is one `chmod +x` between "wat produced a native
;; binary" and "the binary ran", and it is the only part of this that is not wat.
;;
;; What the program CAN do is check its own work, and it does: it reads the file back and
;; compares it, byte for byte, with the hex it assembled.
;;
;; Run from the repository root:
;;   wat elf/hello.wat            # writes elf/out/hello.elf and verifies it
;;   tools/elf-run.sh             # chmod +x, run it, compare its output

;; ---------------------------------------------------------------- hex encoding

(:wat::core::defn :elf::nibble [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::subs "0123456789abcdef" n (:wat::core::+ n 1)))

(:wat::core::defn :elf::u8 [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:elf::nibble (:wat::core::/ n 16))
                        (:elf::nibble (:wat::core::rem n 16))))

;; little-endian, `width` bytes wide -- low byte first, which is every field in an x86-64 ELF
(:wat::core::defn :elf::le [n <- :wat::core::i64 width <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::= width 0) ""
    (:wat::string::concat (:elf::u8 (:wat::core::rem n 256))
                          (:elf::le (:wat::core::/ n 256) (:wat::core::- width 1)))))

;; ---------------------------------------------------------------- ASCII, without a char type
;;
;; wat has no character-to-integer verb, so the code of a character is its INDEX in the printable
;; range, which starts at 32. A scan over a 95-character table is the whole encoder; newline is
;; the one thing outside it that this program needs.

(:wat::core::defn :elf::printable [] -> :wat::core::String
  " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(:wat::core::defn :elf::scan [c <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::string::length (:elf::printable)))
      (:wat::kernel::assertion-failed! :message (:wat::string::concat "not encodable: " c)))
    ((:wat::core::= (:wat::string::subs (:elf::printable) i (:wat::core::+ i 1)) c)
      (:wat::core::+ i 32))
    (:else (:elf::scan c (:wat::core::+ i 1)))))

(:wat::core::defn :elf::code-of [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::if (:wat::core::= c "\n") 10 (:elf::scan c 0)))

(:wat::core::defn :elf::ascii [s <- :wat::core::String i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:elf::ascii s (:wat::core::+ i 1)
      (:wat::string::concat acc
        (:elf::u8 (:elf::code-of (:wat::string::subs s i (:wat::core::+ i 1))))))))

;; ---------------------------------------------------------------- the machine code
;;
;;   b8 01 00 00 00   mov eax, 1          ; __NR_write
;;   bf 01 00 00 00   mov edi, 1          ; fd 1, stdout
;;   be <msg>         mov esi, msg        ; the address this pass is being told
;;   ba <len>         mov edx, len
;;   0f 05            syscall
;;   b8 3c 00 00 00   mov eax, 60         ; __NR_exit
;;   31 ff            xor edi, edi        ; status 0
;;   0f 05            syscall
;;
;; Every immediate is four bytes whatever its value, which is why pass one can measure the text
;; with the address still unknown.

(:wat::core::defn :elf::text [msg-addr <- :wat::core::i64 msg-len <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:wat::string::concat "b8" (:elf::le 1 4))
    (:wat::string::concat "bf" (:elf::le 1 4))
    (:wat::string::concat "be" (:elf::le msg-addr 4))
    (:wat::string::concat "ba" (:elf::le msg-len 4))
    "0f05"
    (:wat::string::concat "b8" (:elf::le 60 4))
    "31ff"
    "0f05"))

;; ---------------------------------------------------------------- the ELF itself

(:wat::core::defn :elf::ehdr [entry <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    "7f454c46"          ;; magic
    "02"                ;; ELFCLASS64
    (:wat::string::concat
      "01"              ;; ELFDATA2LSB
      "01"              ;; EI_VERSION
      "00"              ;; ELFOSABI_SYSV
      (:elf::le 0 8))   ;; EI_ABIVERSION and padding
    (:wat::string::concat
      (:elf::le 2 2)    ;; e_type   = ET_EXEC
      (:elf::le 62 2)   ;; e_machine = EM_X86_64
      (:elf::le 1 4))   ;; e_version
    (:wat::string::concat
      (:elf::le entry 8)  ;; e_entry
      (:elf::le 64 8)     ;; e_phoff -- the program header follows this one
      (:elf::le 0 8))     ;; e_shoff -- no section headers at all
    (:wat::string::concat
      (:elf::le 0 4)      ;; e_flags
      (:elf::le 64 2)     ;; e_ehsize
      (:elf::le 56 2)     ;; e_phentsize
      (:elf::le 1 2))     ;; e_phnum
    (:wat::string::concat
      (:elf::le 0 2)      ;; e_shentsize
      (:elf::le 0 2)      ;; e_shnum
      (:elf::le 0 2))))   ;; e_shstrndx

;; one segment, mapped read+execute, covering the file from byte zero -- which is why the ELF
;; header and the program header are themselves inside the mapping
(:wat::core::defn :elf::phdr [vaddr <- :wat::core::i64 filesz <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:wat::string::concat (:elf::le 1 4) (:elf::le 5 4))     ;; PT_LOAD, PF_R | PF_X
    (:elf::le 0 8)                                            ;; p_offset
    (:wat::string::concat (:elf::le vaddr 8) (:elf::le vaddr 8))
    (:wat::string::concat (:elf::le filesz 8) (:elf::le filesz 8))
    (:elf::le 4096 8)))                                       ;; p_align

;; a second program, to show the code is being CHOSEN rather than pasted: exit with a status wat
;; computed. No message, so the tail is empty and the address argument is ignored.
;;
;;   b8 3c 00 00 00   mov eax, 60
;;   bf <status>      mov edi, status
;;   0f 05            syscall
(:wat::core::defn :elf::exit-text [tail-addr <- :wat::core::i64 status <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:wat::string::concat "b8" (:elf::le 60 4))
    (:wat::string::concat "bf" (:elf::le status 4))
    "0f05"))

;; ---------------------------------------------------------------- lay it out and write it

(:wat::core::defn :elf::base [] -> :wat::core::i64 4194304)   ;; 0x400000
(:wat::core::defn :elf::hdrs [] -> :wat::core::i64 120)       ;; 64 + 56, where the text begins
(:wat::core::defn :elf::path [] -> :wat::core::String "elf/out/hello.elf")

(:wat::core::defn :elf::write-bytes [path <- :wat::core::String hex <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::core::Bytes::from-hex hex)
    [:wat::core::Option.None {}
      (:wat::kernel::assertion-failed! :message "assembled hex did not decode")]
    [:wat::core::Option.Some {:value bs}
      (:wat::core::let [w (:wat::io::IOWriter/open-file path)]
        (:wat::core::do
          (:wat::io::IOWriter/write-all w bs)
          (:wat::io::IOWriter/flush w)
          (:wat::io::IOWriter/close w)
          (:wat::core::length bs)))]))

(:wat::core::defn :elf::read-hex [path <- :wat::core::String] -> :wat::core::String
  (:wat::core::Bytes::to-hex (:wat::io::IOReader/read-all (:wat::io::IOReader/open-file path))))

(:wat::core::defn :elf::report [path <- :wat::core::String written <- :wat::core::i64
                                text-len <- :wat::core::i64 tail-len <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:wat::kernel::println
      (:wat::string::concat "elf: " (:elf::pad path 20) " " (:elf::pad (int written) 4) " bytes"
        "   text " (:elf::pad (int text-len) 3)
        "   tail " (:elf::pad (int tail-len) 3)
        "   verified byte for byte"))))

(:wat::core::defn :elf::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:elf::pad (:wat::string::concat s " ") n)))

;; the whole emitter: given a way to build the text and a tail to put after it, work out every
;; address from the lengths, write the file, read it back and check it
(:wat::core::defn :elf::emit [path <- :wat::core::String
                              make-text <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::String]
                              arg <- :wat::core::i64
                              tail-hex <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let
    [tail-len (:wat::core::/ (:wat::string::length tail-hex) 2)
     ;; PASS ONE: the address is not known yet, and does not need to be
     probe (make-text 0 arg)
     text-len (:wat::core::/ (:wat::string::length probe) 2)
     entry (:wat::core::+ (:elf::base) (:elf::hdrs))
     tail-addr (:wat::core::+ entry text-len)
     filesz (:wat::core::+ (:wat::core::+ (:elf::hdrs) text-len) tail-len)
     ;; PASS TWO: now it is
     text (make-text tail-addr arg)
     blob (:wat::string::concat (:elf::ehdr entry) (:elf::phdr (:elf::base) filesz) text tail-hex)
     written (:elf::write-bytes path blob)
     back (:elf::read-hex path)]
    (:wat::core::do
      ;; the invariant that makes a two-pass assembler sound: the passes agree on size
      (:wat::test::assert-eq (:wat::string::length probe) (:wat::string::length text))
      ;; the layout is what the header claims it is
      (:wat::test::assert-eq (:wat::core::/ (:wat::string::length blob) 2) filesz)
      (:wat::test::assert-eq written filesz)
      ;; and the file on disk is the file that was assembled
      (:wat::test::assert-eq back blob)
      (:elf::report path written text-len tail-len))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [msg "hello from wat\n"
     msg-hex (:elf::ascii msg 0 "")]
    (:wat::core::do
      ;; a program that prints -- the tail is the message, and the text has to be told where it is
      (:elf::emit "elf/out/hello.elf"
        (:wat::core::fn [addr <- :wat::core::i64 len <- :wat::core::i64] -> :wat::core::String
          (:elf::text addr len))
        (:wat::string::length msg)
        msg-hex)
      ;; a program that only exits, with a status this program worked out. Same headers, same
      ;; layout arithmetic, different instructions -- which is the difference between emitting
      ;; code and copying a blob.
      (:elf::emit "elf/out/exit42.elf"
        (:wat::core::fn [addr <- :wat::core::i64 status <- :wat::core::i64] -> :wat::core::String
          (:elf::exit-text addr status))
        (:wat::core::* 6 7)
        "")
      (:wat::kernel::println "elf: ok"))))
