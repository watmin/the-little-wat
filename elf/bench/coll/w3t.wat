(:wat::load-file! "common.wat")
(wat.core/defrecord :user::Box [k :- wat.type/i64])
(wat.core/defrecord :user::Built [box :- :user::Box b :- (wat.core/Vector :- [wat.type/i64])])
(wat.core/defrecord :user::St [b :- (wat.core/Vector :- [wat.type/i64]) t0 :- wat.type/i64])

(wat.core/defn user/chunk [i :- wat.type/i64 goal :- wat.type/i64 box :- :user::Box] :- :user::Box
  (wat.core/if (wat.core/= i goal) box
    (user/chunk (wat.core/+ i 1) goal (wat.core/assoc box :k (wat.core/+ i 1)))))

(wat.core/defn user/batches [k :- wat.type/i64 m :- wat.type/i64 box :- :user::Box st :- :user::St] :- :user::Built
  (wat.core/if (wat.core/= k m) (:user::Built :box box :b (:user::St/b st))
    (wat.core/let [box2 (user/chunk (wat.core/* k 1000) (wat.core/* (wat.core/+ k 1) 1000) box)
                   t1 (wat.os/clock-ns)]
      (user/batches (wat.core/+ k 1) m box2
        (:user::St :b (wat.core/conj (:user::St/b st) (wat.core/- t1 (:user::St/t0 st))) :t0 t1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 built (user/batches 0 (wat.core/quot n 1000) (:user::Box :k 0)
                         (:user::St :b (wat.core/Vector :- [wat.type/i64]) :t0 (wat.os/clock-ns)))]
    (wat.core/do
      (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (:user::Box/k (:user::Built/box built)))))
      (user/tails (:user::Built/b built)))))
