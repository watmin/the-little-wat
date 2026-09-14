;; sexp-primitives.wat: Little Schemer ch 1's primitives, on quoted data (WatAST).
;; Expected, one per line:
;;   "list"   "symbol"   true   true   true   true   "list"
;; covering: a quoted list is a list; its first element is a symbol (an atom);
;; car = first; cdr = rest; null? = empty?; eq? = = on atoms; the empty list is a list.
;;
;; The empty list is built as (rest '(a)). Writing it as (quote ()) is refused by the
;; checker (FINDINGS.md, F-004).

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [l      (wat.core/quote (a b c))
                 empty  (wat.core/rest (wat.core/quote (a)))]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind l))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first l)))
      (wat.kernel/println (wat.core/= (wat.core/first l) (wat.core/quote a)))
      (wat.kernel/println (wat.core/= (wat.core/rest l) (wat.core/quote (b c))))
      (wat.kernel/println (wat.core/empty? empty))
      (wat.kernel/println (wat.core/= (wat.core/quote a) (wat.core/quote a)))
      (wat.kernel/println (wat.core/ast-kind empty)))))
