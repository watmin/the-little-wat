;; Clojure's + takes any number of arguments. Expected in Clojure: 6
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/+ 1 2 3)))
