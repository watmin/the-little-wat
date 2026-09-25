#!/usr/bin/env bash
# tools/elf-run.sh: the two steps wat cannot take, and the check it cannot make.
#
# wat can compute the bytes of an ELF and write them, and elf/hello.wat and elf/compile.wat both
# verify what they wrote by reading it back. What wat cannot do is set the executable bit
# (`:wat::io::` has no chmod) or run the result (`:wat::kernel::spawn-process` forks a wat child
# that evaluates a source string, not an arbitrary program). This script does those, and then the
# check that matters most: for every program in elf/src/, the COMPILED BINARY and the wat
# INTERPRETER must print exactly the same thing and exit the same way.
#
# Exit code: 0 when every binary behaves and every differential comparison agrees.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "elf-run: no wat binary at $WAT"; exit 2; }
fail=0

# **every read out of a container goes through `:c::read-out`** (F-188, stone 0a). Static, and
# first: a new read verb that bypasses the count is a wrong answer that every run below can miss.
tools/reads.sh || exit 1

# SKIP_BUILD=1 uses whatever is already in elf/out/ instead of rebuilding it through the
# interpreter. tools/bootstrap.sh --fast sets it, because it has just built everything with a
# compiled compiler and rebuilding the same bytes at 150x the cost proves nothing.
echo "== hand-written: elf/hello.wat =="
if [ -z "${SKIP_BUILD:-}" ]; then "$WAT" elf/hello.wat || exit 1; fi
chmod +x elf/out/hello.elf elf/out/exit42.elf
out=$(./elf/out/hello.elf); rc=$?
[ "$out" = "hello from wat" ] && [ $rc -eq 0 ] || { echo "FAIL hello.elf: '$out' exit $rc"; fail=1; }
echo "hello.elf   printed '$out', exited $rc"
./elf/out/exit42.elf; rc=$?
[ $rc -eq 42 ] || { echo "FAIL exit42.elf: exit $rc"; fail=1; }
echo "exit42.elf  exited $rc, which wat computed as 6 * 7"

echo
echo "== compiled from wat source: elf/compile.wat =="
if [ -z "${SKIP_BUILD:-}" ]; then "$WAT" elf/compile.wat || exit 1; fi
chmod +x elf/out/*.elf

echo
echo "== the check that matters: compiled binary vs wat interpreter =="
# The interpreter's answer depends only on the source and on which wat binary is asking, so it
# is cached. A change to the COMPILER -- which is most changes -- then costs no interpreter runs
# at all, and the suite goes from thirty-odd seconds to about one.
# **counted, not asserted.** This summary used to be a sentence with the numbers written into
# it, and it went stale the moment a probe was added -- it claimed twenty-five agreeing programs
# on a run where twenty-seven did.
agreed=0; natively=0; refused=0; trapped=0
ORACLE="elf/out/.oracle"; mkdir -p "$ORACLE"
WATID=$(stat -c%s,%Y "$WAT" 2>/dev/null | tr ',' '-')
oracle () {   # source path -> its output on stdout, its exit status as the return
  local src="$1" key out
  key="$ORACLE/$(basename "$src" .wat).$(sha256sum "$src" | cut -c1-16).$WATID"
  if [ -f "$key" ]; then
    tail -n +2 "$key"; return "$(head -1 "$key")"
  fi
  out=$("$WAT" "$src" 2>&1); local rc=$?
  { echo "$rc"; printf '%s\n' "$out"; } > "$key"
  printf '%s\n' "$out"; return $rc
}

# **This list used to be written inline, and it went stale the moment a program was added.**
# The header above already says that happened once. It happened AGAIN when elf/src/fnref.wat
# and elf/src/fnvec.wat arrived: both compiled, neither compared, and the summary still said
# "30 agree" while building two more binaries. So the list is a variable now, and the coverage
# guard below fails when anything in elf/src is not accounted for.
COMPARED="four arith greet branch fib bench strings shadow churn deep logic vectors pvec assocn
          memory linear moved freed strverbs strown extremes nnegsub select counted bits codeat
          reader diag fileio asmbits fnref fnvec enums shapes matchval option escape
          borrowed"
# collapsed to single spaces: the guard below matches with a glob on " $n ", and a name that
# happened to sit at the end of a line was followed by a NEWLINE, so it read as uncovered.
COMPARED=$(echo $COMPARED)
for name in $COMPARED; do
  src="elf/src/$name.wat"; bin="elf/out/$name.elf"
  interp=$(oracle "$src"); irc=$?
  # **a timeout, because a miscompiled program does not fail -- it SPINS.** One of these ran
  # for seven minutes at 99% of a core after the harness itself had been killed, holding ETXTBSY
  # on its own file so every later `write-hex` failed, and slowing every measurement taken
  # meanwhile. R-005 is about `wat` runs; it applies to the binaries too.
  native=$(timeout -s KILL 60 "./$bin" 2>&1); nrc=$?
  agreed=$((agreed+1))
  if [ "$interp" = "$native" ] && [ $irc -eq $nrc ]; then
    printf '%-8s agree (exit %d, %4s bytes native)  %s\n' "$name" "$nrc" "$(stat -c%s "$bin")" \
           "$(printf '%s' "$native" | tr '\n' ' ' | cut -c1-46)"
  else
    echo "FAIL $name: interpreter and binary differ"
    diff <(printf '%s\n' "$interp") <(printf '%s\n' "$native") | sed 's/^/      /'
    fail=1
  fi
done

# **the coverage guard**: every program in elf/src must be compared, or named here as to why
# not. A program that is compiled but never checked is worse than one that does not exist --
# it inflates the binary count while proving nothing, which is exactly what fnref and fnvec
# did on the build that added them.
uncovered=0
for f in elf/src/*.wat; do
  n=$(basename "$f" .wat)
  case " $COMPARED " in *" $n "*) continue ;; esac
  echo "   UNCOVERED: elf/src/$n.wat is compiled but never compared -- add it to COMPARED"
  uncovered=$((uncovered+1))
done
[ $uncovered -eq 0 ] || fail=1

# churn allocates 2.4 MB out of a 1 MiB heap and gives all of it back; before the compiler
# learned to release at statement boundaries it died here with a segmentation fault.
echo "         (churn allocates 2.4 MB against a 1 MiB heap -- it only agrees because the"
echo "          compiler releases what a discarded statement allocated: C-120)"
echo "         (deep is 1000000 tail calls -- wat eliminates them and so does this"
echo "          compiler, on the same frame: C-121)"
echo "         (linear proves BOTH halves of the in-place conj guard: remove the share"
echo "          increment and base comes back with 4 elements instead of 3: C-127)"
echo "         (freed allocates 650 MB -- ten heaps -- and completes, which it can only do"
echo "          if the space is reused; without the release it dies at round ten: C-128)"
echo
echo "== native-only: syscalls the interpreter has no implementation of (F-119) =="
check_native () {   # name, expected output (newline separated)
  local name="$1" want="$2" bin="elf/out/$1.elf"
  local got rc
  got=$(timeout -s KILL 20 "./$bin" 2>&1); rc=$?
  natively=$((natively+1))
  if [ "$got" = "$want" ] && [ $rc -eq 0 ]; then
    printf '%-10s %4s bytes  %s\n' "$name" "$(stat -c%s "$bin")" "$(printf '%s' "$got" | tr '\n' ' ')"
  else
    echo "FAIL $name: got '$got' (exit $rc), wanted '$want'"
    fail=1
  fi
}
# fork: parent prints 1, child prints 2 and exits 7, parent reads that status back, then 1 1 4
check_native fork     "$(printf '1\n2\n7\n1\n1\n4')"
# clone with CLONE_VM: the child writes 22 into a page the parent mmap'd, and the parent sees it
check_native thread   "$(printf '11\n22')"
# four threads, each writing its own slot; 100 + 200 + 300 + 400
check_native threads4 "1000"

echo
# a measurement, not a test, and the interpreted half of it is four seconds -- which is most of
# what tools/loop.sh would otherwise pay per iteration
if [ -z "${SKIP_BUILD:-}" ]; then
echo "== what compiling is worth: fib(27), the same source both ways =="
s=$(date +%s%N); "$WAT" elf/src/bench.wat >/dev/null 2>&1; i=$(( ($(date +%s%N)-s)/1000000 ))
s=$(date +%s%N); ./elf/out/bench.elf  >/dev/null 2>&1; n=$(( ($(date +%s%N)-s)/1000000 ))
[ "$n" -lt 1 ] && n=1
printf 'interpreted %5s ms    native %3s ms    %sx\n' "$i" "$n" "$(( i / n ))"
fi

echo
echo "== and the compiler refuses what it cannot translate =="
# Both files are generated from elf/compile.wat by tools/gen-refuse.sh, so they are the SAME
# compiler; both programs are valid wat that the interpreter runs.
#
# **And that is only true if they have been REGENERATED** (F-152). They are generated but
# committed, and nothing regenerated them, so they drifted across seven changes to
# elf/compile.wat while still passing -- the injected error kept firing for its own reason
# and the stale copy underneath it went unnoticed. A negative test that has drifted from the
# thing it tests proves nothing, which gen-refuse.sh's own header says. So check.
stale=0
for f in elf/refuse.wat elf/refuse-nonascii.wat elf/refuse-arity.wat elf/refuse-ptradd.wat elf/refuse-variant.wat; do
  [ -f "$f" ] || continue
  # the generated body is elf/compile.wat up to its driver; compare that, not the driver
  if ! diff -q <(sed '/^(:wat::core::defn :user::main/,$d' elf/compile.wat) \
                <(sed -e '1,/^$/d' -e '/^(:wat::core::defn :user::main/,$d' "$f") >/dev/null; then
    echo "   STALE: $f has drifted from elf/compile.wat -- run tools/gen-refuse.sh"
    stale=$((stale+1))
  fi
done
[ $stale -eq 0 ] || fail=1
refuses () {   # driver, needle, what it proves
  local drv="$1" needle="$2" why="$3" msg
  refused=$((refused+1))
  msg=$("$WAT" "$drv" 2>&1)
  if printf '%s' "$msg" | grep -qF "$needle"; then
    echo "$why"
  else
    echo "FAIL: $drv did not refuse as expected"
    printf '%s\n' "$msg" | head -3 | sed 's/^/      /'
    fail=1
  fi
}
# i64 TRAPS, and a compiled program must trap too -- both sides stop, and say why (F-125)
echo
echo "== and the arithmetic traps, both ways =="
got=$(./elf/out/overflow.elf 2>&1); rc=$?
int=$("$WAT" elf/bad/overflow.wat 2>&1); irc=$?
if printf '%s' "$got" | grep -qF 'i64 overflow' && [ $rc -ne 0 ] \
   && printf '%s' "$int" | grep -qF 'IntegerOverflow'; then
  trapped=$((trapped+1))
  echo "  (+ 9223372036854775807 1) stops both ways -- compiled exit $rc, interpreted refuses"
  dgot=$(./elf/out/divzero.elf 2>&1); drc=$?
  dint=$("$WAT" elf/bad/divzero.wat 2>&1)
  if printf '%s' "$dgot" | grep -qF 'division by zero' && [ $drc -ne 0 ] \
     && printf '%s' "$dint" | grep -qF 'DivisionByZero'; then
    trapped=$((trapped+1))
    echo "  (quot 1 0) stops both ways too -- compiled exit $drc, not SIGFPE"
    # C-166 drops the check on `(- x k)` where the branch proved `x >= 0`. A `let` that rebinds
    # the name binds a different value, and the proof must not travel with the name.
    sgot=$(./elf/out/nnegshadow.elf 2>&1); src2=$?
    sint=$("$WAT" elf/bad/nnegshadow.wat 2>&1)
    if printf '%s' "$sgot" | grep -qF 'i64 overflow' && [ $src2 -ne 0 ] \
       && printf '%s' "$sint" | grep -qF 'IntegerOverflow'; then
      trapped=$((trapped+1))
      echo "  and a rebound name loses the proof -- nnegshadow stops both ways, exit $src2"
      # C-170 bounds a counted loop's parameter and drops the checks that bound proves dead.
      # A multiply the bound does NOT cover must still stop.
      cgot=$(./elf/out/countedovf.elf 2>&1); crc=$?
      cint=$("$WAT" elf/bad/countedovf.wat 2>&1)
      if printf '%s' "$cgot" | grep -qF 'i64 overflow' && [ $crc -ne 0 ] \
         && printf '%s' "$cint" | grep -qF 'IntegerOverflow'; then
        trapped=$((trapped+1))
        echo "  and a counted bound licenses no real overflow -- countedovf stops, exit $crc"
      else
        echo "  FAIL: C-170 elided a check the loop bound does not cover (compiled rc=$crc)"
        printf '%s\n' "$cgot" | head -2 | sed 's/^/      /'
        fail=1
      fi
    else
      echo "  FAIL: C-166 elided a check that a rebinding should have kept (compiled rc=$src2)"
      printf '%s\n' "$sgot" | head -2 | sed 's/^/      /'
      fail=1
    fi
  else
    echo "  FAIL: division by zero did not stop both ways (compiled rc=$drc)"
    printf '%s\n' "$dgot" | head -2 | sed 's/^/      /'
    fail=1
  fi
else
  echo "  FAIL: overflow did not stop both ways (compiled rc=$rc irc=$irc)"
  printf '%s\n' "$got" | head -2 | sed 's/^/      /'
  fail=1
fi

# **the type pass meets it first** (excursus 002 stone 4): `println` asks its argument's type
# before anything is emitted, and a call the pass does not know is a refusal naming the form AND
# where it is -- it used to be typed `i64` and refused one step later, by the generator.
refuses elf/refuse.wat          'cannot type a call this pass does not know at elf/bad/unsupported.wat 2 23: (wat.core/str 10)' \
        "refused elf/bad/unsupported.wat, naming form and place: (wat.core/str 10) at 2:23"
refuses elf/refuse-nonascii.wat 'not encodable' \
        "refused elf/bad/nonascii.wat, naming the character:  e-acute (F-120: bytes vs chars)"
refuses elf/refuse-arity.wat    'wrong number of arguments' \
        "refused elf/bad/arity.wat, naming the call:         (user/two 1 2 3)  (F-128)"
refuses elf/refuse-ptradd.wat   'arithmetic on a str' \
        "refused elf/bad/ptradd.wat, naming the type:        arithmetic on a str  (F-128)"
# **a variant is assignable to its enum and to nothing else** (excursus 002 stone 5): a `None`
# where a `Some` is wanted is refused, naming the call -- as `wat --check` refuses it
refuses elf/refuse-variant.wat  'cannot pass argument 0 of user/needs-some: it wants (:user::Opt.Some :- [:wat::core::String]) and is given (:user::Opt.None :- [:?]) at elf/probe/variant-param-wrong.wat 12 25: (user/needs-some (:user::Opt.None {}))' \
        "refused elf/probe/variant-param-wrong.wat, naming the call: a None where a Some is wanted (stone 5)"

# **the compiler must agree with itself at every boundary** (excursus 002 stone 1). The compiler,
# asked, says the type it gave every argument of every call to a user function and every
# parameter of every `defn`; wat-rs's rete joins the two and reports each argument whose type is
# not its parameter's.
echo
# Excursus 002 stone 2 rides the same run: the type the compiler gave every node it typed, joined
# by position with the type wat-rs's own checker gave it.
#
# **MUST BE ZERO** since stone 4: one boundary conflict or one type conflict fails this run, and
# so does a join that is not whole (see tools/rules.sh). Stones 1 and 2 ran it in report mode.
echo "== the compiler agrees with itself, and with the language: tools/rules.sh (must be zero) =="
rout=$(tools/rules.sh 2>&1); rrc=$?
printf '%s\n' "$rout" | sed 's/^/  /'
case $rrc in
  0) ;;
  1) echo "  FAIL: the compiler disagrees -- with itself, with the language, or the export moved a byte"; fail=1 ;;
  *) echo "  FAIL: tools/rules.sh could not make the check (exit $rrc)"; fail=1 ;;
esac
rtot=$(printf '%s\n' "$rout" | sed -n 's/.*TOTAL over \([0-9]*\) programs.*pairs \([0-9]*\)  agree \([0-9]*\)  variant \([0-9]*\)  CONFLICT \([0-9]*\).*/\5 conflicts in \2 argument-parameter pairs (\3 equal, \4 a variant to its enum) over \1 programs/p')
ttot=$(printf '%s\n' "$rout" | sed -n 's/^types: TOTAL over \([0-9]*\) programs.*joined \([0-9]*\)  agree \([0-9]*\)  refined \([0-9]*\)  TYPE-CONFLICT \([0-9]*\) .*/\5 type conflicts in \2 nodes both typed (\3 agree, \4 refined) over \1 programs/p')

echo
if [ $fail -eq 0 ]; then
  echo "elf-run: ok -- $(ls elf/out/*.elf | wc -l) native binaries. $agreed agree with the interpreter;"
  echo "         $natively more use syscalls it has no implementation of (F-119); $refused refusals and"
  echo "         $trapped traps, both ways. rules: ${rtot:-no total}."
  echo "         types: ${ttot:-no total}."
else
  echo "elf-run: FAILED"
fi
exit $fail
