# wat's sqlite surface, against the sqlite3 CLI

wat ships `:wat::sqlite::` — `open`, `open-readonly`, `execute-ddl`, `execute`, `select`,
`begin`, `commit`, `pragma`, `classify` — a thin interop over rusqlite, described in its own
source as "the RAW layer BELOW the backend-agnostic `:wat::query::Store` contract". Nothing in
this repository had touched it, and no finding mentioned it.

The oracle is **sqlite3 itself** (`/usr/bin/sqlite3`, 3.53.4), the same engine wat binds. That
makes this a different kind of comparison from the rest of the repo: not one implementation
against another, but wat's *surface* against the reference client. If a row comes back
different, it is wat's marshalling that differs, not the SQL.

## Cases (2026-09-15, wat-rs `a3218644d`)

| case | what it exercises | results | wat |
|---|---|---|---|
| s01-crud | schema, bound parameters, NULL, aggregates, GROUP BY, update, delete, ordering, a zero-row query | 17, all matching sqlite3 | 0.95 s |

The time is the whole run, wat's 0.29 s of startup included — so opening `:memory:`, creating the
table, four inserts, an update, a delete and ten queries cost a few hundred milliseconds.

## What the first case showed

- **It ports cleanly** (C-037). All 17 results agree on the first run.
- **The read-only connection is capability-honest, and the checker enforces it.** `sqlite.wat`
  claims no write verb is registered under `ReadConnection`'s type path, "so the checker rejects
  any attempt to write through one". It does, at **startup**:

  ```
  :wat::sqlite::execute: parameter #1 expects :wat::sqlite::Connection;
  got :rust::sqlite::ReadConnection
  ```

  with a read through the same connection still accepted. That is a real guarantee — not "the
  database will refuse at runtime", but "the program will not compile". It is also the first
  documented claim in this repository's recent rounds that survived checking exactly as written.
- **Errors are values, and that is better than the language around it.** A duplicate key gives
  `Err Constraint`, bad SQL gives `Err Fatal`, an unopenable path gives `Err Fatal`, and a
  program faces all of them in sequence and keeps running — no `run-thread`, no spawned thread,
  no death (`probes/sqlite/errors-are-values.wat`). F-063 measured the alternative: wat's only
  general catch costs about 1.3 ms and lives in the **test** namespace. sqlite already does what
  that finding asks for.
- **Rows are positional.** `select` answers `(Vector :- [(Vector :- [Cell])])` — no column names
  anywhere, so every read is by index. SQL's results are named; wat's are not.
- **`begin` and `commit` exist; `rollback` does not** (F-068), on a surface whose own header says
  "do NOT rename or add verbs". Raw `execute conn "ROLLBACK"` works and does undo the write, so
  the capability is there and only the name is missing — but nothing says so.
- **F-034 again, in a second context.** A `REAL` column holding `2.0` renders as `2` where
  sqlite3 prints `2.0`. The value round-trips correctly; only the printing differs. This case
  therefore holds no floats — they need a case where that difference is the subject rather than
  an accident.

## Running

```
tools/sqlite-oracle.sh s01-crud   # sqlite3 writes oracle/sqlite/s01-crud.expected
wat sqlite/s01-crud.wat           # the same SQL through wat, checked against it
./run.sh sqlite                   # every case in this suite
./run.sh                          # every case, with every chapter (16 minutes)
```
