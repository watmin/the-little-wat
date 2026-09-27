# BRIEF — excursus 008 stone 2: every reference is counted — the preconditions of M1

> The builder's rulings this stone serves (2026-09-26): memory "very close to what rust feels like";
> one reclamation discipline, the count; `poke` typed. Before a count can come DOWN (stone 3), it has
> to be TRUE on the way up.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/008-persistent-collections-and-memory/CRAWL-M1-the-count-comes-down.md` —
   WHOLE: what the header word is, what is settled (questions 2, 4, 5, 7, C4) and why
2. `SCOPE.md` beside it — the items; this stone is the precondition half of M1
3. `FINDINGS.md` — `### F-188` (every read out of a container is counted), and `tools/reads.sh`, the
   gate that keeps it so — this stone builds the same kind of gate for COPIES

## THE CONTRACT

**A pointer held in one more place is one more count.** Every pointer slot a runtime routine
duplicates — copying a flat Vector, copying a record or a Vector for `assoc`, sharing trie nodes by
path copying, moving elements into a trie — raises the count of what that slot points at. And no wat
value ever passes through raw memory.

## THE ROWS

| row | what | rooms |
|---|---|---|
| **P1** | **`poke` typed**: the address `i64`, the value `i64`; a pointer-typed value is a compile-time refusal naming the form (`:c::fail`). `peek` answers `i64` as today | `elf/compile.wat:2502` (the `poke` arm), `:1705` (the typer's `peek`) |
| **P2** | **the five pointer-slot copies count what they duplicate**: `rt-vec-conj` (`runtime.wat:946`), `rt-vec-conj-own`'s copying path (`:623`), `rt-slot-set` (`:975`), `rt-node-copy` (`:714`), `rt-cpath` (`:1183`). A copied slot holding a POINTER gets the increment; a slot holding a word (an `i64`, a tag, a bool) does not — the routine must know which, from the container's element or field kind, or the stone reports how it cannot know (STOP-1). A shared trie child — the untouched siblings of a copied path, and an old root placed under a new one in `tree_push` — is a pointer slot like any other | the five routines |
| **P3** | **a gate for copies, as `tools/reads.sh` is for reads**: a tool that finds every bulk copy (`rep movsq` / `rep movsb` and any hand-rolled slot loop) in `elf/lib/runtime.wat` and fails unless each is either COUNTED or on a named, reasoned list of BYTE copies (`rt-str-cat`, `rt-str-cat-own`, `rt-str-subs`, `rt-i64-to-str`, `rt-buf-put`, `rt-io-read-file`). A new copy nobody classified fails the build. Run it in `tools/elf-run.sh` | a new `tools/copies.sh` |

## THE FIXTURES

- A program that `poke`s a String is refused at compile time, naming the form; `elf/native/thread*.wat`
  still compile and agree.
- For each of the five routines, a program that duplicates a pointer slot and then extends the ORIGINAL
  in place where it could before (an owned `conj` / `concat`) — agrees with the interpreter. A mutant
  that drops P2's increment in any one routine must make its fixture diverge, or the SCORE says why
  it cannot (the F-188 lesson: a wall no fixture can isolate is named, not assumed).
- The whole corpus agrees; the in-place paths still fire where they did (say how you know).

## STOP TRIGGERS

- **STOP-1 — a routine cannot tell a pointer slot from a word slot** without a per-element tag it does
  not have. Report the routine and what it would take.
- **STOP-2 — the cost is large**: instructions for the compiler compiling the corpus rise more than 5%
  against this commit's compiler at its own fixpoint. Report the split per routine.
- **STOP-3 — a red, or a gate above zero.** Capture it; never re-run it.

## OUT OF SCOPE

Any decrement or drop (stone 3) · the allocator (M2) · the region release (retires last) · wat-rs.

## METHOD

`timeout -s KILL` on every run; assert every text replacement; no `_`, no catch-all; leave the tree alone
while `tools/bootstrap.sh` / `tools/elf-run.sh` runs; bootstrap WITHOUT `--fast`; `tools/elf-run.sh` IN
FULL; `tools/emitted.sh` with every moved program explained (the runtime changed, so every binary may
move — show the only differences are the runtime's); cost (instructions and cycles, the 1.8% floor).
**Commit nothing; leave the tree dirty.** Write `SCORE-stone-2-every-reference-is-counted.md` here.
