;; A keyword as a function on a map. In Clojure (:a {:a 1}) is 1. Expected in Clojure: 1
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (:a {:a 1})))
