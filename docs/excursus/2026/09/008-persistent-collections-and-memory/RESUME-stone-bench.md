# RESUME — excursus 008 bench stone (the session closed mid-strike)

2026-09-27, found by the orchestrator. The strike stopped before its measurements; no SCORE, no
`BENCH-baseline.md`. **Continue it — do not restart.** On disk, uncommitted, as you left it:

- `elf/compile.wat`: the `wat.os/clock-ns` intrinsic (+13 lines), and the regenerated `elf/refuse*.wat`
- `elf/bench/coll/`: `w1`–`w5.wat`, the timed `w1t`–`w5t.wat`, `common.wat` (last touched 03:50),
  `clock.wat`, `clock-arity.wat`, `arity4.wat`, `coll.c`, `coll.clj`, `rust/` (Cargo.toml, Cargo.lock,
  src/main.rs), `n.txt` (= 100000, last touched 06:25 — a run was likely in progress)
- `tools/bench-coll.sh` (10 KB, last touched 03:41)
- `/tmp/bench-coll/`: `reps.tsv`, `notes.tsv`, `coll-c`, `coll-rs`, `maxrss`, logs — **partial and of
  unknown completeness: re-measure rather than trust any row you cannot tie to a finished run.**

Read the BRIEF and EXPECTATIONS again, check what the scripts and programs do against them, finish, and
write `SCORE-stone-bench-collections-and-memory.md`. Verify with `tools/verify.sh`.
