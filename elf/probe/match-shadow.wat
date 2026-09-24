;; The match payload read site, door-2 shape: the payload binding `xs` shadows the linear
;; parameter `xs`, so `conj` treats a Vector still held by the subject as owned. (Passing the
;; binding on as an argument would share it -- it is a Symbol -- so door 1 cannot reach here.)
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::B :wat::enum::Pure
  :None []
  :One  [n <- :wat::core::i64]
  :Many [xs <- :user::Row])

(wat.core/defn user/grow [v :- :user::Row junk :- :user::Row] :- :user::Row
  (wat.core/conj v 7))

(wat.core/defn user/size [b :- :user::B] :- wat.type/i64
  (:wat::core::match b
    [:user::B.None {} 0]
    [:user::B.One {:n n} 1]
    [:user::B.Many {:xs xs} (wat.core/length xs)]))

(wat.core/defn user/poke [xs :- :user::Row b :- :user::B] :- wat.type/i64
  (:wat::core::match b
    [:user::B.None {} 0]
    [:user::B.One {:n n} n]
    [:user::B.Many {:xs xs} (wat.core/length (wat.core/conj xs 99))]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 b (:user::B.Many {:xs (user/grow (wat.core/Vector :- [wat.type/i64] 1 2 3)
                                                  (wat.core/Vector :- [wat.type/i64] 5))})
                 k (user/poke e b)]
    (wat.kernel/println k)                                        ;; 5
    (wat.kernel/println (user/size b))))                          ;; 4
