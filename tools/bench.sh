#!/usr/bin/env bash
# tools/bench.sh — the performance baseline (NEXT.md §7).
#
# Runs every bench/*.wat REPS times and keeps the MINIMUM per label: the least-disturbed run,
# which is the standard choice on a machine that also has a browser open. Emits a dated
# tab-free table; bench programs print " | "-separated rows because :wat::kernel::println
# EDN-quotes a String, so a tab would arrive as a literal backslash-t (F-049).
#
# The point of this file is to exist BEFORE the byte-code / jump-DAG work. A before/after
# cannot be taken afterwards.
#
# Usage: tools/bench.sh [path-to-wat-rs] [reps]
set -uo pipefail
RS="${1:-../wat-rs}"; WAT="$RS/target/release/wat"; REPS="${2:-3}"
T="${TMPDIR:-/tmp}/wat-bench"; mkdir -p "$T"; : > "$T/all"

for f in bench/*.wat; do
  [ -f "$f" ] || continue
  for i in $(seq "$REPS"); do
    timeout -s KILL 900 "$WAT" "$f" 2>/dev/null | sed 's/^"//; s/"$//' | grep '^BENCH | ' >> "$T/all"
  done
done

rev=$(git -C "$RS" rev-parse --short HEAD 2>/dev/null || echo unknown)
echo "# wat performance baseline"
echo "# date: $(date -u +%Y-%m-%d)   wat-rs: $rev   reps: $REPS (minimum kept)   host: $(nproc) cores"
echo
printf '| %-28s | %10s | %12s |\n' "what" "ops" "ns/op (min)"
printf '|%s|%s|%s|\n' "------------------------------" "------------" "--------------"
awk -F' \\| ' '{ key=$2; ops=$3; v=$6+0; if (!(key in m) || v < m[key]) { m[key]=v; o[key]=ops } }
  END { for (k in m) printf "| %-28s | %10s | %12d |\n", k, o[k], m[k] }' "$T/all" | sort
