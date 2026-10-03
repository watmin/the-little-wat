# BRIEF — excursus 009: wat-rs's `Vector` and `List` become persistent

> The builder, 2026-10-02: *"swapping vec and list to their persistent flavors is the call here"* — *"long term we
> only use rpds"*. The interpreter compiling `elf/compile.wat` (stage 0) now takes 25–40 minutes.

## WHY — measured

- `wat-rs/src/collection/eval.rs:280`: `Vector`'s `conj` is `(**xs).clone(); out.push(item)` — EVERY element cloned,
  even when nothing else holds the vector. Building N elements by `conj` is N²/2 clones. The compiler conjs every
  reader node onto its arena and every code chunk onto its buffers.
- `src/value/value.rs:340`: `List` is `Arc<std::collections::LinkedList<Value>>`; `conj` (prepend) clones every node.
- A profile of stage 0's first minute: ~25–35% name resolution by string hashing (a separate arc), ~7% malloc/free.
  A profile 20 minutes in is being taken now (`/tmp/interp-late`) — the quadratic copy grows with the run.

## THE CONTRACT — unobservable

A wat program cannot tell. Same values, same printing, same equality and hashing, same type names (`Vector`, `List`).
Only cost changes: `conj` stops being O(n).

## THE ROWS

- **V — `Vector` becomes `PVec`.** `Value::Vec(Arc<Vec<Value>>)` → `Value::Vec(crate::value::pvec::PVec)` — the
  promoting vector `PersistentVector` already uses (`src/value/pvec.rs`: an array from a bulk build, an `rpds` RRB tree
  after persistent `conj` past 8; equality and hash by sequence — "representation must be UNOBSERVABLE"). `conj` →
  `PVec::push_back`. 238 `Value::Vec` sites in 43 files: `.iter()` / `.len()` / `.get(i)` carry over; a site that needs a
  contiguous slice (`&[Value]`) is the real work — an iterator, or a bulk-built array arm proven to be one. List every
  slice site you changed and how.
- **L — `List` becomes `rpds::ListSync`.** `Arc<LinkedList<Value>>` → `rpds::ListSync<Value>` (persistent, O(1)
  prepend, structural sharing). `conj` → `push_front`. 54 sites in 16 files. Equality, hashing and printing by sequence,
  exactly as today.
- Order: V first (it carries the compiler's cost), gated; then L.

## GATES

1. **The wat-rs floor** (`cargo nextest`, `NEXTEST_TEST_THREADS=4`): the same result as the branch you started from —
   its only known reds are F-197's two lint reds; state the before and after counts.
2. **Byte-exact on a real program**: the-little-wat's stage 0 (the interpreter running `elf/compile.wat`) writes the
   SAME 103 binaries with the new `wat` as with the old — `cmp` every one.
3. **The measure**: stage 0's wall time, old `wat` vs new, on the same tree, same machine, one run each after a warm
   start; and a 60-second `perf` sample late in the new run.

## WHERE — isolated, because another strike is using `wat` right now

- Work in a FRESH CLONE: `git clone /home/watmin/Work/holon/wat-rs /tmp/wat-rs-009` (a clone, not a worktree), branch
  `the-little-wat-persistent` from `the-little-wat`, and `CARGO_TARGET_DIR=/tmp/wat-rs-009-target`. NEVER build in, or
  switch branches in, `/home/watmin/Work/holon/wat-rs` — another executor's stage 0 runs depend on its binary and source.
- For the stage 0 gates, a sandbox copy of the-little-wat (`git -C /home/watmin/Work/holon/the-little-wat archive HEAD`)
  with its `../wat-rs` pointing at the clone, and the NEW binary passed explicitly.
- Push the branch (`git push origin the-little-wat-persistent` from the clone) after each green commit — GitHub is the DR
  site. Commits in the clone are fine; the orchestrator merges forward after weighing.

## STOP TRIGGERS

- **STOP-1** — a site whose correctness depends on the representation (identity, `Arc::ptr_eq`, mutation in place).
- **STOP-2** — a floor test that changes result for a reason other than a representation leak you can name.
- **STOP-3** — stage 0's binaries differ.

## METHOD

`timeout -s KILL` on every run; never read an exit code through a pipe; never re-run a red; no git in the holon root;
no worktrees. Write `SCORE.md` in this directory AS YOU GO (in the-little-wat — this directory only, nothing else in
that tree).
