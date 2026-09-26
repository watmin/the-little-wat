;; a closure captures a record parameter and uses it only through one field. The bare name at
;; the closure node is a retain, so the parameter is not scalarised down to that field.
(:wat::core::defrecord :user::Box [n <- :wat::core::i64])
(wat.core/defn user/use [b :- :user::Box] :- wat.type/i64
  (wat.core/let [f (wat.core/fn [x :- wat.type/i64] :- wat.type/i64
                    (wat.core/+ x (:user::Box/n b)))]
    (f 2)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/use (:user::Box :n 40))))
