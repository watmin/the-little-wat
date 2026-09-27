# SCORE — excursus 008 stone 1: the heap grows to demand

`:c::heap-bytes` is gone. It is not a floor. A fixed ceiling is not the machine, and this stone removes the 1.9 GB one.

The stub asks `sysinfo` (syscall 99) for `totalram` (offset 32), `totalswap` (offset 64) and `mem_unit` (offset 104, a `u32`). The reservation is `(totalram + totalswap) * mem_unit`, mapped with `PROT_READ|PROT_WRITE` and `MAP_PRIVATE|MAP_ANONYMOUS` (`r10 = 34`, no `MAP_NORESERVE`). A `mem_unit` of 0 is read as 1. That is a floor on the unit. A zero size still fails `mmap` and takes the named stop.

On this box the product is 99,885,187,072 bytes (`mem_unit` was 1). The 8192-byte output buffer is the front of that mapping: `r15 = base + 8192`, and `[r14+8] = base + reservation`, added in registers (`mov` / `add`), so the limit is 64 bits. The `lea` of the total is gone. `mmap(RAM+swap+8192)` — 99,885,195,264 bytes — was refused here; `mmap` of the product was accepted. Putting the buffer on top would make every program hit the refusal stop. Usable heap is the reservation minus 8192. Pages commit when touched. A run of the live fixture showed one anonymous mapping of exactly 99,885,187,072 bytes.

A refused `sysinfo` or a refused `mmap` prints `wat: reservation refused` and exits 70, before `r14` is trusted. `oom()` still prints `wat: heap exhausted` and exits 70. Its prose says the reservation is the machine's RAM plus swap, it does not grow past that, and running out is the program's responsibility.

`:c::stub-len` asserts that `(:c::stub 0 lay)` and `(:c::stub (:asm::base) lay)` have the same length. The reservation is computed at run time, so the numbers are not in the encoding. The emitted stub is 261 bytes. The previous stub was 117. The delta is 144.

## Expectations

| # | result |
|---|---|
| 1 | `elf/bench/live2g.wat` retains 2,147,483,648 bytes (a 64-byte seed doubled 20 times, then that 64 MiB chunk appended 31 times). Above 1,900,000,000 and under 32 GB. Native and interpreter both printed `2147483648`, `"0123456789abcdef"`, `"0123456789abcdef"`, exit 0. Peak RSS 5,917,352 KiB. The mapping is ~93 GiB virtual; the resident set is the pages the copies touched, including capacity the bump does not return to the kernel. Not on the elf-run corpus. |
| 2 | `tools/mem.sh` exited 0 both before and after. Five repeats of each binary (old stub archived first): the new range sits inside the old noise. See below. |
| 3 | A mutant `mov rax, -1` after `mmap` printed `wat: reservation refused` and exited 70. Reverted. |
| 4 | A mutant that set the limit equal to the bump, then `(concat "a" "b")`, printed `wat: heap exhausted` and exited 70. Reverted. |
| 5 | The length assert above held for every compile in elf-run and bootstrap. Stub 261 bytes either way. |
| 6 | `tools/emitted.sh check`: 87 of 96 programs changed, 0 new. Those 87 each grew by 144 bytes, and after the old stub the only differing bytes are absolute addresses increased by 144. `hello.elf` and `exit42.elf` are hand-written and identical. Seven leftovers the current compiler does not rebuild (`dz`, `grow2000`, `grow4000`, `grow8000`, `one`, `onec`, `ovf`) are byte-identical. `compiler.elf` is excluded by emitted.sh; it grew 294,005 → 295,842 because the compiler source changed. |
| 7 | Full `tools/elf-run.sh` exit 0. 99 binaries, 50 agree, 3 native-only, 10 refusals, 4 traps. `rules: 0 conflicts in 12138 pairs` (unplaced 0). `types: 0 type conflicts in 20487 nodes` (partial 0). |
| 8 | `tools/bootstrap.sh` without `--fast`. Stage 0: 99 binaries in 639,813 ms, compiler 295,842 bytes. Stage 1: the same work in 1,009 ms. 98 binaries byte-identical between the two compilers. Stage 1 equals stage 2, 295,842 bytes. `bootstrap: ok`. |

## Peak RSS, five runs each (KiB)

| program | old stub | new stub |
|---|---|---|
| memory | 512–704 | 512–704 |
| grow20000 | 672–2164 | 696–2080 |
| grow200000 | 1536–3564 | 1408–3452 |
| grow2000000 | 16012–17532 | 15840–17188 |
| freed | 12760–13328 | 13072–13384 |
| cat32000 | 1024–2964 | 1024–2612 |
| linear | 512–704 | 512–704 |

`tools/mem.sh`'s single draws sit in these spans. The one-shot `grow200000` line (1,536 then 2,416) is inside both. Nothing existing grew past that noise.

## The two runs that stopped early

`tools/reads.sh` names every `:c::mov-rm` outside `:c::read-out`. The first elf-run exited 1 there, before any program was compiled: the new loads are `totalram` and `mem_unit` in the `sysinfo` struct on the stack. They are named in `tools/reads.sh`. The checker then reported ok.

The next full elf-run executed every program. Agreements passed, `CONFLICT 0`, `TYPE-CONFLICT 0`, and it exited 1 because the ten generated `elf/refuse*.wat` copies had not been regenerated (`STALE`, the check's own instruction). `tools/gen-refuse.sh` rewrote them from `elf/compile.wat`. The full elf-run after that is the exit 0 above. It was not a re-run of a red suite; the refusal copies were still the previous compiler until then.

Nothing was committed. The tree stays dirty.

## R1 — take what the kernel grants

The first reservation was the whole of RAM plus swap, so under `ulimit -v 4000000` `arith.elf` printed `wat: reservation refused` and exited 70. A refused `mmap` is now asked again for half, and for the floor when the next half would be smaller than the floor. The stop fires only when that floor itself is refused.

The floor is 8 MiB (`:c::heap-floor`, 8,388,608). It sits above the 8192-byte output buffer, so a granted floor is a heap the bump can use. It is the smallest grant we accept, not the reservation: on an unlimited machine the first `mmap` is still RAM plus swap.

| row | result |
|---|---|
| `ulimit -v 4000000` then `arith.elf` | exit 0, printed `-28` `15` `-123` `0`, the interpreter's answer. The same halving, measured beside it, is granted at 3,121,412,096 bytes under that limit. |
| `ulimit -v 4096` (4 MiB, below the floor) | `wat: reservation refused`, exit 70. The static binary still starts; the floor mapping is what is refused. |
| `live2g` unlimited | exit 0, both sides printed `2147483648` and `"0123456789abcdef"` twice. Peak RSS 5,917,816 KiB. |
| stub length | still asserted equal for a placeholder address and `:asm::base`. 302 bytes. The previous stub was 261. The delta is 41. |
| every binary | 87 programs grew by 41 bytes. After the old stub, the only differing bytes are absolute addresses increased by 41. The hand-written pair and the seven leftovers the compiler does not rebuild are unchanged. |
| elf-run | exit 0. 99 binaries, 50 agree, 3 native-only, 10 refusals, 4 traps. `rules: 0 conflicts in 12163 pairs` (unplaced 0). `types: 0 type conflicts in 20566 nodes` (partial 0). |
| bootstrap, no `--fast` | stage 0: 99 binaries in 809,985 ms, compiler 296,907 bytes. Stage 1: 1,161 ms. 98 binaries byte-identical. Stage 1 equals stage 2, 296,907 bytes. `bootstrap: ok`. |

The refuse copies were regenerated with `tools/gen-refuse.sh` before this elf-run. Nothing was committed.
