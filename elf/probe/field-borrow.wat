;; The record-field read site: a Vector read out of a record by its accessor, passed to a
;; function that conjs its linear parameter. The field's Vector was made by `vec_conj_own`'s
;; COPYING path, so it carries `:c::arm-own` and has room -- path 2 writes in place.
;; `bumps` is also the scalarised shape: its record parameter is used only through one field.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defrecord :user::R [xs <- :user::Row k <- :wat::core::i64])

(wat.core/defn user/grow [v :- :user::Row junk :- :user::Row] :- :user::Row
  (wat.core/conj v 7))

(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))

(wat.core/defn user/bumps [r :- :user::R] :- wat.type/i64
  (user/bump (:user::R/xs r)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [r (:user::R :xs (user/grow (wat.core/Vector :- [wat.type/i64] 1 2 3)
                                             (wat.core/Vector :- [wat.type/i64] 5))
                             :k 0)
                 a (user/bump (:user::R/xs r))
                 b (user/bumps r)]
    (wat.kernel/println a)                                        ;; 5
    (wat.kernel/println b)                                        ;; 5
    (wat.kernel/println (wat.core/length (:user::R/xs r)))))       ;; 4
