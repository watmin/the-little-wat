;; probes/lint/catches-what.wat: does the linter catch code that is deliberately bad?
;;
;; probes/lint/stdlib.wat found 99 findings over wat's own stdlib, ALL of one rule
;; (concat-abuse). The linter has a second rule — rule-nested-if-=-ladder-form, which fires when
;; an if/= chain over one variable collects three or more literals, the shape that should be a
;; match — and it produced nothing. Either the stdlib contains no ladders, or the rule does not
;; fire.
;;
;; A linter's whole value is what it catches, so this hands it source that is unambiguously both:
;; a three-literal if/= ladder, and a concat interleaving literals with values.
;;
;; Run from the repository root: wat probes/lint/catches-what.wat

(:wat::core::defn :lc::render [f <- :wat::lint::Finding] -> :wat::core::String
  (:wat::string::concat
    (:wat::lint::Finding/severity f) "  " (:wat::lint::Finding/rule f) "  line "
    (:wat::i64::to-string (:wat::lint::Finding/line f)) "  "
    (:wat::lint::Finding/message f)))

(:wat::core::defn :lc::print [xs <- (:wat::core::Vector :- [:wat::core::String]) i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i n) nil
    (:wat::core::do (:wat::kernel::println (:wat::core::nth xs i))
                    (:lc::print xs (:wat::core::+ i 1) n))))

(:wat::core::defn :lc::lint [label <- :wat::core::String src <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [fs (:wat::lint::lint-file (:wat::source::File :path label :source src))
                    lines (:wat::core::mapv :lc::render fs)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "== " label " => "
                                                   (:wat::i64::to-string (:wat::core::length fs)) " finding(s)"))
      (:lc::print lines 0 (:wat::core::length lines)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; a three-literal if/= ladder over one variable — exactly what the ladder rule describes
    (:lc::lint "ladder.wat"
      "(:wat::core::defn :bad::grade [x <- :wat::core::String] -> :wat::core::i64
  (:wat::core::if (:wat::core::= x \"a\") 1
    (:wat::core::if (:wat::core::= x \"b\") 2
      (:wat::core::if (:wat::core::= x \"c\") 3 0))))")
    ;; a concat interleaving a literal with a value — what fired 99 times on the stdlib
    (:lc::lint "concat.wat"
      "(:wat::core::defn :bad::greet [n <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat \"hello \" n \"!\"))")
    ;; both at once
    (:lc::lint "both.wat"
      "(:wat::core::defn :bad::both [x <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::= x \"a\") (:wat::string::concat \"got \" x \"!\")
    (:wat::core::if (:wat::core::= x \"b\") \"b\"
      (:wat::core::if (:wat::core::= x \"c\") \"c\" \"z\"))))")
    ;; clean code — must produce nothing
    (:lc::lint "clean.wat"
      "(:wat::core::defn :ok::add [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ a b))")))
