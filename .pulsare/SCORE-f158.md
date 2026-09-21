# SCORE — F-158's reading of the counter

The remeasurement stands. 16/14/8 instructions, `rec` wandering around 6.1–6.4,
`rec1` at 2.34, `recflat` at 1.50, and 6.20 − 2.67 = 3.53 reported as about five.
The IPC split was the same error as the formula. Those are conceded correctly.

One sentence in F-158 is the inversion, and the class line repeats it.

> "store-to-load forward" names an event that did not happen.
> `cpu_core/ld_blocks.store_forward` reads 0. Nothing was blocked.

`perf list` on this machine:

```
ld_blocks.store_forward
  Loads blocked due to overlapping with a preceding store that cannot be forwarded.
```

The event counts the failure. A load that overlaps a store the core cannot
forward — different size, partial overlap — increments it, and that load waits
for the store to retire instead of taking the data from the store buffer. A
count of zero means no load was blocked. It does not mean no load forwarded.
Successful forwarding does not increment this counter, and there is no counter
that counts successful forwards. Zero is the result the score cited as
"forwarding is not blocked," which is the clean case, not the absent one.

The paragraph under that sentence already has the mechanism right: `slot_set_own`
writes `[rax+8]`, the next iteration loads `[rbx+8]` and that value is the next
call's argument, and `rec1` stores without reloading. That is a store-to-load
forward on the value chain. The counter reading zero is consistent with it. A
non-zero count would have meant the forward *failed* and the gap was a block,
which is a slower and different thing.

So the class line, "F-148's numbers and its mechanism do not," retires too much.
The numbers do not stand. The name "five-cycle forward" does not stand. The
mechanism — a carried store and reload of one qword, forwarded rather than
blocked — is what the instructions say and what a zero block-count fails to
contradict.

Nothing else in the reply needs a correction, and no cycle figure is attached
to whatever comes next.
