# SCORE — excursus 008 stone 3b-3a: the worklist

Struck 2026-10-03. HEAD `271c768` (the brief commit; ancestor of `6ae2fb7`). Tree left dirty. Nothing committed. This is not a landing claim. Every gate below is a run that printed; the rows that sit outside the published band are reported as measured.

## What landed in the tree

Every type `t` with `(:c::cyclic? t pg)` — `rec:`, `henum:`, or `vec:` — is a member with an index `k`. `fn:` is not walked, so closures stay on 3b-3b. `:c::and-name-dead?` is still `starts-with? "rec:"`.

The census (`:c::glue-census`) is filled once, before pass one, the same way `gtys` already was:

- non-cyclic shapes and non-cyclic `vec:` types, plus every `vec:`'s `node:` helper (a cyclic vector keeps `node:`);
- each member's type string, which is the stub `:c::glue-addr` returns (first match);
- `mbody:` plus that type, which is the body only the drain calls;
- the always-present pseudos, now `freestr freerec freevec freenode closize pend`.

`:c::gtys-from-vecs` takes `pg` and does not keep a cyclic `vec:T` as an ordinary glue target. `k` is the order of the `mbody:` entries, 16 bits. `65536` or more is an assertion failure.

The stub is `mov r11, k; jmp pend`. `pend` is one more pseudo. Its dispatch is the `closize` cascade: compare `r11` with `k`, push the object, call that body, pop it, then free it (`:c::free-target` of member `k`'s type) or, on a check build, poison it, then jump back to the loop. A `k` the cascade does not know jumps to `:c::at-uflow`.

Two header words sit after the free-list tables and before the census: `:c::hdr-wl-head` at 1040 and `:c::hdr-wl-busy` at 1048. `:c::hdr-census-alloc` moved from 1040 to 1056. The free-list offsets did not move. Both `:c::hdr-buf` switches grew by 16, and `:c::buf-bytes` still leaves 8176 of buffer. Anonymous mmap pages are zero, so the words need no init. A pending word is `(1 << 63) | (k << 47) | next`. `pend` writes it at `[rax-8]`, links `rax` as the head, and returns if busy is already set. Otherwise it sets busy, unlinks (stores `next` into the head) before the body, runs the body, then frees or poisons, and clears busy only when the head is 0. `pend` clobbers `rax`, `rdx`, and `r8`–`r11`. It also refuses a pointer at or above `2^47` (the object, and the old head) by jumping to `:c::rt-uflow`. No fixture has taken that path, so there is no address to report for STOP-1.

`:c::dropchk-hex`, when the glue target is a member, emits the stub call and does not emit `free-hex` or poison. The drain owns both. A non-member's plain path is the same call, then free, then (check) poison, then (census) zero-count. A member's zero-count is the `add` inside `pend`, so the census counts it once. `call-pos` is still `body-pos + 1`.

Check-build guards are one signed compare. Poison is −1 and a pending word has bit 63 set, so both are negative. The decrement guard (`:c::dropchk-hex`) is `cmp [rax-8], 1; jl uflow` (`488378f801` plus `:c::cc-less`, which is 12). The increment guard (`:c::countchk-hex`) is `cmp [rax-8], 0; jl uflow`. A literal's exact 0 does not take the increment's `jl`, so it still falls through to the existing literal skip. The decrement compares with 1, which would stop a literal 0, and `:c::lit-then` jumps over that whole decrement when the count is exactly 0. The trie root guard in `:c::vec-glue-body` and the child guard in `:c::node-glue-body` use the same `cmp [rax-8], 1; jl`. Loop-index unsigned `jb`s were left. The owned-flat marker `2^32+1` is positive, so the sign test does not refuse it.

For a Vector the user pointer is at block+16 (`:c::varr-ptr`), so `[p-8]` is the count word and the tag stays at `[p-16]`. The drain runs the body, which reads that tag, and only then frees. Free's link is written at the block start, which is the tag, so the body-before-free order is what keeps `freevec` honest. The tree's RSS drop (row 3) is the evidence that this held on a cyclic vector.

`tools/reads.sh` gained three ALLOW rows, each count 1, for the loads inside `:c::pend-glue-body`: the worklist head (twice) and the pending word at `[rax-8]`. Those are the allocator header and a dead object's count slot. The count-hex caller expectation is still 6.

Fixtures copied into `elf/probe/` with sources unchanged: `drop-3b-tree.wat`, `drop-3b-mutual.wat`, and `drop-3b-closure-chain.wat` (the crawl already had the chain; row 1 names it). `drop-3b-list.wat` and `drop-3b-closure.wat` were already there. `drop-cons.wat` was not touched and was not run.

The double-decrement mutant is not in the repo. It lives only under `/var/tmp/ret-r3/s3b/mut/`.

## Gates that have printed

| # | result |
|---|---|
| 1 | 36 programs, plain and check, each `agree`, each log `EXIT:0`. The set is every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus `f209-*`, `m2-region-collision`, and `r3-*`. Five of the plain logs are named `list.log`, `tree.log`, `mutual.log`, `closure.log`, `chain.log`; the other 31 are `plain-*.log`. Answers: list, tree, mutual `99999000000`; closure `1188895`; closure-chain `20`. |
| 2 | `drop-3b-list` maxrss, `taskset -c 2`, three runs: 4600, 5792, 4848 KB. All ≤ 16,000. |
| 3 | `drop-3b-tree`: 8000, 7300, 7248 KB. All ≤ 28,000. |
| 4 | `drop-3b-mutual`: 5716, 4224, 5268 KB. All ≤ 16,000. |
| 5 | Closure samples, same method: 6952, 5812, 6064, 7524, 7352, 6060 KB. The published band is 5,820–6,492. One sample is 8 KB under it and three are above it, the highest by about 1 MB. Chain: 48708, 46948, 46936 KB, against 47,916–48,412. Two sit about 1 MB under that band and one about 300 KB over. The chain is still about 47 MB, so this stone did not free it. Every run exited 0 and printed the same answer as row 1. |
| 6 | `ulimit -s 256` on the five natives: all `EXIT:0`, answers `99999000000`, `99999000000`, `99999000000`, `1188895`, `20`. |
| 7 | `WAT_HEAP_CENSUS=1` on `drop-3b-list`: stdout `99999000000`, `EXIT:0`. `alloc.vec_new.count 2000000` (bytes 80000000), `free.record.youngest.count 2000000` (bytes 80000000), pushed 0, given_up 0, `reached.record.count 2000000`. `alloc.varr_new.count 0`. Frees match allocations. The record zero-count is the one `pend` emits. |
| 8 | Pending mutant, check build, sandbox only. A second `cmp [rax-8], 1; jl uflow` is appended after every pointer drop's zero path. Program: a two-cell `:user::L` list, println `"held"`, then the let drops it. The outer stub starts the drain; the child's stub links and returns because busy is set; the extra guard then sees the pending word. stdout `"held"`, stderr `wat: reference count underflow`, exit 70. The driver was never copied into the repo. |
| 9 | Poison mutant, same sandbox compiler. Program: a non-cyclic `:user::Box` of two `i64`s, 3 and 5, then println of their sum. No member, so the extra guard can only be looking at a poisoned count. stderr `wat: reference count underflow`, exit 70. stdout was empty: the stop landed on a poisoned temporary inside `to-string` before that line was flushed. That is still a second look at a poisoned non-member. |
| 10 | Plain: interpreter seed, native s1, s2, s3. `stage1 == stage2` at 610,494 bytes, and a further hop of `/var/tmp/ret-r3/s3b/plain-s2.elf` printed `compile: ok` with s2 == s3 at the same size (`cmp`). Check: `WAT_DROP_CHECK=1` on the compiling process (the variable is read from `/proc/self/environ`; it is not a bit baked into the binary). `stage1 == stage2` at 738,709 bytes, and the same hop with `WAT_DROP_CHECK=1` printed `compile: ok` with s2 == s3 at 738,709. |
| 11 | `tools/verify.sh` printed `verify: ok` (`EXIT:0`). Stage 0 was 1,878,924 ms and the compiler was 610,494 bytes; stage 1 was 2,744 ms; 102 other binaries byte-identical. `elf-run: ok` — 103 native binaries, 54 agree with the interpreter, 3 use syscalls it has no implementation of, 11 refusals and 4 traps. Rules: 0 conflicts in 16,864 pairs (16,783 equal, 81 a variant to its enum) over 172 programs. Types: 0 conflicts in 32,217 nodes both typed. `WAT_DROP_CHECK=1 tools/verify.sh` printed `verify: ok` (`EXIT:0`). Stage 0 was 1,761,556 ms and the compiler was 738,709 bytes; stage 1 was 3,328 ms; the same 102 binaries byte-identical and the same elf-run line. Both logs also printed `reads: ok`. Plain grew by 6,985 from 603,509. Check moved from 798,499 to 738,709 (−59,790), which is the signed guard replacing the poison `je` plus the unsigned `jb`. |
| 12 | The plain 610,494-byte compiler, saved at `/var/tmp/ret-r3/s3b/plain-fixpoint.elf`, compiling `/var/tmp/ret-r3/tree956` (`956b4bb`). One confirming run printed `compile: ok` and wrote that tree's compiler as 522,106 bytes. Three `taskset -c 2` runs of `perf stat -e instructions:u,cycles:u` around `/var/tmp/ret-r2/maxrss`, `cpu_core` counters: instructions 12,830,069,833 / 12,830,068,344 / 12,830,068,976; cycles 5,891,688,264 / 5,220,820,711 / 5,643,470,387; RSS 56,548 / 57,764 / 56,380 KB. Instructions are 0.68% above 12.744 B, inside the +1% allowance. Two RSS samples sit in 56,332–57,220; 57,764 is 544 KB above that top. That tree's `elf/out` was not copied back. |
| 13 | `tools/rsp.sh`: `rsp: ok` (exception line 9078). `tools/reads.sh`: `reads: ok` (and again inside both verifies). |

`elf/out/compiler.elf` is the check fixpoint, 738,709 bytes, because the check hop ran last. The plain fixpoint is `/var/tmp/ret-r3/s3b/plain-fixpoint.elf` (610,494). Round 3's `/var/tmp/ret-r3/final-plain.elf` is still 603,509. `tools/gen-refuse.sh` regenerated the refuse drivers during bootstrap; they are dirty and were not hand-edited.

## STOP triggers

- STOP-1: the `2^47` check is in `pend`. No fixture hit it, and neither self-compile did.
- STOP-2: member bodies are the `mbody:` cascade arms. A body drops a member field through `:c::emit-drop`, which resolves to the stub. No body calls another member body directly.
- STOP-3: the check-build probes agreed, and both self-compiles finished and fixed. No unnamed stop.
- STOP-4: the sandbox driver (`/var/tmp/ret-r3/s3b/stop4`, not the repo) censused the compiler's own types after `gtys0` and before pass one, before either verify. It printed `MEMBER-COUNT 0` and then the assertion `STOP-4 census printed` (exit 2, the stop the driver was written to take). No `MEMBER` line. No compiler type is a member.

## Round 2 — 2026-10-03

The weigh's two honest fixes, struck on the dirty tree at HEAD `7714f83`. Not a landing claim. Nothing committed. Closure RSS and the `956b4bb` instruction row were already weighed and were not measured again. `WAT` was `/home/watmin/Work/holon/wat-rs/target/release/wat` at wat-rs `89e3d49cd`. It was not rebuilt, and `~/.cache/wat-kw-007` was not used.

### The address stop

Both address compares in `pend` (the object, and the old head) now jump to `:c::at-range`, runtime index 34. That routine calls `:c::rt-abort` with `wat: heap address beyond the worklist's 47 bits` and exits 70. `:c::at-uflow` stays index 35 and stays last. An unknown `k` still jumps there: a broken index is not a high address. `:c::rt-level`'s plain floor is `rt-count - 2`, so the new stop is in the blob even when nothing else names it; a check build still includes `rt-count - 1`. `grep -a` finds both messages in the plain fixpoint and in the check fixpoint, because `pend` names both.

### The high-water word

The label stays `heap.hiwater_bytes`. `WEIGH-M2` and `SCORE-retention-sites` already quote that name as high water, and a rename would leave the measurement gap the weigh named. The word is `:c::hdr-census-hiwater`, one word after the census tables, inside `:c::census-size`, so a plain `:c::hdr-buf` does not move. The census stub stores the heap start there. `:c::census-note-top` runs only inside `census?`, after the bump's limit check (and after the reuse path's `pop-then-tail`, so a found hole records the restored top, which does not advance). It keeps the greater of that top and the stored word. Youngest-free still rewinds `r15` and does not write the word.

Two failures sat in front of the number. Path 3 of `:c::rt-vec-conj-own` skips the extend with `eb`. The note lengthens a non-reusing bump, and that distance no longer fits a rel8. The jump is `e9` only when `disp8?` is false, and the same rule covers the earlier jump that skips the extend; later addresses take `hexlen` of the form actually emitted. Without the note the short form still fits, which is the plain encoding. Then the first census run of the list printed `heap.hiwater_bytes 0`: `:c::br-over` emits the branch and not the body, and the store was only inside that length. The store now follows the branch. The bytes in the census list are `76 07` then `mov [r14+disp], r11` then `pop r10`.

That binary (`/var/tmp/ret-r3/s3b/r2c3/elf/out/probe.elf`, 55,726 bytes) printed stdout `99999000000` and exited 0. Stderr: `alloc.vec_new` 2,000,000 / 80,000,000; `total.alloc_count` 2,000,001 and `total.alloc_bytes` 80,000,032; the same two totals for free; `live_bytes 0`; `heap.hiwater_bytes 4800000`. The extra allocation is the printed string (32 bytes) and it is freed. 4,800,000 is one live list, not the twenty-round sum: 100,000 cons cells at 40 credited bytes plus the 8-byte site word `census-fresh-slide` adds before the caller commits. F-212 is closed in `FINDINGS.md` with a pointer here.

### Gates that printed this round

| | result |
|---|---|
| Fixtures | 36 programs, plain and `WAT_DROP_CHECK=1`, each `agree`, each exit 0. `N:36 FAILFLAG:0` in `/var/tmp/ret-r3/s3b/r2-probes-plain.log` and `r2-probes-check.log`. The set is every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus `f209-*`, `m2-region-collision`, and `r3-*`. Answers unchanged: list, tree, mutual `99999000000`; closure `1188895`; closure-chain `20`. |
| Chains | Plain `tools/verify.sh` printed `verify: ok` (`EXIT:0`). Stage 0 was 2,891,543 ms and the compiler was 612,458 bytes; stage 1 was 6,358 ms; stage 1 == stage 2. A further hop of `/var/tmp/ret-r3/s3b/plain-r2.elf` printed `compile: ok` and `cmp` said s2 == s3 at 612,458. `WAT_DROP_CHECK=1 tools/verify.sh` printed `verify: ok` (`EXIT:0`). Stage 0 was 3,303,988 ms and the compiler was 740,885 bytes; stage 1 was 6,159 ms; stage 1 == stage 2. The hop of `/var/tmp/ret-r3/s3b/check-r2.elf` kept `WAT_DROP_CHECK=1`, printed `compile: ok`, and s2 == s3 at 740,885. Both elf-runs: 103 native binaries, 54 agree, 3 syscall-only, 11 refusals, 4 traps; rules 0 conflicts in 16,903 pairs (16,822 equal, 81 a variant to its enum) over 172 programs; types 0 conflicts in 32,296 nodes. Both logs also printed `reads: ok` and `rsp: ok` (exception line 9082). |
| Census | The list row above. Frees equal allocs. The mark is 4,800,000, not 0. |

`elf/out/compiler.elf` is the check fixpoint, 740,885 bytes, because the check hop ran last. The plain fixpoint is `/var/tmp/ret-r3/s3b/plain-r2.elf` (612,458). Round 1's `/var/tmp/ret-r3/s3b/plain-fixpoint.elf` is still 610,494. Round 3's `/var/tmp/ret-r3/final-plain.elf` is still 603,509. Both fixpoints moved from round 1 because `:c::rt-range` is in every binary. The high-water update is not: neither verify exported `WAT_HEAP_CENSUS`. `tools/gen-refuse.sh` regenerated the refuse drivers during bootstrap; they are dirty and were not hand-edited. Stone 3b-3b was not started.
