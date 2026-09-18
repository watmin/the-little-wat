(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/* (wat.core/- 10 3) -4))
  (wat.kernel/println (wat.core/+ 1 2 3 4 5))
  (wat.kernel/println (wat.core/* (wat.core/+ 100 23) (wat.core/- 0 1)))
  (wat.kernel/println 0))
