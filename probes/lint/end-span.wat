;; probes/lint/end-span.wat: is lint.wat's auto-fix blocker still true?
;;
;; wat/lint.wat's header says the auto-fix "cannot land cleanly because :wat::core::ast-span
;; returns ONLY the START location (line/col), not the end — so computing old-len for a
;; structural node is not possible with the current substrate primitives", and ships the ladder
;; rule REPORT-ONLY because of it.
;;
;; But the same file's FixEdit record documents end-line/end-col as coming "from ast-end-span".
;; Either the header is stale or the record is wrong. This asks the runtime.
;;
;; Run from the repository root: wat probes/lint/end-span.wat

(:wat::core::defn :e::show [l <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat l "  " s)))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [form (:wat::core::quote (:wat::core::+ 1 2))]
    (:wat::core::do
      (:e::show "ast-span     " (:wat::edn::write (:wat::core::ast-span form)))
      (:e::show "ast-end-span " (:wat::edn::write (:wat::core::ast-end-span form))))))
