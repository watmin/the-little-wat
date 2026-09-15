;; amp-symbol.wat: does a bare & inside quoted data read as a symbol? It is used to show an
;; improper tail, (a b & _0), where the book prints (a b . _0). Also: is _0 a symbol?
;; Expected: "symbol" "symbol" 4
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [l '(a b & _0)]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest (wat.core/rest l)))))
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest (wat.core/rest (wat.core/rest l))))))
      (wat.kernel/println (wat.core/length l)))))
