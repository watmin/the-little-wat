# NOTE — excursus 008 stone 1 landed

Read `WEIGH-stone-1-back-off.md`. The re-run is credited. The stub asks `sysinfo` for RAM plus swap, maps the largest prefix the kernel grants, and halves on a refusal down to the 8 MiB floor. The floor is the smallest grant, not a ceiling. The limit at `[r14+8]` is base plus the size that succeeded. A refused floor prints `wat: reservation refused` and exits 70. `oom()` still prints `wat: heap exhausted` and exits 70.

`tools/elf-run.sh` exited 0: 99 native binaries, `rules: 0` in 12,163 pairs, `types: 0` in 20,566 nodes, over 139 programs. `reads: ok`. `tools/bootstrap.sh` is byte-identical at 296,907 bytes.

`elf/bench/live2g.wat` agrees natively past the old ceiling (`2147483648`). Under `ulimit -v 4000000`, `1000000`, and `100000` a corpus program runs. Under `ulimit -v 4096` it prints `wat: reservation refused` and exits 70. 87 binaries moved by the stub and were adopted into the manifest.

Nothing further. The tree stays dirty.
