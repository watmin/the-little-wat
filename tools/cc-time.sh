#!/usr/bin/env bash
# tools/cc-time.sh: time the compiler compiling everything, without measuring a crash.
#
# **A self-hosting compiler cannot be timed where it lives.** `elf/out/compiler.elf` writes
# `elf/out/compiler.elf`, and the kernel holds ETXTBSY on the text of a running image -- so the
# run dies with `assert failed: (:wat::test::assert-eq written filesz)` and exit 70, near the
# END of its work. Under `>/dev/null 2>&1` that looks exactly like a slightly fast success, and
# a session measured 361 ms against 553 ms that way and believed a 53% regression that was not
# there. Apples to apples it was +3.6% instructions and no wall change at all.
#
# So this never runs the image in place: it copies first, checks the exit status of every run,
# and interleaves the two builds it is comparing -- because C-163 measured a 1.5% difference at
# eight repetitions that was 0.15% at fourteen.
#
#   tools/cc-time.sh                      time elf/out/compiler.elf (copied)
#   tools/cc-time.sh a.elf b.elf          interleave two, best of 14 each
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
reps=${REPS:-14}
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
prep () { cp "$1" "$tmp/$(basename "$1")"; chmod +x "$tmp/$(basename "$1")"; echo "$tmp/$(basename "$1")"; }

srcs=("$@"); [ $# -eq 0 ] && srcs=(elf/out/compiler.elf)
bins=(); names=()
for s in "${srcs[@]}"; do
  [ -x "$s" ] || { echo "cc-time: not executable: $s"; exit 2; }
  bins+=("$(prep "$s")"); names+=("$(basename "$s")")
done

# one clean run each first, so a failure is reported rather than timed
for i in "${!bins[@]}"; do
  "${bins[$i]}" >/dev/null 2>"$tmp/err"; rc=$?
  if [ $rc -ne 0 ]; then
    echo "cc-time: ${names[$i]} exited $rc -- timing it would measure the failure, not the work"
    head -3 "$tmp/err" | sed 's/^/      /'
    exit 1
  fi
done

declare -a best
for i in "${!bins[@]}"; do best[$i]=99999999; done
for ((r=0; r<reps; r++)); do
  for i in "${!bins[@]}"; do
    s=$(date +%s%N); "${bins[$i]}" >/dev/null 2>&1; rc=$?
    [ $rc -ne 0 ] && { echo "cc-time: ${names[$i]} exited $rc mid-run"; exit 1; }
    m=$(( ($(date +%s%N)-s)/1000000 ))
    [ $m -lt ${best[$i]} ] && best[$i]=$m
  done
done

for i in "${!bins[@]}"; do
  ins=""
  if command -v perf >/dev/null && [ -r /proc/sys/kernel/perf_event_paranoid ]; then
    ins=$(taskset -c 2 perf stat -e cpu_core/instructions/ "${bins[$i]}" 2>&1 >/dev/null \
          | awk '/instructions/{gsub(",","",$1); print $1}')
  fi
  printf '  %-22s %5s ms (best of %s)   %s instructions\n' "${names[$i]}" "${best[$i]}" "$reps" "${ins:-n/a}"
done
