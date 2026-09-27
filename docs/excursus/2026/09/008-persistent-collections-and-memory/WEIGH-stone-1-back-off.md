# WEIGH — excursus 008 stone 1: one row back — take what the kernel grants

2026-09-26. Credited as scored: `sysinfo` → RAM + swap, a lazy plain mapping, the 64-bit limit in
registers, the stub's fixed length (261 bytes, asserted), the named `reservation refused` and
`heap exhausted` stops, `live2g` retaining 2 GiB and finishing, every existing program's peak RSS
inside the old noise, 87 binaries moved by exactly the stub's 144 bytes, gates zero, a fixpoint at
295,842 bytes.

**R1 — the reservation sits AT the kernel's limit, and takes nothing less.** The SCORE measured it:
`mmap(RAM+swap)` accepted, 8 KiB more refused. The orchestrator measured what that costs:

```
$ bash -c 'ulimit -v 4000000; ./elf/out/arith.elf'     # a trivial program, 4 GB address-space limit
wat: reservation refused                                 # exit 70 — it cannot start
$ ./elf/out/arith.elf                                    # exit 0
```

Before this stone the same program started under that limit (1.9 GB fitted). Under strict overcommit
(`overcommit_memory = 2`), a container's limit, or any `RLIMIT_AS`, every program would refuse to
start — the opposite of *"consume the least amount necessary"*.

**The fix: reserve the largest amount the kernel GRANTS, up to RAM + swap.** On a refused `mmap`, ask
again for less (halving is enough), down to a floor; the named stop fires only when the floor itself
is refused. Say the floor and why. Fixed-width as before; the stub's length stays constant.

**Rows to show:** `ulimit -v 4000000` then a corpus program — runs, exit 0; `ulimit -v` below the floor
— `wat: reservation refused`, exit 70; `live2g` unlimited — still finishes; and the rest as before
(elf-run in full, bootstrap, the stub delta the same in every binary).

---

**Credited, 2026-09-26, on the orchestrator's own runs (after an unexpected reboot interrupted the
first attempt):** `tools/elf-run.sh` exit 0 (99 binaries; `rules: 0` in 12,163 pairs, `types: 0` in 20,566
nodes, over 139 programs); `tools/bootstrap.sh` byte-identical at **296,907 bytes**; `elf/bench/live2g.wat`
agrees natively past the old ceiling (`2147483648`); under `ulimit -v 4000000`, `1000000` and `100000`
a corpus program runs, under `4096` it prints `wat: reservation refused`, exit 70; `reads: ok`; 87
binaries moved by the stub, adopted into the manifest.
