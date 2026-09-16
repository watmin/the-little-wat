#!/usr/bin/env bash
# tools/sqlite-oracle.sh: run a case's SQL against the sqlite3 CLI, oracle/sqlite/NAME.sql (our
# own schema and queries), and keep its results, one per line, in oracle/sqlite/NAME.expected.
#
# The oracle is sqlite3 itself — the same engine wat's :wat::sqlite:: surface binds — so this
# compares wat's SURFACE against the reference client, not one database against another. Output
# is shaped with `.mode list` and `.separator |` so both sides emit identical strings; a NULL
# prints as <null> rather than an empty field, since an empty field and an empty string are not
# the same answer.
#
# Usage: tools/sqlite-oracle.sh s01-crud      (needs the sqlite3 CLI)
set -u
name="$1"
src="oracle/sqlite/$name.sql"
out="oracle/sqlite/$name.expected"
raw=$(timeout -s KILL 300 sqlite3 :memory: < "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "sqlite-oracle: sqlite3 failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "sqlite-oracle: $(wc -l < "$out") results -> $out"
