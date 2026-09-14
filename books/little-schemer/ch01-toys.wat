;; The Little Schemer, chapter 1 (Toys): atoms, lists, and the five primitives
;; car, cdr, cons, null?, eq?, plus atom?.
;;
;; S-expressions are wat's own quoted forms (WatAST). A quoted list is a list; every
;; other node (symbol, number, string, …) is an atom. Our own code and examples, not
;; the book's text.
;;
;; The empty list cannot be written as '() in wat (FINDINGS.md, F-004), so it is built
;; once, as the rest of a one-element list.
;;
;; Run: wat books/little-schemer/ch01-toys.wat   (exit 0 and a final "ok" line = pass)

(wat.core/defn ls/empty-list [] :- :wat::WatAST
  (wat.core/rest (wat.core/quote (x))))

(wat.core/defn ls/atom? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/not (wat.core/= (wat.core/ast-kind x) "list")))

(wat.core/defn ls/car [l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/first l))

(wat.core/defn ls/cdr [l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/rest l))

(wat.core/defn ls/cons [a :- :wat::WatAST
                        l :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/quasiquote (~a ~@l)))

(wat.core/defn ls/null? [l :- :wat::WatAST] :- wat.type/bool
  (wat.core/empty? l))

(wat.core/defn ls/eq? [a :- :wat::WatAST
                       b :- :wat::WatAST]
  :- wat.type/bool
  (wat.core/= a b))

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
