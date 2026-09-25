;; Stone 5b fixture -- {:keys} on a RECORD: the same destructuring, the other aggregate.
(:wat::core::defrecord :user::P [name <- :wat::core::String age <- :wat::core::i64])
(wat.core/defn user/describe [p :- :user::P] :- wat.type/i64
  (wat.core/let [{:keys [name age]} p] (wat.core/+ (wat.string/length name) age)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/describe (:user::P :name "ada" :age 36))))
