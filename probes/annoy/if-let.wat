;; Clojure's if-let over an Option-returning lookup. Expected in Clojure: 1
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/if-let [x (wat.core/get {:a 1} :a)] x 0)))
