# EXPECTATIONS — stone 0b: a type is guarded only against what it can actually be

Written BEFORE the strike, on `main` at `c9746f1` (stone 0a landed).

⚠ **The failure mode is a guard dropped from a type that needed it** — that is a write to a
read-only page (a segfault) or `[rax-8]` on a small-integer tag (a read at a negative address).
Both are LOUD, which is the one mercy here. Row 2 is built to make them fire if they exist.

⚠ **The metric is instructions, and the cost may be memory.** F-189 was measured in instructions;
a bare `incq [rax-8]` still touches the same word the `cmp` read. If instructions recover and cycles
do not, the remaining cost is the memory touch — a different stone, per STOP-3.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the cost comes back | corpus compile, user-mode instructions AND cycles, best of 9, interleaved, pinned; three compilers each at its own fixpoint: `dada88f` (before stone 0), `c9746f1` (now), yours | at least HALF of F-189's gap recovered — yours no more than +5.32% over `dada88f` in instructions. Cycles reported beside, whatever they say |
| 2 | ⛔ the premise holds | `tools/probe.sh elf/probe/count-bare.wat` | agrees, `1\|0\|1\|0\|"t"\|3` — reads an EMPTY Vector, a record and a record's Vector field out of containers, then touches them |
| 3 | ⛔ F-188 stays closed | `tools/probe.sh` on the 8 door probes + `elf/src/borrowed.wat` | 9 of 9 agree |
| 4 | the derivation is written | the SCORE and `:c::count-hex`'s prose | a table: each pointer type (`str`, `vec:`, `rec:`, `penum:`, `henum:`), what its values can be, and the guard that follows — with the `file:line` that establishes each "can be" |
| 5 | no site dropped | `tools/reads.sh` | `reads: ok` — `:c::read-out` still emits `:c::count-hex`, which still has two callers |
| 6 | the emission moved only where it should | `tools/emitted.sh` | every moved program explainable as a `vec:`/`rec:` count losing its `cmp`/`je`; a program whose only counted reads are `str` or enum must NOT move |
| 7 | the String guard survives | a probe that reads a String LITERAL out of a Vector and passes it to an in-place `concat` | agrees, no fault — `str` must keep its literal guard |
| 8 | corpus | `tools/elf-run.sh` | `0 divergences, 0 UNCOVERED` |
| 9 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 10 | the benchmarks | `tools/vs-c.sh` | no row worse than before; `optmh` (F-189's one moved row, +3.3%) reported |

## RUNTIME PREDICTION

**45–75 min.** One function's cases, one derivation table, three fixpoint compilers to measure.

## TRAP DOORS

- **`penum:` is its payload.** A tier-1 enum value IS its payload pointer, so if a payload can be a
  String literal, a `penum:` can be a read-only literal too. Its guard follows its payload's, not
  its tier's.
- **A trie Vector.** `nth` over a promoted Vector answers through the runtime's `tget`; the count is
  on what comes back, and the header word is still at `[rax-8]`. Verify it, do not assume it.
- **Row 1 against the wrong baseline.** Stone 0a changed the compiler's source, so its own binary —
  the workload — differs from stone 0's. Measure all three compilers on identical input trees, each
  proved at its own fixpoint, as the stone-0 verdict did.
