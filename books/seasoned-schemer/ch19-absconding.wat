;; The Seasoned Schemer, chapter 19 (Absconding with the Jewels): saved continuations and
;; generators, ported to continuation-passing style and lazy streams. The definitions live
;; in lib/ch19-absconding.wat; this program checks them. Our own code and examples.
;;
;; Run: wat books/seasoned-schemer/ch19-absconding.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/counter.wat")
(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch19-absconding.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [toppings (ss/toppings 3)]
    (wat.core/do
      ;; the saved rest-of-computation, reused with different fillings
      (wat.test/assert-eq (toppings 'cake) '(((cake))))
      (wat.test/assert-eq (toppings 'mozzarella) '(((mozzarella))))

      ;; THE DIVERGENCE (R-003). In the book, calling the continuation toppings inside a cons
      ;; abandons the cons, and the answer is (((cake))). A wat function returns to its
      ;; caller, so the cons happens: one more level.
      (wat.test/assert-eq (ls/cons (toppings 'cake) '()) '((((cake)))))

      ;; the generator: the first leaf, however deep
      (ss/counter-reset! :ss::visits 0)
      (wat.test/assert-eq (ss/get-first '(((pear)) plum (fig (kiwi)))) 'pear)
      ;; ...and laziness, measured: asking for the first leaf produced exactly one leaf
      (wat.test/assert-eq (ss/counter-get :ss::visits) 1)
      (wat.test/assert-eq (ss/get-first '(() (()))) '())

      ;; two equal leaves in a row, across list boundaries
      (wat.test/assert-eq (ss/two-in-a-row*? '((pear) plum (plum fig))) true)
      (wat.test/assert-eq (ss/two-in-a-row*? '(pear (plum ((fig))) fig)) true)
      (wat.test/assert-eq (ss/two-in-a-row*? '(pear (plum fig) (kiwi))) false)

      ;; the whole walk, when every leaf is needed: 4 leaves, 4 units of leaf work
      (ss/counter-reset! :ss::visits 0)
      (wat.test/assert-eq (ss/two-in-a-row*? '(pear (plum fig) (kiwi))) false)
      (wat.test/assert-eq (ss/counter-get :ss::visits) 4)

      (wat.kernel/println "seasoned-schemer ch19 absconding: ok"))))
