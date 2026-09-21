#!/usr/bin/env bash
# tools/rt-disasm.sh: read the runtime.
#
# The `:c::rt-*` routines are the only part of the compiler's output not written as source the
# reader can check -- they are machine code, and until this existed there was no way to confirm
# that any of them does what its comment says. `str_cat` is 96 bytes and its comment was the
# only claim about it.
#
# **It asks the compiler for the bytes rather than grepping them out of the source.** The first
# version pulled hex string literals out of elf/lib/runtime.wat, which worked only while a
# routine WAS a hex literal -- so as C-173 converted them to composed expressions the tool that
# audits them quietly stopped seeing them (`tree-get` read as "3 bytes", having matched the "8b"
# inside a mnemonic). The routines are now built by evaluating `(:c::rt-nth i lay)`, which is the
# same list `:c::runtime` lays down, so this reads what actually ships and cannot drift from it.
#
# **A byte count belongs in this tool's output, never in a comment.** When the claims were
# audited against the real bytes the first time, two of the four that stated a size were wrong --
# `i64_to_str` by ten and `vec_conj_own` by 188, a routine that had grown 4.6x while its comment
# stood still. Nothing could have caught that while the tool read hex literals out of the source.
# The counts are gone from the comments; this prints them.
#
#   tools/rt-disasm.sh                 every routine
#   tools/rt-disasm.sh str-cat         one of them (substring match)
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
want="${1:-}"
WAT="${WAT:-../wat-rs/target/release/wat}"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# the order is the runtime's own, read out of :c::rt-nth so the two cannot disagree
mapfile -t names < <(sed -n '/defn :c::rt-nth /,/^$/p' elf/lib/runtime.wat \
                     | grep -oE ':c::rt-[a-z0-9-]+' | sed 's/:c::rt-//' | grep -vx 'nth')
[ "${#names[@]}" -eq 0 ] && { echo "rt-disasm: could not read the routine order"; exit 1; }

{ printf '(:wat::load-file! "%s/elf/lib/prim.wat")\n'    "$PWD"
  printf '(:wat::load-file! "%s/elf/lib/asm.wat")\n'     "$PWD"
  printf '(:wat::load-file! "%s/elf/lib/reader.wat")\n'  "$PWD"
  printf '(:wat::load-file! "%s/elf/lib/x86.wat")\n'     "$PWD"
  printf '(:wat::load-file! "%s/elf/lib/runtime.wat")\n' "$PWD"
  printf '(:wat::core::defn :d::go [lay <- :c::Layout i <- :wat::core::i64] -> :wat::core::i64\n'
  printf '  (:wat::core::if (:wat::core::>= i (:c::rt-count)) 0\n'
  printf '    (:wat::core::do (:wat::kernel::println (:c::rt-nth i lay))\n'
  printf '                    (:d::go lay (:wat::core::+ i 1)))))\n'
  printf '(:wat::core::defn :user::main [] -> :wat::core::nil\n'
  printf '  (:wat::kernel::println (:wat::core::str (:d::go (:c::layout 0) 0))))\n'
} > "$tmp/dump.wat"

"$WAT" "$tmp/dump.wat" 2>"$tmp/err" | tr -d '"' | head -n -1 > "$tmp/hex" || {
  echo "rt-disasm: the compiler would not load:"; tail -2 "$tmp/err"; exit 1; }

i=0
while IFS= read -r hex; do
  fn="${names[$i]:-?}"; i=$((i+1))
  [ -n "$want" ] && [[ "$fn" != *"$want"* ]] && continue
  [ -z "$hex" ] && continue
  python3 -c "import binascii;open('$tmp/r.bin','wb').write(binascii.unhexlify('$hex'))" || continue
  echo "=== :c::rt-$fn  ($(( ${#hex} / 2 )) bytes) ==="
  # the one-line claim the source makes about it, so it sits beside the instructions
  grep -B14 "defn :c::rt-$fn \[" elf/lib/runtime.wat | grep -E '^;; *`' | head -1 | sed 's/^;; */  claim: /'
  objdump -D -b binary -m i386:x86-64 "$tmp/r.bin" 2>/dev/null | tail -n +8 | sed 's/^/  /'
  echo
done < "$tmp/hex"
