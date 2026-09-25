;; ORCHESTRATOR'S second probe: a tier-1 variant IS its payload, so 5b ALIASES rather than reads. Grow
;; the destructured payload in a callee, then read the variant again: it must be unchanged.
(:wat::core::typealias :user::Row (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/bump [v :- :user::Row] :- wat.type/i64
  (wat.core/length (wat.core/conj v 99)))
(wat.core/defn user/again [s :- (:user::Opt.Some :- [:user::Row])] :- wat.type/i64
  (wat.core/let [{:keys [value]} s] (wat.core/length value)))
(wat.core/defn user/go [s :- (:user::Opt.Some :- [:user::Row])] :- wat.type/i64
  (wat.core/let [{:keys [value]} s
                 n (user/bump value)]
    (wat.core/+ (wat.core/* 10 n) (user/again s))))       ;; 10*4 + 3 = 43
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/go (:user::Opt.Some {:value (wat.core/Vector :- [wat.type/i64] 1 2 3)}))))
