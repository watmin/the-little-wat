# WEIGH — excursus 008 M2

## Round 1 (2026-10-01)

**Credited:** the free-list take lives INSIDE `:c::rt-bump` (one door by construction, self-contained: it saves
the registers it uses); the two inline bumps go through it; a dead non-youngest block goes onto its class's list;
three allocator bugs found and fixed on the way (`rt-cap`'s `out` clobbering `rcx`; the list pushed an object
pointer where a block start belongs; the small path's jump skipping the list). The region release is retired
(`:c::seq`'s `push r15`/`pop r15`, `:c::releasable?` and the poke call graph that only served it).

**STOP-2 was the region release, not argument liveness** — on my own run, `/tmp/probe8.wat` diverges with the
region release (`"561"|"2"`) and agrees without it: a block freed onto a list inside a statement, then the
statement's `pop r15` rewound the bump below it — one block, two owners. Now `elf/probe/m2-region-collision.wat`.

**STOP-3 — the plain self-compile segfaults; it is the ALLOCATOR, proven by elimination:**
- gdb on `/tmp/chain-m2f/elf/out/seed.elf` (my run): the Vector glue faults walking an object whose count word is
  0 and whose LENGTH word is 9 — more than a flat Vector holds (`:c::arr-max` 8); the words after it read as a
  9-field RECORD (zeros, a heap pointer, small integers, string bytes). The Vector glue was handed a pointer whose
  bytes now hold a record.
- **The check build is clean on the same source** (my run, `/tmp/m2-check-chain`, `WAT_DROP_CHECK=1`, seed = 3b-2's
  check compiler → s1 → s2 → s3): s2 compiles everything, `s2 == s3`, 518,767 bytes, no stop. So no count is wrong
  and nothing is dropped twice — a dead object's reuse would have stopped there.
- So a LIVE Vector's bytes were taken by a record's allocation: a freed block was listed under a class LARGER than
  its true block, and an allocation from that list ran past the block's end into its live neighbour. The brief's
  lower-bound rule is violated somewhere.

## R1 — the block that was listed too large

Find it, don't reason about it: in the plain chain's crashing binary (`/tmp/chain-m2f/elf/out/seed.elf`, or
rebuild), under `setarch -R gdb`, take the faulting object's address `P` (rbx at the fault), then re-run with a
hardware watchpoint on `P` and on `P-8` (`watch -l`, after `starti`) logging every write with `$pc` and the value:
the allocation that wrote `9` into the length word is the record; the step before it, its free-list pop, names the
class and the block. Then find who FREED that block, and with what size versus the size its allocator gave it.
Fix the size function at the root (the brief: each kind's size from the SAME function its allocator uses, and an
ambiguous block listed under the SMALLEST it could be). Then the plain chain to a fixpoint, the measurements, and
both verifies.
