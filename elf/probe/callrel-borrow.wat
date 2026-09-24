;; **the half of STOP-1 that is NOT closed -- and this DIVERGES AT HEAD, with no caller-side
;; release at all.** The pointer reaches the callee as `(wat.core/nth g 3)`, which is not a
;; Symbol, so `:c::share` never increments it; its arm word stays `:c::heap-arm` and it is still
;; the youngest allocation, so `vec_conj_own` path 3 extends a LIVE container's element in place.
;;
;; The interpreter says the row is 3 long and ends in 30. The compiler says 4, and the last
;; element reads:
;;
;;   99   without the caller-side release -- the extension is real memory, merely uncounted
;;    0   with it -- the caller's rewind freed the extension while the length still counts it
;;
;; So the caller-side release does not cause this; it turns a wrong length into a read of
;; reclaimed memory. `elf/compile.wat`'s `own?` at the `conj` site is where the gate belongs.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :user::Grid (:wat::core::Vector :- [:user::Row]))

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/nth (wat.core/conj v 99) 2))

(wat.core/defn user/fill [n :- wat.type/i64 acc :- :user::Grid] :- :user::Grid
  (wat.core/if (wat.core/= n 0) acc
    (user/fill (wat.core/- n 1)
      (wat.core/conj acc (wat.core/Vector :- [wat.type/i64] n 20 30)))))

(wat.core/defn user/churn [i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/churn (wat.core/+ i 1) n
      (wat.core/+ acc (wat.core/nth (wat.core/Vector :- [wat.type/i64] 7 8 9 10 11 12) 5)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [g (user/fill 4 (wat.core/Vector :- [:user::Row]))
                 k (user/bump (wat.core/nth g 3))
                 z (user/churn 0 20000 0)]
    (wat.kernel/println k)                                        ;; 99
    (wat.kernel/println z)
    (wat.kernel/println (wat.core/length (wat.core/nth g 3)))     ;; 3, not 4
    (wat.kernel/println (wat.core/nth (wat.core/nth g 3) 0))      ;; 1
    (wat.kernel/println (wat.core/nth (wat.core/nth g 3)
      (wat.core/- (wat.core/length (wat.core/nth g 3)) 1)))))    ;; 30
