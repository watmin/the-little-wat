;; probes/koans/bigint-literal.wat: does wat read Clojure's bigint literal, 1000000000000000000000000N?
;; (wat-rs's own parity corpus reads 1N, tests/clj_expr_oracle/corpus.txt.)

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write 1000000000000000000000000N)))
