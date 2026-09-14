;; Clojure's when. Expected in Clojure: prints "yes"
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/when (wat.core/= 1 1) (wat.kernel/println "yes")))
