;; smoke.wat — proves exactly one thing: this sibling crate builds against ../wat-rs and
;; its deftests are discovered and run. Nothing Friedman-shaped depends on anything until
;; this is green.

(:wat::test::deftest :friedman::smoke::one-plus-one
  (:wat::test::assert-eq (:wat::core::+ 1 1) 2))
