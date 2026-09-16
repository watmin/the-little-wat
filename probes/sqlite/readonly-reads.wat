;; probes/sqlite/readonly-reads.wat: the CONTROL for probes/sqlite/readonly-refuses-write.wat.
;;
;; That probe expects a write through a ReadConnection to be refused at startup. A refusal only
;; means "writes are refused" if a READ through the same connection is accepted — otherwise it
;; would just mean ReadConnection is unusable, or that open-readonly on ":memory:" fails, and the
;; measurement would say nothing about capability honesty.
;;
;; select is a defclause with a clause for each connection type, so a ReadConnection should
;; answer to it. This file checks that it does.
;;
;; Run from the repository root: wat probes/sqlite/readonly-reads.wat
;; Expected: exit 0.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:wat::core::Result/expect
                           (:wat::sqlite::open-readonly ":memory:")
                           "open-readonly failed")
                    rows (:wat::sqlite::select conn "SELECT 1" (:wat::core::Vector :- [:wat::sqlite::Param]))]
    (:wat::kernel::println
      (:wat::core::match rows
        [:wat::core::Result.Ok {:value rs}
          (:wat::string::concat "a read through a read-only connection is fine: "
                                (:wat::i64::to-string (:wat::core::count rs)) " row(s)")]
        [:wat::core::Result.Err {:error _e} "the read itself failed"]))))
