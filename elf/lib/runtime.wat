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

;; `print_i64(rax)` -- the digits come out BACKWARDS, so they are written backwards. rsi starts
;; at the end of a stack scratch and walks down; the count at the end is how far it walked.
;;
;; `div` leaves the remainder in rdx, and adding `'0'` to its LOW BYTE turns it into a character
;; in place -- which is what the 8-bit forms are for. The newline is planted first, at the top of
;; the buffer, so it needs no separate write.
(:wat::core::defn :c::rt-print-i64 [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [top -1
     ;; one digit: divide by ten, make the remainder a character, step back, store it
     digit (:wat::string::concat
             (:c::xor-rr (:c::rdx) (:c::rdx))
             (:c::div-r (:c::rcx))
             (:c::add-ri8 (:c::rdx) (:asm::code-of "0"))
             (:c::dec-r (:c::rsi))
             (:c::mov-mr8 (:c::rdx) (:c::rsi) 0)
             (:c::test-rr (:c::rax) (:c::rax)))
     loop (:wat::string::concat digit
            (:c::br-back (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) digit))
     ;; a negative was negated for the division, and r8 remembers it
     sign (:wat::string::concat (:c::neg-r (:c::rax)) (:c::mov-ri (:c::r8) 1))
     minus (:wat::string::concat
             (:c::dec-r (:c::rsi))
             (:c::mov-mi8 (:c::rsi) 0 (:asm::code-of "-")))
     tail (:wat::string::concat
            (:c::lea-at (:c::rbp) top (:c::rdx))
            (:c::sub-rr (:c::rsi) (:c::rdx))
            (:c::inc-r (:c::rdx)))
     head (:wat::string::concat
            (:c::reg-push (:c::rbp)) (:c::mov-rr (:c::rsp) (:c::rbp))
            (:c::sub-ri (:c::rsp) (:c::scratch-frame))
            (:c::lea-at (:c::rbp) top (:c::rsi))
            (:c::mov-mi8 (:c::rsi) 0 (:c::nl))
            (:c::xor-rr (:c::r8) (:c::r8))
            (:c::test-rr (:c::rax) (:c::rax))
            (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-sign))) sign)
            sign
            (:c::mov-ri (:c::rcx) 10)
            loop
            (:c::test-rr (:c::r8) (:c::r8))
            (:c::br-over (:c::jcc-rel8 (:c::cc-zero)) minus)
            minus
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
     fit (:wat::string::concat
           (:c::mov-mr (:c::r11) (:c::rax) 0)
           (:c::rm "8d" (:c::rdi) (:c::rax) (:c::r8) 1 (:c::str-data))
           (:c::lea-at (:c::r9) (:c::str-data) (:c::rsi))
           (:c::mov-rr (:c::r10) (:c::rcx))
           (:c::rep-movsb)
           (:c::ret))
     body (:wat::string::concat
            (:c::mov-rr (:c::rcx) (:c::r9))
            (:c::mov-rm (:c::rax) 0 (:c::r8))
            (:c::mov-rm (:c::r9) 0 (:c::r10))
            (:c::mov-rr (:c::r8) (:c::r11))
            (:c::add-rr (:c::r10) (:c::r11))
            (:c::rt-cap (:c::r8) (:c::rdi))
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
           (:c::rt-cap (:c::rax) (:c::rdx)))]
    (:wat::string::concat
      pre
      ;; rcx carries the new top here, not r11 -- r10 and r11 are holding the two sources
      (:c::rt-bump (:wat::core::+ (:c::at-cat lay) (:c::hexlen pre)) lay
        (:c::add-rr (:c::rdx) (:c::rcx)) (:c::rcx))
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

(:wat::core::defn :c::rt-print-str [] -> :wat::core::String
  (:wat::string::concat
    "4989c04d8b08498d70084c89ff4d89fac6072248ffc74d31db4d39cb7d5a"
    "8a063c2274173c5c74133c0a741c3c0974263c0d7430880748ffc7eb35c6"
    "075c48ffc7880748ffc7eb28c6075c48ffc7c6076e48ffc7eb1ac6075c48"
    "ffc7c6077448ffc7eb0cc6075c48ffc7c6077248ffc748ffc649ffc3eba1"
    "c6072248ffc7c6070a48ffc74889fa4c29d24c89d6e84dfdffffc3"))

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
(:wat::core::defn :c::rt-cap [len <- :wat::core::i64 out <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat
    (:c::lea-at len 15 (:c::rdx))
    (:c::bsr-rr (:c::rdx) (:c::rcx))
    (:c::mov-ri out 2)
    (:c::shl-cl out)))

;; `grow` is how r11 reaches the new top: `add %rcx,%r11` when the size was computed into rcx,
;; or `add $imm,%r11` when it is a constant. That is the ONLY difference between the three
;; allocators, and it was the reason each carried its own copy of the check.
(:wat::core::defn :c::rt-bump [here <- :wat::core::i64 lay <- :c::Layout
                               grow <- :wat::core::String
                               top <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let
    [chk (:wat::string::concat
           (:c::mov-rr (:c::r15) top)
           grow
           (:c::cmp-rm (:c::r14) (:c::hdr-limit) top))
     at-call (:wat::core::+ here (:wat::core::+ (:c::hexlen chk) (:c::rel8-size)))
     to-oom (:c::rt-call (:c::at-oom lay) (:wat::core::+ at-call (:c::call-size)))]
    (:wat::string::concat chk (:c::jbe-over to-oom) to-oom)))

;; `vec_new(rax = len) -> rax` -- a record, whose arm word says which one. The size is
;; `hdr + len*8` and `lea` computes it without touching a flag: scale 8, no base at all, which
;; is the SIB form whose base field means "none".
(:wat::core::defn :c::rt-vec-new [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [size (:c::lea (:c::no-reg) (:c::rax) (:c::word) (:c::vec-hdr) (:c::rcx))]
    (:wat::string::concat
      size
      (:c::rt-bump (:wat::core::+ (:c::at-vnew lay) (:c::hexlen size)) lay
        (:c::add-rr (:c::rcx) (:c::r11)) (:c::r11))
      (:c::mov-mi (:c::r15) 0 1)
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r10))
      (:c::mov-mr (:c::rax) (:c::r10) 0)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r10) (:c::rax))
      (:c::ret))))

;; `vec_conj(rax = vector, rcx = element) -> rax`, 48 bytes: a longer copy with the element on
;; the end. `rep movsq` moves the old slots in three bytes of code. This is `conj`, and it is
;; O(n) every time, which is the same thing the interpreter's Vector does (F-023).
;; `vec_conj_own` -- `conj` where the compiler has PROVED the container is a last use.
;; That plus a reference count of 1 (never stored anywhere durable) plus being the top of the
;; heap is enough to extend in place, which turns an accumulator loop from O(n^2) into O(n). It
;; is Rust's `Vec::push` and Clojure's transient, assembled from the two halves neither wat nor
;; this compiler had alone: the count rules out aliases, last-use rules out later reads. Any of
;; the three tests failing falls through to the copying `vec_conj` below.
(:wat::core::defn :c::rt-vec-conj-own [] -> :wat::core::String
  (:wat::string::concat
    "488378f0000f8587ffffff49b901000000010000004c3948f8743d488378"
    "f8010f856cffffff4c8b004a8d54c0084c39fa74054989c9eb564d89fb49"
    "83c3084d3b5e087605e828f9ffff49890f4d89df498d5001488910c34c8b"
    "004989c94a8d14c517000000480fbdca48c7c20200000048d3e24e8d1cc5"
    "200000004939d3770d4e894cc008498d5001488910c34c8b004a8d14c51f"
    "000000480fbdca48c7c20200000048d3e24d89fb4901d34d3b5e087605e8"
    "baf8ffff49c7070000000048ba0100000001000000498957084d8d571049"
    "8d5001498912498d7a08488d70084c89c1f348a54c890f4d89df4c89d0c3"))

;; `varr_new(rax = len) -> rax` -- a Vector's leaf array, which carries one more header word
;; than a record does and is otherwise the same allocation
(:wat::core::defn :c::rt-varr-new [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [size (:c::lea (:c::no-reg) (:c::rax) (:c::word) (:c::varr-hdr) (:c::rcx))]
    (:wat::string::concat
      size
      (:c::rt-bump (:wat::core::+ (:c::at-varr lay) (:c::hexlen size)) lay
        (:c::add-rr (:c::rcx) (:c::r11)) (:c::r11))
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
            (:c::add-ri (:c::r11) (:wat::core::+ (:c::vec-hdr) slots)) (:c::r11))]
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
    [pre (:wat::string::concat (:c::reg-push (:c::rbx)) (:c::mov-rr (:c::rax) (:c::rbx)))
     at-call (:wat::core::+ (:c::at-ncopy lay) (:c::hexlen pre))]
    (:wat::string::concat
      pre
      (:c::rt-call (:c::at-nnew lay) (:wat::core::+ at-call (:c::call-size)))
      (:c::lea-at (:c::rax) (:c::node-data) (:c::rdi))
      (:c::lea-at (:c::rbx) (:c::node-data) (:c::rsi))
      (:c::mov-ri (:c::rcx) (:c::node-arity))
      (:c::rep-movsq)
      (:c::reg-pop (:c::rbx))
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

(:wat::core::defn :c::rt-tree-push [] -> :wat::core::String
  (:wat::string::concat
    "53415441554989cc4c8b28488b50084c8b481049c7c2200000004889d149"
    "d3e24d39ea7510e83fffffff4c8948084989c14883c205524c89c8e86aff"
    "ffff4989c04889c34885d274344c89e84889d148d3e84883e01f4989c14a"
    "8b44cb084885c07407e840ffffffeb05e8fafeffff4a8944cb084889c348"
    "83ea05ebc74c89e84883e01f4c8964c3085a4d89fb4983c3284d3b5e0876"
    "05e876faffff49c7070100000049c7470801000000498d4710498d4d0148"
    "8908488950084c8940104d89df415d415c5bc3"))

(:wat::core::defn :c::rt-tree-from-arr [] -> :wat::core::String
  (:wat::string::concat
    "53415441554889c34c8b2b4d31e4e88ffeffff4989c14d89fb4983c3284d"
    "3b5e087605e823faffff49c7070100000049c7470801000000498d471048"
    "c7000000000048c74008000000004c8948104d89df4d39ec730f4a8b4ce3"
    "08e8d9feffff49ffc4ebec415d415c5bc3"))

(:wat::core::defn :c::rt-vec-conj [] -> :wat::core::String
  (:wat::string::concat
    "488378f0000f85c3feffff4c8b004983f808720c51e87bffffff59e9aefe"
    "ffff4989ca4a8d14c5200000004d89fb4901d34d3b5e087605e8a4f9ffff"
    "49c7070000000049c74708010000004d8d4f10498d5001498911498d7908"
    "488d70084c89c1f348a54c89174d89df4c89c8c3"))

;; `slot_set(rax = vector, rcx = index, rdx = value) -> rax` -- a copy of the whole array with
;; one slot changed, which is what an immutable `assoc` on a leaf costs. The allocation is
;; `vec_new`'s, so it is `:c::rt-bump` again; the size is computed into rdx between the two
;; halves of the check, which is why `grow` is a string rather than a register.
(:wat::core::defn :c::rt-slot-set [lay <- :c::Layout] -> :wat::core::String
  (:wat::core::let
    [pre (:wat::string::concat
           (:c::reg-push (:c::rbx))
           (:c::mov-rm (:c::rax) 0 (:c::r8))
           (:c::mov-rr (:c::rcx) (:c::r10))
           (:c::mov-rr (:c::rdx) (:c::rbx)))
     grow (:wat::string::concat
            (:c::lea (:c::no-reg) (:c::r8) (:c::word) (:c::vec-hdr) (:c::rdx))
            (:c::add-rr (:c::rdx) (:c::r11)))]
    (:wat::string::concat
      pre
      (:c::rt-bump (:wat::core::+ (:c::at-slot lay) (:c::hexlen pre)) lay grow (:c::r11))
      (:c::mov-mi (:c::r15) 0 1)
      (:c::lea-at (:c::r15) (:c::vec-ptr) (:c::r9))
      (:c::mov-mr (:c::r8) (:c::r9) 0)
      (:c::lea-at (:c::r9) (:c::vec-data) (:c::rdi))
      (:c::lea-at (:c::rax) (:c::vec-data) (:c::rsi))
      (:c::mov-rr (:c::r8) (:c::rcx))
      (:c::rep-movsq)
      (:c::mov-rr (:c::r11) (:c::r15))
      (:c::mov-rr (:c::r9) (:c::rax))
      ;; the one slot that differs
      (:c::rm "89" (:c::rbx) (:c::rax) (:c::r10) (:c::word) (:c::vec-data))
      (:c::reg-pop (:c::rbx))
      (:c::ret))))

;; `oom()` -- every allocator compares `r15 + need` against the limit at `r14+8` and calls this
;; when it would cross. There is no second chance: the heap is one mmap and it does not grow.
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
           (:c::rt-cap (:c::r8) (:c::r9)))]
    (:wat::string::concat
      pre
      (:c::rt-bump (:wat::core::+ (:c::at-subs lay) (:c::hexlen pre)) lay
        (:c::add-rr (:c::r9) (:c::r11)) (:c::r11))
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

;; `i64_to_str(rax = n) -> rax`: `print_i64`'s divide-by-ten loop, landing in the heap
;; instead of the output buffer.
(:wat::core::defn :c::rt-i64-to-str [] -> :wat::core::String
  (:wat::string::concat
    "554889e54883ec204889ee4d31c04885c0790a48f7d849c7c00100000048"
    "c7c10a0000004831d248f7f180c23048ffce88164885c075ed4d85c07406"
    "48ffcec6062d4989e94929f14d8d510f490fbdca49c7c20200000049d3e2"
    "4d89fb4d01d34d3b5e087605e8c0fcffff49c707010000004d8d57084d89"
    "0a498d7a084d89df4c89c9f3a44c89d0c9c3"))

;; `str_eq(rax = a, rcx = b) -> 0 or 1`, 40 bytes. **This one closes a silent divergence.**
;; `(wat.core/= a b)` on two Strings compiled to a machine-word compare, which compares
;; POINTERS: `(= (concat "ab" "c") (concat "a" "bc"))` answered false where the interpreter
;; answers true. The type pass knows both operand types, so `=` on two `str` operands now calls
;; this instead. Nothing had noticed because no program in elf/src compared two strings -- a
;; reader is the first thing that must.
;; `str_eq(rax, rcx) -> 0 or 1`. Different lengths are different strings, and that test is one
;; instruction against the header rather than a comparison that has to run.
(:wat::core::defn :c::rt-str-eq [] -> :wat::core::String
  (:wat::string::concat
    (:c::mov-rm (:c::rax) 0 (:c::r8))
    (:c::cmp-rm (:c::rcx) 0 (:c::r8))
    (:c::br-over (:c::jcc-rel8 (:c::negate-cc (:c::cc-zero))) (:c::rt-str-body))
    (:c::rt-str-tail)))

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

;; `prim_write_hex(rax = path, rcx = hex) -> rax = bytes written`. Decodes the hex into a
;; buffer above the heap top and writes it with open/write/close. **Parks its pointers in r12,
;; not r11: `syscall` destroys rcx and r11.**
(:wat::core::defn :c::rt-prim-write-hex [] -> :wat::core::String
  (:wat::string::concat
    "5341544989c04989c94d89fa498d70084c89d7498b08f3a4c6070048ffc7"
    "4989fc498b1148d1ea4889d3498d71084885d2742b480fb606e8a6ffffff"
    "48c1e0044889c1480fb64601e895ffffff4809c888074883c60248ffc748"
    "ffca75d548c7c0020000004c89d748c7c64102000048c7c2ed0100000f05"
    "4989c148c7c0010000004c89cf4c89e64889da0f054989c248c7c0030000"
    "004c89cf0f054c89d0415c5bc3"))

;; `prim_read_hex(rax = path) -> rax = a String of hex`.
(:wat::core::defn :c::rt-prim-read-hex [] -> :wat::core::String
  (:wat::string::concat
    "41544d89fa488d70084c89d7488b08f3a4c6070048ffc74989fc48c7c002"
    "0000004c89d74831f64831d20f054989c04d89e148c7c0000000004c89c7"
    "4c89ce48c7c2000001000f054885c07e054901c1ebe048c7c0030000004c"
    "89c70f054c89ca4c29e24d8d41074983e0f84889d04801c0488d480f480f"
    "bdc948c7c60200000048d3e64c01c6493b76087605e8e3f6ffff4989f749"
    "c700010000004d8d5008498902498d7a084c89e64885d2742e480fb60648"
    "89c148c1e804e88ffeffff880748ffc74889c84883e00fe87efeffff8807"
    "48ffc748ffc648ffca75d24c89d0415cc3"))

;; `io_read_file(rax = path) -> rax = a String of the file bytes`. This is `wat.io/read-file`.
(:wat::core::defn :c::rt-io-read-file [] -> :wat::core::String
  (:wat::string::concat
    "41544d89fa488d70084c89d7488b08f3a4c6070048ffc74989fc48c7c002"
    "0000004c89d74831f64831d20f054989c04d89e148c7c0000000004c89c7"
    "4c89ce48c7c2000001000f054885c07e054901c1ebe048c7c0030000004c"
    "89c70f054c89ca4c29e24d8d41074983e0f8488d4a0f480fbdc948c7c602"
    "00000048d3e64c01c6493b76087605e806f6ffff4989f749c70001000000"
    "4d8d5008498912498d7a084c89e64889d1f3a44c89d0415cc3"))

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

(:wat::core::defn :c::rt-count [] -> :wat::core::i64 33)

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
    ((:wat::core::= i 10) (:c::rt-print-str))
    ((:wat::core::= i 11) (:c::rt-str-cat lay))
    ((:wat::core::= i 12) (:c::rt-str-cat-own lay))
    ((:wat::core::= i 13) (:c::rt-str-subs lay))
    ((:wat::core::= i 14) (:c::rt-i64-to-str))
    ((:wat::core::= i 15) (:c::rt-str-starts))
    ((:wat::core::= i 16) (:c::rt-str-contains))
    ((:wat::core::= i 17) (:c::rt-str-eq))
    ((:wat::core::= i 18) (:c::rt-vec-new lay))
    ((:wat::core::= i 19) (:c::rt-varr-new lay))
    ((:wat::core::= i 20) (:c::rt-node-new lay))
    ((:wat::core::= i 21) (:c::rt-node-copy lay))
    ((:wat::core::= i 22) (:c::rt-tree-get))
    ((:wat::core::= i 23) (:c::rt-tree-push))
    ((:wat::core::= i 24) (:c::rt-tree-from-arr))
    ((:wat::core::= i 25) (:c::rt-vec-conj))
    ((:wat::core::= i 26) (:c::rt-vec-conj-own))
    ((:wat::core::= i 27) (:c::rt-slot-set lay))
    ((:wat::core::= i 28) (:c::rt-hexval))
    ((:wat::core::= i 29) (:c::rt-hexchar))
    ((:wat::core::= i 30) (:c::rt-prim-write-hex))
    ((:wat::core::= i 31) (:c::rt-prim-read-hex))
    (:else (:c::rt-io-read-file))))

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
(:wat::core::defn :c::at-vconj [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 25))
(:wat::core::defn :c::at-vconj-own [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 26))
(:wat::core::defn :c::at-slot [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 27))
(:wat::core::defn :c::at-hexval [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 28))
(:wat::core::defn :c::at-wrhex [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 30))
(:wat::core::defn :c::at-rdhex [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 31))
(:wat::core::defn :c::at-rdfile [lay <- :c::Layout] -> :wat::core::i64 (:wat::core::nth lay 32))

;; ---------------------------------------------------------------- what the heap looks like
;;
;; **Three displacements account for most of the runtime, and all three were the literal 8.** A
;; string is a length followed by its bytes, so its characters begin one word in; a vector is a
;; tag word followed by a length followed by its elements, and the pointer handed out is the one
;; to the LENGTH, so its elements begin one word past that. Writing 8 at each site means the
;; three uses are indistinguishable -- and a routine that reads a vector's length with a string's
;; offset is right by accident, which is the worst way for a thing to be right.
(:wat::core::defn :c::word [] -> :wat::core::i64 8)
;; r14 addresses a three-field header the runtime keeps in front of everything: how many bytes
;; are waiting to be written, where the heap must stop, and the buffer itself.
(:wat::core::defn :c::hdr-pending [] -> :wat::core::i64 0)
(:wat::core::defn :c::hdr-limit [] -> :wat::core::i64 8)
(:wat::core::defn :c::hdr-buf [] -> :wat::core::i64 16)
;; the pending count at which the buffer is written out. The allocation (`:c::buf-bytes`) is
;; larger, so a single put that crosses this still has somewhere to land before the flush.
(:wat::core::defn :c::buf-hiwater [] -> :wat::core::i64 4096)
;; the Linux calls this runtime makes, by number rather than by the `1` that means three things
(:wat::core::defn :c::sys-write [] -> :wat::core::i64 1)
(:wat::core::defn :c::sys-exit [] -> :wat::core::i64 60)
(:wat::core::defn :c::fd-stdout [] -> :wat::core::i64 1)
(:wat::core::defn :c::fd-stderr [] -> :wat::core::i64 2)
;; what a program exits with when the runtime stops it -- an overflow, a division by zero, a
;; `die`. Distinct from anything a correct program returns; `tools/elf-run.sh` asserts on it.
(:wat::core::defn :c::exit-fail [] -> :wat::core::i64 70)
;; the word every allocation writes at its start, one word BEFORE the pointer it hands out.
;; `str_cat_own` tests it to tell an owned String from a borrowed one.
(:wat::core::defn :c::heap-arm [] -> :wat::core::i64 1)
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
