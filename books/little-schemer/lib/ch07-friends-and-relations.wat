;; The Little Schemer, ch 7 (Friends and Relations): the definitions. Sets are lats with no
;; repeats. Pairs are lists of exactly two S-expressions. Relations are sets of pairs.
;; Needs lib/ch01-toys.wat, lib/ch02-do-it-again.wat (member?) and
;; lib/ch03-cons-the-magnificent.wat (multirember, firsts) loaded first. No main here.

;; ── sets ─────────────────────────────────────────────────────────────────────────────

(wat.core/defn ls/set? [lat :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/null? lat) true)
    ((ls/member? (ls/car lat) (ls/cdr lat)) false)
    (:else (ls/set? (ls/cdr lat)))))

;; makeset: keep each atom's first occurrence, removing its later repeats.
(wat.core/defn ls/makeset [lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? lat)
    (ls/empty-list)
    (ls/cons (ls/car lat) (ls/makeset (ls/multirember (ls/car lat) (ls/cdr lat))))))

(wat.core/defn ls/subset? [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/null? set1)
    true
    (wat.core/and (ls/member? (ls/car set1) set2) (ls/subset? (ls/cdr set1) set2))))

(wat.core/defn ls/eqset? [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/and (ls/subset? set1 set2) (ls/subset? set2 set1)))

(wat.core/defn ls/intersect? [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/null? set1)
    false
    (wat.core/or (ls/member? (ls/car set1) set2) (ls/intersect? (ls/cdr set1) set2))))

(wat.core/defn ls/intersect [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? set1) (ls/empty-list))
    ((ls/member? (ls/car set1) set2) (ls/cons (ls/car set1) (ls/intersect (ls/cdr set1) set2)))
    (:else (ls/intersect (ls/cdr set1) set2))))

(wat.core/defn ls/union [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? set1) set2)
    ((ls/member? (ls/car set1) set2) (ls/union (ls/cdr set1) set2))
    (:else (ls/cons (ls/car set1) (ls/union (ls/cdr set1) set2)))))

;; difference: the atoms of set1 that are not in set2.
(wat.core/defn ls/difference [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? set1) (ls/empty-list))
    ((ls/member? (ls/car set1) set2) (ls/difference (ls/cdr set1) set2))
    (:else (ls/cons (ls/car set1) (ls/difference (ls/cdr set1) set2)))))

;; intersectall: the intersection of a non-empty list of sets.
(wat.core/defn ls/intersectall [l-set :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? (ls/cdr l-set))
    (ls/car l-set)
    (ls/intersect (ls/car l-set) (ls/intersectall (ls/cdr l-set)))))

;; ── pairs and relations ──────────────────────────────────────────────────────────────

(wat.core/defn ls/a-pair? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/atom? x) false)
    ((ls/null? x) false)
    ((ls/null? (ls/cdr x)) false)
    ((ls/null? (ls/cdr (ls/cdr x))) true)
    (:else false)))

;; first / second / build: the pair's parts, and a pair from two parts. These are ls/first
;; and ls/second, distinct from wat.core/first and wat.core/second.
(wat.core/defn ls/first [p :- :wat::WatAST] :- :wat::WatAST
  (ls/car p))

(wat.core/defn ls/second [p :- :wat::WatAST] :- :wat::WatAST
  (ls/car (ls/cdr p)))

(wat.core/defn ls/build [s1 :- :wat::WatAST s2 :- :wat::WatAST] :- :wat::WatAST
  (ls/cons s1 (ls/cons s2 (ls/empty-list))))

;; fun?: a relation is a function when no first element repeats.
(wat.core/defn ls/fun? [rel :- :wat::WatAST] :- wat.type/bool
  (ls/set? (ls/firsts rel)))

(wat.core/defn ls/revpair [pair :- :wat::WatAST] :- :wat::WatAST
  (ls/build (ls/second pair) (ls/first pair)))

(wat.core/defn ls/revrel [rel :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? rel)
    (ls/empty-list)
    (ls/cons (ls/revpair (ls/car rel)) (ls/revrel (ls/cdr rel)))))

(wat.core/defn ls/seconds [rel :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? rel)
    (ls/empty-list)
    (ls/cons (ls/second (ls/car rel)) (ls/seconds (ls/cdr rel)))))

;; one-to-one?: a function whose reverse is also a function, i.e. no second repeats.
(wat.core/defn ls/one-to-one? [fun :- :wat::WatAST] :- wat.type/bool
  (ls/set? (ls/seconds fun)))
