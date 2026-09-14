;; The Little Schemer, chapter 1 (Toys): atoms, lists, and the five primitives
;; car, cdr, cons, null?, eq?, plus atom?. The definitions live in lib/ch01-toys.wat; this
;; program checks them. Our own code and examples, not the book's text.
;;
;; Run: wat books/little-schemer/ch01-toys.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; atom?: symbols and numbers are atoms; lists, including the empty list, are not.
    (wat.test/assert-eq (ls/atom? (wat.core/quote pear)) true)
    (wat.test/assert-eq (ls/atom? (wat.core/quote 7)) true)
    (wat.test/assert-eq (ls/atom? (wat.core/quote (pear plum))) false)
    (wat.test/assert-eq (ls/atom? (ls/empty-list)) false)

    ;; car: the first element, which may itself be a list.
    (wat.test/assert-eq (ls/car (wat.core/quote (pear plum fig))) (wat.core/quote pear))
    (wat.test/assert-eq (ls/car (wat.core/quote ((pear plum) fig))) (wat.core/quote (pear plum)))

    ;; cdr: everything after the first element, always a list.
    (wat.test/assert-eq (ls/cdr (wat.core/quote (pear plum fig))) (wat.core/quote (plum fig)))
    (wat.test/assert-eq (ls/cdr (wat.core/quote (pear))) (ls/empty-list))

    ;; cons: put an S-expression on the front of a list.
    (wat.test/assert-eq (ls/cons (wat.core/quote pear) (wat.core/quote (plum fig)))
                        (wat.core/quote (pear plum fig)))
    (wat.test/assert-eq (ls/cons (wat.core/quote (pear plum)) (wat.core/quote (fig)))
                        (wat.core/quote ((pear plum) fig)))
    (wat.test/assert-eq (ls/cons (wat.core/quote pear) (ls/empty-list))
                        (wat.core/quote (pear)))

    ;; null?: true only for the empty list.
    (wat.test/assert-eq (ls/null? (ls/empty-list)) true)
    (wat.test/assert-eq (ls/null? (wat.core/quote (pear))) false)

    ;; eq?: two atoms are the same atom.
    (wat.test/assert-eq (ls/eq? (wat.core/quote pear) (wat.core/quote pear)) true)
    (wat.test/assert-eq (ls/eq? (wat.core/quote pear) (wat.core/quote plum)) false)

    (wat.kernel/println "little-schemer ch01 toys: ok")))
