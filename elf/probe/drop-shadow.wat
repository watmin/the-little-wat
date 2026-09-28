(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [s (wat.string/concat "out" "er")]
    (wat.core/let [s (wat.string/concat "in" "ner")]
      (wat.core/do
        (wat.kernel/println s)
        (wat.kernel/println s)))
    (wat.kernel/println s)))
