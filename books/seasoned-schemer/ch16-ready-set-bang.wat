;; The Seasoned Schemer, chapter 16 (Ready, Set, Bang!): remembering with set!, ported to
;; Cells, and a memo table that provably stops recomputation. The definitions live in
;; lib/ch16-ready-set-bang.wat; this program checks them. Our own code and examples.
;;
;; Run: wat books/seasoned-schemer/ch16-ready-set-bang.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/cell.wat")
(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch16-ready-set-bang.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [last        (ss/new-cell 'angelfood)
                 ingredients (ss/new-cell '())
                 ns          (ss/new-cell '())
                 rs          (ss/new-cell '())
                 deepM       (ss/make-deepM)]
    (wat.core/do
      ;; the last food, and every food
      (wat.test/assert-eq (ss/sweet-toothL last 'chocolate) '(chocolate cake))
      (wat.test/assert-eq (ss/cell-get last) 'chocolate)
      (wat.test/assert-eq (ss/sweet-toothL last 'fruit) '(fruit cake))
      (wat.test/assert-eq (ss/cell-get last) 'fruit)
      (wat.test/assert-eq (ss/sweet-toothR ingredients 'chocolate) '(chocolate cake))
      (wat.test/assert-eq (ss/sweet-toothR ingredients 'fruit) '(fruit cake))
      (wat.test/assert-eq (ss/cell-get ingredients) '(fruit chocolate))

      ;; deep, plain
      (wat.test/assert-eq (ss/deep 0) 'pizza)
      (wat.test/assert-eq (ss/deep 3) '(((pizza))))

      ;; deepM: the answers, and proof the memo works. The memo size is the number of
      ;; remembered questions.
      (wat.test/assert-eq (ss/deepM ns rs 3) '(((pizza))))
      (wat.test/assert-eq (ls/length (ss/cell-get ns)) 4)
      (wat.test/assert-eq (ss/deepM ns rs 5) '(((((pizza))))))
      (wat.test/assert-eq (ls/length (ss/cell-get ns)) 6)
      (wat.test/assert-eq (ss/deepM ns rs 3) '(((pizza))))
      (wat.test/assert-eq (ls/length (ss/cell-get ns)) 6)

      ;; the private-memo version
      (wat.test/assert-eq (deepM 2) '((pizza)))
      (wat.test/assert-eq (deepM 2) '((pizza)))

      (wat.kernel/println "seasoned-schemer ch16 ready-set-bang: ok"))))
