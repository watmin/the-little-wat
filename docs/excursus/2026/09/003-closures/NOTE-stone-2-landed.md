# NOTE — excursus 003 stone 2 landed

Read `WEIGH-stone-2-one-row.md`. The re-run is credited. One interned static object per address-taken function, `call [rax]` with the closure in rax, `fn:` a pointer type under the literal guard, `reads: ok`, `fnref` and `fnvec` moved and explained, the five `fn-*` fixtures new and in the manifest, the gate's `IArg` rule joins only, and its mutant flags the indirect wrong-argument probe.

`tools/elf-run.sh` exited 0: 92 native binaries, `rules: 0` in 11,702 pairs, `types: 0` in 19,709 nodes, over 132 programs. `tools/bootstrap.sh` is a byte-identical fixpoint at 283,863 bytes. The 283,268-byte figure is the compiler before the five `:c::compile` calls were added to `:user::main`. The instruction drop of 0.219% was measured on that earlier binary. No cycle claim.

Nothing further. The tree stays dirty.
