-- oracle/sqlite/s01-crud.sql: the expected results for sqlite/s01-crud.wat.
--
-- Our own schema and queries, run by the sqlite3 CLI — the same engine wat's :wat::sqlite::
-- surface binds. So this compares wat's SURFACE against the reference client, not one database
-- against another.
--
-- Output is shaped so both sides emit identical strings: `.mode list` with `|` as the separator,
-- and a NULL printed as <null> via ifnull(), because an empty field and an empty string are not
-- the same answer.
--
-- Floats are deliberately absent. F-034: wat prints an integral f64 without its .0, so a REAL
-- column holding 2.0 renders as "2" in wat and "2.0" here — a formatting difference, not a data
-- one, measured in probes/sqlite/cell-rendering.wat. Putting floats in this case would make it
-- fail for the wrong reason; they get a case of their own where the difference is the subject.
--
-- Every line printed after "=> " is a result the wat case must print, in order.
--
-- Run: tools/sqlite-oracle.sh s01-crud

.mode list
.separator |
.headers off

CREATE TABLE part (
  id    INTEGER PRIMARY KEY,
  name  TEXT NOT NULL,
  bin   TEXT
);

INSERT INTO part (id, name, bin) VALUES (1, 'bolt',   'A1');
INSERT INTO part (id, name, bin) VALUES (2, 'nut',    'A2');
INSERT INTO part (id, name, bin) VALUES (3, 'washer', NULL);
INSERT INTO part (id, name, bin) VALUES (4, 'screw',  'B1');

-- how many rows landed
SELECT '=> ' || count(*) FROM part;

-- every row, in order, with NULL made visible
SELECT '=> ' || id || '|' || name || '|' || ifnull(bin, '<null>') FROM part ORDER BY id;

-- a parameterised lookup (the wat side binds this with a Param, not by interpolation)
SELECT '=> ' || id || '|' || name FROM part WHERE name = 'nut';

-- an aggregate, and a GROUP BY, both over a NULLable column
SELECT '=> ' || count(bin) FROM part;
SELECT '=> ' || ifnull(bin, '<null>') || '|' || count(*) FROM part GROUP BY bin ORDER BY bin;

-- an update, then the row it changed
UPDATE part SET bin = 'C9' WHERE id = 3;
SELECT '=> ' || id || '|' || name || '|' || ifnull(bin, '<null>') FROM part WHERE id = 3;

-- a delete, then the count
DELETE FROM part WHERE id = 4;
SELECT '=> ' || count(*) FROM part;

-- ordering by something other than the key, to be sure ORDER BY is honoured either side
SELECT '=> ' || name FROM part ORDER BY name;

-- a query that matches nothing: zero rows is an answer, not an error
SELECT '=> ' || count(*) FROM part WHERE name = 'missing';
