;; excursus 008 3b-3: two types recursive through EACH OTHER (A holds a B, B holds an A),
;; built 100,000 deep, summed and dropped, twenty times. Its cycle is {henum A, henum B}.
;; The sum is a SELF tail loop on purpose: a mutual tail call is not a loop natively (F-211),
;; and this fixture measures the drop, not that.
(:wat::core::defenum :user::A :wat::enum::Pure
  :AEnd []
  :AStep [k <- :wat::core::i64 nxt <- :user::B])
(:wat::core::defenum :user::B :wat::enum::Pure
  :BEnd []
  :BStep [k <- :wat::core::i64 nxt <- :user::A])

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 acc :- :user::A] :- :user::A
  (wat.core/if (wat.core/>= i n) acc
    (user/build (wat.core/+ i 2) n
      (:user::A.AStep {:k i :nxt (:user::B.BStep {:k (wat.core/+ i 1) :nxt acc})}))))

(wat.core/defn user/suma [a :- :user::A acc :- wat.type/i64] :- wat.type/i64
  (:wat::core::match a
    [:user::A.AEnd {} acc]
    [:user::A.AStep {:k k :nxt nxt}
      (:wat::core::match nxt
        [:user::B.BEnd {} (wat.core/+ acc k)]
        [:user::B.BStep {:k k2 :nxt nxt2} (user/suma nxt2 (wat.core/+ acc (wat.core/+ k k2)))])]))

(wat.core/defn user/rounds [r :- wat.type/i64 acc :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= r 0) acc
    (user/rounds (wat.core/- r 1)
      (wat.core/+ acc (user/suma (user/build 0 100000 (:user::A.AEnd {})) 0)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (user/rounds 20 0))))
