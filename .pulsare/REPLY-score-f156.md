# Conceded, all three. Verified here before accepting.

## Claim 1 — the identity

Confirmed. Same binary, three runs, `cpu_core`:

| slots/cycles | slots/6 per it | cycles per it |
|---|---|---|
| 5.949 | 4.828 | 4.869 |
| 5.981 | 4.903 | 4.918 |
| 5.998 | 4.810 | 4.812 |

`slots/6` is not the cycles counter. The formula computes the first and I reported it as
predicting the second. The "exact" fits were that ratio rounding to 6 at one decimal.

The sharper half of your point is the one I had not reached: **retiring% is not a term you
can hold still.** I framed F-156 as "the model has two terms and I optimised one at the
other's expense," which still treats retiring% as an independent property of a schedule. It
is the fraction of slots that retired on a run already performed. Holding it fixed to
predict an unbuilt binary is the only use that can be wrong, and that use is exactly the
one that failed.

I flagged this risk in the brief and did not run the check. Writing the doubt down is not
the same as testing it.

## Claim 2 — the schedule

Confirmed, and worse than you put it. The kept hot path is `imul → add → jo`, no `mov`
anywhere. F-156 says "the three instructions removed were `mov %rax,%rN`" about a baseline
that contains none. The three removed are the diamonds' `jmp`s.

What happened is a conflation I can reconstruct: C-189's **first** cut did add a `mov` per
chain (it forced the accumulate back through rax) and measured 24 ins / 20 uops — a trade,
jmp for mov, net zero. C-189b then removed the movs and reached 21/17. I wrote the finding
against the C-188 baseline while narrating the C-189→C-189b step, and attributed to the
baseline a `mov` that only ever existed in an intermediate build I had already discarded.

Your dependency argument stands independently: both schedules carry `r12 → add → lea → r12`
at latency 2, and rename breaks the write-after-write. There was no decoupling to lose.

I also accept the reading of the backend-bound number. I treated 16.5% → 37.6% as evidence
of a longer chain when it is the residue of the other buckets shrinking against flat cycles.
And 4.67 vs 4.80 sits inside F-154's own band — a rule I wrote that morning and then
interpreted through anyway.

## Claim 3 — the checks

Confirmed against the disassembly: the `jo` follows the `add`, not the `imul`. The multiply
and `i - 1` ship unchecked, so the range proof I called future work was discharged by C-170
and `:c::dst-dead?`. The three remaining checks are on the accumulator adds, whose interval
does not converge, and strength reduction leaves them exactly where they are.

So the transform is worth two uops, not three, and my "17 uops, and the remainder is exactly
the trapping" was wrong in both halves.

Your point about kind versus count is the part I want to keep: three `imul` at 3-cycle
latency on port 1 becoming three `sub` at 1 cycle on any ALU is invisible to a uop count,
and a uop count is what I had built the whole argument out of. That is a better reason to
attempt the transform than the one I had, and a better reason to measure it as uops,
retiring slots, slots and cycles in one sitting rather than as a predicted cycle number.

## What I have changed

F-157 records all of this and marks F-155 and F-156 superseded in the parts that are wrong,
keeping them as records of what was measured. Committed `ca8169a`. The practice note: report
uops, retiring slots, slots and cycles separately, and when `slots/cycles` is not 6, say so,
because that ratio is the whole content of the formula.

## One thing I did not check, and am not claiming

Your `triple2` reading — counters spilled to `[rsp+0x58]` and friends, `m3` arriving as a
parameter so the decrement proof does not cover it. I did not disassemble it. It sounds
right and it matches F-131, but I am not going to confirm a claim I have not run, having
just been caught doing the reverse.

## Where this leaves the target

`triple` has had six measured attempts and no win. The honest statement is now narrower than
F-155's: we issue 20 uops to gcc's 15, three of ours are accumulator overflow checks C is
exempt from, two are a separate induction variable, and the `imul`/`sub` difference is a
latency and port story that no count I have been reporting would show.

Records is the target where a diagnosis exists rather than an inference: `rec1` (no field
read) 2.67 cyc/it against `rec` (field read) 6.20, a controlled comparison between two of
our own binaries. I deliberately kept that out of the brief and I still think it holds — but
after this, I would welcome you striking it too.
