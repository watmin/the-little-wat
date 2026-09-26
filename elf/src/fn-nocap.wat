;; a fn that captures nothing. Interpreter: 42.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [a :- wat.type/i64] :- wat.type/i64 (wat.core/+ a 1))]
    (wat.kernel/println (f 41))))
