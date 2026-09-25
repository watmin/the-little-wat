;; F-200, as stone 6 met it. The outer `Some`'s value IS the inner `Opt`, which can be the `None` tag;
;; stone 6's "a payload variant is never a unit tag" dropped the tag test and ran `cmp [rax-8],0` on
;; the tag. Stone 6 as struck: signal 11. Interpreter: -2|-2|6.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
(wat.core/defn user/len [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.None {} -1] [:user::Opt.Some {:value v} (wat.string/length (wat.string/concat v "!"))]))
(wat.core/defn user/none [] :- (:user::Opt :- [wat.type/String]) (:user::Opt.None {}))
(wat.core/defn user/some [s :- wat.type/String] :- (:user::Opt :- [wat.type/String]) (:user::Opt.Some {:value s}))
(wat.core/defn user/outer [o :- (:user::Opt.Some :- [(:user::Opt :- [wat.type/String])])] :- wat.type/i64
  (wat.core/let [{:keys [value]} o]
    (wat.core/+ (user/len value) (user/len value))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (:user::Opt.Some {:value (user/none)})
                 b (:user::Opt.Some {:value (user/some "xy")})]
    (wat.kernel/println (user/outer a))
    (wat.kernel/println (user/outer a))
    (wat.kernel/println (user/outer b))))
