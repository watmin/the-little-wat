;; The Little Schemer, ch 5 ("Oh My Gawd": It's Full of Stars): the definitions.
;; The starred functions recur into nested lists, i.e. into the car as well as the cdr.
;; Then S-expression equality (eqlist? and equal?, which call each other) and a rember
;; that removes any S-expression. Needs lib/ch01-toys.wat and lib/ch04-numbers-games.wat
;; (eqan?, add1) loaded first. No main here.

;; rember*: remove every occurrence of the atom a, at any depth.
(wat.core/defn ls/rember* [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eqan? (ls/car l) a)
       (ls/rember* a (ls/cdr l))
       (ls/cons (ls/car l) (ls/rember* a (ls/cdr l)))))
    (:else (ls/cons (ls/rember* a (ls/car l)) (ls/rember* a (ls/cdr l))))))

;; insertR*: new after every old, at any depth.
(wat.core/defn ls/insertR* [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eqan? (ls/car l) old)
       (ls/cons old (ls/cons new (ls/insertR* new old (ls/cdr l))))
       (ls/cons (ls/car l) (ls/insertR* new old (ls/cdr l)))))
    (:else (ls/cons (ls/insertR* new old (ls/car l)) (ls/insertR* new old (ls/cdr l))))))

;; occur*: how many times the atom a appears, at any depth.
(wat.core/defn ls/occur* [a :- :wat::WatAST l :- :wat::WatAST] :- wat.type/i64
  (wat.core/cond
    ((ls/null? l) 0)
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eqan? (ls/car l) a)
       (ls/add1 (ls/occur* a (ls/cdr l)))
       (ls/occur* a (ls/cdr l))))
    (:else (wat.core/+ (ls/occur* a (ls/car l)) (ls/occur* a (ls/cdr l))))))

;; subst*: new for every old, at any depth.
(wat.core/defn ls/subst* [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eqan? (ls/car l) old)
       (ls/cons new (ls/subst* new old (ls/cdr l)))
       (ls/cons (ls/car l) (ls/subst* new old (ls/cdr l)))))
    (:else (ls/cons (ls/subst* new old (ls/car l)) (ls/subst* new old (ls/cdr l))))))

;; insertL*: new before every old, at any depth.
(wat.core/defn ls/insertL* [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eqan? (ls/car l) old)
       (ls/cons new (ls/cons old (ls/insertL* new old (ls/cdr l))))
       (ls/cons (ls/car l) (ls/insertL* new old (ls/cdr l)))))
    (:else (ls/cons (ls/insertL* new old (ls/car l)) (ls/insertL* new old (ls/cdr l))))))

;; member*: does the atom a appear anywhere?
(wat.core/defn ls/member* [a :- :wat::WatAST l :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/null? l) false)
    ((ls/atom? (ls/car l))
     (wat.core/or (ls/eqan? (ls/car l) a) (ls/member* a (ls/cdr l))))
    (:else (wat.core/or (ls/member* a (ls/car l)) (ls/member* a (ls/cdr l))))))

;; leftmost: the first atom, descending into cars. Only for lists with no empty lists.
(wat.core/defn ls/leftmost [l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/atom? (ls/car l))
    (ls/car l)
    (ls/leftmost (ls/car l))))

;; eqlist? and equal? call each other: two lists are equal when their elements are, and
;; two S-expressions are equal when they are equal atoms or equal lists. eqlist? refers
;; to equal?, which is defined after it.
(wat.core/defn ls/eqlist? [l1 :- :wat::WatAST l2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((wat.core/and (ls/null? l1) (ls/null? l2)) true)
    ((wat.core/or (ls/null? l1) (ls/null? l2)) false)
    (:else (wat.core/and (ls/equal? (ls/car l1) (ls/car l2))
                         (ls/eqlist? (ls/cdr l1) (ls/cdr l2))))))

(wat.core/defn ls/equal? [s1 :- :wat::WatAST s2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((wat.core/and (ls/atom? s1) (ls/atom? s2)) (ls/eqan? s1 s2))
    ((wat.core/or (ls/atom? s1) (ls/atom? s2)) false)
    (:else (ls/eqlist? s1 s2))))

;; rember with equal?: remove the first occurrence of ANY S-expression s, not just an
;; atom. Named rember-equal so it can be loaded beside ch 3's rember.
(wat.core/defn ls/rember-equal [s :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/equal? (ls/car l) s) (ls/cdr l))
    (:else (ls/cons (ls/car l) (ls/rember-equal s (ls/cdr l))))))
