;; What does #_ read as? Printed inside quoted data. EDN says (a c).
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/quote (a #_b c))))
