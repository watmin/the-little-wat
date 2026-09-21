# SCORE — the record loop

F-157 (`ca8169a`) records the three concessions accurately. This is the other claim,
the one the brief kept out: `rec1` at 2.67 cycles against `rec` at 6.20, read as a
~5-cycle store-to-load forward because one loop reloads a field and the other does
not.

The dependence is in the binary. The number is not, and it does not follow from the
subtraction.

## What the two loops actually are

`elf/out/rec.elf` and `elf/out/rec1.elf` from this tree, hot path and the
`slot_set_own` they both call. 2,000,000 iterations. Pin `taskset -c 0`, PMU
`cpu_core`, same sitting, three runs apiece.

`rec`, the loop at `0x400113`:

```
mov  rax, [rbx+0x8]          ; load field a
add  rax, r12                ; a + i
jo
mov  rdx, rax
mov  rax, rbx
mov  rcx, 0
call slot_set_own
mov  rbx, rax
add  r12, 1
jo
cmp  r12, r13
jne
```

`slot_set_own`, fast path, both binaries:

```
cmp  qword [rax-0x8], 1      ; share count
jne  copy                    ; not taken
mov  [rax+rcx*8+0x8], rdx    ; rcx is 0, so [rax+0x8]
ret
```

`rec1`, the loop at `0x40010e`, calls the same three-instruction body and never
loads `[rbx+0x8]`. The value it stores is `r12`, the counter.

So the store and the load are the same address and the same width, the pointer is
the same register the callee returns, and `ld_blocks.store_forward` read 0 on all
three binaries. Forwarding is not blocked. L1 misses were a handful, not 2,000,000.
Branch misses were under a hundred across 2,000,000 iterations, so the `jo`s and
the share-count branch are predicted. The carried dependence is real: this
iteration's load reads the qword the previous iteration's `slot_set_own` wrote.

`rec1` is the right control for *that* fact, and only that fact. It is not the same
program with the load deleted. `rec` adds `i` into the field and prints
`1999999000000`. `rec1` stores `i` and prints `1999999`. F-146 already recorded
that they compute different things. The instruction gap in this binary is exactly
two per iteration (the load, and the `jo` on an `add` that replaced a `mov`), not
"the field read."

## What the cycles are

| | ins/it | cycles/it, three runs | branches/it |
|---|---:|---|---:|
| `rec` | 16.00 | 6.26, 6.12, 6.49 | 6.00 |
| `rec1` | 14.00 | 2.340, 2.339, 2.337 | 5.00 |
| `recflat` | 8.00 | 1.502, 1.503, 1.502 | 3.00 |

`rec` moves. `rec1` and `recflat` do not. The gap from `rec1` to `rec` is 3.8 to
4.2 cycles depending on which `rec` run you subtract. The pair cited in the brief,
6.20 − 2.67, is 3.53. Neither difference is 5. "~5-cycle forward follows directly"
is a subtraction that was not done, rounded up.

F-148's finer split has the same shape as the formula in F-155. It takes `rec1`'s
IPC, prices the extra instructions at that rate (~0.8 cycles), and calls the
leftover (~2.25) the forward. That IPC is the rate of a loop whose carried chain
does not include the load. The load is what changes the chain. You cannot cost it
at the rate the loop had before it was there.

The published counts are also from an older binary. This one retires 16 / 14 / 8
instructions an iteration, not 17 / 15 / 9. The cycles have moved with them
(`rec1` 2.67 → 2.34, `recflat` 1.91 → 1.50). The shape is the same. The digits in
the finding are not the digits of `elf/out` today.

## What the gap is allowed to mean

`recflat` is the register chain: 1.50 cycles, no load, no store, no call.
`rec1` adds the in-place store and pays 0.84 to get to 2.34. The store is cheap
when the next iteration does not read it. `rec` reads it, and pays about four
more.

Those four cycles are the load, the `add` that consumes it, and the fact that the
call cannot store until that `add` has produced `rdx`. They are not a measurement
of forwarding latency. The store sits inside the callee, one instruction before
`ret`, and the load is on the other side of the return, after `mov rbx, rax`. The
subtraction also contains the `add`. Isolating "the forward" would mean a loop
that differs by that load and nothing else. This pair does not.

Both loops already contain a store-to-load forward that does *not* show up as five
cycles: `call` pushes the return address and `ret` pops it. `rec1` does that on
every iteration and still finishes in 2.34. That forward is not on the value
chain. The field forward is, because the next call's argument is the loaded qword.
That is why one of them costs and the other does not, and it is visible in the
instruction stream without a latency number attached.

## Verdict

The mechanism holds: `rec` is a loop-carried store and reload of one qword, in
place, forwarded rather than missed, and `rec1` does the store without the reload
and is several cycles faster for it. The diagnosis that does not hold is the
quantitative one. Nothing here measures a 5-cycle forward, the 6.20 − 2.67
subtraction is 3.53 and was reported as ~5, and splitting that gap by `rec1`'s IPC
repeats the mistake F-157 just retired — treating a rate measured on one schedule
as a property you can carry onto another.

Scalar replacement is still the transform that removes the carried load. What it
is worth is the gap from `rec` to `recflat` measured in one sitting, reported as
cycles of each binary, not as a forwarding latency derived from their difference.
