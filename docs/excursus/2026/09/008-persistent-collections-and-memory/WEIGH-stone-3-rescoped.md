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

---

# Round 2 — the drops corrupt the compiler itself (2026-09-27)

**Credited:** R1 done at the root — the `-691` / `0x40028e` drops were STALE RELOADS (a register let
reloaded after a call reused the register; a stack binding read with the raw frame displacement), fixed by
spilling register lets when bound and pointer parameters on entry; the guard is gone. R3's placements
(copying `assoc` / `concat`, the `match` subject, `if` arms, unused parameters kept off `rax`, read-only
parameters exempted at tail pass-through — which the check caught with `ud2`). R2's answer on the mutant
(2 -> 1 is a legal release; no count check can see it). Eleven probes agree with the check on.

**Not landable:** stage 1 — the compiled compiler — dies in `asm::fits?` on `0xffff8017499e8e06`, check on
or off. The signature of a drop placed too early somewhere in the compiler's own code: a count reaches 1
while another holder remains, something grows in place, memory is corrupted — the case the underflow check
cannot see.

**A named candidate class — evaluation order ≠ textual order.** Drops sit at a name's last TEXTUAL
occurrence, but `:c::call-indirect` pushes the arguments FIRST and evaluates the head SECOND ("the
arguments are pushed first and the target loaded second"): in `(f (g f))` the textual last `f` is in the
argument, evaluated before the head `f` — a use after drop. Every form whose evaluation order differs from
its text is the same class (check the binary-operator fold's operand order too). **The last occurrence must
be the last in EVALUATION order** — derive it from the order the code generator emits, not the text.

**Find the site systematically, not by hunting:**
1. **Per-class switches**: one compiler flag per drop class (temporaries, discarded statements, last-use
   names, copying `conj`/`assoc`/`concat` sources, `match` subjects, `if` arms, `ret`, tail parameters).
   Build stage 1 with ONE class on at a time — stage 1 compiling the compiler is the test. The class that
   fails is the class.
2. **Then by function**: within that class, enable drops only for functions in a name range and halve —
   the site falls out in ~9 builds.
3. Fix the ROOT the site shows (as R1 did), keep the switches out of the final tree or behind the check
   build, and run `tools/verify.sh` to the fixpoint.

Append a round-2 section to the SCORE. Commit nothing.
