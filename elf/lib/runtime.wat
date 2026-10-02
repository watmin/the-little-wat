;; elf/lib/runtime.wat -- the support routines every compiled program carries, and the shape of
;; the objects they operate on.
;;
;; **This is the emitted program's libc**, in about 2 KB: printing, string concatenation and
;; comparison, integer division that traps, the bump allocator, the persistent-vector tree, and
;; the two error exits. A compiled program links none of it from outside -- `:c::runtime` returns
;; the block as hex and `:c::at-*` gives each entry point its address, computed from the length of
;; what precedes it rather than written in by hand.
;;
;; **It knows nothing about wat either** -- no AST, no types, no scopes. It depends only on
;; lib/x86.wat. What it hides is the machine code of the routines and the LAYOUT of a heap object;
;; the compiler above sees only `(:c::call o (:c::at-str rt))`.
;;
;; Testable alone: `tools/rt-disasm.sh` unhexes each routine and disassembles it beside the claim
;; its comment makes -- which is the only way to check a hand-assembled routine at all, and did
;; not exist before C-173.
;;
;; Split out of elf/compile.wat by C-174; see FINDINGS.md.

;; ---------------------------------------------------------------- the runtime
;;
;; Twenty-three routines, 1958 bytes, assembled as ONE block so they can call each other -- which is why
;; the order below is load-bearing. This is the part of the output a C toolchain would link libc
;; for, and `buf_put` is the part libc calls stdio.

;; **the digits, and the sign -- shared by `print_i64` and `i64_to_str`.**
;;
;; They come out BACKWARDS, so they are written backwards: rsi walks DOWN from wherever the
;; caller left it, and the caller measures how far afterwards. `div` leaves the remainder in rdx,
;; and adding `'0'` to its LOW BYTE makes it a character in place.
;;
;; The two callers differ only in where rsi starts and what they do with the result -- one writes
;; it to the output buffer, the other copies it to the heap -- and these fifty-five bytes were
;; identical in both. That is not a thing anyone was going to see in two hex blobs.
(:wat::core::defn :c::rt-digits [] -> :wat::core::String
  (:wat::core::let
    [digit (:wat::string::concat
             (:c::xor-rr (:c::rdx) (:c::rdx))
             (:c::div-r (:c::rcx))
             (:c::add-ri8 (:c::rdx) (:asm::code-of "0"))
             (:c::dec-r (:c::rsi))
             (:c::mov-mr8 (:c::rdx) (:c::rsi) 0)
             (:c::test-rr (:c::rax) (:c::rax)))
     loop (:wat::string::concat digit
            (:c::br-back (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) digit))
     ;; a negative was negated to divide it, and r8 remembers that it was
     sign (:wat::string::concat (:c::neg-r (:c::rax)) (:c::mov-ri (:c::r8) 1))
     minus (:wat::string::concat
             (:c::dec-r (:c::rsi))
             (:c::mov-mi8 (:c::rsi) 0 (:asm::code-of "-")))]
    (:wat::string::concat
      (:c::xor-rr (:c::r8) (:c::r8))
      (:c::test-rr (:c::rax) (:c::rax))
      (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-sign))) sign)
      sign
      (:c::mov-ri (:c::rcx) 10)
      loop
      (:c::test-rr (:c::r8) (:c::r8))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) minus)
      minus)))

;; `print_i64(rax)` -- the digits come out BACKWARDS, so they are written backwards. rsi starts
;; at the end of a stack scratch and walks down; the count at the end is how far it walked.
;;
;; `div` leaves the remainder in rdx, and adding `'0'` to its LOW BYTE turns it into a character
;; in place -- which is what the 8-bit forms are for. The newline is planted first, at the top of
;; the buffer, so it needs no separate write.
(:wat::core::defn :c::rt-print-i64 [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [top -1
     tail (:wat::string::concat
            (:c::lea-at (:c::rbp) top (:c::rdx))
            (:c::sub-rr (:c::rsi) (:c::rdx))
            (:c::inc-r (:c::rdx)))
     head (:wat::string::concat
            (:c::reg-push (:c::rbp)) (:c::mov-rr (:c::rsp) (:c::rbp))
            (:c::sub-ri (:c::rsp) (:c::scratch-frame))
            ;; the newline is planted first, at the top, so it needs no separate write
            (:c::lea-at (:c::rbp) top (:c::rsi))
            (:c::mov-mi8 (:c::rsi) 0 (:c::nl))
            (:c::rt-digits)
            tail)]
    (:wat::string::concat
      head
      (:c::rt-call (:c::at-put lay)
        (:wat::core::+ (:c::at-i64 lay)
          (:wat::core::+ (:c::hexlen head) (:c::call-size))))
      (:c::leave) (:c::ret))))

;; `str_cat_own(rax = left, rcx = right) -> rax` -- `concat` where the compiler has proved the
;; left operand is a last use, so its buffer may be written into rather than copied (F-127).
;;
;; **Two things have to hold and both are checked here.** The left must be one of OUR
;; allocations -- the word before its pointer is the arm -- and the result must still fit the
;; power-of-two block that was allocated for it. Either failing, it falls through to the copying
;; `str_cat`, which is the routine immediately before this one.
(:wat::core::defn :c::rt-str-cat-own [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [head (:c::cmp-mi (:c::rax) (:wat::core::- 0 (:c::vec-ptr)) (:c::heap-arm))
     ;; the copying concat, which both failures hand off to
     to-cat (:wat::core::- (:c::at-cat-own lay) (:c::hexlen (:c::rt-str-cat lay)))
     ;; **`rep movsb` is a string instruction being asked to copy one byte.** F-147 measured
     ;; its startup against a plain byte store in an identical loop: 18.58 cycles an iteration
     ;; against 12.96, so 5.6 cycles of the 6.5 we were behind C on `strbuild` were this one
     ;; instruction. Appending a single character is the string-building idiom, so it gets the
     ;; two instructions that skip the rep entirely. rdx is free here -- it carried
     ;; `newlen + 16` into the compare above and is dead after it.
     one (:wat::string::concat
           (:c::mov-r8m (:c::rsi) 0 (:c::rdx))
           (:c::mov-mr8 (:c::rdx) (:c::rdi) 0)
           (:c::ret))
     fit (:wat::string::concat
           (:c::mov-mr (:c::r11) (:c::rax) 0)
           (:c::rm "8d" (:c::rdi) (:c::rax) (:c::r8) 1 (:c::str-data))
           (:c::lea-at (:c::r9) (:c::str-data) (:c::rsi))
           (:c::cmp-ri (:c::r10) 1)
           (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) one)
           one
           (:c::mov-rr (:c::r10) (:c::rcx))
           (:c::rep-movsb)
           (:c::ret))
     body (:wat::string::concat
            (:c::mov-rr (:c::rcx) (:c::r9))
            (:c::mov-rm (:c::rax) 0 (:c::r8))
            (:c::mov-rm (:c::r9) 0 (:c::r10))
            (:c::mov-rr (:c::r8) (:c::r11))
            (:c::add-rr (:c::r10) (:c::r11))
            (:c::rt-cap (:c::r8) (:c::rdx) (:c::rdi))
            (:c::lea-at (:c::r11) (:c::vec-hdr) (:c::rdx))
            (:c::cmp-rr (:c::rdi) (:c::rdx))
            (:c::br-over (:c::jcc-rel8 (:c::cc-above)) fit)
            fit
            (:c::mov-rr (:c::r9) (:c::rcx)))
     at-jmp (:wat::core::+ (:c::at-cat-own lay)
              (:wat::core::+ (:c::hexlen head)
                (:wat::core::+ (:c::rel32-size) (:c::hexlen body))))]
    (:wat::string::concat
      head
      (:c::rt-branch (:c::negate-cc (:c::cc-zero)) to-cat
        (:wat::core::+ (:c::at-cat-own lay)
          (:wat::core::+ (:c::hexlen head) (:c::rel32-size))))
      body
      (:c::jmp-rel32 (:wat::core::- to-cat (:wat::core::+ at-jmp 5))))))

;; `str_cat(rax = a, rcx = b) -> rax` -- the copying concat. Both source pointers are taken
;; BEFORE the allocation, because allocating writes rcx and rdx.
(:wat::core::defn :c::rt-str-cat [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::mov-rm (:c::rax) 0 (:c::r8))
           (:c::mov-rm (:c::rcx) 0 (:c::r9))
           (:c::lea-at (:c::rax) (:c::str-data) (:c::r10))
           (:c::lea-at (:c::rcx) (:c::str-data) (:c::r11))
           (:c::mov-rr (:c::r8) (:c::rax))
           (:c::add-rr (:c::r9) (:c::rax))
           (:c::rt-cap (:c::rax) (:c::rdx) (:c::rdx)))]
    (:wat::string::concat
      pre
      ;; rcx carries the new top here, not r11 -- r10 and r11 are holding the two sources
      (:c::rt-bump (:wat::core::+ (:c::at-cat lay) (:c::hexlen pre)) lay
        (:c::add-rr (:c::rdx) (:c::rcx)) (:c::rcx) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 (:c::heap-arm))
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::rdx))
      (:c::mov-mr (:c::rax) (:c::rdx) 0)
      (:c::mov-rr (:c::rcx) (:c::r15))
      (:c::lea-at (:c::rdx) (:c::str-data) (:c::rdi))
      ;; the left, then the right, both landing where rdi was left pointing
      (:c::mov-rr (:c::r10) (:c::rsi))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::rep-movsb)
      (:c::mov-rr (:c::r11) (:c::rsi))
      (:c::mov-rr (:c::r9) (:c::rcx))
      (:c::rep-movsb)
      (:c::mov-rr (:c::rdx) (:c::rax))
      (:c::ret))))

;; `divzero()` -- reached only from inside `i64_quot` and `i64_rem`, which is why it has no entry
;; point of its own. `idiv` FAULTS rather than flagging (F-126), so the divisor is tested first.
(:wat::core::defn :c::rt-divzero [lay <- :c::Layout] -> :wat::core::String
  (:c::rt-abort "wat: division by zero" lay (:c::at-divzero lay)))

;; `i64_quot(rax / rcx) -> rax`, guarded. **`idiv` FAULTS rather than flagging** (F-126), so the
;; divisor is tested before the instruction runs, and `MIN / -1` is `neg`+`jo` because `a / -1`
;; is `-a` and overflows in exactly the same place.
;;
;; Both guards branch OUT of this routine -- to `divzero` and to `ovf` -- and those displacements
;; used to be hand-counted hex. They are computed now: every routine's address already comes from
;; the length of what precedes it, so asking the layout at zero gives the distance. Change
;; `:c::rt-divzero`'s length and this jump follows it.
(:wat::core::defn :c::rt-i64-quot [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [guard     (:c::test-rr (:c::rcx) (:c::rcx))
     minus-one (:c::cmp-ri (:c::rcx) -1)
     negate    (:c::neg-r (:c::rax))
     ;; where each piece lands, as a running sum of the pieces before it
     here      (:c::at-quot lay)
     at-je     (:wat::core::+ here (:c::hexlen guard))
     at-jne    (:wat::core::+ at-je (:wat::core::+ (:c::rel32-size) (:c::hexlen minus-one)))
     at-jo     (:wat::core::+ at-jne (:wat::core::+ (:c::rel8-size) (:c::hexlen negate)))
     ;; `divzero` sits immediately before this routine, so its start is ours less its length
     to-divzero (:c::rt-branch (:c::cc-zero)
                  (:c::at-divzero lay)
                  (:wat::core::+ at-je (:c::rel32-size)))
     ;; the `MIN / -1` arm: `a / -1` is `-a`, and it overflows in exactly the same place
     neg-arm   (:wat::string::concat negate
                 (:c::rt-branch (:c::cc-overflow) (:c::at-ovf lay)
                   (:wat::core::+ at-jo (:c::rel32-size)))
                 (:c::ret))]
    (:wat::string::concat
      guard to-divzero minus-one
      (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) neg-arm)
      neg-arm
      (:c::cqto) (:c::idiv-r (:c::rcx)) (:c::ret))))

;; `i64_rem(rax %% rcx) -> rax`, guarded the same way. `rem` by -1 is zero for every dividend --
;; including the one `quot` cannot do -- so this arm needs no overflow check at all.
(:wat::core::defn :c::rt-i64-rem [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [guard     (:c::test-rr (:c::rcx) (:c::rcx))
     minus-one (:c::cmp-ri (:c::rcx) -1)
     here      (:c::at-rem lay)
     at-je     (:wat::core::+ here (:c::hexlen guard))
     to-divzero (:c::rt-branch (:c::cc-zero)
                  (:c::at-divzero lay)
                  (:wat::core::+ at-je (:c::rel32-size)))
     zero-arm  (:wat::string::concat (:c::xor-rr (:c::rax) (:c::rax)) (:c::ret))]
    (:wat::string::concat
      guard to-divzero minus-one
      (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) zero-arm)
      zero-arm
      (:c::cqto) (:c::idiv-r (:c::rcx)) (:c::mov-rr (:c::rdx) (:c::rax)) (:c::ret))))

;; ---------------------------------------------------------------- EDN escaping, in machine code
;;
;; `print_str(rax = s)` prints a String as a quoted literal: the two characters that would end or
;; continue it are escaped AS THEMSELVES, and three control characters are escaped as letters.
;;
;; **It builds the result at r15 WITHOUT allocating.** The heap top is scratch -- nothing is
;; bumped, so the bytes are gone the moment anything else allocates, which is safe only because
;; `buf_put` copies them out before returning. That is why a routine writing an unbounded number
;; of heap bytes needs no `oom` check: it never owns any of them.
;;
;; **The REPL will need a path that does none of this** -- a prompt cannot be printed by a
;; routine that wraps its argument in quotes (see the REPL section of NEXT.md).
(:wat::core::defn :c::esc-slash [] -> :wat::core::i64 (:asm::code-of "\\"))
(:wat::core::defn :c::esc-quote [] -> :wat::core::i64 (:asm::code-of "\""))
;; `\` then a fixed letter -- how a control character is escaped
(:wat::core::defn :c::rt-esc-as [letter <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:c::mov-mi8 (:c::rdi) 0 (:c::esc-slash)) (:c::inc-r (:c::rdi))
    (:c::mov-mi8 (:c::rdi) 0 letter) (:c::inc-r (:c::rdi))))
;; `\` then the character itself -- how a quote or a backslash is escaped
(:wat::core::defn :c::rt-esc-self [] -> :wat::core::String
  (:wat::string::concat
    (:c::mov-mi8 (:c::rdi) 0 (:c::esc-slash)) (:c::inc-r (:c::rdi))
    (:c::mov-mr8 (:c::rax) (:c::rdi) 0) (:c::inc-r (:c::rdi))))
;; one byte, unescaped
(:wat::core::defn :c::rt-emit1 [] -> :wat::core::String
  (:wat::string::concat (:c::mov-mr8 (:c::rax) (:c::rdi) 0) (:c::inc-r (:c::rdi))))
;; a `cmp $ch, %al` and the branch to that character's arm, given the distance to it
(:wat::core::defn :c::rt-esc-test [ch <- :wat::core::i64 to <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::cmp-al ch)
                        (:c::br-len (:c::jcc-rel8 (:c::cc-zero)) to)))

(:wat::core::defn :c::rt-print-str [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    ;; **every distance here is a sum of arm lengths, and the arms are right there.** Each arm
    ;; but the last jumps to the shared tail, so an arm "costs" its own length plus that jump.
    [q (:c::esc-quote)
     plain (:c::rt-emit1)
     self (:c::rt-esc-self)
     as (:c::rt-esc-as (:asm::code-of "n"))
     j (:c::rel8-size)
     pj (:wat::core::+ (:c::hexlen plain) j)
     sj (:wat::core::+ (:c::hexlen self) j)
     aj (:wat::core::+ (:c::hexlen as) j)
     ;; one test is a compare and a branch, and there are five of them before the arms
     tl (:wat::core::+ (:c::hexlen (:c::cmp-al 0)) j)
     dispatch (:wat::string::concat
                (:c::rt-esc-test q (:wat::core::+ (:wat::core::* 4 tl) pj))
                (:c::rt-esc-test (:c::esc-slash) (:wat::core::+ (:wat::core::* 3 tl) pj))
                (:c::rt-esc-test (:c::nl)
                  (:wat::core::+ (:wat::core::* 2 tl) (:wat::core::+ pj sj)))
                (:c::rt-esc-test (:c::tab)
                  (:wat::core::+ tl (:wat::core::+ pj (:wat::core::+ sj aj))))
                (:c::rt-esc-test (:c::cr)
                  (:wat::core::+ pj (:wat::core::+ sj (:wat::core::+ aj aj)))))
     ;; **the distance from each arm to the shared tail is the arms after it**, which is a
     ;; recurrence from the last one back -- and writing it any other way is how two of these
     ;; came out short the first time, each missing the final arm
     aft-t (:c::hexlen as)
     aft-n (:wat::core::+ aj aft-t)
     aft-self (:wat::core::+ aj aft-n)
     aft-plain (:wat::core::+ sj aft-self)
     arms (:wat::string::concat
            plain (:c::br-len "eb" aft-plain)
            self  (:c::br-len "eb" aft-self)
            as    (:c::br-len "eb" aft-n)
            (:c::rt-esc-as (:asm::code-of "t")) (:c::br-len "eb" aft-t)
            (:c::rt-esc-as (:asm::code-of "r")))
     body (:wat::string::concat
            (:c::mov-r8m (:c::rsi) 0 (:c::rax))
            dispatch arms
            (:c::inc-r (:c::rsi)) (:c::inc-r (:c::r11)))
     loop (:wat::string::concat
            (:c::cmp-rr (:c::r9) (:c::r11))
            (:c::br-len (:c::jcc-rel8 (:c::cc-ge)) (:wat::core::+ (:c::hexlen body) j))
            body)
     head (:wat::string::concat
            (:c::mov-rr (:c::rax) (:c::r8))
            (:c::mov-rm (:c::r8) 0 (:c::r9))
            (:c::lea-at (:c::r8) (:c::str-data) (:c::rsi))
            ;; r15 is the cursor and r10 remembers where it started
            (:c::mov-rr (:c::r15) (:c::rdi))
            (:c::mov-rr (:c::r15) (:c::r10))
            (:c::mov-mi8 (:c::rdi) 0 q) (:c::inc-r (:c::rdi))
            (:c::xor-rr (:c::r11) (:c::r11))
            loop (:c::jmp-back loop)
            (:c::mov-mi8 (:c::rdi) 0 q) (:c::inc-r (:c::rdi))
            (:c::mov-mi8 (:c::rdi) 0 (:c::nl)) (:c::inc-r (:c::rdi))
            ;; how far the cursor moved IS the length
            (:c::mov-rr (:c::rdi) (:c::rdx))
            (:c::sub-rr (:c::r10) (:c::rdx))
            (:c::mov-rr (:c::r10) (:c::rsi)))]
    (:wat::string::concat
      head
      (:c::rt-call (:c::at-put lay)
        (:wat::core::+ (:c::at-str lay)
          (:wat::core::+ (:c::hexlen head) (:c::call-size))))
      (:c::ret))))

;; `print_bool(rax)` -- **`true` and `false` are built on the stack**, so the routine needs no data
;; section and no relocation. Five bytes and six, written as a 4+1 and a 4+2, which is why the
;; narrow stores exist at all. The immediates are the WORDS, read little-endian and computed from
;; them: `"true"` is 0x65757274 and nobody has to be trusted to have transcribed it.
(:wat::core::defn :c::rt-print-bool [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [slot -8
     yes (:wat::string::concat
           (:c::mov-mi32 (:c::rbp) slot (:c::pack "true"))
           (:c::mov-mi8 (:c::rbp) (:wat::core::+ slot 4) (:c::nl))
           (:c::mov-ri (:c::rdx) (:wat::string::length "true\n")))
     no (:wat::string::concat
          (:c::mov-mi32 (:c::rbp) slot (:c::pack "fals"))
          ;; the last two characters as one 16-bit store: 'e' low, newline high
          (:c::mov-mi16 (:c::rbp) (:wat::core::+ slot 4)
            (:wat::core::+ (:asm::code-of "e") (:wat::core::* (:c::nl) 256)))
          (:c::mov-ri (:c::rdx) (:wat::string::length "false\n")))
     yes-arm (:wat::string::concat yes (:c::jmp-over no))
     head (:wat::string::concat
            (:c::reg-push (:c::rbp)) (:c::mov-rr (:c::rsp) (:c::rbp))
            (:c::sub-ri (:c::rsp) 16) (:c::test-rr (:c::rax) (:c::rax)))
     tail-at (:wat::core::+ (:c::at-bool lay)
               (:wat::core::+ (:c::hexlen head)
                 (:wat::core::+ (:c::rel8-size)
                   (:wat::core::+ (:c::hexlen yes-arm) (:c::hexlen no)))))
     lea (:c::lea-at (:c::rbp) slot (:c::rsi))]
    (:wat::string::concat
      head
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) yes-arm)
      yes-arm no
      lea
      (:c::rt-call (:c::at-put lay)
        (:wat::core::+ tail-at (:wat::core::+ (:c::hexlen lea) (:c::call-size))))
      (:c::leave) (:c::ret))))

;; `ovf()` -- what a `jo` lands on. i64 arithmetic TRAPS rather than wrapping (the builder's
;; ruling, arc 300), so this is reached by design and not by accident.
(:wat::core::defn :c::rt-ovf [lay <- :c::Layout] -> :wat::core::String
  (:c::rt-abort "wat: i64 overflow" lay (:c::at-ovf lay)))

;; `buf_put(rsi = bytes, rdx = length)` -- append to the output buffer, flushing first if this
;; put would cross the high-water mark. **A put larger than the buffer goes straight to the
;; kernel**: after the flush there is nothing to append to, so it is written where it stands.
(:wat::core::defn :c::rt-buf-put [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [direct (:wat::string::concat
              (:c::mov-ri (:c::rdi) (:c::fd-stdout))
              (:c::mov-ri (:c::rax) (:c::sys-write))
              (:c::syscall) (:c::ret))
     saved (:wat::string::concat (:c::reg-push (:c::rsi)) (:c::reg-push (:c::rdx)))
     head (:wat::string::concat
            (:c::mov-rm (:c::r14) (:c::hdr-pending) (:c::rax))
            (:c::lea (:c::rax) (:c::rdx) 1 0 (:c::rcx))
            (:c::cmp-ri (:c::rcx) (:c::buf-hiwater)))
     at-call (:wat::core::+ (:c::at-put lay)
               (:wat::core::+ (:c::hexlen head)
                 (:wat::core::+ (:c::rel8-size) (:c::hexlen saved))))
     spill (:wat::string::concat
             saved
             (:c::rt-call (:c::at-flush lay) (:wat::core::+ at-call (:c::call-size)))
             (:c::reg-pop (:c::rdx)) (:c::reg-pop (:c::rsi))
             (:c::cmp-ri (:c::rdx) (:c::buf-hiwater))
             (:c::br-over (:c::jcc-rel8 (:c::cc-below-eq)) direct)
             direct
             ;; the buffer is empty now, so the append starts at zero
             (:c::xor-rr (:c::rax) (:c::rax)))]
    (:wat::string::concat
      head
      (:c::br-over (:c::jcc-rel8 (:c::cc-below-eq)) spill)
      spill
      (:c::lea-at (:c::r14) (:c::hdr-buf) (:c::rdi))
      (:c::add-rr (:c::rax) (:c::rdi))
      (:c::add-mr (:c::rdx) (:c::r14) (:c::hdr-pending))
      (:c::mov-rr (:c::rdx) (:c::rcx))
      (:c::rep-movsb)
      (:c::ret))))

;; `flush()`, 36 bytes: write whatever is buffered and empty it. Called before `exit`, before
;; `fork` and before `clone`, and at the end of the entry stub -- see each for why.
;; `flush()` -- write whatever is waiting and reset the count. **The branch over the whole body
;; is what makes this cheap to call**: flushing nothing is a load, a test, and a return.
(:wat::core::defn :c::rt-flush [] -> :wat::core::String
  (:wat::core::let
    [body (:wat::string::concat
            (:c::lea-at (:c::r14) (:c::hdr-buf) (:c::rsi))
            (:c::mov-ri (:c::rdi) (:c::fd-stdout))
            (:c::mov-ri (:c::rax) (:c::sys-write))
            (:c::syscall)
            (:c::mov-mi (:c::r14) (:c::hdr-pending) 0))]
    (:wat::string::concat
      (:c::mov-rm (:c::r14) (:c::hdr-pending) (:c::rdx))
      (:c::test-rr (:c::rdx) (:c::rdx))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) body)
      body
      (:c::ret))))

;; `vec_new(rax = count) -> rax`, 21 bytes: bump r15 past a header and count slots, leaving
;; them uninitialised because the caller is about to fill every one.
;; ---------------------------------------------------------------- allocation
;;
;; **The bump and the check are one thing, and both constructors do it identically.** r15 is the
;; heap pointer and r14+8 is where it must stop; the new top is computed into r11 FIRST, so the
;; comparison is against the address the allocation would end at rather than against a size.
;; `jbe` rather than `jb` because ending exactly at the limit is fine.
;;
;; The call to `oom` is a real call and not a jump: it never returns, but a `call` leaves a
;; return address, and that address is what a stack trace would need. It is also five bytes
;; whose displacement is now computed from the layout rather than counted by hand.
;; ---------------------------------------------------------------- stopping, with a reason
;;
;; **`ovf`, `oom` and `divzero` were three copies of one routine.** Each flushes what stdout had,
;; builds a message on the stack, writes it to stderr and exits 70; they differ in the message and
;; in nothing else. That was invisible as three hex blobs of 89, 89 and 95 bytes.
;;
;; The message is built by STORES rather than read from a data section, so the binary needs no
;; relocation and no .rodata: eight characters at a time as a `movabs` and a store, and a tail of
;; four or fewer as their 32-bit halves. The immediates ARE the text -- `0x343669203a746177` is
;; "wat: i64" read little-endian -- and they are computed from it here, never transcribed.
;;
;; The newline is appended by `:c::abort-byte` rather than written into the literal, because a
;; `"\n"` in a wat literal is one byte to the interpreter and two to this compiler (F-120), and
;; the message's LENGTH depends on the answer. `:wat::string::byte-at` gives the same byte to
;; both, which is the portable family earning its keep the day after it was added (F-139).
;; **a small stack scratch, big enough for the longest thing built in it.** Two routines want
;; one: an abort message (22 bytes at most) and `print_i64`'s digits (an i64 is at most 20 of
;; them, plus a sign and a newline). 32 covers both with room, and it is one fact rather than the
;; same number written twice for different reasons.
(:wat::core::defn :c::scratch-frame [] -> :wat::core::i64 32)
(:wat::core::defn :c::abort-byte [msg <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::string::byte-length msg)) (:c::nl)
    (:wat::string::byte-at msg i)))
(:wat::core::defn :c::abort-pack [msg <- :wat::core::String from <- :wat::core::i64
                                  i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< i from) acc
    (:c::abort-pack msg from (:wat::core::- i 1)
      (:wat::core::+ (:wat::core::* acc 256) (:c::abort-byte msg i)))))
(:wat::core::defn :c::abort-chunks [n <- :wat::core::i64 msg <- :wat::core::String
                                    i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i n) acc
    (:wat::core::let [left (:wat::core::- n i)
                      last (:wat::core::- n 1)]
      (:wat::core::cond
        ;; four bytes or fewer: the 32-bit halves
        ((:wat::core::<= left 4)
          (:wat::string::concat acc
            (:c::mov-ri32 (:c::rax) (:c::abort-pack msg i last 0))
            (:c::mov-mr32 (:c::rax) (:c::rsp) i)))
        ;; five to seven: one 64-bit store whose high bytes are zero and simply not written
        ((:wat::core::< left 8)
          (:wat::string::concat acc
            (:c::movabs (:c::rax) (:c::abort-pack msg i last 0))
            (:c::mov-mr (:c::rax) (:c::rsp) i)))
        (:else
          (:c::abort-chunks n msg (:wat::core::+ i 8)
            (:wat::string::concat acc
              (:c::movabs (:c::rax) (:c::abort-pack msg i (:wat::core::+ i 7) 0))
              (:c::mov-mr (:c::rax) (:c::rsp) i))))))))

;; `abort(msg)` -- the body all three error exits share. `at` is where this routine starts.
(:wat::core::defn :c::rt-abort [msg <- :wat::core::String lay <- :c::Layout
                                at <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [n (:wat::core::+ (:wat::string::byte-length msg) 1)]
    (:wat::string::concat
      (:c::rt-call (:c::at-flush lay) (:wat::core::+ at (:c::call-size)))
      (:c::sub-ri (:c::rsp) (:c::scratch-frame))
      (:c::abort-chunks n msg 0 "")
      (:c::mov-ri (:c::rdi) (:c::fd-stderr))
      (:c::mov-rr (:c::rsp) (:c::rsi))
      (:c::mov-ri (:c::rdx) n)
      (:c::mov-ri (:c::rax) (:c::sys-write))
      (:c::syscall)
      (:c::mov-ri (:c::rdi) (:c::exit-fail))
      (:c::mov-ri (:c::rax) (:c::sys-exit))
      (:c::syscall))))

;; **the allocation a String of `len` bytes needs: the next power of two at or above len+16.**
;; `bsr` gives the index of the highest set bit -- a base-2 logarithm for free -- and shifting 2
;; by it rounds up. `str_subs` and `str_cat_own` computed this identically and separately.
;; `scratch` holds `len+15` only long enough for `bsr` to read it, and the callers do not agree
;; on which register that is -- three use rdx and `i64_to_str` reuses `out`. It is a parameter
;; rather than a choice made here, because the caller is the one holding everything else.
;; the rounding `bsr` needs to reach the NEXT power of two rather than the current one
(:wat::core::defn :c::cap-bias [] -> :wat::core::i64 15)
(:wat::core::defn :c::rt-cap [len <- :wat::core::i64 scratch <- :wat::core::i64
                              out <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:c::lea-at len (:c::cap-bias) scratch)
    (:c::bsr-rr scratch (:c::rcx))
    (:c::mov-ri out 2)
    (:c::shl-cl out)))

;; `grow` is how `top` reaches the new top: `add %rcx,top` when the size was computed into rcx,
;; or `add $imm,top` when it is a constant. That is the ONLY difference between the allocators
;; that bump at all, and it was the reason each carried its own copy of the check.
;;
;; `base` is where the allocation STARTS (`r15` for every ordinary allocator; `r8` for the two
;; sites that read raw bytes onto the heap top as scratch before deciding where the real object
;; begins -- `:c::rt-prim-read-hex`, `:c::rt-io-read-file`). `top` is `base`'s own register
;; before this runs, used BOTH to hold the prospective new top while `grow` computes it AND,
;; after the caller's own trailing commit (`mov-rr top base-register`), to become the real heap
;; pointer again -- unchanged by anything below when no reuse happens, exactly as before M2.
;;
;; `reuse? = false` is `:c::rt-vec-conj-own`'s path 3 ONLY (`extend`, including its own base-0
;; measuring twin): growing the YOUNGEST object by one word over the heap top is not allocating a
;; new block, it is extending a live one, and redirecting it to a free-list hole would silently
;; relocate live bytes with nothing else told. Every other caller allocates a genuinely new
;; block and passes `true`.
;;
;; excursus 008 M2: when `reuse?` is true, this ALSO tries the free lists FIRST, entirely inside
;; this one generator so no call site needs auditing -- every register beyond `top`/`base` that
;; this uses (`r9`, `r10`, `r12`) is pushed at entry and popped before every exit, so the result
;; is identical to the plain bump-and-check for any caller that happens to be holding something
;; in them, by construction, not by checking. The SIZE needed to classify the allocation is never
;; a new parameter: it is `top - base` once `grow` has run (base is untouched by `grow`), which
;; works whether `grow` added a register or an immediate.
(:wat::core::defn :c::rt-bump [here <- :wat::core::i64 lay <- :c::Layout
                               grow <- :wat::core::String
                               top <- :wat::core::i64 base <- :wat::core::i64
                               reuse? <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if (:wat::core::not reuse?)
    (:wat::core::let
      [chk (:wat::string::concat
             (:c::mov-rr base top)
             grow
             (:c::cmp-rm (:c::r14) (:c::hdr-limit) top))
       at-call (:wat::core::+ here (:wat::core::+ (:c::hexlen chk) (:c::rel8-size)))
       to-oom (:c::rt-call (:c::at-oom lay) (:wat::core::+ at-call (:c::call-size)))]
      (:wat::string::concat chk (:c::jbe-over to-oom) to-oom))
    (:wat::core::let
      [head (:wat::string::concat (:c::mov-rr base top) grow)
       pushes (:wat::string::concat
                (:c::reg-push (:c::r9)) (:c::reg-push (:c::r10)) (:c::reg-push (:c::r12)))
       pops (:wat::string::concat
              (:c::reg-pop (:c::r12)) (:c::reg-pop (:c::r10)) (:c::reg-pop (:c::r9)))
       ;; r9 := size (top - base; `base` is still the original value, `grow` never touches it)
       size-calc (:wat::string::concat (:c::mov-rr top (:c::r9)) (:c::sub-rr base (:c::r9)))
       cmp-small (:c::cmp-ri (:c::r9) (:c::small-max))
       ;; SMALL class address -> r10, index (size>>3)-1, an EXACT match (0..63 for 8..512)
       small-calc (:wat::string::concat
                    (:c::mov-rr (:c::r9) (:c::r10))
                    (:c::shr-ri (:c::r10) 3)
                    (:c::sub-ri (:c::r10) 1)
                    (:c::lea (:c::r14) (:c::r10) 8 (:c::hdr-small) (:c::r10)))
       ;; LARGE power-of-two test: r10 := (size-1) & size; ZF set iff size is a power of two.
       ;; `:c::and-rr`'s src/dst are (r9,r10) so r9 (size) survives for `:c::bsr-rr` below.
       large-test (:wat::string::concat
                    (:c::mov-rr (:c::r9) (:c::r10))
                    (:c::sub-ri (:c::r10) 1)
                    (:c::and-rr (:c::r9) (:c::r10))
                    (:c::test-rr (:c::r10) (:c::r10)))
       ;; LARGE class address -> r10, index bsr(size), reusing `:c::rt-cap`'s own rounding
       large-calc (:wat::string::concat
                    (:c::bsr-rr (:c::r9) (:c::r10))
                    (:c::lea (:c::r14) (:c::r10) 8 (:c::hdr-large) (:c::r10)))
       ;; read the chosen class's head into r9; ZF set iff the list is empty. The head is a
       ;; BLOCK START (`:c::free-tail-emit` pushes `r10`, never the type-specific pointer
       ;; `rax` was -- F1 of this strike's second mistake: pushing `rax` put the popped value
       ;; `:c::vec-ptr`/`:c::varr-ptr` bytes past the real block, corrupting whatever sat
       ;; just past the allocation).
       read-head (:wat::string::concat (:c::mov-rm (:c::r10) 0 (:c::r9)) (:c::test-rr (:c::r9) (:c::r9)))
       ;; FOUND: unlink (the next pointer lives in the dead block's own first word, [r9+0] --
       ;; NOT [r9-8], matching `:c::free-tail-emit`'s push), hand the block back as the
       ;; allocation (base := r9), restore the real top (top := the UNCHANGED original base
       ;; value -- no bump happened, so the caller's own trailing `mov-rr top base-register`
       ;; must be a no-op), then skip the bump/oom tail entirely.
       found-body (:wat::string::concat
                    (:c::mov-rm (:c::r9) 0 (:c::r12))
                    (:c::mov-mr (:c::r12) (:c::r10) 0)
                    (:c::mov-rr base top)
                    (:c::mov-rr (:c::r9) base)
                    pops)
       ;; the tail every path that gives up on reuse still runs: byte-identical to the
       ;; non-reuse branch's own check, computed from `here` plus everything emitted before it
       tail-chk (:c::cmp-rm (:c::r14) (:c::hdr-limit) top)
       pre-call-len (:wat::core::+ (:c::hexlen head)
                      (:wat::core::+ (:c::hexlen pushes)
                        (:wat::core::+ (:c::hexlen size-calc)
                          (:wat::core::+ (:c::hexlen cmp-small)
                            (:wat::core::+ (:c::rel8-size)
                              (:wat::core::+ (:c::hexlen small-calc)
                                (:wat::core::+ (:c::rel8-size)
                                  (:wat::core::+ (:c::hexlen large-test)
                                    (:wat::core::+ (:c::rel8-size)
                                      (:wat::core::+ (:c::hexlen large-calc)
                                        (:wat::core::+ (:c::hexlen read-head)
                                          (:wat::core::+ (:c::rel8-size)
                                            (:wat::core::+ (:c::hexlen found-body)
                                              (:wat::core::+ (:c::rel8-size)
                                                (:wat::core::+ (:c::hexlen pops)
                                                  (:c::hexlen tail-chk))))))))))))))))
       at-call (:wat::core::+ here (:wat::core::+ pre-call-len (:c::rel8-size)))
       to-oom (:c::rt-call (:c::at-oom lay) (:wat::core::+ at-call (:c::call-size)))
       tail (:wat::string::concat tail-chk (:c::jbe-over to-oom) to-oom)
       ;; what `pop-then-tail` IS -- `found-body`'s own jump has to skip exactly this much
       ;; (its OWN pops already ran inside `found-body`; this second `pops` is the OTHER two
       ;; paths' -- empty list, abandoned class -- and `found-exit` must clear both it and
       ;; `tail` to reach the true end, not just `tail` alone)
       pop-then-tail (:wat::string::concat pops tail)
       found-exit (:wat::string::concat found-body (:c::jmp-over pop-then-tail))
       have-slot (:wat::string::concat read-head
                   (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) found-exit) found-exit)
       ;; the LARGE test and class-address calc ALONE, so SMALL's own unconditional jump
       ;; (below) can skip exactly this much and land on `have-slot` -- NOT also skip
       ;; `have-slot` itself, which `(:c::jmp-over large-decide)` did (F1 of this strike's
       ;; third mistake: the SMALL path's own computed class address was always abandoned
       ;; unread, so a freed small shape could be pushed but never popped).
       large-only (:wat::string::concat large-test
                    (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero)))
                      (:wat::string::concat large-calc have-slot))
                    large-calc)
       large-decide (:wat::string::concat large-only have-slot)
       small-section (:wat::string::concat small-calc (:c::jmp-over large-only))]
      (:wat::string::concat
        head pushes size-calc cmp-small
        (:c::br-over (:c::jcc-rel8 (:c::cc-greater)) small-section)
        small-section large-decide pop-then-tail))))

;; `vec_new(rax = len) -> rax` -- a record, whose arm word says which one. The size is
;; `hdr + len*8` and `lea` computes it without touching a flag: scale 8, no base at all, which
;; is the SIB form whose base field means "none".
(:wat::core::defn :c::rt-vec-new [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [size (:c::lea (:c::no-reg) (:c::rax) (:c::word) (:c::vec-hdr) (:c::rcx))]
    (:wat::string::concat
      size
      (:c::rt-bump (:wat::core::+ (:c::at-vnew lay) (:c::hexlen size)) lay
        (:c::add-rr (:c::rcx) (:c::r11)) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 1)
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r10))
      (:c::mov-mr (:c::rax) (:c::r10) 0)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::ret))))

;; **a copied pointer slot is one more reference.** `rax` holds a word. A null, a unit tag, or
;; any integer below a page is not a pointer. A block whose header is 0 is a literal in the
;; read-only tail: counting it would write there. Anything else is a heap object, and the copy
;; just made a second reference, so the count goes up. The caller has already decided that
;; these slots ARE pointers; an `i64` slot never reaches here.
(:wat::core::defn :c::inc-if-ptr [] -> :wat::core::String
  (:wat::core::let
    [inc (:c::bare-hex)
     nz (:wat::string::concat "488378f800"
          (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) inc) inc)
     big (:wat::string::concat "483d00100000"
          (:c::br-over (:c::jcc-rel8 (:c::cc-below)) nz) nz)]
    (:wat::string::concat
      (:c::test-rr (:c::rax) (:c::rax))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) big)
      big)))

;; walk `rcx` slots at `rsi`, skipping index `rdx` (`-1` skips none). `rbx` is preserved.
(:wat::core::defn :c::count-span [] -> :wat::core::String
  (:wat::core::let
    [bump (:c::inc-if-ptr)
     one (:wat::string::concat
           (:c::rm "8b" (:c::rax) (:c::rsi) (:c::rbx) (:c::word) 0)
           bump)
     work (:wat::string::concat
            (:c::cmp-rr (:c::rdx) (:c::rbx))
            (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) one)
            one
            (:c::inc-r (:c::rbx)))
     guard (:wat::string::concat
             (:c::cmp-rr (:c::rcx) (:c::rbx))
             (:c::br-len (:c::jcc-rel8 (:c::negate-cc (:c::cc-below)))
               (:wat::core::+ (:c::hexlen work) (:c::rel8-size))))
     body (:wat::string::concat guard work)]
    (:wat::string::concat
      (:c::reg-push (:c::rbx))
      (:c::xor-rr (:c::rbx) (:c::rbx))
      body
      (:c::jmp-back body)
      (:c::reg-pop (:c::rbx)))))

;; `rdi` is one past the last copied slot, `r8` is how many were copied, `rbx` is nonzero
;; when those slots are pointers. The new element the caller stores AFTER this is not in
;; the range: it was counted at the conj site, or it is a fresh word.
(:wat::core::defn :c::count-copied [] -> :wat::core::String
  (:wat::core::let
    [span (:wat::string::concat
            (:c::mov-rr (:c::rdi) (:c::rsi))
            (:c::mov-rr (:c::r8) (:c::rax))
            (:c::shl-ri (:c::rax) 3)
            (:c::sub-rr (:c::rax) (:c::rsi))
            (:c::mov-rr (:c::r8) (:c::rcx))
            (:c::mov-ri (:c::rdx) -1)
            (:c::count-span))]
    (:wat::string::concat
      (:c::test-rr (:c::rbx) (:c::rbx))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) span)
      span)))

;; `vec_conj_own(rax = vec, rcx = value) -> rax` -- `conj` where the compiler has PROVED the
;; container is a last use (F-127), so the copy may sometimes be skipped entirely.
;;
;; **Four paths, and only the last one copies.** In order of how much they save:
;;
;;   * the Vector is a TRIE, not a flat array -> hand off to the copying `vec_conj`;
;;   * its TAG is `:c::vec-flat-own`, AND its count is exactly one (nobody else shares the
;;     block), AND the new element fits the power-of-two block it was given -> write the
;;     element in place and bump the length. Nothing is allocated at all;
;;   * its count is `:c::heap-arm` (one) and its last element ENDS EXACTLY AT THE HEAP TOP ->
;;     it was the most recent allocation, so the heap can simply be extended by one word over it;
;;   * otherwise -> copy, and tag the copy `:c::vec-flat-own` so the next `conj` can take path
;;     two -- the COUNT word is left holding a real count, one, same as any other allocation
;;     (excursus 008 F2: `:c::arm-own` used to be written there instead, so the ordinary
;;     increment/decrement every type's refcounting uses could never bring it back to zero).
;;
;; That third test is the whole trick: `lea 0x8(%rax,%r8,8)` is the address just past the last
;; element, and comparing it to r15 asks "is this vector the youngest thing on the heap?"
(:wat::core::defn :c::rt-vec-conj-own [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [P (:c::at-vconj-own lay)
     w (:c::word)
     ;; the sizes, each a power-of-two rounding of a byte count
     used-plus-one (:wat::core::+ w (:c::cap-bias))
     need (:wat::core::+ (:c::varr-hdr) w)
     fresh (:wat::core::+ (:c::varr-ptr) (:c::cap-bias))
     bump-len (:wat::string::concat
                (:c::lea-at (:c::r8) 1 (:c::rdx))
                (:c::mov-mr (:c::rdx) (:c::rax) 0)
                (:c::ret))
     ;; path 3: the vector is the youngest allocation, so grow the heap over it. `:c::rt-bump`'s
     ;; emitted length never depends on the VALUE of its address argument (every encoding here
     ;; is fixed-width), only on its own shape -- so this placeholder (address 0) measures the
     ;; real `extend`'s length before that address is known, to size `fallback`'s skip below.
     extend-grow (:c::add-ri (:c::r11) w)
     extend-tail (:wat::string::concat
                   (:c::mov-mr (:c::rcx) (:c::r15) 0)
                   (:c::mov-rr (:c::r11) (:c::r15))
                   bump-len)
     ;; path 3 is an EXTEND, not a new allocation (M2: `reuse?` false) -- the youngest object's
     ;; block is grown by one word over the heap top, so a free-list hole must never be offered.
     extend-at0 (:wat::string::concat
                  (:c::rt-bump 0 lay extend-grow (:c::r11) (:c::r15) false) extend-tail)
     ;; path 2: it has room inside the block it was already given
     grown-test (:wat::string::concat
                  (:c::mov-rm (:c::rax) 0 (:c::r8))
                  (:c::mov-rr (:c::rcx) (:c::r9))
                  (:c::lea (:c::no-reg) (:c::r8) w used-plus-one (:c::rdx))
                  (:c::bsr-rr (:c::rdx) (:c::rcx))
                  (:c::mov-ri (:c::rdx) 2)
                  (:c::shl-cl (:c::rdx))
                  (:c::lea (:c::no-reg) (:c::r8) w need (:c::r11))
                  (:c::cmp-rr (:c::rdx) (:c::r11)))
     grown-tail (:wat::string::concat
                  (:c::rm "89" (:c::r9) (:c::rax) (:c::r8) w (:c::vec-data))
                  bump-len)
     grown (:wat::string::concat grown-test
             (:c::br-len (:c::jcc-rel8 (:c::cc-above)) (:c::hexlen grown-tail))
             grown-tail)
     ;; **the tag is `:c::vec-tree` or not** -- never "is it `:c::vec-flat`": a flat-but-owned
     ;; block (`:c::vec-flat-own`) must take this SAME fall-through, not the trie hand-off
     ;; (excursus 008 F2).
     head (:c::cmp-mi (:c::rax) (:wat::core::- 0 (:c::varr-ptr)) (:c::vec-tree))
     ;; count word only, now that the owned mark lives in the tag: "is this the one and only
     ;; reference" -- `:c::heap-arm` is the literal 1, the count every fresh allocation starts
     ;; at and the only count path 2 or path 3 may act on.
     flat-test (:c::cmp-mi (:c::rax) (:wat::core::- 0 w) (:c::heap-arm))
     ;; path 2's test is now two conditions, AND'd: the tag says the block has spare capacity
     ;; (`:c::vec-flat-own`), and the count says nobody else shares it (reusing `flat-test`'s
     ;; exact bytes for the second half -- same comparison, same meaning). A tag mismatch skips
     ;; the count check entirely and leaves ZF as the tag check left it (not equal), so the far
     ;; jump below to `grown` is not taken either way.
     own-test (:wat::string::concat
                (:c::cmp-mi (:c::rax) (:wat::core::- 0 (:c::varr-ptr)) (:c::vec-flat-own))
                (:c::br-len (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) (:c::hexlen flat-test))
                flat-test)
     tail-test (:wat::string::concat
                 (:c::mov-rm (:c::rax) 0 (:c::r8))
                 (:c::rm "8d" (:c::rdx) (:c::rax) (:c::r8) w (:c::vec-data))
                 (:c::cmp-rr (:c::r15) (:c::rdx)))
     fallback (:wat::string::concat
                (:c::mov-rr (:c::rcx) (:c::r9))
                (:c::br-len "eb" (:wat::core::+ (:c::hexlen extend-at0) (:c::hexlen grown))))
     a-j1 (:wat::core::+ P (:c::hexlen head))
     a-j2 (:wat::core::+ a-j1
            (:wat::core::+ (:c::rel32-size)
              (:wat::core::+ (:c::hexlen own-test)
                (:wat::core::+ (:c::rel8-size) (:c::hexlen flat-test)))))
     ;; the address `extend` begins at, as a sum of the pieces that precede it -- not a
     ;; remembered number: own-test's length changed under F2, and a literal here (as it used
     ;; to be, "56") would have gone stale silently instead of moving with it.
     pre-extend (:wat::core::+ (:wat::core::- a-j2 P)
                  (:wat::core::+ (:c::rel32-size)
                    (:wat::core::+ (:c::hexlen tail-test)
                      (:wat::core::+ (:c::rel8-size) (:c::hexlen fallback)))))
     extend (:wat::string::concat
              (:c::rt-bump (:wat::core::+ P pre-extend) lay extend-grow (:c::r11) (:c::r15) false)
              extend-tail)
     ;; the address `copy` begins at -- `extend`'s real length equals `extend-at0`'s by
     ;; construction (same fixed-width encoding, a different address plugged in), so this is
     ;; exact, not an approximation.
     pre-copy (:wat::core::+ pre-extend (:wat::core::+ (:c::hexlen extend) (:c::hexlen grown)))
     ;; path 4: copy, and tag the copy so the next conj can take path two
     copy-pre (:wat::string::concat
                (:c::mov-rm (:c::rax) 0 (:c::r8))
                (:c::lea (:c::no-reg) (:c::r8) w fresh (:c::rdx))
                (:c::bsr-rr (:c::rdx) (:c::rcx))
                (:c::mov-ri (:c::rdx) 2)
                (:c::shl-cl (:c::rdx)))
     copy (:wat::string::concat
            copy-pre
            (:c::rt-bump (:wat::core::+ P (:wat::core::+ pre-copy (:c::hexlen copy-pre))) lay
              (:c::add-rr (:c::rdx) (:c::r11)) (:c::r11) (:c::r15) true)
            (:c::mov-mi (:c::r15) 0 (:c::vec-flat-own))
            (:c::mov-mi (:c::r15) w 1)
            ;; r10 is still the caller's flag; the next lea spends the register
            (:c::reg-push (:c::rbx))
            (:c::mov-rr (:c::r10) (:c::rbx))
            (:c::lea-at (:c::r15) (:c::varr-ptr) (:c::r10))
            (:c::lea-at (:c::r8) 1 (:c::rdx))
            (:c::mov-mr (:c::rdx) (:c::r10) 0)
            (:c::lea-at (:c::r10) (:c::vec-data) (:c::rdi))
            (:c::lea-at (:c::rax) (:c::vec-data) (:c::rsi))
            (:c::mov-rr (:c::r8) (:c::rcx))
            (:c::rep-movsq)
            (:c::count-copied)
            (:c::reg-pop (:c::rbx))
            (:c::mov-mr (:c::r9) (:c::rdi) 0)
            (:c::mov-rr (:c::r11) (:c::r15))
            (:c::mov-rr (:c::r10) (:c::rax))
            (:c::ret))]
    (:wat::string::concat
      head
      (:c::rt-branch (:c::cc-zero) (:c::at-vconj lay)
        (:wat::core::+ a-j1 (:c::rel32-size)))
      own-test
      (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
        (:wat::core::+ (:c::hexlen flat-test)
          (:wat::core::+ (:c::rel32-size)
            (:wat::core::+ (:c::hexlen tail-test)
              (:wat::core::+ (:c::rel8-size)
                (:wat::core::+ (:c::hexlen fallback) (:c::hexlen extend)))))))
      flat-test
      (:c::rt-branch (:c::negate-cc (:c::cc-zero)) (:c::at-vconj lay)
        (:wat::core::+ a-j2 (:c::rel32-size)))
      tail-test
      (:c::br-len (:c::jcc-rel8 (:c::cc-zero)) (:c::hexlen fallback))
      fallback extend grown copy)))

;; `varr_new(rax = len) -> rax` -- a Vector's leaf array, which carries one more header word
;; than a record does and is otherwise the same allocation
(:wat::core::defn :c::rt-varr-new [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [size (:c::lea (:c::no-reg) (:c::rax) (:c::word) (:c::varr-hdr) (:c::rcx))]
    (:wat::string::concat
      size
      (:c::rt-bump (:wat::core::+ (:c::at-varr lay) (:c::hexlen size)) lay
        (:c::add-rr (:c::rcx) (:c::r11)) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 0)
      (:c::mov-mi (:c::r15) (:c::word) 1)
      (:c::lea-at (:c::r15) (:c::varr-ptr) (:c::r10))
      (:c::mov-mr (:c::rax) (:c::r10) 0)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::ret))))

;; `node_new() -> rax` -- a fresh 32-way tree node, every child slot zeroed. The allocation is a
;; constant size, which is the one thing that differs from `vec_new`: the bump adds an immediate
;; instead of rcx.
(:wat::core::defn :c::rt-node-new [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [slots (:wat::core::* (:c::node-arity) (:c::word))
     bump (:c::rt-bump (:c::at-nnew lay) lay
            (:c::add-ri (:c::r11) (:wat::core::+ (:c::vec-hdr) slots)) (:c::r11) (:c::r15) true)]
    (:wat::string::concat
      bump
      (:c::mov-mi (:c::r15) 0 1)
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r10))
      (:c::mov-mi (:c::r10) 0 (:c::node-arity))
      ;; zero every child slot: `rep stos` writes rcx quadwords of rax at (rdi)
      (:c::lea-at (:c::r10) (:c::node-data) (:c::rdi))
      (:c::mov-ri (:c::rcx) (:c::node-arity))
      (:c::xor-rr (:c::rax) (:c::rax))
      (:c::rep-stosq)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::ret))))

;; `node_copy(rax) -> rax` -- a fresh node with the same children. **`rep movsq` is a loop the
;; hardware runs**: rcx quadwords from (rsi) to (rdi), which is the entire body of the copy.
(:wat::core::defn :c::rt-node-copy [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    ;; rdx is tree_push's shift, live across this call: count-span spends it as the
    ;; skip index. r11 is the caller's "these slots are pointers" flag, and node_new
    ;; spends r11 on the bump. Three pushes keep the call aligned. The flag sits at
    ;; [rsp+8] and the shift at [rsp+16] once rbx is on top.
    [pre (:wat::string::concat
           (:c::reg-push (:c::rdx))
           (:c::reg-push (:c::r11))
           (:c::reg-push (:c::rbx))
           (:c::mov-rr (:c::rax) (:c::rbx)))
     at-call (:wat::core::+ (:c::at-ncopy lay) (:c::hexlen pre))
     span (:wat::string::concat
            (:c::lea-at (:c::rax) (:c::node-data) (:c::rsi))
            (:c::mov-ri (:c::rcx) (:c::node-arity))
            (:c::mov-ri (:c::rdx) -1)
            (:c::reg-push (:c::rax))
            (:c::count-span)
            (:c::reg-pop (:c::rax))
            ;; count-span spent rdx; the shift is still on the stack
            (:c::mov-rm (:c::rsp) 16 (:c::rdx)))]
    (:wat::string::concat
      pre
      (:c::rt-call (:c::at-nnew lay) (:wat::core::+ at-call (:c::call-size)))
      (:c::mov-rm (:c::rsp) 8 (:c::r11))
      (:c::lea-at (:c::rax) (:c::node-data) (:c::rdi))
      (:c::lea-at (:c::rbx) (:c::node-data) (:c::rsi))
      (:c::mov-ri (:c::rcx) (:c::node-arity))
      (:c::rep-movsq)
      (:c::test-rr (:c::r11) (:c::r11))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) span)
      span
      (:c::reg-pop (:c::rbx))
      (:c::reg-pop (:c::r11))
      (:c::reg-pop (:c::rdx))
      (:c::ret))))

;; `tree_get(rax = vec, rcx = index) -> rax`. A Vector is a 32-way trie: `shift` says how many
;; bits of the index the current level consumes, and each level takes five bits and descends into
;; the child at that slot. **The loop's backward jump needs no label** -- its displacement is the
;; length of the body it jumps over, plus its own two bytes.
(:wat::core::defn :c::rt-tree-get [] -> :wat::core::String
  (:wat::core::let
    [bits 5
     ;; one level: index >> shift, masked to five bits, is the slot; follow it
     step (:wat::string::concat
            (:c::mov-rr (:c::rdx) (:c::rax))
            (:c::mov-rr (:c::rsi) (:c::rcx))
            (:c::shr-cl (:c::rax))
            (:c::and-ri (:c::rax) 31)
            (:c::rm "8b" (:c::rdi) (:c::rdi) (:c::rax) (:c::word) (:c::node-data))
            (:c::sub-ri (:c::rsi) bits))
     ;; the test sits at the TOP, so the body is the step plus the jump back over both
     body (:wat::string::concat step (:c::jmp-back
            (:wat::string::concat (:c::test-rr (:c::rsi) (:c::rsi))
                                  (:c::jcc-rel8 (:c::cc-zero)) "00" step)))
     leaf (:wat::string::concat
            (:c::mov-rr (:c::rdx) (:c::rax))
            (:c::and-ri (:c::rax) 31)
            (:c::rm "8b" (:c::rax) (:c::rdi) (:c::rax) (:c::word) (:c::node-data))
            (:c::reg-pop (:c::rdi)) (:c::reg-pop (:c::rsi)) (:c::reg-pop (:c::rdx))
            (:c::ret))]
    (:wat::string::concat
      (:c::reg-push (:c::rdx)) (:c::reg-push (:c::rsi)) (:c::reg-push (:c::rdi))
      (:c::mov-rr (:c::rcx) (:c::rdx))
      (:c::mov-rm (:c::rax) (:c::vec-shift) (:c::rsi))
      (:c::mov-rm (:c::rax) (:c::vec-root) (:c::rdi))
      (:c::test-rr (:c::rsi) (:c::rsi))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) body)
      body
      leaf)))

;; `tree_push(rax = vec, rcx = value) -> rax` -- append to a Vector held as a 32-way trie, by
;; **copying the path** from the root to the leaf and sharing everything else. That is what makes
;; the structure persistent: the old Vector is still valid and still points at the untouched
;; siblings of every node on the path.
;;
;; Three things happen in order. If the trie is FULL -- capacity is `32 << shift` and the count
;; has reached it -- a new root is made with the old one as its first child and the shift grows
;; by five. Then the root is copied, and the descent copies each node it passes (or makes one
;; where the trie was empty), five bits of the index at a time. Finally the value goes in the
;; leaf and a new Vector object is allocated to carry the new count, shift and root.
;;
;; `shift` is pushed across the descent because the loop consumes it and the new object needs it.
(:wat::core::defn :c::rt-tree-push [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [bits 5
     mask (:wat::core::- (:c::node-arity) 1)
     one (:c::mov-ri (:c::r11) 1)
     pre (:wat::string::concat
           ;; r10 is the caller's "elements are pointers" flag. Keep it in rbp, and
           ;; hand it back in r10 so a loop of pushes still sees it.
           (:c::reg-push (:c::rbp))
           (:c::mov-rr (:c::r10) (:c::rbp))
           (:c::reg-push (:c::rbx)) (:c::reg-push (:c::r12)) (:c::reg-push (:c::r13))
           (:c::mov-rr (:c::rcx) (:c::r12))
           (:c::mov-rm (:c::rax) 0 (:c::r13))
           (:c::mov-rm (:c::rax) (:c::vec-shift) (:c::rdx))
           (:c::mov-rm (:c::rax) (:c::vec-root) (:c::r9))
           ;; capacity = arity << shift
           (:c::mov-ri (:c::r10) (:c::node-arity))
           (:c::mov-rr (:c::rdx) (:c::rcx))
           (:c::shl-cl (:c::r10))
           (:c::cmp-rr (:c::r13) (:c::r10)))
     a-grow (:wat::core::+ (:c::at-tpush lay)
              (:wat::core::+ (:c::hexlen pre) (:c::rel8-size)))
     ;; the trie is full: a new root, with the old one beneath it
     ;; the old root is now a child of the new one: that is one more reference
     grow (:wat::string::concat
            (:c::rt-call (:c::at-nnew lay) (:wat::core::+ a-grow (:c::call-size)))
            (:c::mov-mr (:c::r9) (:c::rax) (:c::node-data))
            (:c::reg-push (:c::rax))
            (:c::mov-rr (:c::r9) (:c::rax))
            (:c::inc-if-ptr)
            (:c::reg-pop (:c::rax))
            (:c::mov-rr (:c::rax) (:c::r9))
            (:c::add-ri (:c::rdx) bits))
     a-mid (:wat::core::+ a-grow (:c::hexlen grow))
     mid-head (:wat::string::concat
                (:c::reg-push (:c::rdx)) (:c::mov-rr (:c::r9) (:c::rax))
                ;; a shift of 0 means this root is a leaf: its slots are elements
                (:c::xor-rr (:c::r11) (:c::r11))
                (:c::test-rr (:c::rdx) (:c::rdx))
                (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) one)
                one)
     mid (:wat::string::concat
           mid-head
           (:c::rt-call (:c::at-ncopy lay)
             (:wat::core::+ a-mid (:wat::core::+ (:c::hexlen mid-head) (:c::call-size))))
           (:c::mov-rr (:c::rax) (:c::r8))
           (:c::mov-rr (:c::rax) (:c::rbx)))
     ;; one level of the descent: the slot, then the child -- copied if it exists, made if not
     a-body (:wat::core::+ a-mid
              (:wat::core::+ (:c::hexlen mid)
                (:wat::core::+ (:c::hexlen (:c::test-rr (:c::rdx) (:c::rdx))) (:c::rel8-size))))
     slot (:wat::string::concat
            (:c::mov-rr (:c::r13) (:c::rax))
            (:c::mov-rr (:c::rdx) (:c::rcx))
            (:c::shr-cl (:c::rax))
            (:c::and-ri (:c::rax) mask)
            (:c::mov-rr (:c::rax) (:c::r9))
            (:c::rm "8b" (:c::rax) (:c::rbx) (:c::r9) (:c::word) (:c::node-data))
            (:c::test-rr (:c::rax) (:c::rax)))
     a-copy (:wat::core::+ a-body (:wat::core::+ (:c::hexlen slot) (:c::rel8-size)))
     ;; shift == 5 means the child is a leaf. r11 tells node_copy whether to count.
     kid (:wat::string::concat
           (:c::xor-rr (:c::r11) (:c::r11))
           (:c::cmp-ri (:c::rdx) bits)
           (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) one)
           one)
     a-new (:wat::core::+ a-copy
             (:wat::core::+ (:c::hexlen kid)
               (:wat::core::+ (:c::call-size) (:c::rel8-size))))
     child (:wat::string::concat
             (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
               (:wat::core::+ (:c::hexlen kid)
                 (:wat::core::+ (:c::call-size) (:c::rel8-size))))
             kid
             (:c::rt-call (:c::at-ncopy lay)
               (:wat::core::+ a-copy (:wat::core::+ (:c::hexlen kid) (:c::call-size))))
             ;; skip the "make one" call; a call is a call-size, not a string to measure
             (:c::br-len "eb" (:c::call-size))
             (:c::rt-call (:c::at-nnew lay) (:wat::core::+ a-new (:c::call-size))))
     body (:wat::string::concat
            slot child
            (:c::rm "89" (:c::rax) (:c::rbx) (:c::r9) (:c::word) (:c::node-data))
            (:c::mov-rr (:c::rax) (:c::rbx))
            (:c::sub-ri (:c::rdx) bits))
     ;; **the jump back goes to the loop's TOP, not to its body** -- so it spans the test and the
     ;; branch as well, and `inner` is named to make that the only thing it can mean
     inner (:wat::string::concat
             (:c::test-rr (:c::rdx) (:c::rdx))
             (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
               (:wat::core::+ (:c::hexlen body) (:c::rel8-size)))
             body)
     loop (:wat::string::concat inner (:c::jmp-back inner))
     leaf-n (:wat::core::let
              [span (:wat::string::concat
                      (:c::lea-at (:c::rbx) (:c::node-data) (:c::rsi))
                      (:c::mov-ri (:c::rcx) (:c::node-arity))
                      (:c::mov-rr (:c::rax) (:c::rdx))
                      (:c::count-span))]
              (:wat::string::concat
                (:c::test-rr (:c::rbp) (:c::rbp))
                (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) span)
                span))
     leaf (:wat::string::concat
            (:c::mov-rr (:c::r13) (:c::rax))
            (:c::and-ri (:c::rax) mask)
            leaf-n
            (:c::mov-rr (:c::r13) (:c::rax))
            (:c::and-ri (:c::rax) mask)
            (:c::rm "89" (:c::r12) (:c::rbx) (:c::rax) (:c::word) (:c::node-data))
            (:c::reg-pop (:c::rdx)))
     obj (:wat::core::+ (:c::varr-ptr) (:wat::core::* 3 (:c::word)))
     a-bump (:wat::core::+ a-mid
              (:wat::core::+ (:c::hexlen mid)
                (:wat::core::+ (:c::hexlen loop) (:c::hexlen leaf))))]
    (:wat::string::concat
      pre
      (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) grow)
      grow mid loop leaf
      (:c::rt-bump a-bump lay (:c::add-ri (:c::r11) obj) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 (:c::vec-tree))
      (:c::mov-mi (:c::r15) (:c::word) (:c::heap-arm))
      (:c::lea-at (:c::r15) (:c::varr-ptr) (:c::rax))
      (:c::lea-at (:c::r13) 1 (:c::rcx))
      (:c::mov-mr (:c::rcx) (:c::rax) 0)
      (:c::mov-mr (:c::rdx) (:c::rax) (:c::vec-shift))
      (:c::mov-mr (:c::r8) (:c::rax) (:c::vec-root))
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::rbp) (:c::r10))
      (:c::reg-pop (:c::r13)) (:c::reg-pop (:c::r12)) (:c::reg-pop (:c::rbx))
      (:c::reg-pop (:c::rbp))
      (:c::ret))))

;; `tree_from_arr(rax = flat array) -> rax` -- promote a flat Vector to the 32-way trie, by
;; making an empty tree and pushing every element into it. Called once, when a vector outgrows
;; `:c::arr-max`; after that `vec_conj` goes straight to `tree_push`.
(:wat::core::defn :c::rt-tree-from-arr [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           ;; the caller's element-kind flag (r10) has to survive node_new and the bump,
           ;; which clobber it, and the five pushes keep the call aligned. The pad is
           ;; the extra one: three callee-saves plus r10 is an even count.
           (:c::reg-push (:c::rax))
           (:c::reg-push (:c::r10))
           (:c::reg-push (:c::rbx)) (:c::reg-push 1) (:c::reg-push 2)
           (:c::mov-rr (:c::rax) (:c::rbx))
           (:c::mov-rm (:c::rbx) 0 2)
           (:c::xor-rr 1 1))
     ;; the root node first: `tree_push` needs somewhere to push into
     at-nn (:wat::core::+ (:c::at-tfa lay) (:c::hexlen pre))
     mk (:wat::string::concat
          (:c::rt-call (:c::at-nnew lay) (:wat::core::+ at-nn (:c::call-size)))
          (:c::mov-rr (:c::rax) (:c::r9)))
     ;; an empty Vector object: the tree arm, then len 0, shift 0, and the root
     obj (:wat::core::+ (:c::varr-ptr) (:wat::core::* 3 (:c::word)))
     alloc (:wat::string::concat
             (:c::mov-mi (:c::r15) 0 (:c::vec-tree))
             (:c::mov-mi (:c::r15) (:c::word) (:c::heap-arm))
             (:c::lea-at (:c::r15) (:c::varr-ptr) (:c::rax))
             (:c::mov-mi (:c::rax) 0 0)
             (:c::mov-mi (:c::rax) (:c::vec-shift) 0)
             (:c::mov-mr (:c::r9) (:c::rax) (:c::vec-root))
             (:c::mov-rr (:c::r11) (:c::r15)))
     ;; the pad comes off into r11, not rax: rax is the tree this function returns
     exit (:wat::string::concat
            (:c::reg-pop 2) (:c::reg-pop 1) (:c::reg-pop (:c::rbx))
            (:c::reg-pop (:c::r10)) (:c::reg-pop (:c::r11)) (:c::ret))
     ;; one element: fetch it, and put the saved flag back in r10. After the three
     ;; callee-saves the flag sits at [rsp+24]; the pad is at [rsp+32].
     step0 (:wat::string::concat
             (:c::rm "8b" (:c::rcx) (:c::rbx) 1 (:c::word) (:c::vec-data))
             (:c::mov-rm (:c::rsp) 24 (:c::r10)))
]
    (:wat::core::let
      [bump (:c::rt-bump (:wat::core::+ at-nn (:c::hexlen mk)) lay
              (:c::add-ri (:c::r11) obj) (:c::r11) (:c::r15) true)
       top (:wat::core::+ at-nn
             (:wat::core::+ (:c::hexlen mk)
               (:wat::core::+ (:c::hexlen bump) (:c::hexlen alloc))))
       guard (:wat::string::concat (:c::cmp-rr 2 1)
               (:c::br-len (:c::jcc-rel8 (:c::negate-cc (:c::cc-below)))
                 (:wat::core::+ (:c::hexlen step0)
                   (:wat::core::+ (:c::call-size)
                     (:wat::core::+ (:c::hexlen (:c::inc-r 1)) (:c::rel8-size))))))
       at-push (:wat::core::+ top (:wat::core::+ (:c::hexlen guard) (:c::hexlen step0)))
       body (:wat::string::concat guard step0
              (:c::rt-call (:c::at-tpush lay) (:wat::core::+ at-push (:c::call-size)))
              (:c::inc-r 1))]
      (:wat::string::concat pre mk bump alloc body (:c::jmp-back body) exit))))

;; `vec_conj(rax = vec, rcx = value) -> rax`. Three paths, and the first two are handoffs:
;; a vector already a TREE goes to `tree_push`; a flat one at `:c::arr-max` is promoted first and
;; then goes to `tree_push`; a flat one with room is copied with the new element appended.
(:wat::core::defn :c::rt-vec-conj [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [;; **the tag is `:c::vec-tree` or not** -- never "is it `:c::vec-flat`": a flat-but-owned
     ;; block (`:c::vec-flat-own`) must fall through here too, not be mistaken for a trie
     ;; already and handed to `tree_push`, which would read its elements as `shift`/`root`
     ;; (excursus 008 F2).
     head (:c::cmp-mi (:c::rax) (:wat::core::- 0 (:c::varr-ptr)) (:c::vec-tree))
     at-je (:wat::core::+ (:c::at-vconj lay) (:c::hexlen head))
     ;; a trie already: jump on EQUAL (the discriminant is `:c::vec-tree`)
     to-push (:c::rt-branch (:c::cc-zero) (:c::at-tpush lay)
               (:wat::core::+ at-je (:c::rel32-size)))
     test (:wat::string::concat
            (:c::mov-rm (:c::rax) 0 (:c::r8))
            (:c::cmp-ri (:c::r8) (:c::arr-max)))
     at-promote (:wat::core::+ at-je
                  (:wat::core::+ (:c::rel32-size)
                    (:wat::core::+ (:c::hexlen test) (:c::rel8-size))))
     ;; full: promote to a tree, then push into it
     promote (:wat::string::concat
               (:c::reg-push (:c::rcx))
               (:c::rt-call (:c::at-tfa lay)
                 (:wat::core::+ at-promote
                   (:wat::core::+ (:c::hexlen (:c::reg-push (:c::rcx))) (:c::call-size))))
               (:c::reg-pop (:c::rcx)))
     at-jmp (:wat::core::+ at-promote (:c::hexlen promote))
     spill (:wat::string::concat promote
             (:c::jmp-rel32 (:wat::core::- (:c::at-tpush lay)
                              (:wat::core::+ at-jmp (:c::call-size)))))
     size (:c::lea (:c::no-reg) (:c::r8) (:c::word)
            (:wat::core::+ (:c::varr-hdr) (:c::word)) (:c::rdx))
     pre (:wat::string::concat
           (:c::reg-push (:c::rbx))
           (:c::mov-rr (:c::r10) (:c::rbx))
           (:c::mov-rr (:c::rcx) (:c::r10)) size)
     at-bump (:wat::core::+ at-promote
               (:wat::core::+ (:c::hexlen spill) (:c::hexlen pre)))]
    (:wat::string::concat
      head to-push test
      (:c::br-over (:c::jcc-rel8 (:c::cc-below)) spill)
      spill pre
      (:c::rt-bump at-bump lay (:c::add-rr (:c::rdx) (:c::r11)) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 (:c::vec-flat))
      (:c::mov-mi (:c::r15) (:c::word) (:c::heap-arm))
      (:c::lea-at (:c::r15) (:c::varr-ptr) (:c::r9))
      (:c::lea-at (:c::r8) 1 (:c::rdx))
      (:c::mov-mr (:c::rdx) (:c::r9) 0)
      (:c::lea-at (:c::r9) (:c::vec-data) (:c::rdi))
      (:c::lea-at (:c::rax) (:c::vec-data) (:c::rsi))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::rep-movsq)
      (:c::count-copied)
      (:c::mov-mr (:c::r10) (:c::rdi) 0)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r9) (:c::rax))
      (:c::reg-pop (:c::rbx))
      (:c::ret))))

;; `rsi` slots, `r8` of them, skip index `r10`, bitmask of pointer slots in `r12`.
(:wat::core::defn :c::count-masked [] -> :wat::core::String
  (:wat::core::let
    [bump (:c::inc-if-ptr)
     hit (:wat::string::concat
           (:c::rm "8b" (:c::rax) (:c::rsi) (:c::rbx) (:c::word) 0)
           bump)
     bit (:wat::string::concat
           (:c::mov-rr (:c::rbx) (:c::rcx))
           (:c::mov-ri (:c::rax) 1)
           (:c::shl-cl (:c::rax))
           (:c::test-rr (:c::rax) (:c::r12))
           (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) hit)
           hit)
     work (:wat::string::concat
            (:c::cmp-rr (:c::r10) (:c::rbx))
            (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) bit)
            bit
            (:c::inc-r (:c::rbx)))
     guard (:wat::string::concat
             (:c::cmp-rr (:c::r8) (:c::rbx))
             (:c::br-len (:c::jcc-rel8 (:c::negate-cc (:c::cc-below)))
               (:wat::core::+ (:c::hexlen work) (:c::rel8-size))))
     body (:wat::string::concat guard work)]
    (:wat::string::concat
      (:c::reg-push (:c::rbx))
      (:c::xor-rr (:c::rbx) (:c::rbx))
      body
      (:c::jmp-back body)
      (:c::reg-pop (:c::rbx)))))

;; `slot_set(rax = vector, rcx = index, rdx = value) -> rax` -- a copy of the whole array with
;; one slot changed, which is what an immutable `assoc` on a leaf costs. The allocation is
;; `vec_new`'s, so it is `:c::rt-bump` again; the size is computed into rdx between the two
;; halves of the check, which is why `grow` is a string rather than a register.
(:wat::core::defn :c::rt-slot-set [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::reg-push (:c::rbx))
           (:c::reg-push (:c::r12))
           ;; r11 is the caller's bitmask of pointer fields; the bump spends r11
           (:c::mov-rr (:c::r11) (:c::r12))
           (:c::mov-rm (:c::rax) 0 (:c::r8))
           (:c::mov-rr (:c::rcx) (:c::r10))
           (:c::mov-rr (:c::rdx) (:c::rbx)))
     grow (:wat::string::concat
            (:c::lea (:c::no-reg) (:c::r8) (:c::word) (:c::vec-hdr) (:c::rdx))
            (:c::add-rr (:c::rdx) (:c::r11)))]
    (:wat::string::concat
      pre
      (:c::rt-bump (:wat::core::+ (:c::at-slot lay) (:c::hexlen pre)) lay grow (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 1)
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r9))
      (:c::mov-mr (:c::r8) (:c::r9) 0)
      (:c::lea-at (:c::r9) (:c::vec-data) (:c::rdi))
      (:c::lea-at (:c::rax) (:c::vec-data) (:c::rsi))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::rep-movsq)
      (:wat::core::let [span (:wat::string::concat
                               (:c::mov-rr (:c::rdi) (:c::rsi))
                               (:c::mov-rr (:c::r8) (:c::rax))
                               (:c::shl-ri (:c::rax) 3)
                               (:c::sub-rr (:c::rax) (:c::rsi))
                               (:c::count-masked))]
        (:wat::string::concat
          (:c::test-rr (:c::r12) (:c::r12))
          (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) span)
          span))
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r9) (:c::rax))
      ;; the one slot that differs
      (:c::rm "89" (:c::rbx) (:c::rax) (:c::r10) (:c::word) (:c::vec-data))
      (:c::reg-pop (:c::r12))
      (:c::reg-pop (:c::rbx))
      (:c::ret))))

;; `oom()` -- every allocator compares `r15 + need` against the limit at `r14+8` and calls this
;; when it would cross. The reservation is the machine's RAM plus swap, taken once at startup,
;; and it does not grow past that. Running out is the program's responsibility: the stop names
;; it and exits 70.
(:wat::core::defn :c::rt-oom [lay <- :c::Layout] -> :wat::core::String
  (:c::rt-abort "wat: heap exhausted" lay (:c::at-oom lay)))

;; `str_subs(rax = s, rcx = from, rdx = to) -> rax` -- a new String of the bytes in `[from, to)`.
;; The source pointer is computed BEFORE the allocation, because allocating clobbers rcx.
(:wat::core::defn :c::rt-str-subs [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::mov-rr (:c::rdx) (:c::r8))
           (:c::sub-rr (:c::rcx) (:c::r8))
           (:c::rm "8d" (:c::rdi) (:c::rax) (:c::rcx) 1 (:c::str-data))
           (:c::rt-cap (:c::r8) (:c::rdx) (:c::r9)))]
    (:wat::string::concat
      pre
      (:c::rt-bump (:wat::core::+ (:c::at-subs lay) (:c::hexlen pre)) lay
        (:c::add-rr (:c::r9) (:c::r11)) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 (:c::heap-arm))
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r10))
      (:c::mov-mr (:c::r8) (:c::r10) 0)
      (:c::mov-rr (:c::rdi) (:c::rsi))
      (:c::lea-at (:c::r10) (:c::str-data) (:c::rdi))
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::rep-movsb)
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::ret))))

;; `str_starts(rax = s, rcx = prefix) -> 0 or 1`, 40 bytes, `repe cmpsb`.
;; ---------------------------------------------------------------- the two string comparisons
;;
;; **`str_eq` and `str_starts` differ in their first eight bytes and agree in the other thirty-two**,
;; which was invisible while both were hex. One asks whether the lengths MATCH, the other whether
;; the prefix FITS; after that they run the same comparison over the same registers and answer the
;; same 0 or 1. So the tail is written once.
;;
;; `repz cmpsb` compares rcx bytes at (rsi) and (rdi) and stops at the first difference, leaving
;; ZF set if it ran out of bytes instead -- but with rcx already zero it does nothing at all and
;; leaves the flags from whatever came before, so the empty case is branched around rather than
;; trusted. That guard is the difference between `str_eq("", "")` answering true and answering
;; whatever the last comparison happened to set.
(:wat::core::defn :c::rt-str-fail [] -> :wat::core::String
  (:wat::string::concat (:c::xor-rr (:c::rax) (:c::rax)) (:c::ret)))
;; everything the head's branch skips: the comparison, and the `true` it falls into
(:wat::core::defn :c::rt-str-body [] -> :wat::core::String
  (:wat::core::let
    [yes (:wat::string::concat (:c::mov-ri (:c::rax) 1) (:c::ret))
     run (:wat::string::concat (:c::repz-cmpsb)
           (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) yes))]
    (:wat::string::concat
      (:c::lea-at (:c::rax) (:c::str-data) (:c::rsi))
      (:c::lea-at (:c::rcx) (:c::str-data) (:c::rdi))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::test-rr (:c::rcx) (:c::rcx))
      (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) run)
      run
      yes)))
(:wat::core::defn :c::rt-str-tail [] -> :wat::core::String
  (:wat::string::concat (:c::rt-str-body) (:c::rt-str-fail)))

;; `str_starts(rax = s, rcx = prefix) -> 0 or 1`. A prefix LONGER than the string cannot start
;; it, and the comparison count is the prefix's length either way.
(:wat::core::defn :c::rt-str-starts [] -> :wat::core::String
  (:wat::string::concat
    (:c::mov-rm (:c::rcx) 0 (:c::r8))
    (:c::cmp-rm (:c::rax) 0 (:c::r8))
    (:c::br-over (:c::jcc-rel8 (:c::cc-greater)) (:c::rt-str-body))
    (:c::rt-str-tail)))

;; `str_contains(rax = s, rcx = needle) -> 0 or 1`, the naive search -- try the needle at every
;; offset the haystack has room for. **`repz cmpsb` is the inner loop**, so what this routine
;; writes is the OUTER one: bump the offset, re-point rsi, compare again.
;;
;; The two forward exits and the jump back all measure themselves. The jump back cannot ask
;; `:c::br-over` for its distance -- the body it jumps over contains the jump -- so it is a sum
;; of the pieces that do exist, which is what `:c::br-len` is for.
(:wat::core::defn :c::rt-str-contains [] -> :wat::core::String
  (:wat::core::let
    [yes  (:wat::string::concat (:c::mov-ri (:c::rax) 1) (:c::ret))
     fail (:wat::string::concat (:c::xor-rr (:c::rax) (:c::rax)) (:c::ret))
     inc  (:c::inc-r (:c::rax))
     ;; the needle matched: skip the bump and the jump back
     je2  (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
            (:wat::core::+ (:c::hexlen inc) (:c::rel8-size)))
     scan (:wat::string::concat (:c::repz-cmpsb) je2 inc)
     ;; an empty needle matches anywhere, and `repz cmpsb` with rcx = 0 sets no flags at all
     je1  (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
            (:wat::core::+ (:c::hexlen scan) (:c::rel8-size)))
     probe (:wat::string::concat
             (:c::mov-rr (:c::r11) (:c::rsi)) (:c::add-rr (:c::rax) (:c::rsi))
             (:c::mov-rr (:c::rdx) (:c::rdi)) (:c::mov-rr (:c::r9) (:c::rcx))
             (:c::test-rr (:c::rcx) (:c::rcx)) je1 scan)
     ;; past the last offset the needle could fit at
     jg   (:c::br-len (:c::jcc-rel8 (:c::cc-greater))
            (:wat::core::+ (:c::hexlen probe)
              (:wat::core::+ (:c::rel8-size) (:c::hexlen yes))))
     body (:wat::string::concat (:c::cmp-rr (:c::r10) (:c::rax)) jg probe)
     loop (:wat::string::concat body (:c::jmp-back body))
     setup (:wat::string::concat
             (:c::lea-at (:c::rax) (:c::str-data) (:c::r11))
             (:c::lea-at (:c::rcx) (:c::str-data) (:c::rdx))
             (:c::xor-rr (:c::rax) (:c::rax)))]
    (:wat::string::concat
      (:c::mov-rm (:c::rax) 0 (:c::r8))
      (:c::mov-rm (:c::rcx) 0 (:c::r9))
      (:c::mov-rr (:c::r8) (:c::r10))
      (:c::sub-rr (:c::r9) (:c::r10))
      ;; a needle longer than the haystack: the subtraction went negative
      (:c::br-over (:c::jcc-rel8 (:c::cc-sign))
        (:wat::string::concat setup loop yes))
      setup loop yes fail)))

;; `i64_to_str(rax = n) -> rax` -- the same digits, landing in the heap instead of the output
;; buffer. rsi starts AT rbp here rather than one below it, because there is no newline to plant.
(:wat::core::defn :c::rt-i64-to-str [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::reg-push (:c::rbp)) (:c::mov-rr (:c::rsp) (:c::rbp))
           (:c::sub-ri (:c::rsp) (:c::scratch-frame))
           (:c::mov-rr (:c::rbp) (:c::rsi))
           (:c::rt-digits)
           ;; how far rsi walked IS the length
           (:c::mov-rr (:c::rbp) (:c::r9))
           (:c::sub-rr (:c::rsi) (:c::r9))
           (:c::rt-cap (:c::r9) (:c::r10) (:c::r10)))]
    (:wat::string::concat
      pre
      (:c::rt-bump (:wat::core::+ (:c::at-tostr lay) (:c::hexlen pre)) lay
        (:c::add-rr (:c::r10) (:c::r11)) (:c::r11) (:c::r15) true)
      (:c::mov-mi (:c::r15) 0 (:c::heap-arm))
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r10))
      (:c::mov-mr (:c::r9) (:c::r10) 0)
      (:c::lea-at (:c::r10) (:c::str-data) (:c::rdi))
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r9) (:c::rcx))
      (:c::rep-movsb)
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::leave) (:c::ret))))

;; `str_eq(rax = a, rcx = b) -> 0 or 1`, 40 bytes. **This one closes a silent divergence.**
;; `(wat.core/= a b)` on two Strings compiled to a machine-word compare, which compares
;; POINTERS: `(= (concat "ab" "c") (concat "a" "bc"))` answered false where the interpreter
;; answers true. The type pass knows both operand types, so `=` on two `str` operands now calls
;; this instead. Nothing had noticed because no program in elf/src compared two strings -- a
;; reader is the first thing that must.
;; `str_eq(rax, rcx) -> 0 or 1`. Different lengths are different strings, and that test is one
;; instruction against the header rather than a comparison that has to run.
;; **the LAST eight bytes, before the byte walk.** `repz cmpsb` retires roughly a uop per byte,
;; and the heads this compiler spends its life comparing are `:wat::core::*` -- which collide in
;; LENGTH as well as prefix (`:wat::core::if`/`or`/`do` are all 14, `let`/`and`/`not` all 15).
;; So the length short-circuit above never fires and the walk compares TWELVE IDENTICAL BYTES
;; before reaching the one that differs, on every failing arm of every dispatch chain. F-174
;; measured the family at ~24.5% of a self-compile.
;;
;; A string's data starts at `+8`, so its last eight bytes start at `base + len` -- one
;; base-plus-index operand, no arithmetic. `:wat::core::if` against `:wat::core::or` differs
;; inside that window and is rejected in four instructions instead of the walk.
;;
;; **Inline, not a call.** The same check written in wat as `:c::is?` calling `byte-at` cost
;; +16.4%: `byte-length` and `byte-at` are calls, and the call overhead dwarfed the saving.
;; That is the whole lesson -- the work is not the bytes, it is the per-call price of asking.
;;
;; Shorter than eight bytes skips the check, because `base + len` would read before the data.
;; r9 is free: our callees treat r8-r11 as dead, and this routine already clobbers r8.
(:wat::core::defn :c::rt-str-eq [] -> :wat::core::String
  (:wat::core::let
    [body (:c::rt-str-body)
     tail8 (:wat::string::concat
             (:c::rm "8b" (:c::r9) (:c::rax) (:c::r8) 1 0)     ;; mov r9, [rax+r8]
             (:c::rm "3b" (:c::r9) (:c::rcx) (:c::r8) 1 0)     ;; cmp r9, [rcx+r8]
             (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) body))
     pre (:wat::string::concat
           (:c::cmp-ri (:c::r8) 8)
           (:c::br-over (:c::jcc-rel8 (:c::cc-below)) tail8)
           tail8)]
    (:wat::string::concat
      (:c::mov-rm (:c::rax) 0 (:c::r8))
      (:c::cmp-rm (:c::rcx) 0 (:c::r8))
      (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero)))
                   (:wat::string::concat pre body))
      pre
      body
      (:c::rt-str-fail))))

;; **a syscall needs a C string and a wat String is not one** -- it is a length and then bytes,
;; with nothing at the end. So the path is copied to the heap top and a NUL is put after it.
;; Nothing is allocated: r15 is scratch here exactly as in `print_str`, and r12 is left pointing
;; PAST the NUL, which is where the caller's own scratch begins.
;;
;; `prim_write_hex` and `io_read_file` did this identically, differing only in which register
;; holds the path.
(:wat::core::defn :c::rt-cpath [src <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:c::mov-rr (:c::r15) (:c::r10))
    (:c::lea-at src (:c::str-data) (:c::rsi))
    (:c::mov-rr (:c::r10) (:c::rdi))
    (:c::mov-rm src 0 (:c::rcx))
    (:c::rep-movsb)
    (:c::mov-mi8 (:c::rdi) 0 0)
    (:c::inc-r (:c::rdi))
    (:c::mov-rr (:c::rdi) (:c::r12))))

;; `write(fd)` with rsi and rdx already set -- the three instructions every direct write shares.
;; A local `fn` would say this better, but this compiler takes `defn` at the top level and
;; nothing else, so a helper it is.
(:wat::core::defn :c::rt-write [fd <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::mov-ri (:c::rdi) fd)
                        (:c::mov-ri (:c::rax) (:c::sys-write))
                        (:c::syscall)))

;; `die(rax = String)` -- put the message on STDERR and stop. The pending stdout is flushed
;; first, so the two streams come out in the order they were written rather than whichever the
;; kernel buffered last. The newline is a second write of one byte off the stack, because there
;; is nowhere to append it to.
(:wat::core::defn :c::rt-die [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:c::mov-rr (:c::rax) (:c::r10))
]
    (:wat::string::concat
      pre
      (:c::rt-call (:c::at-flush lay)
        (:wat::core::+ (:c::at-die lay)
          (:wat::core::+ (:c::hexlen pre) (:c::call-size))))
      (:c::mov-rm (:c::r10) 0 (:c::rdx))
      (:c::lea-at (:c::r10) (:c::str-data) (:c::rsi))
      (:c::rt-write (:c::fd-stderr))
      ;; one byte of stack to put the newline in
      (:c::sub-ri (:c::rsp) (:c::word))
      (:c::mov-mi8 (:c::rsp) 0 (:c::nl))
      (:c::mov-ri (:c::rdi) (:c::fd-stderr))
      (:c::mov-rr (:c::rsp) (:c::rsi))
      (:c::mov-ri (:c::rdx) 1)
      (:c::mov-ri (:c::rax) (:c::sys-write))
      (:c::syscall)
      (:c::mov-ri (:c::rdi) (:c::exit-fail))
      (:c::mov-ri (:c::rax) (:c::sys-exit))
      (:c::syscall))))

;; **The last mile: a file, as bytes.** Five routines.
;;
;; A compiled program can open and write a file in three syscalls. What it cannot do is call
;; wat's `:wat::io::` verbs, because those are Rust inside the evaluator -- and it cannot route
;; around them through a String, because a String is UTF-8 there and a byte array here, so the
;; two disagree on the first byte above 0x7f, which an ELF header has in its second byte.
;;
;; So these are **F-119's contract made concrete**: `prim/read-hex` and `prim/write-hex` have a
;; wat definition for the interpreter (`elf/lib/prim.wat`) and this implementation for the
;; compiler, and a program using them still runs both ways. Hex is the carrier for the same
;; reason the rest of `elf/` uses it: it is the only byte representation a wat String can hold
;; (F-118).
;;
;; They are separate defns so that their ADDRESSES come from their own lengths. They used to be
;; one blob with `+ 30`, `+ 163` and `+ 220` written into the offset chain by hand -- the same
;; shape as the `base + 11` that broke every tail call in C-135.


;; `slot_set_own(rax = rec, rcx = index, rdx = value) -> rax` -- `assoc` where the record turns
;; out to be uniquely held, so the field is written where it stands and nothing is allocated.
;;
;; **The word one before the pointer is a SHARE COUNT, not a tag.** `:c::share` increments it
;; when a value is stored or passed on -- guarded, because a literal in the read-only segment has
;; a count of zero by construction and writing to it would fault. So a count of exactly one means
;; nobody else holds this record and a write cannot be observed.
;;
;; That makes the RUNTIME the safety proof and the compiler's `:c::linear?` merely a hint, which
;; is why `assoc` calls this unconditionally: being wrong costs a compare and a branch, never
;; correctness. F-141 measured what the conservative hint costs when it is the only gate.
(:wat::core::defn :c::rt-slot-set-own [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [head (:c::cmp-mi (:c::rax) (:wat::core::- 0 (:c::vec-ptr)) (:c::heap-arm))
     at-jne (:wat::core::+ (:c::at-slot-own lay) (:c::hexlen head))]
    (:wat::string::concat
      head
      ;; shared, or a literal: fall through to the copy
      (:c::rt-branch (:c::negate-cc (:c::cc-zero)) (:c::at-slot lay)
        (:wat::core::+ at-jne (:c::rel32-size)))
      (:c::rm "89" (:c::rdx) (:c::rax) (:c::rcx) (:c::word) (:c::vec-data))
      (:c::ret))))

;; `hexval(rax = one ascii hex digit) -> rax = 0..15`, 15 bytes -- `:c::rt-hexchar` run backwards,
;; and composed the same way. Take off `'0'`; if what is left is still above nine it was a letter,
;; so take off the seven-character gap as well.
(:wat::core::defn :c::rt-hexval [] -> :wat::core::String
  (:wat::core::let [gap (:c::sub-ri (:c::rax) (:c::hex-gap))
                    max-digit (:wat::core::- (:asm::code-of "9") (:asm::code-of "0"))]
    (:wat::string::concat
      (:c::sub-ri (:c::rax) (:asm::code-of "0"))
      (:c::cmp-ri (:c::rax) max-digit)
      (:c::jbe-over gap)                                  ;; it was a digit: done
      gap
      (:c::ret))))

;; `hexchar(rax = 0..15) -> al`, 15 bytes -- **and the first routine that is INSTRUCTIONS rather
;; than a hex blob.** A digit is `'0' + n`; a letter is seven further on, because seven ASCII
;; characters sit between `'9'` and `'a'`. So: below ten, skip the extra; otherwise take both.
;;
;; The forward branch needs no label table. Its displacement is the length of the piece it jumps
;; over, and that piece is the very expression bound to `gap` -- which is how C-169's `:c::sel`
;; already emits a diamond. Byte-identical to the blob it replaces; `tools/bootstrap.sh` is what
;; says so, since the old hex is an exact oracle for the new form.
(:wat::core::defn :c::rt-hexchar [] -> :wat::core::String
  (:wat::core::let [gap (:c::add-ri (:c::rax) (:c::hex-gap))
                    ndigits (:wat::string::length "0123456789")]
    (:wat::string::concat
      (:c::cmp-ri (:c::rax) ndigits)
      (:c::jb-over gap)                                   ;; a digit: skip the gap
      gap
      (:c::add-ri (:c::rax) (:asm::code-of "0"))
      (:c::ret))))

;; `prim_write_hex(rax = path, rcx = hex) -> rax = bytes written` -- decode a hex String into
;; bytes and write them to a file. This is how the compiler emits an ELF: everything it builds is
;; a String of hex, and this is the only thing that turns that into a file.
;;
;; Two characters make one byte, so the count is the length halved, and each pair is
;; `hexval(hi) << 4 | hexval(lo)`.
(:wat::core::defn :c::rt-prim-write-hex [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::reg-push (:c::rbx)) (:c::reg-push (:c::r12))
           (:c::mov-rr (:c::rax) (:c::r8))
           (:c::mov-rr (:c::rcx) (:c::r9))
           (:c::rt-cpath (:c::r8))
           (:c::mov-rm (:c::r9) 0 (:c::rdx))
           (:c::shr-1 (:c::rdx))
           (:c::mov-rr (:c::rdx) (:c::rbx))
           (:c::lea-at (:c::r9) (:c::str-data) (:c::rsi))
           (:c::test-rr (:c::rdx) (:c::rdx)))
     ;; where each `hexval` call lands, as a running sum of the pieces before it
     at-loop (:wat::core::+ (:c::at-wrhex lay)
               (:wat::core::+ (:c::hexlen pre) (:c::rel8-size)))
     hi (:c::movzb (:c::rsi) (:c::no-reg) 0 (:c::rax))
     at-c1 (:wat::core::+ at-loop (:c::hexlen hi))
     mid (:wat::string::concat
           (:c::shl-ri (:c::rax) 4)
           (:c::mov-rr (:c::rax) (:c::rcx))
           (:c::movzb (:c::rsi) (:c::no-reg) 1 (:c::rax)))
     at-c2 (:wat::core::+ at-c1 (:wat::core::+ (:c::call-size) (:c::hexlen mid)))
     body (:wat::string::concat
            hi
            (:c::rt-call (:c::at-hexval lay) (:wat::core::+ at-c1 (:c::call-size)))
            mid
            (:c::rt-call (:c::at-hexval lay) (:wat::core::+ at-c2 (:c::call-size)))
            (:c::or-rr (:c::rcx) (:c::rax))
            (:c::mov-mr8 (:c::rax) (:c::rdi) 0)
            (:c::add-ri (:c::rsi) 2)
            (:c::inc-r (:c::rdi))
            (:c::dec-r (:c::rdx)))]
    (:wat::string::concat
      pre
      (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
        (:wat::core::+ (:c::hexlen body) (:c::rel8-size)))
      body
      (:c::br-back (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) body)
      ;; open, write, close -- the fd in r9 across all three
      (:c::mov-ri (:c::rax) (:c::sys-open))
      (:c::mov-rr (:c::r10) (:c::rdi))
      (:c::mov-ri (:c::rsi) (:wat::core::+ (:c::o-wronly)
                              (:wat::core::+ (:c::o-creat) (:c::o-trunc))))
      (:c::mov-ri (:c::rdx) (:c::file-mode))
      (:c::syscall)
      (:c::mov-rr (:c::rax) (:c::r9))
      (:c::mov-ri (:c::rax) (:c::sys-write))
      (:c::mov-rr (:c::r9) (:c::rdi))
      (:c::mov-rr (:c::r12) (:c::rsi))
      (:c::mov-rr (:c::rbx) (:c::rdx))
      (:c::syscall)
      (:c::mov-rr (:c::rax) (:c::r10))
      (:c::mov-ri (:c::rax) (:c::sys-close))
      (:c::mov-rr (:c::r9) (:c::rdi))
      (:c::syscall)
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::reg-pop (:c::r12)) (:c::reg-pop (:c::rbx))
      (:c::ret))))

;; `prim_read_hex(rax = path) -> rax = a String of hex` -- read a file and render its bytes as
;; hex, which is how the compiler reads a binary back to check what it wrote. The same slurp as
;; `io_read_file`; the String allocated is TWICE the length, because a byte is two characters.
;; excursus 008 M2: `base`=r8 (the real allocation start -- the raw bytes were already read
;; onto the heap top as scratch by `:c::rt-slurp`, so the object begins past them, not at `r15`),
;; `top`=rsi. `:c::rt-cap`'s OUT moves to r9 (scratch stays rcx -- `:c::rt-cap` hardcodes rcx as
;; `bsr-rr`'s/`shl-cl`'s own shift-count register internally, so `out` may never BE rcx) so
;; `grow` is a plain register add, the shape `:c::rt-bump` already expects.
(:wat::core::defn :c::rt-prim-read-hex [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::rt-slurp)
           (:c::mov-rr (:c::rdx) (:c::rax))
           (:c::add-rr (:c::rax) (:c::rax))           ;; two characters a byte
           ;; `:c::rt-cap`'s OWN `bsr-rr`/`shl-cl` pair hardcodes rcx as the shift count, so
           ;; `out` can never BE rcx (F1 of this strike's own mistake, caught by
           ;; `/tmp/readbig-probe.wat` diverging by exactly the rounding error that bug leaves
           ;; behind) -- scratch stays rcx (transient, read then immediately overwritten by
           ;; `bsr-rr` itself), out moves to r9.
           (:c::rt-cap (:c::rax) (:c::rcx) (:c::r9)))
     bump (:c::rt-bump (:wat::core::+ (:c::at-rdhex lay) (:c::hexlen pre)) lay
            (:c::add-rr (:c::r9) (:c::rsi)) (:c::rsi) (:c::r8) true)
     head (:wat::string::concat
            pre bump
            (:c::mov-rr (:c::rsi) (:c::r15))
            (:c::mov-mi (:c::r8) 0 (:c::heap-arm))
            (:c::lea-at (:c::r8) (:c::vec-ptr) (:c::r10))
            (:c::mov-mr (:c::rax) (:c::r10) 0)
            (:c::lea-at (:c::r10) (:c::str-data) (:c::rdi))
            (:c::mov-rr (:c::r12) (:c::rsi)))
     a-body (:wat::core::+ (:c::at-rdhex lay)
              (:wat::core::+ (:c::hexlen head)
                (:wat::core::+ (:c::hexlen (:c::test-rr (:c::rdx) (:c::rdx)))
                               (:c::rel8-size))))
     hi (:wat::string::concat
          (:c::movzb (:c::rsi) (:c::no-reg) 0 (:c::rax))
          (:c::mov-rr (:c::rax) (:c::rcx))
          (:c::shr-ri (:c::rax) 4))
     a-c1 (:wat::core::+ a-body (:c::hexlen hi))
     mid (:wat::string::concat
           (:c::mov-mr8 (:c::rax) (:c::rdi) 0)
           (:c::inc-r (:c::rdi))
           (:c::mov-rr (:c::rcx) (:c::rax))
           (:c::and-ri (:c::rax) 15))
     a-c2 (:wat::core::+ a-c1 (:wat::core::+ (:c::call-size) (:c::hexlen mid)))
     body (:wat::string::concat
            hi
            (:c::rt-call (:c::at-hexchar lay) (:wat::core::+ a-c1 (:c::call-size)))
            mid
            (:c::rt-call (:c::at-hexchar lay) (:wat::core::+ a-c2 (:c::call-size)))
            (:c::mov-mr8 (:c::rax) (:c::rdi) 0)
            (:c::inc-r (:c::rdi))
            (:c::inc-r (:c::rsi))
            (:c::dec-r (:c::rdx)))]
    (:wat::string::concat
      head
      (:c::test-rr (:c::rdx) (:c::rdx))
      (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
        (:wat::core::+ (:c::hexlen body) (:c::rel8-size)))
      body
      (:c::br-back (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) body)
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::reg-pop (:c::r12))
      (:c::ret))))

;; **reading a whole file, which two routines do identically.** `io_read_file` and
;; `prim_read_hex` differ only in what they do with the bytes afterwards -- one wraps them in a
;; String, the other hex-encodes them -- and these hundred and eight bytes were written twice.
;;
;; There is no size to ask for in advance, so it reads a chunk at a time onto the heap top until
;; `read` returns nothing. Nothing is allocated: r15 is scratch, exactly as in `print_str`. On
;; return rdx is the length, r12 points at the first byte, and r8 is the end rounded UP to a
;; word -- which is where an allocation can start without disturbing what was just read.
(:wat::core::defn :c::rt-slurp [] -> :wat::core::String
  (:wat::core::let
    [chunk (:wat::string::concat
             (:c::mov-ri (:c::rax) (:c::sys-read))
             (:c::mov-rr (:c::r8) (:c::rdi))
             (:c::mov-rr (:c::r9) (:c::rsi))
             (:c::mov-ri (:c::rdx) (:c::read-chunk))
             (:c::syscall)
             (:c::test-rr (:c::rax) (:c::rax)))
     step (:c::add-rr (:c::rax) (:c::r9))
     inner (:wat::string::concat
             chunk
             (:c::br-len (:c::jcc-rel8 (:c::cc-le))
               (:wat::core::+ (:c::hexlen step) (:c::rel8-size)))
             step)]
    (:wat::string::concat
      (:c::reg-push (:c::r12))
      (:c::rt-cpath (:c::rax))
      (:c::mov-ri (:c::rax) (:c::sys-open))
      (:c::mov-rr (:c::r10) (:c::rdi))
      (:c::xor-rr (:c::rsi) (:c::rsi))            ;; O_RDONLY is zero
      (:c::xor-rr (:c::rdx) (:c::rdx))
      (:c::syscall)
      (:c::mov-rr (:c::rax) (:c::r8))             ;; the fd
      (:c::mov-rr (:c::r12) (:c::r9))             ;; the cursor
      inner (:c::jmp-back inner)
      (:c::mov-ri (:c::rax) (:c::sys-close))
      (:c::mov-rr (:c::r8) (:c::rdi))
      (:c::syscall)
      ;; how far the cursor moved IS the length
      (:c::mov-rr (:c::r9) (:c::rdx))
      (:c::sub-rr (:c::r12) (:c::rdx))
      ;; round the end up to a word: a String header wants alignment
      (:c::lea-at (:c::r9) 7 (:c::r8))
      (:c::and-ri (:c::r8) -8))))

;; `io_read_file(rax = path) -> rax = a String of the bytes`. This is `wat.io/read-file`, and it
;; is how the compiler reads its own source.
;;
;; **The read loop has no size to ask for in advance**, so it reads a chunk at a time onto the
;; heap top until `read` returns nothing, and only THEN allocates -- the bytes are already where
;; they need to be, so the allocation just has to reach past them. `lea 7(r9)` then `and -8`
;; rounds the end up to a word, because the String header wants alignment.
;; excursus 008 M2: `base`=r8, `top`=rsi -- same adaptation as `:c::rt-prim-read-hex` above.
;; `:c::rt-cap`'s scratch stays rcx (its own `bsr-rr`/`shl-cl` hardcode rcx as the shift count,
;; so `out` may never be rcx -- F1 of this strike's own first attempt, which put OUT there and
;; diverged on a real file); OUT moves to r9 (not an output `:c::rt-slurp` documents, so free).
(:wat::core::defn :c::rt-io-read-file [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::rt-slurp)
           (:c::rt-cap (:c::rdx) (:c::rcx) (:c::r9)))
     bump (:c::rt-bump (:wat::core::+ (:c::at-rdfile lay) (:c::hexlen pre)) lay
            (:c::add-rr (:c::r9) (:c::rsi)) (:c::rsi) (:c::r8) true)]
    (:wat::string::concat
      pre bump
      ;; the bytes are already in place; the allocation only has to reach past them
      (:c::mov-rr (:c::rsi) (:c::r15))
      (:c::mov-mi (:c::r8) 0 (:c::heap-arm))
      (:c::lea-at (:c::r8) (:c::vec-ptr) (:c::r10))
      (:c::mov-mr (:c::rdx) (:c::r10) 0)
      (:c::lea-at (:c::r10) (:c::str-data) (:c::rdi))
      (:c::mov-rr (:c::r12) (:c::rsi))
      (:c::mov-rr (:c::rdx) (:c::rcx))
      (:c::rep-movsb)
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::reg-pop (:c::r12))
      (:c::ret))))

(:wat::core::defn :c::rt-at [lvl <- :wat::core::i64 n <- :wat::core::i64
                             hex <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= lvl n) hex ""))

;; **elf/runtime.s is ordered so that every internal call points BACKWARD** -- `buf_put` calls
;; `flush`, `str_cat` calls `oom`, `vec_conj_own` calls `vec_conj`, and nothing calls anything
;; defined after it. That makes any PREFIX of the blob a complete runtime, so a program carries
;; only as much of it as it can reach and every routine's address is still the sum of the
;; lengths before it. `tools/rt-embed.sh` checks the order on every regeneration.
;; **every routine's address, in one vector.** What used to be a bare `rt` base threaded through
;; the compiler is now the whole layout -- same threading, same call sites, but an address is a
;; lookup instead of a walk.
(:wat::core::typealias :c::Layout (:wat::core::Vector :- [:wat::core::i64]))

;; excursus 008 stone 3b (G6): `:c::rt-drop1` retired. It was a GUESS -- a raw hex walk that
;; stopped at the first field below a page, trusting that a small word is never a pointer --
;; and nothing called it (`:c::emit-drop` only ever emitted the decrement). The glue that
;; replaces it is per TYPE, from the compiler, which knows every field's type at every drop
;; site and never has to guess.
;;
;; excursus 008 stone 3a round 7 (R17): the check build's abort, reached by a `jb rel32` from
;; every drop site instead of a bare `ud2` -- see `:c::dropchk-hex` in elf/compile.wat for why
;; a raw trap does not read as one on this machine.
(:wat::core::defn :c::rt-uflow [lay <- :c::Layout] -> :wat::core::String
  (:c::rt-abort "wat: reference count underflow" lay (:c::at-uflow lay)))

(:wat::core::defn :c::rt-count [] -> :wat::core::i64 35)

;; **the one place the routine order is written.** It used to be in three: this list, the
;; `rt-at lvl N` table inside `:c::runtime`, and the recursion in the `at-*` chain. The other two
;; are derived from this one now, so a routine cannot be inserted in one order and addressed in
;; another. `lay` is the layout SO FAR -- see `:c::lay` below for why that is the whole trick.
(:wat::core::defn :c::rt-nth [i <- :wat::core::i64 lay <- :c::Layout] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= i 0) (:c::rt-flush))
    ((:wat::core::= i 1) (:c::rt-ovf lay))
    ((:wat::core::= i 2) (:c::rt-buf-put lay))
    ((:wat::core::= i 3) (:c::rt-print-i64 lay))
    ((:wat::core::= i 4) (:c::rt-print-bool lay))
    ((:wat::core::= i 5) (:c::rt-oom lay))
    ((:wat::core::= i 6) (:c::rt-die lay))
    ((:wat::core::= i 7) (:c::rt-divzero lay))
    ((:wat::core::= i 8) (:c::rt-i64-quot lay))
    ((:wat::core::= i 9) (:c::rt-i64-rem lay))
    ((:wat::core::= i 10) (:c::rt-print-str lay))
    ((:wat::core::= i 11) (:c::rt-str-cat lay))
    ((:wat::core::= i 12) (:c::rt-str-cat-own lay))
    ((:wat::core::= i 13) (:c::rt-str-subs lay))
    ((:wat::core::= i 14) (:c::rt-i64-to-str lay))
    ((:wat::core::= i 15) (:c::rt-str-starts))
    ((:wat::core::= i 16) (:c::rt-str-contains))
    ((:wat::core::= i 17) (:c::rt-str-eq))
    ((:wat::core::= i 18) (:c::rt-vec-new lay))
    ((:wat::core::= i 19) (:c::rt-varr-new lay))
    ((:wat::core::= i 20) (:c::rt-node-new lay))
    ((:wat::core::= i 21) (:c::rt-node-copy lay))
    ((:wat::core::= i 22) (:c::rt-tree-get))
    ((:wat::core::= i 23) (:c::rt-tree-push lay))
    ((:wat::core::= i 24) (:c::rt-tree-from-arr lay))
    ((:wat::core::= i 25) (:c::rt-vec-conj lay))
    ((:wat::core::= i 26) (:c::rt-vec-conj-own lay))
    ((:wat::core::= i 27) (:c::rt-slot-set lay))
    ((:wat::core::= i 28) (:c::rt-slot-set-own lay))
    ((:wat::core::= i 29) (:c::rt-hexval))
    ((:wat::core::= i 30) (:c::rt-hexchar))
    ((:wat::core::= i 31) (:c::rt-prim-write-hex lay))
    ((:wat::core::= i 32) (:c::rt-prim-read-hex lay))
    ((:wat::core::= i 33) (:c::rt-io-read-file lay))
    (:else (:c::rt-uflow lay))))

(:wat::core::defn :c::rt-cat [lvl <- :wat::core::i64 i <- :wat::core::i64 lay <- :c::Layout
                              acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i (:c::rt-count)) acc
    (:c::rt-cat lvl (:wat::core::+ i 1) lay
      (:wat::string::concat acc (:c::rt-at lvl i (:c::rt-nth i lay))))))

(:wat::core::defn :c::runtime [lvl <- :wat::core::i64 lay <- :c::Layout] -> :wat::core::String
  (:c::rt-cat lvl 0 lay ""))

;; hex is two characters a byte
(:wat::core::defn :c::hexlen [h <- :wat::core::String] -> :wat::core::i64
  (:wat::core::/ (:wat::string::length h) 2))

;; ---------------------------------------------------------------- where each routine lands
;;
;; **Asking a routine's address used to BUILD every routine before it.** `at-X` was
;; `(+ (:c::at-prev rt) (:c::hexlen (:c::rt-prev)))`, so one lookup walked the whole chain --
;; free while a routine was a literal string, and 250 ms once C-173 made them compositions,
;; because "measuring" then meant running the encoder a few hundred times. The compiler asks
;; once per emitted call site, so compiling one 115-line program went 3.7 s -> 19.3 s and the
;; compiled compiler went 0.4 s -> 1.7 s (F-137). **The bytes never moved, so the bootstrap
;; stayed green through all of it** -- an exact oracle that says nothing about cost.
;;
;; So the offsets are computed ONCE, by one forward pass, and handed out by index.
;;
;; **And the pass makes the backward-call rule structural.** Every internal call in this block
;; points backward: that is the prefix property C-141 relies on, and until now a convention
;; `tools/rt-embed.sh` checked on regeneration. Here the layout is ACCUMULATED, so when routine
;; `i` is built the vector holds exactly `0..i` -- a reference to a routine defined after it has
;; no value to read. A convention became a shape.
(:wat::core::defn :c::lay [lay <- :c::Layout at <- :wat::core::i64
                           i <- :wat::core::i64] -> :c::Layout
  (:wat::core::if (:wat::core::>= i (:c::rt-count)) lay
    ;; the routine's OWN address goes in before it is built -- `i64_quot` measures its jumps
    ;; from where it starts, so it has to be able to ask
    (:wat::core::let [lay1 (:wat::core::conj lay at)]
      (:c::lay lay1
        (:wat::core::+ at (:c::hexlen (:c::rt-nth i lay1)))
        (:wat::core::+ i 1)))))

(:wat::core::defn :c::layout [rt <- :wat::core::i64] -> :c::Layout
  (:c::lay (:wat::core::Vector :- [:wat::core::i64]) rt 0))

;; **the block does not move, so it is built ONCE and the offsets are shifted.**
;;
;; Every internal reference in it is a DIFFERENCE between two of its own addresses, so the bytes
;; at base 0 and at a real load address are identical -- checked directly when the layout was
;; first computed (F-137), not assumed. That makes `(:c::layout rt-addr)` the base-0 layout plus
;; rt-addr, and nothing has to be built a second time to learn it.
;;
;; This matters because a routine is no longer a string literal. `:c::compile` built the whole
;; block THREE times -- `(:c::layout 0)` to measure, `(:c::layout rt-addr)` for the real
;; addresses, and `:c::runtime` to emit -- which cost nothing while `:c::rt-flush` returned a
;; constant and cost 36% of the compiler's time by the twenty-sixth conversion. F-137's shape,
;; one level up: the work was always there, and turning the routines into expressions is what
;; made it expensive.
(:wat::core::defn :c::shift [lay <- :c::Layout base <- :wat::core::i64 i <- :wat::core::i64
                             acc <- :c::Layout] -> :c::Layout
  (:wat::core::if (:wat::core::>= i (:wat::core::length lay)) acc
    (:c::shift lay base (:wat::core::+ i 1)
      (:wat::core::conj acc (:wat::core::+ (:wat::core::nth lay i) base)))))
(:wat::core::defn :c::rebase [lay <- :c::Layout base <- :wat::core::i64] -> :c::Layout
  (:c::shift lay base 0 (:wat::core::Vector :- [:wat::core::i64])))

;; every entry point, by index into that one pass. `divzero`, `tree-push`, `tree-from-arr`,
;; `hexchar` and `node-new`'s siblings are reached only from inside other routines, so they need
;; no accessor -- only their place in the order, which they have.
(:wat::core::defn :c::at-flush [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 0))
(:wat::core::defn :c::at-ovf [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 1))
(:wat::core::defn :c::at-put [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 2))
(:wat::core::defn :c::at-i64 [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 3))
(:wat::core::defn :c::at-bool [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 4))
(:wat::core::defn :c::at-oom [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 5))
(:wat::core::defn :c::at-die [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 6))
;; `divzero` is reached only from inside the two division routines, so it needs no entry point in
;; the sense of being CALLED -- but it has an offset like everything else, and asking the layout
;; for it is the only non-recursive way to know where it starts. Computing it as "quot's start
;; less divzero's length" was fine while divzero was a hex literal and is a loop now that it is
;; an expression: measuring it requires building it, and building it requires measuring it.
(:wat::core::defn :c::at-divzero [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 7))
(:wat::core::defn :c::at-quot [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 8))
(:wat::core::defn :c::at-rem [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 9))
(:wat::core::defn :c::at-str [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 10))
(:wat::core::defn :c::at-cat [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 11))
(:wat::core::defn :c::at-cat-own [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 12))
(:wat::core::defn :c::at-subs [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 13))
(:wat::core::defn :c::at-tostr [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 14))
(:wat::core::defn :c::at-starts [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 15))
(:wat::core::defn :c::at-contains [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 16))
(:wat::core::defn :c::at-streq [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 17))
(:wat::core::defn :c::at-vnew [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 18))
(:wat::core::defn :c::at-varr [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 19))
(:wat::core::defn :c::at-nnew [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 20))
(:wat::core::defn :c::at-ncopy [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 21))
(:wat::core::defn :c::at-tget [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 22))
;; reached only from inside the vector routines, like `divzero` -- but with an offset like
;; everything else, and asking the layout is the only non-recursive way to have it
(:wat::core::defn :c::at-tpush [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 23))
(:wat::core::defn :c::at-tfa [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 24))
(:wat::core::defn :c::at-vconj [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 25))
(:wat::core::defn :c::at-vconj-own [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 26))
(:wat::core::defn :c::at-slot [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 27))
(:wat::core::defn :c::at-slot-own [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 28))
(:wat::core::defn :c::at-hexval [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 29))
(:wat::core::defn :c::at-hexchar [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 30))
(:wat::core::defn :c::at-wrhex [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 31))
(:wat::core::defn :c::at-rdhex [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 32))
(:wat::core::defn :c::at-rdfile [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 33))
;; R17: the check build's underflow abort -- see `:c::rt-uflow` above and `:c::dropchk-hex`.
;; G6 (stone 3b): index 34 used to be `:c::rt-drop1`, retired -- this is the `:c::rt-nth`
;; `:else` fallthrough now, one index earlier than before.
(:wat::core::defn :c::at-uflow [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 34))

;; ---------------------------------------------------------------- what the heap looks like
;;
;; **Three displacements account for most of the runtime, and all three were the literal 8.** A
;; string is a length followed by its bytes, so its characters begin one word in; a vector is a
;; tag word followed by a length followed by its elements, and the pointer handed out is the one
;; to the LENGTH, so its elements begin one word past that. Writing 8 at each site means the
;; three uses are indistinguishable -- and a routine that reads a vector's length with a string's
;; offset is right by accident, which is the worst way for a thing to be right.
(:wat::core::defn :c::word [] -> :wat::core::i64 8)
;; r14 addresses a header the runtime keeps in front of everything: how many bytes are waiting
;; to be written, where the heap must stop, two size-class free-list tables (excursus 008 M2),
;; and the buffer itself.
(:wat::core::defn :c::hdr-pending [] -> :wat::core::i64 0)
(:wat::core::defn :c::hdr-limit [] -> :wat::core::i64 8)
;; **M2: the allocator reuses holes.** Two tables of list-head words, both zero-filled for free
;; (anonymous `mmap` pages come zeroed, so an empty list needs no explicit init -- `:c::stub-arm`
;; never touches this range). A list head of 0 means empty; a nonzero head is a dead block's own
;; pointer, and the dead block's own count word (`[pointer-8]`, already meaningless the instant
;; the count hits zero -- a poisoned or live object never reaches this path) holds the link to
;; the next dead block, or 0.
;;
;; `SMALL`: one list per EXACT multiple of 8 from 8 through `:c::small-max` (512) -- a trie node's
;; fixed 272 bytes is the largest FIXED shape in the runtime, and 512 leaves room for a record or
;; closure of up to 62 fields/captures before a shape stops fitting, comfortably past anything in
;; `elf/`'s own corpus. Index `(size>>3)-1` (0..63), an EXACT match every time: the table only
;; ever holds a size it was asked for exactly, so a pop wastes nothing.
;;
;; `LARGE`: one list per power of two, index `bsr(size)` (0..63) -- `:c::rt-cap`'s OWN classing
;; (a String's or an owned Vector's block is already a power of two by construction, from the
;; same bsr+shift this indexes by), not a second rounding rule. Only reached when `size >
;; :c::small-max` AND `size` is itself already a power of two (`:c::rt-bump` tests this with
;; `size & (size-1) == 0`); a large EXACT (non-power-of-two) shape -- nothing in `elf/` ever
;; produces one, see `:c::small-max` above -- is freed but never listed: filing it under a FLOORED
;; power-of-two class would make it invisible to a future CEILING-based search for the same size,
;; and the honest answer is not to pretend reuse works there.
(:wat::core::defn :c::small-max [] -> :wat::core::i64 512)
(:wat::core::defn :c::hdr-small [] -> :wat::core::i64 16)
(:wat::core::defn :c::hdr-large [] -> :wat::core::i64 (:wat::core::+ 16 512))
(:wat::core::defn :c::hdr-buf [] -> :wat::core::i64 (:wat::core::+ 16 (:wat::core::+ 512 512)))
;; the pending count at which the buffer is written out. The allocation (`:c::buf-bytes`) is
;; larger, so a single put that crosses this still has somewhere to land before the flush.
(:wat::core::defn :c::buf-hiwater [] -> :wat::core::i64 4096)
;; the Linux calls this runtime makes, by number rather than by the `1` that means three things
(:wat::core::defn :c::sys-write [] -> :wat::core::i64 1)
(:wat::core::defn :c::sys-read [] -> :wat::core::i64 0)
(:wat::core::defn :c::sys-open [] -> :wat::core::i64 2)
(:wat::core::defn :c::sys-close [] -> :wat::core::i64 3)
(:wat::core::defn :c::sys-exit [] -> :wat::core::i64 60)
(:wat::core::defn :c::sys-mmap [] -> :wat::core::i64 9)
(:wat::core::defn :c::sys-sysinfo [] -> :wat::core::i64 99)
;; **the open flags, added rather than written.** 0x241 is three bits and saying so is the whole
;; difference between a number and a decision.
(:wat::core::defn :c::o-wronly [] -> :wat::core::i64 1)
(:wat::core::defn :c::o-creat [] -> :wat::core::i64 64)
(:wat::core::defn :c::o-trunc [] -> :wat::core::i64 512)
(:wat::core::defn :c::file-mode [] -> :wat::core::i64 493)    ;; 0o755
;; how much `read` is asked for at a time
(:wat::core::defn :c::read-chunk [] -> :wat::core::i64 65536)
(:wat::core::defn :c::fd-stdout [] -> :wat::core::i64 1)
(:wat::core::defn :c::fd-stderr [] -> :wat::core::i64 2)
;; the two other control characters EDN escapes, beside the newline `:c::nl` already names.
;; `:asm::code-of` cannot give any of the three -- its table starts at 32 (F-062).
(:wat::core::defn :c::tab [] -> :wat::core::i64 9)
(:wat::core::defn :c::cr [] -> :wat::core::i64 13)
;; what a program exits with when the runtime stops it -- an overflow, a division by zero, a
;; `die`. Distinct from anything a correct program returns; `tools/elf-run.sh` asserts on it.
(:wat::core::defn :c::exit-fail [] -> :wat::core::i64 70)
;; the word every allocation writes at its start, one word BEFORE the pointer it hands out.
;; `str_cat_own` tests it to tell an owned String from a borrowed one.
(:wat::core::defn :c::heap-arm [] -> :wat::core::i64 1)
;; excursus 008 stone 3b-1 (G5): what a dead object's count word becomes, under
;; `WAT_DROP_CHECK=1`, the moment a decrement takes it to zero. Not 0 -- a literal's count is
;; already 0, and a poisoned object must never read as one. `-1` sign-extends through
;; `:c::mov-mi`'s 32-bit immediate to fill the whole 64-bit word, and no live count is ever
;; negative, so one comparison tells a poisoned object from a live one. Nothing is freed this
;; strike -- the bytes stay exactly where they were, only unusable.
(:wat::core::defn :c::poison-count [] -> :wat::core::i64 -1)
;; a tree node: one header word, then a fixed fan-out of child slots
(:wat::core::defn :c::node-data [] -> :wat::core::i64 8)
(:wat::core::defn :c::node-arity [] -> :wat::core::i64 32)
(:wat::core::defn :c::str-data [] -> :wat::core::i64 8)   ;; past the length
;; **the pointer handed out is not the start of the allocation.** A record is [arm][len][elem...]
;; and the pointer is to the len, one word in; a Vector is [0][1][len][elem...] and the pointer is
;; two words in. So the allocation is bigger than the object by exactly the distance skipped, and
;; the two numbers are written as one fact each rather than as 16 and 8 in adjacent lines.
;; what a Vector's pointer actually addresses: the length, then the trie's shift (how many bits
;; of an index the root level consumes), then the root node.
;; from the pointer to the first element. C-174 deleted this as dead -- it was, then -- and
;; `slot_set` is what wanted it: the distance it copies from and to.
(:wat::core::defn :c::vec-data [] -> :wat::core::i64 8)
(:wat::core::defn :c::vec-shift [] -> :wat::core::i64 8)
(:wat::core::defn :c::vec-root [] -> :wat::core::i64 16)
(:wat::core::defn :c::vec-ptr [] -> :wat::core::i64 8)
(:wat::core::defn :c::vec-hdr [] -> :wat::core::i64 16)
;; **a Vector is FLAT until it is not.** The word two before the pointer says which: a small
;; vector is a plain array and `conj` copies it; past `:c::arr-max` elements it is promoted to
;; the 32-way trie and `conj` goes through `tree_push` instead. `vec_conj` tests exactly this.
;; Every reader must ask "is it `:c::vec-tree`", never "is it `:c::vec-flat`": a third value
;; (`:c::vec-flat-own`) is ALSO flat (excursus 008 F2).
(:wat::core::defn :c::vec-flat [] -> :wat::core::i64 0)
(:wat::core::defn :c::vec-tree [] -> :wat::core::i64 1)
;; **flat, in an owned power-of-two block** (excursus 008 F2) -- `vec_conj_own`'s path 4 marks
;; its fresh copy with this instead of plain `:c::vec-flat`, because the block has spare
;; capacity past `len` that path 2 may fill in place. This used to be `:c::arm-own`, written
;; into the COUNT word; a count word must hold only a count (it is read and written by the
;; same generic increment/decrement every other type uses), so the mark moves here and path 2
;; now asks two things: this tag, AND a count of exactly one (nobody else shares the block).
(:wat::core::defn :c::vec-flat-own [] -> :wat::core::i64 2)
(:wat::core::defn :c::arr-max [] -> :wat::core::i64 8)
(:wat::core::defn :c::varr-ptr [] -> :wat::core::i64 16)
(:wat::core::defn :c::varr-hdr [] -> :wat::core::i64 24)

;; **a branch to somewhere else in the runtime block.** Both ends are offsets from the same
;; base, so evaluating the layout at zero gives the distance and the base cancels. `here` is
;; where the branch ENDS, which is what a relative displacement is measured from.
(:wat::core::defn :c::rt-branch [cc <- :wat::core::i64 target <- :wat::core::i64
                                 here <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat (:c::jcc-rel32 cc) (:asm::le (:wat::core::- target here) 4)))
;; the same distance, called rather than jumped
(:wat::core::defn :c::rt-call [target <- :wat::core::i64
                               here <- :wat::core::i64] -> :wat::core::String
  (:c::call-rel32 (:wat::core::- target here)))

;; **the gap between the digits and the letters, derived rather than written.** `'a'` does not
;; follow `'9'` in ASCII -- seven punctuation characters sit between them -- and every hex routine
;; has to step over exactly that distance. Writing `39` means trusting whoever counted; asking
;; `:asm::code-of` means the number cannot be wrong, because it is computed from the two
;; characters it is the distance between.
(:wat::core::defn :c::hex-gap [] -> :wat::core::i64
  (:wat::core::- (:wat::core::- (:asm::code-of "a") (:asm::code-of "9")) 1))
