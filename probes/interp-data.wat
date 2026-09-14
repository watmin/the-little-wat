;; interp-data.wat: data the Little Schemer ch 10 interpreter will read. Inside quoted data:
;; is `true` a bool node, and does a nested (quote x) form stay plain data (a list whose
;; head is the symbol quote)?
;; Expected: "bool"  "list"  "symbol"  true
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [prog (wat.core/quote (car (quote (pear plum)) true))
                 inner (wat.core/first (wat.core/rest prog))]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest (wat.core/rest prog)))))
      (wat.kernel/println (wat.core/ast-kind inner))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first inner)))
      (wat.kernel/println (wat.core/= (wat.core/first inner) (wat.core/quote quote))))))
