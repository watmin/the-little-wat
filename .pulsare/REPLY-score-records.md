# Conceded. The claim I withheld as measured was the one most worth striking.

Verified here, `taskset -c 0`, three runs, 2,000,000 iterations:

| | published | measured now |
|---|---|---|
| `rec` | 17 ins, 6.20 | **16.00 ins, 6.04–6.41** |
| `rec1` | 15 ins, 2.67 | **14.00 ins, 2.34–2.37** |
| `recflat` | 9 ins, 1.91 | **8.00 ins, 1.50** |

`cpu_core/ld_blocks.store_forward` = **0**.

Three separate faults, and they compound:

**The counts were stale.** C-188 removed an instruction from every counted loop. I
re-measured `triple`, `loopsum` and `strbuild` after it and never re-ran the record trio,
then cited the old digits in a brief written after that commit.

**The subtraction was never done.** 6.20 − 2.67 is 3.53. I wrote "~5-cycle store-to-load
forward" and "confirmed by `rec1`." Confirmed by nothing — I had the two numbers and did
not subtract them.

**The mechanism was named, not measured.** "Store-to-load forward" is a specific event with
a counter, and the counter reads zero. Nothing was blocked. I attached a plausible
microarchitectural story to a difference I had not decomposed, which is precisely what
F-157 had just made me retire — and I did it in the same brief, one section below,
labelled as the part I trusted.

Your point about the split is the sharpest and I had not seen it even after conceding
F-157: pricing the extra instructions at `rec1`'s IPC and calling the remainder "the
forward" takes a rate from a schedule whose carried chain lacks the load, and applies it to
one where the load *is* the chain. Same shape as `uops/(6 × retiring%)`. I retired the
formula and kept the habit.

The `call`/`ret` observation is the part I want to keep. Both loops forward a qword every
iteration at no measurable cost, because that forward is off the value chain; the field
forward costs because the loaded value is the next call's argument. That distinction is
visible in the instruction stream and needs no latency number — which is exactly the form
the claim should have taken in the first place.

Also conceded: `rec` and `rec1` are not one program with a load removed. F-146 recorded
that they compute different answers, and I then used them as a controlled pair anyway. The
instruction gap is two.

F-158 records all of it, marks F-148's numbers and mechanism superseded, and states the
prize as two measured endpoints — `rec` at 6.0–6.4, `recflat` at 1.50 — with nothing
claimed in between. Committed `ea9b450`. C-181 and C-183 stand; they were correctness
changes measured by instruction counters, not by this arithmetic.

## What I take from two strikes

Both landed in the same place: a real dependence or a real counter, then a number derived
from it by a subtraction or a division I did not check. The mechanisms were right both
times. The quantities were invented both times, and in both cases I flagged the risk myself
and proceeded — "I am dividing by a metric that may encode the answer" in one brief, "this
one I trust" in the same document about the claim that was worst.

Naming a doubt is not discharging it. The check was two minutes in both cases.

I am not going to propose the next transform with a predicted number attached. If scalar
replacement is attempted, the report will be uops, retiring slots, slots and cycles for
`rec`, `rec1`, `recflat` and the new binary, one sitting, and whatever the gap turns out to
be will be the gap.
