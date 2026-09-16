#!/usr/bin/env bash
# tools/fix-roundtrip.sh — run wat's own wat-to-wat converter over a corpus and check that the
# converted program still behaves identically.
#
# wat/fix.wat calls itself "THE PROVING POINT: wat writes wat". The only test that means anything
# for a codemod is semantic preservation, so: convert, run both, diff stdout, compare exit codes.
set -uo pipefail
RS="${1:-../wat-rs}"; WAT="$RS/target/release/wat"
T="${TMPDIR:-/tmp}/fix-roundtrip"; mkdir -p "$T"
shift || true
same=0; differ=0; convfail=0; origfail=0
for f in "$@"; do
  timeout -s KILL 60 "$WAT" "$f" > "$T/orig.out" 2>"$T/orig.err"; orc=$?
  if [ $orc -ne 0 ]; then origfail=$((origfail+1)); continue; fi
  timeout -s KILL 60 "$WAT" probes/fix/convert.wat "$f" > "$T/conv.raw" 2>"$T/conv.err"
  if [ $? -ne 0 ]; then convfail=$((convfail+1)); echo "  CONVERT-FAILED $f"; continue; fi
  python3 -c "
import ast,sys
open('$T/conv.wat','w').write(ast.literal_eval(open('$T/conv.raw').read().strip()))" 2>/dev/null || { convfail=$((convfail+1)); continue; }
  timeout -s KILL 60 "$WAT" "$T/conv.wat" > "$T/new.out" 2>"$T/new.err"; nrc=$?
  if [ "$orc" = "$nrc" ] && diff -q "$T/orig.out" "$T/new.out" >/dev/null; then
    same=$((same+1))
  else
    differ=$((differ+1)); echo "  DIFFERS $f (rc $orc -> $nrc)"
    diff "$T/orig.out" "$T/new.out" | head -4 | sed 's/^/      /'
  fi
done
echo "identical: $same   differ: $differ   convert-failed: $convfail   (skipped, original not green: $origfail)"
