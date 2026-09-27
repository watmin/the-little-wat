(wat.core/defrecord :user::Box [n :- wat.type/i64 s :- wat.type/String])
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (:user::Box :n 1 :s (wat.string/concat "a" "b"))
                 c (wat.core/assoc b :n 2)]
    (wat.kernel/println (:user::Box/n b))
    (wat.kernel/println (:user::Box/n c))
    (wat.kernel/println (:user::Box/s b))
    (wat.kernel/println (:user::Box/s c))))
