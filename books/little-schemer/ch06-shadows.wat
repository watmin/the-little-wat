;; The Little Schemer, chapter 6 (Shadows): arithmetic expressions as S-expressions, and
;; numbers as lists of empty lists. The definitions live in lib/ch06-shadows.wat; this
;; program checks them. Our own code and examples, not the book's text.
;;
;; Expected values that contain empty lists use the KEYWORD spelling of quote.
;; (wat.core/quote (() ())) is refused; (:wat::core::quote (() ())) works (FINDINGS.md, F-004).
;;
;; Run: wat books/little-schemer/ch06-shadows.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch02-do-it-again.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch06-shadows.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [two   (ls/edd1 (ls/edd1 (ls/empty-list)))
                 three (ls/edd1 two)]
    (wat.core/do
      ;; numbered?: a well-formed infix expression, all the way down
      (wat.test/assert-eq (ls/numbered? (wat.core/quote (3 + (4 * 5)))) true)
      (wat.test/assert-eq (ls/numbered? (wat.core/quote (3 + pear))) false)
      (wat.test/assert-eq (ls/numbered? (wat.core/quote 5)) true)

      ;; value, infix and then prefix through the three helpers
      (wat.test/assert-eq (ls/value-infix (wat.core/quote (3 + (4 * 5)))) 23)
      (wat.test/assert-eq (ls/value-infix (wat.core/quote ((2 ** 3) + 1))) 9)
      (wat.test/assert-eq (ls/value (wat.core/quote (+ 3 (* 4 5)))) 23)
      (wat.test/assert-eq (ls/value (wat.core/quote (** 2 (+ 1 2)))) 8)

      ;; shadows: n is n empty lists
      (wat.test/assert-eq two (:wat::core::quote (() ())))
      (wat.test/assert-eq (ls/sero? (ls/empty-list)) true)
      (wat.test/assert-eq (ls/zub1 three) two)
      (wat.test/assert-eq (ls/shadow+ two three) (:wat::core::quote (() () () () ())))
      ;; ...and why they are only shadows: a list of empty lists is not a lat
      (wat.test/assert-eq (ls/lat? three) false)

      (wat.kernel/println "little-schemer ch06 shadows: ok"))))
