;; F-017 control: the same match, keyword-spelled, inside a Clojure/EDN-spelled defn.
;; Expected: 5
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println
    (:wat::core::match (:wat::core::Result.Ok {:value 5})
      [:wat::core::Result.Ok {:value v} v]
      [:wat::core::Result.Err {:error e} e])))
