#!/usr/bin/env bash
# tools/rsp.sh -- is every rsp-moving opcode reaching the output through :c::push / :c::popn?
#
# elf/compile.wat:305 (the comment above :c::push/:c::popn): "Every instruction that moves rsp
# goes through one of these and nothing else may move it." That is a convention, not something
# the language enforces, and it failed twice (excursus 008 stone 3a): the copying `concat` fix
# (round 2) found a raw `push rax` / `pop rax` pair that never updated `:c::Out/sp`, shifting
# every rsp-relative local by eight bytes for the rest of the window -- and the crawl for THIS
# gate (round 3) found the same shape twice more, harmless only because nothing between the push
# and the pop happened to address rsp: `:c::drop-saved`'s raw "59504889c8" and the `length`
# branch's raw "50" .. "58" around its drop. Both are fixed to go through :c::push/:c::popn.
#
# **What this checks**: every hex literal in elf/compile.wat that DECODES to a push or pop of a
# general-purpose register (opcode byte 0x50-0x5f, one register form per byte -- this codebase's
# hand-written x86 never puts a byte in that range anywhere else in a raw literal; an immediate
# or a displacement goes through :asm::u8 / :asm::le, a computed argument, never a literal digit
# here) must sit lexically inside a `(:c::push ...)` or `(:c::popn ...)` form -- however the
# parens wrap across lines, and however deep inside a `:wat::string::concat` it is nested, as
# long as no INTERVENING form is itself a `:c::push`/`:c::popn` call for something else.
#
# The one exception is the function PROLOGUE's own `push rbp` (`:c::compile-fn`, guarded by
# fpr?): it runs BEFORE the body's `:c::Out/sp` starts counting (the top-of-file comment: "sp is
# how many bytes the stack has been pushed SINCE THE BODY BEGAN"), and the frame it opens is
# addressed through `:c::fk` instead, so nothing about it belongs to `:c::Out/sp` at all. The
# matching `pop rbp` is folded into `leave` ("c9"), one byte that is not in the 0x50-0x5f range,
# so there is no second exception to name.
#
# Exit: 0 clean, 1 a push/pop byte reaches the output some other way (or the exception moved).
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
F=elf/compile.wat
fail=0

# the one named exception: the prologue's "55" (push rbp), before fpr?'s frame -- counted, so a
# second one appearing (or this one moving) fails rather than silently widening the exception
PROLOGUE_LINE=$(grep -n '(:wat::core::if fpr? (:wat::string::concat "55" "4889e5") "")' "$F" | cut -d: -f1)
[ -n "$PROLOGUE_LINE" ] || { echo "rsp: FAIL -- the prologue's push rbp line moved or is gone; update tools/rsp.sh"; exit 1; }

out=$(python3 - "$F" <<'PYEOF'
import re, sys

path = sys.argv[1]
src = open(path).read()

def trailing_backslashes(s, idx):
    k = 0
    j = idx - 1
    while j >= 0 and s[j] == '\\':
        k += 1
        j -= 1
    return k

# pass 1: strip ;; comments (never inside a string), tracking string state with proper
# backslash-escape counting -- a bare `src[i-1] != '\\'` check breaks on a literal "\\" (F-nothing
# yet, just a bug in an earlier draft of this very script: a two-backslash string desynced the
# scanner for the rest of the file).
i = 0; n = len(src); in_str = False; line = 1
kept = []
while i < n:
    c = src[i]
    if c == '\n':
        line += 1
    if in_str:
        kept.append((c, line))
        if c == '"' and trailing_backslashes(src, i) % 2 == 0:
            in_str = False
        i += 1
        continue
    if c == '"':
        in_str = True
        kept.append((c, line))
        i += 1
        continue
    if c == ';' and i + 1 < n and src[i+1] == ';':
        while i < n and src[i] != '\n':
            i += 1
        continue
    kept.append((c, line))
    i += 1
if in_str:
    print("FAIL\t0\tunclosed string at EOF\t0\t00")
    sys.exit(0)

# pass 2: tokenize into parens / strings / atoms
tokens = []
i = 0; n = len(kept)
while i < n:
    c, ln = kept[i]
    if c in '()[]{}':
        tokens.append(('paren', c, ln)); i += 1
    elif c.isspace():
        i += 1
    elif c == '"':
        j = i + 1; buf = []
        while j < n:
            cj, _ = kept[j]
            if cj == '"':
                k = 0; bi = len(buf) - 1
                while bi >= 0 and buf[bi] == '\\':
                    k += 1; bi -= 1
                if k % 2 == 0:
                    break
            buf.append(cj); j += 1
        tokens.append(('str', ''.join(buf), ln)); i = j + 1
    else:
        j = i; buf = []
        while j < n and (not kept[j][0].isspace()) and kept[j][0] not in '()[]{}"':
            buf.append(kept[j][0]); j += 1
        tokens.append(('atom', ''.join(buf), ln)); i = j

# pass 3: walk the paren stack, remembering each open `(`'s head symbol, and flag a push/pop
# byte in a string literal that is not lexically inside a :c::push / :c::popn form
HEXRE = re.compile(r'^[0-9a-fA-F]+$')
def push_pop_bytes(s):
    if len(s) == 0 or len(s) % 2 != 0 or not HEXRE.match(s):
        return []
    return [(k, int(s[k:k+2], 16)) for k in range(0, len(s), 2)
            if 0x50 <= int(s[k:k+2], 16) <= 0x5f]

stack = []
for kind, val, ln in tokens:
    if kind == 'paren':
        if val in '([{':
            stack.append({'open': val, 'head': None, 'first_seen': False})
        elif stack:
            stack.pop()
    elif kind == 'atom':
        if stack and not stack[-1]['first_seen']:
            if stack[-1]['open'] == '(':
                stack[-1]['head'] = val
            stack[-1]['first_seen'] = True
    elif kind == 'str':
        if stack and not stack[-1]['first_seen']:
            stack[-1]['first_seen'] = True
        for off, byte in push_pop_bytes(val):
            safe = any(fr['head'] in (':c::push', ':c::popn') for fr in stack)
            print(f"{'safe' if safe else 'UNSAFE'}\t{ln}\t{val}\t{off}\t{byte:02x}")
PYEOF
)

if printf '%s\n' "$out" | grep -q '^FAIL'; then
  printf '%s\n' "$out" | grep '^FAIL' | sed 's/^FAIL\t[0-9]*\t/rsp: FAIL -- /'
  fail=1
fi

# every UNSAFE hit fails, except the one named exception (the prologue's own "55")
real_fail=$(printf '%s\n' "$out" | awk -F'\t' -v pl="$PROLOGUE_LINE" \
  '$1=="UNSAFE" && !($2==pl && $3=="55") {c++} END{print c+0}')
if [ "$real_fail" -gt 0 ]; then
  printf '%s\n' "$out" | awk -F'\t' -v pl="$PROLOGUE_LINE" \
    '$1=="UNSAFE" && !($2==pl && $3=="55") {
       printf "rsp: FAIL -- %s:%s a raw push/pop byte (%s in \"%s\") does not reach :c::push/:c::popn\n", "'"$F"'", $2, $5, $3
     }'
  fail=1
fi

[ $fail -eq 0 ] && echo "rsp: ok -- every push/pop byte in $F reaches the output through :c::push / :c::popn (exception: line $PROLOGUE_LINE, the prologue's own push rbp)"
exit $fail
