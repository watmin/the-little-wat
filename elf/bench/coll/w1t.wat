(:wat::load-file! "common.wat")
(wat.core/defrecord :user::Built [v :- (wat.core/Vector :- [wat.type/i64])
                                  b :- (wat.core/Vector :- [wat.type/i64])])
(wat.core/defrecord :user::St [b :- (wat.core/Vector :- [wat.type/i64]) t0 :- wat.type/i64])

;; One call site, the same shape as the untimed loop, so the vector stays linear.
(wat.core/defn user/chunk [i :- wat.type/i64 goal :- wat.type/i64
                           v :- (wat.core/Vector :- [wat.type/i64])] :- (wat.core/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/= i goal) v
    (user/chunk (wat.core/+ i 1) goal (wat.core/conj v i))))

(wat.core/defn user/batches [k :- wat.type/i64 m :- wat.type/i64
                             v :- (wat.core/Vector :- [wat.type/i64]) st :- :user::St] :- :user::Built
  (wat.core/if (wat.core/= k m) (:user::Built :v v :b (:user::St/b st))
    (wat.core/let [v2 (user/chunk (wat.core/* k 1000) (wat.core/* (wat.core/+ k 1) 1000) v)
                   t1 (wat.os/clock-ns)]
      (user/batches (wat.core/+ k 1) m v2
        (:user::St :b (wat.core/conj (:user::St/b st) (wat.core/- t1 (:user::St/t0 st))) :t0 t1)))))

(wat.core/defn user/sum [v :- (wat.core/Vector :- [wat.type/i64]) i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/sum v (wat.core/+ i 1) n (wat.core/+ acc (wat.core/nth v i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 built (user/batches 0 (wat.core/quot n 1000) (wat.core/Vector :- [wat.type/i64])
                         (:user::St :b (wat.core/Vector :- [wat.type/i64]) :t0 (wat.os/clock-ns)))]
    (wat.core/do
      (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (user/sum (:user::Built/v built) 0 n 0))))
      (user/tails (:user::Built/b built)))))
