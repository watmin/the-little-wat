#!/usr/bin/env bash
# tools/bracket-os-oracle.sh — what speedup can this machine actually reach on this work?
#
# probes/bracket/scaling.wat measures :wat::bracket::map on a thread pool and a process pool.
# A ratio alone cannot say whether a shortfall is the pool or the hardware: a laptop drops its
# turbo clock when every core is busy, and this one is 4 P-cores + 8 E-cores, so "16x" was never
# available. This supplies the control — the SAME burn, the SAME interpreter, run as N independent
# OS processes, with the OS doing the scheduling. That is the ceiling wat's own pool is measured
# against.
set -uo pipefail
RS="${1:-../wat-rs}"; WAT="$RS/target/release/wat"; N="${2:-16}"
T="${TMPDIR:-/tmp}/bracket-oracle"; mkdir -p "$T"
cat > "$T/unit.wat" <<'EOF'
(:wat::core::defn :u::burn-loop [k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:u::burn-loop (:wat::core::- k 1) (:wat::core::rem (:wat::core::+ acc k) 1000003))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::burn-loop 100000 0)))
EOF
s=$(date +%s%N); for i in $(seq "$N"); do timeout -s KILL 120 "$WAT" "$T/unit.wat" >/dev/null 2>&1; done; e=$(date +%s%N)
seqms=$(( (e-s)/1000000 ))
s=$(date +%s%N); for i in $(seq "$N"); do timeout -s KILL 120 "$WAT" "$T/unit.wat" >/dev/null 2>&1 & done; wait; e=$(date +%s%N)
parms=$(( (e-s)/1000000 ))
echo "$N OS processes, sequential: ${seqms} ms"
echo "$N OS processes, concurrent: ${parms} ms"
python3 -c "print(f'OS-process speedup: {$seqms/$parms:.2f}x  (the ceiling for this machine and this work)')"
