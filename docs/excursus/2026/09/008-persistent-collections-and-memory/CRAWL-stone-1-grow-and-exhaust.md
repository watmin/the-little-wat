# CRAWL — excursus 008 stone 1: the heap grows; running out is honest (M3, M5)

2026-09-26, at the-little-wat `dc69fc3`. The builder chose memory before collections (the items'
dependencies: persistent structures allocate a new path per update, and structural sharing needs M1's
decrementing count).

## What is on disk

- `:c::stub` (`elf/compile.wat`, beside `:c::heap-bytes`): `mmap(NULL, heap+buf, PROT_READ|PROT_WRITE,
  MAP_PRIVATE|MAP_ANONYMOUS)` — `r10 = 34`, no `MAP_NORESERVE` — then `mov r14, rax`.
- **The mmap result is never checked**: a refused reservation leaves a negative errno in `r14`, and the
  first allocation writes through it. A defect in any design.
- **The limit is a 32-bit displacement**: `lea rcx,[rax+total]` with `total` in four bytes, so the
  encoding itself caps the heap below 2 GiB. A larger heap needs a fixed-width 64-bit sequence
  (`movabs` + `add`), the same length in both passes.
- Every allocator compares `r15 + need` against `[r14+8]` and calls `oom()` (`elf/lib/runtime.wat:984`):
  `wat: heap exhausted`, exit 70.
- **wat-rs has no allocation-failure handling** (no `handle_alloc_error`, no `#[global_allocator]`, no
  exhaustion kind in `RuntimeErrorKind`): the interpreter aborts on exhaustion by Rust's default.
  Allocation in wat is implicit — no allocating expression returns a `Result`.

## The probe (`probe-reservation.c`, this directory)

This box: 32 GB RAM, 64 GB swap, `overcommit_memory = 0`, `CommitLimit` 81 GB.

| reservation | plain (today's flags) | `MAP_NORESERVE` |
|---|---|---|
| 2 / 16 / 64 GiB | ok, 3.8 MB resident after touching the last page | ok |
| 256 GiB, 1 / 16 / 64 TiB | **refused** (the overcommit heuristic) | ok, 3.8 MB resident |

## M3 — scored

| | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| A. `MAP_NORESERVE` + terabytes | YES | YES | **NO** — real exhaustion becomes the kernel's OOM killer, no message | — |
| **B. reserve what the machine has at startup** (`sysinfo`: RAM + swap), plain mmap, a 64-bit limit | YES | YES | YES — the heap uses the machine; exhaustion stays the named stop | YES |
| C. chunked growth at the limit | YES | **NO** — a chunked bump allocator B makes unnecessary | — | — |

## M5 — waiting on the builder

"Exhaustion is a matchable error" has no form in wat: allocation is implicit, and wat-rs aborts. Either
(i) exhaustion is the machine's limit, not a program error — a deterministic, NAMED stop, the same in
the interpreter and the compiled code, as stack overflow is; or (ii) a language redesign in which
allocating expressions answer a failure value. The totality ruling covered the program's own errors;
which of these exhaustion is, is the builder's to say.

## The builder's ruling on M5 (2026-09-26)

> *"my ask is that we can grow and shrink our memory allocation based on user program demands - they own
> responsibility if they oom - we just consume the least amount necessary"*

Exhaustion is the machine's limit and the PROGRAM's responsibility: a named, deterministic stop, no
failure value in the language (option i). Our obligation is the other half: consume the least amount
necessary, growing and shrinking with demand. Growth is B above (lazy, so only touched pages are
committed). Shrinking needs memory that actually dies (M1, M2) and gives pages back (M4).
