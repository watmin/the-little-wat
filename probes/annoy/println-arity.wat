;; println given two arguments. Caught at startup (exit 3) or only at runtime (exit 1)?
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println 1 2))
