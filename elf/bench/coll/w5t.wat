(:wat::load-file! "common.wat")
(wat.core/defrecord :user::Built [s :- wat.type/String b :- (wat.core/Vector :- [wat.type/i64])])
(wat.core/defrecord :user::St [b :- (wat.core/Vector :- [wat.type/i64]) t0 :- wat.type/i64])

(wat.core/defn user/chunk [i :- wat.type/i64 goal :- wat.type/i64 s :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= i goal) s
    (user/chunk (wat.core/+ i 1) goal (wat.string/concat s "a"))))

(wat.core/defn user/batches [k :- wat.type/i64 m :- wat.type/i64 s :- wat.type/String st :- :user::St] :- :user::Built
  (wat.core/if (wat.core/= k m) (:user::Built :s s :b (:user::St/b st))
    (wat.core/let [s2 (user/chunk (wat.core/* k 1000) (wat.core/* (wat.core/+ k 1) 1000) s)
                   t1 (wat.os/clock-ns)]
      (user/batches (wat.core/+ k 1) m s2
        (:user::St :b (wat.core/conj (:user::St/b st) (wat.core/- t1 (:user::St/t0 st))) :t0 t1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 built (user/batches 0 (wat.core/quot n 1000) ""
                         (:user::St :b (wat.core/Vector :- [wat.type/i64]) :t0 (wat.os/clock-ns)))]
    (wat.core/do
      (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (wat.string/length (:user::Built/s built)))))
      (user/tails (:user::Built/b built)))))
