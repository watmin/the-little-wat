(:wat::load-file! "common.wat")
(wat.core/defrecord :user::Got [v :- (wat.core/Vector :- [wat.type/i64])
                                vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])])
(wat.core/defrecord :user::Built [vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
                                  b :- (wat.core/Vector :- [wat.type/i64])])
(wat.core/defrecord :user::St [b :- (wat.core/Vector :- [wat.type/i64]) t0 :- wat.type/i64])

(wat.core/defn user/chunk [i :- wat.type/i64 goal :- wat.type/i64
                           v :- (wat.core/Vector :- [wat.type/i64])
                           vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])] :- :user::Got
  (wat.core/if (wat.core/= i goal) (:user::Got :v v :vs vs)
    (wat.core/let [v2 (wat.core/conj v i)]
      (user/chunk (wat.core/+ i 1) goal v2 (wat.core/conj vs v2)))))

(wat.core/defn user/batches [k :- wat.type/i64 m :- wat.type/i64
                             v :- (wat.core/Vector :- [wat.type/i64])
                             vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
                             st :- :user::St] :- :user::Built
  (wat.core/if (wat.core/= k m) (:user::Built :vs vs :b (:user::St/b st))
    (wat.core/let [got (user/chunk (wat.core/* k 1000) (wat.core/* (wat.core/+ k 1) 1000) v vs)
                   t1 (wat.os/clock-ns)]
      (user/batches (wat.core/+ k 1) m (:user::Got/v got) (:user::Got/vs got)
        (:user::St :b (wat.core/conj (:user::St/b st) (wat.core/- t1 (:user::St/t0 st))) :t0 t1)))))

(wat.core/defn user/readall [vs :- (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
                             i :- wat.type/i64 n :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i n) acc
    (user/readall vs (wat.core/+ i 1) n (wat.core/+ acc (wat.core/nth (wat.core/nth vs i) i)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 built (user/batches 0 (wat.core/quot n 1000)
                         (wat.core/Vector :- [wat.type/i64])
                         (wat.core/Vector :- [(wat.core/Vector :- [wat.type/i64])])
                         (:user::St :b (wat.core/Vector :- [wat.type/i64]) :t0 (wat.os/clock-ns)))]
    (wat.core/do
      (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (user/readall (:user::Built/vs built) 0 n 0))))
      (user/tails (:user::Built/b built)))))
