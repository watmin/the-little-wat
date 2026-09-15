;; clj-let-symcalls-mixed.wat (P3): the same with SYMBOL-headed calls. Expected: xy
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [a (wat.core/+ 1 2)
                 b (wat.string/concat "x" "y")]
    (wat.kernel/println b)))
