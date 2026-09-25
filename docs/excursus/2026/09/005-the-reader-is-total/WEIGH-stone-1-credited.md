# WEIGH — excursus 005 stone 1: CREDITED

The orchestrator's weighing of `SCORE-stone-1-every-read-makes-progress.md` (a subagent executor,
two rounds), 2026-09-25, on the orchestrator's own runs.

| row | re-run here | result |
|---|---|---|
| 1-3, 9 | `tools/probe.sh` on all five `elf/probe/reader-*.wat` | each `COMPILE-FAILED` in ~2 s, naming the right line and column; the unterminated string names the QUOTE (6:23), not the enclosing `(` |
| 4 | `tools/emitted.sh check` | all 84 byte-identical against the re-saved manifest; `reader.elf` ruled a legitimate mover (it compiles `elf/lib/reader.wat`) |
| 5 | full `tools/elf-run.sh` | exit 0; 10 standing refusals, the five reader rows among them; `rules: 0` (11,650 pairs), `types: 0` (19,575 nodes), `partial 0` |
| 7 | `tools/bootstrap.sh`, no `--fast` | byte-identical fixpoint, 281,728 bytes |
| 8 | accepted on the executor's measurement | the native compiler refuses a stray `)` in `elf/compile.wat` in 287 ms at 7.6 MB, where the stone-6 compiler exhausted 1.9 GB; exit 70 is the runtime's one stop code |

Found by the strike and folded in: an unterminated string read as complete at end of input, and
a trailing backslash read one byte past the end. Harness hardening kept: `refuses` in
`tools/elf-run.sh` runs under `timeout -s KILL 300`, because the executor's mutant B (the old
zero-length atom restored) otherwise hangs `elf-run` forever.
