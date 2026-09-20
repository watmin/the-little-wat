#!/usr/bin/env bash
# tools/rt-disasm.sh: read the runtime.
#
# The thirty-three `:c::rt-*` routines are the only part of the compiler's output not computed
# from a mnemonic -- they are hand-assembled hex, and until this existed there was no way to
# check that any of them does what its comment says. That is a real gap: `str_cat` is 96 bytes
# of "4989..." and the comment is the only claim about it.
#
# This extracts each routine's hex from elf/compile.wat and disassembles it, so the claim and
# the instructions can be read side by side.
#
#   tools/rt-disasm.sh                 every routine
#   tools/rt-disasm.sh str-cat         one of them (substring match)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
want="${1:-}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

grep -oE 'defn :c::rt-[a-z0-9-]+' elf/compile.wat | sed 's/defn //' | while read -r fn; do
  [ -n "$want" ] && [[ "$fn" != *"$want"* ]] && continue
  hex=$(awk "/defn $fn \[\]/,/^\$/" elf/compile.wat | grep -oE '"[0-9a-f]+"' | tr -d '"' | tr -d '\n')
  [ -z "$hex" ] && continue
  python3 -c "
import binascii,sys
open('$tmp/r.bin','wb').write(binascii.unhexlify('$hex'))" || continue
  echo "=== $fn  ($(( ${#hex} / 2 )) bytes) ==="
  # the one-line claim the source makes about it, so it sits beside the instructions
  grep -B4 "defn $fn \[\]" elf/compile.wat | grep -E '^;; *`' | head -1 | sed 's/^;; */  claim: /'
  objdump -D -b binary -m i386:x86-64 "$tmp/r.bin" 2>/dev/null | tail -n +8 | sed 's/^/  /'
  echo
done
