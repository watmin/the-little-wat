#!/usr/bin/env bash
# tools/bench-coll.sh — collections baseline. One command. Every exit checked.
# Never pipes a measured program. Size is a file / argv, not a literal (F-184).
# A wat run whose resident set passes 8 GiB is killed and recorded (STOP-2).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
WAT="${WAT:-/home/watmin/.cache/wat-kw-007/release/wat}"
[ -x "$WAT" ] || WAT="../wat-rs/target/release/wat"
[ -x "$WAT" ] || { echo "bench-coll: no wat at $WAT"; exit 2; }
REPS="${REPS:-5}"
SIZES="${SIZES:-10000 100000 1000000}"
OUT="${OUT:-/tmp/bench-coll}"
mkdir -p "$OUT"
# maxrss execs with execv, so every program path has to be absolute.
CLJ="${CLJ:-/home/watmin/.local/share/mise/installs/clojure/latest/bin/clj}"
C="$OUT/coll-c"
RS="$OUT/coll-rs"
MAX="$OUT/maxrss"
gcc -O2 -o "$C" elf/bench/coll/coll.c || exit 2
gcc -O2 -o "$MAX" elf/bench/maxrss.c || exit 2
( cd elf/bench/coll/rust && CARGO_TARGET_DIR="$OUT/rs-target" cargo build --release --offline --quiet ) || exit 2
cp "$OUT/rs-target/release/coll" "$RS" || exit 2

# compile the wat programs with one interpreted run of the compiler, if asked
if [ "${COMPILE:-1}" = 1 ]; then
  python3 - << 'PY'
import pathlib
root = pathlib.Path(".")
text = (root/"elf/compile.wat").read_text().splitlines(True)
n = next(i for i,l in enumerate(text) if "defn :user::main" in l)
files = ["w1","w2","w3","w4","w5","w1t","w2t","w3t","w4t","w5t","clock"]
body = "\n".join(f'    (:c::compile "elf/bench/coll/{f}.wat" "/tmp/bench-coll/{f}.elf")' for f in files)
drv = "".join(text[:n]) + "(:wat::core::defn :user::main [] -> :wat::core::nil\n  (:wat::core::do\n" + body + "\n    (:wat::kernel::println \"compile: ok\")))\n"
(root/"elf/drv-coll.wat").write_text(drv)
PY
  timeout -s KILL 400 "$WAT" elf/drv-coll.wat > "$OUT/compile.log" 2>&1 || {
    echo "bench-coll: compile failed"; tail -5 "$OUT/compile.log"; rm -f elf/drv-coll.wat; exit 2; }
  rm -f elf/drv-coll.wat
  grep -q 'compile: ok' "$OUT/compile.log" || { echo "bench-coll: compile did not finish"; exit 2; }
  chmod +x "$OUT"/w*.elf "$OUT/clock.elf"
fi

# clock: monotonic, and a wrong arity is refused
echo 1 > elf/bench/coll/n.txt
c=$("$OUT/clock.elf" | tr -d '"'); crc=$?
[ "$crc" -eq 0 ] && [ "$c" = 1 ] || { echo "bench-coll: clock not monotonic ($c rc $crc)"; exit 2; }
# arity: a direct compile of the bad program must name clock-ns arity. Reuse the log if present,
# else compile just that file.
python3 - << 'PY'
import pathlib
root = pathlib.Path(".")
text = (root/"elf/compile.wat").read_text().splitlines(True)
n = next(i for i,l in enumerate(text) if "defn :user::main" in l)
drv = "".join(text[:n]) + """(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c::compile "elf/bench/coll/clock-arity.wat" "/tmp/bench-coll/clock-arity.elf")
    (:wat::kernel::println "compile: ok")))
"""
(root/"elf/drv-coll.wat").write_text(drv)
PY
timeout -s KILL 180 "$WAT" elf/drv-coll.wat > "$OUT/arity.log" 2>&1 || true
rm -f elf/drv-coll.wat
grep -q 'clock-ns arity' "$OUT/arity.log" || { echo "bench-coll: clock arity was not refused"; exit 2; }
echo "bench-coll: clock ok"

answer_of () { tr -d '"' < "$1" | grep '^ANSWER ' | head -1 | awk '{print $2}'; }

# Max VmRSS (KiB) of pid and its descendants. The reservation's RSS is the child, not perf.
rss_under () {
  local max=0
  _rss_walk () {
    local p=$1 c rss
    rss=$(awk '/^VmRSS:/{print $2; exit}' "/proc/$p/status" 2>/dev/null || true)
    if [ -n "${rss:-}" ] && [ "$rss" -gt "$max" ]; then max=$rss; fi
    for c in $(ps -o pid= --ppid "$p" 2>/dev/null); do
      _rss_walk "$c"
    done
  }
  _rss_walk "$1"
  echo "$max"
}

# Run one opponent. Kills the process group if any descendant VmRSS passes 8 GiB.
# status file: $OUT/status  ok | exceeded | timeout | exit N
run_limited () {
  local secs="$1"; shift
  local log="$1"; shift
  setsid "$@" > "$log" 2>"$log.err" &
  local pid=$!
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    local rss
    rss=$(rss_under "$pid")
    if [ -n "$rss" ] && [ "$rss" -gt 8000000 ]; then
      kill -9 -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo exceeded > "$OUT/status"
      return 2
    fi
    i=$((i+1))
    if [ "$i" -gt $((secs*10)) ]; then
      kill -9 -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo timeout > "$OUT/status"
      return 3
    fi
    sleep 0.1
  done
  wait "$pid"; local rc=$?
  if [ "$rc" -ne 0 ]; then echo "exit $rc" > "$OUT/status"; return "$rc"; fi
  echo ok > "$OUT/status"
  return 0
}

perf_one () {
  # $1 log $2 secs, rest command. instructions and cycles on stdout: ins,cyc or FAIL or EXCEEDED
  local log="$1" secs="$2"; shift 2
  local err="$OUT/perf.err"
  setsid taskset -c 0 perf stat -e cpu_core/instructions/,cpu_core/cycles/ -x, -- \
    timeout -s KILL "$secs" "$@" > "$log" 2>"$err" &
  local pid=$!
  local i=0
  local blown=0
  while kill -0 "$pid" 2>/dev/null; do
    local rss
    rss=$(rss_under "$pid")
    if [ -n "$rss" ] && [ "$rss" -gt 8000000 ]; then
      kill -9 -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "EXCEEDED"
      return 1
    fi
    i=$((i+1))
    if [ "$i" -gt $((secs*10)) ]; then
      kill -9 -- "-$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "FAIL"
      return 1
    fi
    sleep 0.1
  done
  wait "$pid" || blown=1
  local ins cyc
  ins=$(awk -F, '/instructions/{print $1; exit}' "$err")
  cyc=$(awk -F, '/cycles/{print $1; exit}' "$err")
  if [ "$blown" -ne 0 ] || [ -z "${ins:-}" ] || [ -z "${cyc:-}" ]; then
    echo "FAIL"
    return 1
  fi
  echo "$ins,$cyc"
}

declare -A BEST_INS BEST_CYC MIN_CYC MAX_CYC
floor_key () { echo "$1"; }

# An interpreter or a C full-copy can ask for tens of gigabytes. Cap their address
# space at 8 GiB so malloc fails instead of pushing the machine into swap.
# Wat is not capped: its reservation is larger than 8 GiB of virtual address space.
ASCAP=$((8*1024*1024*1024))

if [ "${APPEND:-0}" = 1 ]; then
  echo "bench-coll: appending from ${START_W:-w1} ${START_N:-first}"
else
  echo "workload size opponent ins cyc rss answer" > "$OUT/table.tsv"
  echo "workload size opponent p50 p99 p999 max" > "$OUT/tails.tsv"
  echo "workload size opponent note" > "$OUT/notes.tsv"
fi

armed=1
[ -n "${START_W:-}" ] && armed=0
for w in w1 w2 w3 w4 w5; do
  for n in $SIZES; do
    if [ "$armed" = 0 ]; then
      if [ "$w" = "$START_W" ] && [ "$n" = "${START_N:-$n}" ]; then armed=1; else continue; fi
    fi
    echo "$n" > elf/bench/coll/n.txt
    echo "== $w $n =="
    # answers first, one each, so a disagreement stops the size
    declare -A ANS
    run_opp () {
      local name="$1" secs="$2"; shift 2
      if run_limited "$secs" "$OUT/run.log" "$@"; then
        ANS[$name]=$(answer_of "$OUT/run.log")
        echo "  $name answer ${ANS[$name]}"
      else
        echo "  $name $(cat "$OUT/status")"
        echo "$w $n $name $(cat "$OUT/status")" >> "$OUT/notes.tsv"
        ANS[$name]="FAIL"
      fi
    }
    run_opp wat 600 "$OUT/$w.elf"
    run_opp interp 900 /usr/bin/prlimit --as="$ASCAP" -- "$WAT" "elf/bench/coll/$w.wat"
    run_opp rust 600 "$RS" "$w" "$n" plain
    # W1–W3: rust is the persistent path; rust-own / clj-own are the one-owner idiom.
    if [ "$w" = w1 ] || [ "$w" = w2 ] || [ "$w" = w3 ]; then
      run_opp rust-own 600 "$RS" "${w}m" "$n" plain
      run_opp clj-own 900 "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain own
    fi
    run_opp c-free 600 /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" free plain
    run_opp c-leak 600 /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" leak plain
    # clojure cold answer (also the cold tail if timed separately)
    run_opp clj 900 "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain
    base="${ANS[wat]}"
    if [ "$base" = FAIL ] || [ -z "$base" ]; then
      echo "bench-coll: wat failed $w $n — larger sizes of $w are not started"
      break
    fi
    for name in interp rust c-free c-leak clj; do
      if [ "${ANS[$name]}" != "$base" ]; then
        echo "STOP-1 $w $n $name answer ${ANS[$name]} wat $base"
        echo "$w $n $name STOP-1 answer ${ANS[$name]} wat $base" >> "$OUT/notes.tsv"
      fi
    done
    # interleaved instructions, REPS times. A non-finish is recorded once, not repeated.
    unset DEAD
    declare -A DEAD
    take_perf () {
      local name="$1"; shift
      local key="$w $n $name"
      if [ -n "${DEAD[$key]:-}" ]; then return 0; fi
      local got
      got=$(perf_one "$OUT/p.log" 600 "$@") || true
      if [ "$got" = EXCEEDED ] || [ "$got" = FAIL ] || [ -z "$got" ]; then
        echo "$w $n $name ${got:-perf-fail}" >> "$OUT/notes.tsv"
        DEAD[$key]=1
        return 0
      fi
      local ins="${got%%,*}" cyc="${got#*,}"
      if [ -z "${BEST_INS[$key]:-}" ] || [ "$ins" -lt "${BEST_INS[$key]}" ]; then
        BEST_INS[$key]=$ins; BEST_CYC[$key]=$cyc
      fi
      if [ -z "${MIN_CYC[$key]:-}" ] || [ "$cyc" -lt "${MIN_CYC[$key]}" ]; then MIN_CYC[$key]=$cyc; fi
      if [ -z "${MAX_CYC[$key]:-}" ] || [ "$cyc" -gt "${MAX_CYC[$key]}" ]; then MAX_CYC[$key]=$cyc; fi
      echo "$w $n $name $ins $cyc" >> "$OUT/reps.tsv"
    }
    for ((r=1; r<=REPS; r++)); do
      take_perf wat "$OUT/$w.elf"
      take_perf interp /usr/bin/prlimit --as="$ASCAP" -- "$WAT" "elf/bench/coll/$w.wat"
      take_perf rust "$RS" "$w" "$n" plain
      if [ "$w" = w1 ] || [ "$w" = w2 ] || [ "$w" = w3 ]; then
        take_perf rust-own "$RS" "${w}m" "$n" plain
        take_perf clj-own "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain own
      fi
      take_perf c-free /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" free plain
      take_perf c-leak /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" leak plain
      take_perf clj "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain
    done
    # RSS one shot each. maxrss prints KiB; its child stdout is /dev/null.
    take_rss () {
      local name="$1"; shift
      local rss
      if run_limited 600 "$OUT/rss.log" "$MAX" "$@"; then
        rss=$(tr -d '[:space:]' < "$OUT/rss.log")
      else
        rss=$(cat "$OUT/status")
      fi
      echo "$w $n $name ${BEST_INS["$w $n $name"]:-} ${BEST_CYC["$w $n $name"]:-} $rss ${ANS[$name]:-}" >> "$OUT/table.tsv"
    }
    take_rss wat "$OUT/$w.elf"
    take_rss interp /usr/bin/prlimit --as="$ASCAP" -- "$WAT" "elf/bench/coll/$w.wat"
    take_rss rust "$RS" "$w" "$n" plain
    if [ "$w" = w1 ] || [ "$w" = w2 ] || [ "$w" = w3 ]; then
      take_rss rust-own "$RS" "${w}m" "$n" plain
      take_rss clj-own "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain own
    fi
    take_rss c-free /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" free plain
    take_rss c-leak /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" leak plain
    take_rss clj "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold plain
    # tails
    tail_one () {
      local name="$1" secs="$2"; shift 2
      if run_limited "$secs" "$OUT/tail.log" "$@"; then
        local line
        line=$(tr -d '"' < "$OUT/tail.log" | grep '^TAIL ' | head -1)
        echo "$w $n $name ${line#TAIL }" >> "$OUT/tails.tsv"
      else
        echo "$w $n $name $(cat "$OUT/status")" >> "$OUT/tails.tsv"
      fi
    }
    tail_one wat 900 "$OUT/${w}t.elf"
    tail_one rust 900 "$RS" "$w" "$n" timed
    if [ "$w" = w1 ] || [ "$w" = w2 ] || [ "$w" = w3 ]; then
      tail_one rust-own 900 "$RS" "${w}m" "$n" timed
      tail_one clj-own 900 "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold timed own
    fi
    tail_one c-free 900 /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" free timed
    tail_one c-leak 900 /usr/bin/prlimit --as="$ASCAP" -- "$C" "$w" "$n" leak timed
    tail_one clj-cold 900 "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" cold timed
    tail_one clj-warm 1200 "$CLJ" -Sdeps '{:paths ["elf/bench/coll"]}' -M -m coll "$w" "$n" warm timed
  done
done

# From every recorded repetition, including a run this script resumed.
echo "key min_cyc max_cyc spread" > "$OUT/floors.tsv"
awk '{
  key=$1" "$2" "$3; c=$5+0
  if (!(key in min) || c < min[key]) min[key]=c
  if (!(key in max) || c > max[key]) max[key]=c
}
END {
  for (k in min) {
    b=min[k]; a=max[k]
    printf "%s %d %d %.6f\n", k, b, a, (b==0)?0:(a-b)/b
  }
}' "$OUT/reps.tsv" >> "$OUT/floors.tsv"

echo "bench-coll: table $OUT/table.tsv"
echo "bench-coll: tails $OUT/tails.tsv"
echo "bench-coll: notes $OUT/notes.tsv"
