#!/usr/bin/env bash
# tools/copies.sh -- every bulk copy in the runtime is counted, or it is bytes.
#
# A `rep movsq` / `rep movsb` duplicates slots. Pointer slots have to raise the count
# of what they copy (`:c::count-span` or `:c::count-copied` or `:c::count-masked` in
# the same routine). Byte copies are named here, with the reason. A new copy that is
# neither fails.
#
#   tools/copies.sh          check elf/lib/runtime.wat
#   tools/copies.sh --plant  a synthetic uncounted copy must fail
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

# byte copies: the payload is characters or digits, never a wat pointer
BYTE="rt-str-cat rt-str-cat-own rt-str-subs rt-i64-to-str rt-buf-put rt-print-str rt-cpath rt-io-read-file"
# cpath copies a path's bytes onto the heap top so a syscall can see a C string.
# It is not a pointer slot; the brief's line number landed on this rep movsb.

plant=0
[ "${1:-}" = "--plant" ] && plant=1

src=$(mktemp)
if [ "$plant" -eq 1 ]; then
  cat > "$src" <<'EOF'
(:wat::core::defn :c::rt-evil [] -> :wat::core::String
  (:c::rep-movsq))
EOF
else
  cp elf/lib/runtime.wat "$src"
fi

fail=0
cur=""
while IFS= read -r line; do
  case "$line" in
    *'defn :c::rt-'*)
      cur=$(printf '%s' "$line" | sed -n 's/.*defn :c::\([a-z0-9-]*\).*/\1/p')
      ;;
  esac
  case "$line" in
    *':c::rep-movsq'*|*':c::rep-movsb'*)
      ok=0
      for b in $BYTE; do [ "$cur" = "$b" ] && ok=1; done
      printf '%s\n' "$line" | grep -q 'count-span\|count-copied\|count-masked' && ok=1
      # the count may be the next forms in the same routine; accept the routine if
      # its text, from this defn to the next, mentions a counter
      if [ "$ok" -eq 0 ] && [ -n "$cur" ]; then
        awk -v fn="$cur" '
          $0 ~ "defn :c::" fn {on=1}
          on && $0 ~ "defn :c::" && $0 !~ ("defn :c::" fn) {exit}
          on && /count-span|count-copied|count-masked/ {found=1}
          END {exit !found}
        ' "$src" && ok=1
      fi
      if [ "$ok" -eq 0 ]; then
        echo "copies: FAIL -- $cur copies slots and nothing counts them"
        echo "      $line"
        fail=1
      fi
      ;;
  esac
done < "$src"
rm -f "$src"

if [ "$fail" -eq 0 ]; then
  if [ "$plant" -eq 1 ]; then
    echo "copies: FAIL -- the planted copy was accepted"
    exit 1
  fi
  echo "copies: ok -- every bulk copy is counted or is bytes"
  exit 0
fi
if [ "$plant" -eq 1 ]; then
  echo "copies: plant refused, as it must be"
  exit 0
fi
exit 1
