#!/usr/bin/env bash
# tools/verify.sh -- THE way to verify the tree before a commit: a full bootstrap (never --fast), then
# tools/elf-run.sh on the binaries that bootstrap just proved at the fixpoint (SKIP_BUILD=1).
#
# elf-run.sh used to rebuild everything through the interpreter first -- the same 12-15 minute
# computation bootstrap.sh's stage 0 does -- so a verification paid it twice. Now it is paid once,
# and SKIP_BUILD cannot check stale binaries: bootstrap writes a stamp of every build input only when
# it reaches the fixpoint, and elf-run refuses unless the tree still matches it (tools/sums.sh).
# Leave the tree alone while this runs. Exit: bootstrap's failure, else elf-run's.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
tools/bootstrap.sh; rc=$?
if [ $rc -ne 0 ]; then echo "verify: bootstrap FAILED (exit $rc) -- elf-run not run"; exit $rc; fi
SKIP_BUILD=1 tools/elf-run.sh; rc=$?
if [ $rc -eq 0 ]; then echo "verify: ok"; else echo "verify: elf-run FAILED (exit $rc)"; fi
exit $rc
