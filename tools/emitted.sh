#!/usr/bin/env bash
# tools/emitted.sh: did this change alter the code we EMIT, and for which programs?
#
# **`tools/bootstrap.sh`'s "byte-identical" is a different question.** It compares the
# binaries the interpreted compiler wrote against the ones the native compiler wrote --
# the compiler agreeing with ITSELF, which is the self-hosting check and passes whether
# or not the emitted code changed. Nothing compared a build against the PREVIOUS build,
# so a refactor claiming to be pure had no oracle at all.
#
# This is that oracle. `save` records a manifest, `check` compares against it and names
# every program whose bytes moved. A pure refactor must report zero.
#
# elf/out/compiler.elf and stage*.elf are excluded on purpose: the compiler compiles
# ITSELF, so adding a function to its source legitimately changes its own binary while
# changing nothing about what it emits for anything else.
#
#   tools/emitted.sh save            record the current emitted code
#   tools/emitted.sh check           compare, and name what moved
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
M=elf/out/.emitted-manifest
# seed.elf is `bootstrap.sh --fast`'s scratch copy of the compiler, not emitted code -- it was
# missing from this list and reported as a moved program after a --fast excursion, which is a
# false positive from a tool whose whole job is to be believed.
progs () { ls elf/out/*.elf 2>/dev/null | grep -v -e 'compiler\.elf' -e 'stage[0-9]*\.elf' -e 'seed\.elf'; }
case "${1:-check}" in
  save)  sha256sum $(progs) > $M; echo "emitted: saved $(wc -l < $M) programs"; ;;
  check)
    [ -f $M ] || { echo "emitted: no manifest -- run 'tools/emitted.sh save' first"; exit 2; }
    n=$(wc -l < $M); d=0
    while read -r want f; do
      got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
      if [ -z "$got" ]; then echo "   GONE:  $f"; d=$((d+1))
      elif [ "$got" != "$want" ]; then echo "   MOVED: $f"; d=$((d+1)); fi
    done < $M
    # **A program the manifest has never heard of used to be invisible here**, which is the
    # same class of hole as the seed.elf false positive above: a tool whose whole job is to be
    # believed was silently not checking two of the programs it had just built. NEW is not a
    # failure -- adding a program is legitimate -- but it has to be SAID, so that "ok" always
    # means "everything on disk was compared", never "everything I happened to know about".
    new=0
    for f in $(progs); do
      grep -q "  $f\$" $M || { echo "   NEW:   $f  (not in the manifest -- run 'save' to adopt)"; new=$((new+1)); }
    done
    if [ $d -eq 0 ] && [ $new -eq 0 ]; then
      echo "emitted: ok -- all $n programs byte-identical to the manifest"
    elif [ $d -eq 0 ]; then
      echo "emitted: $n byte-identical, $new not yet in the manifest"
    else echo "emitted: $d of $n programs changed${new:+, $new new}"; fi
    [ $d -eq 0 ] || exit 1
    ;;
  *) echo "usage: tools/emitted.sh [save|check]"; exit 2 ;;
esac
