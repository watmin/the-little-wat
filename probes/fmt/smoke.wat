;; smoke: can an ordinary program drive wat's formatter?
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/atoms.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/cond.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defn-args.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defn.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defrecord-fields.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defrecord.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/if.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/kwargs.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let-bindings.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let-blank.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/match.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/siblings.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/table.wat")

(:wat::core::defn :sm::show [l <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat l "  " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [rules (:wat::rete::collect-rules :fmt)
     src "(:wat::core::defn :a::f [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))"
     one (:wat::fmt::format-source "smoke.wat" src rules)
     two (:wat::fmt::format-source "smoke.wat" one rules)]
    (:wat::core::do
      (:sm::show "rules collected" (:wat::i64::to-string (:wat::core::length rules)))
      (:wat::kernel::println "--- once ---")
      (:wat::kernel::println one)
      (:wat::kernel::println "--- twice ---")
      (:wat::kernel::println two)
      (:sm::show "idempotent?" (:wat::core::if (:wat::core::= one two) "yes" "NO")))))
