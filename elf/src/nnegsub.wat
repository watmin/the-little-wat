;; **What a branch proves about the arm it guards** (C-166). Inside the THEN arm of `(> x k)`
;; with `k >= 0`, `x` is non-negative -- and `x - j` with `j >= 0` then lies in `[-j, x]`, which
;; is inside i64 whatever `x` and `j` are. So the overflow check on that subtraction is dead code
;; and is not emitted. `elf/bench/triple.wat` is three of those an iteration; so is every `fib`.
;;
;; Everything here is a value wat computes without trapping, so both sides must print it. The
;; case where the proof does NOT travel -- a `let` rebinding the name -- is in elf/bad/, because
;; it stops.

(wat.core/defn user/id [n :- wat.type/i64] :- wat.type/i64 n)

;; the guarded subtraction at the edge of what the elision can reach: the largest right operand
;; that still fits the one-instruction form, taken from the smallest x the branch admits
(wat.core/defn user/edge [x :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= x 0) (wat.core/- x 2147483647) x))

;; past that width the subtraction is not one instruction, so the elision does not fire and the
;; answer must be the same anyway
(wat.core/defn user/big [x :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= x 0) (wat.core/- x 9223372036854775807) x))

;; the same fact reached from the other side: the ELSE arm of `(< x k)` knows `x >= k >= 0`
(wat.core/defn user/other [x :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< x 5) x (wat.core/- x 5)))

;; the subtraction chains, and only the FIRST step is covered -- `x - 1000` is nothing the
;; branch said anything about
(wat.core/defn user/chain [x :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= x 1000) (wat.core/- x 1000 1000) x))

;; a negative literal on the right proves nothing, so the check stays and the answer is the same
(wat.core/defn user/plus [x :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/> x 3) (wat.core/- x -4) x))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/edge (user/id 0)))
  (wat.kernel/println (user/edge (user/id 2147483647)))
  (wat.kernel/println (user/edge (user/id -1)))
  (wat.kernel/println (user/big (user/id 0)))
  (wat.kernel/println (user/big (user/id 9223372036854775807)))
  (wat.kernel/println (user/other (user/id 4)))
  (wat.kernel/println (user/other (user/id 5)))
  (wat.kernel/println (user/other (user/id -9223372036854775808)))
  (wat.kernel/println (user/chain (user/id 1000)))
  (wat.kernel/println (user/chain (user/id 999)))
  (wat.kernel/println (user/plus (user/id 4))))
