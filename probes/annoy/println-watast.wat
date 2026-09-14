;; Printing a quoted S-expression. Expected: something like (pear (plum 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/quote (pear (plum 1)))))
