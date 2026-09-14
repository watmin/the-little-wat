;; quote-empty-symbol.wat: the F-004 repro in its plainest form. The whole quoted form is
;; the empty list, in the Clojure/EDN spelling of quote. Refused at startup today; compare
;; quote-empty-keyword.wat, which passes with the keyword spelling.
;; Expected once fixed: "list" then true
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [e (wat.core/quote ())]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind e))
      (wat.kernel/println (wat.core/empty? e)))))
