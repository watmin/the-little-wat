;; **The branchless-arm select** (C-169). A tail-call argument of the shape
;; `(if (CMP reg imm) A B)` where both arms are values -- a register, a constant, or `(- x k)`
;; that C-166 proved cannot underflow -- is written straight into its parameter register, one
;; instruction per arm, instead of going through rax and a join.
;;
;; Only `elf/bench/loopsum.wat` and `elf/bench/triple.wat` changed a byte when it went in, which
;; is thin coverage for new code generation. This is the coverage: every arm shape, both sides of
;; the comparison, the case where an arm is already in its destination, and the edges of i64.
;;
;; Run both ways; they must agree.

;; both arms are registers: the shape of `max`
(wat.core/defn user/mx [i :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) (wat.core/+ a b)
    (user/mx (wat.core/- i 1) (wat.core/if (wat.core/> a 0) a b) b)))

;; one arm is a constant, the other is the destination register already -- so the else arm
;; compiles to nothing and the branch is the one that skips the THEN arm
(wat.core/defn user/clamp [i :- wat.type/i64 a :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) a
    (user/clamp (wat.core/- i 1) (wat.core/if (wat.core/> a 100) 100 a))))

;; the C-166 arm on the THEN side, at the largest right operand the one-instruction form reaches
(wat.core/defn user/wrap [i :- wat.type/i64 a :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) a
    (user/wrap (wat.core/- i 1)
      (wat.core/if (wat.core/> a 2147483647) (wat.core/- a 2147483647) (wat.core/+ a 1000000000)))))

;; ...and on the ELSE side, where `(< a k)` proves it about the arm it does NOT guard
(wat.core/defn user/down [i :- wat.type/i64 a :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) a
    (user/down (wat.core/- i 1) (wat.core/if (wat.core/< a 7) a (wat.core/- a 7)))))

;; both arms are the SAME register: there is nothing to choose between, and the select must
;; emit nothing at all rather than a compare with two empty arms
(wat.core/defn user/same [i :- wat.type/i64 a :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) a
    (user/same (wat.core/- i 1) (wat.core/if (wat.core/>= a 0) a a))))

;; a destination beyond the first four registers, so the REX bits on both operands are exercised
(wat.core/defn user/wide [i :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64 c :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/= i 0) (wat.core/+ a (wat.core/+ b c))
    (wat.core/let [d (wat.core/+ a 1) e (wat.core/+ b 2) f (wat.core/+ c 3)]
      (user/wide (wat.core/- i 1)
        (wat.core/if (wat.core/> d 50) (wat.core/- d 50) d)
        (wat.core/if (wat.core/> e 60) (wat.core/- e 60) e)
        (wat.core/if (wat.core/> f 70) (wat.core/- f 70) f)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/mx 5 3 9))
  (wat.kernel/println (user/mx 5 -3 9))
  (wat.kernel/println (user/mx 0 -3 9))
  (wat.kernel/println (user/clamp 4 7))
  (wat.kernel/println (user/clamp 4 500))
  (wat.kernel/println (user/clamp 4 -9223372036854775808))
  (wat.kernel/println (user/wrap 6 0))
  (wat.kernel/println (user/wrap 6 2147483648))
  (wat.kernel/println (user/down 9 100))
  (wat.kernel/println (user/down 9 6))
  (wat.kernel/println (user/down 9 -9223372036854775808))
  (wat.kernel/println (user/same 3 42))
  (wat.kernel/println (user/same 3 -9223372036854775808))
  (wat.kernel/println (user/wide 10 0 0 0))
  (wat.kernel/println (user/wide 100 45 55 65)))
