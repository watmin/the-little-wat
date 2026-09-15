;; clj-let-kwcalls-mixed.wat (P2): a Clojure-spelled let binding KEYWORD-headed calls of
;; different types (i64, String). Expected: xy
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (:wat::core::+ 1 2)
                 b (:wat::string::concat "x" "y")]
    (wat.kernel/println b)))
