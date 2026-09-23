;; The share at site A happens only when `c` is true. Site B is after the merge. A set keyed
;; on the binding, with no invalidation at joins, records A's key and elides B -- so on the
;; FALSE path `s` was never shared, keeps its owned marker, and `hold` mutates it in place.
(wat.core/defn user/hold [s :- wat.type/String] :- wat.type/String
  (wat.string/concat s "!"))

(wat.core/defn user/f [a :- wat.type/String c :- wat.type/bool] :- wat.type/String
  (wat.core/let [s (wat.string/concat a "1")]
    (wat.core/let [x (wat.core/if c (user/hold s) "-")]
      (wat.core/let [y (user/hold s)]
        (wat.string/concat s (wat.string/concat x y))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (user/f "z" true))
    (wat.kernel/println (user/f "z" false))))
