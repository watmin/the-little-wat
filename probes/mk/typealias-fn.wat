;; typealias-fn.wat: a keyword-named typealias for a FUNCTION type, used in a Clojure-spelled
;; defn. miniKanren's Goal is a function type. Expected: 7
(wat.core/typealias :u::IntFn [wat.type/i64 :-> wat.type/i64])
(wat.core/defn u/twice [f :- :u::IntFn x :- wat.type/i64] :- wat.type/i64
  (f (f x)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice (wat.core/fn [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 3)) 1)))
