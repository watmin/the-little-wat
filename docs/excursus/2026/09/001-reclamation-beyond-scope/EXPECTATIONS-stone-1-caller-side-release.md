# EXPECTATIONS — stone 1: a call that returns no pointer releases what it made

Written BEFORE the strike. HEAD `e35a682`, bootstrap fixpoint **249,978 B**, 86 binaries.

⚠ **A GREEN BOOTSTRAP IS NOT THE BAR HERE.** A byte-identical fixpoint proves the compiler still
reproduces itself; it says nothing about whether the feature did anything. Three times this
session a change was green on every oracle and wrong — and once (C-211 strike 3) the build was
byte-identical to baseline because the feature silently did nothing at all, found only by
disassembly. Rows 1 and 2 exist so the bar cannot be reached without the feature firing.

⚠ **Row 3 is the one that catches this wrong.** Freeing memory that is still live is the failure
mode, and it is silent. `tools/mem.sh` §1 is built to catch it.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the gap CLOSES | `tools/mem.sh`, the `escape` row | peak **FLAT in n** — n=1M/2M/3M within noise of each other, ~2 MB. Linear growth = the stone did not happen, whatever else is green |
| 2 | ⛔ the emission actually moved | `tools/emitted.sh` | a non-zero set of programs moved. Zero moved = the predicate never fired |
| 3 | ⛔ nothing freed early | `tools/mem.sh` §1 | `no: interpreter and binary agree` — the answer line unchanged |
| 4 | the in-place path is intact | `tools/mem.sh` §6 | `linear.wat agrees` |
| 5 | the existing release is intact | `tools/mem.sh` §2 and §4 | §2 still ~2.9x; §4 still completes at ~13 MB, not `heap exhausted` |
| 6 | STOP-1 is answered, not skipped | the SCORE | a citation proving `vec_conj_own` path 3 cannot fire on a caller's vector across a call — or a STOP report. An unanswered STOP-1 fails this row even if every other row is green |
| 7 | the corpus is correct | `tools/elf-run.sh` | no new divergence against the interpreter; report the counts, and report UNCOVERED if any |
| 8 | `escape.elf` agrees both ways | `./elf/out/escape.elf` vs `wat elf/src/escape.wat` | both `6400000`, both exit 0 |
| 9 | `optmh` moves | `tools/mem.sh` | 610.9 MB materially lower. If it does NOT move, say so — it is a returned-pointer shape and may be out of reach; that is a finding, not a failure |
| 10 | it self-hosts | `tools/bootstrap.sh` (no `--fast`) | byte-identical fixpoint, all binaries |
| 11 | the cost is named | the SCORE | the instruction delta on `elf/bench/optm.wat`, user-mode, best of 5. Two pushes and two pops per qualifying call is not free and the number goes in the record either way |

## RUNTIME PREDICTION

**60–90 min.** The emission is three lines copied from `:c::seq`; the cost is STOP-1 (a soundness
argument that must be grounded, not asserted) and two bootstraps at ~6 min of stage 0 each.

## TRAP DOORS

- **STOP-1 is the real one.** If `share` does not close `vec_conj_own` path 3, a caller-side
  restore frees an in-place extension while the vector's length still counts it — silent
  corruption, the worst failure mode in this tree. It is the reason this stone is drawn for a
  capable tier rather than a cheap one.
- **Mark placement.** The mark must precede ARGUMENT evaluation and the release must follow the
  RETURN. Marking after the arguments frees nothing; releasing before the return frees the
  callee's own frame work.
- **`tools/variant.sh` is a bisecting tool, not a gate.** It seeds from the native compiler and
  never runs the interpreter's type checks — C-208's `:String` bug passed it and died in
  bootstrap stage 0.
- **Instructions measure work ISSUED, not work DONE.** F-179: a representation win was understated
  by 70% because allocation costs bandwidth, not instructions. If row 11 looks too good, check RSS
  as well.
- **One root, or a second finding.** If closing this leaves a residue of leaked bytes, the residue
  is a SECOND finding and belongs in the SCORE by name — not absorbed into this one.
