#!/usr/bin/env bash
# tools/mal-test.sh: run one Make-a-Lisp step's own tests against its wat implementation.
#
#   tools/mal-test.sh step0_repl        # mal/step0_repl.wat against vendor/mal/tests/step0_repl.mal
#
# mal's runner (vendor/mal/runtest.py, unmodified) drives the program through tools/mal-shim.py,
# which stands in for the terminal a wat program can't be (FINDINGS F-049, F-050). Extra
# arguments go to runtest.py (for example --continue-after-fail, or --hard).
#
# WAT overrides the binary (default ../wat-rs/target/release/wat). Exit code: runtest.py's, 0
# when every hard test passes. Read it directly, not through a pipe.

set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2

step="${1:?usage: tools/mal-test.sh STEP [runtest.py options]}"
shift
WAT="${WAT:-../wat-rs/target/release/wat}"
root="$(pwd)"
python3 vendor/mal/runtest.py --no-pty --rundir "$root" "$@" "vendor/mal/tests/$step.mal" -- \
  python3 "$root/tools/mal-shim.py" "$root/$WAT" "$root/mal/$step.wat"
