;; wat's sqlite surface, against the sqlite3 CLI on the same schema and the same queries.
;;
;; wat ships :wat::sqlite:: — open, open-readonly, execute-ddl, execute, select, begin, commit,
;; pragma, classify — a thin, ratified interop over rusqlite. Nothing in this repository had
;; touched it, and no finding mentioned it.
;;
;; The oracle is sqlite3 itself (oracle/sqlite/s01-crud.sql, run by tools/sqlite-oracle.sh), the
;; same engine wat binds. So this compares wat's SURFACE against the reference client rather than
;; one database against another: if a row comes back different, it is wat's marshalling that
;; differs, not the SQL.
;;
;; Two things this case deliberately does NOT do:
;;   floats     F-034 — wat prints an integral f64 without its .0, so a REAL holding 2.0 renders
;;              as "2" where sqlite3 prints "2.0" (measured, probes/sqlite/cell-rendering.wat).
;;              A float here would fail on formatting rather than on data.
;;   string SQL for the parameterised lookup the value is BOUND as a Param, not interpolated into
;;              the SQL, since binding is the thing worth testing.
;;
;; A select answers (Result :- [(Vector :- [(Vector :- [Cell])]) Error]) — positional rows of
;; positional cells, with no column names anywhere. Every read below is therefore by index.
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat sqlite/s01-crud.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sq::Rows (:wat::core::Vector :- [(:wat::core::Vector :- [:wat::sqlite::Cell])]))
(:wat::core::typealias :sq::Row  (:wat::core::Vector :- [:wat::sqlite::Cell]))
(:wat::core::typealias :sq::Params (:wat::core::Vector :- [:wat::sqlite::Param]))

;; ---- rendering a cell the way the oracle prints it

(:wat::core::defn :sq::cell [c <- :wat::sqlite::Cell] -> :wat::core::String
  (:wat::core::match c
    [:wat::sqlite::Cell.I64 {:v v} (:wat::i64::to-string v)]
    [:wat::sqlite::Cell.F64 {:v v} (:wat::f64::to-string v)]
    [:wat::sqlite::Cell.Str {:v v} v]
    [:wat::sqlite::Cell.Nil {} "<null>"]))

(:wat::core::defn :sq::row [r <- :sq::Row] -> :wat::core::String
  (:wat::string::join "|" (:wat::core::mapv :sq::cell r)))

(:wat::core::defn :sq::no-params [] -> :sq::Params (:wat::core::Vector :- [:wat::sqlite::Param]))

;; ---- talking to the database

(:wat::core::defn :sq::query [conn <- :wat::sqlite::Connection sql <- :wat::core::String params <- :sq::Params] -> :sq::Rows
  (:wat::core::Result/expect (:wat::sqlite::select conn sql params)
                             (:wat::string::concat "select failed: " sql)))

(:wat::core::defn :sq::run [conn <- :wat::sqlite::Connection sql <- :wat::core::String] -> :wat::core::i64
  (:wat::core::Result/expect (:wat::sqlite::execute conn sql (:sq::no-params))
                             (:wat::string::concat "execute failed: " sql)))

;; every row of a result, rendered, in order
(:wat::core::defn :sq::rows-of [rows <- :sq::Rows] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::mapv :sq::row rows))

;; the single cell of a single-row, single-column result — a count, usually
(:wat::core::defn :sq::one [rows <- :sq::Rows] -> :wat::core::String
  (:sq::cell (:wat::core::first (:wat::core::first rows))))

;; ---- the case

(:wat::core::defn :sq::seeded [] -> :wat::sqlite::Connection
  (:wat::core::let [conn (:wat::core::Result/expect (:wat::sqlite::open ":memory:") "open failed")
                    _ddl (:wat::core::Result/expect
                           (:wat::sqlite::execute-ddl conn
                             "CREATE TABLE part (id INTEGER PRIMARY KEY, name TEXT NOT NULL, bin TEXT)")
                           "ddl failed")
                    _i1 (:sq::run conn "INSERT INTO part (id, name, bin) VALUES (1, 'bolt', 'A1')")
                    _i2 (:sq::run conn "INSERT INTO part (id, name, bin) VALUES (2, 'nut', 'A2')")
                    _i3 (:sq::run conn "INSERT INTO part (id, name, bin) VALUES (3, 'washer', NULL)")
                    _i4 (:sq::run conn "INSERT INTO part (id, name, bin) VALUES (4, 'screw', 'B1')")]
    conn))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:sq::seeded)

                    ;; how many rows landed
                    n0 (:sq::one (:sq::query conn "SELECT count(*) FROM part" (:sq::no-params)))

                    ;; every row, in order, with NULL made visible
                    all (:sq::rows-of
                          (:sq::query conn
                            "SELECT id, name, ifnull(bin, '<null>') FROM part ORDER BY id"
                            (:sq::no-params)))

                    ;; a parameterised lookup — the value is BOUND, not interpolated
                    found (:sq::rows-of
                            (:sq::query conn "SELECT id, name FROM part WHERE name = ?"
                              (:wat::core::Vector :- [:wat::sqlite::Param]
                                (:wat::sqlite::Param.Str {:v "nut"}))))

                    ;; an aggregate that skips the NULL, and a GROUP BY where NULL is its own group
                    nbin (:sq::one (:sq::query conn "SELECT count(bin) FROM part" (:sq::no-params)))
                    grouped (:sq::rows-of
                              (:sq::query conn
                                "SELECT ifnull(bin, '<null>'), count(*) FROM part GROUP BY bin ORDER BY bin"
                                (:sq::no-params)))

                    ;; an update, then the row it changed
                    _u (:sq::run conn "UPDATE part SET bin = 'C9' WHERE id = 3")
                    updated (:sq::rows-of
                              (:sq::query conn
                                "SELECT id, name, ifnull(bin, '<null>') FROM part WHERE id = 3"
                                (:sq::no-params)))

                    ;; a delete, then the count
                    _d (:sq::run conn "DELETE FROM part WHERE id = 4")
                    n1 (:sq::one (:sq::query conn "SELECT count(*) FROM part" (:sq::no-params)))

                    ;; ordering by something other than the key
                    names (:sq::rows-of
                            (:sq::query conn "SELECT name FROM part ORDER BY name" (:sq::no-params)))

                    ;; a query that matches nothing: zero rows is an answer, not an error
                    none (:sq::one (:sq::query conn "SELECT count(*) FROM part WHERE name = 'missing'"
                                     (:sq::no-params)))]
    (:sq::check-results "oracle/sqlite/s01-crud.expected"
                        "sqlite s01 crud"
                        (:wat::core::concat
                          (:wat::core::concat
                            (:wat::core::concat
                              (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] n0) all)
                              (:wat::core::concat found
                                (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] nbin) grouped)))
                            (:wat::core::concat updated (:wat::core::Vector :- [:wat::core::String] n1)))
                          (:wat::core::concat names (:wat::core::Vector :- [:wat::core::String] none))))))
