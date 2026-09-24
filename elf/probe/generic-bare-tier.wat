;; A GENERIC enum as a bare parameter type, `(o :- :user::Opt)`, handed `(Opt.Some {:value "xy"})`.
;; At `T = String` that value is TIER 1 -- the pointer itself; the callee, reading `T` as i64,
;; compiled its match for TIER 3 -- a heap block with the tag in slot 0. Interpreter `1|0`; HEAD
;; printed `4197723|0`, exit 0 -- F-194 in a new place: one value, two tiers. Excursus 002 stone 4
;; refuses the bare generic type at compile time, naming it.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/slen [o :- :user::Opt] :- wat.type/i64
  (:wat::core::match o
    [:user::Opt.Some {:value v} 1]
    [:user::Opt.None {}         0]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [o (:user::Opt.Some {:value "xy"})]
    (wat.kernel/println (user/slen o))
    (wat.kernel/println (user/slen (:user::Opt.None {})))))
