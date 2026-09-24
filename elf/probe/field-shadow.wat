;; The record-field read site, door-2 shape: a `let` shadows the linear parameter `v` with a
;; field read, so `conj` extends the record's own Vector in place (path 2: it carries arm-own).
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defrecord :user::R [xs <- :user::Row k <- :wat::core::i64])

(wat.core/defn user/grow [v :- :user::Row junk :- :user::Row] :- :user::Row
  (wat.core/conj v 7))

(wat.core/defn user/bump [v :- :user::Row r :- :user::R] :- wat.type/i64
  (wat.core/let [v (:user::R/xs r)]
    (wat.core/length (wat.core/conj v 99))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/Vector :- [wat.type/i64])
                 r (:user::R :xs (user/grow (wat.core/Vector :- [wat.type/i64] 1 2 3)
                                             (wat.core/Vector :- [wat.type/i64] 5))
                             :k 0)
                 a (user/bump e r)]
    (wat.kernel/println a)                                        ;; 5
    (wat.kernel/println (wat.core/length (:user::R/xs r)))))       ;; 4
