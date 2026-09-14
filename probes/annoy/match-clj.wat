;; F-017 repro: the Clojure/EDN-spelled match over a Result. Its arms are [pattern body]
;; vectors, the same arms wat-rs uses with the keyword spelling everywhere.
;; Expected once fixed: 5
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (wat.core/match (:wat::core::Result.Ok {:value 5})
      [:wat::core::Result.Ok {:value v} v]
      [:wat::core::Result.Err {:error e} e])))
