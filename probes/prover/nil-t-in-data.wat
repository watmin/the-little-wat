;; nil-t-in-data.wat: J-Bob's false is the symbol nil and its true the symbol t. wat has a nil
;; literal. How do nil, t and 0 read inside quoted data? Prints ast-kind of each.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [d '(nil t 0 (quote nil))]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind (wat.core/first d)))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest d))))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest (wat.core/rest d)))))
      (wat.kernel/println (wat.core/first (wat.core/rest (wat.core/rest (wat.core/rest d)))))
      (wat.kernel/println (wat.core/= (wat.core/first d) 'nil)))))
