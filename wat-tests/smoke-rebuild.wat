;; smoke-rebuild.wat: the control for build.rs (FINDINGS.md, F-002). This file was ADDED
;; after the crate was built, with nothing else touched. If the next `cargo test` lists
;; friedman::smoke::rebuild-control, adding a file triggers rediscovery.

(:wat::test::deftest :friedman::smoke::rebuild-control
  (:wat::test::assert-eq (:wat::core::+ 2 2) 4))
