;; The Seasoned Schemer, ch 16 (Ready, Set, Bang!): the definitions. Remembering with set!:
;; the last food, every food, and a memo table that stops deep from recomputing. State lives
;; in Cells (lib/cell.wat, FINDINGS.md C-014).
;;
;; Not ported: the chapter's Y-bang, recursion by set!-ing a name to a function that calls
;; through that name. A function cannot be a service's durable state or ride in a request
;; (R-002). Recursion without names is Y (Little Schemer ch 9, C-010).
;;
;; Needs lib/cell.wat, ../little-schemer/lib/ch01-toys.wat and
;; ../little-schemer/lib/ch04-numbers-games.wat (sub1, zero?, ast->i64, length) loaded
;; first. No main here.

;; sweet-toothL remembers the last food in the shared Cell last.
(wat.core/defn ss/sweet-toothL [last :- :ss::CellRef food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_put (ss/cell-put! last food)]
    (wat.core/quasiquote (~food cake))))

;; sweet-toothR remembers every food, most recent first, in the shared Cell ingredients.
(wat.core/defn ss/sweet-toothR [ingredients :- :ss::CellRef food :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_put (ss/cell-put! ingredients (ls/cons food (ss/cell-get ingredients)))]
    (wat.core/quasiquote (~food cake))))

;; deep: pizza wrapped in m lists.
(wat.core/defn ss/deep [m :- wat.type/i64] :- :wat::WatAST
  (wat.core/if (ls/zero? m)
    'pizza
    (ls/cons (ss/deep (ls/sub1 m)) '())))

;; ── the memo: two parallel lists, ns (the numbers asked for, as number nodes) and rs
;; (their answers), each kept in a Cell ──────────────────────────────────────────────

(wat.core/defn ss/remembered? [n :- wat.type/i64 ns :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((ls/null? ns) false)
    ((wat.core/= (ls/ast->i64 (ls/car ns)) n) true)
    (:else (ss/remembered? n (ls/cdr ns)))))

;; find: the answer remembered for n
(wat.core/defn ss/find [n :- wat.type/i64 ns :- :wat::WatAST rs :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (wat.core/= (ls/ast->i64 (ls/car ns)) n)
    (ls/car rs)
    (ss/find n (ls/cdr ns) (ls/cdr rs))))

;; deepM: deep, memoized. A repeated question is answered from the memo; each new answer is
;; recorded, including the ones its own recursion computes on the way.
(wat.core/defn ss/deepM [ns :- :ss::CellRef rs :- :ss::CellRef m :- wat.type/i64] :- :wat::WatAST
  (wat.core/if (ss/remembered? m (ss/cell-get ns))
    (ss/find m (ss/cell-get ns) (ss/cell-get rs))
    (wat.core/let [result (wat.core/if (ls/zero? m)
                            'pizza
                            (ls/cons (ss/deepM ns rs (ls/sub1 m)) '()))
                   _ns    (ss/cell-put! ns (ls/cons (wat.core/quasiquote ~m) (ss/cell-get ns)))
                   _rs    (ss/cell-put! rs (ls/cons result (ss/cell-get rs)))]
      result)))

;; make-deepM: a memoized deep whose memo is private to it, the book's final shape.
(wat.core/defn ss/make-deepM [] :- [wat.type/i64 :-> :wat::WatAST]
  (wat.core/let [ns (ss/new-cell '())
                 rs (ss/new-cell '())]
    (wat.core/fn [m :- wat.type/i64] :- :wat::WatAST
      (ss/deepM ns rs m))))
