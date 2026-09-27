# BRIEF — excursus 008, the bench stone: collections and memory against the semantic twin

> The builder, 2026-09-27: *"how do we challenge the perf implications of these changes? do our c
> comparisons via gcc and clang still apply here?"* — they do not: `fib`, `loopsum`, `four`, `opt` touch
> no collection, and stone 2 left `arith.elf` byte-identical. *"draw it after stone 2 lands"* — this is a
> BASELINE, taken before stone 3's drops, that stone 3 (and M2) are measured against.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/008-persistent-collections-and-memory/SCOPE.md` and `CRAWL-M1-...md` — what
   008 builds; the builder's rulings ("very close to what rust feels like"; no Java/Go GC pauses)
2. `WEIGH-stone-2-the-split.md` — stone 2's cost and where it lies
3. `FINDINGS.md` `### F-132` (compare against the SAME semantics), `### F-192` (a noise floor is
   measured per workload), `### F-184` (a C opponent that constant-folds is measuring the wrong thing)
4. `tools/bench.sh`, `elf/bench/*.c`, `elf/bench/maxrss.c`, and the `cc-time` discipline (copies,
   interleaved runs, every exit checked)

## THE OPPONENTS — each labelled with the semantics it has

| opponent | semantics |
|---|---|
| **the compiled wat program** | persistent, counted (the subject) |
| **the wat-rs interpreter**, same source | persistent (wat-rs's own collections) |
| **Rust with `rpds` 1.2.1** (`VectorSync`, `Arc` everywhere; offline from cargo's cache) | persistent, reference-counted, inline drop — **the semantic twin**, and "feels like Rust" made literal |
| **C, `malloc`/`free`**, mutable arrays and structs | the IMPERATIVE floor — different semantics, labelled so; what explicit management costs |
| **C, never freeing** | the old bump model: where 008 started |
| **Clojure** (`clj`, persistent vectors, JVM GC) | persistent, garbage-collected — the PAUSE comparison |

## THE WORKLOADS — each at three sizes (10^4, 10^5, 10^6), each program printing its result so every opponent's answer is compared

- **W1** build a Vector of i64 by `conj`, then sum it;
- **W2** build a Vector of Strings by `conj` (pointer elements — stone 2's counts), then total their lengths;
- **W3** `assoc` one field of a record in a loop, keeping only the latest (the compiler's own `emit` shape);
- **W4** persistent updates that KEEP every old version (a Vector of versions, each one `conj` on the
  last), then read an element of each — structural sharing, and memory held;
- **W5** build a String by repeated `concat`.

No opponent may be allowed to fold the loop away (F-184): the input size arrives at run time, and the
result is printed.

## THE MEASUREMENTS

- **instructions** (`cpu_core/instructions/u`) and **cycles** (`cpu_core/cycles/u`), pinned, best of N,
  interleaved; a noise floor MEASURED for each workload (F-192), and no cycle claim inside it;
- **peak RSS** (`elf/bench/maxrss.c`);
- **latency tails**: each program times batches of operations (1,000 per batch) with a monotonic clock and
  prints the p50, p99, p99.9 and MAX batch time. The compiler has no clock: add `wat.os/clock-ns`
  (`clock_gettime(CLOCK_MONOTONIC)`, nanoseconds, an `i64`) to its INTRINSIC set beside `getpid` and
  `peek` (`elf/compile.wat:45-55`) — the timed variant is native-only; the result line is what the
  interpreter is compared on.

## THE DELIVERABLE

`tools/bench-coll.sh` (one command, every exit checked, never through a pipe) and
`docs/excursus/2026/09/008-persistent-collections-and-memory/BENCH-baseline.md`: the table, the
commit, the machine, the floors — the baseline stone 3 is measured against.

## STOP TRIGGERS

- **STOP-1 — any opponent's answer differs** from the others on a workload. Capture it.
- **STOP-2 — a wat workload's peak RSS or run exhausts the heap / exceeds 8 GB** at 10^6: report it — that
  is the finding stone 3 exists for, not a reason to shrink the workload.
- **STOP-3 — an opponent's compiler folds the work away** (instructions flat across sizes). Fix the opponent.

## OUT OF SCOPE

Changing the compiler's collections or memory (only the clock intrinsic is added) · maps and sets (C2/C3,
not built) · tuning any opponent beyond its idiomatic release build.

## METHOD

`timeout -s KILL` on every run; verify with **`tools/verify.sh`** (bootstrap, then `SKIP_BUILD` elf-run);
no `_`, no catch-all; every number is one you measured. **Commit nothing; leave the tree dirty.** Write
`SCORE-stone-bench-collections-and-memory.md` here.
