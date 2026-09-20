;; **`elf/bench/triple.wat` with the strength reduction done BY HAND.** gcc -O2 emits no `imul`
;; at all for that loop: it turns `(* i 3)`, `(* i 5)` and `(* i 7)` into three registers counting
;; down by 3, 5 and 7. This is the same program with those three induction variables written out
;; as parameters, which is the best a compiler doing the transform could hand us.
;;
;; It is here to answer whether strength reduction is the missing optimisation or whether the gap
;; is the trapping semantics. gcc replaces an `imul` with a `sub` and pays nothing; we would
;; replace `imul`+`jo` with `sub`+`jo` and still owe the check, because nothing proves `m - 3`
;; cannot underflow. If that reasoning is right this program is not faster than triple.wat.
(wat.core/defn user/go [i :- wat.type/i64 a :- wat.type/i64 b :- wat.type/i64 c :- wat.type/i64
                        m3 :- wat.type/i64 m5 :- wat.type/i64 m7 :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= i 0) (wat.core/+ a (wat.core/+ b c))
    (wat.core/let [a2 (wat.core/+ a m3)
                   b2 (wat.core/+ b m5)
                   c2 (wat.core/+ c m7)]
      (user/go (wat.core/- i 1)
        (wat.core/if (wat.core/> a2 1000000) (wat.core/- a2 1000000) a2)
        (wat.core/if (wat.core/> b2 2000000) (wat.core/- b2 2000000) b2)
        (wat.core/if (wat.core/> c2 3000000) (wat.core/- c2 3000000) c2)
        (wat.core/- m3 3) (wat.core/- m5 5) (wat.core/- m7 7)))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go 30000000 0 0 0 90000000 150000000 210000000)))
