(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.i64/to-string (wat.string/length (wat.string/concat "ab" "cd")))))
