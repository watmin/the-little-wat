;; Loading the same library twice, which a chapter could do by loading two libs that share
;; a dependency. Clojure's require is idempotent. Expected there: 42
(:wat::load-file! "../load/lib.wat")
(:wat::load-file! "../load/lib.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice 21)))
