;; probes/lint/stdlib.wat: what does wat's linter say about wat's own stdlib?
;;
;; :wat::lint:: is a pure-wat linter — "a rule is (form -> (Vector :- [Finding]))" — and
;; `lint-stdlib` is its surface: form-level findings over the real stdlib, plus deporder's
;; load-order check folded in as rule-zero. It is zero-argument, so the most direct question
;; available is simply to ask it.
;;
;; A linter's entire value is what it catches, so this reports the findings grouped by rule and
;; by severity rather than just a count.
;;
;; Run from the repository root: wat probes/lint/stdlib.wat

(:wat::core::typealias :ls::Findings (:wat::core::Vector :- [:wat::lint::Finding]))
(:wat::core::typealias :ls::Lines (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :ls::render [f <- :wat::lint::Finding] -> :wat::core::String
  (:wat::string::concat
    (:wat::lint::Finding/severity f) "  "
    (:wat::lint::Finding/rule f) "  "
    (:wat::lint::Finding/file f) ":"
    (:wat::i64::to-string (:wat::lint::Finding/line f)) ":"
    (:wat::i64::to-string (:wat::lint::Finding/col f)) "  "
    (:wat::lint::Finding/message f)
    (:wat::core::match (:wat::lint::Finding/fix f)
      [:wat::core::Option.Some {:value _x} "   [auto-fixable]"]
      [:wat::core::Option.None {} ""])))

(:wat::core::defn :ls::print [xs <- :ls::Lines i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i n) nil
    (:wat::core::do (:wat::kernel::println (:wat::core::nth xs i))
                    (:ls::print xs (:wat::core::+ i 1) n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [fs (:wat::lint::lint-stdlib)
                    lines (:wat::core::mapv :ls::render fs)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "findings over the stdlib: "
                                                   (:wat::i64::to-string (:wat::core::length fs))))
      (:ls::print lines 0 (:wat::core::length lines)))))
