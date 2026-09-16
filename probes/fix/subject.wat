;; probes/fix/subject.wat — the input to probes/fix/convert.wat.
;; Chosen to exercise all four of fix-source's documented rules at once:
;;   strip-if   an `if` carrying a `-> :T` return annotation
;;   head-rule  `::`-keyword call heads
;;   arrow-rule bare `<-` / `->` annotation arrows
;;   type-rule  keywords in type position, including a bracketed one
(:wat::core::defn :subj::classify [n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::> n 0) "positive" "non-positive"))

(:wat::core::defn :subj::total [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::+ a b))
    0 xs))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:subj::classify 5))
    (:wat::kernel::println (:subj::classify -5))
    (:wat::kernel::println (:subj::total (:wat::core::Vector :- [:wat::core::i64] 1 2 3 4)))))
