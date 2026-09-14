;; The Seasoned Schemer, chapter 14 (Let There Be Names): let, and letcc's escapes from a
;; search (leftmost, rember1*). The definitions live in lib/ch14-let-there-be-names.wat;
;; this program checks them. Our own code and examples, not the book's text.
;;
;; Run: wat books/seasoned-schemer/ch14-let-there-be-names.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch14-let-there-be-names.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; leftmost jumps out with the first atom, skipping empty lists before it
    (wat.test/assert-eq (ss/leftmost '(((()) pear) plum)) 'pear)
    (wat.test/assert-eq (ss/leftmost '((() (fig)) plum)) 'fig)
    (wat.test/assert-eq (ss/leftmost '(() (()))) '())

    ;; rember1*: only the leftmost plum, at any depth; no plum leaves the list as it was
    (wat.test/assert-eq (ss/rember1* 'plum '((pear (plum fig)) plum)) '((pear (fig)) plum))
    (wat.test/assert-eq (ss/rember1* 'plum '(pear plum plum)) '(pear plum))
    (wat.test/assert-eq (ss/rember1* 'kiwi '(pear (plum))) '(pear (plum)))

    ;; depth*
    (wat.test/assert-eq (ss/depth* '(pear (plum (fig)))) 3)
    (wat.test/assert-eq (ss/depth* '(pear plum)) 1)
    (wat.test/assert-eq (ss/depth* '()) 1)

    (wat.kernel/println "seasoned-schemer ch14 let-there-be-names: ok")))
