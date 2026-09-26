# BRIEF — excursus 008 stone 1: the heap grows to demand, and running out is the program's

> The builder, 2026-09-26: *"my ask is that we can grow and shrink our memory allocation based on user
> program demands - they own responsibility if they oom - we just consume the least amount necessary"*.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/008-persistent-collections-and-memory/SCOPE.md` — the items; this stone is M3
   (and the stub's unchecked `mmap`); M5 is RULED there
2. `CRAWL-stone-1-grow-and-exhaust.md` beside it — the stub, the 32-bit limit, the reservation probe,
   the four-question scoring (candidate B), the ruling
3. `elf/compile.wat` `:c::stub` and `:c::heap-bytes`; `elf/lib/runtime.wat:984` (`oom()`)

## THE WORK

1. **Reserve what the machine has, lazily.** At startup the stub asks `sysinfo` (syscall 99) for total
   RAM plus total swap, and reserves that much (plus the output buffer) with today's plain
   `MAP_PRIVATE|MAP_ANONYMOUS` — pages are committed only when touched, so a program consumes exactly
   what it uses. No fixed 1.9 GB ceiling remains; `:c::heap-bytes` is gone or is only a floor, say
   which and why.
2. **The limit is a 64-bit quantity**: `[r14+8]` = base + the reservation, computed with fixed-width
   instructions (the stub's length must not depend on the numbers — `:c::stub-len` measures it with
   placeholders). The `lea` with a 32-bit displacement goes.
3. **The `mmap` result is checked**: a refused reservation is a named stop on stderr (not a write
   through a negative pointer), exit 70 like `oom()`.
4. **Exhaustion stays the named stop** (`wat: heap exhausted`, exit 70): the program's responsibility,
   by the ruling. Its prose says so.

## THE FIXTURES

- A program that allocates well past 1.9 GB of LIVE data (retained, so it is genuinely needed) and
  finishes — measured with `elf/bench/maxrss.c`: its peak RSS is what it touched. Keep its size below
  this box's RAM (32 GB) with margin; say the number chosen.
- `tools/mem.sh`'s programs: peak RSS unchanged within noise (the reservation is lazy).
- A mutant stub whose `mmap` is forced to fail must print the named stop and exit 70, not fault.

## STOP TRIGGERS

- **STOP-1 — the stub's length changes between placeholder and real numbers.** Report it.
- **STOP-2 — any existing program's peak RSS grows** beyond noise. The reservation must stay lazy.
- **STOP-3 — a red, or a gate above zero.** Capture it; never re-run it.

## OUT OF SCOPE

Shrinking (M4, needs M1/M2) · freeing (M1) · the allocator (M2) · wat-rs.

## METHOD

`timeout -s KILL` on every run; assert every text replacement; no `_`, no catch-all; leave the tree alone
while `tools/bootstrap.sh` / `tools/elf-run.sh` runs; bootstrap WITHOUT `--fast`; `tools/elf-run.sh` IN
FULL; `tools/emitted.sh` — every program's stub changes, so every binary moves by the same stub delta:
show that and nothing else. **Commit nothing; leave the tree dirty.** Write
`SCORE-stone-1-the-heap-grows-to-demand.md` here.
