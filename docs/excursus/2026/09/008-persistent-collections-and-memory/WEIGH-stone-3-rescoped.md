# WEIGH — excursus 008 stone 3: re-scoped — this strike becomes 3a, placement correct and checked

2026-09-27. The SCORE is honest about being partial, and that is credited. It cannot land: a misplaced
decrement makes a count TOO LOW, and a count of 1 licenses in-place mutation while another holder still
has the value — silent corruption. Until every drop is placed correctly and the WHOLE corpus runs clean
under the underflow check, decrements are unsafe to ship. The stone is too large for one strike, so:

- **3a (this tree, re-strike):** placement, correct and checked — R1–R3 below.
- **3b (drawn after 3a lands):** D1 drop glue per type with a worklist for recursive types, and D4
  freeing (to the bump when youngest).
- **then the bench** against `BENCH-baseline.md`, and the compiler's cost against stones 1 and 2.

## Credited so far

The decrement `:c::dec-hex` emitted only from `:c::drop-hex` through `:c::emit-drop` (one emission); drops
for a reading built-in's temporary (`drop-len`), a discarded allocating statement, an unused pointer
binding, a tail-call parameter not passed on, the copying `conj`'s source; the check build (`ud2` on
underflow) with its `jae` fix; `tools/reads.sh`'s third `count-hex` caller justified; fixpoint 319,048;
gates zero. The early-drop mutant diverged (a hang the check did not trap — see R2).

## R1 — remove the heap-range guard, and find the root

`:c::drop-hex` skips any value outside `r14`..`r15`, added because drops reached `rax = -691` and a code
address (`0x40028e`). A drop is emitted only for a value whose TYPE is a pointer, and the compiler knows
every type — so each of those was an emission site dropping a non-pointer (or a raw code address where
stone 2 made every function value an object). The guard hides the defect; extirpare forbids it. Remove
it; find each site that emitted a drop for a non-pointer (the check build and the stage-1 fault will name
them); fix the site. A literal (count 0) stays skipped by the literal guard, as stone 6 of 002 derived.
**STOP** if a pointer-typed value can legitimately lie outside the heap other than as a count-0 literal.

## R2 — the check is the gate, over EVERYTHING

Run the whole corpus and the compiler's own bootstrap with `:c::drop-check?` on: zero underflows. The
early-drop mutant hung instead of trapping — say why the check did not see it (a count taken from 2 to 1
is not an underflow; the corruption came from in-place growth at count 1). Add the check that WOULD see
it, or a fixture that shows it, or say why neither exists.

## R3 — complete the placements

Named bindings and parameters at their LAST use (`:c::live-after`), not only unused ones; `assoc` and
`concat` copy paths drop their source like `conj`'s; the `match` scrutinee at arm entry; a name dead in
one `if` arm at that arm's start. Closures' captures belong with drop glue (3b) — leave them.

Then `tools/verify.sh`, and append a re-strike section to the SCORE. Commit nothing.
