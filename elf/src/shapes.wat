(:wat::core::defenum :user::Shape :wat::enum::Pure
  :Dot  []
  :Line [len <- :wat::core::i64]
  :Box  [w <- :wat::core::i64  h <- :wat::core::i64])

(wat.core/defn user/area [s :- :user::Shape] :- wat.type/i64
  (:wat::core::match s
    [:user::Shape.Dot  {}            0]
    [:user::Shape.Line {:len n}      n]
    [:user::Shape.Box  {:w a :h b}   (wat.core/* a b)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/area (:user::Shape.Dot {})))
    (wat.kernel/println (user/area (:user::Shape.Line {:len 7})))
    (wat.kernel/println (user/area (:user::Shape.Box {:w 6 :h 7})))))
