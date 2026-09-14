;; The Little Schemer, chapter 9 (...and Again, and Again, and Again): partial functions,
;; and Y. The definitions live in lib/ch09-and-again.wat; this program checks the ones that
;; finish (eternity, shuffle on a pair of pairs, and will-stop? are not run). Our own code
;; and examples, not the book's text.
;;
;; Run: wat books/little-schemer/ch09-and-again.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch02-do-it-again.wat")
(:wat::load-file! "lib/ch03-cons-the-magnificent.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch06-shadows.wat")
(:wat::load-file! "lib/ch07-friends-and-relations.wat")
(:wat::load-file! "lib/ch08-lambda-the-ultimate.wat")
(:wat::load-file! "lib/ch09-and-again.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [len (ls/length-Y)]
    (wat.core/do
      ;; looking: 3 -> 2 -> fig, found; 2 -> plum, not fig
      (wat.test/assert-eq (ls/looking (wat.core/quote fig) (wat.core/quote (3 fig 2))) true)
      (wat.test/assert-eq (ls/looking (wat.core/quote fig) (wat.core/quote (2 plum fig))) false)

      ;; pairs of pairs
      (wat.test/assert-eq (ls/shift (wat.core/quote ((pear plum) fig))) (wat.core/quote (pear (plum fig))))
      (wat.test/assert-eq (ls/align (wat.core/quote ((pear plum) fig))) (wat.core/quote (pear (plum fig))))
      (wat.test/assert-eq (ls/length* (wat.core/quote ((pear plum) fig))) 3)
      (wat.test/assert-eq (ls/weight* (wat.core/quote ((pear plum) fig))) 7)
      (wat.test/assert-eq (ls/weight* (wat.core/quote (pear (plum fig)))) 5)
      (wat.test/assert-eq (ls/shuffle (wat.core/quote (pear (plum fig)))) (wat.core/quote (pear (plum fig))))
      (wat.test/assert-eq (ls/shuffle (wat.core/quote ((pear plum) fig))) (wat.core/quote (fig (pear plum))))

      ;; Collatz (always answers 1 when it finishes) and Ackermann
      (wat.test/assert-eq (ls/C 1) 1)
      (wat.test/assert-eq (ls/C 6) 1)
      (wat.test/assert-eq (ls/A 1 0) 2)
      (wat.test/assert-eq (ls/A 1 1) 3)
      (wat.test/assert-eq (ls/A 2 2) 7)

      ;; Y: length with no function naming itself
      (wat.test/assert-eq (len (wat.core/quote (pear plum fig kiwi))) 4)
      (wat.test/assert-eq (len (ls/empty-list)) 0)

      (wat.kernel/println "little-schemer ch09 and-again: ok"))))
