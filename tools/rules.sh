#!/usr/bin/env bash
# tools/rules.sh [program.wat ...] -- the compiler must agree with itself at every boundary.
#
# Excursus 002 stone 1. For each program: compile it with the export on (`:c::compile-as ...
# true`), which prints what the compiler DECIDED -- the type it gave each argument of each call
# to a user function (CArg) and each parameter of each `defn` (CParam), at wat-grep's source
# positions -- then feed those lines to tools/rules/check.wat, where wat-rs's rete joins them
# with wat-grep's facts and reports every argument whose type is not its parameter's.
#
# **MUST-BE-ZERO** (excursus 002 stone 4; stones 1 and 2 ran it in report mode). It prints every
# finding and the counts, and exits 1 when the compiler disagrees with itself (a boundary
# CONFLICT) or with the language (a TYPE-CONFLICT), or when the join is not whole -- a fact it
# could not place or join, a type it could not translate, a type the checker left unresolved --
# because a join that has gone blind would report zero conflicts too. `refined` stays allowed:
# the checker knowing the VARIANT where the compiler knows the enum is representation, not a
# disagreement. It exits 1 as well when the export moved an emitted byte, and 2 when it could not
# do the check at all: the exporter would not build or the checker died.
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
#
# **Stone 2 -- the compiler knows what the language knows.** The same export also prints, at the
# compiler's type waist, the type it gave every node it typed (CType), in wat's spelling. And
# wat-rs's own checker is asked for the type ITS `infer` gave every node of the same program
# (`WAT_CHECK_TYPES=1 wat --check`, one process per program, four at a time); those lines become
# KType/KUnres facts in the same block. check.wat joins the two by position. A program the
# checker refuses has no KType facts and is counted. RULES_DETAIL=<file> keeps every line the
# checker printed, the counted witnesses (`~`) included.
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

# ---- stone 2: what the LANGUAGE says each node's type is -- wat-rs's checker, one process per
# program, four at a time (they are independent)
s=$(date +%s%N)
mkdir -p "$BOX/k"
i=0; for p in $PROGS; do i=$((i+1)); printf '%s %s\n' "$i" "$p"; done > "$BOX/k/list"
export WAT BOX
xargs -P 4 -L 1 sh -c 'WAT_CHECK_TYPES=1 timeout -s KILL 300 "$WAT" --check "$1" > "$BOX/k/$0.types" 2> "$BOX/k/$0.err"; echo $? > "$BOX/k/$0.rc"' < "$BOX/k/list"
tkchk=$(ms $s)
kref=0; kerr=0; korph=0; kmul=0; kunr=0
while read -r i p; do
  if [ "$(cat "$BOX/k/$i.rc")" != 0 ] || ! grep -q '^TYPES ' "$BOX/k/$i.types"; then
    kref=$((kref+1)); echo "  checker refused  $p  ($(grep -v '^TYPES-CHECK-ERROR' "$BOX/k/$i.err" | head -1 | cut -c1-110))"
  else
    set -- $(sed -n 's/^TYPES recorded .* multi \([0-9]*\) unresolved \([0-9]*\) orphans \([0-9]*\) check-errors \([0-9]*\)$/\1 \2 \3 \4/p' "$BOX/k/$i.types")
    kmul=$((kmul+$1)); kunr=$((kunr+$2)); korph=$((korph+$3)); kerr=$((kerr+$4))
    [ "$4" = 0 ] || echo "  checker's recording check found $4 errors in $p: $(grep -m1 '^TYPES-CHECK-ERROR' "$BOX/k/$i.err" | cut -c1-140)"
  fi
done < "$BOX/k/list"
echo "types: the checker typed $(( $(echo $PROGS | wc -w) - kref )) programs in $tkchk ms ($kref refused);" \
     "over the whole of each (stdlib included): $kmul positions with two types, $kunr unresolved, $korph orphans, $kerr check errors"

# ---- export, one process per program, so a program the compiler refuses costs only itself
s=$(date +%s%N)
: > "$BOX/facts"
nprog=0; refused=0; moved=0; same_out=0; diff_out=0; i=0
for p in $PROGS; do
  i=$((i+1))
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
  # one block per program; a line said twice (a form compiled twice) is one fact. A CType is one
  # fact per node and type, whichever function it was typed in (an inlined body is typed once
  # per caller): the first `in` is kept.
  sed -n '/^"PROG /,/^"END"/p' "$BOX/one" | grep -E '^"(PROG|FILE|CArg|CParam|CType)[ "]' \
    | awk '!seen[$0]++' | awk '$1 != "\"CType" || !ct[$2" "$3" "$4" "$6]++' >> "$BOX/facts"
  # the checker's types for the files this program was read from, re-spelled with the
  # compiler's path for each (the two name a loaded file differently: `elf/src/../lib/x.wat`)
  grep '^"FILE ' "$BOX/one" | sed 's/^"FILE //; s/"$//' | awk '!s[$0]++' | while read -r f; do
    printf '%s\t%s\n' "$(realpath -m --relative-to="$REPO" "$f")" "$f"; done > "$BOX/map"
  cut -f2 "$BOX/k/$i.types" | grep -v '^TYPES' | sort -u | while read -r l; do
    printf '%s\t%s\n' "$l" "$(realpath -m --relative-to="$REPO" "$l")"; done > "$BOX/labels"
  awk -F'\t' 'FILENAME==ARGV[1] { comp[$1]=$2; next }
               FILENAME==ARGV[2] { if ($2 in comp) lab[$1]=comp[$2]; next }
               ($1=="TYPE" || $1=="UNRESOLVED") && ($2 in lab) {
                 if ($1=="TYPE") printf "\"KType\\t%s\\t%s\\t%s\\t%s\\t%s\"\n", lab[$2], $3, $4, $5, $6
                 else            printf "\"KUnres\\t%s\\t%s\\t%s\\t%s\"\n", lab[$2], $3, $4, $5 }' \
      "$BOX/map" "$BOX/labels" "$BOX/k/$i.types" >> "$BOX/facts"
  echo '"END"' >> "$BOX/facts"
done
texp=$(ms $s)
echo "rules: exported $nprog programs in $texp ms ($refused refused by the compiler);" \
     "export-on == export-off for $((nprog-moved)) of $nprog; $same_out corpus binaries byte-identical to elf/out, $diff_out not"
[ -n "${RULES_KEEP:-}" ] && cp "$BOX/facts" "$RULES_KEEP"

# ---- the check
s=$(date +%s%N)
timeout -s KILL 1800 "$WAT" tools/rules/check.wat < "$BOX/facts" > "$BOX/check" 2>&1; rc=$?
tchk=$(ms $s)
sed -e 's/^"//' -e 's/"$//' -e 's/\\"/"/g' "$BOX/check" > "$BOX/check.txt"
[ -n "${RULES_DETAIL:-}" ] && cp "$BOX/check.txt" "$RULES_DETAIL"
grep -v '^  ~' "$BOX/check.txt" | grep -v '^rules: [^T].*CONFLICT 0  unplaced 0  unjoined 0  mismatch 0$' \
  | grep -v '^types: [^T].*TYPE-CONFLICT 0  partial [0-9]*  untranslatable 0  unresolved 0  checker-multi 0  compiler-multi 0 '
echo "rules: checked in $tchk ms; total $(ms $t0) ms"
[ $rc -eq 0 ] || { echo "rules: the checker died (exit $rc)"; exit 2; }
# ---- the verdict, from the two TOTAL lines. A missing one is a check that was not made.
rtl=$(grep '^rules: TOTAL ' "$BOX/check.txt"); ttl=$(grep '^types: TOTAL ' "$BOX/check.txt")
[ -n "$rtl" ] && [ -n "$ttl" ] || { echo "rules: the checker printed no TOTAL -- no verdict"; exit 2; }
num () { printf '%s\n' "$1" | sed -n "s/.*  $2 \([0-9]*\).*/\1/p"; }
bad=0
for f in CONFLICT unplaced unjoined mismatch; do
  v=$(num "$rtl" "$f"); [ "${v:-x}" = 0 ] || { echo "rules: FAIL -- $f ${v:-?} (must be 0)"; bad=1; }
done
for f in TYPE-CONFLICT untranslatable unresolved; do
  v=$(num "$ttl" "$f"); [ "${v:-x}" = 0 ] || { echo "types: FAIL -- $f ${v:-?} (must be 0)"; bad=1; }
done
[ $moved -eq 0 ] || bad=1
exit $bad
