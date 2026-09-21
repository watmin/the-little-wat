# SCORE — the three losses

Tree `ff13ef2`. Records is the one that is real, and it does not need an
allocator. The fib defence holds against unchecked gcc and overclaims against
`-ftrapv`. The triple defence does not hold: the 1.33× is not "the trapping."

## Records

Remeasured, `taskset -c 0`, 2,000,000 iterations, all three printing
`1999999000000`:

| | instructions | cycles, three runs | per iteration |
|---|---:|---|---|
| `rec` | 32,000,210 | 13.37M, 12.44M, 12.04M | 16.00 ins, 6.0–6.7 cyc |
| `recflat` | 16,000,200 | 3.018M, 3.027M, 3.005M | 8.00 ins, 1.50 cyc |

The gap is the carried store and reload. `recflat` is that loop with the sum
in the parameter. It is not "exactly gcc." `gcc -O2` on the same addition,
`a += i; i += 1` for the same bounds, does not run it: 187,410 instructions
and ~0.25M cycles, the sum computed closed. Milliseconds against that build
are not a ceiling.

The spare-register arithmetic is real and it is not the obstacle for this
loop. `nr = min(nparams, 4)`. `step` has three parameters, so one callee-saved
register is unclaimed. `nlr` is `min(4 - nr, slots)` when the function is not
call-free, and this body has no `let`, so `slots` is 0 and that spare is not
handed to anyone. `callfree?` is false because `slot_set_own` returns, which
also keeps r8–r11 out. A transform that needs a *new* register fires for this
arity and dies when a fourth parameter is added. That is the cliff, and it is
the version F-150 disqualified.

It is not the only version. The record is already parameter 0, in a register.
The loop reads one field, writes it back in place, and the base case returns
that field. `b`, `c` and `d` are never read. The pointer is dead the moment
the field lives in the register the pointer occupied. No spare is required,
and a fourth parameter does not take this one away unless the record itself
is the parameter that fell off the end of the four. A second live field does
need another register, and a four-parameter function has none. That cliff is
real. This benchmark is one field.

Deleting the call also deletes the reason the function is not call-free. The
r8–r11 pool comes back after the transform, not before it. Treating
`callfree?` as a fixed fact about the source is why the spare looked like the
prerequisite.

So the prerequisite claim is too strong. Scalar replacement of one live field
into the register the record already has is buildable without an allocator.
`recflat` is what it should emit. An allocator is the prerequisite for the
general case — two hot fields, a record that is not already in a register, a
write-back where the whole record escapes — and F-150 is right to refuse a
version whose speed depends on a spare happening to exist. It is wrong that
nothing narrower is honest. This loop is the narrower one.

## Fib

The reassociation claim holds. Unchecked `gcc -O2` makes 364,490 calls against
the naive 7,049,155, and `-fwrapv` keeps that count, so the transform is not
"I may assume overflow cannot happen," it is "addition is associative."
`(a+b)+c` traps where `a+(b+c)` does not. A trapping compiler cannot make that
move. That part of the defence is right, and it is why fib is a bad place to
spend the next month.

The 3.22× against `gcc -ftrapv` should not be in the defence. F-132 already
says so: `-ftrapv` emits a call to `__addvdi3`, and ours is an inline `jo`.
That ratio is their implementation. Clang's trap, inline and with no helper
call, is the opponent, and the 2.46× there is our inlining still firing under
a rule that forbids the reassociation. That one is a real win. It is not a
reason to call the unchecked gap fake. Against `gcc -O2` as people write it,
fib is 1.5×, and twelve percent is all the headroom even an unchecked compiler
has left on this program. Closed as a grind. Not closed because the comparison
was the wrong language.

## Triple

`__builtin_add_overflow` is the same condition as `jo`: the signed overflow
flag, then a trap. It is not the same instruction. On `triplechk.c` at `-O2`:

- gcc strength-reduces. The three multiplies are gone. Two of the adds are
  `jo`. The third is `add; seto; …; test; jne`, because the flag has to
  survive the other flag-setting instructions. `seto` plus a later test is
  three uops where `jo` is one. That is why checked gcc at 4.97 cycles loses
  to our 4.86. The comparison flatters us, and the flattery is the shape of
  the check, not a weaker guarantee.
- clang also strength-reduces, and its three checks are `jo`, the same shape
  as ours. Twenty instructions, nineteen uops, 4.51 cycles. Our loop is still
  three `imul`s and three taken `jmp`s in the diamonds: twenty-four
  instructions, twenty uops, 4.86–4.92.

Both checked compilers deleted the multiply checks, which is what our bounds
pass already did. The surviving obligation on this program is the three
accumulator adds. "The same guarantee" is fair against clang and unfair
against gcc's `seto` as a claim that we won.

"The whole 1.33× is the trapping" is not. Unchecked gcc is 15 uops and 3.69
cycles. Checked clang, still trapping, is 19 uops and 4.51, and it did not
need undefined overflow to turn `i*3` into a decrement. That transform is
legal for us: the multiply checks are already gone. The gap from 4.9 to 3.69
is the three `jo`s *and* the three `imul`s a checking compiler has already
removed. F-159's "worth roughly one uop" prices the second of those as a
count. The `imul` is three cycles and port 1 only. Whether that shows up as
the 0.35 cycle against clang is one program, inside the band where a single
sitting does not settle a cycle, and the instruction difference is not in
doubt.

## The decision

Do not stop on the grounds that all three are closed.

- Fib is closed. The unchecked lead is a transform trapping forbids, and the
  remaining headroom is about twelve percent.
- Triple is not a semantic mismatch against checked clang. The 8% is three
  `imul`s and three taken jumps. It is small, and it is not an allocator.
- Records, for this loop, is one field reused in the register the record
  already occupies. That is smaller than an allocator, and `recflat` is the
  number it should hit: 1.50 cycles, not gcc's closed form.

The headline for someone choosing wat over C is the other frame, and it should
be said beside the first. Idiomatic `gcc -O2` is faster on both loops. On fib
that is the guarantee. On triple it is the guarantee and a transform the
guarantee does not forbid.
