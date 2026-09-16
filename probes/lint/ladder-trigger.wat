;; probes/lint/ladder-trigger.wat: what does the nested-if-=-ladder rule actually fire on?
;;
;; probes/lint/catches-what.wat handed the linter a three-literal if/= ladder returning 1/2/3 and
;; got NOTHING, while concat-abuse fired correctly. The rule's own comments explain why: the
;; chain must bottom out in `false` — "if else is a non-false non-ladder, the chain breaks". It is
;; a MEMBERSHIP rule, and it recommends (contains? (HashSet …) var).
;;
;; This pins the trigger with positive, negative and threshold cases, so "the rule never fires"
;; is not reported when the truth is "the rule is narrower than I assumed".
;;
;; Run from the repository root: wat probes/lint/ladder-trigger.wat

(:wat::core::defn :lv::render [f <- :wat::lint::Finding] -> :wat::core::String
  (:wat::string::concat (:wat::lint::Finding/rule f) ": " (:wat::lint::Finding/message f)))
(:wat::core::defn :lv::lint [label <- :wat::core::String src <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [fs (:wat::lint::lint-file (:wat::source::File :path label :source src))]
    (:wat::kernel::println
      (:wat::string::concat label " => " (:wat::i64::to-string (:wat::core::length fs)) " finding(s)  "
        (:wat::core::if (:wat::core::empty? fs) "" (:lv::render (:wat::core::first fs)))))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; boolean ladder, 3 literals, ends in false — the shape the comments describe
    (:lv::lint "bool-3-false"
      "(:wat::core::defn :b::f [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::= x \"a\") true
    (:wat::core::if (:wat::core::= x \"b\") true
      (:wat::core::if (:wat::core::= x \"c\") true false))))")
    ;; 4 literals, ends in false
    (:lv::lint "bool-4-false"
      "(:wat::core::defn :b::f [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::= x \"a\") true
    (:wat::core::if (:wat::core::= x \"b\") true
      (:wat::core::if (:wat::core::= x \"c\") true
        (:wat::core::if (:wat::core::= x \"d\") true false)))))")
    ;; 2 literals, ends in false — below the stated threshold, must NOT fire
    (:lv::lint "bool-2-false"
      "(:wat::core::defn :b::f [x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::= x \"a\") true
    (:wat::core::if (:wat::core::= x \"b\") true false)))")
    ;; 3 literals over a keyword, ends in false
    (:lv::lint "kw-3-false"
      "(:wat::core::defn :b::f [x <- :wat::core::keyword] -> :wat::core::bool
  (:wat::core::if (:wat::core::= x :a) true
    (:wat::core::if (:wat::core::= x :b) true
      (:wat::core::if (:wat::core::= x :c) true false))))")
    ;; 3 literals, value-returning, ends in 0 — the case that produced nothing before
    (:lv::lint "value-3-zero"
      "(:wat::core::defn :b::f [x <- :wat::core::String] -> :wat::core::i64
  (:wat::core::if (:wat::core::= x \"a\") 1
    (:wat::core::if (:wat::core::= x \"b\") 2
      (:wat::core::if (:wat::core::= x \"c\") 3 0))))")))
