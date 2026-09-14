;; smoke-clojure-deftest.wat: is a deftest spelled entirely in Clojure/EDN symbols
;; discovered and run? If discovery recognises only the keyword head, this file adds zero
;; tests with no error. The check is the count: `cargo test` must list
;; friedman.smoke/clojure-deftest, not merely come back green.

(wat.core/defn u/some-other-fn
  [x :- wat.type/i64
   y :- wat.type/i64]
  :- wat.type/i64
  (wat.core/+ x y))

(wat.test/deftest friedman.smoke/clojure-deftest
  (wat.test/assert-eq (u/some-other-fn 40 2) 42))
