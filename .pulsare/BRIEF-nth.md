# BRIEF — `nth` on a promoted vector: 37 uops against C's 3

Tree `d470e1d`. F-164 put vectors on the board for the first time and split them cleanly:

| per element | ins | uops | cycles | retiring |
|---|---|---|---|---|
| BUILD — ours `conj` | 33.00 | 30.0 | **6.717** | 74.5% |
| BUILD — `gcc -O2` | 15.12 | 15.8 | 8.854 | 29.8% |
| READ — ours `nth` | 36.00 | **37.0** | 5.03 | |
| READ — `gcc -O2` `buf[i]` | 4.00 | **2.9** | 1.37 | |

`conj` beats gcc by 1.32x. `nth` is 3.7x behind and it is the open item.

## What it costs today, and why

`elf/compile.wat:1370` emits the arm test inline and calls out for the tree:

    cmp qword [rax-16], 0     which arm
    jne +7                    tree
    mov rax,[rax+rcx*8+8]     FLAT: one load, already as good as C
    jmp +5
    call tree_get

`elf/lib/runtime.wat:722` `:c::rt-tree-get` is a 32-way trie walk: three pushes, then per
level `mov, mov, shr, and, load, sub, test, jcc` — eight instructions — and 2,000,000
elements is four or five levels, then the leaf load, three pops and `ret`. About forty-two
instructions. That is the 37 uops.

**The flat arm is already C's single load.** The cost is entirely the promoted tree, which is
C-145's bargain: promotion made `conj` O(log n) and closed a 1,580x cliff. The build half of
F-164 is that bargain paying off. This is the bill.

## The shape that matters

`elf/bench/vecsum.wat` reads 0, 1, 2 … n−1 **in order**, and so does every fold, map and sum
anyone writes. A tree walk per element makes a full traversal O(n log n) where an array is
O(n), and the walk repeats almost all of its work: consecutive indices share every level
above the leaf.

**A leaf cache is the obvious candidate** — remember the last leaf node and the index range it
covers; if the next index falls in it, skip the walk and do one masked load. Sequential access
then walks once per 32 elements, so about 31 of every 32 walks disappear: roughly six
instructions on a hit against forty-two on a miss.

It is not the only candidate and I am not fixing the design. Others: raise `:c::arr-max` (8
today) so more vectors stay flat — but a flat `conj` is the O(n) copy C-145 removed, so that
trades the win back; or a cursor form for iteration, which changes the language surface rather
than the runtime.

## STOP triggers

1. **If the cache can go STALE, STOP.** `vec_conj_own` (`elf/lib/runtime.wat`, routine 26)
   mutates a vector in place when the share count proves it unique. A cached leaf pointer that
   survives a mutation is a wrong answer, not a slow one. Invalidation must be structural —
   name where it happens — not a comment saying callers should be careful.
2. **If the fix needs the compiler to recognise sequential access, STOP.** That is a pattern
   match on the shape of a loop and it is the F-129 cliff: fast until someone writes the index
   differently. The runtime should be faster for any access pattern, or at least never slower.
3. **If `conj` regresses, STOP.** The build is the half we win, 6.72 against 8.85, and it is
   not available to trade.

## Expectations — fixed before the strike

| what | command | expected |
|---|---|---|
| self-hosts | `./tools/bootstrap.sh` | byte-identical fixpoint |
| blast radius | `./tools/emitted.sh check` | programs using `nth` on a Vector; `rec`/`recflat`/`strbuild` untouched |
| answers | `./tools/elf-run.sh` | 30/30, same refusals and traps — `deepvec.wat` asserts every element against the closed form and is the load-bearing one |
| `vecsum` read half | `taskset -c 0 perf stat -e '{cpu_core/instructions/,cpu_core/cycles/,cpu_core/topdown-retiring/,cpu_core/slots/}' ./elf/out/vecsum.elf` | toward `grow2000000` + C's read: the read half from 37 uops toward single digits |
| `grow2000000` | same | **must not regress** — 33.00 ins, 30.0 uops, 6.717 cyc |

No predicted cycle figure. Report ins, uops, retiring slots, slots, cycles separately, and
state `slots/cycles` when it is not 6. On this benchmark we retire at 91–95% while gcc is at
31% — the uop count is not the whole story here and the retiring fraction has flipped the
reading twice this session already.

## Ground

`elf/bench/vecsum.wat`, `elf/bench/grow2000000.wat`, `elf/bench/deepvec.wat` (the assertion
test — every element checked), `elf/bench/vec.c`, `elf/compile.wat:1370` (the arm test),
`elf/lib/runtime.wat:722` (`rt-tree-get`), routine 26 `rt-vec-conj-own` (the mutation).
