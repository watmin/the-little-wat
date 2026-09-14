;; main-symbol.wat: fully Clojure/EDN. Does the `wat` binary find a main spelled
;; `user/main`? Expected: 42, or a diagnostic naming the missing entry point.

(wat.core/defn u/add
  [x :- wat.type/i64
   y :- wat.type/i64]
  :- wat.type/i64
  (wat.core/+ x y))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/add 40 2)))
