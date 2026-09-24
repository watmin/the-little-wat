;; A GENERIC enum as a bare parameter type, `(o :- :user::Opt)`. The language accepts it and infers
;; `T` per call. The native compiler read `T` as i64 (`:c::variant-ftys` answered "i64" for an
;; uninstantiated `:T`), so `v` -- a Vector -- was never shared, and the first `user/bump` grew it
;; in place under the second. Interpreter `44`; HEAD printed a POINTER, exit 0. Excursus 002
;; stone 4 refuses the bare generic type at compile time, naming it.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))
(wat.core/defn user/grow [o :- :user::Opt] :- wat.type/i64
  (:wat::core::match o
    [:user::Opt.Some {:value v} (wat.core/+ (user/bump v) (wat.core/* 10 (user/bump v)))]
    [:user::Opt.None {}         0]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/grow (:user::Opt.Some {:value (wat.core/Vector :- [wat.type/i64] 1 2 3)}))))
