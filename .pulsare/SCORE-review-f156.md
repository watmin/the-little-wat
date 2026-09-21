# SCORE — review of F-155 / F-156

Reviewer: grok. Stone: `the-little-wat/.pulsare/review-f156.md`, against the tree at
`9ca0a01` (F-156) and the binaries in `elf/out/` from that commit. Machine: 12th Gen
i7-1270P, P-core (Golden Cove, allocation width 6), pin `taskset -c 0`, PMU `cpu_core`.
C-189 is not in the tree — it was reverted before the finding was committed — so claims
about its schedule are checked against the measured 21 ins / 17.05 uops and against
`elf/compile.wat` as it stands. The kept binary was disassembled, not remembered.

## Verdicts

1. **The formula is not a model.** `cycles = uops / (6 × retiring%)` is `slots / 6`
   rewritten. It matches a cycles counter only when that counter happens to equal
   `slots / 6`. Holding retiring% constant and predicting a future binary is the only
   use that can be wrong, and C-189 already showed that use fail. The post-hoc fit on
   C-189 means the counters were consistent. It does not mean the formula predicted
   anything.

2. **The decoupling story does not describe the loop that was measured.** The hot path
   of `elf/out/triple.elf` has no `mov %rax,%rN`. The three instructions that separate
   24/20 from 21/17 are the three taken `jmp`s. A hot `mov` added on top of that would
   have cancelled the saving. `add %r12, %rax` does not serialize against the following
   `lea` beyond the read the `lea` has in either schedule; the renamer already breaks
   the write-after-write. This is F-151's mechanism, which F-153 already falsified,
   stated again. The backend-bound jump from 16.5% to 37.6% is what the percentages do
   when three retiring uops and the front-end bubbles disappear and the cycles do not
   fall. It is not a separate observation of a longer chain.

3. **Trapping does not forbid strength reduction, and the proof the claim says is
   missing is already in the binary.** The three `imul`s and the `i - 1` ship with no
   `jo`. The three `jo`s that remain are the accumulator adds, which strength reduction
   does not remove and which no interval can prove (C-170). The uop saving is two, not
   three, and `17 uops → 4.08 cycles` is the constant-retiring% prediction one section
   earlier had just watched fail. `triple2` does not measure the transform: it still
   spills three counters and still emits `jo` on the decrements. Whether a
   register-resident, check-free decrement is faster is unmeasured. It is not the same
   wall C-189 hit.

## Claim 1 — the identity

`cpu_core/topdown-retiring/` is a slot count. `cpu_core/slots/` is the slot supply.
With bad speculation at zero, retiring slots and `uops_retired.slots` are the same
number (measured, below). So

```
retiring%  =  uops / slots
uops / (6 × retiring%)  =  slots / 6
```

The `6` is Golden Cove's allocation width, which is the right constant for this PMU.
The formula equals the `cycles` event if and only if `slots = 6 × cycles`. That
equality is not a property of the program. On this chip, with SMT left on (cpu 0's
sibling is cpu 1), it moves with whatever else the core is doing.

Same binary, `elf/out/triple.elf`, 30,000,000 iterations, 24.00 ins/it, 20.00 retired
uops/it:

| run | slots | cycles | slots/cycles | slots/6 per it | cycles per it |
|---|---:|---:|---:|---:|---:|
| quieter | 871,345,272 | 146,796,236 | 5.936 | 4.841 | 4.893 |
| busier | 853,329,684 | 154,833,062 | 5.512 | 4.741 | 5.161 |

Quieter run, the inputs the formula actually consumes: `uops_retired.slots` =
600,090,858, so retiring% against slots is 68.87%, and `20.003 / (6 × 0.6887) = 4.841`,
which is `slots/6` and not the cycles counter. Busier run, topdown-bad-spec was 0 and
topdown-retiring was 599,003,974 against 600,036,946 retired slots on the neighbouring
run — same quantity, and the four topdown buckets sum to slots within the 8-bit
quantization of PERF_METRICS (0.4% short).

`loopsum` on the same quieter sitting: slots/cycles = 5.912, so the formula misses the
cycles counter by 1.5%, not by a different mechanism. F-155's "~10% on loopsum" is a
slots/cycles of about 5.5, which is the busier row above. The residual is the slot
counter. It is not model error, and it is not evidence the formula is tracking
something other than slots.

What the exact fits in the brief are: runs where slots/cycles happened to round to 6
at one decimal place. `20 / (6 × 0.714) = 4.668`, which prints as 4.67. Predicted
4.67 against measured 4.67 is that rounding. C-189's "predicted 4.80 / measured 4.80"
is the same checksum after the fact (`17.05 / (6 × 0.588) = 4.83`, already a rounding
choice, not a prediction).

The one use that was a prediction was F-156's own: assume retiring% stays 71.4%,
conclude `17 / (6 × 0.714) = 3.97`. That was falsified, and the falsification stands.
The reason it had to fail is stronger than "the model has two terms." Retiring% is not
a term you can hold still. It is the fraction of slots that retired a uop on that run.
You cannot know it for a binary you have not run, and once you have run it you already
have the cycles.

What is worth keeping from F-155 is the comparison the formula was standing in for,
which does not need the formula. On `triple` both compilers retire near 70% of slots,
so the side with fewer uops wins. On `loopsum` gcc retires near 30% and is mostly
backend-bound, so our eight uops beat its five. Both of those are direct reads of the
counters. Neither is a derivation of cycles.

## Claim 2 — what C-189 actually removed

Hot path of the kept binary, `elf/out/triple.elf`, entry `0x40012f`. One iteration,
subtract side, which is the side that runs: `i` starts at 30,000,000 and `i * 3` is
above 1,000,000 until `i` is far below that, so the `jle` is not taken for essentially
all 30,000,000 iterations.

```
imul r8,  rbx, 3
add  r8,  r12
jo
imul r9,  rbx, 5
add  r9,  r13
jo
imul r10, rbx, 7
add  r10, rbp
jo
lea  rbx, [rbx-1]
cmp  r8,  1000000
jle                           ; not taken
lea  r12, [r8-1000000]
jmp                           ; taken
cmp  r9,  2000000
jle
lea  r13, [r9-2000000]
jmp
cmp  r10, 3000000
jle
lea  rbp, [r10-3000000]
jmp
cmp  rbx, 0
jne                           ; taken, the back edge
```

Twenty-four instructions. Four macro-fusions (`cmp`+`jle` three times, `cmp`+`jne`
once; `jo` does not fuse). Twenty uops. That is the whole of the "20.00". The copy
`mov r12, r8` exists, and the two like it, on the taken side of `jle`. They do not
retire in this benchmark. Nothing in the loop is a `mov` from `rax`.

`gcc -O2` and `clang -O2` on `elf/bench/triple.c`, compiled here, are the loops the
brief describes: three counters stepping by 3, 5 and 7, `i` deleted, the test folded
into a decrement, `lea`/`cmp`/`cmov`, sixteen instructions, fifteen uops. No dispute
there.

The measured C-189 delta is −3 instructions and −3.0 uops, exactly. An unconditional
`jmp` is one instruction and one retired uop. Deleting the three taken `jmp`s is the
only one-line change that produces that delta. A hot `mov %rax,%rN` added at the same
time would be +1 instruction and +1 retired uop per chain (move elimination skips the
execution port; it does not skip retirement), which cancels the `jmp` and leaves the
counts where they were. The brief's "adding `mov %rax,%r12` per chain" and F-156's
"the three instructions removed were `mov %rax,%rN`" cannot both be true, and neither
is the change the counters describe.

The schedule that does fit — and it matches the second sentence of F-156, not the
first — is the product in a temp and the add writing the accumulator, select in place,
no join:

```
imul rax, rbx, 3
add  r12, rax
jo
cmp  r12, K
jle  skip          ; not taken
lea  r12, [r12-K]
skip:
```

Six instructions and five uops per chain, plus `lea rbx,[rbx-1]` and a fused back
edge: 21 and 17. `:c::to-dst?` in `elf/compile.wat` refuses this today, because the
left operand of `+` is `a` and the destination would be `a`'s register, and computing
the right-hand side there would clobber `a` before the add reads it. The fallback is
compute-in-`rax` plus `mov` to the destination, which is the schedule the counts rule
out. So C-189 was not only an allocation change. It had to emit `add` into the
parameter register without the trailing `mov`. That binary is gone, so this paragraph
is a reconstruction from the counts plus the compiler's own refusal. The negative
claims above — what the kept hot path contains, and what a hot `mov` would have done
to the counts — do not depend on it.

Dependency, once the schedule is the one the counts allow. Both versions have the same
loop-carried accumulator:

```
C-188   r12 → add (writes r8) → lea (writes r12) → r12     latency 2
C-189   r12 → add (writes r12) → lea (writes r12) → r12    latency 2
```

The `lea` waits because it reads the sum, not because both instructions write `r12`.
Write-after-write is broken by rename on this core. The next iteration's `imul` reads
`rbx`, not the accumulator, in both schedules, so it is off that chain either way. A
rename-eliminated `mov` between the add and the `lea` would add nothing to the chain
and remove nothing from it. There is no decoupling for it to do.

`llvm-mca -mcpu=alderlake` on the two hot paths agrees with that and with nothing
finer: same block throughput, same cycle count, same port pressure. I do not trust its
cycle number. It prices a direct `jmp` at zero uops, and it puts a simple
`lea r,[r+disp]` on port 1 only at one per clock; the first contradicts the retired-uop
count, and the second would floor this loop at 7 cycles against the ~5 we measure. The
part that matches a known fact is the `imul`: 3-cycle latency, one per clock, port 1.
Both schedules carry three of those. C-189 did not take any of them off the loop.

The front-end drop, 14.1% → 3.5%, is the expected signature of deleting three taken
branches and is large enough to believe. The backend rise is then arithmetic. At 4.67
cycles the core offers about 28 slots. Twenty of them retire and about four are
front-end bubbles, leaving about four backend. Delete three retiring uops and shrink
the front-end bubbles to about one, and if the cycles do not fall the leftover ten
slots are labelled backend-bound, which is the reported 37%. That label moved because
the other two labels gave up slots. It is not an independent measurement that a chain
got longer.

And the cycles themselves, 4.67 against 4.80, are not a result. F-156 records the same
binary at 4.67 and at 5.09 an hour apart. F-154's rule, written the same day, is that
a sub-25% cycle difference between two builds of one program is layout and thermal
until something else replicates it. The uop count and the retiring fraction are the
stable quantities, and the retiring fraction moved because the uop count moved and the
cycles did not. "A cheap uop can be load-bearing" overclaims the evidence. The
evidence says these three were not load-bearing.

The alternative in the brief — seventeen uops no longer fill the machine, and the stall
was always there but hidden — has the inequality backwards. A stall the front end was
hiding is a floor under the old cycles. Removing front-end bubbles can lower cycles to
that floor. It cannot raise them. A real regression would mean the new schedule
lengthened the backend path. A 3% cycle move does not show that, and the dependency
structure above does not produce it.

## Claim 3 — what strength reduction can and cannot remove

Permitted and forbidden, against the binary rather than the principle:

| op in `triple` | in `elf/out/triple.elf` | why |
|---|---|---|
| `i * 3`, `i * 5`, `i * 7` | `imul`, no `jo` | C-170 proved these; `:c::dst-dead?` deleted the check |
| `i - 1` | `lea rbx,[rbx-1]`, no `jo` | same proof |
| `a + i*3` and its two siblings | `add` + `jo` | C-170: the accumulator interval never converges. Still true in this binary |
| `a2 - 1000000` under `a2 > 1000000` | `lea`, no `jo` | C-166, the dominating compare |

The multiply-range proof the claim treats as future work is already discharged. What
trapping still costs on this loop is three `jo`s on the accumulator adds. Strength
reduction does not touch those. C is exempt from them because signed overflow is
undefined there; that part of the claim is right, and it is about the adds, not about
the multiply.

Uop gap, each uop once, off the two disassemblies and not off F-155's table:

- Ours: 3 `imul` + 3 `add` + 3 `jo` + 1 `lea` + 3 fused compares + 3 `lea` + 3 `jmp` + 1 fused back edge = 20.
- gcc: 3 `add` + 3 `lea` + 3 `cmp` + 3 `cmov` + 2 `sub` + 1 fused `sub`/`jne` = 15.

The five-uop gap is the three `jo`s plus a net two from keeping a separate induction
variable (`lea` + a back edge, against gcc's three `sub`s which also replace the three
`imul`s). The `imul`-versus-`sub` is a wash in the count. It is not a wash in kind:
`imul` is 3 cycles and port 1 only, one per clock; `sub` is 1 cycle on any ALU. That
is the actual content of strength reduction on this loop, and it does not appear in a
formula that only has a uop count and a retiring percentage.

F-155's "seventeen uops, about 4.08 cycles" subtracts three and then divides by
`6 × 69.4%`. The itemization in the same section only has two uops to subtract, and
the division is the prediction C-189 falsified. Eighteen uops at a retiring percentage
you have not measured is not a cycle count.

`elf/bench/triple2.wat` is still the wrong experiment, and the current
`elf/out/triple2.elf` still shows why. The three counters live at `[rsp+0x58]`,
`[rsp+0x50]`, `[rsp+0x48]`: load, `sub`, `jo`, store, per counter. Seven parameters,
four callee-saved registers. And `m3` arrives as a parameter, so the proof that
already covers `i * 3` does not cover `m3 - 3`; the `jo` is still emitted. F-131
measured spills plus checks that a compiler transform, rewriting registers it already
holds and reusing a proof it already has, would not pay. Keeping that result as a
reason the transform cannot win was the overreach. Keeping it as a reason not to do
the transform by adding parameters was right.

Would the real transform hit C-189's wall? Not for the reason in the brief. C-189 kept
the three `imul`s and deleted three `jmp`s; the cycles stayed put and the retiring
percentage fell because that is what a flat cycle count does to a smaller numerator.
Replacing three port-1 `imul`s with `sub`s changes the backend of the loop, which
deleting a `jmp` does not. It can help. It can also fail to show up, because a
two-uop, one-program difference sits inside the band F-154 refused to interpret, and
because the three accumulator `jo`s and the three taken `jmp`s of the diamonds are
still in the loop after the multiply is gone. The cycle prediction from the formula
should not be made at all. The measurement, if it is done, is uops and retiring%
within one sitting, on the compiler's own output, with the new counters in registers
and the decrement checks deleted by the proof that already exists.

## What I would stop writing down

- `cycles = uops / (6 × retiring%)` as an explanation of either quantity. Report uops,
  retiring slots, slots, and cycles. When `slots / cycles` is not 6, say so; that
  ratio is the whole content of the formula.
- That the `mov`s were load-bearing, or that `add %rax,%r12` serialized against the
  `lea`. The hot path does not contain those `mov`s, and the chain length does not
  change.
- That strength reduction is blocked on a range proof, or that it would land at 4.08
  cycles and leave only the overflow checks. The multiply checks are already gone. The
  checks that remain are not the ones strength reduction removes.
