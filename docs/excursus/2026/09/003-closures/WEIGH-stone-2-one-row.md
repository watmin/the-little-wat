# WEIGH — excursus 003 stone 2: one row back

2026-09-26. The contract holds as scored: one interned static object per address-taken function,
`call [rax]` with the closure in rax (no prologue reads it first), `fn:` a pointer type under the
literal guard, `reads: ok`, only `fnref` and `fnvec` moved and both are explained, the gate's `IArg`
rule joins only and its mutant flags the indirect wrong-argument probe, a byte-identical fixpoint at
283,268 bytes, instructions -0.219% in both rounds.

**R6 — `tools/elf-run.sh` exited 1.** The five fixtures went into `elf/src/`, so they are corpus
programs, and the coverage guard refuses a compiled source missing from `COMPARED`
(`UNCOVERED: elf/src/fn-box.wat` ... `fn-vecpass.wat`). A red is a red: list each in `COMPARED` (they
agree under `tools/probe.sh`), then run `tools/elf-run.sh` IN FULL again and report its exit and its
`rules:`/`types:` lines. Nothing else changes.
