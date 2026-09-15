;; clj-let-body-unchecked.wat (P4): a Clojure-spelled let whose body adds 1 to the String it
;; bound. The keyword let refuses this at startup (kw-let-body-checked.wat). Here?
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a "x"]
    (wat.kernel/println (:wat::core::+ a 1))))
