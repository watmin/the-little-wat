;; elf/compile.wat — a compiler from wat source to a native x86-64 Linux executable, in wat.
;;
;; `elf/hello.wat` emits a binary this file's author chose. This one is given a wat PROGRAM and
;; emits a binary for it: it reads the source with `:wat::core::read-string`, walks the AST it
;; gets back, and generates machine code for what it finds. Nothing is pasted -- every
;; instruction, every immediate, every jump distance and every address is computed from the
;; program being compiled.
;;
;; The whole front end is three verbs wat already has:
;;
;;   `:wat::core::read-string`    source text -> a `:wat::WatAST`
;;   `:wat::core::ast-kind`       "list", "symbol", "int", "string", "vector", "keyword"
;;   `:wat::core::ast->children`  a node's children
;;   `:wat::core::ast->source`    a node's text, which is the literal for ints and the name for
;;                                symbols, so `ast-name` is never needed
;;
;; That wat can take its own source apart is the reason this is a compiler and not a code
;; generator with a hard-coded program.
;;
;; ## The language it accepts
;;
;;   (wat.core/defn user/main [] :- wat.type/nil  BODY...)
;;   (wat.kernel/println EXPR)        EXPR compiled to rax, then `call print_i64`
;;   (wat.kernel/println "literal")   written directly, with the string in the data tail
;;   (wat.core/+ a b ...)             n-ary, folded left
;;   (wat.core/- a b ...)
;;   (wat.core/* a b ...)
;;   integer literals, negative ones included, nested to any depth
;;
;; Both spellings of every name are accepted -- `wat.core/+` and `:wat::core::+` -- because the
;; reader keeps whichever the source used and this repository writes one while the migration
;; targets the other.
;;
;; Anything else is a COMPILE ERROR that names the form it could not translate, which is the
;; least a compiler owes its caller.
;;
;; ## The code it generates
;;
;; A stack discipline, which is the obvious thing and also the only thing available without a
;; register allocator: every expression leaves its value in `rax`, and a binary operator
;; evaluates its left side, pushes it, evaluates its right side, and pops.
;;
;;   48 b8 <imm64>   mov rax, literal
;;   50              push rax
;;   48 89 c1        mov rcx, rax
;;   58              pop rax
;;   48 01 c8        add rax, rcx
;;   48 29 c8        sub rax, rcx
;;   48 0f af c1     imul rax, rcx
;;   e8 <rel32>      call print_i64        -- a real relocation, computed in pass two
;;
;; ## Two passes, for the reason every assembler has two
;;
;; A `call` needs the distance to `print_i64`, which sits after the code, so its address is not
;; known until the code has been generated. Pass one compiles with the runtime at address zero
;; purely to measure; pass two compiles again with the real address. Every immediate is
;; fixed-width, so the two passes are the same length -- and the program ASSERTS that, because it
;; is the invariant the technique rests on.
;;
;; ## The runtime
;;
;; `print_i64` is 105 bytes of hand-assembled x86-64 embedded below: sign handling, a divide-by-
;; ten loop building digits backwards on the stack, and one `write` syscall. It is the only part
;; of the output not computed from the source, and it is the part a C toolchain would call libc
;; for. Its correctness was checked against four values (a negative, a small one, zero, and
;; i64::MAX) before it was embedded.
;;
;; Run from the repository root:
;;   wat elf/compile.wat        # compiles elf/src/*.wat to elf/out/*.elf and verifies each
;;   tools/elf-run.sh           # chmod +x, run them, compare their output

(:wat::load-file! "lib/asm.wat")

;; ---------------------------------------------------------------- the runtime
;;
;;   push rbp / mov rbp,rsp / sub rsp,32        a 32-byte digit buffer on the stack
;;   lea rsi,[rbp-1] / mov byte [rsi],10        newline goes in last
;;   test rax,rax / jns / neg rax / mov r8,1    remember and remove the sign
;;   mov rcx,10 / xor rdx,rdx / div rcx         digits, least significant first
;;   add dl,'0' / mov [rsi],dl / dec rsi        written backwards into the buffer
;;   test rax,rax / jnz                         until the value is used up
;;   cmp r8,0 / je / mov byte [rsi],'-'         put the sign back
;;   lea rdx,[rbp-1] / sub rdx,rsi / inc rdx    length = end - start + 1
;;   mov rax,1 / mov rdi,1 / syscall            write(1, rsi, rdx)
;;   leave / ret
(:wat::core::defn :c::runtime [] -> :wat::core::String
  (:wat::string::concat
    "554889e54883ec20488d75ffc6060a48ffce4d31c04885c0790a48f7d8"
    "49c7c00100000048c7c10a0000004831d248f7f180c230881648ffce48"
    "85c075ed4983f8007406c6062d48ffce48ffc6488d55ff4829f248ffc2"
    "48c7c00100000048c7c7010000000f05c9c3"))

;; ---------------------------------------------------------------- instructions

(:wat::core::defn :c::mov-rax [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "48b8" (:asm::le n 8)))
(:wat::core::defn :c::mov-rdi [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "48bf" (:asm::le n 8)))
(:wat::core::defn :c::mov-rsi [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "48be" (:asm::le n 8)))
(:wat::core::defn :c::mov-rdx [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "48ba" (:asm::le n 8)))
(:wat::core::defn :c::op-hex [op <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "+") "4801c8")
    ((:wat::core::= op "-") "4829c8")
    (:else "480fafc1")))

;; ---------------------------------------------------------------- the output being built

(:wat::core::defrecord :c::Out [code <- :wat::core::String  tail <- :wat::core::String])

(:wat::core::defn :c::emit [o <- :c::Out hex <- :wat::core::String] -> :c::Out
  (:wat::core::assoc o :code (:wat::string::concat (:c::Out/code o) hex)))

;; the virtual address of the next instruction, which is what a relocation needs
(:wat::core::defn :c::here [o <- :c::Out] -> :wat::core::i64
  (:wat::core::+ (:asm::entry) (:wat::core::/ (:wat::string::length (:c::Out/code o)) 2)))

(:wat::core::defn :c::call [o <- :c::Out target <- :wat::core::i64] -> :c::Out
  (:c::emit o (:wat::string::concat "e8"
    (:asm::le (:wat::core::- target (:wat::core::+ (:c::here o) 5)) 4))))

;; ---------------------------------------------------------------- names, in both spellings

(:wat::core::defn :c::is? [src <- :wat::core::String clj <- :wat::core::String kw <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= src clj) (:wat::core::= src kw)))

(:wat::core::defn :c::arith-op [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:c::is? src "wat.core/+" ":wat::core::+") "+")
    ((:c::is? src "wat.core/-" ":wat::core::-") "-")
    ((:c::is? src "wat.core/*" ":wat::core::*") "*")
    (:else "")))

(:wat::core::defn :c::println? [src <- :wat::core::String] -> :wat::core::bool
  (:c::is? src "wat.kernel/println" ":wat::kernel::println"))

(:wat::core::defn :c::fail [what <- :wat::core::String a <- :wat::WatAST] -> :c::Out
  (:wat::kernel::assertion-failed!
    :message (:wat::string::concat "compile: cannot compile " what ": " (:wat::core::ast->source a))))

;; ---------------------------------------------------------------- expressions

(:wat::core::defn :c::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {}
      (:wat::kernel::assertion-failed! :message (:wat::string::concat "compile: not an integer: " s))]))

(:wat::core::typealias :c::Kids (:wat::core::Vector :- [:wat::WatAST]))

(:wat::core::defn :c::expr [a <- :wat::WatAST o <- :c::Out rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let [k (:wat::core::str (:wat::core::ast-kind a))]
    (:wat::core::cond
      ((:wat::core::= k "int") (:c::emit o (:c::mov-rax (:c::to-int (:wat::core::ast->source a)))))
      ((:wat::core::= k "list") (:c::arith a o rt tb))
      (:else (:c::fail "expression" a)))))

;; left fold: the first argument lands in rax, and each one after it is pushed, computed and
;; popped back -- the stack discipline a compiler without a register allocator has to use
(:wat::core::defn :c::fold [op <- :wat::core::String ks <- :c::Kids i <- :wat::core::i64
                            o <- :c::Out rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:wat::core::let
      [o1 (:c::emit o "50")                                   ;; push rax
       o2 (:c::expr (:wat::core::nth ks i) o1 rt tb)
       o3 (:c::emit o2 "4889c1")                              ;; mov rcx, rax
       o4 (:c::emit o3 "58")                                  ;; pop rax
       o5 (:c::emit o4 (:c::op-hex op))]
      (:c::fold op ks (:wat::core::+ i 1) o5 rt tb))))

(:wat::core::defn :c::arith [a <- :wat::WatAST o <- :c::Out rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let [ks (:wat::core::ast->children a)
                    head (:wat::core::ast->source (:wat::core::nth ks 0))
                    op (:c::arith-op head)]
    (:wat::core::if (:wat::core::= op "") (:c::fail "call" a)
      (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) (:c::fail "call with no arguments" a)
        (:c::fold op ks 2 (:c::expr (:wat::core::nth ks 1) o rt tb) rt tb)))))

;; ---------------------------------------------------------------- statements

;; `:wat::kernel::println` renders a String as EDN -- `(println "a\nb")` writes `"a\nb"` and a
;; newline, quotes kept and the escape NOT expanded -- so the faithful compilation of a string
;; literal is its SOURCE TEXT, verbatim. The first version of this function stripped the quotes
;; and unescaped, and the differential test against the interpreter caught it on the first run.
(:wat::core::defn :c::print-string [a <- :wat::WatAST o <- :c::Out tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let
    [text (:wat::string::concat (:wat::core::ast->source a) "\n")
     addr (:wat::core::+ tb (:wat::core::/ (:wat::string::length (:c::Out/tail o)) 2))
     o1 (:wat::core::assoc o :tail (:wat::string::concat (:c::Out/tail o) (:asm::ascii text 0 "")))]
    (:c::emit (:c::emit (:c::emit (:c::emit o1 (:c::mov-rax 1)) (:c::mov-rdi 1))
                (:wat::string::concat (:c::mov-rsi addr) (:c::mov-rdx (:wat::string::length text))))
      "0f05")))

(:wat::core::defn :c::stmt [a <- :wat::WatAST o <- :c::Out rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not (:wat::core::= (:wat::core::str (:wat::core::ast-kind a)) "list"))
    (:c::fail "statement" a)
    (:wat::core::let [ks (:wat::core::ast->children a)
                      head (:wat::core::ast->source (:wat::core::nth ks 0))]
      (:wat::core::if (:wat::core::not (:c::println? head)) (:c::fail "statement" a)
        (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "println arity" a)
          (:wat::core::let [arg (:wat::core::nth ks 1)]
            (:wat::core::if (:wat::core::= (:wat::core::str (:wat::core::ast-kind arg)) "string")
              (:c::print-string arg o tb)
              (:c::call (:c::expr arg o rt tb) rt))))))))

;; the body of `main` is every child of the `defn` from the first list onwards, which skips the
;; name, the parameter vector and the return type without caring which spelling they were in
(:wat::core::defn :c::body-start [ks <- :c::Kids i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length ks)) i)
    ((:wat::core::= (:wat::core::str (:wat::core::ast-kind (:wat::core::nth ks i))) "list") i)
    (:else (:c::body-start ks (:wat::core::+ i 1)))))

(:wat::core::defn :c::body [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out
                            rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::body ks (:wat::core::+ i 1) (:c::stmt (:wat::core::nth ks i) o rt tb) rt tb)))

;; ---------------------------------------------------------------- driver

(:wat::core::defn :c::forms-of [src <- :wat::core::String] -> :wat::WatAST
  (:wat::core::match (:wat::core::read-string src)
    [:wat::core::ReadOutcome.Forms {:forms fs} fs]
    [:wat::core::ReadOutcome.Malformed {:cause e}
      (:wat::kernel::assertion-failed!
        :message (:wat::string::concat "compile: unreadable source: " (:wat::core::Error/message e)))]))

(:wat::core::defn :c::exit0 [] -> :wat::core::String
  (:wat::string::concat (:c::mov-rax 60) "31ff" "0f05"))

(:wat::core::defn :c::pass [ks <- :c::Kids start <- :wat::core::i64
                            rt <- :wat::core::i64 tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let [o (:c::body ks start (:c::Out :code "" :tail "") rt tb)]
    (:c::emit o (:c::exit0))))

(:wat::core::defn :c::compile [src-path <- :wat::core::String out-path <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let
    [top (:wat::core::nth (:wat::core::ast->children (:c::forms-of (:wat::io::read-file src-path))) 0)
     ks (:wat::core::ast->children top)
     start (:c::body-start ks 1)

     ;; PASS ONE: the runtime and the data have no addresses yet, and do not need any
     probe (:c::pass ks start 0 0)
     code-len (:wat::core::/ (:wat::string::length (:c::Out/code probe)) 2)
     rt-addr (:wat::core::+ (:asm::entry) code-len)
     tail-base (:wat::core::+ rt-addr (:wat::core::/ (:wat::string::length (:c::runtime)) 2))

     ;; PASS TWO: now they do
     final (:c::pass ks start rt-addr tail-base)
     text (:wat::string::concat (:c::Out/code final) (:c::runtime))
     written (:asm::link out-path text (:c::Out/tail final))
     int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:wat::core::do
      ;; the invariant the two-pass technique rests on
      (:wat::test::assert-eq (:wat::string::length (:c::Out/code probe))
                             (:wat::string::length (:c::Out/code final)))
      (:wat::test::assert-eq (:wat::string::length (:c::Out/tail probe))
                             (:wat::string::length (:c::Out/tail final)))
      (:wat::kernel::println
        (:wat::string::concat "compile: " (:asm::pad src-path 18) " -> " (:asm::pad out-path 22)
          (:asm::pad (int written) 5) " bytes   code " (:asm::pad (int code-len) 4)
          "  data " (:asm::pad (int (:wat::core::/ (:wat::string::length (:c::Out/tail final)) 2)) 4)
          "  verified")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c::compile "elf/src/four.wat"  "elf/out/four.elf")
    (:c::compile "elf/src/arith.wat" "elf/out/arith.elf")
    (:c::compile "elf/src/greet.wat" "elf/out/greet.elf")
    (:wat::kernel::println "compile: ok")))
