# BRIEF — excursus 003 stone 2: every function value is a closure object

> Stone 3 compiles `fn`. This stone gives it somewhere to land: ONE representation for every
> function value, so a closure and a top-level function are called the same way, and the gate sees
> every argument either one is handed.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/003-closures/DESIGN.md` — the three stones; this is the second
2. `WEIGH-stone-1-credited.md` beside it — stone 1's named gap is this stone's row G
3. `SCORE-stone-6-the-guard-knows-the-variant.md` (`002-no-guesses/`) — the count guard's derivation
   table, which gains a row here; `WEIGH-stone-6-refuted.md` — why every row is checked against
   every kind of value the type admits
4. `FINDINGS.md` — `### F-202`, `### F-188`

## THE CONTRACT

A function value is a POINTER to a closure object laid out as the runtime's other objects are:
`[count:8][code:8][capture:8]…`, the pointer at `code`, the count at `[p-8]`. A top-level function
used as a value is a STATIC object in the read-only tail with count 0 — a literal, exactly as a
String literal is (`:c::static-str`, `elf/compile.wat:2127`) — and has no captures. An indirect call
is `call [rax]` with **the closure itself in rax at entry**: that is the contract stone 3's closure
code reads its captures through; a top-level function ignores it.

## THE ROWS

| row | what | rooms |
|---|---|---|
| **R1** | the function value: `(:c::mov-rax <object address>)` where it was the code address — still the ten-byte `movabs`, so pass 1 and pass 2 agree on length. ONE static object per function whose address is taken (interned), `[0][code]`, its code address final in pass 2 and the same LENGTH in both | `:2347-2351`, `:c::static-str` `:2127`, `:c::fn-addr` `:1272` |
| **R2** | the call: `ff 10` (`call [rax]`) where it was `ff d0`; arguments pushed first, head second, as today | `:c::call-indirect` `:5297` |
| **R3** | `fn:` is a pointer type: `:c::ptr-ty?` (`:3813`) includes it and `:c::word-ty?` (`:3988`) no longer does; the prose above the value arm that says "a CODE address, never heap" says what is true now | |
| **R4** | the count guard's derivation gains the row: a `fn:` value is a static object (count 0) or, after stone 3, a heap closure (count ≥ 1) — the LITERAL guard, `:c::maybe-literal?` (`:3893`) true for `fn:`; `:c::count-hex`'s prose table gains the row | `:3893`, `:3920` |
| **R5** | `tools/reads.sh`: loading the code slot through `call [rax]` is not a value read out of a container (it answers no value a program sees). Classify it in the tool with that reason, or show the tool needs nothing | |
| **G** | **the gate sees an indirect call's arguments** (stone 1's gap): export each indirect-call argument — its position, index, the compiled-in function and its type — and a rule that joins it to argument *i* of the HEAD's exported function type (which the types gate already holds to wat's checker). Parse the function type in plain wat while loading; rules only join (`feedback`: rete is for rules). A mutant that disables `:c::check-fn-args` must make the gate flag `elf/probe/fnty-indirect-arg-wrong-refused.wat`'s shape | `:c::check-fn-args` `:1937`; `tools/rules/check.wat` `:65-165` |

## THE FIXTURES

`elf/src/fnref.wat`, `elf/src/fnvec.wat` and every `elf/probe/fnty-*.wat` agree (or refuse) exactly as
before. **New, yours to write**: a function value stored in a record, returned from a function, and
passed through a Vector then called — each agreeing with the interpreter; and one where the SAME
function's value is taken at two sites (the interned object: one tail entry, not two).

## STOP TRIGGERS

- **STOP-1 — a prologue or entry sequence reads rax** before it is overwritten, so "the closure in
  rax" would change what a function computes. Report where.
- **STOP-2 — a moved program is not explained** by R1, R2 and the tail's growth.
- **STOP-3 — a gate above zero, or a red.** Capture it; never re-run it.

## OUT OF SCOPE

The `fn` form (stone 3) · heap closures and captures (stone 3) · tail calls through a closure.

## METHOD

`timeout -s KILL` on every wat run; assert every text replacement; `cond` ends in `(:else …)`, no
`_`, no catch-all; leave the tree alone while `tools/bootstrap.sh` / `tools/elf-run.sh` runs;
bootstrap WITHOUT `--fast`; `tools/elf-run.sh` IN FULL; cost (instructions and cycles, the 1.8% floor)
against this commit's compiler at its own fixpoint. **Commit nothing; leave the tree dirty.** Write
`SCORE-stone-2-one-closure-representation.md` here.
