#!/usr/bin/env bash
# tools/cli-surface.sh — what modes does the wat binary have, and which are documented?
#
# Exit codes are read WITHOUT a pipe: `wat --help | head` reports head's status, not wat's,
# which is how an earlier pass of this measurement got rc=0 for a failed read.
set -uo pipefail
RS="${1:-../wat-rs}"; WAT="$RS/target/release/wat"
T="${TMPDIR:-/tmp}/cli-surface"; mkdir -p "$T"

echo "=== flags a user would try first ==="
for a in --help -h help --version -V; do
  timeout -s KILL 20 "$WAT" "$a" > "$T/o" 2> "$T/e" < /dev/null
  printf '  %-10s rc=%-4s %s\n' "$a" "$?" "$(head -c 70 "$T/e" | tr '\n' ' ')"
done

echo; echo "=== the usage block (reachable only with NO arguments) ==="
timeout -s KILL 20 "$WAT" > "$T/o" 2> "$T/e" < /dev/null
echo "  rc=$?"; sed 's/^/  /' "$T/e" "$T/o" 2>/dev/null | grep -v '^  $'

echo; echo "=== which modes exist ==="
for m in --check --repl --mcp --grep --fmt --lint --test; do
  timeout -s KILL 20 "$WAT" "$m" > "$T/o" 2> "$T/e" < /dev/null
  rc=$?
  if grep -q 'No such file or directory' "$T/e"; then s="NOT A MODE (read as a filename)"; else s="exists"; fi
  printf '  %-9s rc=%-4s %s\n' "$m" "$rc" "$s"
done

echo; echo "=== documentation coverage across the four user-facing pages ==="
for m in --check --repl --mcp --grep; do
  t=0
  for d in USER-GUIDE.md WAT-CHEATSHEET.md CLOJURE-ROSETTA.md README.md; do
    t=$(( t + $(grep -c -- "\\$m" "$RS/docs/$d" 2>/dev/null; true) ))
  done
  printf '  %-9s mentions: %s\n' "$m" "$t"
done

echo; echo "=== does the undocumented REPL work? ==="
printf '(:wat::core::+ 2 3)\n' | timeout -s KILL 30 "$WAT" --repl 2>/dev/null | sed 's/^/  (+ 2 3) -> /'
