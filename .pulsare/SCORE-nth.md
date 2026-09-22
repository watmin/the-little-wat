# SCORE — `nth`, stopped

Tree `d470e1d`. Nothing was built. `tree_get` is unchanged.

The 37 uops are not the trie. `vecsum` and `grow2000000` never promote, so a leaf cache in `tree_get` is not on the path the number measures. Forcing promotion so the cache would matter replaces the build that wins. That is stop 3.

## The build is the flat extend

`user/grow` in both benches is compiled to `vec_conj_own` (routine 26). In `elf/out/vecsum.elf` the call is `0x40012b → 0x400a0e`. In `elf/out/grow2000000.elf` it is `0x400122 → 0x400958`. Both targets open with

```
cmp qword [rax-0x10], 0
jne  vec_conj
```

and the retiring continuation is the youngest-object arm: compare the end of the array with `r15`, `add r11, 8`, store the element, bump the length, `ret`. The tag at `[rax-0x10]` is never written, so it stays 0. `:c::arr-max` is consulted only by the copying `vec_conj`, which this branch does not take.

A path-copy of a 32-way trie would retire one `rep movsq` step per qword of every copied node. At 2,000,000 elements that average is well above a hundred instructions per `conj`. The measured build is 33.00. It is one array, grown in place.

`perf record -e cycles:u` on `vecsum` (301 samples) lands in that extend (`0xa0e`, `0xa3c`, `0xa65`) and in the sum loop. None land in `tree_get` (`0x833`).

## The read is the flat arm, plus the loop around it

`user/sum` does emit the arm test, and the not-taken side is the one load:

```
cmp qword [rax-0x10], 0
jne tree_get          ; not taken
mov rax, [rax+rcx*8+8]
jmp +5
```

Samples sit on the `cmp` (`0x1a1`) and on the `jmp` that skips the call (`0x1b1`). The call itself is cold. Counting the loop from `0x40015e` through the tail `jmp` gives 32 instructions, one of which is the load. The other 31 are the length compare, the share `inc` on `[rax-8]`, `i+1` with `jo`, the pushes that set up `nth`, the add into the accumulator with `jo`, and the tail restores.

Same sitting, `taskset -c 0`, `cpu_core`, 2,000,000 iterations. `slots/cycles` is 6.00 on both.

| | ins | uops | retiring slots | slots | cycles |
|---|---|---|---|---|---|
| `grow2000000` | 66,000,218 | 60,042,004 | 60,063,698 | 76,581,216 | 12,765,862 |
| per iter | 33.00 | 30.02 | 30.03 | 38.29 | 6.383 |
| `vecsum` | 138,000,646 | 134,217,771 | 134,332,823 | 143,325,816 | 23,890,034 |
| per iter | 69.00 | 67.11 | 67.17 | 71.66 | 11.945 |
| difference | 36.00 | 37.09 | 37.13 | 33.37 | 5.562 |

The difference matches the sum loop above, not a four-level walk. `retiring/slots` is 78.4% on the build and 93.7% on build+read.

## Why the cache does not apply

`deepvec` does not supply the missing trie. `user/add` is one `conj` of its parameter, compiled to `vec_conj_own` at `0x400e2c`, same tag test, same extend. The file's own comment says that path never promotes. The assertions then read a flat array. A wrong `tree_get` would not fail them.

A leaf remembered on a vector header would be consulted only after the arm test branches to `tree_get`. That branch is not taken here. Installing the cache, and widening the tree object so the words stay zero, would change binaries that merely contain the runtime prefix and would leave `vecsum`'s 37 uops where they are.

The edit that would make the walk run is to stop taking `vec_conj_own` on this accumulator. That is the 33-instruction build. It is not available to trade.
