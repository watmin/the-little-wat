;; smoke-clojure-defn.wat: the Clojure/EDN spelling wat is moving to. Symbol heads,
;; `:-` type annotations, `wat.type/` types, a namespaced symbol for the name. Code in
;; this repo is written this way wherever the substrate accepts it, so the coming syntax
;; migration costs nothing here.
;;
;; The deftest stays in the keyword spelling on purpose: this file tests the defn
;; spelling alone. smoke-clojure-deftest.wat tests the deftest spelling separately.

(wat.core/defn u/some-fn
  [x :- wat.type/i64
   y :- wat.type/i64]
  :- wat.type/i64
  (wat.core/+ x y))

(:wat::test::deftest :friedman::smoke::clojure-defn
  (:wat::test::assert-eq (u/some-fn 40 2) 42))
