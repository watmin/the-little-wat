;; probes/sqlite/cell-rendering.wat: how does a Cell become a string wat and sqlite3 can agree on?
;;
;; A select answers (Result :- [(Vector :- [(Vector :- [Cell])]) Error]) — positional rows of
;; positional cells, with no column names anywhere. To compare a row against the sqlite3 CLI's
;; `.mode list` output (`1|hello|1.5|<null>`) each Cell has to be rendered, and two of the four
;; variants are hazardous:
;;
;;   Cell.F64  F-034: wat prints an integral float WITHOUT its .0 — 2.0 renders as "2" where
;;             sqlite3 prints "2.0". Any case comparing printed floats would fail on FORMATTING
;;             rather than on data, so this must be known before a case is built on it.
;;   Cell.Nil  an empty field and an empty string are not the same answer. The oracle prints
;;             <null> via ifnull(), so wat must do the same rather than render "".
;;
;; This measures all four variants through a query whose values are known, so the renderer can be
;; written against what wat actually prints instead of against what I assume it prints.
;;
;; Run from the repository root: wat probes/sqlite/cell-rendering.wat

(:wat::core::defn :cr::cell [c <- :wat::sqlite::Cell] -> :wat::core::String
  (:wat::core::match c
    [:wat::sqlite::Cell.I64 {:v v} (:wat::i64::to-string v)]
    [:wat::sqlite::Cell.F64 {:v v} (:wat::f64::to-string v)]
    [:wat::sqlite::Cell.Str {:v v} v]
    [:wat::sqlite::Cell.Nil {} "<null>"]))

(:wat::core::defn :cr::row [r <- (:wat::core::Vector :- [:wat::sqlite::Cell])] -> :wat::core::String
  (:wat::string::join "|"
    (:wat::core::mapv :cr::cell r)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:wat::core::Result/expect (:wat::sqlite::open ":memory:") "open failed")
                    _ddl (:wat::core::Result/expect
                           (:wat::sqlite::execute-ddl conn
                             "CREATE TABLE t (id INTEGER, s TEXT, f REAL, n TEXT)")
                           "ddl failed")
                    _i (:wat::core::Result/expect
                         (:wat::sqlite::execute conn
                           "INSERT INTO t VALUES (1,'hello',1.5,NULL),(2,'world',2.0,'set')"
                           (:wat::core::Vector :- [:wat::sqlite::Param]))
                         "insert failed")
                    rows (:wat::core::Result/expect
                           (:wat::sqlite::select conn "SELECT id, s, f, n FROM t ORDER BY id"
                             (:wat::core::Vector :- [:wat::sqlite::Param]))
                           "select failed")]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "rows: " (:wat::i64::to-string (:wat::core::count rows))))
      ;; sqlite3 prints:  1|hello|1.5|<null>
      (:wat::kernel::println (:wat::string::concat "row 0: " (:cr::row (:wat::core::first rows))))
      ;; sqlite3 prints:  2|world|2.0|set   <- the F-034 hazard: wat may print 2.0 as "2"
      (:wat::kernel::println (:wat::string::concat "row 1: " (:cr::row (:wat::core::nth rows 1))))
      ;; and the round trip of a float bound as a Param, for the same reason
      (:wat::kernel::println (:wat::string::concat "f64 2.0 renders as: " (:wat::f64::to-string 2.0)))
      (:wat::kernel::println (:wat::string::concat "f64 1.5 renders as: " (:wat::f64::to-string 1.5))))))
