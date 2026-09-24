#!/usr/bin/env bash
# tools/rules.sh [program.wat ...] -- the compiler must agree with itself at every boundary.
#
# Excursus 002 stone 1. For each program: compile it with the export on (`:c::compile-as ...
# true`), which prints what the compiler DECIDED -- the type it gave each argument of each call
# to a user function (CArg) and each parameter of each `defn` (CParam), at wat-grep's source
# positions -- then feed those lines to tools/rules/check.wat, where wat-rs's rete joins them
# with wat-grep's facts and reports every argument whose type is not its parameter's.
#
# **REPORT mode**: it prints every finding and the counts, and exits 0 whatever it finds. It
# exits non-zero only when it could not do the check: the exporter would not build, the export
# moved an emitted byte, or the checker died.
#
# With no arguments: the whole corpus -- every program elf/compile.wat's driver compiles, the
# compiler itself included -- and every elf/probe/*.wat.
#
# **The exporter is NATIVE.** Running the export through the interpreter costs what bootstrap's
# stage 0 costs (9m42s measured on this machine, for the corpus). So the export driver --
# elf/compile.wat with its `:user::main` replaced -- is compiled by the native compiler, the same
# trick `bootstrap.sh --fast` uses: elf/out/compiler.elf compiles "elf/compile.wat" to
# "elf/out/compiler.elf" relative to where it runs, so run in a sandbox whose elf/compile.wat IS
# the driver, it writes the exporter. RULES_INTERP=1 runs the same driver in the interpreter
# instead (the stage-0 path; slow, and the proof that the export works there too).
#
# **Every program is compiled twice by the exporter** -- export on, export off -- and the two
# binaries must be byte-identical: the export may say things, never change them.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
REPO=$PWD
WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "rules: no wat binary at $WAT"; exit 2; }
BOX=$(mktemp -d); trap 'rm -rf "$BOX"' EXIT
t0=$(date +%s%N)
ms () { echo $(( ($(date +%s%N) - $1) / 1000000 )); }

if [ $# -gt 0 ]; then PROGS="$*"
else
  PROGS="$(sed -n 's/^ *(:c::compile "\([^"]*\)" .*/\1/p' elf/compile.wat) $(ls elf/probe/*.wat)"
fi

# ---- the driver: the compiler with a main that compiles the ONE program named in $BOX/prog
n=$(grep -n 'defn :user::main' elf/compile.wat | cut -d: -f1)
[ -n "$n" ] || { echo "rules: could not find :user::main in elf/compile.wat"; exit 2; }
mkdir -p "$BOX/cc/elf/out"
head -$((n-1)) elf/compile.wat > "$BOX/cc/elf/compile.wat"
cat >> "$BOX/cc/elf/compile.wat" <<EOF
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [src (:wat::io::read-file "$BOX/prog")]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "PROG " src))
      (:c::compile-as src "$BOX/x.elf" true)
      (:wat::kernel::println "END")
      (:c::compile-as src "$BOX/n.elf" false)
      (:wat::kernel::println "compile: ok"))))
EOF

if [ -z "${RULES_INTERP:-}" ]; then
  [ -x elf/out/compiler.elf ] || { echo "rules: no elf/out/compiler.elf -- run tools/bootstrap.sh"; exit 2; }
  for d in src bad bench native lib; do ln -s "$REPO/elf/$d" "$BOX/cc/elf/$d"; done
  s=$(date +%s%N)
  ( cd "$BOX/cc" && timeout -s KILL 120 "$REPO/elf/out/compiler.elf" > "$BOX/cc.log" 2>&1 )
  grep -q '"compile: ok"' "$BOX/cc.log" && [ -f "$BOX/cc/elf/out/compiler.elf" ] || {
    echo "rules: the native compiler could not build the exporter"; tail -3 "$BOX/cc.log"; exit 2; }
  chmod +x "$BOX/cc/elf/out/compiler.elf"
  EXPORT=("$BOX/cc/elf/out/compiler.elf"); TMO=120
  echo "rules: exporter built natively in $(ms $s) ms"
else
  ln -s "$REPO/elf/lib" "$BOX/cc/elf/lib"
  EXPORT=("$REPO/$WAT" "$BOX/cc/elf/compile.wat"); TMO=1800
  echo "rules: exporter is the INTERPRETER (RULES_INTERP)"
fi

# ---- export, one process per program, so a program the compiler refuses costs only itself
s=$(date +%s%N)
: > "$BOX/facts"
nprog=0; refused=0; moved=0; same_out=0; diff_out=0
for p in $PROGS; do
  printf '%s' "$p" > "$BOX/prog"; rm -f "$BOX/x.elf" "$BOX/n.elf"
  timeout -s KILL $TMO "${EXPORT[@]}" > "$BOX/one" 2>&1
  if ! grep -q '"compile: ok"' "$BOX/one"; then
    refused=$((refused+1))
    echo "  refused  $p  ($(grep -v '^"C' "$BOX/one" | tail -1 | cut -c1-110))"
    continue
  fi
  nprog=$((nprog+1))
  if ! cmp -s "$BOX/x.elf" "$BOX/n.elf"; then
    echo "  MOVED    $p: the export changed an emitted byte"; moved=$((moved+1))
  fi
  # the corpus's binaries are also compared with the build on disk -- informational: it holds
  # when elf/out is current with the source
  o=$(sed -n "s|^ *(:c::compile \"$p\" *\"\([^\"]*\)\").*|\1|p" elf/compile.wat | head -1)
  if [ -n "$o" ] && [ -f "$o" ]; then
    if cmp -s "$BOX/n.elf" "$o"; then same_out=$((same_out+1)); else diff_out=$((diff_out+1)); echo "  (differs from $o)"; fi
  fi
  # one block per program; a line said twice (a form compiled twice) is one fact
  sed -n '/^"PROG /,/^"END"/p' "$BOX/one" | grep -E '^"(PROG|END|FILE|CArg|CParam)[ "]' \
    | awk '!seen[$0]++' >> "$BOX/facts"
done
texp=$(ms $s)
echo "rules: exported $nprog programs in $texp ms ($refused refused by the compiler);" \
     "export-on == export-off for $((nprog-moved)) of $nprog; $same_out corpus binaries byte-identical to elf/out, $diff_out not"
[ -n "${RULES_KEEP:-}" ] && cp "$BOX/facts" "$RULES_KEEP"

# ---- the check
s=$(date +%s%N)
timeout -s KILL 1800 "$WAT" tools/rules/check.wat < "$BOX/facts" > "$BOX/check" 2>&1; rc=$?
tchk=$(ms $s)
sed -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g' "$BOX/check" | grep -v '^rules: .*CONFLICT 0  unplaced 0  unjoined 0  mismatch 0$'
echo "rules: checked in $tchk ms; total $(ms $t0) ms"
[ $rc -eq 0 ] || { echo "rules: the checker died (exit $rc)"; exit 2; }
[ $moved -eq 0 ] || exit 1
exit 0
