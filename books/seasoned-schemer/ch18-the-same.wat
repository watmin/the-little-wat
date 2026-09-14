;; The Seasoned Schemer, chapter 18 (We Change, Therefore We Are the Same!): mutable lists,
;; shared structure and cycles, on an Arena. The definitions live in lib/ch18-the-same.wat
;; and lib/arena.wat; this program checks them. Our own code and examples, not the book's.
;;
;; Run: wat books/seasoned-schemer/ch18-the-same.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/arena.wat")
(:wat::load-file! "lib/ch18-the-same.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a    (ss/new-arena)
                 l    (ss/lots a 3)
                 tail (ss/lots a 2)
                 l1   (ss/kons! a 'apple tail)
                 l2   (ss/kons! a 'pear tail)]
    (wat.core/do
      ;; building and measuring
      (wat.test/assert-eq (ss/lenkth a l) 3)
      (wat.test/assert-eq (ss/kar a l) 'egg)
      (wat.test/assert-eq (ss/kdr a (ss/last-kons a l)) -1)

      ;; copying versus changing: add-at-end leaves l alone; add-at-end-too changes it
      (wat.test/assert-eq (ss/lenkth a (ss/add-at-end a l)) 4)
      (wat.test/assert-eq (ss/lenkth a l) 3)
      (wat.test/assert-eq (ss/lenkth a (ss/add-at-end-too a l)) 4)
      (wat.test/assert-eq (ss/lenkth a l) 4)

      ;; same?, by mutation, and the list is put back afterwards
      (wat.test/assert-eq (ss/same? a l l) true)
      (wat.test/assert-eq (ss/same? a l (ss/kdr a l)) false)
      (wat.test/assert-eq (ss/lenkth a l) 4)

      ;; shared structure: l1 and l2 share one tail, so growing l1 grows l2 as well
      (wat.test/assert-eq (ss/lenkth a l2) 3)
      (ss/add-at-end-too a l1)
      (wat.test/assert-eq (ss/lenkth a l1) 4)
      (wat.test/assert-eq (ss/lenkth a l2) 4)

      ;; finite-lenkth: 4, then -1 once the last node points back at the first
      (wat.test/assert-eq (ss/finite-lenkth a l) 4)
      (ss/set-kdr! a (ss/last-kons a l) l)
      (wat.test/assert-eq (ss/finite-lenkth a l) -1)

      (wat.kernel/println "seasoned-schemer ch18 the-same: ok"))))
