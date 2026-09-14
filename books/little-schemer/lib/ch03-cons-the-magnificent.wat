;; The Little Schemer, ch 3 (Cons the Magnificent): the definitions. Building new lists
;; with cons while recurring: remove, collect, insert and substitute. Needs
;; lib/ch01-toys.wat loaded first. No main here.

;; rember: remove the first occurrence of the atom a.
(wat.core/defn ls/rember [a   :- :wat::WatAST
                          lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) a) (ls/cdr lat))
    (:else (ls/cons (ls/car lat) (ls/rember a (ls/cdr lat))))))

;; firsts: the first element of each (non-empty) list in l.
(wat.core/defn ls/firsts [l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    (:else (ls/cons (ls/car (ls/car l)) (ls/firsts (ls/cdr l))))))

;; insertR: put new just after the first old.
(wat.core/defn ls/insertR [new :- :wat::WatAST
                           old :- :wat::WatAST
                           lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old) (ls/cons old (ls/cons new (ls/cdr lat))))
    (:else (ls/cons (ls/car lat) (ls/insertR new old (ls/cdr lat))))))

;; insertL: put new just before the first old.
(wat.core/defn ls/insertL [new :- :wat::WatAST
                           old :- :wat::WatAST
                           lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old) (ls/cons new lat))
    (:else (ls/cons (ls/car lat) (ls/insertL new old (ls/cdr lat))))))

;; subst: replace the first old with new.
(wat.core/defn ls/subst [new :- :wat::WatAST
                         old :- :wat::WatAST
                         lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old) (ls/cons new (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ls/subst new old (ls/cdr lat))))))

;; subst2: replace whichever of o1 or o2 comes first with new.
(wat.core/defn ls/subst2 [new :- :wat::WatAST
                          o1  :- :wat::WatAST
                          o2  :- :wat::WatAST
                          lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((wat.core/or (ls/eq? (ls/car lat) o1) (ls/eq? (ls/car lat) o2))
     (ls/cons new (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ls/subst2 new o1 o2 (ls/cdr lat))))))

;; multirember: remove every occurrence of a.
(wat.core/defn ls/multirember [a   :- :wat::WatAST
                               lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) a) (ls/multirember a (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ls/multirember a (ls/cdr lat))))))

;; multiinsertR: put new after every old.
(wat.core/defn ls/multiinsertR [new :- :wat::WatAST
                                old :- :wat::WatAST
                                lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old)
     (ls/cons old (ls/cons new (ls/multiinsertR new old (ls/cdr lat)))))
    (:else (ls/cons (ls/car lat) (ls/multiinsertR new old (ls/cdr lat))))))

;; multiinsertL: put new before every old.
(wat.core/defn ls/multiinsertL [new :- :wat::WatAST
                                old :- :wat::WatAST
                                lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old)
     (ls/cons new (ls/cons old (ls/multiinsertL new old (ls/cdr lat)))))
    (:else (ls/cons (ls/car lat) (ls/multiinsertL new old (ls/cdr lat))))))

;; multisubst: replace every old with new.
(wat.core/defn ls/multisubst [new :- :wat::WatAST
                              old :- :wat::WatAST
                              lat :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) old) (ls/cons new (ls/multisubst new old (ls/cdr lat))))
    (:else (ls/cons (ls/car lat) (ls/multisubst new old (ls/cdr lat))))))
