;; The Little Schemer, ch 1 (Toys): the definitions. Loaded by ../ch01-toys.wat and by
;; every later chapter that builds on them. No main here.
;;
;; S-expressions are wat's own quoted forms (:wat::WatAST). A quoted list is a list; every
;; other node (symbol, number, string, …) is an atom. The empty list cannot be written as
;; '() (FINDINGS.md, F-004), so it is built once, as the rest of a one-element list. Types
;; use the keyword :wat::WatAST because the Clojure/EDN spelling has none yet (F-005).

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
