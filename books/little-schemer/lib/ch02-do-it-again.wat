;; The Little Schemer, ch 2 (Do It, Do It Again, and Again, and Again): the definitions.
;; Recursion over a list with cond: lat? (is every element an atom?) and member? (is this
;; atom in the list?). Needs lib/ch01-toys.wat loaded first. No main here.

(wat.core/defn ls/lat? [l :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/null? l) true)
    ((ls/atom? (ls/car l)) (ls/lat? (ls/cdr l)))
    (:else false)))

(wat.core/defn ls/member? [a   :- :wat::WatAST
                           lat :- :wat::WatAST]
  :- wat.type/bool
  (wat.core/cond
    ((ls/null? lat) false)
    (:else (wat.core/or (ls/eq? (ls/car lat) a)
                        (ls/member? a (ls/cdr lat))))))
