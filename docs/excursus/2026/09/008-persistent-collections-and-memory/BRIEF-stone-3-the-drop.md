# BRIEF — excursus 008 stone 3: the drop — a count that comes down

> The builder: memory *"very close to what rust feels like"*, *"i do not want GC pauses like java or go"*.
> Stone 2 made every count TRUE on the way up. This stone brings it DOWN where a reference dies, and drops
> the object at zero — synchronously, iteratively, Rust's `Drop`, inferred rather than written.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/008-persistent-collections-and-memory/CRAWL-M1-the-count-comes-down.md` —
   WHOLE, and its last section above all: the disconfirming probe that places every drop
2. `WEIGH-stone-2-the-split.md` — stone 2's cost and the recovery path this stone opens (`:c::emit`)
3. `BENCH-baseline.md` and `tools/bench-coll.sh` — what this stone is measured against
4. `FINDINGS.md` `### F-188` (counted reads), and `tools/reads.sh`, `tools/copies.sh`

## THE CONTRACT

Every reference dies somewhere, and there the compiler emits its DROP: decrement the count; at zero,
drop what the object holds and free it. The rules are settled (the CRAWL): arguments are OWNED (a caller
that still needs a value increments before passing it; the callee drops at its own last use); one
discipline, the count. Placement is the probe's table:

| where a reference dies | where its drop goes |
|---|---|
| a temporary operand of a READING built-in (`length`, `nth`, comparisons, `contains?`, `starts-with?`, `byte-*`, `code-point-at`, `subs`, `println`, `assert-eq`) | right after the read |
| a temporary argument to a USER function | moved in; the callee drops it |
| a statement's discarded value | right after the statement |
| a named binding / parameter | after its last use (`:c::live-after`) |
| a name dead in one `if` arm | at that arm's start |
| a parameter not passed on at a self tail call | before the jump |
| a `match` scrutinee | at arm entry, after its parts are counted out |

`live-after` over-counts (textual, through shadowing): a drop may come LATER than Rust's, never EARLY.

## THE ROWS

- **D1 — drop glue, one per type.** The compiler emits, for each pointer type it knows, a routine that
  drops what an object of that type holds (a Vector's pointer elements or its trie nodes; a record's
  pointer fields; a variant's payload; a closure's captures; a String holds none) and then frees the
  object. A self-recursive type (a `Cons` list, a tree) walks with an explicit WORKLIST, never recursion:
  a 100,000-deep chain drops without growing the stack. A count-0 literal (a String literal, a static
  closure) is never dropped — the literal guard, as stone 6 of 002 derived it.
- **D2 — the drops**, placed by the table above, through ONE emission (as `:c::count-hex` is the one
  increment) so a gate can find every one.
- **D3 — consuming built-ins take ownership.** A copying `conj` / `assoc` / `concat` consumed one
  reference to the source and drops it after copying (`vec_conj`, `slot_set`, `str_cat` copy paths).
- **D4 — "free" until M2 exists**: a freed object that is the YOUNGEST allocation gives its bytes back to
  the bump (`r15`); any other stays where it is (as today). The counts become TRUE either way — which
  returns in-place growth whenever a count comes back to 1, and is what the bench measures.
- **D5 — a count never goes below zero**: a CHECK build (an environment switch in the compiler, off by
  default) makes every decrement verify the count was above zero and abort naming the site otherwise.
  Run the whole corpus under it: zero underflows. It is the gate that catches a double drop.
- **D6 — the region release stays** (it retires LAST, the settled order). Say what it does to counts now:
  a rewind frees without decrementing what the region referenced outside it — counts too HIGH, memory
  held, never freed early.

## THE FIXTURES — each on the interpreter first

A shadowed name (shows the lateness, still agrees); a name dead in one arm; a self tail call that drops a
parameter it does not pass on; `(length (concat a b))`; a `match` whose scrutinee dies; a copying `conj`
whose source then has count 1 again and grows in place; a closure whose drop drops its captures; a
100,000-deep `Cons` list dropped whole; a Vector of records of Strings dropped whole. **Mutants:** a drop
placed one use too early must make a fixture diverge or trip D5; dropping D3's source-drop must show in a
fixture's count or memory.

## MEASURE — against `BENCH-baseline.md`

`tools/bench-coll.sh` in full: instructions, cycles against the floors, peak RSS, tails — and the
compiler compiling the corpus against stone 1's and stone 2's figures (does `:c::emit`'s `assoc` now take
`rt-slot-set-own`?). Report what moved and why.

## STOP TRIGGERS

- **STOP-1 — a drop cannot be placed** by the table (a shape the probe did not see). Report it.
- **STOP-2 — D5 finds an underflow** you cannot trace to a placement defect. Capture it.
- **STOP-3 — a recursive type cannot be dropped iteratively** within its glue. Report the shape.
- **STOP-4 — a red, or a gate above zero.** Capture it; never re-run it.

## OUT OF SCOPE

The allocator (M2) and pages back to the OS (M4) · retiring the region release · maps and sets.

## METHOD

`timeout -s KILL` on every run; assert every text replacement; no `_`, no catch-all; verify with
**`tools/verify.sh`**; `tools/emitted.sh` with every moved program explained. **Commit nothing; leave the
tree dirty.** Write `SCORE-stone-3-the-drop.md` here.
