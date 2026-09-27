# SCORE — excursus 008, the bench stone

A baseline, taken before stone 3 drops anything. The full grid is `BENCH-baseline.md` in this directory. The tree is dirty at `4f89874`. Nothing was committed.

`wat.os/clock-ns` is the only change to the compiler. It is `clock_gettime(CLOCK_MONOTONIC)`, nanoseconds, an i64. The collections and the memory model are the ones stone 2 left.

## Expectations

| # | result |
|---|---|
| 1 | Every opponent that printed an answer agreed, on every workload and every size. The cells that did not finish are listed below. They did not print a different number. |
| 2 | Instructions grow with size for every opponent that finished both ends. Clojure's ratio from 10^4 to 10^6 is small on W1–W4 because a cold JVM is about 6.7 billion instructions before the work; the counts still rise (W1 Clojure 6.74e9 → 8.28e9). That is startup, not a folded loop. |
| 3 | `clock.elf` printed `1`: two `clock-ns` calls with a spin between them were monotonic. Compiling `(wat.os/clock-ns 1)` was refused: `compile: cannot compile clock-ns arity: (wat.os/clock-ns 1)`. |
| 4 | The cycle spread of the pinned repetitions is in the baseline, beside the cycles of the minimum-instruction repetition. Several spreads are wide (W1 at 10^4, compiled wat, 33.4%; W4 at 10^5, compiled wat, 64.7% across the interrupted run and the resume). No cycle comparison is made inside those spreads. |
| 5 | Peak RSS is in the baseline for every cell, including the ones recorded as exceeded or aborted. |
| 6 | p50, p99, p99.9, and max are in the baseline, in nanoseconds, for a batch of 1,000 operations. The comparison row for Clojure is the warm run. The cold run is beside it. The GC pause is visible: W4 at 10^6, Clojure cold max 95.5 ms against a p50 of 0.099 ms; the warm run's max is still 85.7 ms. A warm-up did not remove the tail. |
| 7 | `tools/verify.sh` exited 0 (`verify: ok`). `tools/emitted.sh check` reported all 100 corpus programs byte-identical to the manifest. The refuse fixtures carry the same clock arm, because they are copies of the compiler source; the binaries those programs emit did not move. |
| 8 | `BENCH-baseline.md` names commit `4f89874`, the dirty tree, and this machine: 12th Gen Intel i7-1270P, 32 GB RAM, 64 GB swap. |

## What did not finish

The script prints `STOP-1` whenever an answer is missing. These are that kind of miss. The finished opponents on the same row agree with each other.

| workload | n | who | what |
|---|---:|---|---|
| W1, W2 | 10^6 | wat interpreter | no answer in 900 s |
| W4 | 10^5 and 10^6 | C, both columns | resident set passed 8 GiB. Free only runs at the end, so the two peaks match |
| W4 | 10^5 and 10^6 | wat interpreter | passed 8 GiB, then aborted under an 8 GiB address cap on the resume |
| W5 | 10^6 | C never-free | resident set passed 8 GiB. At 10^5 it peaked at 4,886,048 KiB |

Wat itself did not trip the 8 GiB line on any workload. W4 at 10^6, the case the line was drawn for, finished at 1,108,492 KiB (about 1.06 GiB) and printed 499,999,500,000. Rust `VectorSync` on the same row was 966,144 KiB and 9.27 billion instructions. Compiled wat was 1.49 billion instructions.

## What the baseline is for

W3 is the compiler's `emit` shape, one field overwritten, only the latest kept. Compiled wat stays at about 956 KiB at 10^4, 10^5, and 10^6. The record stays uniquely owned, so the update does not accumulate. C never-free on the same workload grows to 32,992 KiB at 10^6, one allocation per step.

W5 is a string built by repeated concat. Compiled wat finishes at 10^6 in 30.3 million instructions and 3,904 KiB. The parameter stays linear, so the concat stays in place. C `realloc` doubling also finishes (11.0 million instructions, 2,832 KiB). C never-free, which copies into a fresh buffer every character and drops the old pointer, does not finish at 10^6. Rust's `s = s + "a"` consumes the `String` (`Add` takes `self`), so it is the doubling buffer, not a retained persistent copy: 12.7 million instructions and 3,200 KiB at 10^6. Clojure's source is `(str s "a")` each step. Its instructions go 6.76e9, 8.71e9, 1.07e11, and its RSS peaks at 177,412 KiB, 3,638,300 KiB, then 1,271,960 KiB. The 10^5 peak is higher than the 10^6 peak; that is the collector. The warm batch tail at 10^6 runs from a p50 of 157 ms to a max of 428 ms, not the thousand-fold opening a fully retained quadratic copy would show.

W1 at 10^6, i64 elements, compiled wat is 63.3 million instructions and 9,580 KiB. The imperative C loop is 10.5 million instructions and about the same RSS. W2, a fresh string per element, moves wat to 103 million instructions and 47,652 KiB, and C `malloc`/`free` to 386 million instructions and 40,608 KiB. The pointer counts are in that gap. The Rust column those sentences used to cite is the persistent API; the one-owner remeasure is below.

## R1 — one owner

W1–W3 in wat build with a uniquely owned accumulator, so the conj extends in place. The first Rust column called `push_back` and `set`, which clone the vector on every step even when nothing else holds it. The one-owner API on the same crate is `push_back_mut` and `set_mut`. Both columns were remeasured together, five pinned repetitions, same counters. Every answer matched. W4 and W5 were left as they stood: W4 keeps every version, so the persistent call is the work.

| workload | n | wat ins | Rust persistent | Rust one-owner | one-owner / wat | persistent / one-owner | one-owner RSS KiB |
|---|---:|---:|---:|---:|---:|---:|---:|
| W1 | 10^6 | 63,331,393 | 3,644,630,825 | 932,683,073 | 14.7× | 3.9× | 44,820 |
| W2 | 10^6 | 103,011,277 | 4,008,670,715 | 1,269,105,325 | 12.3× | 3.2× | 90,772 |
| W3 | 10^6 | 17,331,169 | 499,736,489 | 214,736,106 | 12.4× | 2.3× | 1,976 |

The one-owner column's cycle spread at 10^6 is 2.7% (W1), 3.1% (W2), and 0.9% (W3). W3 at 10^5 spreads 49.1% on cycles while the instruction counts stay on 22,135,733–22,136,432, so that row has no cycle claim. Full sizes are in the baseline.

`set_mut` on a one-element vector stays near 2,000 KiB at every size. `push_back_mut` at 10^6 is 44,820 KiB (W1) and 90,772 KiB (W2), against compiled wat's 9,580 and 47,652. The mut API is the twin, and it is still about fifteen times wat on W1 instructions.

The other opponents, on the same test:

- C `malloc`/`free` on W1–W3 is already the one-owner idiom: a mutable buffer, overwritten, freed at the end. The never-free column is the bump, and it is labelled that way.
- Clojure's measured column is plain `conj` / `assoc`, which is the persistent idiom. `transient` / `conj!` / `assoc!` with `persistent!` only at the end is the one-owner builder. It was measured. At 10^6 its best instruction counts are 8.33 billion (W1), 8.88 billion (W2), and 7.48 billion (W3), on the same JVM-startup floor as plain `conj` (W1 plain was 8.28 billion). The whole-process count does not separate the two. The batch p50 at 10^6 is 43 µs (W1), 52 µs (W2), and 29 µs (W3).
- The wat interpreter runs the same source as the compiled program, so the program is the one-owner shape. Its collections are wat-rs's. Those rows were not remeasured.
