#!/usr/bin/env bash
# tools/rt-embed.sh: assemble elf/runtime.s and write the bytes into elf/lib/runtime.wat.
#
# The compiler embeds its runtime as hex string constants (`:c::rt-*`), because a compiled wat
# program has no assembler and no linker -- the bytes have to be IN the compiler. elf/runtime.s
# is the source they come from, and until now the transfer was done by hand: assemble, read
# `nm -n`, slice the binary, paste. That is a step where a typo is a fault at runtime, and the
# scale-factor error in C-140 was found only because the pipeline happened to print it.
#
# Every symbol in runtime.s must have a `:c::rt-<name>` defn in runtime.wat, spelled with
# hyphens; the order in the file must match the order of `:c::runtime`'s concat, because the
# offsets are derived from the lengths of what precedes each routine.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
O=$(mktemp -d); trap 'rm -rf "$O"' EXIT

as --64 -o "$O/rt.o" elf/runtime.s || { echo "rt-embed: assembly failed"; exit 1; }

# A relocation here means `as` left a `call` for a linker that never runs, and objcopy does not
# apply them -- the call would jump to the next instruction and unbalance the stack. See the
# header of runtime.s: this is why the symbols are not .globl.
if objdump -r "$O/rt.o" | grep -q '^0'; then
  echo "rt-embed: runtime.s has relocations -- a symbol is .globl, or a call left unresolved"
  objdump -r "$O/rt.o"; exit 1
fi

objcopy -O binary --only-section=.text "$O/rt.o" "$O/rt.bin" || exit 1
nm -n "$O/rt.o" | awk '$2=="t"{print $1, $3}' > "$O/syms"

python3 - "$O/rt.bin" "$O/syms" elf/lib/runtime.wat <<'PY'
import sys, re
blob = open(sys.argv[1], 'rb').read()
syms = [(int(a, 16), n) for a, n in (l.split() for l in open(sys.argv[2]))]
src  = open(sys.argv[3]).read()

pieces, changed, total = [], 0, 0
for i, (off, name) in enumerate(syms):
    end = syms[i + 1][0] if i + 1 < len(syms) else len(blob)
    pieces.append((name, blob[off:end]))

for name, body in pieces:
    defn  = ':c::rt-' + name.replace('_', '-')
    total += len(body)
    hexs  = body.hex()
    lines = [hexs[i:i + 60] for i in range(0, len(hexs), 60)] or ['']
    new   = ('(:wat::core::defn %s [] -> :wat::core::String\n  (:wat::string::concat\n' % defn
             + '\n'.join('    "%s"' % l for l in lines) + '))')
    pat = re.compile(r'\(:wat::core::defn ' + re.escape(defn) +
                     r' \[\] -> :wat::core::String\n(?:.*\n)*?.*?\)\)', re.M)
    m = pat.search(src)
    if not m:
        sys.exit('rt-embed: no %s in runtime.wat for symbol %s' % (defn, name))
    if m.group(0) != new:
        src = src[:m.start()] + new + src[m.end():]
        changed += 1

open(sys.argv[3], 'w').write(src)
# The prefix property the compiler relies on: elf/lib/runtime.wat carries only as much of this blob
# as a program can reach, which is sound ONLY while every cross-routine reference points
# backward and :c::runtime concatenates the routines in the assembled order.
order = [n for _, n in syms]
conc = re.search(r'\(:wat::core::defn :c::runtime \[lvl(.*?)\n\n', src, re.S)
if not conc:
    sys.exit('rt-embed: no :c::runtime to check the order against')
named = re.findall(r':c::rt-([a-z0-9-]+)\)', conc.group(1))
named = [n.replace('-', '_') for n in named]
if named != order:
    sys.exit('rt-embed: :c::runtime order does not match the assembled order\n  assembled: %s\n  concat:    %s'
             % (' '.join(order), ' '.join(named)))
print('rt-embed: %d routines, %d bytes, %d rewritten; :c::runtime order matches' % (len(pieces), total, changed))
PY
