;; probes/sqlite/errors-are-values.wat: does a failing query really come back as a VALUE?
;;
;; sqlite.wat's header says so, in capitals: "errors are VALUES — never panics, never raise!
;; Every :rust::sqlite'::* dispatch fn returns a wat Result whose Err payload is a raw (code,
;; diagnostic, message) 3-tuple (never a panic)".
;;
;; That matters beyond this surface. F-063 found that wat's only general way to survive a
;; failure is :wat::test::run-thread — a TEST verb that spawns a thread, at about 1.3 ms a
;; catch. A subsystem that hands failures back as ordinary values needs none of that: a match
;; arm costs nothing. If sqlite really does this, it is the pattern the rest of the language
;; does not have, and worth saying so.
;;
;; Three failures, each a different axis of the Error enum:
;;   Constraint  a duplicate primary key
;;   Fatal       a syntax error, and a file that cannot be opened
;; and the point is that the program keeps running through all of them and prints a verdict at
;; the end — no run-thread, no catch, no death.
;;
;; Run from the repository root: wat probes/sqlite/errors-are-values.wat

(:wat::core::defn :ev::classify [r <- (:wat::core::Result :- [:wat::core::i64 :wat::sqlite::Error])] -> :wat::core::String
  (:wat::core::match r
    [:wat::core::Result.Ok {:value n} (:wat::string::concat "Ok " (:wat::i64::to-string n))]
    [:wat::core::Result.Err {:error e}
      (:wat::core::match e
        [:wat::sqlite::Error.Transient {:fault _f} "Err Transient"]
        [:wat::sqlite::Error.Constraint {:fault _f} "Err Constraint"]
        [:wat::sqlite::Error.Fatal {:fault _f} "Err Fatal"])]))

(:wat::core::defn :ev::open-outcome [r <- (:wat::core::Result :- [:wat::sqlite::Connection :wat::sqlite::Error])] -> :wat::core::String
  (:wat::core::match r
    [:wat::core::Result.Ok {:value _c} "Ok — opened"]
    [:wat::core::Result.Err {:error e}
      (:wat::core::match e
        [:wat::sqlite::Error.Transient {:fault _f} "Err Transient"]
        [:wat::sqlite::Error.Constraint {:fault _f} "Err Constraint"]
        [:wat::sqlite::Error.Fatal {:fault _f} "Err Fatal"])]))

(:wat::core::defn :ev::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [conn (:wat::core::Result/expect (:wat::sqlite::open ":memory:") "open failed")
                    _ddl (:wat::core::Result/expect
                           (:wat::sqlite::execute-ddl conn "CREATE TABLE t (id INTEGER PRIMARY KEY)")
                           "ddl failed")
                    ok1 (:wat::sqlite::execute conn "INSERT INTO t (id) VALUES (1)"
                          (:wat::core::Vector :- [:wat::sqlite::Param]))
                    ;; the same key again — a constraint violation
                    dup (:wat::sqlite::execute conn "INSERT INTO t (id) VALUES (1)"
                          (:wat::core::Vector :- [:wat::sqlite::Param]))
                    ;; nonsense SQL
                    bad (:wat::sqlite::execute conn "INSERT INTO" (:wat::core::Vector :- [:wat::sqlite::Param]))
                    ;; a path that cannot be opened
                    nodir (:wat::sqlite::open "/nonexistent-dir-wat-friedman/x.db")]
    (:wat::core::do
      (:ev::show "a good insert" (:ev::classify ok1))
      (:ev::show "a duplicate primary key" (:ev::classify dup))
      (:ev::show "a syntax error" (:ev::classify bad))
      (:ev::show "an unopenable path" (:ev::open-outcome nodir))
      ;; the whole point: four failures faced, no thread spawned, still running
      (:ev::show "the program survived all of it" "yes — every failure was a value"))))
