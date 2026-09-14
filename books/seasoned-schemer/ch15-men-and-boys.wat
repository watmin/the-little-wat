;; The Seasoned Schemer, chapter 15 (The Difference Between Men and Boys...): set!, ported
;; to Cells on services. The definitions live in lib/ch15-men-and-boys.wat and lib/cell.wat;
;; this program checks them. Our own code and examples, not the book's text.
;;
;; Run: wat books/seasoned-schemer/ch15-men-and-boys.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/cell.wat")
(:wat::load-file! "lib/ch15-men-and-boys.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [x    (ss/new-cell 'pizza)
                 food (ss/new-cell 'none)
                 omnivore (ss/make-omnivore)
                 gobbler  (ss/make-gobbler)
                 diner    (ss/make-remembering-diner 'soup)]
    (wat.core/do
      ;; the shared x: read, then set
      (wat.test/assert-eq (ss/gourmet x 'onion) '(onion pizza))
      (wat.test/assert-eq (ss/gourmand x 'potato) '(potato potato))
      (wat.test/assert-eq (ss/cell-get x) 'potato)
      (wat.test/assert-eq (ss/dinerR x 'onion) '(milkshake onion))
      (wat.test/assert-eq (ss/cell-get x) 'onion)

      ;; private x's: omnivore and gobbler each set their own; the shared x is untouched
      (wat.test/assert-eq (omnivore 'bouillabaisse) '(bouillabaisse bouillabaisse))
      (wat.test/assert-eq (gobbler 'gumbo) '(gumbo gumbo))
      (wat.test/assert-eq (ss/cell-get x) 'onion)

      ;; nibbler's x is new on every call
      (wat.test/assert-eq (ss/nibbler 'cheerio) '(cheerio cheerio))
      (wat.test/assert-eq (ss/nibbler 'bagel) '(bagel bagel))

      ;; persistence you can see: the diner answers (food previous-food)
      (wat.test/assert-eq (diner 'pizza) '(pizza soup))
      (wat.test/assert-eq (diner 'pasta) '(pasta pizza))

      ;; glutton sets the shared food; chez-nous swaps x and food
      (wat.test/assert-eq (ss/glutton food 'garlic) '(more garlic more garlic))
      (wat.test/assert-eq (ss/cell-get food) 'garlic)
      (ss/chez-nous x food)
      (wat.test/assert-eq (ss/cell-get x) 'garlic)
      (wat.test/assert-eq (ss/cell-get food) 'onion)

      (wat.kernel/println "seasoned-schemer ch15 men-and-boys: ok"))))
