;; C-170 gives a counted loop's parameter the bound `[0, E]`, and that bound is what licenses
;; dropping the overflow check on `(* i C)`. **It must not license a multiply that really does
;; overflow.** Here `i` starts at a million and the multiplier is ten trillion: the very first
;; product is 10^19, past i64's ceiling of about 9.22x10^18.
;;
;; If the bound arithmetic is wrong -- if `:c::mul-ok?` says yes where it should say no -- this
;; program prints a wrapped answer instead of stopping, which is the worst kind of divergence
;; there is (F-120's shape, and the reason elf/bad/overflow.wat exists).
(wat.core/defn user/go [i :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) acc
    (user/go (wat.core/- i 1) (wat.core/* i 10000000000000))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 1000000 0)))
