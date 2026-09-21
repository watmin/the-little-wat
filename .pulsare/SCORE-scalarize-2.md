# SCORE — scalarise, built

Tree was `535c8d2`. The classifier is in `elf/compile.wat`. Bootstrap
reproduced itself: 75 binaries byte-identical, stage1 == stage2, 229,326 bytes.
`elf-run` 30/30, same refusals and traps.

## The walk

`:c::use-walk` returns none, one field, or other. A field read is
`(:R/f name)` resolved with `:c::acc-index`, and the record name has to be the
parameter's. An `assoc` of the parameter is a write of that field only when the
assoc itself is an argument of a tail self-call; anywhere else the result
would be a record and the register no longer holds one. A bare name is other,
except as that same tail argument, where it is the field already in the
register.

The arms of an `if` are unioned, not maxed. A read of `a` on one arm and a
read of `b` on the other is other. So is a bare `s` on either arm, and so is a
self-call that is not in tail position — that call re-enters the prologue,
which still expects a pointer. Two fields cannot agree on one `f`. A function
whose return type is a record is left alone, so the transform cannot hand a
field back where a pointer is required.

The entry `mov 8+8f(%p), %p` is in the prologue, after the parameter load and
before the tail target. `main` still passes the pointer. The back edge jumps
to the body.

## What moved

`tools/emitted.sh`: 2 of 74. `rec.elf` and `moved.elf`.

`user/leak` in `elf/src/moved.wat` is the same shape by the rule above. Its
only uses of the `Box` parameter are two reads of field `v`, and it returns an
`i64`. The record does not escape. The answers are unchanged: 304, 3, 304, 3,
then the thread counts. `elf-run` agrees.

`rec`, 2,000,000 iterations, `taskset -c 0`, printing `1999999000000`:

| | ins | cycles | uops retired | slots | slots/cycles | per iteration |
|---|---:|---:|---:|---:|---:|---|
| `rec` | 16,000,208 | 3,023,693 | 14,004,255 | 18,025,662 | 5.96 | 8.00 ins, 7.00 uops, 1.51 cyc |
| `recflat` | 16,000,201 | 3,005,860 | 14,003,122 | 18,035,160 | 6.00 | 8.00 ins, 7.00 uops, 1.50 cyc |

The hot path is the field load once, then `mov rax, rbx; add rax, r12; jo;
mov rbx, rax; add r12, 1; jo; cmp; jne` back to the body, not to the load.
That is `recflat`. `slots/cycles` on this run of `rec` was 5.96, not 6.

`rec1` still prints `1999999`, 14.00 instructions per iteration, 2.39 cycles.
It returns the record, so the bare name is other and the transform does not
fire. `recflat` was not a record and did not move.
