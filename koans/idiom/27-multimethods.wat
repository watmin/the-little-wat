;; koans/idiom/27-multimethods.wat: the multimethod koans (koans/literal/27-multimethods.tsv),
;; each said the way wat says it, or marked as having no wat route. Keyword spelling
;; throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; There are no multimethods. Dispatch on a value is a cond; it is closed, where a multimethod
;; is open to new methods anywhere, and it needs an :else where a multimethod with no default
;; would throw. A map of options with a number and a Vector is a record.
;;
;; Run from the repository root: wat koans/idiom/27-multimethods.wat

(:wat::core::defn :koan::inc [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))
(:wat::core::defn :koan::plus [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))

(:wat::core::defn :koan::describe [k <- :wat::core::keyword] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= k :sun) "hot and bright")
    ((:wat::core::= k :moon) "cold and pale")
    (:else "unknown")))

(:wat::core::defrecord :koan::Opts [chosen <- :wat::core::i64  items <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::defn :koan::handle [kind <- :wat::core::keyword opts <- :koan::Opts] -> :wat::core::i64
  (:wat::core::cond
    ((:wat::core::= kind :pick) (:koan::Opts/chosen opts))
    ((:wat::core::= kind :total) (:wat::core::->> (:koan::Opts/items opts) (:wat::core::mapv :koan::inc) (:wat::core::foldl :koan::plus 0)))
    (:else 0)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:koan::describe :sun) "hot and bright") ; row 1
    (:wat::test::assert-eq (:koan::describe :moon) "cold and pale") ; row 2
    (:wat::test::assert-eq (:koan::handle :pick (:koan::Opts :chosen 7 :items [1 2])) 7) ; row 3
    (:wat::test::assert-eq (:koan::handle :total (:koan::Opts :chosen 7 :items [1 2 3])) 9) ; row 4
    (:wat::kernel::println "koans idiom 27-multimethods: ok")))
