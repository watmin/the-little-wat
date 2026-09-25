# BRIEF — excursus 005 stone 1: the compiler's reader is total

> Grok hit this by accident: one extra `)` in an intermediate `elf/compile.wat` made the stone-6
> compiler exhaust its 1.9 GB heap instead of naming the line (F-205). The builder's ruling on
> totality: panic is for COMPILATION only, and a compile-time refusal names what and where.

## YOU ARE NEW TO THIS — read first

`the-little-wat` is a self-hosting compiler for wat, written in wat, emitting x86-64. Read:
1. `FINDINGS.md` — `### F-205` (this stone), then `### F-204` (the same class in wat-rs's stepper)
2. `elf/lib/reader.wat` whole — 262 lines; it is the compiler's own reader
3. `tools/elf-run.sh:150-250` and `tools/gen-refuse.sh` — how a compile-time refusal is pinned as a
   standing negative (`refuses <driver> <needle> <what it proves>`)

## THE WORK

1. **Every read consumes at least one byte or refuses — by construction.** Today a delimiter where
   a form belongs reads as a zero-length atom (`rd/form` `:184` → `rd/atom-end` `:128`), and the
   caller asks again at the same position forever. Make that state unrepresentable in the reader's
   shape, not guarded for `)` alone: a closing delimiter (`)`, `]`, `}`) where a form belongs is a
   refusal; the atom arm is reached only by a byte that can start an atom.
2. **A list closes with ITS closer or refuses.** In `rd/kids-of` (`:202`): end of input inside a
   `(`/`[`/`{` is a refusal naming where it opened; a closer that is not this list's is a refusal
   naming both.
3. **Refusals name the place** as the rest of the compiler does (`line col`, and the file) — find
   how the existing refusals compute it (`:c::loc-str`, `:c::where`, the `Src`/`locs` machinery in
   `elf/compile.wat`) and use that one way; do not write a second.
4. **Standing negatives.** `elf/probe/reader-extra-rparen.wat`, `reader-missing-rparen.wat`,
   `reader-mismatched-closer.wat` become refusals `tools/elf-run.sh` checks every run, through
   `tools/gen-refuse.sh` like the five that exist.

**No corpus byte moves** — no committed program has a malformed delimiter.

## STOP TRIGGERS

- **STOP-1 — a corpus program's bytes move** (`tools/emitted.sh check`). Capture it.
- **STOP-2 — the refusal cannot name a position** without a second position computation. Report.
- **STOP-3 — a red, or a gate above zero.** Capture it; never re-run it to make it pass.

## OUT OF SCOPE

wat-rs (Grok is working there — do not touch `../wat-rs`) · any reader feature · error recovery
(the first malformed delimiter refuses; nothing continues past it).

## METHOD

`timeout -s KILL` on every wat run; assert every text replacement matched exactly once; `cond`
ends in `(:else …)`, no `_`, no catch-all; leave the tree alone while `tools/bootstrap.sh` or
`tools/elf-run.sh` runs; bootstrap WITHOUT `--fast`; run `tools/elf-run.sh` IN FULL. Every number
you report is one you measured. **Commit nothing; leave the tree dirty.** Write
`SCORE-stone-1-every-read-makes-progress.md` in this directory, against
`EXPECTATIONS-stone-1-every-read-makes-progress.md`.
