;; elf/lib/x86.wat -- the x86-64 instruction encoder.
;;
;; **This file knows nothing about wat.** It takes registers and numbers and returns hex; it
;; never sees an AST, a program, a scope or a type. That is the whole claim, and it is checkable
;; by grep: none of the compiler's own record types is named anywhere below this header.
;;
;; An instruction is REX + opcode + ModRM + SIB + displacement + immediate, and everything except
;; the opcode and its /digit is COMPUTED from the operands. C-169 built that half; C-173 deleted
;; the twelve tables that had been writing the results down by hand. What is left is one function
;; per instruction, each carrying its opcode exactly once -- so a mistyped name is an unresolved
;; reference before anything runs, rather than a wrong byte that assembles and ships.
;;
;; Arguments are in the order `objdump` prints, so a call site reads as the line you check it
;; against. `imul` is the one whose destination rides in the ModRM `reg` field rather than `rm`.
;;
;; Testable alone: encode an instruction, disassemble the bytes, compare.
;;   (:c::lea (:c::r15) (:c::rax) 8 24 (:c::rcx))  ==  lea 0x18(%r15,%rax,8),%rcx
;;
;; Split out of elf/compile.wat by C-174; see FINDINGS.md.

;; ---------------------------------------------------------------- instructions

;; **`movabs` into each of eight registers was eight opcodes, and the opcode is arithmetic**:
;; `b8` plus the register's three-bit code, with REX.B for the extended half. `48b8`, `48bf`,
;; `48be`, `48ba`, `49ba`, `49b8`, `49b9`, `48b9` -- eight literals encoding one instruction,
;; and no way to tell from any of them which register it meant.
(:wat::core::defn :c::mov-rax [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::rax) n))
(:wat::core::defn :c::mov-rdi [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::rdi) n))
(:wat::core::defn :c::mov-rsi [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::rsi) n))
(:wat::core::defn :c::mov-rdx [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::rdx) n))
;; mov [rbp+disp32], rax   and   mov rax, [rbp+disp32]
;; ---------------------------------------------------------------- short forms
;;
;; x86 encodes a small displacement in one byte and a large one in four, and the same for an
;; immediate. Every frame access here was four bytes of displacement where one would do, and
;; every literal was a ten-byte `movabs`.
;;
;; **The two-pass technique is why this needed thinking about rather than just doing.** Pass one
;; compiles with every address zero purely to measure, and pass two must come out the same
;; length -- so anything whose value CHANGES between the passes has to stay fixed-width. Frame
;; displacements and source literals do not change: the frame layout and the program text are
;; the same both times. Addresses do, so `mov-rax` keeps its `movabs` and every call and jump
;; keeps its rel32.
;; **the two width questions, which are the same question at two sizes.** x86 encodes a small
;; displacement in one byte and a large one in four, and the same for an immediate -- so every
;; encoder below asks one of these and picks its width from the answer. They live here because
;; the answer is a fact about the INSTRUCTION SET, not about the program being compiled.
(:wat::core::defn :c::imm32? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::>= n -2147483648) (:wat::core::<= n 2147483647)))
(:wat::core::defn :c::disp8? [d <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::>= d -128) (:wat::core::<= d 127)))

;; **Every frame access is measured from rsp, not rbp.** The displacement arrives already
;; adjusted by `:c::fp` -- the caller is the only thing that knows how deep the stack is right
;; here -- and the opcodes carry a SIB byte, because rsp cannot be a ModRM base without one.
;; That byte is the price of the frame pointer's register: one more byte per frame access.
(:wat::core::defn :c::rbp-at [op1 <- :wat::core::String op4 <- :wat::core::String
                              d <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:c::disp8? d)
    (:wat::string::concat op1 (:asm::le d 1))
    (:wat::string::concat op4 (:asm::le d 4))))

;; the same, choosing between a frame-pointer form and an rsp form. The rsp opcodes carry a SIB
;; byte, because rsp cannot be a ModRM base without one -- one byte per frame access, which is
;; what the register costs.
(:wat::core::defn :c::at-frame [fp? <- :wat::core::bool
                                b1 <- :wat::core::String b4 <- :wat::core::String
                                s1 <- :wat::core::String s4 <- :wat::core::String
                                d <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if fp? (:c::rbp-at b1 b4 d) (:c::rbp-at s1 s4 d)))

(:wat::core::defn :c::store [d <- :wat::core::i64 fp? <- :wat::core::bool] -> :wat::core::String
  (:c::at-frame fp? "488945" "488985" "48894424" "48898424" d))
(:wat::core::defn :c::load [d <- :wat::core::i64 fp? <- :wat::core::bool] -> :wat::core::String
  (:c::at-frame fp? "488b45" "488b85" "488b4424" "488b8424" d))

;; a source literal into rax: seven bytes when it fits in a sign-extended 32, ten when it does
;; not. Addresses keep `:c::mov-rax`, which is always ten.
(:wat::core::defn :c::mov-rax-lit [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:c::imm32? n)
    (:wat::string::concat "48c7c0" (:asm::le n 4))
    (:c::mov-rax n)))
;; the registers a Linux syscall takes its arguments in
(:wat::core::defn :c::mov-r10 [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::r10) n))
(:wat::core::defn :c::mov-r8 [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::r8) n))
(:wat::core::defn :c::mov-r9 [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::r9) n))
(:wat::core::defn :c::mov-rcx [n <- :wat::core::i64] -> :wat::core::String
  (:c::movabs (:c::rcx) n))
;; mov rax, [rax+d] -- a field read and an `nth` at a constant index are the same instruction
(:wat::core::defn :c::load-at [d <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "488b80" (:asm::le d 4)))
;; mov [rax+d], rcx -- filling a slot of a freshly allocated vector or record
(:wat::core::defn :c::store-slot [d <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "488988" (:asm::le d 4)))
(:wat::core::defn :c::mov-rdi-rax [] -> :wat::core::String (:c::mov-rr (:c::rax) (:c::rdi)))
(:wat::core::defn :c::mov-rsi-rax [] -> :wat::core::String (:c::mov-rr (:c::rax) (:c::rsi)))

;; and nothing at all when the frame is empty, which is most leaf functions
(:wat::core::defn :c::sub-rsp [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= n 0) "")
    ((:c::disp8? n) (:wat::string::concat "4883ec" (:asm::le n 1)))
    (:else (:wat::string::concat "4881ec" (:asm::le n 4)))))
(:wat::core::defn :c::add-rsp [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= n 0) "")
    ((:c::disp8? n) (:wat::string::concat "4883c4" (:asm::le n 1)))
    (:else (:wat::string::concat "4881c4" (:asm::le n 4)))))

;; **the one string verb that does not allocate** (F-135). A String is `[len:8][bytes...]` and a
;; non-ASCII literal is refused (F-120), so a character index IS a byte offset here and the whole
;; verb is one `movzbq`. Reading a character used to mean `(subs s i (+ i 1))`, which allocates a
;; one-character String and then needs `str_eq` to look at it: 71 instructions a byte.
;; `movzbq 8(BASE,INDEX,1), %rax` -- the whole verb when both operands are already in
;; registers, which in a scanning loop they always are. **x86 addresses base-plus-index
;; directly**, so the five instructions that shuffle them through rax and rcx are not work, they
;; are ceremony. Index code 4 means "no index" only when REX.X is clear, so r12 is a legal index
;; here; base code 5 is legal because mod=01 always carries the displacement.
(:wat::core::defn :c::movzb-sib [base <- :wat::core::i64 index <- :wat::core::i64] -> :wat::core::String
  (:c::movzb base index (:c::str-data) (:c::rax)))

;; **0-3 are the callee-saved registers and 4-7 are r8-r11.** The second group is only ever
;; handed out to a function that makes no returning call (`:c::callfree?`), because nothing else
;; preserves them -- and for exactly that reason they need no saving in the prologue either.
;; ---------------------------------------------------------------- registers, by number
;;
;; **Everything above this point is a hand-written hex table, and there is a reason it stops
;; here.** A table has one entry per (operand, register) pair and the tables above are already
;; eight entries wide; what comes next needs a value moved between ANY two of ten registers, plus
;; `lea`, plus `cmov`, which is three more tables of a hundred entries. So these two functions
;; say what a register IS -- its three-bit code and whether it needs the REX extension bit -- and
;; the encodings are computed from that, which is what `:asm::u8` was for.
;;
;; The numbering extends the allocator's: 0-3 are the callee-saved four, 4-7 are r8-r11 (C-165),
;; 8-10 are rax, rcx and rdx, which nothing allocates and everything scribbles on, and 11-15 are
;; the rest of the file -- rsi, rdi, rsp, and the two the runtime dedicates (r14 the output
;; buffer, r15 the heap pointer). **These indices are not hardware codes and never were**: index
;; 1 is r12 and index 4 is r8, and the mapping below is the only place that knows it. A function
;; per register keeps the numbers off every call site, so what a reader sees is `(:c::r15)`.
;;
;; `-1` is not a register. `:c::no-reg` gives it a name, because a memory operand with no index
;; has to say so, and a bare -1 at a call site says nothing.
(:wat::core::defn :c::rcode [r <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= r 0) 3) ((:wat::core::= r 1) 4) ((:wat::core::= r 2) 5) ((:wat::core::= r 3) 5)
    ((:wat::core::= r 4) 0) ((:wat::core::= r 5) 1) ((:wat::core::= r 6) 2) ((:wat::core::= r 7) 3)
    ((:wat::core::= r 8) 0) ((:wat::core::= r 9) 1) ((:wat::core::= r 10) 2)
    ((:wat::core::= r 11) 6) ((:wat::core::= r 12) 7) ((:wat::core::= r 13) 4)
    ((:wat::core::= r 14) 6) (:else 7)))
(:wat::core::defn :c::rext? [r <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::or (:wat::core::= r 1) (:wat::core::or (:wat::core::= r 2)
    (:wat::core::or (:wat::core::and (:wat::core::>= r 4) (:wat::core::<= r 7))
                    (:wat::core::>= r 14)))))
(:wat::core::defn :c::no-reg [] -> :wat::core::i64 -1)
(:wat::core::defn :c::reg? [r <- :wat::core::i64] -> :wat::core::bool (:wat::core::>= r 0))
;; **REX names the three operand fields it extends, because that is what it is.** It used to take
;; two bools called `w` and `b`, where `w` was really REX.R and REX.X had to be computed by hand
;; at the one site that needed it. `r` extends the ModRM reg field, `x` the SIB index, `b` the
;; ModRM rm or SIB base. REX.W is always set: everything this compiler emits is 64-bit.
(:wat::core::defn :c::rex [r <- :wat::core::bool x <- :wat::core::bool
                           b <- :wat::core::bool] -> :wat::core::String
  (:asm::u8 (:wat::core::+ 72 (:wat::core::+ (:wat::core::if r 4 0)
              (:wat::core::+ (:wat::core::if x 2 0) (:wat::core::if b 1 0))))))
(:wat::core::defn :c::modrm [mod <- :wat::core::i64 reg <- :wat::core::i64
                             rm <- :wat::core::i64] -> :wat::core::String
  (:asm::u8 (:wat::core::+ (:wat::core::* mod 64) (:wat::core::+ (:wat::core::* reg 8) rm))))

;; ---------------------------------------------------------------- two operand shapes
;;
;; **Every hand-written table below this line is one of these two.** An instruction on two
;; registers is an opcode plus a ModRM naming them; WHICH operand lands in the `reg` field and
;; which in `rm` is the opcode's business, not the caller's, so these name the FIELDS rather than
;; "source" and "destination" -- `add` puts its source in `reg` and `imul` puts its destination
;; there, and a table that pretends otherwise has to be read twice to be believed.
(:wat::core::defn :c::rr [opc <- :wat::core::String reg <- :wat::core::i64
                          rm <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex (:c::rext? reg) false (:c::rext? rm)) opc
                        (:c::modrm 3 (:c::rcode reg) (:c::rcode rm))))

;; the other shape: the `reg` field is not a register at all but an opcode EXTENSION -- the
;; `/0`..`/7` an Intel manual writes after the opcode. `shl` and `sar` are the same byte `d3`
;; and differ only in this digit.
(:wat::core::defn :c::rd [opc <- :wat::core::String digit <- :wat::core::i64
                          rm <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex false false (:c::rext? rm)) opc
                        (:c::modrm 3 digit (:c::rcode rm))))

;; every register by name, so a call site reads as the instruction it is
(:wat::core::defn :c::rax [] -> :wat::core::i64 8)
(:wat::core::defn :c::rcx [] -> :wat::core::i64 9)
(:wat::core::defn :c::rdx [] -> :wat::core::i64 10)
(:wat::core::defn :c::rsi [] -> :wat::core::i64 11)
(:wat::core::defn :c::rdi [] -> :wat::core::i64 12)
(:wat::core::defn :c::rsp [] -> :wat::core::i64 13)
(:wat::core::defn :c::rbx [] -> :wat::core::i64 0)
(:wat::core::defn :c::rbp [] -> :wat::core::i64 3)
(:wat::core::defn :c::r8  [] -> :wat::core::i64 4)
(:wat::core::defn :c::r9  [] -> :wat::core::i64 5)
(:wat::core::defn :c::r10 [] -> :wat::core::i64 6)
(:wat::core::defn :c::r11 [] -> :wat::core::i64 7)
;; the two the runtime owns outright: r14 addresses the output buffer and its header, r15 is the
;; bump pointer. Nothing the allocator hands out ever names them.
(:wat::core::defn :c::r14 [] -> :wat::core::i64 14)
(:wat::core::defn :c::r15 [] -> :wat::core::i64 15)

;; ---------------------------------------------------------------- the third operand shape
;;
;; **A memory operand is `disp(%base,%index,scale)` and every shape x86 allows is that one with
;; pieces left out.** `(%rax)` has no disp and no index; `0x8(%r14)` has no index; `0x18(,%rax,8)`
;; has no base. Four shapes written as four encoders is four chances to disagree, so this takes
;; the whole operand and lets `:c::no-reg` say which pieces are absent.
;;
;; Three facts decide the bytes, and not one of them is visible in the bytes:
;;   * **ModRM.rm = 4 does not mean rsp.** It means A SIB BYTE FOLLOWS -- so rsp and r12, which
;;     share that code, can never be addressed without one.
;;   * **mod = 0 with rm = 5 does not mean `(%rbp)`.** It means a bare disp32 and no base -- so
;;     rbp and r13 always carry a displacement byte, even a zero one.
;;   * **In the SIB byte, index = 4 means no index and base = 5 (with mod 0) means no base.**
;;     That is how `(,%rax,8)` is spelled: index rax, base "none", and a disp32 that must be
;;     there whether or not the source wrote one.
;; The old `:c::lea` knew the first of these and half of the second, in a comment.
(:wat::core::defn :c::sib-scale [s <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond ((:wat::core::= s 1) 0) ((:wat::core::= s 2) 1)
                    ((:wat::core::= s 4) 2) (:else 3)))

;; a SIB byte is needed when there is an index, when there is no base at all, or when the base
;; is one of the two registers whose code is spoken for
(:wat::core::defn :c::sib? [base <- :wat::core::i64 index <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::or (:c::reg? index)
    (:wat::core::or (:wat::core::not (:c::reg? base)) (:wat::core::= (:c::rcode base) 4))))

;; mod 0 is the shortest form and is available when the displacement is zero and the base's code
;; is not the one that means "no base"; a base of rbp or r13 is why mod 1 exists with a zero byte
(:wat::core::defn :c::mem-mod [base <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::not (:c::reg? base)) 0)
    ((:wat::core::and (:wat::core::= disp 0) (:wat::core::not= (:c::rcode base) 5)) 0)
    ((:c::disp8? disp) 1)
    (:else 2)))

(:wat::core::defn :c::sib-byte [base <- :wat::core::i64 index <- :wat::core::i64
                                scale <- :wat::core::i64] -> :wat::core::String
  (:asm::u8 (:wat::core::+ (:wat::core::* (:c::sib-scale scale) 64)
              (:wat::core::+ (:wat::core::* (:wat::core::if (:c::reg? index) (:c::rcode index) 4) 8)
                             (:wat::core::if (:c::reg? base) (:c::rcode base) 5)))))

;; mod says how wide the displacement is -- except with no base, where mod is 0 and it is a
;; disp32 regardless, which is the one case the mod field does not tell you
(:wat::core::defn :c::mem-disp [base <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [m (:c::mem-mod base disp)]
    (:wat::core::cond
      ((:wat::core::not (:c::reg? base)) (:asm::le disp 4))
      ((:wat::core::= m 1) (:asm::le disp 1))
      ((:wat::core::= m 2) (:asm::le disp 4))
      (:else ""))))

;; ModRM + SIB + displacement for a memory operand, with `field` already reduced to three bits --
;; it is a register code for a two-operand instruction and an opcode digit for a /n one
(:wat::core::defn :c::mrm [field <- :wat::core::i64 base <- :wat::core::i64
                           index <- :wat::core::i64 scale <- :wat::core::i64
                           disp <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [s? (:c::sib? base index)]
    (:wat::string::concat
      (:c::modrm (:c::mem-mod base disp) field
                 (:wat::core::if s? 4 (:c::rcode base)))
      (:wat::core::if s? (:c::sib-byte base index scale) "")
      (:c::mem-disp base disp))))

;; REX for a memory operand: `x` is the SIB index and `b` the base, which is exactly why
;; `:c::rex` names its three bits after the fields they extend rather than after operands
(:wat::core::defn :c::rex-m [reg <- :wat::core::i64 base <- :wat::core::i64
                             index <- :wat::core::i64] -> :wat::core::String
  (:c::rex (:c::rext? reg)
           (:wat::core::and (:c::reg? index) (:c::rext? index))
           (:wat::core::and (:c::reg? base) (:c::rext? base))))

;; `OPC reg, mem` -- the two-operand shape with one operand in memory
(:wat::core::defn :c::rm [opc <- :wat::core::String reg <- :wat::core::i64
                          base <- :wat::core::i64 index <- :wat::core::i64
                          scale <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex-m reg base index) opc
                        (:c::mrm (:c::rcode reg) base index scale disp)))

;; `OPC /digit, mem` -- the extension shape with one operand in memory
(:wat::core::defn :c::dm [opc <- :wat::core::String digit <- :wat::core::i64
                          base <- :wat::core::i64 index <- :wat::core::i64
                          scale <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex-m (:c::no-reg) base index) opc
                        (:c::mrm digit base index scale disp)))

;; the common case, spelled without the index nobody is using
(:wat::core::defn :c::rm-at [opc <- :wat::core::String reg <- :wat::core::i64
                             base <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::String
  (:c::rm opc reg base (:c::no-reg) 1 disp))
(:wat::core::defn :c::dm-at [opc <- :wat::core::String digit <- :wat::core::i64
                             base <- :wat::core::i64 disp <- :wat::core::i64] -> :wat::core::String
  (:c::dm opc digit base (:c::no-reg) 1 disp))

;; ---------------------------------------------------------------- the instructions
;;
;; **One function per instruction, each carrying its opcode exactly once.** A bare `"39"` at a
;; call site is a silent wrong byte when it is mistyped as `"93"` -- it assembles, it links, and
;; it is only caught if some test happens to execute it. A mistyped NAME is an unresolved
;; reference before anything runs, which is the same failure moved from runtime to build time.
;;
;; Arguments are in the order `objdump` prints, so a call site reads as the line you check it
;; against. `imul` is the one whose destination rides in the ModRM `reg` field rather than `rm`;
;; that is hidden here rather than at twenty call sites.
;; ---------------------------------------------------------------- the stack, and control flow
;;
;; The bytes that were bare literals at forty sites. `50`/`58` are `push`/`pop` with the register
;; in the low three bits of the opcode, same shape as `:c::stack-op` above -- spelled out here
;; because rax and rcx are not allocator registers and do not have an index to hand it.
(:wat::core::defn :c::push-rax [] -> :wat::core::String "50")
(:wat::core::defn :c::pop-rax [] -> :wat::core::String "58")
(:wat::core::defn :c::pop-rcx [] -> :wat::core::String "59")
(:wat::core::defn :c::ret [] -> :wat::core::String "c3")

;; **a `jmp` whose displacement is not known yet.** Every one of these is emitted with a zero and
;; patched once the target address exists, which is why the placeholder is part of the name: a
;; bare `(:c::jmp-unpatched)` at a call site says nothing about the four bytes being a promise.
(:wat::core::defn :c::jmp-unpatched [] -> :wat::core::String "e900000000")

(:wat::core::defn :c::add-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "01" src dst))
(:wat::core::defn :c::sub-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "29" src dst))
(:wat::core::defn :c::cmp-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "39" src dst))
(:wat::core::defn :c::and-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "21" src dst))
(:wat::core::defn :c::or-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "09" src dst))
(:wat::core::defn :c::xor-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "31" src dst))
;; `imul %src, %dst` -- the destination is the `reg` field, which is why the arguments swap here
(:wat::core::defn :c::imul-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "0faf" dst src))

;; the shifts: one opcode, three digits -- /4 shl, /7 sar (sign-filling), /5 shr (zero-filling)
(:wat::core::defn :c::shl-cl [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "d3" 4 dst))
(:wat::core::defn :c::sar-cl [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "d3" 7 dst))
(:wat::core::defn :c::shr-cl [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "d3" 5 dst))

;; `cmp $imm, %dst` and `imul $imm, %src, %rax` -- both pick a short opcode when the immediate
;; fits in a byte, which is the only thing that varies between their two forms
(:wat::core::defn :c::cmp-ri [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::string::concat (:c::rd (:wat::core::if short? "83" "81") 7 dst)
                          (:asm::le n (:wat::core::if short? 1 4)))))
;; the one-operand forms: a `/digit` and nothing else
;; `and $imm, DST` -- the mask, which is how a tree index takes its low five bits
(:wat::core::defn :c::and-ri [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::string::concat (:c::rd (:wat::core::if short? "83" "81") 4 dst)
                          (:asm::le n (:wat::core::if short? 1 4)))))
(:wat::core::defn :c::neg-r [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "f7" 3 dst))
(:wat::core::defn :c::idiv-r [src <- :wat::core::i64] -> :wat::core::String (:c::rd "f7" 7 src))
(:wat::core::defn :c::test-rr [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::String
  (:c::rr "85" a b))
;; sign-extend rax into rdx:rax, which is what `idiv` wants of its dividend
(:wat::core::defn :c::cqto [] -> :wat::core::String "4899")
;; how much room a branch takes, so an offset can be written as a sum of pieces rather than a
;; sum of remembered numbers
(:wat::core::defn :c::rel32-size [] -> :wat::core::i64 6)
(:wat::core::defn :c::rel8-size [] -> :wat::core::i64 2)

(:wat::core::defn :c::add-ri [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::string::concat (:c::rd (:wat::core::if short? "83" "81") 0 dst)
                          (:asm::le n (:wat::core::if short? 1 4)))))
(:wat::core::defn :c::sub-ri [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::string::concat (:c::rd (:wat::core::if short? "83" "81") 5 dst)
                          (:asm::le n (:wat::core::if short? 1 4)))))

;; **a forward branch over a piece, where the displacement IS that piece's length.** No label
;; table is needed when the thing being skipped is an expression: it is right there, so
;; `:c::hexlen` of it is the displacement. C-169's `:c::sel` already builds its diamond this way.
;; the same branch given the DISTANCE rather than the piece. A loop whose body contains the
;; branch cannot hand that body to `:c::br-over` -- it does not exist yet -- but its length is
;; still a sum of pieces that do.
(:wat::core::defn :c::br-len [cc <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat cc (:asm::le n 1)))
(:wat::core::defn :c::br-over [cc <- :wat::core::String body <- :wat::core::String] -> :wat::core::String
  (:c::br-len cc (:c::hexlen body)))
;; **a BACKWARD jump, where the displacement is the piece being jumped over plus the jump.**
;; The forward case (`:c::br-over`) skips a piece that follows it, so the distance is that piece's
;; length. A loop jumps back over a piece that PRECEDES it and over itself, so the distance is
;; that length plus two, negated -- which is the whole of what a label table would have told us.
(:wat::core::defn :c::jmp-back [body <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat "eb"
    (:asm::le (:wat::core::- 0 (:wat::core::+ (:c::hexlen body) (:c::rel8-size))) 1)))
(:wat::core::defn :c::jb-over [body <- :wat::core::String] -> :wat::core::String
  (:c::br-over (:c::jcc-rel8 (:c::cc-below)) body))
(:wat::core::defn :c::jbe-over [body <- :wat::core::String] -> :wat::core::String
  (:c::br-over (:c::jcc-rel8 (:c::cc-below-eq)) body))

(:wat::core::defn :c::imul-rri [src <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [short? (:c::disp8? n)]
    (:wat::string::concat (:c::rr (:wat::core::if short? "6b" "69") (:c::rax) src)
                          (:asm::le n (:wat::core::if short? 1 4)))))

;; `mov SRC, DST` for any two of them
(:wat::core::defn :c::mov-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex (:c::rext? src) false (:c::rext? dst)) "89"
                        (:c::modrm 3 (:c::rcode src) (:c::rcode dst))))

;; `mov $imm32, DST`
(:wat::core::defn :c::mov-ri [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex false false (:c::rext? dst)) "c7"
                        (:c::modrm 3 0 (:c::rcode dst)) (:asm::le n 4)))

;; ---------------------------------------------------------------- instructions on memory
;;
;; **`lea` is an address computed but not followed** -- the arithmetic that sets no flags. It is
;; the only instruction whose operand is a memory reference it never reads, which is why the
;; general form is the one worth having: `lea 0x18(,%rax,8),%rcx` multiplies and adds in one go.
(:wat::core::defn :c::lea [base <- :wat::core::i64 index <- :wat::core::i64
                           scale <- :wat::core::i64 disp <- :wat::core::i64
                           dst <- :wat::core::i64] -> :wat::core::String
  (:c::rm "8d" dst base index scale disp))
(:wat::core::defn :c::lea-at [base <- :wat::core::i64 disp <- :wat::core::i64
                              dst <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "8d" dst base disp))

;; `mov disp(BASE), DST` and `mov SRC, disp(BASE)` -- a load and a store, which differ by one
;; opcode bit and nothing else. Naming them apart is the whole defence against writing where you
;; meant to read: `8b` and `89` are one keystroke from each other and both assemble.
(:wat::core::defn :c::mov-rm [base <- :wat::core::i64 disp <- :wat::core::i64
                              dst <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "8b" dst base disp))
(:wat::core::defn :c::mov-mr [src <- :wat::core::i64 base <- :wat::core::i64
                              disp <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "89" src base disp))
;; `movq $imm32, disp(BASE)` -- the store whose source is a constant, sign-extended to 64 bits
(:wat::core::defn :c::mov-mi [base <- :wat::core::i64 disp <- :wat::core::i64
                              n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::dm-at "c7" 0 base disp) (:asm::le n 4)))
;; the arithmetic with one operand in memory, so a compare against a header field needs no load
(:wat::core::defn :c::cmp-rm [base <- :wat::core::i64 disp <- :wat::core::i64
                              reg <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "3b" reg base disp))
(:wat::core::defn :c::add-rm [base <- :wat::core::i64 disp <- :wat::core::i64
                              reg <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "03" reg base disp))
;; the other direction -- `add %rdx,(%r14)` bumps a counter that lives in memory without loading
;; it first. `03` reads memory into a register; `01` adds a register into memory.
(:wat::core::defn :c::add-mr [src <- :wat::core::i64 base <- :wat::core::i64
                              disp <- :wat::core::i64] -> :wat::core::String
  (:c::rm-at "01" src base disp))
;; `movzbq disp(BASE,INDEX,1), DST` -- one byte, zero-extended, which is how a string's
;; characters are read (C-172)
(:wat::core::defn :c::movzb [base <- :wat::core::i64 index <- :wat::core::i64
                             disp <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rm "0fb6" dst base index 1 disp))

;; ---------------------------------------------------------------- the rest of the vocabulary
;;
;; `movabs` is the only instruction that carries a full 64-bit immediate, and it has no ModRM at
;; all -- the register rides in the low three bits of the opcode, like `push`.
;; ---------------------------------------------------------------- narrower than a word
;;
;; **Everything else here is 64-bit, because everything this compiler emits is.** REX.W is what
;; makes it so, and these are the one place that must NOT set it: a short string built on the
;; stack is written four bytes, then two, then one, and those encodings differ from their 64-bit
;; siblings only in a prefix and an opcode. A 16-bit store adds the `66` operand-size prefix; an
;; 8-bit store changes `c7` to `c6`; a 32-bit store is the same opcode with no REX at all.
;;
;; A REX byte appears only when a register needs extending -- `-0x8(%rbp)` needs none.
(:wat::core::defn :c::rex-narrow [base <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::and (:c::reg? base) (:c::rext? base))
    (:asm::u8 65) ""))                                   ;; 0x41 = REX.B, and no W
(:wat::core::defn :c::mov-mi32 [base <- :wat::core::i64 disp <- :wat::core::i64
                                n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex-narrow base) "c7"
    (:c::mrm 0 base (:c::no-reg) 1 disp) (:asm::le n 4)))
(:wat::core::defn :c::mov-mi16 [base <- :wat::core::i64 disp <- :wat::core::i64
                                n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "66" (:c::rex-narrow base) "c7"
    (:c::mrm 0 base (:c::no-reg) 1 disp) (:asm::le n 2)))
(:wat::core::defn :c::mov-mi8 [base <- :wat::core::i64 disp <- :wat::core::i64
                               n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex-narrow base) "c6"
    (:c::mrm 0 base (:c::no-reg) 1 disp) (:asm::le n 1)))

;; **a short string AS an immediate, computed from the string.** `movl $0x65757274` is `"true"`
;; read little-endian, and writing the number means trusting whoever transcribed it; asking the
;; characters means it cannot be wrong. Same rule as `:asm::code-of` and `:c::hex-gap` (C-173).
(:wat::core::defn :c::packed [s <- :wat::core::String i <- :wat::core::i64
                              acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< i 0) acc
    (:c::packed s (:wat::core::- i 1)
      (:wat::core::+ (:wat::core::* acc 256)
        (:asm::code-of (:wat::string::subs s i (:wat::core::+ i 1)))))))
(:wat::core::defn :c::pack [s <- :wat::core::String] -> :wat::core::i64
  (:c::packed s (:wat::core::- (:wat::string::length s) 1) 0))
;; the one character `:asm::code-of` cannot give, because its table starts at 32 (F-062)
(:wat::core::defn :c::nl [] -> :wat::core::i64 10)

;; `leave` -- undoes the frame `push %rbp; mov %rsp,%rbp` set up, in one byte
(:wat::core::defn :c::leave [] -> :wat::core::String "c9")
;; the unconditional twin of :c::br-over
(:wat::core::defn :c::jmp-over [body <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat "eb" (:asm::le (:c::hexlen body) 1)))

(:wat::core::defn :c::movabs [dst <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::rex false false (:c::rext? dst))
                        (:asm::u8 (:wat::core::+ 184 (:c::rcode dst))) (:asm::le n 8)))
(:wat::core::defn :c::inc-r [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "ff" 0 dst))
(:wat::core::defn :c::dec-r [dst <- :wat::core::i64] -> :wat::core::String (:c::rd "ff" 1 dst))
(:wat::core::defn :c::div-r [src <- :wat::core::i64] -> :wat::core::String (:c::rd "f7" 6 src))
;; `bsr` -- the index of the highest set bit, which is a base-2 logarithm for free
(:wat::core::defn :c::bsr-rr [src <- :wat::core::i64 dst <- :wat::core::i64] -> :wat::core::String
  (:c::rr "0fbd" dst src))

;; **the string instructions, which are loops the hardware runs.** `rep movsq` copies rcx
;; quadwords from (rsi) to (rdi); `repz cmpsb` compares rcx bytes and stops at the first
;; difference, leaving ZF set if it ran out first. They have no operands to encode -- the
;; registers are fixed by the opcode -- so these are the one place a bare literal is the whole
;; instruction and naming it is all there is to do.
;; `rep stos` fills rcx quadwords at (rdi) with rax -- zeroing a fresh node's slots
(:wat::core::defn :c::rep-stosq [] -> :wat::core::String "f348ab")
(:wat::core::defn :c::rep-movsq [] -> :wat::core::String "f348a5")
(:wat::core::defn :c::rep-movsb [] -> :wat::core::String "f3a4")
(:wat::core::defn :c::repz-cmpsb [] -> :wat::core::String "f3a6")
(:wat::core::defn :c::syscall [] -> :wat::core::String "0f05")

;; **a `call` whose displacement is measured from the END of the instruction**, which is five
;; bytes past its start -- the single most common off-by-five in hand-written machine code.
(:wat::core::defn :c::call-rel32 [rel <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "e8" (:asm::le rel 4)))
(:wat::core::defn :c::call-size [] -> :wat::core::i64 5)

;; these two WERE `:c::mov-rr` all along, written out sixteen times
(:wat::core::defn :c::reg-mov-to [r <- :wat::core::i64] -> :wat::core::String
  (:c::mov-rr r (:c::rax)))
(:wat::core::defn :c::reg-mov-from [r <- :wat::core::i64] -> :wat::core::String
  (:c::mov-rr (:c::rax) r))

;; `push`/`pop` have no ModRM at all: the register rides in the low three bits of the opcode,
;; and REX.B is the only prefix an extended one needs.
(:wat::core::defn :c::stack-op [base <- :wat::core::i64 r <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:wat::core::if (:c::rext? r) "41" "")
                        (:asm::u8 (:wat::core::+ base (:c::rcode r)))))
(:wat::core::defn :c::reg-push [r <- :wat::core::i64] -> :wat::core::String (:c::stack-op 80 r))
(:wat::core::defn :c::reg-pop [r <- :wat::core::i64] -> :wat::core::String (:c::stack-op 88 r))

;; `cmp $imm, REG` -- the comparison with a register on the LEFT. C-133 taught the right operand
;; of a binop to come straight from an immediate or the frame; the left one always went through
;; rax, so every `(if (= i 0) ...)` on a parameter in a register cost a `mov` before the `cmp`
;; it did not need. C-153 counted three of them in one loop body.
(:wat::core::defn :c::reg-cmp-imm [r <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:c::cmp-ri r n))

;; which register this operand already lives in, or -1
;; **`imul` is the one arithmetic instruction with a three-operand form**: `imul $3,%rbx,%rax`
;; multiplies a register by a literal into a DIFFERENT register, so the `mov` that every other
;; binop needs to get its left operand into rax is not needed here. `add` and `sub` have no such
;; form -- `lea` does the arithmetic but sets no flags, and every one of these carries a `jo`.
(:wat::core::defn :c::imul3 [r <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::String
  (:c::imul-rri r n))
(:wat::core::defn :c::reg-load [r <- :wat::core::i64 d <- :wat::core::i64
                                fp? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= r 0) (:c::at-frame fp? "488b5d" "488b9d" "488b5c24" "488b9c24" d))
    ((:wat::core::= r 1) (:c::at-frame fp? "4c8b65" "4c8ba5" "4c8b6424" "4c8ba424" d))
    ((:wat::core::= r 2) (:c::at-frame fp? "4c8b6d" "4c8bad" "4c8b6c24" "4c8bac24" d))
    (:else (:c::at-frame fp? "488b6d" "488bad" "488b6c24" "488bac24" d))))

;; **negating a condition flips bit zero**, which is not a coincidence -- it is why the ISA pairs
;; them the way it does: je(4)/jne(5), jb(2)/jae(3), jl(12)/jge(13), jle(14)/jg(15). So the four
;; jump tables this replaced were one table read four ways.
(:wat::core::defn :c::negate-cc [cc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= (:wat::core::rem cc 2) 0)
    (:wat::core::+ cc 1) (:wat::core::- cc 1)))

;; and the two encodings that carry one: a short displacement rides in the opcode itself, a long
;; one behind a `0f` escape
(:wat::core::defn :c::jcc-rel8 [cc <- :wat::core::i64] -> :wat::core::String
  (:asm::u8 (:wat::core::+ 112 cc)))
(:wat::core::defn :c::jcc-rel32 [cc <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "0f" (:asm::u8 (:wat::core::+ 128 cc))))

;; the unsigned pair the hex routines need: `below` is 2, and negating it gives `above-or-equal`
;; **the five conditions this compiler names.** Three of them lived in lib/runtime.wat until now,
;; not because they were runtime facts but because they sat beside `:c::rt-branch` when C-174 drew
;; the line. A condition code is an x86 fact: it is the low nibble of the opcode, and
;; `:c::negate-cc` flips bit zero, which is why the pairs below are adjacent numbers.
(:wat::core::defn :c::cc-overflow [] -> :wat::core::i64 0)
(:wat::core::defn :c::cc-below [] -> :wat::core::i64 2)
(:wat::core::defn :c::cc-zero [] -> :wat::core::i64 4)
(:wat::core::defn :c::cc-below-eq [] -> :wat::core::i64 6)
;; `js` -- the sign flag, so a subtraction that went negative is tested without a second compare
(:wat::core::defn :c::cc-sign [] -> :wat::core::i64 8)
(:wat::core::defn :c::cc-greater [] -> :wat::core::i64 15)
