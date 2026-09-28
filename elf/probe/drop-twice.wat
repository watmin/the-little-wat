(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64] 1 2 3)]
    (wat.core/do
      (wat.kernel/println (wat.i64/to-string (wat.core/length v)))
      (wat.kernel/println (wat.i64/to-string (wat.core/length v))))))
