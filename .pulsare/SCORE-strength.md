# SCORE — strength reduction, stopped

Tree `59ce92d`. Stop 1. Nothing was built. `triple` is unchanged.

The hot loop in `elf/out/triple.elf` is the assignment the brief describes:

```
imul r8, rbx, 3      rbx = i
add  r8, r12         r12 = a     r8  = a2
imul r9, rbx, 5      r13 = b     r9  = b2
add  r9, r13         rbp = c     r10 = c2
imul r10, rbx, 7                 r11 unused
add  r10, rbp
lea  rbx, [rbx-1]
```

`nr = min(4, 4) = 4`, so `i a b c` take rbx, r12, r13, rbp. The body is
call-free, `slots = 3`, and `nlr = min((4-4)+4, 3) = 3`, so `a2 b2 c2` take
r8, r9, r10. `nscr = 1`, which is r11, and this loop does not use it: the
`imul` writes the let register directly.

Three carried counters have to be live together with `a`, `b`, `c` and with
`a2`, `b2`, `c2`, because each `a2` is `a` plus its counter and the three
lets are all alive before any tail argument overwrites an accumulator. That
is nine values. The file has eight registers. One spills.

Eliminating `i` frees rbx and drops the peak to eight values in eight
registers, with nothing left for the address arithmetic the lets already do
in a register. It does not free three. r11 is the other unoccupied register.
rbx and r11 are two homes. The third counter still lands on the stack.

Taking r8–r10 away from `a2 b2 c2` would make the counters fit, and that is
computing the accumulator in place. C-189 did that, lost the cycle, and was
reverted. The probe was not a licence to repeat it.

Keeping `i` and adding the counters is worse, which is stop 2 as well: the
test has to become one of the counters or the induction variable stays, and
carrying both is the nine-value peak plus `i`. Clang's six values fit in its
allocator. They do not fit in this one while the three lets keep their
registers.

A spilled counter is `triple2`: three loads, three stores, and a `jo` on the
decrement. F-131 measured that and it lost. The decrement's `jo` was not
reached. There is no register to put the counter in, so there is no
strength-reduced `triple` to time.
