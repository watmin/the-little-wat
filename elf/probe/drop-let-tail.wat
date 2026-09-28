;; excursus 008 stone 3a round 7 (R16), the `let`-tail variant: a `let`'s BODY (its last form)
;; is the value of the whole `let`, exactly as an `if` arm is the value of the whole `if`. `b`
;; is bound outside, passed through an unrelated `let` untouched, and read again afterwards.
(wat.core/defrecord :user::Box [n :- wat.type/i64 s :- wat.type/String])
(wat.core/defn user/take [b :- :user::Box] :- wat.type/i64
  (:user::Box/n b))
(wat.core/defn user/pick [b :- :user::Box] :- wat.type/i64
  (wat.core/+ (user/take (wat.core/let [z 1] b))
              (:user::Box/n b)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (:user::Box :n 3 :s (wat.string/concat "a" "b"))]
    (wat.kernel/println (user/pick b))
    (wat.kernel/println (:user::Box/s b))))
