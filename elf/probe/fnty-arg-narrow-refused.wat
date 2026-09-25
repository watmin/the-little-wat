;; F-202. A function taking a VARIANT passed where one taking the PARENT is wanted. wat refuses it
;; (arguments are contravariant). The native compiler at beb513d COMPILED it and answered 1.
;; It must be refused: tools/probe.sh answers COMPILE-FAILED, naming the argument.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; a function that takes a VARIANT, passed where a function taking the PARENT is wanted
(wat.core/defn user/onsome [o :- (:user::Opt.Some :- [wat.type/i64])] :- wat.type/i64 1)
(wat.core/defn user/apply [f :- [(:user::Opt :- [wat.type/i64]) :-> wat.type/i64]] :- wat.type/i64
  (f (:user::Opt.None {})))
(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (user/apply user/onsome)))
