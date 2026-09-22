#!/usr/bin/env bash
# tools/probe.sh <program.wat> [label] -- compile ONE small program and diff the native
# answer against the interpreter's. About two seconds, against a bootstrap's 8.5 minutes.
#
# This is the tool that turned F-168 from a seven-minute bisect into a two-second one, and
# it is the only oracle in the tree that answers "does the compiler emit CORRECT code for
# this shape" about a program that is not already in elf/. tools/elf-run.sh asks the same
# question but only of the committed corpus; tools/emitted.sh asks whether bytes MOVED, not
# whether they were ever right.
#
# The interpreter drives the compile. That is not a compromise: bootstrap proves the
# interpreted compiler and the native compiler emit byte-identical output for all 74
# programs, so the bytes this produces are the bytes elf/out would get -- and it needs no
# prebuilt binary, so it works on a tree whose compiler is broken.
#
#   tools/probe.sh scratch/shape.wat          compile it, run it, compare
#
# Exit: 0 agree, 1 diverge or crash, 2 could not compile.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
REPO=$PWD
WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "probe: no wat binary at $WAT"; exit 2; }
SRC="${1:?usage: tools/probe.sh <program.wat> [label]}"
[ -f "$SRC" ] || { echo "probe: no such program: $SRC"; exit 2; }
SRC=$(realpath "$SRC")
LABEL="${2:-$(basename "$SRC" .wat)}"

# A sandbox, so a probe never writes into elf/out and never races a bootstrap. lib/ is
# symlinked because :wat::load-file! resolves relative to the driver's own directory.
BOX=$(mktemp -d); trap 'rm -rf "$BOX"' EXIT
mkdir -p "$BOX/elf/src" "$BOX/elf/out"
ln -s "$REPO/elf/lib" "$BOX/elf/lib"
cp "$SRC" "$BOX/elf/src/probe.wat"

# the driver: compile.wat with its :user::main replaced by a single compile of the probe
n=$(grep -n 'defn :user::main' elf/compile.wat | cut -d: -f1)
[ -n "$n" ] || { echo "probe: could not find :user::main in elf/compile.wat"; exit 2; }
head -$((n-1)) elf/compile.wat > "$BOX/elf/drv.wat"
cat >> "$BOX/elf/drv.wat" <<'EOF'
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c::compile "elf/src/probe.wat" "elf/out/probe.elf")
    (:wat::kernel::println "compile: ok")))
EOF

cd "$BOX" || exit 2
if ! timeout -s KILL 600 "$REPO/$WAT" elf/drv.wat > "$BOX/cc.log" 2>&1 || [ ! -f elf/out/probe.elf ]; then
  echo "$LABEL: COMPILE-FAILED  $(tail -1 "$BOX/cc.log")"; exit 2
fi
chmod +x elf/out/probe.elf

native=$(timeout -s KILL 60 ./elf/out/probe.elf 2>&1); nrc=$?
interp=$(timeout -s KILL 300 "$REPO/$WAT" elf/src/probe.wat 2>&1); irc=$?
nn=$(printf '%s' "$native" | tr '\n' '|'); ii=$(printf '%s' "$interp" | tr '\n' '|')

if [ "$nrc" -ge 128 ]; then
  echo "$LABEL: CRASH signal=$((nrc-128))   interp=[$ii]"; exit 1
elif [ "$nn" = "$ii" ] && [ "$nrc" -eq "$irc" ]; then
  echo "$LABEL: agree   [$ii]"; exit 0
else
  echo "$LABEL: DIVERGE  native=[$nn] (exit $nrc)   interp=[$ii] (exit $irc)"; exit 1
fi
