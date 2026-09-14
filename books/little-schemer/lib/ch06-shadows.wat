;; The Little Schemer, ch 6 (Shadows): the definitions. Arithmetic expressions written as
;; S-expressions and evaluated by value. Then numbers represented as lists of empty lists,
;; the "shadows". Needs lib/ch01-toys.wat and lib/ch04-numbers-games.wat (number?,
;; ast->i64, o+, o*, pow) loaded first. No main here.
;;
;; Operators in the data are the symbols +, * and **. ** stands in for the book's up-arrow,
;; because `^` is EDN metadata syntax. The book's 1st-sub-exp and 2nd-sub-exp are spelled
;; first-sub-exp and second-sub-exp, since a name starting with a digit after the `/` is not
;; a valid Clojure symbol.

(wat.core/defn ls/operator? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/or (ls/eq? x (wat.core/quote +))
               (wat.core/or (ls/eq? x (wat.core/quote *))
                            (ls/eq? x (wat.core/quote **)))))

;; numbered?: is this an arithmetic expression, infix (a op b), all the way down?
(wat.core/defn ls/numbered? [aexp :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/atom? aexp)
    (ls/number? aexp)
    (wat.core/and (ls/numbered? (ls/car aexp))
                  (wat.core/and (ls/operator? (ls/car (ls/cdr aexp)))
                                (ls/numbered? (ls/car (ls/cdr (ls/cdr aexp))))))))

;; value-infix: evaluate an infix expression, e.g. (3 + (4 * 5)).
(wat.core/defn ls/value-infix [nexp :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/atom? nexp)
    (ls/ast->i64 nexp)
    (ls/apply-op (ls/car (ls/cdr nexp))
                 (ls/value-infix (ls/car nexp))
                 (ls/value-infix (ls/car (ls/cdr (ls/cdr nexp)))))))

(wat.core/defn ls/apply-op [op :- :wat::WatAST
                            a  :- wat.type/i64
                            b  :- wat.type/i64]
  :- wat.type/i64
  (wat.core/cond
    ((ls/eq? op (wat.core/quote +)) (ls/o+ a b))
    ((ls/eq? op (wat.core/quote *)) (ls/o* a b))
    (:else (ls/pow a b))))

;; The prefix representation, (op a b), reached only through three helpers. Changing the
;; representation means changing only these three.
(wat.core/defn ls/operator [aexp :- :wat::WatAST] :- :wat::WatAST
  (ls/car aexp))

(wat.core/defn ls/first-sub-exp [aexp :- :wat::WatAST] :- :wat::WatAST
  (ls/car (ls/cdr aexp)))

(wat.core/defn ls/second-sub-exp [aexp :- :wat::WatAST] :- :wat::WatAST
  (ls/car (ls/cdr (ls/cdr aexp))))

(wat.core/defn ls/value [nexp :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/atom? nexp)
    (ls/ast->i64 nexp)
    (ls/apply-op (ls/operator nexp)
                 (ls/value (ls/first-sub-exp nexp))
                 (ls/value (ls/second-sub-exp nexp)))))

;; ── shadows: n is a list of n empty lists ────────────────────────────────────────────

(wat.core/defn ls/sero? [n :- :wat::WatAST] :- wat.type/bool
  (ls/null? n))

(wat.core/defn ls/edd1 [n :- :wat::WatAST] :- :wat::WatAST
  (ls/cons (ls/empty-list) n))

(wat.core/defn ls/zub1 [n :- :wat::WatAST] :- :wat::WatAST
  (ls/cdr n))

(wat.core/defn ls/shadow+ [n :- :wat::WatAST m :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/sero? m) n (ls/edd1 (ls/shadow+ n (ls/zub1 m)))))
