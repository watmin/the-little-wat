# BRIEF — stone 0c: what the count buys (a census, not a change)

> The builder asked: *"we slower because we're correct?"* F-193 answered half: the read counts'
> writes cost the compiler 3.5% of its time, and on its own run they protect nothing. This stone
> answers the other half — **how much of ALL the counting can protect anything at all** — and nothing
> in `main`'s compiler changes. It is a measurement. The answer decides what comes next.

## THE QUESTION — made precise by the disk

A count exists so that one of exactly THREE sites can refuse to mutate a shared value in place:

```
elf/compile.wat:1886   vec_conj_own   -- conj, gated by own? at :1883
elf/compile.wat:2436   str_cat_own    -- concat, own? threaded in at :2427
elf/compile.wat:3334   slot_set_own   -- assoc, gated by own? at :3315
```

The compiler is whole-program and statically typed. **A count on a value of static type T can
matter only if, somewhere in the same program, one of those three sites can receive a value of
type T.** Call such a T *reachable*. A count on an unreachable type is insurance nobody can claim.

★ Two populations are counted, and both are in scope: **reads** (`:c::read-out`, stone 0 — 313
sites in the compiler) and **shares** (`:c::share`, predating this excursus — ~2,341 sites in the
compiler). F-193 measured only the reads.

## THE RULING — builder, 2026-09-23

> *"do we need to re-assess our compilation primitives?... we slower because we're correct?"* —
> and, to drawing this re-assessment: *"yes"*

## THE WORK

1. **The census.** For each corpus program AND the compiler: the set of reachable types (the
   container types that reach any of the three own sites), and every counted site — read and share
   — classified reachable / unreachable by its type. Report counts per program; for the compiler,
   also by type.
2. **The time the unreachable counts cost the compiler**, by F-193's same-layout method: two
   compilers identical in structure, one with every count real, one with only the UNREACHABLE
   counts NOP'd (same-length `0f1f4000`). Byte-diff them to prove only those sites moved. Their
   corpus outputs must match apart from the swaps — if not, the census called something
   unreachable that was not, and that is STOP-1.
3. **Everything in scratch.** No change to `elf/compile.wat` on `main`. The tree gets the SCORE and
   nothing else, unless a census tool proves worth keeping — then `tools/`, stated in the SCORE.

## READ IN ORDER

```
FINDINGS.md F-192, F-193                              the floor, the method, the first half
docs/excursus/.../SCORE-stone-0b-*.md                 the per-type guard derivation (the same "what can a type be" reasoning)
elf/compile.wat  :1880-1886, :2420-2436, :3310-3334   the three own sites and their gates
elf/compile.wat  :c::share, :c::read-out, :c::count-hex   the two populations and their one emission
elf/compile.wat  :c::type-of, :c::ptr-ty?              how a type string is formed
elf/compile.wat:900-975                                the enum ladder -- a penum: value IS its payload
```

## STOP TRIGGERS

- **STOP-1 — the NOP'd-unreachable compiler computes something different.** Then a type the census
  called unreachable was reachable. Report the program and the type; do not patch the census to fit.
- **STOP-2 — one type has two spellings.** If a typealias, a `penum:` payload or anything else lets
  one type appear as two strings, reachability by string comparison is unsound. Report how, stop.
- **STOP-3 — a value can reach an own site as a type other than its own.** Any conversion, union or
  erasure that does this breaks the whole premise. Report it.
- **STOP-4 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Changing `main`'s compiler · a type-filtered count as a feature (that is the stone this may justify,
not this one) · stone 1 · F-190, F-191.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, `main`, HEAD at the commit that added this brief.
Variants in scratch, each proved at its own fixpoint (`git archive` + seed + `--fast` twice).
`timeout -s KILL` on every run. Cycles AND instructions, user-mode, pinned `taskset -c 0`,
interleaved, at least 11 rounds, min and median. The layout floor for this workload is 1.8%
(F-192) and does not apply to a same-layout comparison — say which kind each number is.
**Leave the tree dirty; do not commit.** Write `SCORE-stone-0c-what-the-count-buys.md` beside this
file, one section per EXPECTATIONS row, output pasted in.
