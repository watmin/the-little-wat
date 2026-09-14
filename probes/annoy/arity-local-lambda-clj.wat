;; F-014 mechanism check. A LOCAL lambda (let-bound), called with the wrong arity, in the
;; Clojure/EDN spelling. check.rs:6214-6272 infers a symbol head as a value; a let-bound fn
;; infers to a Fn type, so its arity SHOULD be checked at startup. Named functions
;; (u/add1, wat.core/length) are not.
;; Expected per the code: caught at STARTUP (exit 3), callee "(value head)".
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [f (wat.core/fn [x :- wat.type/i64] :- wat.type/i64 x)]
    (wat.kernel/println (f 1 2))))
