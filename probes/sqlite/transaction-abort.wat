;; probes/sqlite/transaction-abort.wat: can a wat program abandon a transaction?
;;
;; wat's sqlite surface is ratified and closed — sqlite.wat's header says "the named surface
;; (intueri-cast — do NOT rename or add verbs)" and lists it: open / open-readonly / pragma /
;; begin / commit / execute / execute-ddl / select.
;;
;; There is a `begin` and a `commit`. There is NO rollback: a word-boundary search for
;; rollback across :wat::sqlite:: and :rust::sqlite:: finds nothing. So a program can open a
;; transaction and finish it, but the verb for abandoning one is absent from a surface that is
;; explicitly not to be added to.
;;
;; The absence is not the interesting part — the CONSEQUENCE is, and it decides how serious this
;; is:
;;
;;   WORKAROUND EXISTS   `execute` takes arbitrary SQL, so (execute conn "ROLLBACK" []) may just
;;                       work, and the gap is a missing convenience verb. Extend, trivial.
;;   NO WAY BACK         if raw ROLLBACK is refused or ignored, then a wat program that has begun
;;                       a transaction can only commit it, and a half-finished write cannot be
;;                       undone. That is much worse than a missing verb.
;;
;; Two things measured: whether raw ROLLBACK runs at all, and whether it actually undoes the
;; write. A verb that returns Ok and changes nothing would be the worst answer of the three.
;;
;; Run from the repository root: wat probes/sqlite/transaction-abort.wat

(:wat::core::defn :tx::rows [conn <- :wat::sqlite::Connection] -> :wat::core::i64
  (:wat::core::count
    (:wat::core::Result/expect
      (:wat::sqlite::select conn "SELECT id FROM t ORDER BY id"
        (:wat::core::Vector :- [:wat::sqlite::Param]))
      "select failed")))

(:wat::core::defn :tx::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :tx::outcome [r <- (:wat::core::Result :- [:wat::core::i64 :wat::sqlite::Error])] -> :wat::core::String
  (:wat::core::match r
    [:wat::core::Result.Ok {:value n} (:wat::string::concat "Ok " (:wat::i64::to-string n))]
    [:wat::core::Result.Err {:error e}
      (:wat::core::match e
        [:wat::sqlite::Error.Transient {:fault _f} "Err Transient"]
        [:wat::sqlite::Error.Constraint {:fault _f} "Err Constraint"]
        [:wat::sqlite::Error.Fatal {:fault _f} "Err Fatal"])]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:wat::core::Result/expect (:wat::sqlite::open ":memory:") "open failed")
                    _ddl (:wat::core::Result/expect
                           (:wat::sqlite::execute-ddl conn "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                           "ddl failed")
                    ;; one row, committed the ordinary way
                    _i1 (:wat::core::Result/expect
                          (:wat::sqlite::execute conn "INSERT INTO t (id) VALUES (1)"
                            (:wat::core::Vector :- [:wat::sqlite::Param]))
                          "insert 1 failed")
                    before (:tx::rows conn)
                    ;; begin, write, then try to abandon it
                    _b (:wat::core::Result/expect (:wat::sqlite::begin conn) "begin failed")
                    _i2 (:wat::core::Result/expect
                          (:wat::sqlite::execute conn "INSERT INTO t (id) VALUES (2)"
                            (:wat::core::Vector :- [:wat::sqlite::Param]))
                          "insert 2 failed")
                    during (:tx::rows conn)
                    rb (:wat::sqlite::execute conn "ROLLBACK"
                         (:wat::core::Vector :- [:wat::sqlite::Param]))
                    after (:tx::rows conn)]
    (:wat::core::do
      (:tx::show "rows before the transaction" (:wat::i64::to-string before))
      (:tx::show "rows inside the transaction" (:wat::i64::to-string during))
      (:tx::show "raw ROLLBACK through execute" (:tx::outcome rb))
      (:tx::show "rows after the rollback" (:wat::i64::to-string after))
      (:tx::show "the write was undone"
                 (:wat::core::if (:wat::core::= after before) "yes" "NO — it survived")))))
