;; probes/doctest/equals-on-enum.wat: does :wat::core::= refuse two IDENTICAL enum values?
;;
;; :wat::doctest::verify-examples died in wat's own source (wat/doctest.wat:118) on
;;
;;   :wat::core::=: expected matching comparable pair, got wat::core::Enum `:wat::edn::Validation.Valid`
;;
;; That line is `(:wat::core::= got want)` — the doctest runner comparing an example's result
;; against its `#=>`. For a PASSING example those two are the same value, so this may be broader
;; than F-019, which is about a variant keeping its NARROWED type so two DIFFERENT variants of
;; one enum won't compare. If `=` refuses two identical enum values outright, every doctest whose
;; result is an enum is unrunnable, whatever it claims.
;;
;; Three questions, narrowest first:
;;   1. does `=` compare two identical variants of a user enum?
;;   2. does it compare two identical variants held at the ENUM's type (P-006's widening route)?
;;   3. does it compare two identical variants of a STDLIB enum, the case that actually died?
;;
;; Its own file per question would be ideal, but `=` returning bool means a refusal is a startup
;; or runtime error either way, so the narrowest one goes first and the rest follow if it passes.
;;
;; Run from the repository root: wat probes/doctest/equals-on-enum.wat

(:wat::core::defenum :eq::Colour :wat::enum::Pure
  :Red []
  :Blue [])

;; the widening route (P-006): a helper whose declared return type is the ENUM
(:wat::core::defn :eq::red [] -> :eq::Colour (:eq::Colour.Red {}))

(:wat::core::defn :eq::show [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " (:wat::core::if b "true" "false"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; 2. two identical variants, both WIDENED to the enum type
    (:eq::show "widened Red = widened Red" (:wat::core::= (:eq::red) (:eq::red)))
    ;; 1. two identical variants written inline, each keeping its narrowed type
    (:eq::show "inline Red = inline Red" (:wat::core::= (:eq::Colour.Red {}) (:eq::Colour.Red {})))))
