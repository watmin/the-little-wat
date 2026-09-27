# SCORE — excursus 008 stone 2: every reference is counted

A pointer held in one more place is one more count. No wat value is stored through `poke`. Nothing here drops a count: that is stone 3. The tree is dirty; nothing was committed.

The count lives in the header word at `[p-8]`. A fresh heap object is born at 1. The compiler tells the runtime which slots are pointers, because a large `i64` is not a pointer and this machine's reservation is a lazy mapping: a load of an address inside it commits a page. `r10` is 1 when a vector's elements are pointers and 0 otherwise, set at the conj site and preserved across `tree_from_arr`. `r11` is the record's pointer-field mask, or, inside `tree_push`, 1 when the node being copied holds child pointers. A record of 64 or more fields is a compile failure: `compile: a record with more than 64 fields has no pointer mask`. No such record is in the corpus.

## Expectations

| # | result |
|---|---|
| 1 | `elf/probe/poke-string.wat` is refused by the compiler: `compile: cannot compile poke of a pointer: (wat.os/poke p s)`. `peek` is still `i64`. `elf/native/thread.wat` printed `11` `22`. `elf/native/threads4.wat` printed `1000`. Both are native-only in elf-run; the interpreter has no `wat.os`. |
| 2 | `count-vec`, `count-trie`, `count-own`, and `count-rec` agree with the interpreter. `rt-cpath` is not a pointer-slot copy: it is `rep movsb` of a path onto the heap top plus a NUL, the same shape as `rt-print-str`. `tools/copies.sh` lists both as bytes. The other four routines increment. So does the leaf walk in `tree_push`, and the store of an old root under a new one. |
| 3 | One mutant per increment, each reverted. Dropping `count-copied` in `rt-vec-conj`, `count-copied` in `rt-vec-conj-own`, `count-span` in `rt-node-copy`, `count-masked` in `rt-slot-set`, and the leaf `count-span` in `tree_push` left the fixture agreeing. `:c::share` and `:c::read-out` already increment a named pointer, and nothing drops, so a missing copy-increment cannot show up in a printed value. Node counts are not readable until stone 3. The increments stay. |
| 4 | `tools/copies.sh` printed `copies: ok -- every bulk copy is counted or is bytes`. `tools/copies.sh --plant` printed `copies: FAIL -- rt-evil copies slots and nothing counts them` and exited 0, which is the plant refusing an uncounted `rep movsq`. |
| 5 | Full `tools/elf-run.sh` exit 0. `reads.sh` and `copies.sh` ran inside it, both ok. 103 native binaries, 54 agree, 3 native-only, the refusals, 4 traps. `rules: 0 conflicts in 12398 argument-parameter pairs` (unplaced 0). `types: 0 type conflicts in 20946 nodes` (partial 0). `checker-multi` is the same class of note as stone 1; it is not a conflict. |
| 6 | `tools/emitted.sh check`: 42 of 96 programs changed, 4 new (`count-vec`, `count-trie`, `count-own`, `count-rec`). Against the pre-change snapshot, 56 binaries are byte-identical, including `arith.elf`, and 43 moved. `hello.elf` and `exit42.elf` are hand-written and identical. The stub is still 302 bytes. Where a binary grew, the stub's only changed byte is the displacement of its call into the program. The moved bytes are the count loops and the `r10`/`r11` setup in the runtimes that copy pointer slots. |
| 7 | `tools/bootstrap.sh` without `--fast`. Stage 0: 103 binaries in 926,520 ms, compiler 304,181 bytes. Stage 1: the same work in 1,574 ms (588x). 102 binaries byte-identical. Stage 1 equals stage 2, 304,181 bytes. `bootstrap: ok`. |
| 8 | Instructions **+10.22%** against `/tmp/compiler-stone1.elf` (296,907 bytes) at its own fixpoint. Cycles are not claimed. STOP-2 is reported below; the counts were not removed. |

## What the first red run was

The first full elf-run, log `/tmp/stone2-elf.log`, was red. `pvec`, `moved`, and `reader` grew without bound and printed nothing. Two defects, both since fixed, and this score's elf-run is the run after the fix.

`tree_from_arr` called `tree_push` after `node_new` had overwritten `r10`. A nonzero garbage flag made the leaf walk treat `i64`s at or above a page as pointers. On this machine those loads first-touch the lazy reservation. The flag is saved across that call and reloaded from `[rsp+24]` before every push.

`node_copy`'s slot walk then stored `-1` in `rdx`, which `tree_push` was using as the shift. The descent never hit zero and allocated a node per step. `node_copy` now restores `rdx` and the caller's `r11` (`node_new` spends `r11` on the bump). A third defect was in the same function: the alignment pad was popped back into `rax`, so `tree_from_arr` returned the flat array instead of the tree, and the following `tree_push` read the first two elements as shift and root. The pad is discarded into `r11`.

After that, `pvec` agrees (including the 1025 probe and the string and record probes) and `moved`'s `user/thread` of 20000 agrees: `304`, `3`, `304`, `3`, `20000`, `20000`, `20000`, `1`, `200010000`. `reader` agrees. An `i64` conj site moves 0 into `r10`, so the copy walk is skipped and does not disturb `arm-own`. `grow20000` and `linear` agree inside the suite's 60-second native limit.

## Cost

Both compilers ran their own `main` in a private directory, so `elf/out` in the tree was not rewritten. Each compiled the current sources, including the current `elf/compile.wat`. `taskset -c 0`, `perf stat -e cpu_core/instructions/,cpu_core/cycles/ -x,`, nine repetitions, two rounds. `best_cyc` is the cycles of the minimum-instruction repetition.

| round | stone 1 instructions | stone 1 cycles | stone 2 instructions | stone 2 cycles |
|---|---:|---:|---:|---:|
| 1 | 2,966,025,191 | 1,588,476,577 | 3,269,238,833 | 1,775,428,588 |
| 2 | 2,966,025,131 | 1,586,452,035 | 3,269,238,776 | 1,718,726,146 |

Instructions agree across rounds (the two stone-2 minima differ by 57). The rise is 303,213,642 instructions, **+10.22%**. That is past the 5% line.

The stone-2 cycle figures differ by 3.3% between rounds, which is past 1.8%, so this score does not claim a cycle change.

The counts were not taken out. Programs that never copy a pointer slot did not change at all (`arith.elf` is byte-identical, 887 bytes). Programs that do grew by about 500 to 600 bytes (`pvec.elf` 5,543 to 6,140, `reader.elf` 10,038 to 10,555, `moved.elf` 3,866 to 4,376). The compiler itself grew 296,907 to 304,181.

## The split

Five compilers, each built by the stone-2 fixpoint from the current sources with one routine's increment removed, then run on the unmodified sources. Same measurement as the two ends: `taskset -c 0`, `cpu_core/instructions/` and `cpu_core/cycles/`, nine repetitions, two rounds, the minimum-instruction repetition. Every one printed `compile: ok`. Instruction counts agree across rounds (the spread inside a round is under 1,200). Cycles do not: `vec-conj-own`'s two best-cycle figures differ by about 7%, so this section claims no cycles.

The figure in the last column is how many instructions that routine's increment accounts for: the full stone-2 run minus the run with that increment removed (round 1).

| compiler | round 1 instructions | round 2 instructions | removed vs full |
|---|---:|---:|---:|
| stone 1, its own fixpoint | 2,966,025,191 | 2,966,025,131 | |
| no `rt-vec-conj` `count-copied` | 3,266,595,236 | 3,266,595,101 | 2,643,597 |
| no `rt-vec-conj-own` `count-copied` | 3,266,591,683 | 3,266,591,365 | 2,647,150 |
| no `rt-node-copy` `count-span` | 3,267,716,417 | 3,267,716,376 | 1,522,416 |
| no `rt-slot-set` `count-masked` | 3,267,030,887 | 3,267,031,171 | 2,207,946 |
| no `tree_push` leaf walk and old-root increment | 3,267,006,471 | 3,267,005,725 | 2,232,362 |
| stone 2, full | 3,269,238,833 | 3,269,238,776 | |

The five increments add to 11,253,471 instructions, 3.7% of the +303,213,642 and 0.38% of the stone-1 run. The hottest is `rt-vec-conj-own`'s copying path, and `rt-vec-conj`'s flat copy is 3,553 instructions behind it. `rt-slot-set` is third. Taking every one of these increments out would leave the rise at about +9.84%. They are not the 10%.

`perf record -e cycles:u -F 1000` on the full stone-2 compiler (1,909 samples, `compile: ok`) does not land in those walks. The hottest addresses are string equality (`repz cmpsb`, 156 samples) and the `rep movsb` inside string `concat` (82 samples). One assoc of `:c::Out` is visible just beside them: `movabs r11, 0x78e` then the call. That mask is `:c::Out`'s pointer fields and no others — `code`, `tail`, `rax`, `shared`, `fnames`, `faddrs`, `caps` — which is the guess. Its increment is the 2,207,946 line above, not the 303 million.

The `conj` those two vector routines count is the one `:c::buf-add` does on every `:c::emit`: `(conj (:c::Buf/ch b) s)`. A chunk vector still flat and not last-use takes `rt-vec-conj`; a last use that cannot extend takes `rt-vec-conj-own`'s copy. Past eight chunks the same conj is `tree_push`, whose own increment is the 2.2 million.

What would put `:c::Out` on the in-place path, and what does not. `:c::rt-slot-set-own` is already there. It writes the field where it stands when the header is exactly `:c::heap-arm` (1), and the compiler calls it only when the container is a symbol in `:c::Prog/linear`. `:c::emit` is `(assoc (assoc o :code (buf-add (Out/code o) hex)) :rax "")`: the inner `o` is also read, so it is not linear, and the outer container is a call, not a symbol. `:c::push` assocs the result of `emit` and also reads `(Out/sp o)`. All three call `rt-slot-set`. Binding the field read and the inner assoc to names would make the containers symbols. It would still not be enough. `:c::linear` lists parameters only, not `let` names, and `:c::share` bare-increments a `rec:` symbol on the way into `emit`, so a parameter arrives with a header of at least 2 and `slot-set-own` falls through to the copy. Catching `emit` would take both: a linear name whose only remaining use is the assoc, and a call that does not increment a record it is done with. Nothing here was changed to do that.

## Where the other 292 million are

The five increment bodies are 11.3 million. The other 291,960,171 instructions are not a hidden loop. Two measurements place them.

The runtime blob in a compiler is emitted by the compiler that built it, not by the `runtime.wat` that compiler reads while compiling the next one. A build of the current source by the stone-2 compiler therefore still carries the stone-2 runtime; that binary cannot isolate the flag loads. The build that does isolate the new source is the one the stone-1 compiler itself emitted, from this tree, on the same input. Its own runtime is the stone-1 runtime (its `node_copy` is the old prologue, and it contains no `movabs r11`). Its wat functions are the current source. Same method, two rounds:

| compiler | round 1 | round 2 |
|---|---:|---:|
| stone 1 fixpoint | 2,966,025,191 | 2,966,025,131 |
| current source, built by the stone-1 compiler | 3,002,925,956 | 3,002,925,360 |
| stone 2 fixpoint | 3,269,238,833 | 3,269,238,776 |

The current source on the old runtime and the old emission of its own body costs **+36,900,765** instructions (+1.24% of stone 1, 12% of the rise). Rounds differ by 596 instructions. The remaining **266,312,877** appears only in the stone-2 fixpoint, which is the first binary whose own `conj` and `assoc` sites carry the loads and whose own runtime is the rewritten one. Those two arrive together; one generation cannot build one without the other.

`perf record -e cycles:u -F 1000` on both fixpoints, same input (1,242 samples and 1,417). One sample is about 2.3 million instructions, so a move of a few samples is noise. Scaling each routine's samples by that run's measured instruction count, the routines that moved by more than a handful of samples:

| routine | stone 1 | stone 2 | delta | edited by this stone |
|---|---:|---:|---:|---|
| `rt-str-eq` | 497 M | 570 M | +73 M | no |
| `rt-str-cat` | 322 M | 383 M | +61 M | no |
| `rt-tree-push` | 12 M | 72 M | +60 M | yes |
| `rt-node-copy` | 45 M | 76 M | +31 M | yes |
| `rt-slot-set` | 72 M | 88 M | +16 M | yes |

`str-eq` and `str-cat` were not rewritten. They are the routines the profile already spent the most time in, and they now run more, because the compiler emits more hex and compares more names. `tree_push` is the routine the diff touches most (the flag in `rbp`, the leaf walk, the old-root increment, the extra saves). It is entered from `vec_conj` once a vector has promoted, which for this compiler is `:c::buf-add` after eight chunks, and the vectors that hold the syntax tree. `node_copy` is the child walk it calls. `slot-set`'s sample growth is eight samples, inside the noise; the mask the samples sit near is still `0x78e`, `:c::Out`.

The call sites did not multiply. Stone 1 and stone 2 have the same number of direct calls: `vec_conj` 39, `vec_conj_own` 60, `slot_set` 70, `slot_set_own` 12, `tree_get` 659 and 664. The stone-2 compiler adds 102 `mov r10, imm` and 82 `movabs r11, imm` at those sites. The stone-1 compiler has none. A sample almost never lands on the load itself.

None of this is the defect the first run had. That one did not finish, and the instruction count climbed without a bound. This one finishes, and the two rounds of every compiler here agree to within about a thousand instructions. The extra work is the loads and the longer trie routines on paths the compiler already took, plus more string comparison and concatenation. It is a cost.
