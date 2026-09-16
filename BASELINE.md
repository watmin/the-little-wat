# wat performance baseline
# date: 2026-09-16   wat-rs: a3218644d   reps: 3 (minimum kept)   host: 16 cores

| what                         |        ops |  ns/op (min) |
|------------------------------|------------|--------------|
| defrecord accessor           |     200000 |         6130 |
| defstruct accessor           |     200000 |         1219 |
| dispatch/builtin             |     200000 |          360 |
| dispatch/closure             |     200000 |          853 |
| dispatch/match-2             |     200000 |          675 |
| dispatch/record-get          |     200000 |         6153 |
| dispatch/user-fn             |     200000 |          795 |

## Method

Every figure is the **minimum of 3 runs**, and every loop is measured against an **empty-loop
control of the same shape and iteration count**, because at ~3.6 µs per trivial iteration the
loop machinery dwarfs what is being measured. Each body repeats its operation 10 times, because
a ~200 ns effect against a 3.6 µs iteration is 6% and laptop variance exceeds that — the first
version of `bench/dispatch.wat` reported a *negative* cost for a builtin call.

`bench/records.wat` carries its aggregate through every recursive call and measures that
carrying separately ("carry-only"); it lands at or below the empty loop, which is what licenses
reading the rest as accessor cost.

## Why this file exists

The next phase of wat is byte code / a jump DAG. A before/after can only be captured **before**.

## The numbers already in FINDINGS.md

These are not re-run here; they are the rest of the baseline, each with its own repro.

| | measured | where |
|---|---|---|
| a message to a service | 224 µs, ~100 function calls | F-051 |
| the formatter | ~10 KB/s, ~800 ms fixed floor per invocation | F-075 |
| deporder over comparable source | ~1 MB/s — 100× the formatter | C-050 |
| `bracket::map`, thread pool | 1.69× on 16 runners (OS processes: 5.90×) | F-094 |
| `bracket::map`, process pool | 3.38× | F-094 |
| copying vs sharing containers | 135.1 s → 20.6 s on one AoC day | F-057 |
| `rest` on a Vector | clones, so walking is quadratic | F-055 |
| the interpreter overall | 100–430× the JVM, 13× guile, >100× Racket | C-0xx / books |
