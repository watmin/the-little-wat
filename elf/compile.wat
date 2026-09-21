
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
;;   `rd/read`                    source text -> an arena of nodes (elf/lib/reader.wat, C-130)
;;   `rd/kind`                    "list", "symbol", "int", "string", "vector", "keyword"
;;   `rd/kids`                    a node's children, as indices
;;   `rd/text`                    a node's text, which is the literal for ints and the name for
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
;;   (wat.core/do BODY...)                 a sequence; the last form is the value
;;   (user/NAME args...)                   a call, arguments on the stack, recursion included --
;;                                         and a SELF call in tail position becomes a jmp, because
;;                                         wat has TCO and a compiler for wat therefore owes it
;;   (wat.kernel/println EXPR | "literal")
;;   (wat.core/+ - * quot rem)             n-ary, folded left
;;   (wat.core/< > <= >= = not=)           cmp + setcc + movzx, so a bool is 0 or 1 in rax
;;   (wat.core/cond (TEST BODY...) ...)    a chain of ifs, with (:else BODY) for the last
;;   (wat.core/and A ...) (wat.core/or A ...)  the first falsy / first truthy operand, or the last
;;   (wat.core/not A)                      test + sete + movzx
;;   (:wat::core::/ A B)                   integer division -- keyword spelling only (F-121)
;;   (wat.string/concat A B ...)           n-ary, folded left through `str_cat`
;;   (wat.string/length S)                 a peek at the string's header
;;   (wat.core/Vector :- [T] E ...)        allocate and fill
;;   (wat.core/nth V I) (wat.core/length V) (wat.core/conj V X)
;;   (:ns::Rec :field V ...)               a record, slots filled in DECLARATION order
;;   (:ns::Rec/field R)                    a load at a constant offset
;;   (wat.core/assoc R :field V)           a copy with one slot replaced
;;   nil, true, false                      a machine zero, a one and a zero
;;   integer literals, negatives included, nested to any depth
;;   string literals, as VALUES: a pointer to [len:8][bytes...] in the data tail
;;
;; and an INTRINSIC set that is the compiler's own, not wat's:
;;
;;   (wat.os/getpid) (wat.os/getppid) (wat.os/fork)     a bare syscall, result in rax
;;   (wat.os/exit N)                                     exit(N)
;;   (wat.os/wait)                                       wait4, answering the raw status
;;   (wat.os/mmap N)                                     anonymous read+write memory
;;   (wat.os/clone SP)                                   a child sharing the address space
;;   (wat.os/peek A) (wat.os/poke A V)                   eight bytes at an address
;;
;; Both spellings of every name are accepted -- `wat.core/+` and `:wat::core::+` -- because the
;; reader keeps whichever the source used and this repository writes one while the migration
;; targets the other.
;;
;; Anything else is a COMPILE ERROR that names the form it could not translate, which is the
;; least a compiler owes its caller.
;;
;; ## Where the compiled language stops being wat
;;
;; Everything in the first list is wat, and `elf/src/*.wat` is checked by running each program
;; BOTH ways and requiring identical output. Nothing in the second list is: the interpreter has
;; no `wat.os/fork`, so `elf/native/*.wat` cannot be run by it at all and has no differential
;; oracle. That is the same position a C compiler is in with `write` -- it does not implement it
;; either -- and C's answer is libc. wat has no equivalent: its OS surface (`:wat::io::`,
;; `:wat::kernel::spawn-*`) is implemented in Rust inside the interpreter, so a compiled program
;; cannot reach it. **F-119** is that gap, found by walking into it.
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
;; ## One layout for everything that is not a machine word
;;
;; A String, a Vector and a record are the same shape: `[count:8][payload...]`. So `length` is
;; one instruction for all three, `nth` and a record field read are the same indexed load, and
;; `concat`, `conj` and `assoc` are all copies. The only thing a record has that a Vector does
;; not is field NAMES known at compile time, which is what puts its accesses at constant offsets.
;;
;; `defrecord` and `typealias` have to be written in the keyword spelling -- the Clojure one is
;; refused -- which is F-122.
;;
;; ## Strings, and the heap
;;
;; A String value is one machine word, like everything else: the address of `[len:8][bytes...]`.
;; Literals live in the read-only data tail. Anything `concat` builds lives in a megabyte the
;; entry stub `mmap`s, bump-allocated through **r15**, which is reserved for the program's whole
;; life and is the entire memory model -- no free, no collector, no bounds check.
;;
;; The header length is in BYTES, and `:wat::string::length` counts CHARACTERS. They agree only
;; for ASCII, so a non-ASCII literal is refused rather than silently mis-measured; wat has no
;; byte-length verb to compile against. See F-120, and `elf/bad/nonascii.wat`.
;;
;; ## The runtime
;;
;; Six routines, 501 bytes, the only part of the output not computed from the source, and the
;; part a C toolchain would call libc for:
;;
;;   `print_i64`   87 bytes   sign handling, a divide-by-ten loop building digits backwards on
;;                            the stack, and one `write`. Checked against four values (a
;;                            negative, a small one, zero, and i64::MAX) before it was embedded.
;;   `str_cat`     97 bytes   two lengths added, a header written at the heap top, two copy
;;                            loops, r15 bumped.
;;   `print_str`  147 bytes   wat's EDN escaping, in machine code.
;;   `print_bool`  64 bytes   `true` and `false` built on the stack, so it needs no relocation.
;;   `buf_put`     70 bytes   the thing libc calls stdio: a 4 KiB buffer at r14, one syscall
;;                            per buffer instead of one per `println`.
;;   `flush`       36 bytes   write what is buffered and empty it -- which every way out of the
;;                            program has to do, `exit` and `fork` and `clone` included.
;;
;; That last one is the interesting one. `println` renders a String as EDN, so agreeing with the
;; interpreter means reproducing its escaping exactly -- and every escape in it was found by
;; ASKING the interpreter what it printed, because nothing says. **F-120** is that gap.
;;
;; Run from the repository root:
;;   wat elf/compile.wat        # compiles elf/src/*.wat to elf/out/*.elf and verifies each
;;   tools/elf-run.sh           # chmod +x, run them, compare their output

(:wat::load-file! "lib/prim.wat")
(:wat::load-file! "lib/asm.wat")
(:wat::load-file! "lib/reader.wat")
;; the x86-64 encoder and the support routines every compiled program carries. Neither knows
;; anything about wat -- no AST, no types, no scopes -- which is why they are separable at all
;; (C-174). `runtime` depends on `x86`; nothing below depends on anything above.
(:wat::load-file! "lib/x86.wat")
(:wat::load-file! "lib/runtime.wat")

;; `+` and `*` do not care which side an operand came from; `-`, `quot` and `rem` do
(:wat::core::defn :c::comm-op? [op <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= op "+") (:wat::core::= op "*")))

(:wat::core::defn :c::shift-op? [op <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= op "shl")
    (:wat::core::or (:wat::core::= op "sar") (:wat::core::= op "shr"))))

(:wat::core::defn :c::op-hex [op <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "+") (:c::add-rr (:c::rcx) (:c::rax)))
    ((:wat::core::= op "-") (:c::sub-rr (:c::rcx) (:c::rax)))
    ((:wat::core::= op "*") (:c::imul-rr (:c::rcx) (:c::rax)))
    ;; idiv wants the dividend sign-extended into rdx:rax, which is what cqo is for
    ((:wat::core::= op "quot") "489948f7f9")            ;; cqo ; idiv rcx  -> quotient in rax
    ((:wat::core::= op "rem") "489948f7f94889d0")       ;; cqo ; idiv rcx ; mov rax, rdx
    ((:wat::core::= op "bit-and") (:c::and-rr (:c::rcx) (:c::rax)))
    ((:wat::core::= op "bit-or") (:c::or-rr (:c::rcx) (:c::rax)))
    ((:wat::core::= op "bit-xor") (:c::xor-rr (:c::rcx) (:c::rax)))
    ;; **a variable shift count has to be in CL**, and the fold's non-commutative path has
    ;; already put the right operand in rcx. x86 masks the count to six bits for a 64-bit
    ;; operand, which is exactly what the JVM does and therefore what clj does -- so these
    ;; three match `(bit-shift-left 1 64)` = 1 with no extra work.
    ((:wat::core::= op "shl") (:c::shl-cl (:c::rax)))
    ((:wat::core::= op "sar") (:c::sar-cl (:c::rax)))
    ((:wat::core::= op "shr") (:c::shr-cl (:c::rax)))

    ;; a comparison is cmp + setcc + movzx, so a bool is an ordinary 0 or 1 in rax
    (:else (:wat::string::concat (:c::cmp-rr (:c::rcx) (:c::rax))
                                 (:c::setcc op) "480fb6c0"))))

(:wat::core::defn :c::setcc [op <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "<") "0f9cc0")
    ((:wat::core::= op ">") "0f9fc0")
    ((:wat::core::= op "<=") "0f9ec0")
    ((:wat::core::= op ">=") "0f9dc0")
    ((:wat::core::= op "=") "0f94c0")
    (:else "0f95c0")))

;; ---------------------------------------------------------------- the output being built

;; `rax` names the binding whose value is ALREADY in rax, or "". A `let` writes its register and
;; the body's very first act is usually to read it straight back -- `mov %rax,%rbx` followed by
;; `mov %rbx,%rax` -- which is two instructions at every binding C-142's inlining creates.
;;
;; **The window is one instruction wide and every emission closes it.** `:c::emit` clears the
;; field unconditionally, and only `:c::bind-each` sets it, immediately after its store. So the
;; read is elided only when nothing whatever was emitted in between -- which is also what makes
;; it safe against a jump landing on the read: a branch target is a position some emission
;; recorded, and any emission has already cleared the field.

;; ---------------------------------------------------------------- the accumulator
;;
;; **F-127 made appending to a record field cost 3x, and this is the answer that needs no
;; ownership proof at all.** `concat` can only extend a String in place when the compiler can
;; prove nothing else holds it, and a field read is precisely the case where it cannot -- so the
;; correct rule copies the whole accumulated string on every append, which is quadratic.
;;
;; C-144 met the same wall from the other side and took the same way out: *stop asking the
;; compiler*. A `Buf` is the string as a VECTOR OF CHUNKS, and a chunk vector appends by
;; `conj` -- which on the promoting vector's tree arm (C-145) copies the path to the leaf and
;; SHARES everything else. Around 850 bytes an append instead of the whole accumulator, with no
;; uniqueness to establish, because nothing is mutated.
;;
;; The string only has to exist as one piece twice: when a patch has to reach into it, and at
;; the end. `:c::buf-str` is that fold, and ITS accumulator is a linear parameter -- read once on
;; every path -- so the in-place rule applies to it and the flatten is linear, not quadratic.
(:wat::core::defrecord :c::Buf
  [ch <- (:wat::core::Vector :- [:wat::core::String])  n <- :wat::core::i64])

(:wat::core::defn :c::buf0 [] -> :c::Buf
  (:c::Buf :ch (:wat::core::Vector :- [:wat::core::String]) :n 0))

(:wat::core::defn :c::buf-add [b <- :c::Buf s <- :wat::core::String] -> :c::Buf
  (:c::Buf :ch (:wat::core::conj (:c::Buf/ch b) s)
           :n (:wat::core::+ (:c::Buf/n b) (:wat::string::length s))))

;; the length without building the string -- which is the whole point, since `:c::here` asks for
;; it on every instruction
(:wat::core::defn :c::buf-len [b <- :c::Buf] -> :wat::core::i64 (:c::Buf/n b))

(:wat::core::defn :c::buf-fold [v <- (:wat::core::Vector :- [:wat::core::String])
                                i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:c::buf-fold v (:wat::core::+ i 1)
      (:wat::string::concat acc (:wat::core::nth v i)))))

(:wat::core::defn :c::buf-str [b <- :c::Buf] -> :wat::core::String
  (:c::buf-fold (:c::Buf/ch b) 0 ""))

(:wat::core::defn :c::buf-one [s <- :wat::core::String] -> :c::Buf
  (:c::buf-add (:c::buf0) s))

(:wat::core::defrecord :c::Out
;; **`sp` is how many bytes the stack has been pushed since the body began; `fk` is the distance
;; from rsp to where rbp points.** Neither matters while there is a frame pointer -- a local is
;; `[rbp-8]` however deep the stack happens to be -- and both matter the moment rbp stops being
;; one, because then a local is `[rsp + d + fk + sp]` and the emitter is the only thing that
;; knows the depth. Tracking them while still addressing through rbp is how the tracking gets
;; tested: every binary has to come out byte for byte identical.
  [base <- :wat::core::i64  code <- :c::Buf  tail <- :c::Buf
   rax <- :wat::core::String  sp <- :wat::core::i64  fk <- :wat::core::i64
   fpr <- :wat::core::bool])

(:wat::core::defn :c::emit [o <- :c::Out hex <- :wat::core::String] -> :c::Out
  (:wat::core::assoc (:wat::core::assoc o :code (:c::buf-add (:c::Out/code o) hex))
                     :rax ""))

(:wat::core::defn :c::codelen [o <- :c::Out] -> :wat::core::i64
  (:wat::core::/ (:c::buf-len (:c::Out/code o)) 2))

;; Every instruction that moves rsp goes through one of these and nothing else may move it.
;; **They take the hex the site was already emitting**, rather than splitting it: an emit split
;; in two is a second chunk in the `:c::Buf` and a second call, and one such split in the `poke`
;; clause cost the compiler 168 MB -> 1.85 GB (F-128).
(:wat::core::defn :c::push [o <- :c::Out hex <- :wat::core::String n <- :wat::core::i64] -> :c::Out
  (:wat::core::assoc (:c::emit o hex) :sp (:wat::core::+ (:c::Out/sp o) n)))
(:wat::core::defn :c::popn [o <- :c::Out hex <- :wat::core::String n <- :wat::core::i64] -> :c::Out
  (:wat::core::assoc (:c::emit o hex) :sp (:wat::core::- (:c::Out/sp o) n)))

;; the displacement that reaches what `[rbp + d]` reaches, measured from rsp
;; the displacement that reaches what `[rbp + d]` reaches. **A function that CLONES keeps its
;; frame pointer**, so for those it is still `d`: `clone` gives the child a fresh rsp and lets it
;; inherit rbp, which is the only reason a thread can see the frame it was spawned from. C-136
;; already refuses such a function its register parameters and C-121 its tail calls, for the same
;; reason; this is the third thing the intrinsic costs.
;;
;; **The eight bytes that held the saved rbp are gone, and only the things ABOVE the frame
;; notice.** `sub rsp, frame` still carves the same slots out of the same place, so a local at
;; `[rbp-8k]` lands where it always did; but the return address and the arguments sat above the
;; saved rbp, so each of them is now eight bytes nearer. Locals are the negative displacements
;; and arguments the positive ones, which is what makes the test a sign.
(:wat::core::defn :c::fp-at [d <- :wat::core::i64 adj <- :wat::core::i64
                            fp? <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::if fp? d
    (:wat::core::+ (:wat::core::if (:wat::core::> d 0) (:wat::core::- d 8) d) adj)))

;; how far rsp is from where rbp would be, which is all an operand's own displacement needs
(:wat::core::defn :c::fp-adj [o <- :c::Out] -> :wat::core::i64
  (:wat::core::+ (:c::Out/fk o) (:c::Out/sp o)))

(:wat::core::defn :c::fp [o <- :c::Out d <- :wat::core::i64] -> :wat::core::i64
  (:c::fp-at d (:c::fp-adj o) (:c::Out/fpr o)))

;; a body has to end at the depth it began, or every displacement after it is wrong by whatever
;; leaked. This is the whole test for the tracking, and it runs on every function of every
;; program the compiler builds.
(:wat::core::defn :c::at-depth0 [o <- :c::Out hex <- :wat::core::String] -> :c::Out
  (:wat::core::if (:wat::core::not= (:c::Out/sp o) 0)
    (:wat::kernel::assertion-failed!
      :message (:wat::string::concat "compile: a function body left "
                 (:wat::i64::to-string (:c::Out/sp o)) " bytes on the stack"))
    (:c::emit o hex)))

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
;; **A patch is a branch join, and a join must forget what rax held.** Two paths meet here and
;; they do not agree; every `if` and every `cond` clause lands on one of these, so clearing the
;; tracking in this one place covers all of them.
(:wat::core::defn :c::patch [o <- :c::Out off <- :wat::core::i64 hex <- :wat::core::String] -> :c::Out
  (:wat::core::let [code (:c::buf-str (:c::Out/code o))
                    at (:wat::core::* off 2)]
    (:wat::core::assoc (:wat::core::assoc o :rax "") :code
      (:c::buf-one (:wat::string::concat
        (:wat::string::subs code 0 at)
        hex
        (:wat::string::subs code (:wat::core::+ at (:wat::string::length hex)) (:wat::string::length code)))))))

;; ---------------------------------------------------------------- names, in both spellings

(:wat::core::defn :c::is? [src <- :wat::core::String clj <- :wat::core::String kw <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= src clj) (:wat::core::= src kw)))

(:wat::core::defn :c::binop [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:c::is? src "wat.core/+" ":wat::core::+") "+")
    ((:c::is? src "wat.core/-" ":wat::core::-") "-")
    ((:c::is? src "wat.core/*" ":wat::core::*") "*")
    ((:c::is? src "wat.core/quot" ":wat::core::quot") "quot")
    ;; `/` has no Clojure spelling the reader will take (`wat.core//` reads as `:wat::core/::`),
    ;; and on i64 it truncates toward zero -- `(/ -7 2)` is -3 -- which is exactly idiv
    ((:wat::core::= src ":wat::core::/") "quot")
    ((:c::is? src "wat.core/rem" ":wat::core::rem") "rem")
    ((:c::is? src "wat.core/<" ":wat::core::<") "<")
    ((:c::is? src "wat.core/>" ":wat::core::>") ">")
    ((:c::is? src "wat.core/<=" ":wat::core::<=") "<=")
    ((:c::is? src "wat.core/>=" ":wat::core::>=") ">=")
    ((:c::is? src "wat.core/=" ":wat::core::=") "=")
    ((:c::is? src "wat.core/not=" ":wat::core::not=") "not=")
    ;; **clj's bitwise six** (F-134). They live in the i64 namespace because they are i64-only
    ;; ops; `wat.core/` arithmetic is a stdlib defclause dispatching on argument type, and these
    ;; have nothing to dispatch on. None of them can overflow -- a bit leaving the top is what a
    ;; shift IS -- so `:c::ovf?` never names them and no `jo` is emitted.
    ((:c::is? src "wat.i64/bit-and" ":wat::i64::bit-and") "bit-and")
    ((:c::is? src "wat.i64/bit-or" ":wat::i64::bit-or") "bit-or")
    ((:c::is? src "wat.i64/bit-xor" ":wat::i64::bit-xor") "bit-xor")
    ((:c::is? src "wat.i64/bit-shift-left" ":wat::i64::bit-shift-left") "shl")
    ((:c::is? src "wat.i64/bit-shift-right" ":wat::i64::bit-shift-right") "sar")
    ((:c::is? src "wat.i64/unsigned-bit-shift-right" ":wat::i64::unsigned-bit-shift-right") "shr")
    (:else "")))

;; `bit-not` is the one unary member, so it is not a `:c::binop` -- it sits with `not`
(:wat::core::defn :c::bit-not? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.i64/bit-not" ":wat::i64::bit-not"))

;; ---- the byte-indexed string verbs, which COMPILE TO THE SAME INSTRUCTIONS
;;
;; **F-120 is the whole reason these are aliases here and distinct verbs in the interpreter.**
;; A String on this heap is a length followed by its bytes, and the length is a BYTE count --
;; so `length` already answers what `byte-length` asks, `subs` already slices what `byte-subs`
;; slices, and `code-point-at` is already the `movzbq` that `byte-at` wants. The interpreter has
;; no such luxury: it holds UTF-8 and counts characters, so there the two families genuinely
;; differ and a character index costs a walk.
;;
;; That divergence is safe here for exactly one reason -- this compiler REFUSES a non-ASCII
;; source (`elf/bad/nonascii.wat`), and for ASCII a byte index is a character index. The reader
;; moved to the byte family because the char one made it O(n^2); see F-138.
(:wat::core::defn :c::codeat? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:c::is? s "wat.string/code-point-at" ":wat::string::code-point-at")
    (:c::is? s "wat.string/byte-at" ":wat::string::byte-at")))

;; ---- the compiler's INTRINSICS: verbs that become a syscall rather than a call
;;
;; This is the first point where the compiled language stops being a subset of wat. The
;; interpreter has no `wat.os/fork`, so a program using these cannot be run by it, and the
;; differential test that carried every earlier program does not apply. That is not a trick: it
;; is the same position a C compiler is in with `write`, which it does not implement either. The
;; difference is that C's answer is libc and wat's answer would have to be an intrinsic present
;; in BOTH worlds -- which is a real requirement for the builder's roadmap, stated here because
;; this is the file that ran into it.
(:wat::core::defn :c::syscall-nr [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:c::is? s "wat.os/getpid" ":wat::os::getpid") 39)
    ((:c::is? s "wat.os/fork" ":wat::os::fork") 57)
    ((:c::is? s "wat.os/getppid" ":wat::os::getppid") 110)
    (:else -1)))

(:wat::core::defn :c::exit? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/exit" ":wat::os::exit"))
(:wat::core::defn :c::wait? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/wait" ":wat::os::wait"))
;; one-argument intrinsics that take their argument in a register other than rdi
(:wat::core::defn :c::mmap? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/mmap" ":wat::os::mmap"))
(:wat::core::defn :c::clone? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/clone" ":wat::os::clone"))
(:wat::core::defn :c::peek? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/peek" ":wat::os::peek"))
(:wat::core::defn :c::poke? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.os/poke" ":wat::os::poke"))

(:wat::core::defn :c::do? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/do" ":wat::core::do"))

(:wat::core::defn :c::println? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.kernel/println" ":wat::kernel::println"))
(:wat::core::defn :c::defrecord? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/defrecord" ":wat::core::defrecord"))
(:wat::core::defn :c::typealias? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/typealias" ":wat::core::typealias"))
(:wat::core::defn :c::vector? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/Vector" ":wat::core::Vector"))
(:wat::core::defn :c::nth? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/nth" ":wat::core::nth"))
(:wat::core::defn :c::len? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/length" ":wat::core::length"))
(:wat::core::defn :c::conj? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/conj" ":wat::core::conj"))
(:wat::core::defn :c::assoc? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/assoc" ":wat::core::assoc"))
(:wat::core::defn :c::cond? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/cond" ":wat::core::cond"))
(:wat::core::defn :c::and? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/and" ":wat::core::and"))
(:wat::core::defn :c::or? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/or" ":wat::core::or"))
(:wat::core::defn :c::not? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/not" ":wat::core::not"))
(:wat::core::defn :c::concat? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.string/concat" ":wat::string::concat"))
(:wat::core::defn :c::wrhex? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "prim/write-hex" ":prim::write-hex"))
(:wat::core::defn :c::rdhex? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "prim/read-hex" ":prim::read-hex"))
(:wat::core::defn :c::prim-name? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:c::wrhex? s) (:c::rdhex? s)))
(:wat::core::defn :c::rdfile? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.io/read-file" ":wat::io::read-file"))
(:wat::core::defn :c::die? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.kernel/assertion-failed!" ":wat::kernel::assertion-failed!"))
(:wat::core::defn :c::asserteq? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.test/assert-eq" ":wat::test::assert-eq"))
(:wat::core::defn :c::subs? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:c::is? s "wat.string/subs" ":wat::string::subs")
    (:c::is? s "wat.string/byte-subs" ":wat::string::byte-subs")))
(:wat::core::defn :c::starts? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.string/starts-with?" ":wat::string::starts-with?"))
(:wat::core::defn :c::contains? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.string/contains?" ":wat::string::contains?"))
(:wat::core::defn :c::tostr? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.i64/to-string" ":wat::i64::to-string"))
(:wat::core::defn :c::strlen? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:c::is? s "wat.string/length" ":wat::string::length")
    (:c::is? s "wat.string/byte-length" ":wat::string::byte-length")))
(:wat::core::defn :c::if? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/if" ":wat::core::if"))
(:wat::core::defn :c::let? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/let" ":wat::core::let"))
(:wat::core::defn :c::defn? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat.core/defn" ":wat::core::defn"))

(:wat::core::defn :c::fail [what <- :wat::core::String a <- :wat::core::i64 pg <- :c::Prog] -> :c::Out
  (:wat::kernel::assertion-failed!
    :message (:wat::string::concat "compile: cannot compile " what ": " (:c::text pg a))))

;; digits, by hand. `:wat::string::to-i64` answers an `Option`, and an Option needs `match`,
;; and `match` is one of the last things standing between this compiler and compiling itself --
;; so the parse is a fold over the characters instead, which needs nothing but arithmetic.
(:wat::core::defn :c::digit-val [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= c "0") 0) ((:wat::core::= c "1") 1) ((:wat::core::= c "2") 2)
    ((:wat::core::= c "3") 3) ((:wat::core::= c "4") 4) ((:wat::core::= c "5") 5)
    ((:wat::core::= c "6") 6) ((:wat::core::= c "7") 7) ((:wat::core::= c "8") 8)
    ((:wat::core::= c "9") 9) (:else -1)))

(:wat::core::defn :c::digits-val [s <- :wat::core::String i <- :wat::core::i64
                                  acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:c::digits-val s (:wat::core::+ i 1)
      (:wat::core::+ (:wat::core::* acc 10)
        (:c::digit-val (:wat::string::subs s i (:wat::core::+ i 1)))))))

;; **A negative literal accumulates NEGATIVELY**, and that is not a flourish. i64's range is
;; asymmetric: there is a -9223372036854775808 and no +9223372036854775808. Parsing the digits
;; as a positive magnitude and negating it therefore overflows on exactly the most negative
;; literal there is -- a number wat accepts and prints. It used to WRAP twice and land on the
;; right answer by luck; C-148 made arithmetic trap, and the luck became a refused program.
(:wat::core::defn :c::neg-digits-val [s <- :wat::core::String i <- :wat::core::i64
                                      acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:c::neg-digits-val s (:wat::core::+ i 1)
      (:wat::core::- (:wat::core::* acc 10)
        (:c::digit-val (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :c::to-int [s <- :wat::core::String pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::string::starts-with? s "-")
    (:c::neg-digits-val (:wat::string::subs s 1 (:wat::string::length s)) 0 0)
    (:c::digits-val s 0 0)))

;; the three verbs the reader replaces. `pg` carries the arena, so a node is an index and these
;; are exactly `ast-kind`, `ast->source` and `ast->children` -- except that `:c::text` answers
;; the bytes the file actually had, where `ast->source` re-prints (C-130).
(:wat::core::defn :c::kind [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::String
  (rd/kind (:c::Prog/src pg) a))
(:wat::core::defn :c::text [pg <- :c::Prog a <- :wat::core::i64] -> :wat::core::String
  (rd/text (:c::Prog/src pg) a))
(:wat::core::defn :c::kidsof [pg <- :c::Prog a <- :wat::core::i64] -> :c::Kids
  (rd/kids (:c::Prog/src pg) a))

;; ---------------------------------------------------------------- scopes and functions

(:wat::core::typealias :c::Kids (:wat::core::Vector :- [:wat::core::i64]))

;; a name and where it lives, as a displacement from rbp: parameters above it, locals below
;; A name lives either in the frame at `disp`, or in one of three registers this compiler keeps
;; for the purpose: `reg` is -1 for the frame, or 0, 1, 2 for rbx, r12, r13.
;;
;; Those three are callee-saved in the System V ABI, which is the whole reason they work: a call
;; cannot clobber them, so a parameter read after a call is still there. The runtime routines
;; that used rbx and r12 as scratch (`slot_set` and the three file primitives) now save them.
(:wat::core::defrecord :c::Bind
  [name <- :wat::core::String  disp <- :wat::core::i64  ty <- :wat::core::String
   reg <- :wat::core::i64])
;; ---------------------------------------------------------------- what a value can be
;;
;; **A bound is a closed interval, and "unknown" is not a sentinel -- it is the whole range.**
;; C-166 carried one fact, "this name is non-negative", which is exactly what proves `x - k`
;; safe and exactly what cannot prove `x * 3` safe: for a multiply you need to know how BIG the
;; value is. So the fact becomes an interval, and F-130 is the reason -- the overflow checks are
;; 32% of a throughput-bound loop, and the only sound way to remove one is to prove it dead.
;;
;; The representation is chosen so the mistake has no form. There is no `Option`, no "not found"
;; marker, no 999999 (C-139's complaint, declined here rather than repeated): a name with nothing
;; known about it has the bound `[i64-min, i64-max]`, which is the TOP of the lattice and proves
;; nothing. Every transfer function below is total and returns top when it cannot do better, so
;; "forgot to handle unknown" is not a thing that can be written down -- unknown is just a bound
;; that happens to admit everything.
(:wat::core::defrecord :c::Bnd [name <- :wat::core::String
                                lo <- :wat::core::i64
                                hi <- :wat::core::i64])
(:wat::core::typealias :c::Bnds (:wat::core::Vector :- [:c::Bnd]))

(:wat::core::defn :c::i64-min [] -> :wat::core::i64 -9223372036854775808)
(:wat::core::defn :c::i64-max [] -> :wat::core::i64 9223372036854775807)
(:wat::core::defn :c::bnd-any [] -> :c::Bnd
  (:c::Bnd :name "" :lo (:c::i64-min) :hi (:c::i64-max)))
(:wat::core::defn :c::bnd-at [lo <- :wat::core::i64 hi <- :wat::core::i64] -> :c::Bnd
  (:c::Bnd :name "" :lo lo :hi hi))
(:wat::core::defn :c::bnd-top? [b <- :c::Bnd] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:c::Bnd/lo b) (:c::i64-min))
                   (:wat::core::= (:c::Bnd/hi b) (:c::i64-max))))

;; **the compiler's own arithmetic traps too**, so none of these may compute the thing they are
;; asking about. `a + b` fits iff neither end runs off, and each limit is itself computed by a
;; subtraction that cannot overflow: `max - b` only when `b` is positive, `min - b` only when it
;; is negative.
(:wat::core::defn :c::add-ok? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::not
    (:wat::core::or
      (:wat::core::and (:wat::core::> b 0) (:wat::core::> a (:wat::core::- (:c::i64-max) b)))
      (:wat::core::and (:wat::core::< b 0) (:wat::core::< a (:wat::core::- (:c::i64-min) b))))))
(:wat::core::defn :c::sub-ok? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::not
    (:wat::core::or
      (:wat::core::and (:wat::core::< b 0) (:wat::core::> a (:wat::core::+ (:c::i64-max) b)))
      (:wat::core::and (:wat::core::> b 0) (:wat::core::< a (:wat::core::+ (:c::i64-min) b))))))

;; `a * b` fits, asked in magnitudes so the test is one division. **The most negative i64 has no
;; magnitude** (C-150's lesson, and the reason `:asm::le` was wrong for months), so it is refused
;; outright unless the other side is 0 or 1. Measuring against `i64-max` rather than `|i64-min|`
;; rejects the one product that lands exactly on the floor; being conservative here costs a check
;; that could have gone, which is the safe direction to be wrong in.
(:wat::core::defn :c::iabs [a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a 0) (:wat::core::- 0 a) a))
(:wat::core::defn :c::mul-ok? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::or (:wat::core::= a 0) (:wat::core::= b 0)) true)
    ((:wat::core::or (:wat::core::= a 1) (:wat::core::= b 1)) true)
    ((:wat::core::or (:wat::core::= a (:c::i64-min)) (:wat::core::= b (:c::i64-min))) false)
    (:else (:wat::core::<= (:c::iabs a)
                           (:wat::core::quot (:c::i64-max) (:c::iabs b))))))

(:wat::core::defn :c::bnd-add [x <- :c::Bnd y <- :c::Bnd] -> :c::Bnd
  (:wat::core::if (:wat::core::and (:c::add-ok? (:c::Bnd/lo x) (:c::Bnd/lo y))
                                   (:c::add-ok? (:c::Bnd/hi x) (:c::Bnd/hi y)))
    (:c::bnd-at (:wat::core::+ (:c::Bnd/lo x) (:c::Bnd/lo y))
                (:wat::core::+ (:c::Bnd/hi x) (:c::Bnd/hi y)))
    (:c::bnd-any)))
(:wat::core::defn :c::bnd-sub [x <- :c::Bnd y <- :c::Bnd] -> :c::Bnd
  (:wat::core::if (:wat::core::and (:c::sub-ok? (:c::Bnd/lo x) (:c::Bnd/hi y))
                                   (:c::sub-ok? (:c::Bnd/hi x) (:c::Bnd/lo y)))
    (:c::bnd-at (:wat::core::- (:c::Bnd/lo x) (:c::Bnd/hi y))
                (:wat::core::- (:c::Bnd/hi x) (:c::Bnd/lo y)))
    (:c::bnd-any)))
;; a product's extremes are among the four corners, whatever the signs
(:wat::core::defn :c::bnd-mul [x <- :c::Bnd y <- :c::Bnd] -> :c::Bnd
  (:wat::core::if
    (:wat::core::not (:wat::core::and (:c::mul-ok? (:c::Bnd/lo x) (:c::Bnd/lo y))
                       (:wat::core::and (:c::mul-ok? (:c::Bnd/lo x) (:c::Bnd/hi y))
                         (:wat::core::and (:c::mul-ok? (:c::Bnd/hi x) (:c::Bnd/lo y))
                                          (:c::mul-ok? (:c::Bnd/hi x) (:c::Bnd/hi y))))))
    (:c::bnd-any)
    (:wat::core::let [a (:wat::core::* (:c::Bnd/lo x) (:c::Bnd/lo y))
                      b (:wat::core::* (:c::Bnd/lo x) (:c::Bnd/hi y))
                      c (:wat::core::* (:c::Bnd/hi x) (:c::Bnd/lo y))
                      d (:wat::core::* (:c::Bnd/hi x) (:c::Bnd/hi y))]
      (:c::bnd-at (:c::imin (:c::imin a b) (:c::imin c d))
                  (:c::imax (:c::imax a b) (:c::imax c d))))))

;; **the question every overflow check asks.** `op` on these two bounds cannot leave i64, so the
;; `jo` that guards it can never be taken on any path that reaches it.
(:wat::core::defn :c::op-safe? [op <- :wat::core::String x <- :c::Bnd y <- :c::Bnd] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= op "+") (:wat::core::not (:c::bnd-top? (:c::bnd-add x y))))
    ((:wat::core::= op "-") (:wat::core::not (:c::bnd-top? (:c::bnd-sub x y))))
    ((:wat::core::= op "*") (:wat::core::not (:c::bnd-top? (:c::bnd-mul x y))))
    (:else false)))

;; the bound recorded for a name, or top -- absence IS top, which is why there is no sentinel
(:wat::core::defn :c::bnd-of [bs <- :c::Bnds name <- :wat::core::String
                              i <- :wat::core::i64] -> :c::Bnd
  (:wat::core::cond
    ((:wat::core::< i 0) (:c::bnd-any))
    ((:wat::core::= (:c::Bnd/name (:wat::core::nth bs i)) name) (:wat::core::nth bs i))
    (:else (:c::bnd-of bs name (:wat::core::- i 1)))))
(:wat::core::defn :c::bnd-for [bs <- :c::Bnds name <- :wat::core::String] -> :c::Bnd
  (:c::bnd-of bs name (:wat::core::- (:wat::core::length bs) 1)))

;; **a later entry shadows an earlier one**, because the lookup scans from the end -- so putting
;; is `conj` and dropping is putting top. A `let` that rebinds a name drops what the enclosing
;; branch proved about the old value; nothing has to be removed from the vector for that to hold.
(:wat::core::defn :c::bnd-put [bs <- :c::Bnds name <- :wat::core::String
                               lo <- :wat::core::i64 hi <- :wat::core::i64] -> :c::Bnds
  (:wat::core::conj bs (:c::Bnd :name name :lo lo :hi hi)))
(:wat::core::defn :c::bnd-drop [bs <- :c::Bnds name <- :wat::core::String] -> :c::Bnds
  (:c::bnd-put bs name (:c::i64-min) (:c::i64-max)))

(:wat::core::typealias :c::Env (:wat::core::Vector :- [:c::Bind]))

;; innermost first, so a `let` shadows a parameter of the same name
;; how many parameters get registers, and which registers those are
;; **four, because frame-pointer elimination freed rbp.** rbx, r12, r13, rbp -- every
;; callee-saved register the ABI has that this compiler is not already spending on the output
;; buffer (r14) and the heap (r15). A function that CLONES gets none of them anyway, which is
;; what keeps rbp available as its frame pointer.
(:wat::core::defn :c::nregs [] -> :wat::core::i64 4)

(:wat::core::defn :c::reg-of [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "symbol") -1
    (:c::lookup-reg env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))))

(:wat::core::defn :c::imm-cmp? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:c::kind a pg) "int")
                   (:c::imm32? (:c::to-int (:c::text pg a) pg))))

;; the operand forms, when the right-hand side is one of those registers
;; **`OP REG, rax` -- thirty-two hand-written encodings, now four rows.** `add`, `sub` and `cmp`
;; put their source in the ModRM `reg` field; `imul` is the odd one and puts its DESTINATION
;; there, which is the whole reason `:c::rr` names the fields instead of the operands.
(:wat::core::defn :c::reg-op [op <- :wat::core::String r <- :wat::core::i64] -> :wat::core::String
  (:c::reg-op-to op r (:c::rax)))

;; **the same four rows with somewhere other than rax to put the answer.** Every value this
;; compiler computes lands in rax and is then moved to where it belongs, which is an
;; ACCUMULATOR machine -- and F-151 measured what that costs: three `mov %rax,%rN` an
;; iteration in `triple`, sitting ON the loop-carried chain, which is in turn why the
;; branchless select could not be afforded. `+` and `*` are commutative, so the left operand
;; can be folded in from wherever it already lives once the right one is in the destination.
(:wat::core::defn :c::reg-op-to [op <- :wat::core::String r <- :wat::core::i64
                                 dst <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "+") (:c::add-rr r dst))
    ((:wat::core::= op "-") (:c::sub-rr r dst))
    ((:wat::core::= op "*") (:c::imul-rr r dst))
    ((:c::cmp? op) (:c::cmp-rr r dst))
    (:else "")))

(:wat::core::defn :c::lookup-reg [env <- :c::Env name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::< i 0) -1)
    ((:wat::core::= (:c::Bind/name (:wat::core::nth env i)) name) (:c::Bind/reg (:wat::core::nth env i)))
    (:else (:c::lookup-reg env name (:wat::core::- i 1)))))

(:wat::core::defn :c::lookup [env <- :c::Env name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::< i 0) 999999)
    ((:wat::core::= (:c::Bind/name (:wat::core::nth env i)) name) (:c::Bind/disp (:wat::core::nth env i)))
    (:else (:c::lookup env name (:wat::core::- i 1)))))

(:wat::core::defn :c::lookup-ty [env <- :c::Env name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::< i 0) "i64")
    ((:wat::core::= (:c::Bind/name (:wat::core::nth env i)) name) (:c::Bind/ty (:wat::core::nth env i)))
    (:else (:c::lookup-ty env name (:wat::core::- i 1)))))

(:wat::core::defrecord :c::Fn
  [name <- :wat::core::String  node <- :wat::core::i64  addr <- :wat::core::i64
   ret <- :wat::core::String])
(:wat::core::typealias :c::FnV (:wat::core::Vector :- [:c::Fn]))

;; ---------------------------------------------------------------- records and type aliases
;;
;; A record is a name, its field names in declaration order, and their declared types. That is
;; everything a compiler needs: construction fills the slots in that order, a field access is an
;; indexed load, and `assoc` copies and replaces one -- because a record and a Vector are the
;; SAME shape in memory, `[count:8][slot:8]...`, every slot a machine word.
(:wat::core::defrecord :c::Rec
  [name <- :wat::core::String
   fields <- (:wat::core::Vector :- [:wat::core::String])
   ftypes <- (:wat::core::Vector :- [:wat::core::String])
   fv <- :wat::core::i64])
(:wat::core::typealias :c::Recs (:wat::core::Vector :- [:c::Rec]))

;; a `typealias` is a name standing for a type expression; the compiler only ever needs the
;; type STRING it resolves to, so that is what is stored
(:wat::core::defrecord :c::Alias [name <- :wat::core::String  node <- :wat::core::i64])
(:wat::core::typealias :c::Aliases (:wat::core::Vector :- [:c::Alias]))

;; everything the compiler knows about the program it is compiling, threaded as one value so
;; that adding a table does not mean another parameter on every function
(:wat::core::defrecord :c::Prog
  [fns <- :c::FnV  recs <- :c::Recs  aliases <- :c::Aliases
   linear <- (:wat::core::Vector :- [:wat::core::String])
   pokers <- (:wat::core::Vector :- [:wat::core::String])
   ;; parameters represented by one field, in the register the parameter already has.
   ;; parallel to `sfield`: the field index within the record. empty unless scalarised.
   scalar <- (:wat::core::Vector :- [:wat::core::String])
   sfield <- (:wat::core::Vector :- [:wat::core::i64])
   ;; the callee-saved registers this function hands to `let`: how many, and the first index
   ;; a parameter has not already taken (C-136). Per-function, so it rides here rather than
   ;; threading a new argument through every expression form.
   nlr <- :wat::core::i64
   regbase <- :wat::core::i64
   ;; how many of r8-r11 the scratch pool may still have: four normally, fewer when this
   ;; function has spent some of them on `let` bindings
   nscr <- :wat::core::i64
   ;; **what this branch has proved about the values in scope.** See `:c::Bnd`; a name that is
   ;; not in here is not unknown-as-a-special-case, it simply has the bound that admits anything.
   bnds <- :c::Bnds
   src <- :rd::St])

;; `:c::Bind/name` is a record accessor and `user/main` is a function; the difference is whether
;; the part before the LAST slash names a record. Scanning from the end is the only way to find
;; it: a String has no elements and there is no index-of (F-062).
(:wat::core::defn :c::slash-at [s <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::< i 0) -1)
    ((:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "/") i)
    (:else (:c::slash-at s (:wat::core::- i 1)))))

(:wat::core::defn :c::rec-index [rs <- :c::Recs name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length rs)) -1)
    ((:wat::core::= (:c::Rec/name (:wat::core::nth rs i)) name) i)
    (:else (:c::rec-index rs name (:wat::core::+ i 1)))))

(:wat::core::defn :c::field-index [fs <- (:wat::core::Vector :- [:wat::core::String])
                                   name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length fs)) -1)
    ((:wat::core::= (:wat::core::nth fs i) name) i)
    (:else (:c::field-index fs name (:wat::core::+ i 1)))))

(:wat::core::defn :c::alias-index [as <- :c::Aliases name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length as)) -1)
    ((:wat::core::= (:c::Alias/name (:wat::core::nth as i)) name) i)
    (:else (:c::alias-index as name (:wat::core::+ i 1)))))

(:wat::core::defn :c::empty-prog [] -> :c::Prog
  (:c::Prog :fns (:wat::core::Vector :- [:c::Fn])
            :recs (:wat::core::Vector :- [:c::Rec])
            :aliases (:wat::core::Vector :- [:c::Alias])
            :nscr (:c::nscratch)
            :bnds (:wat::core::Vector :- [:c::Bnd])
            :linear (:wat::core::Vector :- [:wat::core::String])
            :pokers (:wat::core::Vector :- [:wat::core::String])
            :scalar (:wat::core::Vector :- [:wat::core::String])
            :sfield (:wat::core::Vector :- [:wat::core::i64])
            :nlr 0 :regbase 0
            :src (rd/read "")))

(:wat::core::defn :c::fn-ret [pg <- :c::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [v (:c::Prog/fns pg)]
    (:wat::core::cond
      ((:wat::core::>= i (:wat::core::length v)) "i64")
      ((:wat::core::= (:c::Fn/name (:wat::core::nth v i)) name) (:c::Fn/ret (:wat::core::nth v i)))
      (:else (:c::fn-ret pg name (:wat::core::+ i 1))))))

(:wat::core::defn :c::fn-addr [pg <- :c::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [v (:c::Prog/fns pg)]
    (:wat::core::cond
      ((:wat::core::>= i (:wat::core::length v)) -1)
      ((:wat::core::= (:c::Fn/name (:wat::core::nth v i)) name) (:c::Fn/addr (:wat::core::nth v i)))
      (:else (:c::fn-addr pg name (:wat::core::+ i 1))))))

;; A `defn`'s children are: the word, the name, the parameter vector, the `:-` or `->` marker,
;; the return type, and then the body. So the body starts at five, always.
;;
;; This used to scan forward for the first child that was a LIST, which is right for every body
;; that is a call and wrong for every body that is not. `:asm::printable` returns a bare string
;; literal, so the scan ran off the end, the body compiled to nothing, and the function answered
;; whatever was in rax -- a 95-character table that came back with length 0. The compiler had
;; been carrying that since the first commit; nothing noticed until it compiled itself.
(:wat::core::defn :c::body-start [ks <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::< (:wat::core::length ks) 5) (:wat::core::length ks) 5))

;; ---------------------------------------------------------------- what type an expression has
;;
;; The compiler needs this for exactly one decision -- which of the two print routines `println`
;; should call -- but that one decision reaches everywhere, because the argument can be a name, a
;; branch, a call or a `let`. So there is a small static type pass, with two types: a machine
;; word (`i64`) and a pointer to a string header (`str`).
;;
;; It is deliberately not inference. Every type is DECLARED somewhere -- on a parameter, on a
;; `defn`'s return -- and this walk only propagates what the declarations already say. A wat type
;; is recognised by its spelling, which covers `wat.type/String` and `:wat::core::String` without
;; a table.

;; A type is named by its spelling, which works for `wat.type/String` and `:wat::core::String`
;; alike without a table. Three things need more than spelling: a `Vector` type carries its
;; element type, a record name resolves to that record, and a `typealias` stands for whatever it
;; was declared as -- which is why the alias table holds the NODE and this recurses into it.
;; `depth` is the only thing standing between a self-referential alias and a hang.
(:wat::core::defn :c::ty-of-node [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::String
  (:c::ty-node a pg 8))

(:wat::core::defn :c::ty-node [a <- :wat::core::i64 pg <- :c::Prog depth <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::<= depth 0) "i64"
    (:wat::core::if (:wat::core::= (:c::kind a pg) "list")
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::or (:wat::core::< (:wat::core::length ks) 3)
                          (:wat::core::not (:c::vector? (:c::text pg (:wat::core::nth ks 0)))))
          "i64"
          ;; (Vector :- [T]) -- the element type is the type vector's first child
          (:wat::core::let [tv (:c::kidsof pg (:wat::core::nth ks 2))]
            (:wat::core::if (:wat::core::= (:wat::core::length tv) 0) "vec:i64"
              (:wat::string::concat "vec:" (:c::ty-node (:wat::core::nth tv 0) pg (:wat::core::- depth 1)))))))
      (:wat::core::let [src (:c::text pg a)
                        ri (:c::rec-index (:c::Prog/recs pg) src 0)
                        ai (:c::alias-index (:c::Prog/aliases pg) src 0)]
        (:wat::core::cond
          ((:wat::core::>= ri 0) (:wat::string::concat "rec:" src))
          ((:wat::core::>= ai 0)
            (:c::ty-node (:c::Alias/node (:wat::core::nth (:c::Prog/aliases pg) ai)) pg
              (:wat::core::- depth 1)))
          ;; **exact names, not substrings.** This used to ask whether the annotation CONTAINED
          ;; "String", which makes a user type called `StringBuilder` a string and one called
          ;; `nilable` a nil. And the fallthrough was "i64", so an unrecognised type quietly
          ;; became a machine word -- which is the silent-divergence shape F-120 is about:
          ;; `println` would render a pointer as an integer. An unknown type is now a refusal.
          ((:c::is? src "wat.type/String" ":wat::core::String") "str")
          ((:c::is? src "wat.type/bool" ":wat::core::bool") "bool")
          ((:c::is? src "wat.type/nil" ":wat::core::nil") "nil")
          ((:c::is? src "wat.type/i64" ":wat::core::i64") "i64")
          (:else
            (:wat::kernel::assertion-failed!
              :message (:wat::string::concat "compile: unknown type: " src))))))))

;; the element type of a vector type, and the declared type of a record's field
(:wat::core::defn :c::elem-ty [t <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::string::starts-with? t "vec:")
    (:wat::string::subs t 4 (:wat::string::length t)) "i64"))

(:wat::core::defn :c::rec-name-of [t <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::string::starts-with? t "rec:")
    (:wat::string::subs t 4 (:wat::string::length t)) ""))

;; a comparison answers a bool; everything else `:c::binop` names answers a machine word
(:wat::core::defn :c::cmp? [op <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= op "<") (:wat::core::= op ">")
    (:wat::core::or (:wat::core::= op "<=") (:wat::core::= op ">=")
      (:wat::core::or (:wat::core::= op "=") (:wat::core::= op "not=")))))

(:wat::core::defn :c::type-of [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::String
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "string") "str")
      ((:wat::core::= k "nil") "nil")
      ((:wat::core::= k "bool") "bool")
      ((:wat::core::= k "symbol") (:c::lookup-ty env (:c::text pg a)
                                    (:wat::core::- (:wat::core::length env) 1)))
      ((:wat::core::= k "list") (:c::type-of-form (:c::kidsof pg a) env pg))
      (:else "i64"))))

(:wat::core::defn :c::type-of-form [ks <- :c::Kids env <- :c::Env pg <- :c::Prog] -> :wat::core::String
  (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) "i64"
    (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))
                      last (:wat::core::nth ks (:wat::core::- (:wat::core::length ks) 1))]
      (:wat::core::cond
        ((:c::concat? head) "str")
        ((:c::println? head) "nil")
        ((:wat::core::or (:c::die? head) (:c::asserteq? head)) "nil")
        ;; a branch is typed by its consequent; the alternative has to agree, and if it does not
        ;; the program is wrong in a way this compiler does not check
        ((:c::if? head) (:c::type-of (:wat::core::nth ks 2) env pg))
        ((:c::not? head) "bool")
        ;; and / or answer one of their operands, so the last one's type is the honest guess
        ((:wat::core::or (:c::and? head) (:c::or? head)) (:c::type-of last env pg))
        ;; a cond is typed by its first clause's body, the way an if is by its consequent
        ((:c::cond? head)
          (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) "i64"
            (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks 1))]
              (:wat::core::if (:wat::core::< (:wat::core::length cks) 2) "i64"
                (:c::type-of (:wat::core::nth cks (:wat::core::- (:wat::core::length cks) 1)) env pg)))))
        ((:c::do? head) (:c::type-of last env pg))
        ((:c::let? head)
          (:c::type-of last
            (:c::ty-bind (:c::kidsof pg (:wat::core::nth ks 1)) 0 env pg) pg))
        ((:c::cmp? (:c::binop head)) "bool")
        ((:wat::core::>= (:c::fn-addr pg head 0) 0) (:c::fn-ret pg head 0))
        ;; a Vector carries its element type, so `nth` and `conj` can say what they answer
        ((:c::vector? head)
          (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) "vec:i64"
            (:wat::core::let [tv (:c::kidsof pg (:wat::core::nth ks 2))]
              (:wat::core::if (:wat::core::= (:wat::core::length tv) 0) "vec:i64"
                (:wat::string::concat "vec:" (:c::ty-of-node (:wat::core::nth tv 0) pg))))))
        ((:c::codeat? head) "i64")
        ((:wat::core::or (:c::subs? head) (:c::tostr? head)) "str")
        ((:wat::core::or (:c::rdhex? head) (:c::rdfile? head)) "str")
        ((:wat::core::or (:c::starts? head) (:c::contains? head)) "bool")
        ((:c::nth? head)
          (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) "i64"
            (:c::elem-ty (:c::type-of (:wat::core::nth ks 1) env pg))))
        ((:wat::core::or (:c::conj? head) (:c::assoc? head))
          (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) "i64"
            (:c::type-of (:wat::core::nth ks 1) env pg)))
        ((:wat::core::>= (:c::rec-index (:c::Prog/recs pg) head 0) 0)
          (:wat::string::concat "rec:" head))
        ((:wat::core::>= (:c::acc-index pg head) 0) (:c::acc-ty pg head))
        (:else "i64")))))

;; the declared type of the field an accessor reads
(:wat::core::defn :c::acc-ty [pg <- :c::Prog head <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [at (:c::slash-at head (:wat::core::- (:wat::string::length head) 1))]
    (:wat::core::if (:wat::core::< at 0) "i64"
      (:wat::core::let [ri (:c::rec-index (:c::Prog/recs pg) (:wat::string::subs head 0 at) 0)
                        fi (:c::acc-index pg head)]
        (:wat::core::if (:wat::core::or (:wat::core::< ri 0) (:wat::core::< fi 0)) "i64"
          (:wat::core::nth (:c::Rec/ftypes (:wat::core::nth (:c::Prog/recs pg) ri)) fi))))))

;; the same left-to-right walk `:c::bind-each` does, carrying types instead of displacements
(:wat::core::defn :c::ty-bind [bs <- :c::Kids i <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :c::Env
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) env
    (:c::ty-bind bs (:wat::core::+ i 2)
      (:wat::core::conj env
        (:c::Bind :name (:c::text pg (:wat::core::nth bs i)) :disp 0 :reg -1
                  :ty (:c::type-of (:wat::core::nth bs (:wat::core::+ i 1)) env pg)))
      pg)))

;; ---------------------------------------------------------------- string literals, as values
;;
;; A string VALUE is one machine word: the address of `[len:8][bytes...]`, so it fits the same
;; one-register model everything else uses. Literals live in the read-only data tail; anything
;; `concat` builds lives in the heap the entry stub mmaps.
;;
;; The header length is in BYTES, and `:wat::string::length` counts CHARACTERS -- they agree only
;; for ASCII, which is why a non-ASCII literal is refused rather than silently mis-measured. The
;; refusal comes for free: `:asm::code-of` has no code for it and says "not encodable". wat has
;; no byte-length verb to compile against; see F-120.

(:wat::core::defn :c::unescape [s <- :wat::core::String i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:wat::core::let [c (:wat::string::subs s i (:wat::core::+ i 1))]
      (:wat::core::if (:wat::core::and (:wat::core::= c "\\")
                        (:wat::core::< (:wat::core::+ i 1) (:wat::string::length s)))
        (:c::unescape s (:wat::core::+ i 2)
          (:wat::string::concat acc
            (:wat::core::let [d (:wat::string::subs s (:wat::core::+ i 1) (:wat::core::+ i 2))]
              (:wat::core::cond
                ((:wat::core::= d "n") "\n")
                ((:wat::core::= d "t") "\t")
                ((:wat::core::= d "r") "\r")
                (:else d)))))
        (:c::unescape s (:wat::core::+ i 1) (:wat::string::concat acc c))))))

(:wat::core::defn :c::zeros [n <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::<= n 0) acc
    (:c::zeros (:wat::core::- n 1) (:wat::string::concat acc "00"))))

;; a header is eight bytes, so the bytes after it are padded back up to a multiple of eight
;; a String constant in the read-only tail, and the address of it in rax
(:wat::core::defn :c::static-str [text <- :wat::core::String o <- :c::Out tb <- :wat::core::i64
                                  dst <- :wat::core::i64] -> :c::Out
  (:wat::core::let
    [n (:wat::string::length text)

     addr (:wat::core::+ tb (:wat::core::/ (:c::buf-len (:c::Out/tail o)) 2))
     pad (:wat::core::rem (:wat::core::- 8 (:wat::core::rem n 8)) 8)
     o1 (:wat::core::assoc o :tail
          ;; a reference count of ZERO in front of it. Every heap object carries its count at
          ;; [p-8] and starts at 1; a literal lives in the read-only segment and must never be
          ;; mistaken for a unique heap object, so it gets a count no allocation can produce.
          (:c::buf-add (:c::Out/tail o)
            (:wat::string::concat (:asm::le 0 8) (:asm::le n 8)
              (:asm::ascii text 0 "") (:c::zeros pad ""))))]
    (:c::emit o1 (:c::movabs dst (:wat::core::+ addr 8)))))

(:wat::core::defn :c::str-lit [a <- :wat::core::i64 o <- :c::Out tb <- :wat::core::i64
                               pg <- :c::Prog dst <- :wat::core::i64] -> :c::Out
  (:wat::core::let [src (:c::text pg a)]
    (:c::static-str
      (:c::unescape (:wat::string::subs src 1 (:wat::core::- (:wat::string::length src) 1)) 0 "")
      o tb dst)))

;; ---------------------------------------------------------------- frame size
;;
;; A `let` needs a slot per binding, and the prologue has to reserve them before the body is
;; compiled -- so the compiler walks the body first and takes the deepest simultaneous demand.
;; Slots are never reused between sibling `let`s, which costs stack and buys simplicity.

(:wat::core::defn :c::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

(:wat::core::defn :c::slots-of [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::not (:wat::core::= (:c::kind a pg) "list")) 0
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) 0
        (:wat::core::if (:c::let? (:c::text pg (:wat::core::nth ks 0)))
          (:wat::core::+ (:wat::core::/ (:wat::core::length (:c::kidsof pg (:wat::core::nth ks 1))) 2)
            (:c::imax (:c::slots-list (:c::kidsof pg (:wat::core::nth ks 1)) 0 0 pg)
                      (:c::slots-list ks 2 0 pg)))
          (:c::slots-list ks 0 0 pg))))))

(:wat::core::defn :c::slots-list [ks <- :c::Kids i <- :wat::core::i64 best <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:c::slots-list ks (:wat::core::+ i 1) (:c::imax best (:c::slots-of (:wat::core::nth ks i) pg)) pg)))

(:wat::core::defn :c::slots-body [ks <- :c::Kids i <- :wat::core::i64 best <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:c::slots-list ks i best pg))

;; ---------------------------------------------------------------- tail calls
;;
;; **wat eliminates tail calls, so a compiler for wat has to.** A million levels of tail
;; self-recursion return `1000000` under the interpreter; the same depth NOT in tail position
;; dumps core. So iteration in wat is a tail-recursive loop, and a compiler that lays every call
;; down as a `call` turns working programs into segmentation faults. `elf/src/deep.wat` is that
;; program, and before this it segfaulted at exit 139 while the interpreter printed 1000000.
;;
;; A self tail call is a `jmp` back to the top of the body with the arguments replaced:
;;
;;   <evaluate each new argument, pushing it>    left to right, as an ordinary call would
;;   pop rax ; mov [rbp+16], rax                 then popped BACK into the incoming slots,
;;   pop rax ; mov [rbp+24], rax                 last argument first, because it is on top
;;   jmp body                                    and round again, on the same frame
;;
;; The arguments are all evaluated before any of them is stored, which is what makes
;; `(f (g b) (h a))` safe when the new `a` is computed from the old `b` and vice versa.
;;
;; `:c::TC` is the context: the name and arity of the function being compiled, and the address
;; to jump back to. A `name` of "" means "this is not a tail position", and every subexpression
;; that is not in tail position is compiled with `(:c::no-tail)`.
;; **`test` and `body` are the rotated loop** (C-188). A tail-recursive function is emitted
;; as `top: <test> ; jcc body ; <base case> ; body: <recur> ; jmp top` -- so going round costs
;; a `jmp` back to the test AND the test's own branch: two taken branches an iteration where
;; one will do. When the test is one instruction on operands already in registers, the tail
;; call can emit the test ITSELF and branch straight to `body`, leaving the `jmp top` on the
;; exit path where it runs once. `test` is that instruction plus its branch opcode, `body` is
;; where the recursion starts; both empty when the shape does not apply.
(:wat::core::defrecord :c::TC
  [name <- :wat::core::String  arity <- :wat::core::i64  target <- :wat::core::i64
   nregs <- :wat::core::i64    test <- :wat::core::String  body <- :wat::core::i64])

(:wat::core::defn :c::no-tail [] -> :c::TC
  (:c::TC :name "" :arity 0 :target 0 :nregs 0 :test "" :body 0))

(:wat::core::defn :c::tail-call? [tc <- :c::TC head <- :wat::core::String n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::not= (:c::TC/name tc) "")
    (:wat::core::and (:wat::core::= (:c::TC/name tc) head) (:wat::core::= (:c::TC/arity tc) n))))

;; pop the freshly computed arguments back over the incoming ones, last first
;; pop k is argument n-1-k, because they were pushed left to right. A parameter that lives in a
;; register is popped straight into it; one in the frame goes through rax.
(:wat::core::defn :c::tail-store [k <- :wat::core::i64 n <- :wat::core::i64 o <- :c::Out
                                  nr <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= k n) o
    (:wat::core::let
      [i (:wat::core::- (:wat::core::- n 1) k)
       ;; **the store happens AFTER the pop, so it measures from the shallower stack.** This is
       ;; the one site in the compiler where a frame access and a stack move share an emit, and
       ;; it is exactly the kind of thing a frame pointer made impossible to get wrong.
       fpr? (:c::Out/fpr o)
       d (:wat::core::+ (:c::fp o (:wat::core::+ 16 (:wat::core::* 8 k)))
                        (:wat::core::if (:wat::core::or fpr? (:wat::core::= k 0)) 0 -8))]
      (:c::tail-store (:wat::core::+ k 1) n
        (:c::popn o
          ;; **k = 0 is the LAST argument, and it never went to the stack.** It used to be
          ;; pushed by `:c::push-args` and popped back by the very next instruction -- a `mov`
          ;; written as a store and a load, once per iteration of every tail-recursive loop
          ;; (C-153 found the pair adjacent in `loopsum`). `:c::push-but-last` leaves it in rax.
          (:wat::core::if (:wat::core::= k 0)
            (:wat::core::if (:wat::core::< i nr) (:c::reg-mov-from i) (:c::store d fpr?))
            (:wat::core::if (:wat::core::< i nr) (:c::reg-pop i)
              (:wat::string::concat (:c::pop-rax) (:c::store d fpr?))))
          ;; ...so k = 0 moves the stack by nothing, and every other k by one slot
          (:wat::core::if (:wat::core::= k 0) 0 8))
        nr))))

;; every argument but the last pushed; the last computed into rax and LEFT there, because the
;; only thing that reads it is `:c::tail-store`'s first store
(:wat::core::defn :c::push-but-last [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                     pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                     slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:wat::core::if (:wat::core::= i (:wat::core::- (:wat::core::length ks) 1))
      (:c::share (:wat::core::nth ks i) env pg
        (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail)))
      (:c::push-but-last ks (:wat::core::+ i 1)
        (:c::push (:c::share (:wat::core::nth ks i)  env pg
                    (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))) (:c::push-rax) 8)
        env pg rt tb slot))))

;; ---------------------------------------------------------------- expressions

(:wat::core::defn :c::expr [a <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                            rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "int") (:c::emit o (:c::mov-rax-lit (:c::to-int (:c::text pg a) pg))))
      ((:wat::core::= k "symbol")
        (:wat::core::let [r (:c::lookup-reg env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))
                          d (:c::lookup env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))]
          (:wat::core::cond
            ;; already there, and nothing has been emitted since it was put there
            ((:wat::core::= (:c::Out/rax o) (:c::text pg a)) o)
            ;; **and now it IS there, so say so.** C-149 tracked what rax held but only ever
            ;; SET the field where a `let` binding stored one, so a name loaded from a register
            ;; or a frame slot was reloaded the next time it was read. Every load is a fact
            ;; about rax and every `:c::emit` after it clears the field again, which is what
            ;; keeps this honest across a branch.
            ((:wat::core::>= r 0)
              (:wat::core::assoc (:c::emit o (:c::reg-mov-to r)) :rax (:c::text pg a)))
            ((:wat::core::= d 999999) (:c::fail "name" a pg))
            (:else (:wat::core::assoc (:c::emit o (:c::load (:c::fp o d) (:c::Out/fpr o)))
                     :rax (:c::text pg a))))))
      ;; nil is a machine zero and a bool is 0 or 1, which is already what a comparison leaves
      ;; in rax -- so both are literals, and only `println` has to know which is which
      ((:wat::core::= k "nil") (:c::emit o (:c::mov-rax 0)))
      ((:wat::core::= k "bool")
        (:c::emit o (:c::mov-rax
          (:wat::core::if (:wat::core::= (:c::text pg a) "true") 1 0))))
      ((:wat::core::= k "string") (:c::str-lit a o tb pg (:c::rax)))
      ((:wat::core::= k "list") (:c::form a o env pg rt tb slot tc))
      (:else (:c::fail "expression" a pg)))))

(:wat::core::defn :c::form [a <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                            rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) (:c::fail "empty form" a pg)
      (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))
                        op (:c::binop head)]
        (:wat::core::cond
          ((:c::if? head) (:c::if-form ks a o env pg rt tb slot tc))
          ;; cond, and, or and not are `if` wearing different hats: no new instruction between
          ;; them beyond a `sete`, and 46 of the 297 occurrences the census counts (elf/census.wat)
          ((:c::cond? head) (:c::cond-form ks 1 a o env pg rt tb slot tc))
          ((:c::and? head)
            (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) (:c::fail "and arity" a pg)
              (:c::and-form ks 1 o env pg rt tb slot tc)))
          ((:c::or? head)
            (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) (:c::fail "or arity" a pg)
              (:c::or-form ks 1 o env pg rt tb slot tc)))
          ((:c::not? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "not arity" a pg)
              (:c::emit (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                (:wat::string::concat "4885c0" "0f94c0" "480fb6c0"))))   ;; test ; sete al ; movzx
          ;; the bitwise complement: one instruction, and nothing to check
          ((:c::bit-not? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "bit-not arity" a pg)
              (:c::emit (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                "48f7d0")))                                             ;; not rax
          ((:c::do? head) (:c::seq ks 1 o env pg rt tb slot tc))
          ;; a no-argument syscall: the number goes in rax, the result comes back in rax
          ((:wat::core::>= (:c::syscall-nr head) 0)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 1) (:c::fail "syscall arity" a pg)
              ;; fork duplicates the address space, buffer included -- so anything still pending
              ;; would be written TWICE, once by each side. This is the oldest bug in buffered
              ;; I/O and the fix is the oldest fix: flush before forking.
              (:c::emit (:wat::core::if (:wat::core::= (:c::syscall-nr head) 57)
                          (:c::call o (:c::at-flush rt)) o)
                (:wat::string::concat (:c::mov-rax (:c::syscall-nr head)) "0f05"))))
          ;; exit(status): the argument is computed, then moved into rdi
          ((:c::exit? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "exit arity" a pg)
              ;; the status is computed first, parked on the stack while the buffer is written,
              ;; and taken back -- because a flush clobbers rax, rcx, rdx, rsi and rdi
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::call o1 (:c::at-flush rt))]
                (:c::popn o2 (:wat::string::concat (:c::pop-rax) (:c::mov-rdi-rax) (:c::mov-rax 60) "0f05") 8))))
;; mmap(NULL, len, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)
          ;; -- the only way to get writable memory, since the one PT_LOAD is read+execute
          ((:c::mmap? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "mmap arity" a pg)
              (:c::emit (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                (:wat::string::concat
                  (:wat::string::concat (:c::mov-rsi-rax) (:c::mov-rdi 0))
                  (:wat::string::concat (:c::mov-rdx 3) (:c::mov-r10 34))
                  (:wat::string::concat (:c::mov-r8 -1) (:c::mov-r9 0))
                  (:wat::string::concat (:c::mov-rax 9) "0f05")))))
          ;; clone(CLONE_VM|CLONE_FS|CLONE_FILES|SIGCHLD, stack, 0, 0, 0)
          ;;
          ;; CLONE_VM is what makes this a THREAD -- the child shares the address space, so a
          ;; poke on one side is visible on the other. SIGCHLD rather than CLONE_THREAD is what
          ;; keeps it waitable with the same wait4 the fork program uses: a thread proper is not
          ;; a child in wait's sense, and this compiler has no futex.
          ((:c::clone? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "clone arity" a pg)
              (:c::emit (:c::popn (:c::call
                          (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                          (:c::at-flush rt)) (:c::pop-rax) 8)     ;; the child shares the buffer: empty it first
                (:wat::string::concat
                  (:wat::string::concat (:c::mov-rsi-rax) (:c::mov-rdi 1809))
                  (:wat::string::concat (:c::mov-rdx 0) (:c::mov-r10 0) (:c::mov-r8 0))
                  (:wat::string::concat (:c::mov-rax 56) "0f05")))))
          ;; peek and poke: eight bytes at an address, which is all the memory model there is
          ((:c::peek? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "peek arity" a pg)
              (:c::emit (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) "488b00")))
          ((:c::poke? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::fail "poke arity" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))]
                (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax) "488908") 8))))
          ;; wait4(-1, &status, 0, NULL) -- reap any one child and answer its raw STATUS, which is
          ;; more useful than the pid: `(rem (quot st 256) 256)` is the exit code. Sixteen bytes
          ;; of scratch are taken off rsp for the status word and given straight back.
          ((:c::wait? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 1) (:c::fail "wait arity" a pg)
              (:c::emit o (:wat::string::concat
                (:c::sub-rsp 16)
                (:wat::string::concat (:c::mov-rdi -1) "4889e6")      ;; rsi = rsp
                (:wat::string::concat (:c::mov-rdx 0) (:c::mov-r10 0))
                (:wat::string::concat (:c::mov-rax 61) "0f05")
                (:wat::string::concat "488b0424" (:c::add-rsp 16))))))
          ;; string concatenation: a left fold through `str_cat`, which is the only thing the
          ;; compiler emits that allocates. `length` is a peek at the header.
          ;; `(concat x)` is the identity, which wat accepts and this refused -- found by the
          ;; compiler compiling itself, where a routine short enough to fit one line of hex gets
          ;; a one-argument concat
          ((:c::concat? head)
            (:wat::core::if (:wat::core::< (:wat::core::length ks) 2) (:c::fail "concat arity" a pg)
              (:c::cat-fold ks 2 (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                env pg rt tb slot
                ;; the FIRST operand came from somewhere else, so it needs the same last-use
                ;; proof `conj` does -- and a non-symbol gets it from `:c::fresh-str?`, which
                ;; asks whether the operand was ALLOCATED here rather than borrowed
                (:wat::core::if (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                  (:c::linear? pg (:c::text pg (:wat::core::nth ks 1)) 0)
                  (:c::fresh-str? (:wat::core::nth ks 1) pg)))))
          ;; one instruction answers the length of a String, a Vector and a record alike,
          ;; because all three are `[count:8][payload...]` -- and the type pass is REQUIRED to
          ;; say which, rather than merely happening to know. Measured before it was demanded:
          ;; every `length` and `nth` operand in all forty programs, this compiler's own 3,000
          ;; lines included, already resolves. Demanding it is what lets a Vector change
          ;; representation without a record or a String paying for the test (F-124).
          ((:wat::core::or (:c::strlen? head) (:c::len? head))
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "length arity" a pg)
              (:wat::core::if (:wat::core::not (:c::ptr-ty? (:c::type-of (:wat::core::nth ks 1) env pg)))
                (:c::fail "length: operand is not a String, Vector or record" a pg)
                (:c::emit (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) "488b00"))))
          ;; the string verbs a reader needs: `subs` alone is sixteen of the occurrences
          ;; between this compiler and compiling itself
          ((:c::subs? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 4) (:c::fail "subs arity" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::push (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o3 (:c::expr (:wat::core::nth ks 3) o2 env pg rt tb slot (:c::no-tail))]
                (:c::call (:c::popn o3 (:wat::string::concat "4889c2" (:c::pop-rcx) (:c::pop-rax)) 16) (:c::at-subs rt)))))
          ((:wat::core::or (:c::starts? head) (:c::contains? head))
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::fail "string test arity" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))]
                (:c::call (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8)
                  (:wat::core::if (:c::starts? head) (:c::at-starts rt) (:c::at-contains rt))))))
          ((:c::codeat? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::fail "code-point-at arity" a pg)
              (:wat::core::if (:wat::core::not= (:c::type-of (:wat::core::nth ks 1) env pg) "str")
                (:c::fail "code-point-at: operand is not a String" a pg)
                (:wat::core::let
                  [sr (:c::reg-of (:wat::core::nth ks 1) env pg)
                   ir (:c::reg-of (:wat::core::nth ks 2) env pg)]
                  (:wat::core::if (:wat::core::and (:wat::core::>= sr 0) (:wat::core::>= ir 0))
                    ;; both already in registers: one instruction, nothing shuffled
                    (:c::emit o (:c::movzb-sib sr ir))
                    (:wat::core::let
                      [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                       o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))]
                      ;; rcx = the index, rax = the String; the byte is one header past the base
                      (:c::emit (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8)
                                "480fb6440808")))))))           ;; movzbq 8(%rax,%rcx,1), %rax
          ((:c::tostr? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "to-string arity" a pg)
              (:c::call (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                (:c::at-tostr rt))))
          ;; the two diagnostics. The interpreter raises a structured error with a span; a
          ;; compiled program has neither, so these print and exit 70 -- which means the two
          ;; agree on every successful run and differ only on the path that stops the program.
          ((:c::die? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3)
              (:c::fail "assertion-failed! shape" a pg)
              (:c::call (:c::expr (:wat::core::nth ks 2) o env pg rt tb slot (:c::no-tail))
                (:c::at-die rt))))
          ((:c::asserteq? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3)
              (:c::fail "assert-eq arity" a pg)
              (:c::asserteq-form ks a o env pg rt tb slot)))
          ;; the two primitives that reach the disk. A wat definition of the same name exists
          ;; for the interpreter; the compiler implements them instead, which is the whole of
          ;; F-119's contract in two verbs.
          ((:c::wrhex? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::fail "write-hex arity" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))]
                (:c::call (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8) (:c::at-wrhex rt)))))
          ((:c::rdfile? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "read-file arity" a pg)
              (:c::call (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                (:c::at-rdfile rt))))
          ((:c::rdhex? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "read-hex arity" a pg)
              (:c::call (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                (:c::at-rdhex rt))))
          ((:c::vector? head) (:c::vec-form ks a o env pg rt tb slot))
          ((:c::nth? head)
            (:wat::core::if (:wat::core::or (:wat::core::not= (:wat::core::length ks) 3)
                              (:wat::core::not (:c::ptr-ty? (:c::type-of (:wat::core::nth ks 1) env pg))))
              (:c::fail "nth: operand is not a Vector or record" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))
                 o3 (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8)]
                (:wat::core::if
                  (:wat::string::starts-with? (:c::type-of (:wat::core::nth ks 1) env pg) "rec:")
                  ;; a record never conj's, so it is the array arm for ever: one load, no test
                  (:c::emit o3 "488b44c808")
                  ;; a Vector asks. The array arm is the same single load it always was; the
                  ;; tree arm is a walk, and the branch predicts because a vector stays in one
                  ;; arm for its whole life.
                  (:c::call
                    (:c::emit o3 (:wat::string::concat
                      "488378f000"                  ;; cmp qword [rax-16], 0   -- which arm?
                      "0f8507000000"                ;; jne +7                  -- the tree
                      "488b44c808"                  ;; mov rax,[rax+rcx*8+8]   -- the array
                      "eb05"))                      ;; jmp +5                  -- over the call
                    (:c::at-tget rt))))))
          ((:c::conj? head)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::fail "conj arity" a pg)
              (:wat::core::let
                [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
                 o2 (:c::share (:wat::core::nth ks 2) env pg
                      (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail)))
                 ;; when the container is a parameter this function reads at most once on every
                 ;; path, nothing can observe a change to it afterwards -- so the runtime is
                 ;; allowed to try extending it in place instead of copying
                 own? (:wat::core::and (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                        (:c::linear? pg (:c::text pg (:wat::core::nth ks 1)) 0))]
                (:c::call (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8)
                  (:wat::core::if own? (:c::at-vconj-own rt) (:c::at-vconj rt))))))
          ((:c::assoc? head) (:c::assoc-form ks a o env pg rt tb slot))
          ;; a record constructor, and a record field read -- the two forms `defrecord` makes
          ((:wat::core::>= (:c::rec-index (:c::Prog/recs pg) head 0) 0)
            (:c::rec-form ks a (:wat::core::nth (:c::Prog/recs pg)
                                 (:c::rec-index (:c::Prog/recs pg) head 0))
              o env pg rt tb slot))
          ((:wat::core::>= (:c::acc-index pg head) 0)
            (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "field arity" a pg)
              (:wat::core::let
                [d (:wat::core::+ 8 (:wat::core::* 8 (:c::acc-index pg head)))
                 opnd (:wat::core::nth ks 1)
                 r (:c::reg-of opnd env pg)
                 sf (:wat::core::if (:wat::core::= (:c::kind opnd pg) "symbol")
                      (:c::scalar-field pg (:c::text pg opnd) 0) -1)]
                ;; **a field read from a register-resident record does not want the pointer
                ;; in rax first.** `mov %rbx,%rax ; mov 0x8(%rax),%rax` is one instruction:
                ;; `mov 0x8(%rbx),%rax`. `:c::load-at` hardcodes rax as the base, which is
                ;; right when the pointer arrived there and a wasted `mov` when it did not.
                ;; C-183. A scalarised parameter has no pointer left: the register IS the field.
                (:wat::core::cond
                  ((:wat::core::and (:wat::core::>= sf 0) (:wat::core::not= sf (:c::acc-index pg head)))
                    (:c::fail "scalar field" a pg))
                  ((:wat::core::and (:wat::core::>= sf 0) (:wat::core::>= r 0))
                    (:c::emit o (:c::mov-rr r (:c::rax))))
                  ((:wat::core::>= r 0) (:c::emit o (:c::mov-rm r d (:c::rax))))
                  (:else
                    (:c::emit (:c::expr opnd o env pg rt tb slot (:c::no-tail))
                      (:c::load-at d)))))))
          ((:c::let? head) (:c::let-form ks a o env pg rt tb slot tc))
          ((:c::println? head) (:c::print-form ks a o env pg rt tb slot))
          ;; `=` on two Strings must compare CONTENT. The type pass knows both operands, so
          ;; this is decidable at compile time -- and getting it wrong is silent (F-120's
          ;; cousin): a machine-word compare answers false for equal strings.
          ((:wat::core::and (:wat::core::or (:wat::core::= op "=") (:wat::core::= op "not="))
             (:wat::core::and (:wat::core::= (:wat::core::length ks) 3)
               (:wat::core::and (:wat::core::= (:c::type-of (:wat::core::nth ks 1) env pg) "str")
                                (:wat::core::= (:c::type-of (:wat::core::nth ks 2) env pg) "str"))))
            (:wat::core::let
              [o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
               o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))
               o3 (:c::call (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8) (:c::at-streq rt))]
              (:wat::core::if (:wat::core::= op "not=")
                (:c::emit o3 "4883f001")                ;; xor rax, 1
                o3)))
          ((:wat::core::not (:wat::core::= op ""))
            ;; **a String or a Vector is an ADDRESS, and adding to one is not arithmetic.** The
            ;; type pass knows -- it is the same pass that decides `=` on two Strings is `str_eq`
            ;; (C-130) -- and it used to let `(+ i64 String)` through to `add <pointer>(%rsp)`.
            ;; `=` and `not=` are excluded because the clause above already routed the String
            ;; case to `str_eq`, so anything reaching here is a machine word by elimination.
            (:wat::core::if (:wat::core::and (:wat::core::not (:c::cmp? op))
                              (:wat::core::not= (:c::ptr-among ks 1 env pg) ""))
              (:c::fail (:wat::string::concat "arithmetic on a "
                          (:c::ptr-among ks 1 env pg)) a pg)
            (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) (:c::fail "operator arity" a pg)
              (:wat::core::let
                [r0 (:c::reg-of (:wat::core::nth ks 1) env pg)
                 ;; **being in rax is not as good as being in a callee-saved register, and a
                 ;; `let` binding is usually in both.** When the accumulator is only in rax,
                 ;; handing the register down would mean loading it again, so -1 wins. But
                 ;; whatever comes next puts its own value in rax, so rax is the one copy that
                 ;; does NOT survive -- and for a commutative operator the register copy costs
                 ;; one instruction (`add %r12,%rax`) where rax costs three (`push` ... `pop
                 ;; %rcx` ... `add`). `(wat.core/let [a (fib (- n 1))] (+ a (fib (- n 2))))`
                 ;; stored `a` twice, once into r12 and once onto the stack, and then read the
                 ;; stack copy. For `-` the register still has to reach rax first, so there
                 ;; rax keeps its advantage.
                 ar (:wat::core::if (:wat::core::< r0 0) -1
                      (:wat::core::if (:wat::core::and
                                        (:wat::core::= (:c::Out/rax o)
                                                       (:c::text pg (:wat::core::nth ks 1)))
                                        (:wat::core::not (:c::comm-op? op))) -1 r0))]
                (:wat::core::let [ab (:c::bnd-expr (:wat::core::nth ks 1) pg (:c::Prog/bnds pg))]
                  (:wat::core::if (:wat::core::>= ar 0)
                    (:c::fold op ks 2 o env pg rt tb slot ar ab)
                    (:c::fold op ks 2
                      (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                      env pg rt tb slot -1 ab)))))))
          ;; one scan of the function table, not two: the guard used to ask `:c::fn-addr`
          ;; whether the name existed and then `:c::call-user` asked again for the address.
          ;; Asking `:c::fn-of` once answers both and leaves room for the arity check.
          (:else
            (:wat::core::let [fi (:c::fn-of pg head 0)]
              (:wat::core::if (:wat::core::< fi 0) (:c::fail "call" a pg)
                (:wat::core::if (:wat::core::not= (:c::arity-at pg fi)
                                  (:wat::core::- (:wat::core::length ks) 1))
                  (:c::fail "wrong number of arguments" a pg)
                  (:c::call-user ks head o env pg rt tb slot tc))))))))))

;; left fold: the first argument lands in rax, and each one after it is pushed, computed and
;; popped back -- the stack discipline a compiler without a register allocator has to use
;; ---------------------------------------------------------------- expression temporaries
;;
;; `:c::direct` below collapses a right operand that is a constant or a name. What it cannot
;; help with is a COMPOUND right operand -- `(+ a (* b c))`, `(nth v (+ i 1))` -- which still
;; went through the stack: push the accumulator, evaluate the operand into rax, mov rcx,rax,
;; pop rax, combine. Three instructions and two memory references to hold one value.
;;
;; A register would do, if one could be shown to survive. **r8 through r11 survive exactly when
;; the operand emits no call** -- nothing else this compiler generates touches them, and a call
;; touches all of them. So the question is decidable by looking at the subtree, and the answer is
;; a whitelist: arithmetic, comparisons, the logical forms, `if`, `cond`, `let`, `do`, `nth`,
;; `length`, `peek`, and leaves. `=` and `not=` are NOT on it, because on two Strings they call
;; `str_eq` (C-130) and that is decided by types this function does not have.
;;
;; How many of the four a subtree needs is computed bottom-up, so nothing has to be threaded:
;; an operand needing k registers is evaluated with 0..k-1, which leaves k free for the value
;; waiting on it.

(:wat::core::defn :c::nscratch [] -> :wat::core::i64 4)


;; **the pool counts DOWN from r11 so the allocator can count up from r8.** They are the same
;; four registers; taking them from opposite ends is what lets a call-free function spend the
;; ones the pool does not need without either side having to know which. That is the whole of
;; the mapping, and once it is written once the four tables below it are ordinary `mov`s.
(:wat::core::defn :c::scr-reg [r <- :wat::core::i64] -> :wat::core::i64 (:wat::core::- 7 r))

(:wat::core::defn :c::scr-save [r <- :wat::core::i64] -> :wat::core::String
  (:c::mov-rr (:c::rax) (:c::scr-reg r)))
;; `mov SCRATCH, CALLEE-SAVED` -- the scratch copy taken from where rax got it, rather than from
;; rax. `:c::expr` puts a register-resident name into rax and the scratch pool immediately copies
;; rax onward, so the pair reads `mov %r12,%rax ; mov %rax,%r9` where one instruction does it and
;; leaves rax alone (C-153 counted it in `loopsum`). Source rbx/r12/r13, destination r8..r11.
(:wat::core::defn :c::reg-to-scr [lr <- :wat::core::i64 r <- :wat::core::i64] -> :wat::core::String
  (:c::mov-rr lr (:c::scr-reg r)))

;; the register a tracked NAME lives in, or -1 -- including for the empty name, which is what
;; `:c::Out/rax` holds when it knows nothing
(:wat::core::defn :c::reg-of-name [name <- :wat::core::String env <- :c::Env] -> :wat::core::i64
  (:wat::core::if (:wat::core::= name "") -1
    (:c::lookup-reg env name (:wat::core::- (:wat::core::length env) 1))))

(:wat::core::defn :c::scr-back [r <- :wat::core::i64] -> :wat::core::String
  (:c::mov-rr (:c::scr-reg r) (:c::rax)))

;; rax = rN OP rax, where rN holds the left operand
(:wat::core::defn :c::scr-op [op <- :wat::core::String r <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [sr (:c::scr-reg r)]
    (:wat::core::cond
      ((:wat::core::= op "+") (:c::add-rr sr (:c::rax)))
      ((:wat::core::= op "*") (:c::imul-rr sr (:c::rax)))
      ;; **subtraction is not commutative, so it runs backwards and comes home.** The scratch
      ;; register is the left operand, so `rax - scr` would be the wrong way round: subtract INTO
      ;; the scratch and move the answer back.
      ((:wat::core::= op "-")
        (:wat::string::concat (:c::sub-rr (:c::rax) sr) (:c::scr-back r)))
      ;; and the compare goes the other way round for the same reason -- `scr - rax`
      ((:c::cmp? op)
        (:wat::string::concat (:c::cmp-rr (:c::rax) sr) (:c::setcc op) "480fb6c0"))
      (:else ""))))

;; the heads that emit no call and leave r8-r11 alone
(:wat::core::defn :c::quiet-head? [h <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:c::cmp? (:c::binop h))
    (:wat::core::or (:wat::core::not= (:c::binop h) "")
      (:wat::core::or (:c::if? h) (:wat::core::or (:c::cond? h)
        (:wat::core::or (:c::and? h) (:wat::core::or (:c::or? h)
          (:wat::core::or (:wat::core::or (:c::not? h) (:c::bit-not? h)) (:wat::core::or (:c::do? h)
            (:wat::core::or (:c::let? h) (:wat::core::or (:c::nth? h)
              (:wat::core::or (:c::len? h) (:wat::core::or (:c::strlen? h)
                (:wat::core::or (:c::codeat? h) (:c::peek? h)))))))))))))))

(:wat::core::defn :c::scratch-safe? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::cond
      ;; a leaf emits nothing
      ((:wat::core::= (:wat::core::length ks) 0) (:wat::core::not= (:c::kind a pg) "list"))
      ;; **a node with kids that is not a list is still a node with kids** -- a `let`'s binding
      ;; VECTOR is one, and keying this on "list" meant its initialisers were never looked at.
      ;; An initialiser holding a call was judged quiet, and the call then clobbered whichever
      ;; of r8-r11 the enclosing expression was holding a value in. Nothing reached that shape
      ;; until inlining turned every small call into a `let` in operand position.
      ((:wat::core::not= (:c::kind a pg) "list") (:c::all-safe? ks 0 env pg))
      (:else
        (:wat::core::let [h (:c::text pg (:wat::core::nth ks 0))]
          (:wat::core::and (:c::quiet-head? h)
            (:wat::core::and (:c::word-cmp? h ks env pg)
                             (:c::all-safe? ks 1 env pg))))))))

;; `=` and `not=` compile to a machine-word compare, or to a call into `str_eq` -- and which one
;; is a question the type pass can answer, exactly as it does for the `if` condition in
;; `:c::cmp-cond`. Everything else on the whitelist is a word compare by construction.
(:wat::core::defn :c::word-cmp? [h <- :wat::core::String ks <- :c::Kids env <- :c::Env
                                 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::let [op (:c::binop h)]
    (:wat::core::if (:wat::core::and (:wat::core::not= op "=") (:wat::core::not= op "not=")) true
      (:wat::core::and (:wat::core::= (:wat::core::length ks) 3)
        (:wat::core::and
          (:wat::core::not (:c::ptr-ty? (:c::type-of (:wat::core::nth ks 1) env pg)))
          (:wat::core::not (:c::ptr-ty? (:c::type-of (:wat::core::nth ks 2) env pg))))))))

(:wat::core::defn :c::all-safe? [ks <- :c::Kids i <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) true
    (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks i) env pg)
                     (:c::all-safe? ks (:wat::core::+ i 1) env pg))))

;; how many of r8..r11 evaluating this subtree will use
(:wat::core::defn :c::scratch-need [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::and (:wat::core::not= (:c::kind a pg) "list")
                                   (:wat::core::= (:wat::core::length (:c::kidsof pg a)) 0)) 0
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) 0
        (:wat::core::let [op (:wat::core::if (:wat::core::= (:c::kind a pg) "list")
                               (:c::binop (:c::text pg (:wat::core::nth ks 0))) "")]
          (:wat::core::if (:wat::core::or (:wat::core::= op "") (:wat::core::= op "quot"))
            (:c::need-max ks 0 env pg 0)
            (:wat::core::if (:wat::core::= op "rem") (:c::need-max ks 0 env pg 0)
              (:c::need-fold ks 2 env pg
                (:c::scratch-need (:wat::core::nth ks 1) env pg)))))))))

(:wat::core::defn :c::need-max [ks <- :c::Kids i <- :wat::core::i64 env <- :c::Env
                                pg <- :c::Prog best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:c::need-max ks (:wat::core::+ i 1) env pg
      (:c::imax best (:c::scratch-need (:wat::core::nth ks i) env pg)))))

(:wat::core::defn :c::need-fold [ks <- :c::Kids i <- :wat::core::i64 env <- :c::Env
                                 pg <- :c::Prog best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:wat::core::let [r (:c::scratch-need (:wat::core::nth ks i) env pg)
                      use? (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks i) env pg)
                                            (:wat::core::< r (:c::Prog/nscr pg)))]
      (:c::need-fold ks (:wat::core::+ i 1) env pg
        (:c::imax best (:wat::core::if use? (:wat::core::+ r 1) r))))))

;; ---------------------------------------------------------------- the direct operand
;;
;; `(wat.core/- n 1)` used to be six instructions -- push rax, load 1, mov rcx, pop rax, sub --
;; because a compiler with no register allocator keeps everything in rax and the stack. But x86
;; will take the right-hand operand straight from an immediate or from memory, and the two
;; shapes that matter are exactly the two a program writes most: a constant, and a name.
;;
;; So when the right operand is an int literal that fits in 32 bits, or a variable in the frame,
;; the whole sequence collapses to ONE instruction. Everything else still goes the long way.
;;
;; `quot` and `rem` are excluded because `idiv` wants its divisor in rcx anyway, and a comparison
;; keeps its `setcc`/`movzx` tail -- only the compare itself gets shorter.

(:wat::core::defn :c::imm-only [op <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::core::cond
      ((:wat::core::= op "+")
        (:wat::core::if short? (:wat::string::concat "4883c0" (:asm::le n 1))
                               (:wat::string::concat "4805" (:asm::le n 4))))
      ((:wat::core::= op "-")
        (:wat::core::if short? (:wat::string::concat "4883e8" (:asm::le n 1))
                               (:wat::string::concat "482d" (:asm::le n 4))))
      ((:wat::core::= op "*")
        (:wat::core::if short? (:wat::string::concat "486bc0" (:asm::le n 1))
                               (:wat::string::concat "4869c0" (:asm::le n 4))))
      ((:c::cmp? op)
        (:wat::core::if short? (:wat::string::concat "4883f8" (:asm::le n 1))
                               (:wat::string::concat "483d" (:asm::le n 4))))
      ;; the imm32 forms take rax as their implicit destination, so there is no ModRM byte
      ((:wat::core::= op "bit-and") (:wat::string::concat "4825" (:asm::le n 4)))
      ((:wat::core::= op "bit-or") (:wat::string::concat "480d" (:asm::le n 4)))
      ((:wat::core::= op "bit-xor") (:wat::string::concat "4835" (:asm::le n 4)))
      ;; **a shift by a literal takes an 8-BIT count, not a 32-bit one.** Outside 0..63 this
      ;; declines and the general path emits the `cl` form, which masks -- so the answer is the
      ;; same either way and only the encoding differs.
      ((:wat::core::and (:c::shift-op? op)
                        (:wat::core::and (:wat::core::>= n 0) (:wat::core::<= n 63)))
        (:wat::string::concat
          (:wat::core::cond ((:wat::core::= op "shl") "48c1e0")
                            ((:wat::core::= op "sar") "48c1f8")
                            (:else "48c1e8"))
          (:asm::le n 1)))
      (:else ""))))

(:wat::core::defn :c::imm-op [op <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [c (:c::imm-only op n)]
    (:wat::core::if (:wat::core::= c "") ""
      (:wat::core::if (:c::cmp? op) (:wat::string::concat c (:c::setcc op) "480fb6c0") c))))

(:wat::core::defn :c::mem-only [op <- :wat::core::String d <- :wat::core::i64
                                fp? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= op "+") (:c::at-frame fp? "480345" "480385" "48034424" "48038424" d))
    ((:wat::core::= op "-") (:c::at-frame fp? "482b45" "482b85" "482b4424" "482b8424" d))
    ((:wat::core::= op "*")
      (:c::at-frame fp? "480faf45" "480faf85" "480faf4424" "480faf8424" d))
    ((:c::cmp? op) (:c::at-frame fp? "483b45" "483b85" "483b4424" "483b8424" d))
    (:else "")))

(:wat::core::defn :c::mem-op [op <- :wat::core::String d <- :wat::core::i64
                              fp? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::let [c (:c::mem-only op d fp?)]
    (:wat::core::if (:wat::core::= c "") ""
      (:wat::core::if (:c::cmp? op) (:wat::string::concat c (:c::setcc op) "480fb6c0") c))))

;; the one instruction this operand collapses to, or "" if it does not
(:wat::core::defn :c::direct [op <- :wat::core::String a <- :wat::core::i64 env <- :c::Env
                              pg <- :c::Prog adj <- :wat::core::i64
                              fp? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "int")
        (:wat::core::let [n (:c::to-int (:c::text pg a) pg)]
          (:wat::core::if (:c::imm32? n) (:c::imm-op op n) "")))
      ((:wat::core::= k "symbol")
        (:wat::core::let [r (:c::lookup-reg env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))
                          d (:c::lookup env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))]
          (:wat::core::cond
            ((:wat::core::>= r 0)
              (:wat::core::let [c (:c::reg-op op r)]
                (:wat::core::if (:wat::core::= c "") ""
                  (:wat::core::if (:c::cmp? op) (:wat::string::concat c (:c::setcc op) "480fb6c0") c))))
            ((:wat::core::= d 999999) "")
            (:else (:c::mem-op op (:c::fp-at d adj fp?) fp?)))))
      (:else ""))))

;; left fold: the first argument lands in rax, and each one after it either collapses to a
;; single instruction or is pushed, computed and popped back
;; **i64 traps, so the compiled language must trap too.** `add`, `sub` and `imul` set the
;; overflow flag; `jo` to the handler costs six bytes at each site and a branch that is never
;; taken. Before this, `(+ 9223372036854775807 1)` printed -9223372036854775808 and exited 0
;; where the interpreter died with `IntegerOverflow` -- a wrong answer, not a refusal (F-125).
;; `quot` and `rem` are not here: idiv faults on MIN/-1 rather than setting a flag, which is a
;; different mechanism and a separate fix.
(:wat::core::defn :c::ovf? [op <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= op "+")
    (:wat::core::or (:wat::core::= op "-") (:wat::core::= op "*"))))

;; **a division is a CALL**, because `idiv` faults rather than setting a flag: the divisor has
;; to be tested before the instruction runs, and seven inline instructions at every site is a
;; poor trade for something this rare. `:c::op-hex` still carries the bare `cqo; idiv` forms and
;; nothing reaches them -- the only other caller passes "=".
(:wat::core::defn :c::arith-emit [op <- :wat::core::String o <- :c::Out
                                  rt <- :c::Layout dead? <- :wat::core::bool] -> :c::Out
  (:wat::core::cond
    ((:wat::core::= op "quot") (:c::call o (:c::at-quot rt)))
    ((:wat::core::= op "rem") (:c::call o (:c::at-rem rt)))
    (:else (:c::ovf-check op (:c::emit o (:c::op-hex op)) rt dead?))))

(:wat::core::defn :c::ovf-check [op <- :wat::core::String o <- :c::Out
                                 rt <- :c::Layout dead? <- :wat::core::bool] -> :c::Out
  (:wat::core::if (:wat::core::or dead? (:wat::core::not (:c::ovf? op))) o
    (:c::emit o (:wat::string::concat "0f80"
      (:asm::le (:wat::core::- (:c::at-ovf rt)
                  (:wat::core::+ (:c::here o) 6)) 4)))))

;; **`ar` is the register the accumulator is still sitting in, or -1 for "it is in rax".**
;; The first operand used to be materialised into rax before the fold began, and the scratch
;; path's very next instruction copied rax onward -- `mov %r12,%rax ; mov %rax,%r9`. Copying
;; from the source instead only turned the first of those into a DEAD load, because the caller
;; had already emitted it. So the caller stops emitting it and hands the register down; the two
;; paths that genuinely need rax load it themselves, which is one instruction in exactly the
;; cases that need one. After the first operand is consumed the accumulator is in rax and `ar`
;; is -1 forever after.
(:wat::core::defn :c::fold [op <- :wat::core::String ks <- :c::Kids i <- :wat::core::i64
                            o <- :c::Out env <- :c::Env pg <- :c::Prog
                            rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64
                            ar <- :wat::core::i64 ab <- :c::Bnd] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks))
    ;; a one-operand fold never ran a step, so the value is still where it started
    (:wat::core::if (:wat::core::>= ar 0) (:c::emit o (:c::reg-mov-to ar)) o)
    (:wat::core::let [;; **`ab` is what the value accumulated so far can be**, and `ob` what this
                      ;; operand can be. The check this step would emit is dead exactly when the
                      ;; two bounds cannot leave i64 -- asked once here and honoured by all four
                      ;; paths below, because it is a fact about the operands and not about which
                      ;; register they happened to land in.
                      ob (:c::bnd-expr (:wat::core::nth ks i) pg (:c::Prog/bnds pg))
                      dead? (:c::op-safe? op ab ob)
                      ab2 (:wat::core::cond
                            ((:wat::core::= op "+") (:c::bnd-add ab ob))
                            ((:wat::core::= op "-") (:c::bnd-sub ab ob))
                            ((:wat::core::= op "*") (:c::bnd-mul ab ob))
                            (:else (:c::bnd-any)))
                      fast (:c::direct op (:wat::core::nth ks i) env pg
                             (:c::fp-adj o) (:c::Out/fpr o))
                      r (:c::scratch-need (:wat::core::nth ks i) env pg)
                      scr? (:wat::core::and (:wat::core::= fast "")
                             (:wat::core::and (:wat::core::not= (:c::scr-op op 0) "")
                               (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks i) env pg)
                                                (:wat::core::< r (:c::Prog/nscr pg)))))]
      (:wat::core::cond
        ((:wat::core::not= fast "")
          (:wat::core::let
            [;; a register times a literal is one instruction, and the accumulator never has to
             ;; visit rax to get there
             three (:wat::core::if
                     (:wat::core::and (:wat::core::>= ar 0)
                       (:wat::core::and (:wat::core::= op "*")
                                        (:c::imm-cmp? (:wat::core::nth ks i) pg)))
                     (:c::imul3 ar (:c::to-int (:c::text pg (:wat::core::nth ks i)) pg)
                       (:c::rax)) "")
             o0 (:wat::core::if (:wat::core::not= three "") o
                  (:wat::core::if (:wat::core::>= ar 0) (:c::emit o (:c::reg-mov-to ar)) o))
             o1 (:c::emit o0 (:wat::core::if (:wat::core::not= three "") three fast))]
            (:c::fold op ks (:wat::core::+ i 1)
              (:c::ovf-check op o1 rt dead?) env pg rt tb slot -1 ab2)))
        ;; **an accumulator in a CALLEE-SAVED register does not have to wait anywhere.** rbx,
        ;; r12, r13 and rbp survive a call because every callee this compiler emits pushes and
        ;; pops the ones it uses -- so the operand can be evaluated straight into rax and the
        ;; accumulator added from where it already is. That is one instruction where the scratch
        ;; path needs two (`mov %r12,%r9` ... `add %r9,%rax`) and the stack path needs three.
        ;; Commutative only: `add %r12,%rax` puts the sum in rax whichever side each came from,
        ;; and for `-` that would be the wrong answer rather than a slower one.
        ((:wat::core::and (:c::comm-op? op) (:wat::core::>= ar 0))
          (:wat::core::let
            [s2 (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))
             s3 (:c::emit s2 (:c::reg-op op ar))]
            (:c::fold op ks (:wat::core::+ i 1) (:c::ovf-check op s3 rt dead?)
              env pg rt tb slot -1 ab2)))
        ;; the accumulator waits in a register instead of on the stack
        (scr?
          (:wat::core::let
            [lr (:wat::core::if (:wat::core::>= ar 0) ar
                  (:c::reg-of-name (:c::Out/rax o) env))
             s1 (:wat::core::cond
                  ;; never loaded into rax at all: copy straight from the parameter's register
                  ((:wat::core::>= ar 0) (:c::emit o (:c::reg-to-scr lr r)))
                  ;; rax was copied out of a register and nothing has been emitted since, so the
                  ;; scratch copy comes from the SOURCE and rax keeps its value -- which is why
                  ;; the tracking is put back rather than cleared
                  ((:wat::core::>= lr 0)
                    (:wat::core::assoc (:c::emit o (:c::reg-to-scr lr r)) :rax (:c::Out/rax o)))
                  (:else (:c::emit o (:c::scr-save r))))
             s2 (:c::expr (:wat::core::nth ks i) s1 env pg rt tb slot (:c::no-tail))]
            (:c::fold op ks (:wat::core::+ i 1)
              (:c::ovf-check op (:c::emit s2 (:c::scr-op op r)) rt dead?)
              env pg rt tb slot -1 ab2)))
        (:else
          (:wat::core::let
          [o0 (:wat::core::if (:wat::core::>= ar 0) (:c::emit o (:c::reg-mov-to ar)) o)
           o1 (:c::push o0 (:c::push-rax) 8)                            ;; push rax
           o2 (:c::expr (:wat::core::nth ks i) o1 env pg rt tb slot (:c::no-tail))
           ;; **`+` and `*` do not care which side they came from**, so the accumulator can be
           ;; popped straight into rcx: `pop rcx ; add rcx,rax` is what `mov rcx,rax ; pop rax ;
           ;; add rcx,rax` was doing in three instructions instead of two. `-`, `quot` and `rem`
           ;; keep the long form, because for them the order is the answer. The profile of
           ;; `fib(32)` put this sequence at 15% of its cycles: it is how the two halves of
           ;; `(+ (fib (- n 1)) (fib (- n 2)))` are brought together, once per invocation.
           comm? (:wat::core::or (:wat::core::= op "+") (:wat::core::= op "*"))
           o4 (:wat::core::if comm?
                (:c::popn o2 (:c::pop-rcx) 8)                          ;; pop rcx
                (:c::popn (:c::emit o2 "4889c1") (:c::pop-rax) 8))     ;; mov rcx, rax ; pop rax
           o5 (:c::arith-emit op o4 rt dead?)]
          (:c::fold op ks (:wat::core::+ i 1) o5 env pg rt tb slot -1 ab2)))))))

;; **an operand that can be RE-MATERIALIZED does not have to be spilled.** The two-operand
;; forms evaluate the first operand into rax, push it, evaluate the second, and pop -- three
;; instructions and a memory round trip to protect a value that, when it lives in one of the
;; four callee-saved registers, nothing in between can touch. Our own callees save those four
;; and so do the runtime routines that use them as scratch, which is the whole reason
;; parameters live there. `assoc`'s receiver in `elf/bench/rec.wat` was the visible case:
;; `mov %rbx,%rax ; push %rax ; mov %rbx,%rax` spilled rbx and reloaded rbx on the very next
;; instruction. C-179.
(:wat::core::defn :c::remat? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:c::kind a pg) "symbol")
                   (:wat::core::>= (:c::reg-of a env pg) 0)))

;; **an operand with a home of its own does not have to displace the accumulator.**
;; `cat-fold` brackets every right-hand operand with `push rax ... mov rax,rcx ; pop rax` --
;; four instructions of protocol so that the accumulator in rax survives evaluating the
;; operand. A string literal is a `movabs` and a parameter in a register is a `mov`; neither
;; passes through rax on its way to rcx, so for those the protocol IS the whole cost. F-144
;; found three of the seventeen instructions in `strbuild`'s loop were exactly this.
(:wat::core::defn :c::rcx-direct? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "string") true)
    ((:wat::core::= (:c::kind a pg) "symbol") (:wat::core::>= (:c::reg-of a env pg) 0))
    (:else false)))

(:wat::core::defn :c::rcx-direct [a <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                  pg <- :c::Prog tb <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::= (:c::kind a pg) "string") (:c::str-lit a o tb pg (:c::rcx))
    (:c::emit o (:c::mov-rr (:c::reg-of a env pg) (:c::rcx)))))

;; the same shape, with a call where the arithmetic fold has an instruction
(:wat::core::defn :c::cat-fold [ks <- :c::Kids i <- :wat::core::i64
                                o <- :c::Out env <- :c::Env pg <- :c::Prog
                                rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64
                                own? <- :wat::core::bool] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:wat::core::let
      [direct? (:c::rcx-direct? (:wat::core::nth ks i) env pg)
       o1 (:wat::core::if direct? o (:c::push o (:c::push-rax) 8))      ;; push rax
       o2 (:wat::core::if direct? (:c::rcx-direct (:wat::core::nth ks i) o1 env pg tb)
            (:c::expr (:wat::core::nth ks i) o1 env pg rt tb slot (:c::no-tail)))
       o3 (:wat::core::if direct? o2 (:c::emit o2 "4889c1"))  ;; mov rcx, rax
       o4 (:wat::core::if direct? o3 (:c::popn o3 (:c::pop-rax) 8))     ;; pop rax
       o5 (:c::call o4 (:wat::core::if own? (:c::at-cat-own rt) (:c::at-cat rt)))]
      ;; after the first step the accumulator is a temporary this expression made, so nothing
      ;; else can be holding it and every later step may extend in place
      (:c::cat-fold ks (:wat::core::+ i 1) o5 env pg rt tb slot true))))

;; ---------------------------------------------------------------- if

;; ---------------------------------------------------------------- branching on the flags
;;
;; `(if (< n 2) ...)` used to compute the comparison into rax -- `cmp`, `setcc`, `movzx` -- and
;; then throw that away again with `test rax,rax` and a `jz`. Five instructions to reach a branch
;; the `cmp` had already decided.
;;
;; A comparison in the condition of an `if` now branches on the flags directly: the compare, and
;; the OPPOSITE jump to the else. Everything else still goes through rax, because a condition that
;; is not a comparison really does need a value to test.

(:wat::core::defn :c::jcc-not [op <- :wat::core::String] -> :wat::core::String
  (:c::jcc-rel32 (:c::negate-cc (:c::cond-code op))))

;; the compare alone, with no setcc tail, when the right operand is an immediate or a name
;; the type of the first operand of this form that lives on the heap, or "" if none does --
;; which is both the test and the diagnostic, so the message names the operand that is wrong
;; rather than the one that happened to be first
(:wat::core::defn :c::ptr-among [ks <- :c::Kids i <- :wat::core::i64 env <- :c::Env
                                 pg <- :c::Prog] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) ""
    (:wat::core::let [t (:c::type-of (:wat::core::nth ks i) env pg)]
      (:wat::core::if (:c::ptr-ty? t) t (:c::ptr-among ks (:wat::core::+ i 1) env pg)))))

(:wat::core::defn :c::cmp-only [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog
                                adj <- :wat::core::i64
                                fp? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "int")
        (:wat::core::let [n (:c::to-int (:c::text pg a) pg)]
          (:wat::core::if (:c::imm32? n) (:c::imm-only "=" n) "")))
      ((:wat::core::= k "symbol")
        (:wat::core::let [r (:c::lookup-reg env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))
                          d (:c::lookup env (:c::text pg a) (:wat::core::- (:wat::core::length env) 1))]
          (:wat::core::cond
            ((:wat::core::>= r 0) (:c::reg-op "=" r))
            ((:wat::core::= d 999999) "")
            (:else (:c::mem-only "=" (:c::fp-at d adj fp?) fp?)))))
      (:else ""))))

;; Is this condition a two-operand comparison of MACHINE WORDS, and therefore branchable?
;;
;; The type test is the whole point. `(if (wat.core/not= fast "") ...)` is a comparison by
;; spelling and a `str_eq` call by meaning -- branching on `cmp rax, <address>` would compare
;; pointers and answer "not equal" for two equal strings. That is F-120's cousin one more time,
;; and it is how this optimisation announced itself: the compiler stopped recognising its own
;; `defn`s the first time it compiled itself.
(:wat::core::defn :c::cmp-cond [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::String
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") ""
    (:wat::core::let [cks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::not= (:wat::core::length cks) 3) ""
        (:wat::core::let [op (:c::binop (:c::text pg (:wat::core::nth cks 0)))]
          (:wat::core::if (:wat::core::not (:c::cmp? op)) ""
            (:wat::core::if (:wat::core::or
                              (:c::ptr-ty? (:c::type-of (:wat::core::nth cks 1) env pg))
                              (:c::ptr-ty? (:c::type-of (:wat::core::nth cks 2) env pg)))
              "" op)))))))

;; **A branch over a tiny arm fits in two bytes instead of six**, and the arm is tiny exactly
;; when it is a name or a constant: a symbol costs at most an eight-byte load, a literal at most
;; a ten-byte `mov`, and the `jmp` after it is five. Fifteen bytes, comfortably inside the 127 a
;; `rel8` reaches -- so the encoding can be chosen when the branch is EMITTED, with no measuring
;; pass and no guess. `(if (< n 2) n ...)` is that shape, and so is every base case in the corpus.
(:wat::core::defn :c::tiny-arm? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::or (:wat::core::= k "symbol")
      (:wat::core::or (:wat::core::= k "int")
        (:wat::core::or (:wat::core::= k "bool") (:wat::core::= k "nil"))))))

;; the short form of a conditional branch: one opcode byte, one displacement byte
(:wat::core::defn :c::jcc-not8 [op <- :wat::core::String] -> :wat::core::String
  (:c::jcc-rel8 (:c::negate-cc (:c::cond-code op))))

;; **the branch taken when the condition HOLDS**, which is the one an `if` wants when its THEN
;; arm has nothing to emit: the branch over the arm and the jump to the join are then the same
;; jump, and two instructions collapse into one. See `:c::if-cmp`.
(:wat::core::defn :c::cond-code [op <- :wat::core::String] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= op "=") 4) ((:wat::core::= op "not=") 5)
    ((:wat::core::= op "<") 12) ((:wat::core::= op ">=") 13)
    ((:wat::core::= op "<=") 14) (:else 15)))

(:wat::core::defn :c::jcc [op <- :wat::core::String] -> :wat::core::String
  (:c::jcc-rel32 (:c::cond-code op)))

(:wat::core::defn :c::jcc8 [op <- :wat::core::String] -> :wat::core::String
  (:c::jcc-rel8 (:c::cond-code op)))

;; **an arm that emits nothing is an arm whose value is already in rax.** C-149 tracks what rax
;; holds by name and the compare does not disturb it, so this is knowable BEFORE the branch is
;; emitted -- which is what lets the branch be chosen rather than patched afterwards. In `fib`
;; it is 45 of the 99 conditional branches in the binary: every `(if (< n 2) n ...)` compares
;; `n` and then jumps over an arm that would have re-loaded the register it just compared.
(:wat::core::defn :c::arm-free? [a <- :wat::core::i64 kept <- :wat::core::String
                                 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::and (:wat::core::not= kept "")
    (:wat::core::and (:wat::core::= (:c::kind a pg) "symbol")
                     (:wat::core::= (:c::text pg a) kept))))

(:wat::core::defn :c::if-cmp [ks <- :c::Kids op <- :wat::core::String o <- :c::Out env <- :c::Env
                              pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                              slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::let
    [cks (:c::kidsof pg (:wat::core::nth ks 1))
     ;; **both operands in place: nothing is loaded at all.** A register on the left and a
     ;; literal on the right is one instruction, and rax keeps whatever it was holding -- which
     ;; the `o3k`/`o6k` restores below then carry into both arms, exactly as they already do for
     ;; the right-operand fast path.
     ;;
     ;; **A register on BOTH sides is the same one instruction**, and it is the shape every
     ;; counted loop ends with: `(= i n)` on two parameters. Until C-181 only the literal case
     ;; was taken, so `(= i n)` paid `mov %r12,%rax ; cmp %r13,%rax` to say `cmp %r13,%r12`.
     ;; The operand roles are identical -- left minus right -- so the condition codes below
     ;; need no adjusting.
     lr (:c::reg-of (:wat::core::nth cks 1) env pg)
     rr (:c::reg-of (:wat::core::nth cks 2) env pg)
     both? (:wat::core::and (:wat::core::>= lr 0)
             (:wat::core::or (:c::imm-cmp? (:wat::core::nth cks 2) pg) (:wat::core::>= rr 0)))
     o1 (:wat::core::if both? o
          (:c::expr (:wat::core::nth cks 1) o env pg rt tb slot (:c::no-tail)))
     fast (:wat::core::if both?
            (:wat::core::if (:wat::core::>= rr 0) (:c::cmp-rr rr lr)
              (:c::reg-cmp-imm lr (:c::to-int (:c::text pg (:wat::core::nth cks 2)) pg)))
            (:c::cmp-only (:wat::core::nth cks 2) env pg (:c::fp-adj o1) (:c::Out/fpr o1)))
     o2 (:wat::core::if (:wat::core::not= fast "") (:c::emit o1 fast)
          (:wat::core::let
            [p1 (:c::push o1 (:c::push-rax) 8)
             p2 (:c::expr (:wat::core::nth cks 2) p1 env pg rt tb slot (:c::no-tail))]
            (:c::popn p2 (:wat::string::concat "4889c1" (:c::pop-rax) "4839c8") 8)))
     ;; **what rax will still hold on both arms**, or "" when the general path destroyed it
     kept (:wat::core::if (:wat::core::not= fast "") (:c::Out/rax o1) "")
     ;; **an arm that emits nothing does not need a branch over it.** With the THEN arm empty,
     ;; the branch over it and the jump to the join are the same jump, so the branch is taken
     ;; when the condition HOLDS and goes straight to the join -- one instruction instead of
     ;; two, and on the other path a taken branch becomes a fall-through. With the ELSE arm
     ;; empty it is the `jmp` that goes: it would jump zero bytes.
     then0? (:c::arm-free? (:wat::core::nth ks 2) kept pg)
     else0? (:wat::core::and (:wat::core::not then0?)
                             (:c::arm-free? (:wat::core::nth ks 3) kept pg))
     ;; the arm this branch jumps over is a name or a constant, so it and the `jmp` after it
     ;; come to at most fifteen bytes -- a displacement that fits in one. When the THEN arm is
     ;; the empty one the branch clears the ELSE arm instead, so that is the one to measure.
     short? (:c::tiny-arm? (:wat::core::nth ks (:wat::core::if then0? 3 2)) pg)
     w (:wat::core::if short? 1 4)
     o3 (:c::emit o2
          (:wat::core::if then0?
            (:wat::core::if short? (:wat::string::concat (:c::jcc8 op) "00")
                                   (:wat::string::concat (:c::jcc op) "00000000"))
            (:wat::core::if short? (:wat::string::concat (:c::jcc-not8 op) "00")
                                   (:wat::string::concat (:c::jcc-not op) "00000000"))))
     ;; **neither the compare nor the branch writes rax**, so whatever it held before them it
     ;; still holds on BOTH arms -- the fall-through and the jump alike, which is what makes
     ;; this sound rather than merely true on one path. Only when the right operand compiled to
     ;; a bare compare: the general path pushes and evaluates into rax, which destroys it.
     ;; Without this, every inlined `if` reloaded a value already sitting in the register.
     o3k (:wat::core::if (:wat::core::not= fast "")
           (:wat::core::assoc o3 :rax (:c::Out/rax o1)) o3)
     at (:wat::core::- (:c::codelen o3k) w)
     o4 (:c::expr (:wat::core::nth ks 2) o3k env
          (:wat::core::assoc pg :bnds (:c::bnds-arm cks op true pg (:c::Prog/bnds pg)))
          rt tb slot tc)
     o5 (:wat::core::if (:wat::core::or then0? else0?) o4 (:c::emit o4 (:c::jmp-unpatched)))
     jmp-at (:wat::core::- (:c::codelen o5) 4)
     ;; the branch points AT the else arm -- unless it is the jump to the join, in which case it
     ;; has to clear the else arm as well and is patched after it instead
     o6 (:wat::core::if then0? o5
          (:c::patch o5 at (:asm::le (:wat::core::- (:c::codelen o5) (:wat::core::+ at w)) w)))
     ;; that patch pointed the branch AT the else arm; it is not a join. The else arm has
     ;; exactly one predecessor -- the branch itself -- so it inherits what rax held there,
     ;; the same as the fall-through did. (`:c::patch` clears conservatively because most of
     ;; its uses ARE joins; this is the one place that knows better.)
     o6k (:wat::core::if (:wat::core::not= fast "")
           (:wat::core::assoc o6 :rax (:c::Out/rax o1)) o6)
     ;; **the else arm can close the loop itself** (C-188). `fast` is the whole test when
     ;; both operands were already in place -- nothing was emitted for the left one -- so it
     ;; is safe to emit again at the bottom. `:c::here o6k` is where the else arm starts,
     ;; which is exactly where a back edge wants to land.
     ;; **only the `if` that IS the loop head may do this.** `if-cmp` runs for every `if` in
     ;; the function, and handing the test down unconditionally gave any tail call nested in
     ;; an inner `if`'s else arm a back edge to THAT arm instead of the function body -- a
     ;; loop with no exit. Stage 1 hung for twelve minutes on it. The head is the `if` that
     ;; begins the body, so its address is exactly where the back edge already went.
     tc2 (:wat::core::if
           (:wat::core::and (:wat::core::= (:c::here o) (:c::TC/target tc))
             (:wat::core::and (:wat::core::not= fast "")
               (:wat::core::not (:wat::core::or then0? else0?))))
           (:wat::core::assoc (:wat::core::assoc tc :test
             (:wat::string::concat fast (:c::jcc-not op))) :body (:c::here o6k))
           tc)
     o7 (:c::expr (:wat::core::nth ks 3) o6k env
          (:wat::core::assoc pg :bnds (:c::bnds-arm cks op false pg (:c::Prog/bnds pg)))
          rt tb slot tc2)
     o8 (:wat::core::if then0?
          (:c::patch o7 at (:asm::le (:wat::core::- (:c::codelen o7) (:wat::core::+ at w)) w))
          o7)]
    (:wat::core::if (:wat::core::or then0? else0?) o8
      (:c::patch o8 jmp-at (:asm::le (:wat::core::- (:c::codelen o8) (:wat::core::+ jmp-at 4)) 4)))))

(:wat::core::defn :c::if-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                               rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::length ks) 4) (:c::fail "if arity" a pg)
    (:wat::core::let [cop (:c::cmp-cond (:wat::core::nth ks 1) env pg)]
     (:wat::core::if (:wat::core::not= cop "")
      (:c::if-cmp ks cop o env pg rt tb slot tc)
      (:wat::core::let
       [o1 (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
        o2 (:c::emit o1 "4885c0")                      ;; test rax, rax
        o3 (:c::emit o2 "0f8400000000")                ;; jz <patched below>
        jz-at (:wat::core::- (:c::codelen o3) 4)
        o4 (:c::expr (:wat::core::nth ks 2) o3 env pg rt tb slot tc)
        o5 (:c::emit o4 (:c::jmp-unpatched))                  ;; jmp <patched below>
        jmp-at (:wat::core::- (:c::codelen o5) 4)
        o6 (:c::patch o5 jz-at (:asm::le (:wat::core::- (:c::codelen o5) (:wat::core::+ jz-at 4)) 4))
        o7 (:c::expr (:wat::core::nth ks 3) o6 env pg rt tb slot tc)]
       (:c::patch o7 jmp-at (:asm::le (:wat::core::- (:c::codelen o7) (:wat::core::+ jmp-at 4)) 4)))))))

;; ---------------------------------------------------------------- last use
;;
;; **A reference count of 1 is not enough to mutate in place, and that is the trap.** In
;; `(do (conj acc 1) (nth acc 0))` the slot holding `acc` is the only reference -- count 1 -- and
;; mutating would still be wrong, because `conj` is pure and `acc` is read afterwards. Rust
;; escapes this because `v.push(x)` takes `&mut v`, which makes the old value unreachable by
;; construction; a pure `conj` has no such guarantee.
;;
;; So in-place needs two proofs: the count rules out ALIASES, and this rules out LATER READS.
;;
;; `:c::occ` counts how many times a name is read on the WORST path through a body -- the two
;; arms of an `if` are alternatives, so they are maxed rather than summed, while everything else
;; is sequential and sums. A parameter read at most once on every path is read at most once,
;; full stop, so any read of it is the last one. Over-counting is safe: it only declines the
;; optimisation.

(:wat::core::defn :c::occ [a <- :wat::core::i64 name <- :wat::core::String pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "symbol")
      (:wat::core::if (:wat::core::= (:c::text pg a) name) 1 0))
    ((:wat::core::= (:c::kind a pg) "vector") (:c::occ-sum (:c::kidsof pg a) 0 name 0 pg))
    ((:wat::core::not= (:c::kind a pg) "list") 0)
    (:else
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) 0
          (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))]
            (:wat::core::cond
              ;; the two arms of an `if` are alternatives: the worst path takes one of them
              ((:wat::core::and (:c::if? head) (:wat::core::= (:wat::core::length ks) 4))
                (:wat::core::+ (:c::occ (:wat::core::nth ks 1) name pg)
                  (:c::imax (:c::occ (:wat::core::nth ks 2) name pg)
                            (:c::occ (:wat::core::nth ks 3) name pg))))
              ;; a `cond` is the same idea, but every test up to the taken clause runs, so the
              ;; tests are summed and only the bodies are maxed -- an over-count, which is safe
              ((:c::cond? head)
                (:wat::core::+ (:c::occ-tests ks 1 name 0 pg) (:c::occ-bodies ks 1 name 0 pg)))
              (:else (:c::occ-sum ks 0 name 0 pg)))))))))

(:wat::core::defn :c::occ-sum [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                               acc <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:c::occ-sum ks (:wat::core::+ i 1) name
      (:wat::core::+ acc (:c::occ (:wat::core::nth ks i) name pg)) pg)))

(:wat::core::defn :c::occ-tests [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                 acc <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks i))]
      (:c::occ-tests ks (:wat::core::+ i 1) name
        (:wat::core::+ acc (:wat::core::if (:wat::core::= (:wat::core::length cks) 0) 0
                             (:c::occ (:wat::core::nth cks 0) name pg))) pg))))

(:wat::core::defn :c::occ-bodies [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                  best <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks i))]
      (:c::occ-bodies ks (:wat::core::+ i 1) name
        (:c::imax best (:c::occ-sum cks 1 name 0 pg)) pg))))

;; the parameters of this function that are read at most once on every path

;; ---------------------------------------------------------------- liveness, not mention-counting
;;
;; **The question ownership actually asks is "is anything going to READ this after I write it",
;; and counting mentions is not that question.** `(assoc s :a (+ (:St/a s) i))` names `s` twice,
;; but the field read is an ARGUMENT to the update: it finishes before the write begins and `s`
;; is dead afterwards. F-141 measured what the difference costs -- a String builder that is
;; linear with one mention cannot finish a problem a sixteenth the size with two.
;;
;; So: find the one place a name is written, and ask whether anything after it reads the name.
;; "After" is the subtlety -- the two arms of an `if` are ALTERNATIVES, not successors, and in
;; both measured cases the extra mentions live in an arm the write does not run with.
;;
;; Everything that is not an `if` is treated as sequential, which OVER-estimates liveness and so
;; is safe: it costs an optimisation, never a correctness.

;; is the node `u` somewhere inside the subtree `n`?
(:wat::core::defn :c::holds? [pg <- :c::Prog n <- :wat::core::i64 u <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::= n u) true
    (:wat::core::if (:wat::core::not= (:c::kind n pg) "list") false
      (:c::holds-any? pg (:c::kidsof pg n) 0 u))))
(:wat::core::defn :c::holds-any? [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                  u <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) false
    (:wat::core::if (:c::holds? pg (:wat::core::nth ks i) u) true
      (:c::holds-any? pg ks (:wat::core::+ i 1) u))))

;; does `name` get read anywhere that runs AFTER `u`, within the subtree `n`?
(:wat::core::defn :c::live-after [pg <- :c::Prog n <- :wat::core::i64 u <- :wat::core::i64
                                  name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= n u) false)
    ((:wat::core::not= (:c::kind n pg) "list") false)
    (:else
      (:wat::core::let [ks (:c::kidsof pg n)]
        (:wat::core::if (:wat::core::< (:wat::core::length ks) 4) (:c::live-seq pg ks 1 u name)
          (:wat::core::if (:wat::core::not (:c::if? (:c::text pg (:wat::core::nth ks 0))))
            (:c::live-seq pg ks 1 u name)
            ;; `(if cond then else)` -- from the CONDITION either arm may still run; from inside
            ;; an arm, the other one never does
            (:wat::core::cond
              ((:c::holds? pg (:wat::core::nth ks 1) u)
                (:wat::core::or (:c::live-after pg (:wat::core::nth ks 1) u name)
                  (:wat::core::> (:wat::core::+ (:c::occ (:wat::core::nth ks 2) name pg)
                                                (:c::occ (:wat::core::nth ks 3) name pg)) 0)))
              ((:c::holds? pg (:wat::core::nth ks 2) u)
                (:c::live-after pg (:wat::core::nth ks 2) u name))
              ((:c::holds? pg (:wat::core::nth ks 3) u)
                (:c::live-after pg (:wat::core::nth ks 3) u name))
              (:else false))))))))

;; children run left to right: whichever one holds `u`, everything to its right follows
(:wat::core::defn :c::live-seq [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                u <- :wat::core::i64 name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length ks)) false)
    ((:c::holds? pg (:wat::core::nth ks i) u)
      (:wat::core::or (:c::live-after pg (:wat::core::nth ks i) u name)
        (:wat::core::> (:c::occ-sum ks (:wat::core::+ i 1) name 0 pg) 0)))
    (:else (:c::live-seq pg ks (:wat::core::+ i 1) u name))))

;; where `name` is WRITTEN -- the receiver of an `assoc`, `conj` or `concat`. -1 for none, -2 for
;; more than one, because two writes to one name is a shape this does not reason about.
(:wat::core::defn :c::write-head? [h <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:c::assoc? h) (:wat::core::or (:c::conj? h) (:c::concat? h))))
(:wat::core::defn :c::mut-site [pg <- :c::Prog n <- :wat::core::i64 name <- :wat::core::String
                                acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::not= (:c::kind n pg) "list") acc
    (:wat::core::let
      [ks (:c::kidsof pg n)
       hit? (:wat::core::and (:wat::core::>= (:wat::core::length ks) 2)
              (:wat::core::and (:c::write-head? (:c::text pg (:wat::core::nth ks 0)))
                (:wat::core::and (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                  (:wat::core::= (:c::text pg (:wat::core::nth ks 1)) name))))
       acc1 (:wat::core::if hit?
              (:wat::core::if (:wat::core::= acc -1) n -2) acc)]
      (:c::mut-sites pg ks 0 name acc1))))
(:wat::core::defn :c::mut-sites [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                 name <- :wat::core::String acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:c::mut-sites pg ks (:wat::core::+ i 1) name (:c::mut-site pg (:wat::core::nth ks i) name acc))))

;; the whole question: exactly one write, and nothing reads it afterwards
(:wat::core::defn :c::dead-after-write? [pg <- :c::Prog ks <- :c::Kids start <- :wat::core::i64
                                         name <- :wat::core::String] -> :wat::core::bool
  (:wat::core::let [u (:c::mut-sites pg ks start name -1)]
    (:wat::core::and (:wat::core::>= u 0)
      (:wat::core::not (:c::live-seq pg ks start u name)))))

(:wat::core::defn :c::linear-of [pv <- :c::Kids i <- :wat::core::i64 ks <- :c::Kids
                                 start <- :wat::core::i64
                                 acc <- (:wat::core::Vector :- [:wat::core::String]) pg <- :c::Prog]
    -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:wat::core::length pv)) acc
    (:wat::core::let [nm (:c::text pg (:wat::core::nth pv i))]
      (:c::linear-of pv (:wat::core::+ i 3) ks start
        ;; the cheap case first -- one mention needs no analysis at all -- then the real
        ;; question, which is whether anything reads the name after it is written (F-141)
        (:wat::core::if (:wat::core::or (:wat::core::<= (:c::occ-sum ks start nm 0 pg) 1)
                                        (:c::dead-after-write? pg ks start nm))
          (:wat::core::conj acc nm) acc) pg))))

(:wat::core::defn :c::linear? [pg <- :c::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length (:c::Prog/linear pg))) false)
    ((:wat::core::= (:wat::core::nth (:c::Prog/linear pg) i) name) true)
    (:else (:c::linear? pg name (:wat::core::+ i 1)))))

;; A SYMBOL gets the two proofs above. A non-symbol operand used to get a sentence instead:
;; "a non-variable operand is a temporary and always qualifies". That is false, and C-140 wrote
;; it down twice as a limitation without fixing it.
;;
;; A field read is not a temporary. It is a BORROWED pointer into a container that is still
;; alive -- and its share count really is 1, because a fresh value stored into a container is
;; stored by MOVE: `:c::share` increments symbols only, which is exactly what makes the reader's
;; `(conj rows n)` chain cheap. So the runtime guard asks "count 1?", gets the truth, and draws
;; the wrong conclusion. `elf/src/strown.wat` is that in three shapes.
;;
;; What IS true of an operand is that it is fresh when whatever produced it allocated it. Three
;; verbs always do -- `concat`, `subs` and `i64/to-string` each write a new block and answer it,
;; on every path, with no early return of an argument. Everything else -- a field read, an `nth`,
;; a user call, an `if` -- can hand back something older than itself.
(:wat::core::defn :c::fresh-str? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) false
        (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))]
          (:wat::core::or (:c::concat? head) (:c::subs? head) (:c::tostr? head)))))))

;; a value that lives on the heap, and therefore one whose sharing has to be counted
(:wat::core::defn :c::ptr-ty? [t <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= t "str")
    (:wat::core::or (:wat::string::starts-with? t "vec:") (:wat::string::starts-with? t "rec:"))))

;; **the increment, and the only one there is.** A pointer read out of a variable and then stored
;; somewhere durable is now reachable twice, so the count goes up. It never comes down: this is
;; not reclamation, it is a "has this ever been shared?" flag that can only become more
;; conservative. A freshly computed value is not incremented -- the slot takes the count of 1
;; that the allocator already gave it.
(:wat::core::defn :c::share [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog o <- :c::Out] -> :c::Out
  (:wat::core::if (:wat::core::and (:wat::core::= (:c::kind a pg) "symbol")
                    (:c::ptr-ty? (:c::type-of a env pg)))
    ;; **guarded, because a string LITERAL lives in the read-only segment.** Its count is zero
    ;; by construction, which already means "never eligible for in-place" -- so skipping the
    ;; increment costs nothing, and writing it would be a fault. `elf/src/strverbs.wat` found
    ;; this the moment a String parameter was passed on through a recursive call: three
    ;; segmentation faults, all of them a literal reaching a variable and then being shared.
    (:c::emit o "488378f800740448ff40f8")          ;; cmp [rax-8],0 ; je +4 ; incq [rax-8]
    o))

;; ---------------------------------------------------------------- vectors and records
;;
;; A Vector and a record are the same object: `[count:8][slot:8]...`, every slot a machine word,
;; which is also what a String is if you read its bytes as the payload. So one layout answers
;; `length` (a peek at the header), `nth` and a field read (the same indexed load), `conj` and
;; `assoc` (the same copy). The only difference between a Vector and a record is that a record's
;; field NAMES are known at compile time, so its accesses are at constant offsets.
;;
;; Everything is copy-on-write, because F-104 is true in machine code as well: there is no
;; positional update, so `assoc` makes a new one. `conj` is O(n) every time, which is what the
;; interpreter's Vector does too (F-023).

;; each element computed and pushed, left to right, BEFORE anything is allocated -- an element
;; may itself allocate, and the vector's own bump has to come after all of them
(:wat::core::defn :c::push-elems [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                  pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                  slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::push-elems ks (:wat::core::+ i 1)
      (:c::push (:c::share (:wat::core::nth ks i)  env pg
                  (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))) (:c::push-rax) 8)
      env pg rt tb slot)))

;; and popped back off into the slots, last first, because the last one is on top
(:wat::core::defn :c::pop-slots [k <- :wat::core::i64 o <- :c::Out] -> :c::Out
  (:wat::core::if (:wat::core::< k 0) o
    (:c::pop-slots (:wat::core::- k 1)
      (:c::popn o (:wat::string::concat (:c::pop-rcx)                    ;; pop rcx
        (:c::store-slot (:wat::core::+ 8 (:wat::core::* 8 k)))) 8))))

;; `:c::Bind/name` -> the slot index of `name` in the record `:c::Bind`, or -1 if the head is
;; not an accessor at all. `user/main` has a slash too, which is why the prefix has to be a
;; declared record and not merely a namespace.
(:wat::core::defn :c::acc-index [pg <- :c::Prog head <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [at (:c::slash-at head (:wat::core::- (:wat::string::length head) 1))]
    (:wat::core::if (:wat::core::< at 0) -1
      (:wat::core::let
        [rn (:wat::string::subs head 0 at)
         fn (:wat::string::subs head (:wat::core::+ at 1) (:wat::string::length head))
         ri (:c::rec-index (:c::Prog/recs pg) rn 0)]
        (:wat::core::if (:wat::core::< ri 0) -1
          (:c::field-index (:c::Rec/fields (:wat::core::nth (:c::Prog/recs pg) ri)) fn 0))))))

;; `(assoc R :field V)` on a record, `(assoc V I X)` on a vector -- the same runtime routine,
;; and the only difference is whether the index is a compile-time keyword or an expression
(:wat::core::defn :c::assoc-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                  pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                  slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::length ks) 4) (:c::fail "assoc arity" a pg)
    (:wat::core::if (:wat::core::= (:c::kind (:wat::core::nth ks 2) pg) "keyword")
      (:wat::core::let
        [rt-ty (:c::rec-name-of (:c::type-of (:wat::core::nth ks 1) env pg))
         ri (:c::rec-index (:c::Prog/recs pg) rt-ty 0)
         kws (:c::text pg (:wat::core::nth ks 2))
         fi (:wat::core::if (:wat::core::< ri 0) -1
              (:c::field-index (:c::Rec/fields (:wat::core::nth (:c::Prog/recs pg) ri))
                (:wat::string::subs kws 1 (:wat::string::length kws)) 0))]
        (:wat::core::if (:wat::core::< fi 0) (:c::fail "assoc field" a pg)
          (:wat::core::if
            (:wat::core::and (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
              (:wat::core::= (:c::scalar-field pg (:c::text pg (:wat::core::nth ks 1)) 0) fi))
            ;; the value is computed while the register still holds the old field.
            ;; rax keeps the new one; the tail call writes it into the parameter
            ;; register. writing it here would clobber the other arm of an `if`
            ;; that also passes the old field through.
            (:c::share (:wat::core::nth ks 3) env pg
              (:c::expr (:wat::core::nth ks 3) o env pg rt tb slot (:c::no-tail)))
          (:wat::core::let
            [rm? (:c::remat? (:wat::core::nth ks 1) env pg)
             o1 (:wat::core::if rm? o
                  (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail))
                    (:c::push-rax) 8))
             o2 (:c::share (:wat::core::nth ks 3) env pg
                  (:c::expr (:wat::core::nth ks 3) o1 env pg rt tb slot (:c::no-tail)))
             ;; the same proof `conj` requires of its container (elf/compile.wat, `:c::conj?`)
             own? (:wat::core::and (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                    (:c::linear? pg (:c::text pg (:wat::core::nth ks 1)) 0))]
            ;; **The static test is LOAD-BEARING, not a hint** -- measured, F-142. Calling the
            ;; owning path unconditionally and letting the runtime share count decide made the
            ;; compiler emit different code for `bench`, `fib` and `fib32` when compiled than
            ;; when interpreted: the count UNDER-counts, because `:c::share` increments only for
            ;; symbols of pointer type at nine sites, and a record can reach a second holder
            ;; without passing through any of them. So this gates the same way `conj` and
            ;; `concat` do, and the count is the second of two checks rather than the only one.
            ;; the field index is FIXED-WIDTH either way, but unlike a literal's address it
            ;; cannot change between the measuring pass and the emitting pass -- it comes from
            ;; the program text -- so it does not need the ten-byte `movabs` an address does
            (:c::call
              (:wat::core::if rm?
                (:c::emit o2 (:wat::string::concat "4889c2"
                  (:c::mov-rr (:c::reg-of (:wat::core::nth ks 1) env pg) (:c::rax))
                  (:c::mov-ri (:c::rcx) fi)))
                (:c::popn o2 (:wat::string::concat "4889c2" (:c::pop-rax)
                  (:c::mov-ri (:c::rcx) fi)) 8))
              (:wat::core::if own? (:c::at-slot-own rt) (:c::at-slot rt)))))))
      ;; **wat's own `assoc` refuses a Vector** -- "expected (HashMap :- [K V]),
      ;; (PersistentMap :- [K V]), or :wat::core::Record" -- which is F-104 in the language
      ;; itself. The machine code for it is already here and costs nothing extra: `slot_set`
      ;; takes an index and does not care where it came from. Compiling it anyway would make the
      ;; compiled language a SUPERSET of the interpreted one, which is exactly the drift F-119
      ;; warns about, so it is refused instead -- and the refusal is the measurement: positional
      ;; vector update is 49 bytes of runtime that wat does not expose.
      (:c::fail "assoc on a vector (F-104: wat has no positional vector update either)" a pg))))

;; `assert-eq` compiles to the comparison it names and a jump over the diagnostic. The message
;; is the assertion's own SOURCE TEXT, which the compiler has and the interpreter's error does
;; not put anywhere as legible.
(:wat::core::defn :c::asserteq-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out
                                     env <- :c::Env pg <- :c::Prog rt <- :c::Layout
                                     tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::let
    [str? (:wat::core::and (:wat::core::= (:c::type-of (:wat::core::nth ks 1) env pg) "str")
                           (:wat::core::= (:c::type-of (:wat::core::nth ks 2) env pg) "str"))
     o1 (:c::push (:c::expr (:wat::core::nth ks 1) o env pg rt tb slot (:c::no-tail)) (:c::push-rax) 8)
     o2 (:c::expr (:wat::core::nth ks 2) o1 env pg rt tb slot (:c::no-tail))
     o3 (:c::popn o2 (:wat::string::concat "4889c1" (:c::pop-rax)) 8)
     o4 (:wat::core::if str? (:c::call o3 (:c::at-streq rt)) (:c::emit o3 (:c::op-hex "=")))
     o5 (:c::emit (:c::emit o4 "4885c0") "0f8500000000")      ;; test ; jnz over the diagnostic
     at (:wat::core::- (:c::codelen o5) 4)
     o6 (:c::static-str (:wat::string::concat "assert failed: " (:c::text pg a)) o5 tb
          (:c::rax))
     o7 (:c::call o6 (:c::at-die rt))
     o8 (:c::patch o7 at (:asm::le (:wat::core::- (:c::codelen o7) (:wat::core::+ at 4)) 4))]
    (:c::emit o8 (:c::mov-rax 0))))

(:wat::core::defn :c::vec-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) (:c::fail "Vector form" a pg)
    (:wat::core::let
      [n (:wat::core::- (:wat::core::length ks) 3)
       o1 (:c::push-elems ks 3 o env pg rt tb slot)
       o2 (:c::call (:c::emit o1 (:c::mov-rax n)) (:c::at-varr rt))]
      (:c::pop-slots (:wat::core::- n 1) o2))))

;; a record constructor names its fields, so the pairs are popped back into the slot the
;; DECLARATION puts them in rather than the order they were written
(:wat::core::defn :c::rec-pop [ks <- :c::Kids i <- :wat::core::i64 r <- :c::Rec o <- :c::Out
                               a <- :wat::core::i64 pg <- :c::Prog] -> :c::Out
  (:wat::core::if (:wat::core::< i 1) o
    (:wat::core::let
      [kw (:wat::string::subs (:c::text pg (:wat::core::nth ks i)) 1
            (:wat::string::length (:c::text pg (:wat::core::nth ks i))))
       fi (:c::field-index (:c::Rec/fields r) kw 0)]
      (:wat::core::if (:wat::core::< fi 0) (:c::fail "record field" a pg)
        (:c::rec-pop ks (:wat::core::- i 2) r
          (:c::popn o (:wat::string::concat (:c::pop-rcx)
            (:c::store-slot (:wat::core::+ 8 (:wat::core::* 8 fi)))) 8) a pg)))))

(:wat::core::defn :c::rec-form [ks <- :c::Kids a <- :wat::core::i64 r <- :c::Rec o <- :c::Out
                                env <- :c::Env pg <- :c::Prog rt <- :c::Layout
                                tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::rem (:wat::core::length ks) 2) 1)
    (:c::fail "record constructor" a pg)
    (:wat::core::let
      [o1 (:c::rec-vals ks 2 o env pg rt tb slot)
       o2 (:c::call (:c::emit o1 (:c::mov-rax (:wat::core::length (:c::Rec/fields r))))
            (:c::at-vnew rt))]
      (:c::rec-pop ks (:wat::core::- (:wat::core::length ks) 2) r o2 a pg))))

;; the values sit at odd indices after the keywords: 2, 4, 6...
(:wat::core::defn :c::rec-vals [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::rec-vals ks (:wat::core::+ i 2)
      (:c::push (:c::share (:wat::core::nth ks i)  env pg
                  (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))) (:c::push-rax) 8)
      env pg rt tb slot)))

;; ---------------------------------------------------------------- cond, and, or
;;
;; `cond` is a chain of `if`s and needs no new idea; the only thing to get right is that each
;; clause's BODY is in whatever tail position the `cond` itself was, while its test never is.
;; A `cond` that falls off the end answers zero, which is what `nil` compiles to.

(:wat::core::defn :c::cond-form [ks <- :c::Kids i <- :wat::core::i64 a <- :wat::core::i64 o <- :c::Out
                                 env <- :c::Env pg <- :c::Prog rt <- :c::Layout
                                 tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::emit o (:c::mov-rax 0))
    (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks i))]
      (:wat::core::if (:wat::core::< (:wat::core::length cks) 2) (:c::fail "cond clause" a pg)
        (:wat::core::if (:wat::core::= (:c::text pg (:wat::core::nth cks 0)) ":else")
          (:c::seq cks 1 o env pg rt tb slot tc)
          (:wat::core::let
            [o1 (:c::expr (:wat::core::nth cks 0) o env pg rt tb slot (:c::no-tail))
             o2 (:c::emit o1 "4885c0")                      ;; test rax, rax
             o3 (:c::emit o2 "0f8400000000")                ;; jz <next clause>
             jz-at (:wat::core::- (:c::codelen o3) 4)
             o4 (:c::seq cks 1 o3 env pg rt tb slot tc)
             o5 (:c::emit o4 (:c::jmp-unpatched))                  ;; jmp <end>
             jmp-at (:wat::core::- (:c::codelen o5) 4)
             o6 (:c::patch o5 jz-at (:asm::le (:wat::core::- (:c::codelen o5) (:wat::core::+ jz-at 4)) 4))
             o7 (:c::cond-form ks (:wat::core::+ i 1) a o6 env pg rt tb slot tc)]
            (:c::patch o7 jmp-at
              (:asm::le (:wat::core::- (:c::codelen o7) (:wat::core::+ jmp-at 4)) 4))))))))

;; `and` and `or` answer the FIRST falsy / first truthy operand, or the last one -- which is
;; wat's rule and also the cheapest: the deciding value is already in rax, so the short circuit
;; is one conditional jump to the end and nothing to load.
(:wat::core::defn :c::and-form [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::- (:wat::core::length ks) 1))
    (:c::expr (:wat::core::nth ks i) o env pg rt tb slot tc)
    (:wat::core::let
      [o1 (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))
       o2 (:c::emit (:c::emit o1 "4885c0") "0f8400000000")  ;; test ; jz <end, rax is the falsy one>
       at (:wat::core::- (:c::codelen o2) 4)
       o3 (:c::and-form ks (:wat::core::+ i 1) o2 env pg rt tb slot tc)]
      (:c::patch o3 at (:asm::le (:wat::core::- (:c::codelen o3) (:wat::core::+ at 4)) 4)))))

(:wat::core::defn :c::or-form [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                               pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                               slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::- (:wat::core::length ks) 1))
    (:c::expr (:wat::core::nth ks i) o env pg rt tb slot tc)
    (:wat::core::let
      [o1 (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))
       o2 (:c::emit (:c::emit o1 "4885c0") "0f8500000000")  ;; test ; jnz <end, rax is the truthy one>
       at (:wat::core::- (:c::codelen o2) 4)
       o3 (:c::or-form ks (:wat::core::+ i 1) o2 env pg rt tb slot tc)]
      (:c::patch o3 at (:asm::le (:wat::core::- (:c::codelen o3) (:wat::core::+ at 4)) 4)))))

;; ---------------------------------------------------------------- let

(:wat::core::defrecord :c::BindR [o <- :c::Out  env <- :c::Env  slot <- :wat::core::i64])

(:wat::core::defn :c::bind-each [bs <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                 pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                 slot <- :wat::core::i64] -> :c::BindR
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) (:c::BindR :o o :env env :slot slot)
    (:wat::core::let
      [name (:c::text pg (:wat::core::nth bs i))
       ;; the initialiser is compiled in the OUTER scope, which is what makes `let` not `letrec`
       disp (:wat::core::* -8 (:wat::core::+ slot 1))
       r (:wat::core::if (:wat::core::< slot (:c::Prog/nlr pg))
           (:wat::core::+ (:c::Prog/regbase pg) slot) -1)
       ;; **a binding with a register of its own is computed IN it** (C-186). The frame case
       ;; still goes through rax, because a store is where it has to end up either way.
       ;; `:c::share` only ever emits for a symbol of pointer type, which `:c::expr-to` never
       ;; takes a shortcut on -- every clause but the fallback refuses a pointer -- so the
       ;; increment is still emitted exactly where it was.
       o2 (:wat::core::if (:wat::core::>= r 0)
            (:wat::core::assoc
              (:c::share (:wat::core::nth bs (:wat::core::+ i 1)) env pg
                (:c::expr-to (:wat::core::nth bs (:wat::core::+ i 1)) r o env pg rt tb slot))
              :rax "")
            (:wat::core::assoc
              (:c::emit (:c::share (:wat::core::nth bs (:wat::core::+ i 1)) env pg
                          (:c::expr (:wat::core::nth bs (:wat::core::+ i 1)) o env pg rt tb slot
                            (:c::no-tail)))
                (:c::store (:c::fp o disp) (:c::Out/fpr o)))
              :rax name))]
      (:c::bind-each bs (:wat::core::+ i 2) o2
        (:wat::core::conj env
          (:c::Bind :name name :disp disp :reg r
                    :ty (:c::type-of (:wat::core::nth bs (:wat::core::+ i 1)) env pg)))
        pg rt tb (:wat::core::+ slot 1)))))

;; **a binding of the same name is a different value**, so whatever an enclosing branch proved
;; about the old one stops being true in the body -- and what the INITIALISER can be takes its
;; place. The initialisers are read in the OUTER bounds, which is what makes `let` not `letrec`
;; here as everywhere else; each binding then shadows, so they are laid down left to right.
(:wat::core::defn :c::bnds-let [bs <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog
                                out <- :c::Bnds] -> :c::Bnds
  (:wat::core::if (:wat::core::>= i (:wat::core::length bs)) out
    (:wat::core::let [b (:c::bnd-expr (:wat::core::nth bs (:wat::core::+ i 1)) pg out)]
      (:c::bnds-let bs (:wat::core::+ i 2) pg
        (:c::bnd-put out (:c::text pg (:wat::core::nth bs i))
                     (:c::Bnd/lo b) (:c::Bnd/hi b))))))

;; ---------------------------------------------------------------- computing somewhere else
;;
;; **Everything this compiler computes lands in rax and is then moved where it belongs.** That
;; is an accumulator machine, and F-151 measured the bill: three `mov %rax,%rN` an iteration in
;; `triple`, sitting ON the loop-carried chain -- which is also why the branchless select could
;; not be afforded, because `cmov` needs chain slack this model has already spent.
;;
;; `:c::expr-to` is the other way round: given a destination, put the answer there. Three of
;; its four clauses are emitters that already existed for other reasons, and **the fourth is
;; the fallback, which is exactly what the caller used to do** -- so nothing can get worse, and
;; there is no shape whose absence costs more than it did before.
;; `x * k` on a register and a literal is ONE instruction with a destination of its own --
;; the three-operand `imul`, which `:c::fold` has used since C-133. Without this clause the
;; general case below would spend a `mov` putting the literal in the destination first, which
;; is WORSE than the accumulator path it replaces: measured, 28 instructions an iteration in
;; `triple` became 31.
(:wat::core::defn :c::imul3? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) false
        (:wat::core::and (:wat::core::= (:c::binop (:c::text pg (:wat::core::nth ks 0))) "*")
          (:wat::core::and (:wat::core::>= (:c::reg-of (:wat::core::nth ks 1) env pg) 0)
                           (:c::imm-cmp? (:wat::core::nth ks 2) pg)))))))

;; **the overflow check is dead exactly when the bounds say the operands cannot leave i64**,
;; which is the question `:c::fold` asks at every step. Asking it here too is not a second
;; opinion -- it is the same `:c::op-safe?` on the same `:c::bnd-expr` of the same operands.
(:wat::core::defn :c::dst-dead? [ks <- :c::Kids op <- :wat::core::String
                                 pg <- :c::Prog] -> :wat::core::bool
  (:c::op-safe? op (:c::bnd-expr (:wat::core::nth ks 1) pg (:c::Prog/bnds pg))
                   (:c::bnd-expr (:wat::core::nth ks 2) pg (:c::Prog/bnds pg))))

(:wat::core::defn :c::to-dst? [a <- :wat::core::i64 dst <- :wat::core::i64 env <- :c::Env
                               pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) false
        (:wat::core::let [op (:c::binop (:c::text pg (:wat::core::nth ks 0)))
                          ar (:c::reg-of (:wat::core::nth ks 1) env pg)]
          ;; commutative, so the left operand can be folded in from where it lives once the
          ;; right one is in the destination -- and the destination must not BE the left
          ;; operand, or computing the right one would clobber it before the fold reads it
          (:wat::core::and (:c::comm-op? op)
            (:wat::core::and (:wat::core::>= ar 0) (:wat::core::not= ar dst))))))))

(:wat::core::defn :c::expr-to [a <- :wat::core::i64 dst <- :wat::core::i64 o <- :c::Out
                               env <- :c::Env pg <- :c::Prog rt <- :c::Layout
                               tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::cond
    ;; already a value: a register, a small literal, a `reg - imm` the bounds proved safe
    ((:c::selv? a env pg (:c::Prog/bnds pg)) (:c::emit o (:c::selv a dst env pg)))
    ;; `(+ x k)` on a register and an immediate, with the overflow check the bounds did not lift
    ((:c::acc-op? a env pg) (:c::acc-op a dst o env pg rt))
    ;; `x * k`: the three-operand `imul` writes straight to the destination
    ((:c::imul3? a env pg)
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:c::ovf-check "*"
          (:c::emit o (:c::imul3 (:c::reg-of (:wat::core::nth ks 1) env pg)
                        (:c::to-int (:c::text pg (:wat::core::nth ks 2)) pg) dst))
          rt (:c::dst-dead? ks "*" pg))))
    ;; `(op A B)`: the right operand into the destination, then fold A in from its register
    ((:c::to-dst? a dst env pg)
      (:wat::core::let
        [ks (:c::kidsof pg a)
         op (:c::binop (:c::text pg (:wat::core::nth ks 0)))
         o1 (:c::expr-to (:wat::core::nth ks 2) dst o env pg rt tb slot)
         o2 (:c::emit o1 (:c::reg-op-to op (:c::reg-of (:wat::core::nth ks 1) env pg) dst))]
        (:c::ovf-check op o2 rt (:c::dst-dead? ks op pg))))
    ;; and otherwise exactly what the caller did before: compute in rax and move
    (:else (:c::emit (:c::expr a o env pg rt tb slot (:c::no-tail)) (:c::reg-mov-from dst)))))

(:wat::core::defn :c::let-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                                rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::< (:wat::core::length ks) 3) (:c::fail "let arity" a pg)
    (:wat::core::let [bs (:c::kidsof pg (:wat::core::nth ks 1))]
      (:wat::core::if (:wat::core::not= (:wat::core::rem (:wat::core::length bs) 2) 0) (:c::fail "let bindings" a pg)
        (:wat::core::let [r (:c::bind-each bs 0 o env pg rt tb slot)]
          ;; the bindings go out of scope with the body, so the env is not carried back out
          (:c::seq ks 2 (:c::BindR/o r) (:c::BindR/env r)
            (:wat::core::assoc pg :bnds (:c::bnds-let bs 0 pg (:c::Prog/bnds pg)))
            rt tb (:c::BindR/slot r) tc))))))

;; ---------------------------------------------------------------- sequences, and the heap
;;
;; ## Why a bump allocator can free
;;
;; A sequence's last form is its value; every form BEFORE it has its value thrown away. So
;; whatever a non-final form allocated is garbage the instant it finishes -- and with a bump
;; allocator, freeing all of it is one instruction: put r15 back where it was.
;;
;;   push r15 ; push r15        mark
;;   <the statement>
;;   pop r15 ; pop r15          release
;;
;; Twice, because the frame is kept 16-byte aligned and one push would tip it. Eight bytes of
;; code per statement, and it nests without any bookkeeping, because the marks live on the stack.
;;
;; ## Why this is sound, and exactly where it stops
;;
;; The release is only safe if nothing that outlives the statement can be holding a pointer into
;; what it allocated. In this language there are exactly two ways a pointer can be stored:
;;
;;   * a `let` slot -- written inside the statement, and out of scope when it ends, because
;;     `:c::let-form` does not carry its environment back out past its body. Safe.
;;   * `poke` -- an arbitrary address, which the statement can hand to anyone. NOT safe.
;;
;; So a statement containing a `poke` anywhere inside it is not released. The test is a substring
;; of the statement's own source, which is crude in the direction that costs nothing: a false
;; positive only declines to free memory.
;;
;; A returned value is never released, because the final form is never marked -- which is what
;; makes `(defn f [] :- wat.type/String (wat.string/concat ...))` keep working.
;;
;; ## What it does not do
;;
;; Anything whose allocation ESCAPES upward still accumulates, and `(user/stars 40 "")` in
;; elf/src/strings.wat is a deliberate example: each level's result is the next level's argument,
;; so every intermediate string is live until the outermost one is. Freeing those needs
;; reachability, not scope -- a collector, or a caller-side release at every call whose return
;; type is not a pointer. The second is the next thing to build and is the same idea one level
;; up; the first is a different program.

;; **Which statements can have their allocations released, asked properly.**
;;
;; This used to be a substring test for "poke" on the statement's own source. That is wrong in
;; the direction that matters: a statement calling a function that pokes contains no `poke`
;; itself, so it was released -- and anything it allocated and handed over was freed underneath
;; the pointer. No program here did it, but the rule permitted it.
;;
;; The compiler has a call graph: `:c::Prog/fns` holds every function and its body. So the set of
;; functions that transitively reach a `poke` is computed once, as a fixpoint over that graph,
;; and a statement is releasable when it neither pokes nor calls anything that does.
;; `clone` is asked of the function ITSELF, not transitively: the child inherits the frame and
;; the registers that are live at the clone site, which is inside whoever called it. A substring
;; test used to stand in for this, and it would have been fooled by a name or a string literal
;; that merely contained the word.
(:wat::core::defn :c::has-clone? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "vector") (:c::any-clone? (:c::kidsof pg a) 0 pg))
    ((:wat::core::not= (:c::kind a pg) "list") false)
    (:else
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) false
          (:wat::core::or (:c::clone? (:c::text pg (:wat::core::nth ks 0)))
                          (:c::any-clone? ks 0 pg)))))))

(:wat::core::defn :c::any-clone? [ks <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) false
    (:wat::core::or (:c::has-clone? (:wat::core::nth ks i) pg)
                    (:c::any-clone? ks (:wat::core::+ i 1) pg))))

(:wat::core::defn :c::is-poker? [pg <- :c::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length (:c::Prog/pokers pg))) false)
    ((:wat::core::= (:wat::core::nth (:c::Prog/pokers pg) i) name) true)
    (:else (:c::is-poker? pg name (:wat::core::+ i 1)))))

(:wat::core::defn :c::calls-poke? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "vector") (:c::any-poke? (:c::kidsof pg a) 0 pg))
    ((:wat::core::not= (:c::kind a pg) "list") false)
    (:else
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) false
          (:wat::core::let [h (:c::text pg (:wat::core::nth ks 0))]
            (:wat::core::or (:c::poke? h)
              (:wat::core::or (:c::is-poker? pg h 0) (:c::any-poke? ks 0 pg)))))))))

(:wat::core::defn :c::any-poke? [ks <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) false
    (:wat::core::or (:c::calls-poke? (:wat::core::nth ks i) pg)
                    (:c::any-poke? ks (:wat::core::+ i 1) pg))))

;; one sweep: any function that reaches a poke, or calls one that does, joins the set
;; ---------------------------------------------------------------- resolving the types
;;
;; Collection is one forward pass, so a type named before it is declared cannot be resolved as it
;; goes. wat itself has no such rule -- `:c::kidsof` returns `:c::Kids` twenty lines above the
;; typealias that defines it -- so the compiler should not either. Types are therefore left blank
;; during collection and filled once every record and alias has been seen.

(:wat::core::defn :c::fill-recs [pg <- :c::Prog i <- :wat::core::i64 acc <- :c::Recs] -> :c::Prog
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:c::Prog/recs pg)))
    (:wat::core::assoc pg :recs acc)
    (:wat::core::let [r (:wat::core::nth (:c::Prog/recs pg) i)
                      fv (:c::kidsof pg (:c::Rec/fv r))]
      (:c::fill-recs pg (:wat::core::+ i 1)
        (:wat::core::conj acc
          (:wat::core::assoc r :ftypes
            (:c::field-types fv 0 pg (:wat::core::Vector :- [:wat::core::String]))))))))

(:wat::core::defn :c::fill-fns [pg <- :c::Prog i <- :wat::core::i64 acc <- :c::FnV] -> :c::Prog
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:c::Prog/fns pg)))
    (:wat::core::assoc pg :fns acc)
    (:wat::core::let [f (:wat::core::nth (:c::Prog/fns pg) i)
                      ks (:c::kidsof pg (:c::Fn/node f))]
      (:c::fill-fns pg (:wat::core::+ i 1)
        (:wat::core::conj acc
          (:wat::core::assoc f :ret
            (:c::ty-of-node (:wat::core::nth ks (:wat::core::- (:c::body-start ks 3 pg) 1)) pg)))))))

(:wat::core::defn :c::poke-scan [pg <- :c::Prog i <- :wat::core::i64] -> :c::Prog
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:c::Prog/fns pg))) pg
    (:wat::core::let [f (:wat::core::nth (:c::Prog/fns pg) i)
                      nm (:c::Fn/name f)]
      (:c::poke-scan
        (:wat::core::if (:wat::core::and (:wat::core::not (:c::is-poker? pg nm 0))
                                         (:c::calls-poke? (:c::Fn/node f) pg))
          (:wat::core::assoc pg :pokers (:wat::core::conj (:c::Prog/pokers pg) nm))
          pg)
        (:wat::core::+ i 1)))))

;; sweep until nothing new joins; the set can only grow, so the function count bounds the rounds
(:wat::core::defn :c::poke-fix [pg <- :c::Prog rounds <- :wat::core::i64] -> :c::Prog
  (:wat::core::if (:wat::core::<= rounds 0) pg
    (:wat::core::let [pg2 (:c::poke-scan pg 0)]
      (:wat::core::if (:wat::core::= (:wat::core::length (:c::Prog/pokers pg2))
                                     (:wat::core::length (:c::Prog/pokers pg)))
        pg2
        (:c::poke-fix pg2 (:wat::core::- rounds 1))))))

(:wat::core::defn :c::releasable? [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::not (:c::calls-poke? a pg)))

;; a sequence of forms; the last one's value is the value of the whole, and every form before it
;; gives its allocations back
(:wat::core::defn :c::seq [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                           rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:wat::core::let
      [a (:wat::core::nth ks i)
       drop? (:wat::core::and (:wat::core::< i (:wat::core::- (:wat::core::length ks) 1))
                              (:c::releasable? a pg))
       o1 (:wat::core::if drop? (:c::push o "41574157" 16) o)
       last? (:wat::core::= i (:wat::core::- (:wat::core::length ks) 1))
       o2 (:c::expr a o1 env pg rt tb slot (:wat::core::if last? tc (:c::no-tail)))
       o3 (:wat::core::if drop? (:c::popn o2 "415f415f" 16) o2)]
      (:c::seq ks (:wat::core::+ i 1) o3 env pg rt tb slot tc))))

;; ---------------------------------------------------------------- println

(:wat::core::defn :c::print-form [ks <- :c::Kids a <- :wat::core::i64 o <- :c::Out env <- :c::Env pg <- :c::Prog
                                  rt <- :c::Layout tb <- :wat::core::i64 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::not= (:wat::core::length ks) 2) (:c::fail "println arity" a pg)
    (:wat::core::let [arg (:wat::core::nth ks 1)
                      ty (:c::type-of arg env pg)]
      (:wat::core::cond
        ;; a literal is its own EDN rendering, so it goes out as bytes with no runtime at all
        ((:wat::core::= (:c::kind arg pg) "string") (:c::print-string arg o tb rt pg))
        ((:wat::core::= ty "str") (:c::call (:c::expr arg o env pg rt tb slot (:c::no-tail)) (:c::at-str rt)))
        ;; `(println (> 3 2))` prints `true`, not `1`. The type pass is the only thing standing
        ;; between the compiler and a SILENT disagreement with the interpreter here, which is why
        ;; every one of these four paths has a program in elf/src that exercises it.
        ((:wat::core::= ty "bool") (:c::call (:c::expr arg o env pg rt tb slot (:c::no-tail)) (:c::at-bool rt)))
        ((:wat::core::= ty "nil") (:c::print-nil (:c::expr arg o env pg rt tb slot (:c::no-tail)) rt))
        ;; a Vector and a record render as EDN too -- `[1 2 3]`, `#ns/Rec {:f 1}` -- and doing
        ;; that in machine code needs the element types at RUNTIME, which this compiler does not
        ;; carry. Refusing is the only honest option: printing the pointer as an integer would
        ;; disagree with the interpreter in silence.
        ((:wat::core::or (:wat::string::starts-with? ty "vec:") (:wat::string::starts-with? ty "rec:"))
          (:c::fail (:wat::string::concat "println of a " ty) a pg))
        (:else (:c::call (:c::expr arg o env pg rt tb slot (:c::no-tail)) (:c::at-i64 rt)))))))

;; nil renders as four bytes and never varies, so it is written straight out of the stack rather
;; than costing the output a runtime routine: `mov dword [rsp], "nil\n"` and one write.
(:wat::core::defn :c::print-nil [o <- :c::Out rt <- :c::Layout] -> :c::Out
  (:wat::core::let
    [o1 (:c::emit o (:wat::string::concat
          (:c::sub-rsp 16)
          "c704246e696c0a"                                  ;; mov dword [rsp], 0x0a6c696e
          (:wat::string::concat "4889e6" (:c::mov-rdx 4)))) ;; rsi = rsp ; rdx = 4
     o2 (:c::call o1 (:c::at-put rt))]
    (:c::emit o2 (:c::add-rsp 16))))

;; `:wat::kernel::println` renders a String as EDN -- `(println "a\nb")` writes `"a\nb"` and a
;; newline, quotes kept and the escape NOT expanded -- so the faithful compilation of a string
;; literal is its SOURCE TEXT, verbatim. The first version stripped the quotes and unescaped,
;; and the differential test against the interpreter caught it on the first run.
(:wat::core::defn :c::print-string [a <- :wat::core::i64 o <- :c::Out tb <- :wat::core::i64
                                    rt <- :c::Layout pg <- :c::Prog] -> :c::Out
  (:wat::core::let
    [text (:wat::string::concat (:c::text pg a) "\n")
     addr (:wat::core::+ tb (:wat::core::/ (:c::buf-len (:c::Out/tail o)) 2))
     o1 (:wat::core::assoc o :tail (:c::buf-add (:c::Out/tail o) (:asm::ascii text 0 "")))]
    ;; through the buffer like everything else -- a literal written straight to fd 1 would
    ;; overtake whatever `println` had buffered before it
    (:c::call (:c::emit o1 (:wat::string::concat (:c::mov-rsi addr)
                             (:c::mov-rdx (:wat::string::length text))))
      (:c::at-put rt))))

;; ---------------------------------------------------------------- calling a user function
;;
;; Arguments are pushed left to right, so the last one is nearest the top of the stack. Inside
;; the callee, rbp points at the saved rbp, [rbp+8] is the return address, and argument i of n
;; sits at [rbp + 16 + 8*(n-1-i)]. The caller pops them after the call.

(:wat::core::defn :c::push-args [ks <- :c::Kids i <- :wat::core::i64 o <- :c::Out env <- :c::Env
                                 pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                 slot <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) o
    (:c::push-args ks (:wat::core::+ i 1)
      (:c::push (:c::share (:wat::core::nth ks i)  env pg
                  (:c::expr (:wat::core::nth ks i) o env pg rt tb slot (:c::no-tail))) (:c::push-rax) 8)
      env pg rt tb slot)))

;; **a self tail call does not need the stack when the assignment is safe in order.** The
;; arguments are all computed before any parameter is overwritten -- which is why they went to
;; the machine stack and came straight back -- but that is only NECESSARY when a later argument
;; reads a parameter an earlier one clobbers. `(user/go (- i 1) (if (> a 1000000) ...))` does
;; not: nothing after the first argument mentions `i`, so `i` can be written where it lands.
;; C-153 found the `push`/`pop` pair on the critical path of `loopsum`'s `i`, a store and a load
;; with forwarding latency, once per iteration.
(:wat::core::defn :c::none-mention? [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                     pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) true
    (:wat::core::and (:wat::core::= (:c::occ (:wat::core::nth ks i) name pg) 0)
                     (:c::none-mention? ks (:wat::core::+ i 1) name pg))))

;; parameter j's name is `pv[3j]`, its argument `ks[j+1]`, and the arguments after it `ks[j+2..]`
(:wat::core::defn :c::tail-direct? [pv <- :c::Kids ks <- :c::Kids j <- :wat::core::i64
                                    n <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= j n) true
    (:wat::core::and
      (:c::none-mention? ks (:wat::core::+ j 2)
        (:c::text pg (:wat::core::nth pv (:wat::core::* 3 j))) pg)
      (:c::tail-direct? pv ks (:wat::core::+ j 1) n pg))))

;; ---------------------------------------------------------------- the branchless select
;;
;; **`(wat.core/if (wat.core/> a2 1000000) (wat.core/- a2 1000000) a2)` is a value, not a
;; control structure**, and gcc compiles it as one: `lea`, `cmp`, `cmovg`, no branch at all.
;; We compiled it as a diamond -- compare, branch, compute, jump, compute, join -- and then
;; moved the answer out of rax into wherever it belonged, six instructions on the long path and
;; four on the short one, with two branches either way. `elf/bench/triple.wat` has three of them
;; an iteration and they are 18 of its 40 instructions.
;;
;; Three things have to be true, and C-166 is what made the third one reachable:
;;
;;   1. the condition is a REGISTER against an IMMEDIATE, so the compare is one instruction and
;;      touches neither rax nor rcx;
;;   2. both arms are values that can be computed with `mov` or `lea`, which set no flags -- so
;;      the compare can go FIRST and the arms cannot disturb it, and the destination may be the
;;      register the compare reads;
;;   3. neither arm can trap. `(- x k)` normally carries a `jo`, which is a branch, which is the
;;      thing being removed -- but under the dominating comparison C-166 proves that check dead,
;;      and a `lea` that cannot overflow is exactly what is left.
;;
;; The result goes straight into its destination register, which is the other half of the win:
;; the diamond's `mov %rax,%r12` disappears with it.
(:wat::core::defn :c::selv? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog
                             bs <- :c::Bnds] -> :wat::core::bool
  (:wat::core::if (:c::ptr-ty? (:c::type-of a env pg)) false
    (:wat::core::cond
      ((:wat::core::= (:c::kind a pg) "int") (:c::imm32? (:c::to-int (:c::text pg a) pg)))
      ((:wat::core::= (:c::kind a pg) "symbol") (:wat::core::>= (:c::reg-of a env pg) 0))
      ((:wat::core::not= (:c::kind a pg) "list") false)
      (:else
        (:wat::core::let [ks (:c::kidsof pg a)]
          (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) false
            (:wat::core::and (:wat::core::= (:c::binop (:c::text pg (:wat::core::nth ks 0))) "-")
              (:wat::core::and (:wat::core::>= (:c::reg-of (:wat::core::nth ks 1) env pg) 0)
                (:wat::core::and (:wat::core::= (:c::kind (:wat::core::nth ks 2) pg) "int")
                  (:wat::core::and (:c::imm32? (:wat::core::- 0
                                     (:c::to-int (:c::text pg (:wat::core::nth ks 2)) pg)))
                    ;; **the arm must not trap**, because a `lea` carries no check -- and the
                    ;; arm's own bounds are what decide that, the same question the fold asks.
                    (:c::op-safe? "-" (:c::bnd-expr (:wat::core::nth ks 1) pg bs)
                                      (:c::bnd-expr (:wat::core::nth ks 2) pg bs))))))))))))

(:wat::core::defn :c::selv [a <- :wat::core::i64 dst <- :wat::core::i64 env <- :c::Env
                            pg <- :c::Prog] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "int") (:c::mov-ri dst (:c::to-int (:c::text pg a) pg)))
    ((:wat::core::= (:c::kind a pg) "symbol")
      (:wat::core::let [r (:c::reg-of a env pg)]
        ;; already there: the `mov` would be `mov %r12,%r12`
        (:wat::core::if (:wat::core::= r dst) "" (:c::mov-rr r dst))))
    (:else
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:c::lea-at (:c::reg-of (:wat::core::nth ks 1) env pg)
          (:wat::core::- 0 (:c::to-int (:c::text pg (:wat::core::nth ks 2)) pg)) dst)))))

(:wat::core::defn :c::sel-ok? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::not= (:wat::core::length ks) 4) false
        (:wat::core::if (:wat::core::not (:c::if? (:c::text pg (:wat::core::nth ks 0)))) false
          (:wat::core::let [op (:c::cmp-cond (:wat::core::nth ks 1) env pg)]
            (:wat::core::if (:wat::core::= op "") false
              (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks 1))]
                (:wat::core::and (:wat::core::>= (:c::reg-of (:wat::core::nth cks 1) env pg) 0)
                  (:wat::core::and (:c::imm-cmp? (:wat::core::nth cks 2) pg)
                    (:wat::core::and
                      (:c::selv? (:wat::core::nth ks 2) env pg
                        (:c::bnds-arm cks op true pg (:c::Prog/bnds pg)))
                      (:c::selv? (:wat::core::nth ks 3) env pg
                        (:c::bnds-arm cks op false pg (:c::Prog/bnds pg))))))))))))))

;; **and the branch STAYS.** `cmov` was built first and measured: `triple` -15% instructions for
;; -1.6% cycles, and `loopsum` -11% instructions for **+34% cycles**. A `cmov` turns a control
;; dependence into a DATA dependence, and on a latency-bound loop that is the whole cost -- the
;; branch was predicted perfectly and cost nothing, while the `cmov` added itself to the
;; recurrence. (`gcc -O2` if-converts `loopsum` and is 11% slower than our branch for it.)
;;
;; What was worth having is the other half: **both arms written straight into the destination
;; register**, so the diamond's closing `mov %rax,%r12` is gone and each arm is one instruction.
;; Since `:c::selv` has a length the moment it is built, every displacement here is known without
;; patching and both branches are `rel8`.
;; **`(+ i 1)` where `i` is already the parameter register is `add $1,%r12`.** The general
;; path evaluates into rax and moves back, four instructions for one:
;; `mov %r12,%rax ; add $1,%rax ; jo ; mov %rax,%r12`. `:c::selv` gets there in one when the
;; bounds PROVE no overflow, because then it can use `lea`, which carries no check; this is
;; the case where the proof is unavailable and the check has to stay. Writing the destination
;; BEFORE the check is safe because the check aborts -- there is no path on which the
;; clobbered register is read again. C-180.
(:wat::core::defn :c::acc-op? [a <- :wat::core::i64 env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) false
        (:wat::core::let [op (:c::binop (:c::text pg (:wat::core::nth ks 0)))]
          (:wat::core::and
            (:wat::core::or (:wat::core::= op "+") (:wat::core::= op "-"))
            (:wat::core::and (:wat::core::>= (:c::reg-of (:wat::core::nth ks 1) env pg) 0)
                             (:c::imm-cmp? (:wat::core::nth ks 2) pg))))))))

(:wat::core::defn :c::acc-op [a <- :wat::core::i64 dst <- :wat::core::i64 o <- :c::Out
                              env <- :c::Env pg <- :c::Prog rt <- :c::Layout] -> :c::Out
  (:wat::core::let
    [ks (:c::kidsof pg a)
     op (:c::binop (:c::text pg (:wat::core::nth ks 0)))
     r (:c::reg-of (:wat::core::nth ks 1) env pg)
     v (:c::to-int (:c::text pg (:wat::core::nth ks 2)) pg)
     mv (:wat::core::if (:wat::core::= r dst) "" (:c::mov-rr r dst))
     ar (:wat::core::if (:wat::core::= op "+") (:c::add-ri dst v) (:c::sub-ri dst v))]
    (:c::ovf-check op (:c::emit o (:wat::string::concat mv ar)) rt false)))

(:wat::core::defn :c::sel [a <- :wat::core::i64 dst <- :wat::core::i64 o <- :c::Out
                           env <- :c::Env pg <- :c::Prog] -> :c::Out
  (:wat::core::let [ks (:c::kidsof pg a)
                    op (:c::cmp-cond (:wat::core::nth ks 1) env pg)
                    cks (:c::kidsof pg (:wat::core::nth ks 1))
                    cmp (:c::reg-cmp-imm (:c::reg-of (:wat::core::nth cks 1) env pg)
                          (:c::to-int (:c::text pg (:wat::core::nth cks 2)) pg))
                    tb (:c::selv (:wat::core::nth ks 2) dst env pg)
                    eb (:c::selv (:wat::core::nth ks 3) dst env pg)]
    (:wat::core::cond
      ;; both arms are the register already: there is nothing to choose between
      ((:wat::core::and (:wat::core::= tb "") (:wat::core::= eb "")) o)
      ;; the THEN arm is the register already, so the branch is the one that SKIPS the else arm
      ((:wat::core::= tb "")
        (:c::emit o (:wat::string::concat cmp (:c::jcc8 op)
                      (:asm::le (:c::hexlen eb) 1) eb)))
      ;; the ELSE arm is: branch over the then arm and there is nothing after it
      ((:wat::core::= eb "")
        (:c::emit o (:wat::string::concat cmp (:c::jcc-not8 op)
                      (:asm::le (:c::hexlen tb) 1) tb)))
      (:else
        (:c::emit o (:wat::string::concat cmp
          (:c::jcc-not8 op) (:asm::le (:wat::core::+ (:c::hexlen tb) 2) 1) tb
          "eb" (:asm::le (:c::hexlen eb) 1) eb))))))

;; each argument computed into rax and written straight to its parameter, left to right
(:wat::core::defn :c::tail-direct [ks <- :c::Kids j <- :wat::core::i64 n <- :wat::core::i64
                                   o <- :c::Out env <- :c::Env pg <- :c::Prog
                                   rt <- :c::Layout tb <- :wat::core::i64
                                   slot <- :wat::core::i64 nr <- :wat::core::i64] -> :c::Out
  (:wat::core::if (:wat::core::>= j n) o
    (:wat::core::cond
      ;; **an argument that is already a value goes straight into its parameter register** --
      ;; a register, a small literal, a `reg - imm`. `selv` is the same emitter the diamond's
      ;; arms use, and it carries the check that matters here: when the argument is the
      ;; parameter register ALREADY it emits nothing, where the general path below spends
      ;; `mov %rN,%rax ; mov %rax,%rN` saying so. C-177.
      ((:wat::core::and (:wat::core::< j nr)
         (:c::selv? (:wat::core::nth ks (:wat::core::+ j 1)) env pg (:c::Prog/bnds pg)))
        (:c::tail-direct ks (:wat::core::+ j 1) n
          (:c::emit o (:c::selv (:wat::core::nth ks (:wat::core::+ j 1)) j env pg))
          env pg rt tb slot nr))
      ;; **an argument that is a select goes straight into its parameter register**, which is
      ;; where the diamond's last `mov` went anyway
      ((:wat::core::and (:wat::core::< j nr)
                        (:c::sel-ok? (:wat::core::nth ks (:wat::core::+ j 1)) env pg))
        (:c::tail-direct ks (:wat::core::+ j 1) n
          (:c::sel (:wat::core::nth ks (:wat::core::+ j 1)) j o env pg)
          env pg rt tb slot nr))
      ;; the counter step, when no bound was available to make it a `lea`
      ((:wat::core::and (:wat::core::< j nr)
                        (:c::acc-op? (:wat::core::nth ks (:wat::core::+ j 1)) env pg))
        (:c::tail-direct ks (:wat::core::+ j 1) n
          (:c::acc-op (:wat::core::nth ks (:wat::core::+ j 1)) j o env pg rt)
          env pg rt tb slot nr))
      (:else
       (:wat::core::let
        [o1 (:c::share (:wat::core::nth ks (:wat::core::+ j 1)) env pg
              (:c::expr (:wat::core::nth ks (:wat::core::+ j 1)) o env pg rt tb slot (:c::no-tail)))
         o2 (:c::emit o1
              (:wat::core::if (:wat::core::< j nr) (:c::reg-mov-from j)
                (:c::store (:c::fp o1 (:wat::core::+ 16
                             (:wat::core::* 8 (:wat::core::- (:wat::core::- n 1) j))))
                           (:c::Out/fpr o1))))]
        (:c::tail-direct ks (:wat::core::+ j 1) n o2 env pg rt tb slot nr))))))

(:wat::core::defn :c::call-user [ks <- :c::Kids head <- :wat::core::String o <- :c::Out env <- :c::Env
                                 pg <- :c::Prog rt <- :c::Layout tb <- :wat::core::i64
                                 slot <- :wat::core::i64 tc <- :c::TC] -> :c::Out
  (:wat::core::let [n (:wat::core::- (:wat::core::length ks) 1)]
    (:wat::core::if (:c::tail-call? tc head n)
      ;; a self call in tail position: overwrite the incoming arguments and go round again, on
      ;; the SAME frame, so a tail-recursive loop runs in constant stack
      (:wat::core::let
        [fi (:c::fn-of pg head 0)
         pv (:c::kidsof pg (:wat::core::nth
              (:c::kidsof pg (:c::Fn/node (:wat::core::nth (:c::Prog/fns pg) fi))) 2))
         o2 (:wat::core::if (:c::tail-direct? pv ks 0 n pg)
              (:c::tail-direct ks 0 n o env pg rt tb slot (:c::TC/nregs tc))
              (:c::tail-store 0 n (:c::push-but-last ks 1 o env pg rt tb slot)
                (:c::TC/nregs tc)))]
        ;; **the back edge tests for itself** (C-188), when `if-cmp` handed down a test it
        ;; can repeat. Looping is then one taken branch instead of two, and the `jmp` to the
        ;; top is left behind for the exit path -- where it re-runs the test once and falls
        ;; into the base case, which is correct and off the hot path.
        (:wat::core::let
          [t (:c::TC/test tc)
           o3 (:wat::core::if (:wat::core::= t "") o2
                (:c::emit o2 (:wat::string::concat t
                  (:asm::le (:wat::core::- (:c::TC/body tc)
                              (:wat::core::+ (:c::here o2)
                                (:wat::core::+ (:c::hexlen t) 4))) 4))))]
          (:c::emit o3 (:wat::string::concat "e9"
            (:asm::le (:wat::core::- (:c::TC/target tc) (:wat::core::+ (:c::here o3) 5)) 4)))))
      (:wat::core::let [o1 (:c::push-args ks 1 o env pg rt tb slot)
                        o2 (:c::call o1 (:c::fn-addr pg head 0))]
        (:wat::core::if (:wat::core::= n 0) o2
          (:c::popn o2 (:c::add-rsp (:wat::core::* 8 n)) (:wat::core::* 8 n)))))))

;; ---------------------------------------------------------------- compiling one function

(:wat::core::defn :c::param-env [pv <- :c::Kids i <- :wat::core::i64 n <- :wat::core::i64
                                 env <- :c::Env pg <- :c::Prog regs? <- :wat::core::bool] -> :c::Env
  ;; the parameter vector reads `name :- type` per parameter, so names are every third child
  (:wat::core::if (:wat::core::>= i (:wat::core::length pv)) env
    (:c::param-env pv (:wat::core::+ i 3) n
      (:wat::core::conj env
        (:c::Bind :name (:c::text pg (:wat::core::nth pv i))
                  :ty (:c::ty-of-node (:wat::core::nth pv (:wat::core::+ i 2)) pg)
                  :reg (:wat::core::if (:wat::core::and regs?
                                         (:wat::core::< (:wat::core::/ i 3) (:c::nregs)))
                         (:wat::core::/ i 3) -1)
                  :disp (:wat::core::+ 16 (:wat::core::* 8 (:wat::core::- (:wat::core::- n 1)
                                                             (:wat::core::/ i 3))))))
      pg regs?)))

(:wat::core::defn :c::nparams [pv <- :c::Kids] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:wat::core::length pv) 0) 0
    (:wat::core::+ (:wat::core::/ (:wat::core::- (:wat::core::length pv) 1) 3) 1)))

;; ---------------------------------------------------------------- who gets the registers
;;
;; **Measured, because the answer was not what it looked like.** Putting the first three
;; parameters in rbx, r12 and r13 costs a push, a load and a pop in the prologue and epilogue,
;; and saves a memory reference on every read in the body. Whether that is a win depends entirely
;; on how many times the body runs per prologue:
;;
;;   `mix`, 200 million iterations of a tail-recursive loop over three parameters:
;;       with registers 384 ms, without 597 ms  -- 1.55x FASTER
;;   `fib(32)`, one parameter and an enormous number of ordinary calls:
;;       with registers  40 ms, without  32 ms  -- 25% SLOWER
;;
;; In a tail-recursive loop the prologue runs once and the body runs n times. In `fib` the
;; prologue runs on every call and the body is three instructions, so the saving never arrives
;; and the save/restore is pure cost. The loads it replaces were L1 hits either way.
;;
;; So the registers go to functions that LOOP -- ones with a self call in tail position, which
;; is exactly the shape that pays -- and everything else keeps its frame.

(:wat::core::defn :c::tail-self? [a <- :wat::core::i64 name <- :wat::core::String
                                  arity <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list") false
    (:wat::core::let [ks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) false
        (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))
                          last (:wat::core::nth ks (:wat::core::- (:wat::core::length ks) 1))]
          (:wat::core::cond
            ((:wat::core::and (:c::if? head) (:wat::core::= (:wat::core::length ks) 4))
              (:wat::core::or (:c::tail-self? (:wat::core::nth ks 2) name arity pg)
                              (:c::tail-self? (:wat::core::nth ks 3) name arity pg)))
            ((:wat::core::or (:c::do? head) (:c::let? head))
              (:c::tail-self? last name arity pg))
            ((:c::cond? head) (:c::tail-self-clauses ks 1 name arity pg))
            (:else (:wat::core::and (:wat::core::= head name)
                                    (:wat::core::= (:wat::core::- (:wat::core::length ks) 1) arity)))))))))

(:wat::core::defn :c::tail-self-clauses [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                         arity <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) false
    (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks i))]
      (:wat::core::or
        (:wat::core::and (:wat::core::>= (:wat::core::length cks) 2)
          (:c::tail-self? (:wat::core::nth cks (:wat::core::- (:wat::core::length cks) 1))
                          name arity pg))
        (:c::tail-self-clauses ks (:wat::core::+ i 1) name arity pg)))))

;; ---------------------------------------------------------------- who gets r8-r11
;;
;; **A function that makes no RETURNING call owns r8-r11.** Nothing else preserves them -- our
;; own callees save rbx, r12, r13 and rbp and treat r8-r11 as dead -- so a function that never
;; gets control back from a call can put `let` bindings there, and needs no prologue push and no
;; epilogue pop to do it. That doubles the register file for exactly the shape where the
;; register file is the ceiling: `elf/bench/triple.wat` has four parameters, which took all four
;; callee-saved registers and left its three per-iteration `let` bindings round-tripping through
;; the frame.
;;
;; "No returning call" is not "no call": a SELF TAIL CALL is a `jmp`, and control never comes
;; back through it. The next iteration rewrites the same registers from the top, which is what
;; makes the loop shape eligible at all. So this walks the body the way `:c::tail-self?` does,
;; carrying whether the node it is looking at is in tail position, and asks of everything else
;; the question `:c::scratch-safe?` already answers: does this subtree emit a call?
;;
;; The syscalls are excluded for free, which matters more than it looks: `syscall` itself
;; destroys rcx and r11.
(:wat::core::defn :c::noret? [a <- :wat::core::i64 tail? <- :wat::core::bool
                              name <- :wat::core::String arity <- :wat::core::i64
                              env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::cond
      ((:wat::core::= (:wat::core::length ks) 0) (:wat::core::not= (:c::kind a pg) "list"))
      ((:wat::core::not= (:c::kind a pg) "list") (:c::all-safe? ks 0 env pg))
      (:else
        (:wat::core::let [h (:c::text pg (:wat::core::nth ks 0))
                          nk (:wat::core::length ks)]
          (:wat::core::cond
            ((:wat::core::and (:c::if? h) (:wat::core::= nk 4))
              (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks 1) env pg)
                (:wat::core::and (:c::noret? (:wat::core::nth ks 2) tail? name arity env pg)
                                 (:c::noret? (:wat::core::nth ks 3) tail? name arity env pg))))
            ((:c::do? h) (:c::noret-seq? ks 1 tail? name arity env pg))
            ((:wat::core::and (:c::let? h) (:wat::core::>= nk 3))
              (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks 1) env pg)
                               (:c::noret-seq? ks 2 tail? name arity env pg)))
            ((:c::cond? h) (:c::noret-clauses? ks 1 tail? name arity env pg))
            ;; a call, or a head this does not take apart: quiet subtrees pass, and the one
            ;; call that passes is the self tail call with its arguments quiet
            (:else
              (:wat::core::or (:c::scratch-safe? a env pg)
                (:wat::core::and tail?
                  (:wat::core::and (:wat::core::= h name)
                    (:wat::core::and (:wat::core::= (:wat::core::- nk 1) arity)
                                     (:c::all-safe? ks 1 env pg))))))))))))

;; a sequence of forms: the last one inherits the tail position, the rest cannot have one
(:wat::core::defn :c::noret-seq? [ks <- :c::Kids i <- :wat::core::i64 tail? <- :wat::core::bool
                                  name <- :wat::core::String arity <- :wat::core::i64
                                  env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) true
    (:wat::core::if (:wat::core::= i (:wat::core::- (:wat::core::length ks) 1))
      (:c::noret? (:wat::core::nth ks i) tail? name arity env pg)
      (:wat::core::and (:c::scratch-safe? (:wat::core::nth ks i) env pg)
                       (:c::noret-seq? ks (:wat::core::+ i 1) tail? name arity env pg)))))

(:wat::core::defn :c::noret-clauses? [ks <- :c::Kids i <- :wat::core::i64 tail? <- :wat::core::bool
                                      name <- :wat::core::String arity <- :wat::core::i64
                                      env <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) true
    (:wat::core::let [cks (:c::kidsof pg (:wat::core::nth ks i))]
      (:wat::core::and (:wat::core::>= (:wat::core::length cks) 2)
        (:wat::core::and (:c::scratch-safe? (:wat::core::nth cks 0) env pg)
          (:wat::core::and (:c::noret-seq? cks 1 tail? name arity env pg)
                           (:c::noret-clauses? ks (:wat::core::+ i 1) tail? name arity env pg)))))))

;; the whole body, as one sequence whose last form is in tail position
(:wat::core::defn :c::callfree? [ks <- :c::Kids start <- :wat::core::i64 name <- :wat::core::String
                                 arity <- :wat::core::i64 env <- :c::Env
                                 pg <- :c::Prog] -> :wat::core::bool
  (:c::noret-seq? ks start true name arity env pg))

;; ---------------------------------------------------------------- what the branch proves
;;
;; **Inside the THEN arm of `(> x 1000000)`, `x` is greater than a million.** So `(- x 1000000)`
;; there cannot underflow, and the `jo` that guards it is dead code on every path that can reach
;; it. That is the whole of the `elf/bench/triple.wat` idiom, and it is three of the seven
;; overflow checks in that loop.
;;
;; The rule is deliberately the narrowest one that is obviously true: **if `x >= 0` and `k >= 0`
;; then `x - k` lies in `[-k, x]`, which is inside i64.** So all this has to carry is a single
;; name known to be non-negative, and all the comparison has to give is that fact:
;;
;;   (> x k) / (>= x k) with k >= 0   ->  the THEN arm knows x >= 0
;;   (< x k) / (<= x k) with k >= 0   ->  the ELSE arm knows x >= 0
;;
;; `=` and `not=` are left out: `(= x k)` proves it too, but the arm that knows it is the one
;; where `x` is a constant, and constant folding is a different job.
;;
;; It rides on `:c::Prog` rather than in a new parameter for the same reason `nlr` does -- `pg`
;; is already threaded through every expression, and a value put there is scoped exactly to the
;; subtree it was put there for. A `let` that rebinds the name takes the fact away again.
;; **what an expression can be, read off the syntax.** C-166 asked where the value physically
;; was -- which register, or whether rax still held the name -- and could only answer for the one
;; operand shape it knew. The bound is a property of the EXPRESSION, so it needs none of that:
;; a literal is itself, a name is what the branch proved, and arithmetic composes.
(:wat::core::defn :c::bnd-expr [a <- :wat::core::i64 pg <- :c::Prog bs <- :c::Bnds] -> :c::Bnd
  (:wat::core::cond
    ((:wat::core::= (:c::kind a pg) "int")
      (:wat::core::let [n (:c::to-int (:c::text pg a) pg)] (:c::bnd-at n n)))
    ((:wat::core::= (:c::kind a pg) "symbol") (:c::bnd-for bs (:c::text pg a)))
    ((:wat::core::not= (:c::kind a pg) "list") (:c::bnd-any))
    (:else
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::not= (:wat::core::length ks) 3) (:c::bnd-any)
          (:wat::core::let [op (:c::binop (:c::text pg (:wat::core::nth ks 0)))
                            x (:c::bnd-expr (:wat::core::nth ks 1) pg bs)
                            y (:c::bnd-expr (:wat::core::nth ks 2) pg bs)]
            (:wat::core::cond
              ((:wat::core::= op "+") (:c::bnd-add x y))
              ((:wat::core::= op "-") (:c::bnd-sub x y))
              ((:wat::core::= op "*") (:c::bnd-mul x y))
              (:else (:c::bnd-any)))))))))

;; the two bounds a comparison against a literal proves, one for each arm. `=` tells the THEN arm
;; everything and the ELSE arm nothing; `not=` is the same trade the other way round -- neither
;; "x is not 7" nor "x is not in [a,b]" is an interval, so those arms get top and say so.
(:wat::core::defn :c::cmp-lo [op <- :wat::core::String k <- :wat::core::i64
                              then? <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::and (:wat::core::= op ">") then?)
      (:wat::core::if (:c::add-ok? k 1) (:wat::core::+ k 1) (:c::i64-max)))
    ((:wat::core::and (:wat::core::= op ">=") then?) k)
    ((:wat::core::and (:wat::core::= op "<") (:wat::core::not then?)) k)
    ((:wat::core::and (:wat::core::= op "<=") (:wat::core::not then?))
      (:wat::core::if (:c::add-ok? k 1) (:wat::core::+ k 1) (:c::i64-max)))
    ((:wat::core::and (:wat::core::= op "=") then?) k)
    ((:wat::core::and (:wat::core::= op "not=") (:wat::core::not then?)) k)
    (:else (:c::i64-min))))
(:wat::core::defn :c::cmp-hi [op <- :wat::core::String k <- :wat::core::i64
                              then? <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::and (:wat::core::= op ">") (:wat::core::not then?)) k)
    ((:wat::core::and (:wat::core::= op ">=") (:wat::core::not then?))
      (:wat::core::if (:c::sub-ok? k 1) (:wat::core::- k 1) (:c::i64-min)))
    ((:wat::core::and (:wat::core::= op "<") then?)
      (:wat::core::if (:c::sub-ok? k 1) (:wat::core::- k 1) (:c::i64-min)))
    ((:wat::core::and (:wat::core::= op "<=") then?) k)
    ((:wat::core::and (:wat::core::= op "=") then?) k)
    ((:wat::core::and (:wat::core::= op "not=") (:wat::core::not then?)) k)
    (:else (:c::i64-max))))

;; the arm's bounds: what was known, met with what the comparison just proved. An empty meet
;; would mean the arm is unreachable; rather than reason about that, it is given top.
(:wat::core::defn :c::bnds-arm [cks <- :c::Kids op <- :wat::core::String then? <- :wat::core::bool
                                pg <- :c::Prog bs <- :c::Bnds] -> :c::Bnds
  (:wat::core::if (:wat::core::not= (:wat::core::length cks) 3) bs
    (:wat::core::let [x (:wat::core::nth cks 1) k (:wat::core::nth cks 2)]
      (:wat::core::if (:wat::core::or (:wat::core::not= (:c::kind x pg) "symbol")
                                      (:wat::core::not= (:c::kind k pg) "int")) bs
        (:wat::core::let [n (:c::to-int (:c::text pg k) pg)
                          was (:c::bnd-for bs (:c::text pg x))
                          lo (:c::imax (:c::Bnd/lo was) (:c::cmp-lo op n then?))
                          hi (:c::imin (:c::Bnd/hi was) (:c::cmp-hi op n then?))]
          (:wat::core::if (:wat::core::> lo hi) bs
            (:c::bnd-put bs (:c::text pg x) lo hi)))))))

;; ---------------------------------------------------------------- the counted loop
;;
;; **A loop counter has a range, and it is the only thing in these programs that does.** F-130
;; measured the overflow checks at 32% of a throughput-bound loop; the probe that priced this
;; work found that an interval analysis proves four of `triple`'s seven and none of the other
;; three, because the accumulators grow by 89 million an iteration and no interval ever closes
;; on them. The four it does prove are the three `(* i C)` and the `(- i 1)`, and all four rest
;; on one fact: `i` is between zero and where it started.
;;
;; **The invariant is asserted and checked, not discovered.** A widening fixpoint would throw the
;; lower bound to negative infinity on its first step and narrowing would not bring it back --
;; and it would be RIGHT to, because `(user/go -1 ...)` really does run away. What makes the
;; bound true is the entry literal, so the rule reads the entry, claims `[0, E]`, and checks the
;; claim survives one step:
;;
;;   * every call to `f` from outside `f` passes an int literal `E >= 0` for this parameter;
;;   * every self call passes `(- p K)` for it, with `K` a positive literal dividing every `E`;
;;   * the body is `(if (= p 0) base rec)`, so a step only happens when `p` is not zero.
;;
;; Then `p` in `[0,E]` and `p != 0` gives `p-1` in `[0,E]`, which is the induction, and the
;; divisibility is what stops a counter stepping over zero and running to the floor. Any
;; condition that does not hold returns top and the checks stay: every way of failing to
;; recognise the shape fails toward keeping the check.
(:wat::core::defn :c::lit-arg [a <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::= (:c::kind a pg) "int"))

;; does every call to `name` inside node `a` pass a literal in `[0,..]` divisible by `K` at
;; position `j`? Returns the largest such literal, or -1 the moment one does not qualify.
(:wat::core::defn :c::entry-max [a <- :wat::core::i64 name <- :wat::core::String
                                 j <- :wat::core::i64 k <- :wat::core::i64
                                 best <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::< best 0) -1
    (:wat::core::if (:wat::core::not= (:c::kind a pg) "list")
      (:c::entry-kids (:c::kidsof pg a) 0 name j k best pg)
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) best
          (:wat::core::if (:wat::core::not= (:c::text pg (:wat::core::nth ks 0)) name)
            (:c::entry-kids ks 0 name j k best pg)
            ;; a call to it: the argument at `j` decides, and the other arguments still count
            (:wat::core::if (:wat::core::<= (:wat::core::length ks) (:wat::core::+ j 1)) -1
              (:wat::core::let [arg (:wat::core::nth ks (:wat::core::+ j 1))]
                (:wat::core::if (:wat::core::not (:c::lit-arg arg pg)) -1
                  (:wat::core::let [v (:c::to-int (:c::text pg arg) pg)]
                    (:wat::core::if (:wat::core::or (:wat::core::< v 0)
                                                    (:wat::core::not= (:wat::core::rem v k) 0)) -1
                      (:c::entry-kids ks 1 name j k (:c::imax best v) pg))))))))))))
(:wat::core::defn :c::entry-kids [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                  j <- :wat::core::i64 k <- :wat::core::i64
                                  best <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::or (:wat::core::< best 0)
                                  (:wat::core::>= i (:wat::core::length ks))) best
    (:c::entry-kids ks (:wat::core::+ i 1) name j k
      (:c::entry-max (:wat::core::nth ks i) name j k best pg) pg)))

;; across every OTHER function in the program
(:wat::core::defn :c::entry-all [fns <- :c::FnV i <- :wat::core::i64 self <- :wat::core::i64
                                 name <- :wat::core::String j <- :wat::core::i64
                                 k <- :wat::core::i64 best <- :wat::core::i64
                                 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::or (:wat::core::< best 0)
                                  (:wat::core::>= i (:wat::core::length fns))) best
    (:c::entry-all fns (:wat::core::+ i 1) self name j k
      (:wat::core::if (:wat::core::= i self) best
        (:c::entry-max (:c::Fn/node (:wat::core::nth fns i)) name j k best pg)) pg)))

;; the step every self call takes at position `j`: `K` when they all pass `(- p K)` with the
;; same positive literal `K`, and 0 when any of them does anything else
(:wat::core::defn :c::step-of [a <- :wat::core::i64 name <- :wat::core::String
                               p <- :wat::core::String j <- :wat::core::i64
                               k <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) 0
    (:wat::core::if (:wat::core::not= (:c::kind a pg) "list")
      (:c::step-kids (:c::kidsof pg a) 0 name p j k pg)
      (:wat::core::let [ks (:c::kidsof pg a)]
        (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) k
          (:wat::core::if (:wat::core::not= (:c::text pg (:wat::core::nth ks 0)) name)
            (:c::step-kids ks 0 name p j k pg)
            (:wat::core::if (:wat::core::<= (:wat::core::length ks) (:wat::core::+ j 1)) 0
              (:wat::core::let [arg (:wat::core::nth ks (:wat::core::+ j 1))]
                (:wat::core::if (:wat::core::not= (:c::kind arg pg) "list") 0
                  (:wat::core::let [aks (:c::kidsof pg arg)]
                    (:wat::core::if (:wat::core::not= (:wat::core::length aks) 3) 0
                      (:wat::core::if
                        (:wat::core::not
                          (:wat::core::and
                            (:wat::core::= (:c::binop (:c::text pg (:wat::core::nth aks 0))) "-")
                            (:wat::core::and
                              (:wat::core::= (:c::text pg (:wat::core::nth aks 1)) p)
                              (:wat::core::= (:c::kind (:wat::core::nth aks 2) pg) "int")))) 0
                        (:wat::core::let [d (:c::to-int (:c::text pg (:wat::core::nth aks 2)) pg)]
                          (:wat::core::if (:wat::core::or (:wat::core::<= d 0)
                                            (:wat::core::and (:wat::core::not= k -1)
                                                             (:wat::core::not= d k))) 0
                            (:c::step-kids ks 1 name p j d pg)))))))))))))))
(:wat::core::defn :c::step-kids [ks <- :c::Kids i <- :wat::core::i64 name <- :wat::core::String
                                 p <- :wat::core::String j <- :wat::core::i64
                                 k <- :wat::core::i64 pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::if (:wat::core::or (:wat::core::= k 0)
                                  (:wat::core::>= i (:wat::core::length ks))) k
    (:c::step-kids ks (:wat::core::+ i 1) name p j
      (:c::step-of (:wat::core::nth ks i) name p j k pg) pg)))

;; the body is `(if (= p 0) base rec)` -- so no step is taken while `p` is zero
(:wat::core::defn :c::zero-guard? [ks <- :c::Kids start <- :wat::core::i64
                                   p <- :wat::core::String pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::and (:wat::core::= start (:wat::core::- (:wat::core::length ks) 1))
    (:wat::core::let [a (:wat::core::nth ks start)]
      (:wat::core::and (:wat::core::= (:c::kind a pg) "list")
        (:wat::core::let [bs (:c::kidsof pg a)]
          (:wat::core::and (:wat::core::= (:wat::core::length bs) 4)
            (:wat::core::and (:c::if? (:c::text pg (:wat::core::nth bs 0)))
              (:wat::core::let [c (:wat::core::nth bs 1)]
                (:wat::core::and (:wat::core::= (:c::kind c pg) "list")
                  (:wat::core::let [cks (:c::kidsof pg c)]
                    (:wat::core::and (:wat::core::= (:wat::core::length cks) 3)
                      (:wat::core::and
                        (:wat::core::= (:c::binop (:c::text pg (:wat::core::nth cks 0))) "=")
                        (:wat::core::and
                          (:wat::core::= (:c::text pg (:wat::core::nth cks 1)) p)
                          (:wat::core::and
                            (:wat::core::= (:c::kind (:wat::core::nth cks 2) pg) "int")
                            (:wat::core::= (:c::to-int (:c::text pg (:wat::core::nth cks 2)) pg)
                                           0)))))))))))))))

;; the bound for one parameter, or top
(:wat::core::defn :c::counted [ks <- :c::Kids start <- :wat::core::i64
                               pv <- :c::Kids j <- :wat::core::i64 name <- :wat::core::String
                               self <- :wat::core::i64 pg <- :c::Prog] -> :c::Bnd
  (:wat::core::let [p (:c::text pg (:wat::core::nth pv (:wat::core::* 3 j)))]
    (:wat::core::if (:wat::core::not (:c::zero-guard? ks start p pg)) (:c::bnd-any)
      ;; -1 is "no self call seen yet", which is NOT the same as "seen a step of one" -- a
      ;; function whose calls step by 1 and by 5 must be refused, and it only is if the first
      ;; site can be told from the starting value
      (:wat::core::let [k0 (:c::step-of (:wat::core::nth ks start) name p j -1 pg)
                        k (:wat::core::if (:wat::core::= k0 -1) 1 k0)]
        (:wat::core::if (:wat::core::<= k 0) (:c::bnd-any)
          (:wat::core::let [e (:c::entry-all (:c::Prog/fns pg) 0 self name j k 0 pg)]
            (:wat::core::if (:wat::core::< e 0) (:c::bnd-any)
              ;; **the induction is about the PROGRESSION, not the interval.** The reachable
              ;; values are `{0, k, 2k, ... e}` -- `p` enters as a non-negative multiple of `k`
              ;; and only steps while it is non-zero, so it is always at least `k` when it
              ;; steps and lands on `0` rather than stepping past it. `[0,e]` is the interval
              ;; that covers that set. Divisibility is what puts `0` IN the set: from 10 by 3
              ;; the counter goes 10, 7, 4, 1, -2 and runs to the floor, which is why
              ;; `:c::entry-all` refuses an entry literal `k` does not divide.
              (:c::Bnd :name p :lo 0 :hi e))))))))

(:wat::core::defn :c::counted-all [ks <- :c::Kids start <- :wat::core::i64
                                   pv <- :c::Kids j <- :wat::core::i64 n <- :wat::core::i64
                                   name <- :wat::core::String self <- :wat::core::i64
                                   acc <- :c::Bnds pg <- :c::Prog] -> :c::Bnds
  (:wat::core::if (:wat::core::>= j n) acc
    (:wat::core::let [b (:c::counted ks start pv j name self pg)]
      (:c::counted-all ks start pv (:wat::core::+ j 1) n name self
        (:wat::core::if (:c::bnd-top? b) acc
          (:c::bnd-put acc (:c::Bnd/name b) (:c::Bnd/lo b) (:c::Bnd/hi b)))
        pg))))

(:wat::core::defn :c::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

(:wat::core::defn :c::imax0 [a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a 0) 0 a))

(:wat::core::defn :c::reg-saves [i <- :wat::core::i64 nr <- :wat::core::i64
                                 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i nr) acc
    (:c::reg-saves (:wat::core::+ i 1) nr (:wat::string::concat acc (:c::reg-push i)))))

(:wat::core::defn :c::reg-restores [i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::< i 0) acc
    (:c::reg-restores (:wat::core::- i 1) (:wat::string::concat acc (:c::reg-pop i)))))

(:wat::core::defn :c::reg-loads [pv <- :c::Kids i <- :wat::core::i64 n <- :wat::core::i64
                                 nr <- :wat::core::i64 pg <- :c::Prog k <- :wat::core::i64
                                 fp? <- :wat::core::bool
                                 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i nr) acc
    (:c::reg-loads pv (:wat::core::+ i 1) n nr pg k fp?
      (:wat::string::concat acc
        (:c::reg-load i (:wat::core::+ k
          (:wat::core::+ (:wat::core::if fp? 16 8)
                         (:wat::core::* 8 (:wat::core::- (:wat::core::- n 1) i)))) fp?)))))

;; ---------------------------------------------------------------- shrink-wrapping
;;
;; **A base case pays for a frame it never uses.** `(defn fib [n] (if (< n 2) n ...))` returns a
;; parameter, and to do it the callee was executing `sub rsp,32`, four pushes, a parameter load,
;; the test, four pops, `add rsp,32` and `ret` -- fourteen instructions to hand back the argument
;; it was given. The profile of `fib(32)` says that path is taken by **63% of 1,298,098 calls**:
;; `cmp $2,%rbx` and `sub $0x20,%rsp` are the two hottest instructions in the program, because
;; both are the target of a call and both are on the way to doing nothing.
;;
;; So the test goes FIRST, before there is a frame, reading the argument where the caller left
;; it; and the prologue happens only on the path that needs it. That is shrink-wrapping, and the
;; condition for it is narrow on purpose: the arm that returns early must be a parameter or a
;; literal, so that computing it needs no frame, no register and no call.
(:wat::core::defn :c::param-of? [a <- :wat::core::i64 pv <- :c::Kids i <- :wat::core::i64
                                 pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length pv)) false
    (:wat::core::or (:wat::core::= (:c::text pg a) (:c::text pg (:wat::core::nth pv i)))
                    (:c::param-of? a pv (:wat::core::+ i 3) pg))))

;; a value the early return can produce with nothing but the incoming stack
(:wat::core::defn :c::wrap-val? [a <- :wat::core::i64 pv <- :c::Kids pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::or (:wat::core::= (:c::kind a pg) "int")
    (:wat::core::and (:wat::core::= (:c::kind a pg) "symbol") (:c::param-of? a pv 0 pg))))

;; the whole body is one `if`, its test is a machine-word comparison, and its THEN arm is a value
;; the early return can produce. `env0` is the parameters addressed from the frame, which is what
;; they are before the prologue has moved any of them into registers.
(:wat::core::defn :c::wrappable? [ks <- :c::Kids start <- :wat::core::i64 pv <- :c::Kids
                                  env0 <- :c::Env pg <- :c::Prog] -> :wat::core::bool
  (:wat::core::and (:wat::core::= start (:wat::core::- (:wat::core::length ks) 1))
    (:wat::core::let [a (:wat::core::nth ks start)]
      (:wat::core::and (:wat::core::= (:c::kind a pg) "list")
        (:wat::core::let [bs (:c::kidsof pg a)]
          (:wat::core::and (:wat::core::= (:wat::core::length bs) 4)
            (:wat::core::and (:c::if? (:c::text pg (:wat::core::nth bs 0)))
              (:wat::core::and
                (:wat::core::not= (:c::cmp-cond (:wat::core::nth bs 1) env0 pg) "")
                (:c::wrap-val? (:wat::core::nth bs 2) pv pg)))))))))

;; the test and the early return, emitted before there is a frame: compare, branch over, compute
;; the value into rax, `ret`. rsp is untouched, so the `ret` needs no epilogue at all.
(:wat::core::defn :c::wrap-head [bs <- :c::Kids o <- :c::Out env0 <- :c::Env pg <- :c::Prog
                                 rt <- :c::Layout tb <- :wat::core::i64] -> :c::Out
  (:wat::core::let
    [op (:c::cmp-cond (:wat::core::nth bs 1) env0 pg)
     cks (:c::kidsof pg (:wat::core::nth bs 1))
     o1 (:c::expr (:wat::core::nth cks 1) o env0 pg rt tb 0 (:c::no-tail))
     fast (:c::cmp-only (:wat::core::nth cks 2) env0 pg (:c::fp-adj o1) (:c::Out/fpr o1))
     o2 (:wat::core::if (:wat::core::not= fast "") (:c::emit o1 fast)
          (:wat::core::let
            [p1 (:c::push o1 (:c::push-rax) 8)
             p2 (:c::expr (:wat::core::nth cks 2) p1 env0 pg rt tb 0 (:c::no-tail))]
            (:c::popn p2 (:wat::string::concat "4889c1" (:c::pop-rax) "4839c8") 8)))
     ;; `:c::wrap-val?` already guarantees a name or a constant, and what follows it is one
     ;; byte of `ret` -- the shortest branch in the compiler
     o3 (:c::emit o2 (:wat::string::concat (:c::jcc-not8 op) "00"))
     ;; neither the compare nor the branch writes rax, so it still holds the left operand -- and
     ;; the value being returned is usually that same parameter, which is then already there.
     ;; C-149's reasoning, in the one place that reads a parameter twice in three instructions.
     o3k (:wat::core::if (:wat::core::not= fast "")
           (:wat::core::assoc o3 :rax (:c::Out/rax o1)) o3)
     at (:wat::core::- (:c::codelen o3k) 1)
     o4 (:c::expr (:wat::core::nth bs 2) o3k env0 pg rt tb 0 (:c::no-tail))
     o5 (:c::emit o4 (:c::ret))]
    (:c::patch o5 at (:asm::le (:wat::core::- (:c::codelen o5) (:wat::core::+ at 1)) 1))))

;; ---------------------------------------------------------------- one field, in the parameter's register
;;
;; A record parameter whose every use is a read or an `assoc` of ONE field does not need the
;; pointer. The register already assigned to the parameter holds the field: the prologue loads
;; it once, a field read is that register, an `assoc` is a write of it, and a tail self-call
;; passes it back. The back edge jumps to the body, so it skips the load -- the caller still
;; passed a pointer, and only the loop carries the field.
;;
;; `:c::occ` maxes the arms of an `if`, because it asks how many reads the worst path takes.
;; This asks whether ANY arm escapes, so the arms are unioned. A mention the three existing
;; walks cannot classify -- a bare name that is not the container of an `assoc` and not the
;; operand of the one field's reader -- is the record leaving, and that is `other`.

(:wat::core::defrecord :c::Use [k <- :wat::core::i64 f <- :wat::core::i64])
(:wat::core::defrecord :c::Sc
  [names <- (:wat::core::Vector :- [:wat::core::String])
   fields <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :c::use-none [] -> :c::Use (:c::Use :k 0 :f -1))
(:wat::core::defn :c::use-other [] -> :c::Use (:c::Use :k 2 :f -1))
(:wat::core::defn :c::use-field [f <- :wat::core::i64] -> :c::Use (:c::Use :k 1 :f f))

(:wat::core::defn :c::use-union [a <- :c::Use b <- :c::Use] -> :c::Use
  (:wat::core::cond
    ((:wat::core::or (:wat::core::= (:c::Use/k a) 2) (:wat::core::= (:c::Use/k b) 2))
      (:c::use-other))
    ((:wat::core::= (:c::Use/k a) 0) b)
    ((:wat::core::= (:c::Use/k b) 0) a)
    ((:wat::core::= (:c::Use/f a) (:c::Use/f b)) a)
    (:else (:c::use-other))))

(:wat::core::defn :c::scalar-field [pg <- :c::Prog name <- :wat::core::String
                                    i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length (:c::Prog/scalar pg))) -1)
    ((:wat::core::= (:wat::core::nth (:c::Prog/scalar pg) i) name)
      (:wat::core::nth (:c::Prog/sfield pg) i))
    (:else (:c::scalar-field pg name (:wat::core::+ i 1)))))

;; `as-arg` means this expression is an argument of a tail self-call, so its value is the
;; field, not a pointer the callee will load through. A bare name there is the field already
;; in the register. Anywhere else a bare name is the record escaping.
(:wat::core::defn :c::use-walk [pg <- :c::Prog a <- :wat::core::i64 name <- :wat::core::String
                                fname <- :wat::core::String rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "symbol")
        (:wat::core::if (:wat::core::= (:c::text pg a) name)
          (:wat::core::if as-arg (:c::use-none) (:c::use-other))
          (:c::use-none)))
      ((:wat::core::= k "vector")
        (:c::use-fold pg (:c::kidsof pg a) 0 name fname rname false false))
      ((:wat::core::not= k "list") (:c::use-none))
      (:else (:c::use-form pg (:c::kidsof pg a) name fname rname in-tail as-arg)))))

(:wat::core::defn :c::use-fold [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::use-none)
    (:c::use-union
      (:c::use-walk pg (:wat::core::nth ks i) name fname rname in-tail as-arg)
      (:c::use-fold pg ks (:wat::core::+ i 1) name fname rname in-tail as-arg))))

;; both arms, not the worse one. `occ` maxes; an escape on either arm escapes.
(:wat::core::defn :c::use-both [pg <- :c::Prog a <- :wat::core::i64 b <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:c::use-union
    (:c::use-walk pg a name fname rname in-tail as-arg)
    (:c::use-walk pg b name fname rname in-tail as-arg)))

(:wat::core::defn :c::use-last [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::use-none)
    (:wat::core::let [last? (:wat::core::= i (:wat::core::- (:wat::core::length ks) 1))]
      (:c::use-union
        (:c::use-walk pg (:wat::core::nth ks i) name fname rname
          (:wat::core::and in-tail last?)
          (:wat::core::and as-arg last?))
        (:c::use-last pg ks (:wat::core::+ i 1) name fname rname in-tail as-arg)))))

(:wat::core::defn :c::use-cond [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::use-none)
    (:c::use-union
      (:c::use-clause pg (:wat::core::nth ks i) name fname rname in-tail as-arg)
      (:c::use-cond pg ks (:wat::core::+ i 1) name fname rname in-tail as-arg))))

(:wat::core::defn :c::use-clause [pg <- :c::Prog a <- :wat::core::i64 name <- :wat::core::String
                                  fname <- :wat::core::String rname <- :wat::core::String
                                  in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::if (:wat::core::not= (:c::kind a pg) "list")
    (:c::use-walk pg a name fname rname false false)
    (:wat::core::let [cks (:c::kidsof pg a)]
      (:wat::core::if (:wat::core::< (:wat::core::length cks) 1) (:c::use-none)
        (:c::use-union
          (:c::use-walk pg (:wat::core::nth cks 0) name fname rname false false)
          (:c::use-last pg cks 1 name fname rname in-tail as-arg))))))

(:wat::core::defn :c::use-args [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String] -> :c::Use
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::use-none)
    (:c::use-union
      (:c::use-walk pg (:wat::core::nth ks i) name fname rname false true)
      (:c::use-args pg ks (:wat::core::+ i 1) name fname rname))))

(:wat::core::defn :c::kw-field [pg <- :c::Prog rname <- :wat::core::String
                                kw <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [ri (:c::rec-index (:c::Prog/recs pg) rname 0)
                    tx (:c::text pg kw)]
    (:wat::core::if (:wat::core::or (:wat::core::< ri 0)
                      (:wat::core::not= (:c::kind kw pg) "keyword")) -1
      (:c::field-index (:c::Rec/fields (:wat::core::nth (:c::Prog/recs pg) ri))
        (:wat::string::subs tx 1 (:wat::string::length tx)) 0))))

(:wat::core::defn :c::use-form [pg <- :c::Prog ks <- :c::Kids name <- :wat::core::String
                                fname <- :wat::core::String rname <- :wat::core::String
                                in-tail <- :wat::core::bool as-arg <- :wat::core::bool] -> :c::Use
  (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) (:c::use-none)
    (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))]
      (:wat::core::cond
        ;; `(:R/f name)` -- the operand is the parameter, so it is not a bare mention
        ((:wat::core::and (:wat::core::>= (:c::acc-index pg head) 0)
                          (:wat::core::= (:wat::core::length ks) 2)
                          (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                          (:wat::core::= (:c::text pg (:wat::core::nth ks 1)) name))
          (:wat::core::let [at (:c::slash-at head (:wat::core::- (:wat::string::length head) 1))]
            (:wat::core::if (:wat::core::or (:wat::core::< at 0)
                              (:wat::core::not= (:wat::string::subs head 0 at) rname))
              (:c::use-other)
              (:c::use-field (:c::acc-index pg head)))))
        ;; `(assoc name :f v)` is a write only when THIS value is handed to the tail self-call.
        ;; anywhere else the result is a record, and the register no longer holds one.
        ((:wat::core::and (:c::assoc? head)
                          (:wat::core::= (:wat::core::length ks) 4)
                          (:wat::core::= (:c::kind (:wat::core::nth ks 1) pg) "symbol")
                          (:wat::core::= (:c::text pg (:wat::core::nth ks 1)) name))
          (:wat::core::if (:wat::core::not as-arg) (:c::use-other)
            (:wat::core::let [fi (:c::kw-field pg rname (:wat::core::nth ks 2))]
              (:wat::core::if (:wat::core::< fi 0) (:c::use-other)
                (:c::use-union (:c::use-field fi)
                  (:c::use-walk pg (:wat::core::nth ks 3) name fname rname false false))))))
        ((:wat::core::and (:c::if? head) (:wat::core::= (:wat::core::length ks) 4))
          (:c::use-union
            (:c::use-walk pg (:wat::core::nth ks 1) name fname rname false false)
            (:c::use-both pg (:wat::core::nth ks 2) (:wat::core::nth ks 3)
              name fname rname in-tail as-arg)))
        ((:c::do? head)
          (:c::use-last pg ks 1 name fname rname in-tail as-arg))
        ((:wat::core::and (:c::let? head) (:wat::core::>= (:wat::core::length ks) 2))
          (:c::use-union
            (:c::use-walk pg (:wat::core::nth ks 1) name fname rname false false)
            (:c::use-last pg ks 2 name fname rname in-tail as-arg)))
        ((:c::cond? head)
          (:c::use-cond pg ks 1 name fname rname in-tail as-arg))
        ((:wat::core::or (:c::and? head) (:c::or? head))
          (:wat::core::if as-arg
            (:c::use-fold pg ks 1 name fname rname false true)
            (:c::use-last pg ks 1 name fname rname in-tail false)))
        ;; a self-call outside tail position re-enters the prologue, which still expects a pointer
        ((:wat::core::= head fname)
          (:wat::core::if (:wat::core::not in-tail) (:c::use-other)
            (:c::use-args pg ks 1 name fname rname)))
        (:else (:c::use-fold pg ks 1 name fname rname false false))))))

(:wat::core::defn :c::use-body [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                name <- :wat::core::String fname <- :wat::core::String
                                rname <- :wat::core::String] -> :c::Use
  (:c::use-last pg ks i name fname rname true false))

(:wat::core::defn :c::scalar-params [pv <- :c::Kids i <- :wat::core::i64 ks <- :c::Kids
                                     start <- :wat::core::i64 fname <- :wat::core::String
                                     env <- :c::Env pg <- :c::Prog
                                     names <- (:wat::core::Vector :- [:wat::core::String])
                                     fields <- (:wat::core::Vector :- [:wat::core::i64])] -> :c::Sc
  (:wat::core::if (:wat::core::>= i (:wat::core::length pv))
    (:c::Sc :names names :fields fields)
    (:wat::core::let
      [nm (:c::text pg (:wat::core::nth pv i))
       ei (:wat::core::- (:wat::core::length env) 1)
       ty (:c::lookup-ty env nm ei)
       reg (:c::lookup-reg env nm ei)
       rn (:c::rec-name-of ty)
       go? (:wat::core::and (:wat::core::>= reg 0) (:wat::core::not= rn ""))
       u (:wat::core::if go?
           (:c::use-body pg ks start nm fname rn) (:c::use-none))
       take? (:wat::core::= (:c::Use/k u) 1)]
      (:c::scalar-params pv (:wat::core::+ i 3) ks start fname env pg
        (:wat::core::if take? (:wat::core::conj names nm) names)
        (:wat::core::if take? (:wat::core::conj fields (:c::Use/f u)) fields)))))

(:wat::core::defn :c::scalar-of [pv <- :c::Kids ks <- :c::Kids start <- :wat::core::i64
                                 fname <- :wat::core::String env <- :c::Env pg <- :c::Prog] -> :c::Sc
  (:wat::core::if (:wat::string::starts-with? (:c::fn-ret pg fname 0) "rec:")
    (:c::Sc :names (:wat::core::Vector :- [:wat::core::String])
            :fields (:wat::core::Vector :- [:wat::core::i64]))
    (:c::scalar-params pv 0 ks start fname env pg
      (:wat::core::Vector :- [:wat::core::String])
      (:wat::core::Vector :- [:wat::core::i64]))))

(:wat::core::defn :c::scalar-bytes [env <- :c::Env names <- (:wat::core::Vector :- [:wat::core::String])
                                    fields <- (:wat::core::Vector :- [:wat::core::i64])
                                    i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:wat::core::length names)) ""
    (:wat::core::let
      [r (:c::lookup-reg env (:wat::core::nth names i)
           (:wat::core::- (:wat::core::length env) 1))
       d (:wat::core::+ 8 (:wat::core::* 8 (:wat::core::nth fields i)))]
      (:wat::string::concat
        (:wat::core::if (:wat::core::>= r 0) (:c::mov-rm r d r) "")
        (:c::scalar-bytes env names fields (:wat::core::+ i 1))))))

(:wat::core::defn :c::compile-fn [node <- :wat::core::i64 base <- :wat::core::i64 pg <- :c::Prog
                                  rt <- :c::Layout tb <- :wat::core::i64
                                  tail-in <- :c::Buf] -> :c::Out
  (:wat::core::let
    [ks (:c::kidsof pg node)
     pv (:c::kidsof pg (:wat::core::nth ks 2))
     n (:c::nparams pv)
     ;; a function that clones is excluded for the same reason it is excluded from tail calls:
     ;; the child inherits the frame, and moving a parameter into a register moves it out of
     ;; the place the child reads it from
     start (:c::body-start ks 3 pg)
     slots (:c::slots-body ks start 0 pg)
     ;; **C-136 gave parameters registers only to a function with a self tail call**, because the
     ;; prologue cost is per call and the benefit per iteration -- measured, and right at the
     ;; time. C-146 changed the premise: a function with `let` bindings is already saving those
     ;; registers, so the push and the pop are already bought and a parameter's register now
     ;; costs one `mov` in the prologue and saves a frame load at every read. `fib` was loading
     ;; `n` back three times a level with rbx, r12 and r13 already pushed above it.
     regs? (:wat::core::and
             (:wat::core::not (:c::has-clone? node pg))
             (:wat::core::or
               (:c::tail-self? (:wat::core::nth ks (:wat::core::- (:wat::core::length ks) 1))
                               (:c::text pg (:wat::core::nth ks 1)) n pg)
               (:wat::core::> slots 0)))
     nr (:wat::core::if regs? (:c::imin n (:c::nregs)) 0)
     env (:c::param-env pv 0 n (:wat::core::Vector :- [:c::Bind]) pg regs?)
     fname (:c::text pg (:wat::core::nth ks 1))
     sc (:c::scalar-of pv ks start fname env pg)
     ;; **the registers a parameter did not take, `let` can have.** C-142's inlining turns every
     ;; inlined call into a `let`, and each of those bindings was round-tripping through a frame
     ;; slot -- a store and a load per read -- where gcc keeps the value in a register. Excluded
     ;; for a function that clones, for C-136's reason exactly: the child inherits the frame, so
     ;; a value moved out of it is a value the child cannot see.
     ;; **and r8-r11 on top of them, when no call will ever return into this function.**
     ;; See `:c::callfree?`: those four need no saving and no restoring, so the only cost of
     ;; using them is that the scratch pool has fewer -- which is why `nscr` goes down by
     ;; exactly as many as the bindings take.
     free? (:wat::core::and (:wat::core::not (:c::has-clone? node pg))
             (:c::callfree? ks start (:c::text pg (:wat::core::nth ks 1)) n env pg))
     nlr (:wat::core::if (:c::has-clone? node pg) 0
           (:c::imin (:wat::core::+ (:wat::core::- (:c::nregs) nr)
                       (:wat::core::if free? (:c::nscratch) 0))
                     slots))
     ;; the pushes and pops cover the callee-saved four and stop there
     nsave (:c::imin (:c::nregs) (:wat::core::+ nr nlr))
     ;; what is left of the pool after the bindings have taken theirs. The two groups are the
     ;; same four registers approached from opposite ends -- bindings count up from r8, the
     ;; pool counts down from r11 -- so they meet in the middle and never overlap.
     nscr (:wat::core::- (:c::nscratch)
            (:c::imax0 (:wat::core::- (:wat::core::+ nr nlr) (:c::nregs))))
     ;; the System V ABI wants rsp 16-byte aligned at a call, so the frame is rounded up
     frame (:wat::core::* 8 (:wat::core::if (:wat::core::= (:wat::core::rem slots 2) 0) slots
                              (:wat::core::+ slots 1)))
     ;; **the frame pointer is gone except where `clone` needs it.** Without it a local is
     ;; addressed from rsp, which costs a SIB byte and a depth the emitter has to track -- and
     ;; buys `rbp` as a fourth callee-saved register plus two instructions off every call.
     fpr? (:c::has-clone? node pg)
     ;; **where rbp WOULD point, measured from rsp at the top of the body.** `push rbp` used to
     ;; put it eight bytes below the return address, and the frame and the saved registers below
     ;; that -- so without the push the whole frame moves up by those eight bytes, and forgetting
     ;; them puts every parameter one slot out.
     fkv (:wat::core::if fpr? 0
           (:wat::core::+ frame (:wat::core::* 8 nsave)))
     o0 (:c::Out :base base :code (:c::buf0) :tail tail-in :rax "" :sp 0 :fpr fpr? :fk fkv)
     ;; **before the frame exists, the parameters are still where the caller put them**, so this
     ;; environment addresses them from the incoming rsp and `fk` is zero. `fpr?` is excluded
     ;; because a cloning function keeps its frame pointer and its parameters with it.
     env0 (:c::param-env pv 0 n (:wat::core::Vector :- [:c::Bind]) pg false)
     ;; ...and no registers have been handed out yet either, so the peeled head is compiled
     ;; against a program that says so. `pg` still carries the PREVIOUS function's `nlr` and
     ;; `regbase` at this point -- harmless while the pool was a constant four, and not harmless
     ;; now that a binding can reach into it.
     pgw (:wat::core::assoc (:wat::core::assoc (:wat::core::assoc
            (:wat::core::assoc pg :bnds (:wat::core::Vector :- [:c::Bnd])) :nlr 0) :regbase 0)
            :nscr (:c::nscratch))
     ;; **not a function with a self tail call.** C-121 makes such a call a `jmp` to the end of
     ;; the prologue -- and the test now lives BEFORE the prologue, so the jump would skip it and
     ;; the loop would never end (`elf/src/vectors.wat` hangs). It would buy nothing there in any
     ;; case: a loop pays its prologue once per call, not once per iteration.
     wrap? (:wat::core::and (:wat::core::not fpr?)
             (:wat::core::and
               (:wat::core::not (:c::tail-self? (:wat::core::nth ks (:wat::core::- (:wat::core::length ks) 1))
                                  (:c::text pg (:wat::core::nth ks 1)) n pg))
               (:c::wrappable? ks start pv env0 pgw)))
     ;; **fk is zero here and `fkv` afterwards.** Before the prologue rsp still points at the
     ;; return address, so an argument is eight bytes up; after it, the frame and the saved
     ;; registers are in between. Getting this wrong reads the argument at the offset it will
     ;; have LATER, which is a load from the caller's frame.
     ow (:wat::core::if wrap?
          (:wat::core::assoc
            (:c::wrap-head (:c::kidsof pg (:wat::core::nth ks start))
              (:wat::core::assoc o0 :fk 0) env0 pgw rt tb)
            :fk fkv)
          o0)
     ;; make room / save the registers this function will use / load the parameters into them.
     ;; The saves come AFTER the frame so that a `let` slot does not land on a saved register.
     o1 (:c::emit ow (:wat::string::concat
                       (:wat::core::if fpr? (:wat::string::concat "55" "4889e5") "")
                       (:c::sub-rsp frame)
                       (:c::reg-saves 0 nsave "")
                       (:c::reg-loads pv 0 n nr pg fkv fpr? "")
                       ;; after the pointer is in its register, and BEFORE the tail target,
                       ;; so the call from outside loads the field once and the back edge
                       ;; jumps over the load carrying the field
                       (:c::scalar-bytes env (:c::Sc/names sc) (:c::Sc/fields sc) 0)))
     ;; the top of the body is wherever the prologue ended -- which is NOT a constant any more,
     ;; now that `sub rsp` is one byte of displacement when it fits and nothing at all when the
     ;; frame is empty. It used to be hardcoded as eleven, and the first build after the short
     ;; forms went in jumped every self tail call into the middle of its own body.
     ;;
     ;; ...unless the function clones. A tail call REUSES the frame, which is sound only while
     ;; the frame is private to this thread -- and `clone` hands a second thread an rbp pointing
     ;; straight at it (the child gets a fresh rsp but inherits rbp). elf/native/threads4.wat is
     ;; the program that proves it: with its `user/spawn` tail call eliminated, the parent
     ;; overwrote `i` while four children were still reading it, and the answer fell from 1000
     ;; to 400. Same shape as `:c::releasable?` and `poke`, and the same lesson: the intrinsics
     ;; break invariants the rest of the compiler is entitled to assume about wat.
     ;; **what this function's own parameters can be**, before a single expression is compiled.
     ;; Only a counted loop has an answer; everything else gets top and keeps its checks.
     bnds0 (:c::counted-all ks start pv 0 n (:c::text pg (:wat::core::nth ks 1))
             (:c::fn-of pg (:c::text pg (:wat::core::nth ks 1)) 0)
             (:wat::core::Vector :- [:c::Bnd]) pg)
     pg (:wat::core::assoc (:wat::core::assoc (:wat::core::assoc
          (:wat::core::assoc (:wat::core::assoc (:wat::core::assoc
            (:wat::core::assoc pg :bnds bnds0) :nscr nscr) :nlr nlr) :regbase nr)
            :scalar (:c::Sc/names sc)) :sfield (:c::Sc/fields sc))
                           :linear (:c::linear-of pv 0 ks start
                                        (:wat::core::Vector :- [:wat::core::String]) pg))
     tc (:wat::core::if (:c::has-clone? node pg)
          (:c::no-tail)
          (:c::TC :name (:c::text pg (:wat::core::nth ks 1)) :arity n :nregs nr
                  :target (:wat::core::+ base (:c::codelen o1)) :test "" :body 0))
     ;; when the head was peeled off, the body is the `if`'s ELSE arm and nothing else
     o2 (:wat::core::if wrap?
          (:c::expr (:wat::core::nth (:c::kidsof pg (:wat::core::nth ks start)) 3)
            o1 env pg rt tb 0 tc)
          (:c::seq ks start o1 env pg rt tb 0 tc))]
    (:c::at-depth0 o2 (:wat::string::concat
      (:c::reg-restores (:wat::core::- nsave 1) "")
      ;; `leave` is `mov rbp,rsp ; pop rbp`; without a frame pointer the same job is one `add`
      (:wat::core::if fpr? "c9" (:c::add-rsp frame)) (:c::ret)))))

;; ---------------------------------------------------------------- the driver
;;
;; Two passes over the WHOLE program, not just one function: a call needs the callee's address,
;; and a callee's address depends on the length of everything before it. Pass one compiles with
;; every address zero, purely to measure; pass two compiles again with the real table. Every
;; immediate and every displacement is fixed width, so the two passes are the same length -- and
;; the compiler asserts that, function by function.

;; a `defrecord`'s field vector reads `name <- type` per field, so names are every third child
;; and types are every third from index two -- the same shape a `defn`'s parameters have
(:wat::core::defn :c::field-names [fv <- :c::Kids i <- :wat::core::i64
                                   acc <- (:wat::core::Vector :- [:wat::core::String]) pg <- :c::Prog]
    -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:wat::core::length fv)) acc
    (:c::field-names fv (:wat::core::+ i 3)
      (:wat::core::conj acc (:c::text pg (:wat::core::nth fv i))) pg)))

(:wat::core::defn :c::field-types [fv <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog
                                   acc <- (:wat::core::Vector :- [:wat::core::String])]
    -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::>= i (:wat::core::length fv)) acc
    (:c::field-types fv (:wat::core::+ i 3) pg
      (:wat::core::conj acc (:c::ty-of-node (:wat::core::nth fv (:wat::core::+ i 2)) pg)))))

;; everything up to and including the last "/", which is what a relative `load-file!` is
;; relative to
(:wat::core::defn :c::dir-of [path <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [at (:c::slash-at path (:wat::core::- (:wat::string::length path) 1))]
    (:wat::core::if (:wat::core::< at 0) "" (:wat::string::subs path 0 (:wat::core::+ at 1)))))

;; the string a `load-file!` names, without its quotes
(:wat::core::defn :c::lit-text [pg <- :c::Prog a <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [src (:c::text pg a)]
    (:wat::string::subs src 1 (:wat::core::- (:wat::string::length src) 1))))

(:wat::core::defn :c::load? [s <- :wat::core::String] -> :wat::core::bool
  (:c::is? s "wat/load-file!" ":wat::load-file!"))

(:wat::core::defn :c::collect [tops <- :c::Kids i <- :wat::core::i64 acc <- :c::Prog] -> :c::Prog
  (:c::collect-in tops i acc ""))

(:wat::core::defn :c::collect-in [tops <- :c::Kids i <- :wat::core::i64 pg <- :c::Prog
                                  dir <- :wat::core::String] -> :c::Prog
  (:wat::core::if (:wat::core::>= i (:wat::core::length tops)) pg
    (:wat::core::let
      [t (:wat::core::nth tops i)
       ks (:c::kidsof pg t)
       head (:wat::core::if (:wat::core::= (:c::kind t pg) "list")
              (:c::text pg (:wat::core::nth ks 0)) "")]
      (:wat::core::cond
        ;; `load-file!` is a compile-time include: read that file, collect ITS top level, and
        ;; carry on. Relative to the file that names it, the way the interpreter resolves it.
        ((:c::load? head)
          (:wat::core::let
            [path (:wat::string::concat dir (:c::lit-text pg (:wat::core::nth ks 1)))
             ;; read it into the SAME arena, so node indices from every file a program is made
             ;; of live in one space -- two arenas would give two node 7s
             st2 (rd/read-into (:rd::St/arena (:c::Prog/src pg)) (:wat::io::read-file path))
             pg2 (:wat::core::assoc pg :src st2)]
            (:c::collect-in tops (:wat::core::+ i 1)
              (:c::collect-in (:rd::St/kids st2) 0 pg2 (:c::dir-of path))
              dir)))
        ;; **a primitive's wat definition is for the interpreter, and is skipped here.** That is
        ;; the contract stated plainly: `prim/write-hex` and `prim/read-hex` mean the same thing
        ;; in both worlds, and each world supplies its own implementation. Without this the
        ;; compiler would try to compile the interpreter's version, which uses `match` and
        ;; `Bytes::from-hex` and is exactly what a compiled program cannot reach (F-119).
        ((:wat::core::and (:c::defn? head)
           (:c::prim-name? (:c::text pg (:wat::core::nth ks 1))))
          (:c::collect-in tops (:wat::core::+ i 1) pg dir))
        ((:c::defn? head)
          (:c::collect-in tops (:wat::core::+ i 1)
            (:wat::core::assoc pg :fns
              (:wat::core::conj (:c::Prog/fns pg)
                ;; the return TYPE waits until every record and alias has been seen -- a type
                ;; is allowed to be declared after the function that uses it, as it is in wat
                (:c::Fn :name (:c::text pg (:wat::core::nth ks 1)) :node t :addr 0 :ret "")))
            dir))
        ((:c::defrecord? head)
          (:wat::core::let [fv (:c::kidsof pg (:wat::core::nth ks 2))]
            (:c::collect-in tops (:wat::core::+ i 1)
              (:wat::core::assoc pg :recs
                (:wat::core::conj (:c::Prog/recs pg)
                  (:c::Rec :name (:c::text pg (:wat::core::nth ks 1)) :fv (:wat::core::nth ks 2)
                           :fields (:c::field-names fv 0 (:wat::core::Vector :- [:wat::core::String]) pg)
                           :ftypes (:wat::core::Vector :- [:wat::core::String]))))
              dir)))
        ((:c::typealias? head)
          (:c::collect-in tops (:wat::core::+ i 1)
            (:wat::core::assoc pg :aliases
              (:wat::core::conj (:c::Prog/aliases pg)
                (:c::Alias :name (:c::text pg (:wat::core::nth ks 1))
                           :node (:wat::core::nth ks 2))))
            dir))
        (:else
          (:wat::kernel::assertion-failed!
            :message (:wat::string::concat
                       "compile: only defn, defrecord, typealias and load-file! at the top level: "
                       (:c::text pg t))))))))

;; one pass over every function: each is compiled at the address the table says, and the lengths
;; come back so the next table can be built
(:wat::core::defrecord :c::PassR
  [code <- :c::Buf  tail <- :c::Buf
   lens <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :c::pass [pg <- :c::Prog i <- :wat::core::i64 rt <- :c::Layout tb <- :wat::core::i64
                            acc <- :c::PassR] -> :c::PassR
  (:wat::core::if (:wat::core::>= i (:wat::core::length (:c::Prog/fns pg))) acc
    (:wat::core::let
      [f (:wat::core::nth (:c::Prog/fns pg) i)
       o (:c::compile-fn (:c::Fn/node f) (:c::Fn/addr f) pg rt tb (:c::PassR/tail acc))]
      (:c::pass pg (:wat::core::+ i 1) rt tb
        ;; one function's code, flattened once and appended as a single chunk: the flatten is
        ;; linear and happens once per function, so the whole program's code is still O(n)
        (:c::PassR :code (:c::buf-add (:c::PassR/code acc) (:c::buf-str (:c::Out/code o)))
                   :tail (:c::Out/tail o)
                   :lens (:wat::core::conj (:c::PassR/lens acc) (:c::codelen o)))))))

(:wat::core::defn :c::empty-pass [] -> :c::PassR
  (:c::PassR :code (:c::buf0) :tail (:c::buf0) :lens (:wat::core::Vector :- [:wat::core::i64])))

;; the entry stub, and the only code not compiled from a defn: one mmap for both the output
;; buffer and the heap, then main, then a flush, then exit(0). 106 bytes.
;;
;; **r14 and r15 are the whole memory model.** r15 is the heap bump pointer and r14 is the base
;; of a block laid out `[used:8][heap_limit:8][4096 bytes]`; both are callee-saved in the System
;; V ABI, and nothing here ever calls anything this compiler did not emit, so two reserved
;; registers are the entire runtime state. `used` needs no initialising because MAP_ANONYMOUS
;; memory arrives zero-filled.
;;
;; There is no free and no collector, but there IS a bounds check: the limit sits at `[r14+8]`
;; and every allocator tests against it before it writes, so a program that wants more than the
;; heap gets `wat: heap exhausted` on stderr and exit 70 rather than a segmentation fault.
;;
;; **The flush at the end is not optional.** Buffering means the last `println` of a program is
;; still in memory when main returns, so the stub writes it before exit(0) -- and every other
;; way out of the program has to do the same, which is why `exit`, `fork` and `clone` all flush
;; first. That is the same rule C has, and the same bug C programs have when they forget it.
;; A gibibyte, and it costs nothing to ask for: MAP_ANONYMOUS is lazy, so pages are committed only
;; when they are first touched. A megabyte was enough while the only thing that
;; allocated was string concatenation, and 64 MiB until the compiler compiled itself -- which
;; touches more than that, because nothing is reclaimed except at statement boundaries (C-125).
(:wat::core::defn :c::heap-bytes [] -> :wat::core::i64 1900000000)
(:wat::core::defn :c::buf-bytes [] -> :wat::core::i64 8192)

;; measured, not asserted: every form in the stub is fixed-width, so its length does not depend
;; on the addresses it is given. This was written in by hand as 117.
;; **the stub's length, measured with placeholder addresses** -- every address in it is a fixed
;; width, so what they point at cannot change the size.
;;
;; It takes the layout rather than building one. It used to build its own, and it is called TWICE
;; per compile, and pass one built a third -- so `:c::layout` ran three times per program, and
;; each run constructs all thirty-three runtime routines to measure them. That was free while the
;; routines were string literals and is not now that they are expressions (F-137 again, one level
;; up): the compiled compiler drifted 509 -> 690 ms over three more conversions before this was
;; noticed. One layout, built once, threaded.
(:wat::core::defn :c::stub-len [lay0 <- :c::Layout] -> :wat::core::i64
  (:c::hexlen (:c::stub 0 lay0)))

(:wat::core::defn :c::stub [main-addr <- :wat::core::i64 rt <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [o (:c::Out :base (:asm::entry) :code (:c::buf0) :tail (:c::buf0) :rax "" :sp 0 :fk 0
                :fpr false)
     o1 (:c::emit o (:wat::string::concat
          (:wat::string::concat (:c::mov-rax 9) (:c::mov-rdi 0)
            (:c::mov-rsi (:wat::core::+ (:c::heap-bytes) (:c::buf-bytes))))
          (:wat::string::concat (:c::mov-rdx 3) (:c::mov-r10 34))
          (:wat::string::concat (:c::mov-r8 -1) (:c::mov-r9 0))
          (:wat::string::concat "0f05" "4989c6")            ;; syscall ; mov r14, rax
          (:wat::string::concat "4c8db8" (:asm::le (:c::buf-bytes) 4))     ;; lea r15,[rax+8192]
          ;; and the end of the heap, where every allocator checks before it writes
          (:wat::string::concat "488d88"                                   ;; lea rcx,[rax+total]
            (:asm::le (:wat::core::+ (:c::heap-bytes) (:c::buf-bytes)) 4))
          "49894e08"))                                       ;; mov [r14+8], rcx
     o2 (:c::call o1 main-addr)
     o3 (:c::call o2 (:c::at-flush rt))]
    (:c::buf-str (:c::Out/code (:c::emit o3 (:wat::string::concat (:c::mov-rax 60) "31ff" "0f05"))))))

;; place every function end to end after the stub
(:wat::core::defn :c::place [pg <- :c::Prog lens <- (:wat::core::Vector :- [:wat::core::i64])
                             i <- :wat::core::i64 at <- :wat::core::i64 acc <- :c::FnV] -> :c::Prog
  (:wat::core::let [v (:c::Prog/fns pg)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length v)) (:wat::core::assoc pg :fns acc)
      (:c::place pg lens (:wat::core::+ i 1) (:wat::core::+ at (:wat::core::nth lens i))
        (:wat::core::conj acc (:wat::core::assoc (:wat::core::nth v i) :addr at))))))

(:wat::core::defn :c::total [lens <- (:wat::core::Vector :- [:wat::core::i64]) i <- :wat::core::i64
                             acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length lens)) acc
    (:c::total lens (:wat::core::+ i 1) (:wat::core::+ acc (:wat::core::nth lens i)))))

(:wat::core::defn :c::same-lens [a <- (:wat::core::Vector :- [:wat::core::i64])
                                 b <- (:wat::core::Vector :- [:wat::core::i64]) i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i (:wat::core::length a)) nil
    (:wat::core::do (:wat::test::assert-eq (:wat::core::nth a i) (:wat::core::nth b i))
                    (:c::same-lens a b (:wat::core::+ i 1)))))


;; ---------------------------------------------------------------- inlining
;;
;; gcc -O2 beats this compiler four to one on fib(32), and the disassembly says why: **it does
;; not make most of the calls.** It inlines the recursion about six levels deep, so what is left
;; is straight-line arithmetic with one call in the inner loop. This does the same thing, two
;; levels deep, and does it as a rewrite of the AST before either pass sees it: a call becomes a
;; `let` that binds the parameters to the argument expressions and then runs a COPY of the body.
;; Nothing downstream changes -- `:c::fn-code` compiles the rewritten `defn`, and the frame size
;; falls out of `:c::slots-body` walking it, so the emitter and the frame cannot disagree.
;;
;; Three restrictions, each a soundness boundary rather than a simplification:
;;
;;   - **never in tail position.** A self call there is a jump that reuses the frame (C-121) and
;;     a `let` is not; elf/src/deep.wat is a million of them. The test is conservative: tail
;;     position propagates through `if`, `cond`, `do`, `let`, `and` and `or`, which is exactly
;;     the set of forms that pass `tc` down, and stops at everything else.
;;   - **only bodies that touch no heap** -- `:c::lvl-node` at 3 or below, which is arithmetic,
;;     comparisons, the logical forms and calls. A body that conj's or concats is judged by
;;     `:c::linear?`, and that is keyed by NAME and rebuilt per function: inlining moves those
;;     names into a frame whose linear set belongs to somebody else. Reusing the runtime level
;;     for this is not a coincidence -- "allocates nothing" is the same question both times.
;;   - **a size and a depth limit**, because every expansion is a copy.
;;
;; A subtree that does not change is SHARED rather than copied. Appending to the arena is the
;; thing C-140 measured at 745 MB, and copying every node of this compiler would pay it twice.

(:wat::core::defrecord :c::NodeR [pg <- :c::Prog  node <- :wat::core::i64])
(:wat::core::defrecord :c::KidsR [pg <- :c::Prog  kids <- :rd::Kids  same <- :wat::core::bool])

(:wat::core::defn :c::mknode [pg <- :c::Prog kind <- :wat::core::String text <- :wat::core::String
                              kids <- :rd::Kids] -> :c::NodeR
  (:wat::core::let [st (:c::Prog/src pg)]
    (:c::NodeR :node (:wat::core::length (:rd::St/arena st))
               :pg (:wat::core::assoc pg :src
                     (:wat::core::assoc st :arena
                       (:wat::core::conj (:rd::St/arena st)
                         (:rd::Node :kind kind :text text :kids kids)))))))

;; **how many parameters a user function declares, or -1 if there is no such function.**
;; `:c::inl-ok?` has always compared this against the call's argument count before inlining;
;; `:c::call-user` never asked, so a call with the wrong number of arguments compiled. The caller
;; pushes what it has and pops what it pushed, so the stack stays balanced and nothing crashes --
;; the callee simply reads its parameters from the WRONG SLOTS, at `[rsp + ... 8*(n-1-i)]` with
;; its own `n`. It cost an hour of bisection to find one of these by its symptom (F-128).
(:wat::core::defn :c::arity-at [pg <- :c::Prog fi <- :wat::core::i64] -> :wat::core::i64
  (:c::nparams (:c::kidsof pg
    (:wat::core::nth (:c::kidsof pg (:c::Fn/node (:wat::core::nth (:c::Prog/fns pg) fi))) 2))))

(:wat::core::defn :c::fn-of [pg <- :c::Prog name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [v (:c::Prog/fns pg)]
    (:wat::core::cond
      ((:wat::core::>= i (:wat::core::length v)) -1)
      ((:wat::core::= (:c::Fn/name (:wat::core::nth v i)) name) i)
      (:else (:c::fn-of pg name (:wat::core::+ i 1))))))

;; how many nodes a subtree is, and the highest runtime level anything in it reaches
(:wat::core::defn :c::nodes-of [pg <- :c::Prog a <- :wat::core::i64] -> :wat::core::i64
  (:c::nodes-kids pg (:c::kidsof pg a) 0 1))
(:wat::core::defn :c::nodes-kids [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                  acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) acc
    (:c::nodes-kids pg ks (:wat::core::+ i 1)
      (:wat::core::+ acc (:c::nodes-of pg (:wat::core::nth ks i))))))

(:wat::core::defn :c::pure-max [pg <- :c::Prog a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) (:c::lvl-node pg a false)
      (:c::pure-kids pg ks 0 0))))
(:wat::core::defn :c::pure-kids [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) best
    (:c::pure-kids pg ks (:wat::core::+ i 1)
      (:c::imax best (:c::pure-max pg (:wat::core::nth ks i))))))

;; "allocates nothing" is a question, not a number: it is everything at or below the last
;; routine that does not touch the heap -- `print_bool`. Writing it as a literal 3 meant that
;; inserting one routine into the runtime silently switched inlining OFF for every function with
;; a comparison in it, `fib` included, and the only symptom was a binary that got smaller.
(:wat::core::defn :c::lvl-pure [] -> :wat::core::i64 4)

(:wat::core::defn :c::inl-limit [] -> :wat::core::i64 34)
;; **Depth is a property of the CALLEE, not a global number.** A self-recursive callee earns
;; more of it: its inlined copy contains another call to itself, so each level removes a
;; MULTIPLICATIVE number of calls. A leaf accessor earns almost none -- inlining it removes
;; exactly one call per site, and further depth only expands ITS callees. Measured before the
;; rule existed: one global depth of 4 bought `fib` 25% and cost this compiler 21%, because its
;; own inlinable helpers are `:c::at-*` chains and nothing else.
(:wat::core::defn :c::inl-depth [] -> :wat::core::i64 4)

(:wat::core::defn :c::inl-depth-for [pg <- :c::Prog head <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [fi (:c::fn-of pg head 0)]
    (:wat::core::if (:wat::core::< fi 0) 1
      (:wat::core::let [nd (:c::Fn/node (:wat::core::nth (:c::Prog/fns pg) fi))]
        ;; the name occurs once as the definition; more than that is a call to itself
        (:wat::core::if (:wat::core::> (:c::occ nd head pg) 1) 4 1)))))

(:wat::core::defn :c::inl-ok? [pg <- :c::Prog head <- :wat::core::String nargs <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::let [fi (:c::fn-of pg head 0)]
    (:wat::core::if (:wat::core::< fi 0) false
      (:wat::core::let [nd (:c::Fn/node (:wat::core::nth (:c::Prog/fns pg) fi))
                        pv (:c::kidsof pg (:wat::core::nth (:c::kidsof pg nd) 2))]
        (:wat::core::and
          (:wat::core::= nargs (:wat::core::/ (:wat::core::length pv) 3))
          (:wat::core::and (:wat::core::<= (:c::nodes-of pg nd) (:c::inl-limit))
                           (:wat::core::<= (:c::pure-max pg nd) (:c::lvl-pure))))))))

;; tail position propagates through exactly the forms that pass `tc` down
(:wat::core::defn :c::tail-through? [h <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:wat::core::or (:c::if? h) (:c::cond? h))
    (:wat::core::or (:wat::core::or (:c::do? h) (:c::let? h))
                    (:wat::core::or (:c::and? h) (:c::or? h)))))

;; the binding vector of the `let` a call becomes: parameter name, then the argument that was
;; written for it. The names are the callee's own nodes, shared -- `let` already shadows.
;; **`(user/gcd b (wat.core/rem a b))` is why this is not one loop.** Binding the parameters in
;; order gives `a` its new value before the second argument is compiled, and `let` is `let*`, so
;; `(rem a b)` would read the `a` that had just been written -- the oldest bug in inlining. The
;; arguments are bound to temporaries first, in the caller's scope, and only then are the
;; parameters bound to those. The temporary names carry a SPACE, which the reader can never put
;; in a symbol, so they cannot collide with anything a program wrote. One parameter cannot be
;; captured by anything, so the temporaries are skipped there and `fib` pays nothing.
(:wat::core::defn :c::inl-tmp [i <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat " " (:wat::i64::to-string i)))

(:wat::core::defn :c::inl-temps [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64 n <- :wat::core::i64
                                 d <- :wat::core::i64 acc <- :rd::Kids] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i n) (:c::KidsR :pg pg :kids acc :same true)
    (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks (:wat::core::+ i 1)) d false)
                      t (:c::mknode (:c::NodeR/pg r) "symbol" (:c::inl-tmp i)
                          (:wat::core::Vector :- [:wat::core::i64]))]
      (:c::inl-temps (:c::NodeR/pg t) ks (:wat::core::+ i 1) n d
        (:wat::core::conj (:wat::core::conj acc (:c::NodeR/node t)) (:c::NodeR/node r))))))

(:wat::core::defn :c::inl-params [pg <- :c::Prog pv <- :c::Kids i <- :wat::core::i64 n <- :wat::core::i64
                                  acc <- :rd::Kids] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i n) (:c::KidsR :pg pg :kids acc :same true)
    (:wat::core::let [t (:c::mknode pg "symbol" (:c::inl-tmp i)
                          (:wat::core::Vector :- [:wat::core::i64]))]
      (:c::inl-params (:c::NodeR/pg t) pv (:wat::core::+ i 1) n
        (:wat::core::conj (:wat::core::conj acc (:wat::core::nth pv (:wat::core::* i 3)))
                          (:c::NodeR/node t))))))

(:wat::core::defn :c::inl-binds [pg <- :c::Prog pv <- :c::Kids ks <- :c::Kids i <- :wat::core::i64
                                 d <- :wat::core::i64 acc <- :rd::Kids] -> :c::KidsR
  (:wat::core::let [n (:wat::core::/ (:wat::core::length pv) 3)]
    (:wat::core::if (:wat::core::<= n 1)
      (:c::inl-one pg pv ks 0 n d acc)
      (:wat::core::let [tr (:c::inl-temps pg ks 0 n d acc)]
        (:c::inl-params (:c::KidsR/pg tr) pv 0 n (:c::KidsR/kids tr))))))

(:wat::core::defn :c::inl-one [pg <- :c::Prog pv <- :c::Kids ks <- :c::Kids i <- :wat::core::i64
                               n <- :wat::core::i64 d <- :wat::core::i64 acc <- :rd::Kids] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i n) (:c::KidsR :pg pg :kids acc :same true)
    (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks (:wat::core::+ i 1)) d false)]
      (:c::inl-one (:c::NodeR/pg r) pv ks (:wat::core::+ i 1) n d
        (:wat::core::conj (:wat::core::conj acc (:wat::core::nth pv (:wat::core::* i 3)))
                          (:c::NodeR/node r))))))

(:wat::core::defn :c::inl-kids [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                d <- :wat::core::i64 tail? <- :wat::core::bool
                                acc <- :rd::Kids same <- :wat::core::bool] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::KidsR :pg pg :kids acc :same same)
    (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks i) d tail?)]
      (:c::inl-kids (:c::NodeR/pg r) ks (:wat::core::+ i 1) d tail?
        (:wat::core::conj acc (:c::NodeR/node r))
        (:wat::core::and same (:wat::core::= (:c::NodeR/node r) (:wat::core::nth ks i)))))))

;; the body forms of the callee, copied one depth shallower and out of tail position
(:wat::core::defn :c::inl-body [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                d <- :wat::core::i64 acc <- :rd::Kids] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::KidsR :pg pg :kids acc :same true)
    (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks i) d false)]
      (:c::inl-body (:c::NodeR/pg r) ks (:wat::core::+ i 1) d
        (:wat::core::conj acc (:c::NodeR/node r))))))

(:wat::core::defn :c::inl-call [pg <- :c::Prog a <- :wat::core::i64 ks <- :c::Kids
                                head <- :wat::core::String d <- :wat::core::i64] -> :c::NodeR
  (:wat::core::let
    [fi (:c::fn-of pg head 0)
     nd (:c::Fn/node (:wat::core::nth (:c::Prog/fns pg) fi))
     fks (:c::kidsof pg nd)
     pv (:c::kidsof pg (:wat::core::nth fks 2))
     br (:c::inl-binds pg pv ks 0 d (:wat::core::Vector :- [:wat::core::i64]))
     vr (:c::mknode (:c::KidsR/pg br) "vector" "[]" (:c::KidsR/kids br))
     bo (:c::inl-body (:c::NodeR/pg vr) fks (:c::body-start fks 3 (:c::NodeR/pg vr))
          (:c::imin (:wat::core::- d 1) (:c::inl-depth-for pg head))
          (:wat::core::Vector :- [:wat::core::i64]))
     lr (:c::mknode (:c::KidsR/pg bo) "symbol" ":wat::core::let"
          (:wat::core::Vector :- [:wat::core::i64]))]
    (:c::mknode (:c::NodeR/pg lr) "list" (:c::text pg a)
      (:c::inl-cons (:c::NodeR/node lr) (:c::NodeR/node vr) (:c::KidsR/kids bo) 0
        (:wat::core::Vector :- [:wat::core::i64])))))

(:wat::core::defn :c::inl-cons [l <- :wat::core::i64 v <- :wat::core::i64 body <- :rd::Kids
                                i <- :wat::core::i64 acc <- :rd::Kids] -> :rd::Kids
  (:wat::core::if (:wat::core::>= i (:wat::core::length body))
    acc
    (:c::inl-cons l v body (:wat::core::+ i 1)
      (:wat::core::conj (:wat::core::if (:wat::core::= i 0)
                          (:wat::core::conj (:wat::core::conj acc l) v) acc)
                        (:wat::core::nth body i)))))

(:wat::core::defn :c::inl-node [pg <- :c::Prog a <- :wat::core::i64 d <- :wat::core::i64
                                tail? <- :wat::core::bool] -> :c::NodeR
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::if (:wat::core::or (:wat::core::not= (:c::kind a pg) "list")
                                    (:wat::core::= (:wat::core::length ks) 0))
      (:c::NodeR :pg pg :node a)
      (:wat::core::let [head (:c::text pg (:wat::core::nth ks 0))]
        (:wat::core::if
          (:wat::core::and (:wat::core::not tail?)
            (:wat::core::and (:wat::core::> d 0)
                             (:c::inl-ok? pg head (:wat::core::- (:wat::core::length ks) 1))))
          (:c::inl-call pg a ks head d)
          (:wat::core::if (:c::cond? head)
            (:wat::core::let [cr (:c::inl-clauses pg ks 1 d tail?
                                   (:wat::core::conj (:wat::core::Vector :- [:wat::core::i64])
                                                     (:wat::core::nth ks 0)) true)]
              (:wat::core::if (:c::KidsR/same cr) (:c::NodeR :pg (:c::KidsR/pg cr) :node a)
                (:c::mknode (:c::KidsR/pg cr) "list" (:c::text pg a) (:c::KidsR/kids cr))))
          (:wat::core::let
            [kr (:c::inl-kids pg ks 0 d
                  (:wat::core::and tail? (:c::tail-through? head))
                  (:wat::core::Vector :- [:wat::core::i64]) true)]
            (:wat::core::if (:c::KidsR/same kr) (:c::NodeR :pg (:c::KidsR/pg kr) :node a)
              (:c::mknode (:c::KidsR/pg kr) "list" (:c::text pg a) (:c::KidsR/kids kr))))))))))

;; each clause is `(test body...)`: the test is never in tail position and every body form is in
;; whatever position the `cond` itself was. elf/src/logic.wat's `gcd` is a tail call in one.
(:wat::core::defn :c::inl-clauses [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                   d <- :wat::core::i64 tail? <- :wat::core::bool
                                   acc <- :rd::Kids same <- :wat::core::bool] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::KidsR :pg pg :kids acc :same same)
    (:wat::core::let [r (:c::inl-clause pg (:wat::core::nth ks i) d tail?)]
      (:c::inl-clauses (:c::NodeR/pg r) ks (:wat::core::+ i 1) d tail?
        (:wat::core::conj acc (:c::NodeR/node r))
        (:wat::core::and same (:wat::core::= (:c::NodeR/node r) (:wat::core::nth ks i)))))))

(:wat::core::defn :c::inl-clause [pg <- :c::Prog a <- :wat::core::i64 d <- :wat::core::i64
                                  tail? <- :wat::core::bool] -> :c::NodeR
  (:wat::core::let [ks (:c::kidsof pg a)]
    (:wat::core::if (:wat::core::= (:wat::core::length ks) 0) (:c::NodeR :pg pg :node a)
      (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks 0) d false)
                        br (:c::inl-kids (:c::NodeR/pg r) ks 1 d tail?
                             (:wat::core::conj (:wat::core::Vector :- [:wat::core::i64])
                                               (:c::NodeR/node r))
                             (:wat::core::= (:c::NodeR/node r) (:wat::core::nth ks 0)))]
        (:wat::core::if (:c::KidsR/same br) (:c::NodeR :pg (:c::KidsR/pg br) :node a)
          (:c::mknode (:c::KidsR/pg br) (:c::kind a pg) (:c::text pg a) (:c::KidsR/kids br)))))))

;; every function's `defn` rewritten, with the Fn pointing at the new one
(:wat::core::defn :c::inl-fns [pg <- :c::Prog i <- :wat::core::i64 acc <- :c::FnV] -> :c::Prog
  (:wat::core::let [v (:c::Prog/fns pg)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length v)) (:wat::core::assoc pg :fns acc)
      (:wat::core::let
        [f (:wat::core::nth v i)
         ks (:c::kidsof pg (:c::Fn/node f))
         start (:c::body-start ks 3 pg)
         br (:c::inl-body-tail pg ks start (:c::inl-depth)
              (:wat::core::Vector :- [:wat::core::i64]) true)
         nr (:wat::core::if (:c::KidsR/same br) (:c::NodeR :pg (:c::KidsR/pg br) :node (:c::Fn/node f))
              (:c::mknode (:c::KidsR/pg br) "list" (:c::text pg (:c::Fn/node f))
                (:c::inl-head ks start 0 (:c::KidsR/kids br)
                  (:wat::core::Vector :- [:wat::core::i64]))))]
        (:c::inl-fns (:c::NodeR/pg nr) (:wat::core::+ i 1)
          (:wat::core::conj acc (:wat::core::assoc f :node (:c::NodeR/node nr))))))))

;; the `defn`'s first five children, then the rewritten body forms
(:wat::core::defn :c::inl-head [ks <- :c::Kids start <- :wat::core::i64 i <- :wat::core::i64
                                body <- :rd::Kids acc <- :rd::Kids] -> :rd::Kids
  (:wat::core::if (:wat::core::>= i start) (:c::inl-app body 0 acc)
    (:c::inl-head ks start (:wat::core::+ i 1) body
      (:wat::core::conj acc (:wat::core::nth ks i)))))
(:wat::core::defn :c::inl-app [body <- :rd::Kids i <- :wat::core::i64 acc <- :rd::Kids] -> :rd::Kids
  (:wat::core::if (:wat::core::>= i (:wat::core::length body)) acc
    (:c::inl-app body (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth body i)))))

;; only the LAST body form is in tail position
(:wat::core::defn :c::inl-body-tail [pg <- :c::Prog ks <- :c::Kids i <- :wat::core::i64
                                     d <- :wat::core::i64 acc <- :rd::Kids
                                     same <- :wat::core::bool] -> :c::KidsR
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:c::KidsR :pg pg :kids acc :same same)
    (:wat::core::let [r (:c::inl-node pg (:wat::core::nth ks i) d
                          (:wat::core::= i (:wat::core::- (:wat::core::length ks) 1)))]
      (:c::inl-body-tail (:c::NodeR/pg r) ks (:wat::core::+ i 1) d
        (:wat::core::conj acc (:c::NodeR/node r))
        (:wat::core::and same (:wat::core::= (:c::NodeR/node r) (:wat::core::nth ks i)))))))

;; ---------------------------------------------------------------- how much runtime to carry
;;
;; The level is the index of the highest routine a program can reach, and it is read off the
;; ARENA -- every node of every file the program is made of, not just this one's top level,
;; because `load-file!` reads into the same arena. A bare SYMBOL is enough: if
;; `wat.string/concat` appears anywhere at all, `str_cat` is carried whether or not that
;; occurrence is a call. That over-approximates on purpose -- being wrong high costs bytes,
;; being wrong low is a call into the data tail -- and **a built-in this table does not name
;; takes the whole runtime**, so adding a verb to the compiler can never silently truncate it.
(:wat::core::defn :c::builtin? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::string::starts-with? s "wat.") (:wat::string::starts-with? s ":wat::")))

(:wat::core::defn :c::lvl-zero? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:wat::core::or
      (:wat::core::or (:c::is? s "wat.core/+" ":wat::core::+") (:c::is? s "wat.core/-" ":wat::core::-"))
      (:wat::core::or (:c::is? s "wat.core/*" ":wat::core::*") (:c::is? s "wat.core/quot" ":wat::core::quot")))
    (:wat::core::or
      (:wat::core::or
        (:wat::core::or (:c::is? s "wat.core/rem" ":wat::core::rem") (:wat::core::= s ":wat::core::/"))
        (:wat::core::or (:c::is? s "wat.core/if" ":wat::core::if") (:c::is? s "wat.core/let" ":wat::core::let")))
      (:wat::core::or
        (:wat::core::or
          (:wat::core::or (:c::is? s "wat.core/do" ":wat::core::do") (:c::is? s "wat.core/cond" ":wat::core::cond"))
          (:wat::core::or (:c::is? s "wat.core/defn" ":wat::core::defn") (:c::is? s "wat.core/defrecord" ":wat::core::defrecord")))
        (:wat::core::or
          (:wat::core::or
            (:wat::core::or (:c::is? s "wat.core/typealias" ":wat::core::typealias") (:c::is? s "wat.core/nth" ":wat::core::nth"))
            (:wat::core::or (:c::is? s "wat.core/length" ":wat::core::length") (:c::strlen? s)))
          (:wat::core::or
            (:wat::core::or (:c::is? s "wat/load-file!" ":wat::load-file!") (:c::is? s "wat.type/i64" ":wat::core::i64"))
            (:c::is? s "wat.type/nil" ":wat::core::nil")))))))

;; the OS surface compiles to syscalls inline -- no routine, so no level
(:wat::core::defn :c::lvl-os? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:wat::core::or
      (:wat::core::or (:c::is? s "wat.os/peek" ":wat::os::peek") (:c::is? s "wat.os/poke" ":wat::os::poke"))
      (:wat::core::or (:c::is? s "wat.os/mmap" ":wat::os::mmap") (:c::is? s "wat.os/exit" ":wat::os::exit")))
    (:wat::core::or
      (:wat::core::or
        (:wat::core::or (:c::is? s "wat.os/fork" ":wat::os::fork") (:c::is? s "wat.os/wait" ":wat::os::wait"))
        (:wat::core::or (:c::is? s "wat.os/clone" ":wat::os::clone") (:c::is? s "wat.os/getpid" ":wat::os::getpid")))
      (:c::is? s "wat.os/getppid" ":wat::os::getppid"))))

;; a bool can be printed, so anything that makes one reaches print_bool
(:wat::core::defn :c::lvl-bool? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or
    (:wat::core::or
      (:wat::core::or (:c::is? s "wat.core/<" ":wat::core::<") (:c::is? s "wat.core/>" ":wat::core::>"))
      (:wat::core::or (:c::is? s "wat.core/<=" ":wat::core::<=") (:c::is? s "wat.core/>=" ":wat::core::>=")))
    (:wat::core::or
      (:wat::core::or (:c::is? s "wat.core/and" ":wat::core::and") (:c::is? s "wat.core/or" ":wat::core::or"))
      (:wat::core::or (:c::is? s "wat.core/not" ":wat::core::not")
                      ;; a bool PARAMETER can be printed with no comparison anywhere
                      (:c::is? s "wat.type/bool" ":wat::core::bool")))))

(:wat::core::defn :c::lvl-head [s <- :wat::core::String hs <- :wat::core::bool pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::cond
    ;; `nth` on a Vector reaches tree_get; this scan reads names, not types, so it cannot tell
    ;; a Vector's nth from a record's and carries the tree for both
    ((:c::is? s "wat.core/nth" ":wat::core::nth") 22)
    ;; every + - * carries `jo` to the overflow handler, so arithmetic reaches it
    ((:wat::core::or (:c::is? s "wat.core/+" ":wat::core::+")
       (:wat::core::or (:c::is? s "wat.core/-" ":wat::core::-")
                       (:c::is? s "wat.core/*" ":wat::core::*"))) 1)
    ;; a division is a call into a routine that checks the divisor before dividing
    ((:wat::core::or (:c::is? s "wat.core/quot" ":wat::core::quot")
       (:wat::core::or (:c::is? s "wat.core/rem" ":wat::core::rem")
                       (:wat::core::= s ":wat::core::/"))) 9)
    ((:c::lvl-zero? s) 0)
    ((:c::lvl-os? s) 0)
    ((:c::lvl-bool? s) 4)
    ;; `=` on two Strings is str_eq by meaning (C-130); on anything else it is a compare
    ((:wat::core::or (:c::is? s "wat.core/=" ":wat::core::=")
                     (:c::is? s "wat.core/not=" ":wat::core::not=")) (:wat::core::if hs 17 4))
    ((:c::is? s "wat.kernel/println" ":wat::kernel::println") 4)
    ((:c::is? s "wat.kernel/assertion-failed!" ":wat::kernel::assertion-failed!") 10)
    ;; assert-eq COMPARES, so on two Strings it is str_eq and not just the diagnostic
    ((:c::is? s "wat.test/assert-eq" ":wat::test::assert-eq") (:wat::core::if hs 17 6))
    ((:c::is? s "wat.type/String" ":wat::core::String") 10)
    ((:c::is? s "wat.string/concat" ":wat::string::concat") 17)
    ((:c::subs? s) 17)
    ((:c::is? s "wat.i64/to-string" ":wat::i64::to-string") 17)
    ((:c::is? s "wat.string/starts-with?" ":wat::string::starts-with?") 17)
    ((:c::is? s "wat.string/contains?" ":wat::string::contains?") 17)
    ((:c::is? s "wat.core/Vector" ":wat::core::Vector") 19)
    ((:c::is? s "wat.core/conj" ":wat::core::conj") 27)
    ((:c::is? s "wat.core/assoc" ":wat::core::assoc") 28)
    ((:c::is? s "prim/write-hex" ":prim::write-hex") 33)
    ((:c::is? s "prim/read-hex" ":prim::read-hex") 33)
    ((:c::is? s "wat.io/read-file" ":wat::io::read-file") 33)
    ;; a record constructor allocates, which is vec_new
    ((:wat::core::>= (:c::rec-index (:c::Prog/recs pg) s 0) 0) 18)
    ;; **the safety net**: a built-in nothing above names takes all of it
    ((:c::builtin? s) 33)
    (:else 0)))

(:wat::core::defn :c::lvl-node [pg <- :c::Prog a <- :wat::core::i64 hs <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::let [k (:c::kind a pg)]
    (:wat::core::cond
      ((:wat::core::= k "string") 10)
      ;; **both spellings**: `wat.core/assoc` reads as a symbol and `:wat::core::assoc` as a
      ;; KEYWORD, and reading only symbols skipped every name this compiler writes about itself
      ((:wat::core::= k "symbol") (:c::lvl-head (:c::text pg a) hs pg))
      ((:wat::core::= k "keyword") (:c::lvl-head (:c::text pg a) hs pg))
      ((:wat::core::= k "bool") 4)
      (:else 0))))

(:wat::core::defn :c::lvl-scan [pg <- :c::Prog i <- :wat::core::i64 n <- :wat::core::i64
                                hs <- :wat::core::bool best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n) best
    (:c::lvl-scan pg (:wat::core::+ i 1) n hs (:c::imax best (:c::lvl-node pg i hs)))))

;; twice: the first pass answers whether the program has Strings in it at all, which is what
;; decides whether `=` means str_eq
(:wat::core::defn :c::rt-level [pg <- :c::Prog] -> :wat::core::i64
  (:wat::core::let [n (:wat::core::length (:rd::St/arena (:c::Prog/src pg)))
                    base (:c::lvl-scan pg 0 n false 0)]
    (:c::lvl-scan pg 0 n (:wat::core::>= base 10) base)))

(:wat::core::defn :c::compile [src-path <- :wat::core::String out-path <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let
    [st (rd/read (:wat::io::read-file src-path))
     pg-c (:c::collect-in (:rd::St/kids st) 0
            (:wat::core::assoc (:c::empty-prog) :src st) (:c::dir-of src-path))
     ;; which functions reach a `poke`, transitively, before any code is emitted
     ;; every record and alias is known now, so the types can be resolved in any order
     pg-r (:c::fill-recs pg-c 0 (:wat::core::Vector :- [:c::Rec]))
     pg-f (:c::fill-fns pg-r 0 (:wat::core::Vector :- [:c::Fn]))
     pg-p (:c::poke-fix pg-f (:wat::core::length (:c::Prog/fns pg-f)))
     ;; the calls that become `let`s, before either pass sees a node
     pg0 (:c::inl-fns pg-p 0 (:wat::core::Vector :- [:c::Fn]))

     ;; PASS ONE: nothing has an address yet, and nothing needs one -- but every instruction
     ;; must come out the WIDTH it will have in pass two, so the layout is real and based at 0.
     ;; Built ONCE here and handed to everything that measures (see `:c::stub-len`).
     ;; ONE build of the runtime block, here. Everything else shifts or slices it.
     lay0 (:c::layout 0)
     p1 (:c::pass pg0 0 lay0 0 (:c::empty-pass))
     code-total (:c::total (:c::PassR/lens p1) 0 0)

     ;; now every address follows from the lengths
     pg1 (:c::place pg0 (:c::PassR/lens p1) 0
            (:wat::core::+ (:asm::entry) (:c::stub-len lay0)) (:wat::core::Vector :- [:c::Fn]))
     rt-addr (:wat::core::+ (:wat::core::+ (:asm::entry) (:c::stub-len lay0)) code-total)
     lvl (:c::rt-level pg0)
     ;; **once, here** -- every `(:c::at-X rt)` downstream is an index into this (F-137), and it
     ;; is the base-0 layout shifted rather than a second build of all thirty-three routines
     rt (:c::rebase lay0 rt-addr)
     rt-hex (:c::runtime lvl lay0)
     tail-base (:wat::core::+ rt-addr (:c::hexlen rt-hex))
     ;; either spelling of the entry point, because a program is allowed to be written in
     ;; either -- and this compiler's own source happens to use the keyword one
     main-clj (:c::fn-addr pg1 "user/main" 0)
     main-addr (:wat::core::if (:wat::core::>= main-clj 0) main-clj
                 (:c::fn-addr pg1 ":user::main" 0))

     ;; PASS TWO: now they do
     p2 (:c::pass pg1 0 rt tail-base (:c::empty-pass))
     text (:wat::string::concat (:c::stub main-addr rt) (:c::buf-str (:c::PassR/code p2))
            rt-hex)
     written (:asm::link out-path text (:c::buf-str (:c::PassR/tail p2)))]
    (:wat::core::do
      (:wat::core::if (:wat::core::< main-addr 0)
        (:wat::kernel::assertion-failed! :message "compile: no user/main") nil)
      ;; the invariant the two-pass technique rests on
      (:c::same-lens (:c::PassR/lens p1) (:c::PassR/lens p2) 0)
      (:wat::test::assert-eq (:c::buf-len (:c::PassR/tail p1))
                             (:c::buf-len (:c::PassR/tail p2)))
      (:wat::kernel::println
        (:wat::string::concat "compile: " (:asm::pad src-path 22) " -> " (:asm::pad out-path 24)
          (:asm::pad (:wat::i64::to-string written) 5) " bytes   fns " (:asm::pad (:wat::i64::to-string (:wat::core::length (:c::Prog/fns pg0))) 3)
          "  code " (:asm::pad (:wat::i64::to-string code-total) 5)
          "  data " (:asm::pad (:wat::i64::to-string (:wat::core::/ (:c::buf-len (:c::PassR/tail p2)) 2)) 4)
          "  verified")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c::compile "elf/src/four.wat"   "elf/out/four.elf")
    (:c::compile "elf/src/extremes.wat" "elf/out/extremes.elf")
    (:c::compile "elf/src/nnegsub.wat"  "elf/out/nnegsub.elf")
    (:c::compile "elf/src/select.wat"   "elf/out/select.elf")
    (:c::compile "elf/src/counted.wat"  "elf/out/counted.elf")
    (:c::compile "elf/src/bits.wat"     "elf/out/bits.elf")
    (:c::compile "elf/src/codeat.wat"   "elf/out/codeat.elf")
    (:c::compile "elf/bad/countedovf.wat" "elf/out/countedovf.elf")
    (:c::compile "elf/bad/nnegshadow.wat" "elf/out/nnegshadow.elf")
    (:c::compile "elf/bad/overflow.wat" "elf/out/overflow.elf")
    (:c::compile "elf/bad/divzero.wat"  "elf/out/divzero.elf")
    (:c::compile "elf/src/arith.wat"  "elf/out/arith.elf")
    (:c::compile "elf/src/greet.wat"  "elf/out/greet.elf")
    (:c::compile "elf/src/branch.wat" "elf/out/branch.elf")
    (:c::compile "elf/src/fib.wat"    "elf/out/fib.elf")
    (:c::compile "elf/src/bench.wat"  "elf/out/bench.elf")
    (:c::compile "elf/src/strings.wat" "elf/out/strings.elf")
    (:c::compile "elf/src/shadow.wat"  "elf/out/shadow.elf")
    (:c::compile "elf/src/churn.wat"   "elf/out/churn.elf")
    (:c::compile "elf/src/deep.wat"    "elf/out/deep.elf")
    (:c::compile "elf/src/logic.wat"   "elf/out/logic.elf")
    (:c::compile "elf/src/vectors.wat" "elf/out/vectors.elf")
    (:c::compile "elf/src/pvec.wat"     "elf/out/pvec.elf")
    (:c::compile "elf/src/assocn.wat"   "elf/out/assocn.elf")
    (:c::compile "elf/src/memory.wat"  "elf/out/memory.elf")
    (:c::compile "elf/src/linear.wat"  "elf/out/linear.elf")
    (:c::compile "elf/src/moved.wat"   "elf/out/moved.elf")
    (:c::compile "elf/src/freed.wat"   "elf/out/freed.elf")
    (:c::compile "elf/src/strverbs.wat" "elf/out/strverbs.elf")
    (:c::compile "elf/src/strown.wat"  "elf/out/strown.elf")
    (:c::compile "elf/src/reader.wat"  "elf/out/reader.elf")
    (:c::compile "elf/src/diag.wat"    "elf/out/diag.elf")
    (:c::compile "elf/src/fileio.wat"  "elf/out/fileio.elf")
    (:c::compile "elf/src/asmbits.wat" "elf/out/asmbits.elf")
    (:c::compile "elf/bench/fib32.wat" "elf/out/fib32.elf")
    (:c::compile "elf/bench/fibreg.wat" "elf/out/fibreg.elf")
    (:c::compile "elf/bench/loopsum.wat" "elf/out/loopsum.elf")
    (:c::compile "elf/bench/rec.wat"     "elf/out/rec.elf")
    (:c::compile "elf/bench/recflat.wat" "elf/out/recflat.elf")
    (:c::compile "elf/bench/rec1.wat"    "elf/out/rec1.elf")
    (:c::compile "elf/bench/strbuild.wat" "elf/out/strbuild.elf")
    (:c::compile "elf/bench/strbuild2.wat" "elf/out/strbuild2.elf")
    (:c::compile "elf/bench/triple.wat" "elf/out/triple.elf")
    (:c::compile "elf/bench/triple2.wat" "elf/out/triple2.elf")
    (:c::compile "elf/bench/tripleclamp.wat" "elf/out/tripleclamp.elf")
    (:c::compile "elf/bench/parse.wat"  "elf/out/parse.elf")
    (:c::compile "elf/bench/parsebits.wat" "elf/out/parsebits.elf")
    (:c::compile "elf/bench/walk.wat"   "elf/out/walk.elf")
    (:c::compile "elf/bench/scan.wat"   "elf/out/scan.elf")
    (:c::compile "elf/bench/scanfast.wat" "elf/out/scanfast.elf")
    (:c::compile "elf/bench/spew.wat"  "elf/out/spew.elf")
    (:c::compile "elf/bench/mix.wat"   "elf/out/mix.elf")
    (:c::compile "elf/bench/poly.wat"  "elf/out/poly.elf")
    (:c::compile "elf/bench/cat32000.wat"    "elf/out/cat32000.elf")
    (:c::compile "elf/bench/catx.wat"        "elf/out/catx.elf")
    (:c::compile "elf/bench/grow20000.wat"   "elf/out/grow20000.elf")
    (:c::compile "elf/bench/pass20000.wat"   "elf/out/pass20000.elf")
    (:c::compile "elf/bench/pass80000.wat"   "elf/out/pass80000.elf")
    (:c::compile "elf/bench/deepvec.wat"     "elf/out/deepvec.elf")
    (:c::compile "elf/bench/grow200000.wat"  "elf/out/grow200000.elf")
    (:c::compile "elf/bench/grow2000000.wat" "elf/out/grow2000000.elf")
    (:c::compile "elf/bench/vecsum.wat"      "elf/out/vecsum.elf")
    (:c::compile "elf/native/fork.wat"     "elf/out/fork.elf")
    (:c::compile "elf/native/thread.wat"   "elf/out/thread.elf")
    (:c::compile "elf/native/threads4.wat" "elf/out/threads4.elf")
    (:c::compile "elf/compile.wat"   "elf/out/compiler.elf")
    (:wat::kernel::println "compile: ok")))
