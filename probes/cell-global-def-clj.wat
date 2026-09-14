;; cell-global-def-clj.wat: cell-global-def.wat with the Clojure/EDN-spelled def.
;; Expected if it works: pizza then onion
(:wat::load-file! "../books/seasoned-schemer/lib/cell.wat")
(wat.core/def u/x (ss/new-cell 'pizza))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (ss/cell-get u/x))
    (ss/cell-put! u/x 'onion)
    (wat.kernel/println (ss/cell-get u/x))))
