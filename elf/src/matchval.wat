;; The shape a REPL's value takes -- a variant per wat TYPE, not per Lisp datum.
;;
;; `:I64` rather than `:Int`, `:Vec` rather than `:List`: this is a SUBSET of wat, not a
;; different language wearing wat's syntax. The names mirror what wat's types ARE; they do not
;; chase arc 109's `wat.type/str` / `wat.type/vec` spelling, which is a stated DIRECTION that has
;; already reversed once and whose hard half -- Vector against PersistentVector, two live types,
;; ~5,700 sites -- is unresolved. Rename when it lands.
;;
;; The five below are what the compiler can hold today. `:F64` needs SSE, `:Kw` needs keyword,
;; `:Map` needs a map type, `:Fn` needs closures -- the honest backlog, not an oversight.
;;
;; `:Vec` is the load-bearing one: a variant carrying a Vector of the enum's OWN type. It is why
;; this file exists.

(:wat::core::defenum :user::Val :wat::enum::Pure
  :Nil  []
  :I64  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Str  [s <- :wat::core::String]
  :Vec  [xs <- (:wat::core::Vector :- [:user::Val])])

(wat.core/defn user/show [v :- :user::Val] :- wat.type/String
  (:wat::core::match v
    [:user::Val.Nil  {}      "nil"]
    [:user::Val.I64  {:n n}  (wat.i64/to-string n)]
    [:user::Val.Bool {:b b}  (wat.core/if b "true" "false")]
    [:user::Val.Str  {:s s}  s]
    [:user::Val.Vec  {:xs xs}
      (wat.string/concat "[" (wat.string/concat
        (wat.i64/to-string (wat.core/length xs)) "]"))]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/show (:user::Val.Nil {})))
    (wat.kernel/println (user/show (:user::Val.I64 {:n 42})))
    (wat.kernel/println (user/show (:user::Val.Bool {:b true})))
    (wat.kernel/println (user/show (:user::Val.Str {:s "hi"})))
    (wat.kernel/println (user/show (:user::Val.Vec {:xs
      (wat.core/conj (wat.core/conj (wat.core/Vector :- [:user::Val])
        (:user::Val.I64 {:n 1})) (:user::Val.Nil {}))})))))
