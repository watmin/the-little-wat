;; probes/sqlite/readonly-refuses-write.wat: does the checker really refuse a write through a
;; read-only connection?
;;
;; sqlite.wat's header makes a strong, checkable claim about its own design:
;;
;;   "Connection / ReadConnection (opaque, thread-owned; RO is the capability-honest half — no
;;    execute/execute-ddl/pragma/begin/commit is registered under ReadConnection's type path, so
;;    the checker rejects any attempt to write through one)"
;;
;; If that holds, a write through a ReadConnection is a STARTUP refusal — not a runtime error,
;; not a permission denial from sqlite itself, but the type checker declining to compile the
;; program. That is a much stronger guarantee than "the database will say no", and it is the kind
;; of claim worth verifying rather than repeating: this session has already found a doc claiming
;; something its code did not do.
;;
;; Its own file because a startup refusal ends the program. The control — that a READ through a
;; ReadConnection is accepted — lives in probes/sqlite/readonly-reads.wat, so that a refusal here
;; means "writes are refused" and not "ReadConnection is unusable".
;;
;; Run from the repository root: wat probes/sqlite/readonly-refuses-write.wat
;; Expected, if the header is honest: refused at startup, non-zero exit.

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:wat::core::Result/expect
                           (:wat::sqlite::open-readonly ":memory:")
                           "open-readonly failed")
                    n (:wat::core::Result/expect
                        (:wat::sqlite::execute conn "INSERT INTO t (id) VALUES (1)"
                          (:wat::core::Vector :- [:wat::sqlite::Param]))
                        "execute through a ReadConnection")]
    (:wat::kernel::println
      (:wat::string::concat "the checker allowed a write through a read-only connection: "
                            (:wat::i64::to-string n)))))
