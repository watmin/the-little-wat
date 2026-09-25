;; Stone 5b fixture -- the builder's own shape: a VARIANT parameter destructured with {:keys}, no match.
;; Interpreter: 3 3 0.
(:wat::core::defenum :user::Opt :- [T] :wat::enum::Pure
  :Some [value <- :T]
  :None [])
;; wants the VARIANT: only a Some may come in, so one arm is the whole match
(wat.core/defn user/needs-some [s :- (:user::Opt.Some :- [wat.type/String])] :- wat.type/i64
  (wat.core/let [{:keys [value]} s] (wat.string/length value)))
;; wants the PARENT: either variant may come in, so both must be handled
(wat.core/defn user/needs-opt [o :- (:user::Opt :- [wat.type/String])] :- wat.type/i64
  (:wat::core::match o [:user::Opt.Some {:value v} (wat.string/length v)] [:user::Opt.None {} 0]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/needs-some (:user::Opt.Some {:value "abc"})))   ;; a Some where a Some is wanted
    (wat.kernel/println (user/needs-opt  (:user::Opt.Some {:value "abc"})))   ;; a Some where an Opt is wanted
    (wat.kernel/println (user/needs-opt  (:user::Opt.None {})))))            ;; a None where an Opt is wanted
