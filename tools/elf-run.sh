#!/usr/bin/env bash
# tools/elf-run.sh: run the executables elf/hello.wat emitted, and check them.
#
# wat can compute the bytes of an ELF and write them (elf/hello.wat does, and verifies them
# against what it assembled). It cannot set the executable bit -- `:wat::io::` has open-file,
# read-file and list-dir and no chmod -- and it cannot exec the result, because
# `:wat::kernel::spawn-process` forks a wat child that evaluates a source string rather than
# launching an arbitrary program. Those two steps are what this script is.
#
# Exit code: 0 when both binaries behave. Read it directly, not through a pipe.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

WAT="${WAT:-../wat-rs/target/release/wat}"
[ -x "$WAT" ] || { echo "elf-run: no wat binary at $WAT"; exit 2; }

echo "== emitting =="
"$WAT" elf/hello.wat || { echo "elf-run: wat failed to emit"; exit 1; }

chmod +x elf/out/hello.elf elf/out/exit42.elf

echo
echo "== what the kernel makes of them =="
for f in elf/out/hello.elf elf/out/exit42.elf; do
  printf '%-22s %4s bytes  %s\n' "$f" "$(stat -c %s "$f")" "$(file -b "$f" 2>/dev/null || echo '(no file(1))')"
done

echo
echo "== running =="
out=$(./elf/out/hello.elf)
rc=$?
want="hello from wat"
if [ "$out" != "$want" ] || [ $rc -ne 0 ]; then
  echo "FAIL hello.elf: printed '$out' (exit $rc), wanted '$want' (exit 0)"
  exit 1
fi
echo "hello.elf   printed '$out' and exited $rc"

./elf/out/exit42.elf
rc=$?
if [ $rc -ne 42 ]; then
  echo "FAIL exit42.elf: exited $rc, wanted 42"
  exit 1
fi
echo "exit42.elf  exited $rc, which wat computed as 6 * 7"

echo
echo "elf-run: ok -- a wat program emitted both of these, and neither needs wat to run"
