;; load-file! in the Clojure/EDN spelling. Every chapter uses (:wat::load-file! ...).
;; Expected: 42
(wat/load-file! "../load/lib.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice 21)))
