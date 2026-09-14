;; The Little Schemer, chapter 8 (Lambda the Ultimate): functions passed, returned, curried,
;; and used as collectors. The definitions live in lib/ch08-lambda-the-ultimate.wat; this
;; program checks them. Our own code and examples, not the book's text.
;;
;; Expected values that contain empty lists use the keyword spelling of quote (F-004).
;;
;; Run: wat books/little-schemer/ch08-lambda-the-ultimate.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch06-shadows.wat")
(:wat::load-file! "lib/ch08-lambda-the-ultimate.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [pear? (ls/eq?-c (wat.core/quote pear))
                 same-number? (wat.core/fn [x :- :wat::WatAST y :- :wat::WatAST] :- wat.type/bool
                                (ls/eqan? x y))]
    (wat.core/do
      ;; passing a test in
      (wat.test/assert-eq (ls/rember-f ls/eq? (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear fig)))
      (wat.test/assert-eq (ls/rember-f same-number? (wat.core/quote 5) (wat.core/quote (6 5 7)))
                          (wat.core/quote (6 7)))

      ;; getting a function back
      (wat.test/assert-eq (pear? (wat.core/quote pear)) true)
      (wat.test/assert-eq (pear? (wat.core/quote plum)) false)
      (wat.test/assert-eq ((ls/rember-c ls/eq?) (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear fig)))

      ;; one insert, four behaviours
      (wat.test/assert-eq ((ls/insert-g ls/seqL) (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear x plum fig)))
      (wat.test/assert-eq ((ls/insert-g ls/seqR) (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear plum x fig)))
      (wat.test/assert-eq ((ls/insert-g ls/seqS) (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear x fig)))
      (wat.test/assert-eq ((ls/insert-g ls/seqrem) (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig)))
                          (wat.core/quote (pear fig)))

      ;; an operator symbol becomes a function
      (wat.test/assert-eq (ls/value-f (wat.core/quote (+ 3 (* 4 5)))) 23)
      (wat.test/assert-eq (ls/value-f (wat.core/quote (** 2 3))) 8)

      ;; the multi- forms
      (wat.test/assert-eq ((ls/multirember-f ls/eq?) (wat.core/quote plum) (wat.core/quote (plum pear plum)))
                          (wat.core/quote (pear)))
      (wat.test/assert-eq (ls/multiremberT (ls/eq?-c (wat.core/quote plum)) (wat.core/quote (plum pear plum fig)))
                          (wat.core/quote (pear fig)))
      (wat.test/assert-eq (ls/multiinsertLR (wat.core/quote x) (wat.core/quote plum) (wat.core/quote fig)
                                            (wat.core/quote (plum pear fig)))
                          (wat.core/quote (x plum pear fig x)))

      ;; collectors: same walk, the collector decides the answer (bool, i64, a list)
      (wat.test/assert-eq (ls/multirember-co (wat.core/quote plum) (wat.core/quote (pear plum fig))
                            (wat.core/fn [x :- :wat::WatAST y :- :wat::WatAST] :- wat.type/bool (ls/null? y)))
                          false)
      (wat.test/assert-eq (ls/multirember-co (wat.core/quote plum) (wat.core/quote (pear fig))
                            (wat.core/fn [x :- :wat::WatAST y :- :wat::WatAST] :- wat.type/bool (ls/null? y)))
                          true)
      (wat.test/assert-eq (ls/multirember-co (wat.core/quote plum) (wat.core/quote (pear plum fig plum))
                            (wat.core/fn [x :- :wat::WatAST y :- :wat::WatAST] :- wat.type/i64 (ls/length x)))
                          2)
      (wat.test/assert-eq (ls/multiinsertLR-co (wat.core/quote x) (wat.core/quote plum) (wat.core/quote fig)
                                               (wat.core/quote (plum pear fig plum))
                            (wat.core/fn [nl :- :wat::WatAST L :- wat.type/i64 R :- wat.type/i64] :- wat.type/i64
                              (wat.core/+ (wat.core/* L 10) R)))
                          21)

      ;; evens at any depth, and the collector that also multiplies the evens and adds the odds
      (wat.test/assert-eq (ls/evens-only* (wat.core/quote ((5 2 4) 3 6 ((7) 8) 1)))
                          (:wat::core::quote ((2 4) 6 (() 8))))
      (wat.test/assert-eq (ls/evens-only*-co (wat.core/quote ((5 2 4) 3 6 ((7) 8) 1))
                            (wat.core/fn [newl :- :wat::WatAST p :- wat.type/i64 s :- wat.type/i64] :- :wat::WatAST
                              (wat.core/quasiquote (~s ~p ~@newl))))
                          (:wat::core::quote (16 384 (2 4) 6 (() 8))))

      (wat.kernel/println "little-schemer ch08 lambda-the-ultimate: ok"))))
