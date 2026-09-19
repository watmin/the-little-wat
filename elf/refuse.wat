;; elf/refuse.wat — the compiler's NEGATIVE test: the same compiler, pointed at a program it
;; cannot translate. It must die naming the form. `tools/elf-run.sh` checks the message; this
;; file is not part of `./run.sh`, because a program that is supposed to fail cannot pass.
;;
;; (Everything below is elf/compile.wat with a different driver.)
;;
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
;;   (wat.core/defn user/NAME [p :- wat.type/i64 ...] :- T  BODY...)
;;   (wat.core/if COND THEN ELSE)          a real forward branch, patched
;;   (wat.core/let [a E b E] BODY...)      slots in the frame, innermost shadowing outward
;;   (user/NAME args...)                   a call, arguments on the stack, recursion included
;;   (wat.kernel/println EXPR)             EXPR to rax, then `call print_i64`
;;   (wat.kernel/println "literal")        written directly, the string in the data tail
;;   (wat.core/+ - *)                      n-ary, folded left
;;   (wat.core/< > <= >= = not=)           cmp + setcc + movzx, so a bool is 0 or 1 in rax
;;   integer literals, negatives included, nested to any depth
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
;; ## Two passes, over the whole program
;;
;; A call needs the callee's address, and a callee's address depends on the length of everything
;; placed before it -- so one function cannot be compiled without knowing about all of them. Pass
;; one compiles every function with every address zero, purely to measure; the addresses then
;; follow from the lengths; pass two compiles again with the real table. Every immediate and
;; every displacement is fixed width, so the passes are the same length, and the compiler ASSERTS
;; that function by function.
;;
;; Forward branches inside a function are not predicted, they are PATCHED: `if` emits its `jz`
;; with a zero operand, compiles the branch, and overwrites the operand once it knows how far it
;; went. That is F-104 again -- no positional update -- on a String, so the patch is a `subs`
;; either side of the hole. Crafting Interpreters chapter 23 (C-106) is the same problem on a
;; Vector.
;;
;; ## The calling convention
;;
;; Arguments are pushed left to right and popped by the caller. Inside the callee, rbp points at
;; the saved rbp, so argument i of n is at [rbp + 16 + 8*(n-1-i)] and `let` slots are below at
;; [rbp - 8*(slot+1)]. The frame size is worked out before the body is compiled, by walking it
;; for the deepest simultaneous `let` demand.
;;
;; The entry point is a 19-byte stub -- `call user/main`, then exit(0) -- which is the only code
;; in the output not compiled from a `defn`.
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
;; mov [rbp+disp32], rax   and   mov rax, [rbp+disp32]
(:wat::core::defn :c::store [d <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "488985" (:asm::le d 4)))
(:wat::core::defn :c::load [d <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "488b85" (:asm::le d 4)))
(:wat::core::defn :c::sub-rsp [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "4881ec" (:asm::le n 4)))
(:wat::core::defn :c::add-rsp [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "4881c4" (:asm::le n 4)))

(:wat::core::defn :c::op-hex [op <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "+") "4801c8")       ;; add rax, rcx
    ((:wat::core::= op "-") "4829c8")       ;; sub rax, rcx
    ((:wat::core::= op "*") "480fafc1")     ;; imul rax, rcx
    ;; a comparison is cmp + setcc + movzx, so a bool is an ordinary 0 or 1 in rax
    (:else (:wat::string::concat "4839c8" (:c::setcc op) "480fb6c0"))))

(:wat::core::defn :c::setcc [op <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "<") "0f9cc0")
    ((:wat::core::= op ">") "0f9fc0")
    ((:wat::core::= op "<=") "0f9ec0")
    ((:wat::core::= op ">=") "0f9dc0")
    ((:wat::core::= op "=") "0f94c0")
    (:else "0f95c0")))

;; ---------------------------------------------------------------- the output being built

(:wat::core::defrecord :c::Out
  [base <- :wat::core::i64  code <- :wat::core::String  tail <- :wat::core::String])

(:wat::core::defn :c::emit [o <- :c::Out hex <- :wat::core::String] -> :c::Out
  (:wat::core::assoc o :code (:wat::string::concat (:c::Out/code o) hex)))

(:wat::core::defn :c::codelen [o <- :c::Out] -> :wat::core::i64
  (:wat::core::/ (:wat::string::length (:c::Out/code o)) 2))

;; the virtual address of the next instruction, which is what a relocation needs
(:wat::core::defn :c::here [o <- :c::Out] -> :wat::core::i64
  (:wat::core::+ (:c::Out/base o) (:c::codelen o)))

(:wat::core::defn :c::call [o <- :c::Out target <- :wat::core::i64] -> :c::Out
  (:c::emit o (:wat::string::concat "e8"
    (:asm::le (:wat::core::- target (:wat::core::+ (:c::here o) 5)) 4))))

;; **A jump is patched, not predicted.** A forward branch's distance is not known until the code
;; it jumps over exists, so the operand is emitted as four zero bytes and overwritten afterwards.
;; That is F-104 again -- no positional update -- on a String this time, so the patch is a `subs`
;; either side of the hole. Crafting Interpreters chapter 23 (C-106) is the same problem, and
;; there it was a Vector.
(:wat::core::defn :c::patch [o <- :c::Out off <- :wat::core::i64 hex <- :wat::core::String] -> :c::Out
  (:wat::core::let [code (:c::Out/code o)
                    at (:wat::core::* off 2)]
    (:wat::core::assoc o :code
      (:wat::string::concat
        (:wat::string::subs code 0 at)
        hex
        (:wat::string::subs code (:wat::core::+ at (:wat::string::length hex)) (:wat::string::length code))))))

;; ---------------------------------------------------------------- names, in both spellings

(:wat::core::defn :c::is? [src <- :wat::core::String clj <- :wat::core::String kw <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= src clj) (:wat::core::= src kw)))

(:wat::core::defn :c::binop [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:c::is? src "wat.core/+" ":wat::core::+") "+")
    ((:c::is? src "wat.core/-" ":wat::core::-") "-")
    ((:c::is? src "wat.core/*" ":wat::core::*") "*")
    ((:c::is? src "wat.core/<" ":wat::core::<") "<")
    ((:c::is? src "wat.core/>" ":wat::core::>") ">")
    ((:c::is? src "wat.core/<=" ":wat::core::<=") "<=")
    ((:c::is? src "wat.core/>=" ":wat::core::>=") ">=")
    ((:c::is? src "wat.core/=" ":wat::core::=") "=")
    ((:c::is? src "wat.core/not=" ":wat::core::not=") "not=")
    (:else "")))

(:wat::core::defn :c::println? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.kernel/println" ":wat::kernel::println"))
(:wat::core::defn :c::if? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/if" ":wat::core::if"))
(:wat::core::defn :c::let? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/let" ":wat::core::let"))
(:wat::core::defn :c::defn? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/defn" ":wat::core::defn"))

(:wat::core::defn :c::fail [what <- :wat::core::String a <- :wat::WatAST] -> :c::Out
  (:wat::kernel::assertion-failed!
    :message (:wat::string::concat "compile: cannot compile " what ": " (:wat::core::ast->source a))))

(:wat::core::defn :c::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {}
      (:wat::kernel::assertion-failed! :message (:wat::string::concat "compile: not an integer: " s))]))

(:wat::core::defn :c::kind [a <- :wat::WatAST] -> :wat::core::String
  (:wat::core::str (:wat::core::ast-kind a)))

;; ---------------------------------------------------------------- scopes and functions

(:wat::core::typealias :c::Kids (:wat::core::Vector :- [:wat::WatAST]))

;; a name and where it lives, as a displacement from rbp: parameters above it, locals below
(:wat::core::defrecord :c::Bind [name <- :wat::core::String  disp <- :wat::core::i64])
(:wat::core::typealias :c::Env (:wat::core::Vector :- [:c::Bind]))

;; innermost first, so a `let` shadows a parameter of the same name
(:wat::core::defn :c::lookup [env <- :c::Env name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::< i 0) 999999)
    ((:wat::core::= (:c::Bind/name (:wat::core::nth env i)) name) (:c::Bind/disp (:wat::core::nth env i)))
    (:else (:c::lookup env name (:wat::core::- i 1)))))

(:wat::core::defrecord :c::Fn
  [name <- :wat::core::String  node <- :wat::WatAST  addr <- :wat::core::i64])
(:wat::core::typealias :c::Fns (:wat::core::Vector :- [:c::Fn]))

(:wat::core::defn :c::fn-addr [fns <- :c::Fns name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length fns)) -1)
    ((:wat::core::= (:c::Fn/name (:wat::core::nth fns i)) name) (:c::Fn/addr (:wat::core::nth fns i)))
    (:else (:c::fn-addr fns name (:wat::core::+ i 1)))))

;; the body of a `defn` is every child from the first list onwards, which skips the name, the
;; parameter vector and the return type without caring which spelling they were in
(:wat::core::defn :c::body-start [ks <- :c::Kids i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length ks)) i)
    ((:wat::core::= (:c::kind (:wat::core::nth ks i)) "list") i)
    (:else (:c::body-start ks (:wat::core::+ i 1)))))

;; ---------------------------------------------------------------- frame size
;;
;; A `let` needs a slot per binding, and the prologue has to reserve them before the body is
;; compiled -- so the compiler walks the body first and takes the deepest simultaneous demand.
;; Slots are never reused between sibling `let`s, which costs stack and buys simplicity.

(:wat::core::defn :c::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

(:wat::core::defn :c::slots-of [a <- :wat::WatAST] -> :wat::core::i64
  (:wat::core::if (:wat::core::not (:wat::core::= (:c::kind a) "list")) 0
    (:wat::core::let [ks (:wat::core::ast->children a)]
      (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) 0
        (:wat::core::if (:c::let? (:wat::core::ast->source (:wat::core::nth ks 0)))
          (:wat::core::+ (:wat::core::/ (:wat::core::length (:wat::core::ast->children (:wat::core::nth ks 1))) 2)
            (:c::imax (:c::slots-list (:wat::core::ast->children (:wat::core::nth ks 1)) 0 0)
                      (:c::slots-list ks 2 0)))
          (:c::slots-list ks 0 0))))))

(:wat::core::defn :c::slots-list [ks <- :c::Kids i <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:c::slots-list ks (:wat::core::+ i 1) (:c::imax best (:c::slots-of (:wat::core::nth ks i))))))

(:wat::core::defn :c::slots-body [ks <- :c::Kids i <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:c::slots-list ks i best))

;; ---------------------------------------------------------------- expressions

(:wat::core::defn :c::expr [a <- :wat::WatAST o <- :c::Out env <- :c::Env fns <- :c::Fns
                            rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::let [k (:c::kind a)]
    (:wat::core::cond
      ((:wat::core::= k "int") (:c::emit o (:c::mov-rax (:c::to-int (:wat::core::ast->source a)))))
      ((:wat::core::= k "symbol")
        (:wat::core::let [d (:c::lookup env (:wat::core::ast->source a) (:wat::core::- (:wat::core::length env) 1))]
          (:wat::core::if (:wat::core::= d 999999) (:c::fail "name" a) (:c::emit o (:c::load d)))))
      ((:wat::core::= k "list") (:c::form a o env fns rt tb slot))
      (:else (:c::fail "expression" a)))))

(:wat::core::defn :c::form [a <- :wat::WatAST o <- :c::Out env <- :c::Env fns <- :c::Fns
                            rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::let [ks (:wat::core::ast->children a)]
    (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) (:c::fail "empty form" a)
      (:wat::core::let [head (:wat::core::ast->source (:wat::core::nth ks 0))
                        op (:c::binop head)]
        (:wat::core::cond
          ((:c::if? head) (:c::if-form ks a o env fns rt tb slot))
          ((:c::let? head) (:c::let-form ks a o env fns rt tb slot))
          ((:c::println? head) (:c::print-form ks a o env fns rt tb slot))
          ((:wat::core::not (:wat::core::= op ""))
            (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) (:c::fail "operator arity" a)
              (:c::fold op ks 2 (:c::expr (:wat::core::nth ks 1) o env fns rt tb slot) env fns rt tb slot)))
          ((:wat::core::>= (:c::fn-addr fns head 0) 0) (:c::call-user ks head o env fns rt tb slot))
          (:else (:c::fail "call" a)))))))

;; left fold: the first argument lands in rax, and each one after it is pushed, computed and
;; popped back -- the stack discipline a compiler without a register allocator has to use
(:wat::core::defn :c::fold [op <- :wat::core::String ks <- :c::Kids i <- :wat::core::i64
                            o <- :c::Out env <- :c::Env fns <- :c::Fns
                            rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:wat::core::let
      [o1 (:c::emit o "50")                                   ;; push rax
       o2 (:c::expr (:wat::core::nth ks i) o1 env fns rt tb slot)
       o3 (:c::emit o2 "4889c1")                              ;; mov rcx, rax
       o4 (:c::emit o3 "58")                                  ;; pop rax
       o5 (:c::emit o4 (:c::op-hex op))]
      (:c::fold op ks (:wat::core::+ i 1) o5 env fns rt tb slot))))

;; ---------------------------------------------------------------- if

(:wat::core::defn :c::if-form [ks <- :c::Kids a <- :wat::WatAST o <- :c::Out env <- :c::Env fns <- :c::Fns
                               rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::length ks) 4) (:c::fail "if arity" a)
    (:wat::core::let
      [o1 (:c::expr (:wat::core::nth ks 1) o env fns rt tb slot)
       o2 (:c::emit o1 "4885c0")                       ;; test rax, rax
       o3 (:c::emit o2 "0f8400000000")                 ;; jz <patched below>
       jz-at (:wat::core::- (:c::codelen o3) 4)
       o4 (:c::expr (:wat::core::nth ks 2) o3 env fns rt tb slot)
       o5 (:c::emit o4 "e900000000")                   ;; jmp <patched below>
       jmp-at (:wat::core::- (:c::codelen o5) 4)
       o6 (:c::patch o5 jz-at (:asm::le (:wat::core::- (:c::codelen o5) (:wat::core::+ jz-at 4)) 4))
       o7 (:c::expr (:wat::core::nth ks 3) o6 env fns rt tb slot)]
      (:c::patch o7 jmp-at (:asm::le (:wat::core::- (:c::codelen o7) (:wat::core::+ jmp-at 4)) 4)))))

;; ---------------------------------------------------------------- let

(:wat::core::defrecord :c::BindR [o <- :c::Out  env <- :c::Env  slot <- :wat::core::i64])

(:wat::core::defn :c::bind-each [bs <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                 fns <- :c::Fns rt <- :wat::core::i64 tb <- :wat::core::i64
                                 slot <- :wat::core::i64] -> :c::BindR
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) (:c::BindR :o o :env env :slot slot)
    (:wat::core::let
      [name (:wat::core::ast->source (:wat::core::nth bs i))
       ;; the initialiser is compiled in the OUTER scope, which is what makes `let` not `letrec`
       o1 (:c::expr (:wat::core::nth bs (:wat::core::+ i 1)) o env fns rt tb slot)
       disp (:wat::core::* -8 (:wat::core::+ slot 1))
       o2 (:c::emit o1 (:c::store disp))]
      (:c::bind-each bs (:wat::core::+ i 2) o2
        (:wat::core::conj env (:c::Bind :name name :disp disp)) fns rt tb (:wat::core::+ slot 1)))))

(:wat::core::defn :c::let-form [ks <- :c::Kids a <- :wat::WatAST o <- :c::Out env <- :c::Env fns <- :c::Fns
                                rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) (:c::fail "let arity" a)
    (:wat::core::let [bs (:wat::core::ast->children (:wat::core::nth ks 1))]
      (:wat::core::if (:wat::core::not= (:wat::core::rem (:wat::core::length bs) 2) 0) (:c::fail "let bindings" a)
        (:wat::core::let [r (:c::bind-each bs 0 o env fns rt tb slot)]
          ;; the bindings go out of scope with the body, so the env is not carried back out
          (:c::seq ks 2 (:c::BindR/o r) (:c::BindR/env r) fns rt tb (:c::BindR/slot r)))))))

;; a sequence of forms; the last one's value is the value of the whole
(:wat::core::defn :c::seq [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env fns <- :c::Fns
                           rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::seq ks (:wat::core::+ i 1) (:c::expr (:wat::core::nth ks i) o env fns rt tb slot)
      env fns rt tb slot)))

;; ---------------------------------------------------------------- println

(:wat::core::defn :c::print-form [ks <- :c::Kids a <- :wat::WatAST o <- :c::Out env <- :c::Env fns <- :c::Fns
                                  rt <- :wat::core::i64 tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "println arity" a)
    (:wat::core::let [arg (:wat::core::nth ks 1)]
      (:wat::core::if (:wat::core::= (:c::kind arg) "string") (:c::print-string arg o tb)
        (:c::call (:c::expr arg o env fns rt tb slot) rt)))))

;; `:wat::kernel::println` renders a String as EDN -- `(println "a\nb")` writes `"a\nb"` and a
;; newline, quotes kept and the escape NOT expanded -- so the faithful compilation of a string
;; literal is its SOURCE TEXT, verbatim. The first version stripped the quotes and unescaped,
;; and the differential test against the interpreter caught it on the first run.
(:wat::core::defn :c::print-string [a <- :wat::WatAST o <- :c::Out tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let
    [text (:wat::string::concat (:wat::core::ast->source a) "\n")
     addr (:wat::core::+ tb (:wat::core::/ (:wat::string::length (:c::Out/tail o)) 2))
     o1 (:wat::core::assoc o :tail (:wat::string::concat (:c::Out/tail o) (:asm::ascii text 0 "")))]
    (:c::emit (:c::emit (:c::emit (:c::emit o1 (:c::mov-rax 1)) (:c::mov-rdi 1))
                (:wat::string::concat (:c::mov-rsi addr) (:c::mov-rdx (:wat::string::length text))))
      "0f05")))

;; ---------------------------------------------------------------- calling a user function
;;
;; Arguments are pushed left to right, so the last one is nearest the top of the stack. Inside
;; the callee, rbp points at the saved rbp, [rbp+8] is the return address, and argument i of n
;; sits at [rbp + 16 + 8*(n-1-i)]. The caller pops them after the call.

(:wat::core::defn :c::push-args [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                 fns <- :c::Fns rt <- :wat::core::i64 tb <- :wat::core::i64
                                 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::push-args ks (:wat::core::+ i 1)
      (:c::emit (:c::expr (:wat::core::nth ks i) o env fns rt tb slot) "50") env fns rt tb slot)))

(:wat::core::defn :c::call-user [ks <- :c::Kids head <- :wat::core::String o <- :c::Out env <- :c::Env
                                 fns <- :c::Fns rt <- :wat::core::i64 tb <- :wat::core::i64
                                 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::let [n (:wat::core::- (:wat::core::length ks) 1)
                    o1 (:c::push-args ks 1 o env fns rt tb slot)
                    o2 (:c::call o1 (:c::fn-addr fns head 0))]
    (:wat::core::if (:wat::core::= n 0) o2 (:c::emit o2 (:c::add-rsp (:wat::core::* 8 n))))))

;; ---------------------------------------------------------------- compiling one function

(:wat::core::defn :c::param-env [pv <- :c::Kids i <- :wat::core::i64 n <- :wat::core::i64
                                 env <- :c::Env] -> :c::Env
  ;; the parameter vector reads `name :- type` per parameter, so names are every third child
  (:wat::core::if (:wat::core::>= i (:wat::core::length pv)) env
    (:c::param-env pv (:wat::core::+ i 3) n
      (:wat::core::conj env
        (:c::Bind :name (:wat::core::ast->source (:wat::core::nth pv i))
                  :disp (:wat::core::+ 16 (:wat::core::* 8 (:wat::core::- (:wat::core::- n 1)
                                                             (:wat::core::/ i 3)))))))))

(:wat::core::defn :c::nparams [pv <- :c::Kids] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:wat::core::length pv) 0) 0
    (:wat::core::+ (:wat::core::/ (:wat::core::- (:wat::core::length pv) 1) 3) 1)))

(:wat::core::defn :c::compile-fn [node <- :wat::WatAST base <- :wat::core::i64 fns <- :c::Fns
                                  rt <- :wat::core::i64 tb <- :wat::core::i64
                                  tail-in <- :wat::core::String] -> :c::Out
  (:wat::core::let
    [ks (:wat::core::ast->children node)
     pv (:wat::core::ast->children (:wat::core::nth ks 2))
     n (:c::nparams pv)
     env (:c::param-env pv 0 n (:wat::core::Vector :- [:c::Bind]))
     start (:c::body-start ks 3)
     slots (:c::slots-body ks start 0)
     ;; the System V ABI wants rsp 16-byte aligned at a call, so the frame is rounded up
     frame (:wat::core::* 8 (:wat::core::if (:wat::core::= (:wat::core::rem slots 2) 0) slots
                              (:wat::core::+ slots 1)))
     o0 (:c::Out :base base :code "" :tail tail-in)
     o1 (:c::emit o0 (:wat::string::concat "55" "4889e5" (:c::sub-rsp frame)))
     o2 (:c::seq ks start o1 env fns rt tb 0)]
    (:c::emit o2 "c9c3")))                       ;; leave ; ret

;; ---------------------------------------------------------------- the driver
;;
;; Two passes over the WHOLE program, not just one function: a call needs the callee's address,
;; and a callee's address depends on the length of everything before it. Pass one compiles with
;; every address zero, purely to measure; pass two compiles again with the real table. Every
;; immediate and every displacement is fixed width, so the two passes are the same length -- and
;; the compiler asserts that, function by function.

(:wat::core::defn :c::forms-of [src <- :wat::core::String] -> :wat::WatAST
  (:wat::core::match (:wat::core::read-string src)
    [:wat::core::ReadOutcome.Forms {:forms fs} fs]
    [:wat::core::ReadOutcome.Malformed {:cause e}
      (:wat::kernel::assertion-failed!
        :message (:wat::string::concat "compile: unreadable source: " (:wat::core::Error/message e)))]))

(:wat::core::defn :c::collect [tops <- :c::Kids i <- :wat::core::i64 acc <- :c::Fns] -> :c::Fns
  (:wat::core::if (:wat::core::>= i (:wat::core::length tops)) acc
    (:wat::core::let [t (:wat::core::nth tops i)
                      ks (:wat::core::ast->children t)]
      (:wat::core::if (:wat::core::or (:wat::core::not (:wat::core::= (:c::kind t) "list"))
                        (:wat::core::not (:c::defn? (:wat::core::ast->source (:wat::core::nth ks 0)))))
        (:wat::kernel::assertion-failed!
          :message (:wat::string::concat "compile: only defn is allowed at the top level: "
                     (:wat::core::ast->source t)))
        (:c::collect tops (:wat::core::+ i 1)
          (:wat::core::conj acc (:c::Fn :name (:wat::core::ast->source (:wat::core::nth ks 1))
                                        :node t :addr 0)))))))

;; one pass over every function: each is compiled at the address the table says, and the lengths
;; come back so the next table can be built
(:wat::core::defrecord :c::PassR
  [code <- :wat::core::String  tail <- :wat::core::String
   lens <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :c::pass [fns <- :c::Fns i <- :wat::core::i64 rt <- :wat::core::i64 tb <- :wat::core::i64
                            acc <- :c::PassR] -> :c::PassR
  (:wat::core::if (:wat::core::>= i (:wat::core::length fns)) acc
    (:wat::core::let
      [f (:wat::core::nth fns i)
       o (:c::compile-fn (:c::Fn/node f) (:c::Fn/addr f) fns rt tb (:c::PassR/tail acc))]
      (:c::pass fns (:wat::core::+ i 1) rt tb
        (:c::PassR :code (:wat::string::concat (:c::PassR/code acc) (:c::Out/code o))
                   :tail (:c::Out/tail o)
                   :lens (:wat::core::conj (:c::PassR/lens acc) (:c::codelen o)))))))

(:wat::core::defn :c::empty-pass [] -> :c::PassR
  (:c::PassR :code "" :tail "" :lens (:wat::core::Vector :- [:wat::core::i64])))

;; the entry stub: call main, then exit(0). 19 bytes, and the only code not compiled from a defn.
(:wat::core::defn :c::stub-len [] -> :wat::core::i64 19)

(:wat::core::defn :c::stub [main-addr <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [o (:c::Out :base (:asm::entry) :code "" :tail "")]
    (:c::Out/code (:c::emit (:c::call o main-addr)
                    (:wat::string::concat (:c::mov-rax 60) "31ff" "0f05")))))

;; place every function end to end after the stub
(:wat::core::defn :c::place [fns <- :c::Fns lens <- (:wat::core::Vector :- [:wat::core::i64])
                             i <- :wat::core::i64 at <- :wat::core::i64 acc <- :c::Fns] -> :c::Fns
  (:wat::core::if (:wat::core::>= i (:wat::core::length fns)) acc
    (:c::place fns lens (:wat::core::+ i 1) (:wat::core::+ at (:wat::core::nth lens i))
      (:wat::core::conj acc (:wat::core::assoc (:wat::core::nth fns i) :addr at)))))

(:wat::core::defn :c::total [lens <- (:wat::core::Vector :- [:wat::core::i64]) i <- :wat::core::i64
                             acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length lens)) acc
    (:c::total lens (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth lens i)))))

(:wat::core::defn :c::same-lens [a <- (:wat::core::Vector :- [:wat::core::i64])
                                 b <- (:wat::core::Vector :- [:wat::core::i64]) i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i (:wat::core::length a)) nil
    (:wat::core::do (:wat::test::assert-eq (:wat::core::nth a i) (:wat::core::nth b i))
                    (:c::same-lens a b (:wat::core::+ i 1)))))

(:wat::core::defn :c::compile [src-path <- :wat::core::String out-path <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let
    [tops (:wat::core::ast->children (:c::forms-of (:wat::io::read-file src-path)))
     fns0 (:c::collect tops 0 (:wat::core::Vector :- [:c::Fn]))

     ;; PASS ONE: nothing has an address yet, and nothing needs one
     p1 (:c::pass fns0 0 0 0 (:c::empty-pass))
     code-total (:c::total (:c::PassR/lens p1) 0 0)

     ;; now every address follows from the lengths
     fns1 (:c::place fns0 (:c::PassR/lens p1) 0
            (:wat::core::+ (:asm::entry) (:c::stub-len)) (:wat::core::Vector :- [:c::Fn]))
     rt-addr (:wat::core::+ (:wat::core::+ (:asm::entry) (:c::stub-len)) code-total)
     tail-base (:wat::core::+ rt-addr (:wat::core::/ (:wat::string::length (:c::runtime)) 2))
     main-addr (:c::fn-addr fns1 "user/main" 0)

     ;; PASS TWO: now they do
     p2 (:c::pass fns1 0 rt-addr tail-base (:c::empty-pass))
     text (:wat::string::concat (:c::stub main-addr) (:c::PassR/code p2) (:c::runtime))
     written (:asm::link out-path text (:c::PassR/tail p2))
     int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:wat::core::do
      (:wat::core::if (:wat::core::< main-addr 0)
        (:wat::kernel::assertion-failed! :message "compile: no user/main") nil)
      ;; the invariant the two-pass technique rests on
      (:c::same-lens (:c::PassR/lens p1) (:c::PassR/lens p2) 0)
      (:wat::test::assert-eq (:wat::string::length (:c::PassR/tail p1))
                             (:wat::string::length (:c::PassR/tail p2)))
      (:wat::kernel::println
        (:wat::string::concat "compile: " (:asm::pad src-path 22) " -> " (:asm::pad out-path 24)
          (:asm::pad (int written) 5) " bytes   fns " (:asm::pad (int (:wat::core::length fns0)) 3)
          "  code " (:asm::pad (int code-total) 5)
          "  data " (:asm::pad (int (:wat::core::/ (:wat::string::length (:c::PassR/tail p2)) 2)) 4)
          "  verified")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c::compile "elf/bad/unsupported.wat" "elf/out/bad.elf")
    
    
    
    
    
    ))
