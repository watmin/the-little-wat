(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [v (wat.core/Vector :- [wat.type/i64])]
    (wat.kernel/println (wat.i64/to-string
      (wat.core/if false (wat.core/length v) 3)))))
