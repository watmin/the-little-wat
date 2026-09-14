;; quote-empty-nested.wat: is an empty list refused only as the whole quoted form,
;; (quote ()), or anywhere inside quoted data too? Little Schemer uses lists that contain
;; the empty list, e.g. (() () ()) and (a () b).
;; Expected if nested () is fine: "list" then 3.

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [l (wat.core/quote (a () b))]
    (wat.core/do
      (wat.kernel/println (wat.core/ast-kind (wat.core/first (wat.core/rest l))))
      (wat.kernel/println (wat.core/length l)))))
