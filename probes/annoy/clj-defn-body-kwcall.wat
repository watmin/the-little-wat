;; F-014 scope: a KEYWORD-spelled wrong-arity core call inside a CLOJURE-spelled defn body.
;; If this is only caught at runtime, Clojure-spelled definitions switch off checking of
;; their bodies. Startup (exit 3) or runtime (exit 1)?
(wat.core/defn u/f [x :- wat.type/i64] :- wat.type/i64
  (:wat::core::length [1 2] [3]))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/f 1)))
