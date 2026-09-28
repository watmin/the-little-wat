(wat.core/defrecord :user::Box [n :- wat.type/i64 s :- wat.type/String])
(wat.core/defn user/take [b :- :user::Box] :- wat.type/i64
  (:user::Box/n b))
(wat.core/defn user/pick [c :- wat.type/bool b :- :user::Box] :- wat.type/i64
  (wat.core/+ (user/take (wat.core/if c b (:user::Box :n 7 :s "w")))
              (:user::Box/n b)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (:user::Box :n 3 :s (wat.string/concat "a" "b"))]
    (wat.kernel/println (user/pick true b))
    (wat.kernel/println (:user::Box/s b))))
