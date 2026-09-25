# WEIGH — excursus 003 stone 1: CREDITED

The orchestrator's weighing of `SCORE-stone-1-whole-function-types.md` (with
`AMEND-stone-1-rete-is-for-rules.md` in), 2026-09-25. Every row below is the orchestrator's own run.

| row | re-run here | result |
|---|---|---|
| 1-3 | the four `fnty-*` fixtures, `fnty-in-enum` | refused, refused, agree `1`, agree `4`, agree `3` |
| 4 | `tools/emitted.sh check` | all 84 programs byte-identical |
| 5 | full `tools/elf-run.sh` | exit 0; `rules: 0` in 11,553 pairs; `types: 0` in 19,418 nodes; **`partial 0`** -- Grok's numbers exactly |
| 6 | `tools/rules.sh`'s must-be-zero loop | `partial` is in it; Grok's mutant not re-run |
| 7 | the diff | the rule stated in `:c::assignable?`/`:c::fn-assignable?` and `:ck::fits?`; **no `:wat::rete::core::defn` left** (20 `defrule`s) -- the amendment held |
| 8 | `tools/reads.sh` | `reads: ok` |
| 9 | `tools/bootstrap.sh`, no `--fast` | byte-identical fixpoint, 279,568 bytes |

**The adversarial round** -- eight probes, each also run under `wat --check`, now fixtures
(`elf/probe/fnty-indirect-*`, `-nested-variance*`, `-zero-arity`, `-returns-fn`, `-vec-in-enum`,
`-enum-of-fn-arg`): the compiler refuses exactly where wat refuses and agrees exactly where wat
accepts, INCLUDING a wrong argument at an indirect call -- the path the brief's fixtures never
reached (`:c::check-fn-args`). One probe found a wat-rs defect instead: **F-203**, a function type
as a collection's type argument, since fixed in wat-rs.

**The memory jump Grok chased mid-strike** (the stone-6 compiler at 1,855 MB, heap exhausted,
compiling a version of this source) is **not reproduced on the final source**: measured with
`elf/bench/maxrss.c`, the stone-6 compiler on the final stone-1 source peaks at 310 MB, on its own
source 307 MB, and the stone-1 compiler on its own source 309 MB. The SCORE does not mention it.
Owed by the strike: what the intermediate source was, and whether anything was rewritten to AVOID
the blowup rather than to fix it -- a compiler that can reach 6x memory on some source shape is a
defect even when this shape is gone.

**Accepted with one gap named, and carried forward as a required row of stone 2:** an indirect call
exports no `CArg`, so the gate never compares an indirect call's arguments (the compiler checks
them; the independent gate does not). After stone 3 every closure call is indirect. Stone 2's
brief carries "the gate sees an indirect call's arguments" as a row, not as later work.

Cost: Grok's +0.0024% instructions (cycles inside the floor) is not re-run; the change adds typing
only and no corpus byte moved.
