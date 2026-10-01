# SCORE — excursus 008: the discovered defects, fixed before 3b-2

Struck by Claude Sonnet (2026-09-30); its handbacks were cut off before it could write this, so the orchestrator
writes it from the executor's reported evidence, and the gates below are the orchestrator's OWN runs.

## F1 — F-209: FIXED
Root: `:c::enum-tier` decided tier-1 eligibility from `:c::sole-payload-ty`, the payload's FULL spelling; for
`:Node [kids <- (Vector :- [:user::T])]` that resolves `T` again → `:c::enum-tier` on `T` → unbounded recursion
(SIGSEGV in the interpreter). Fix: `:c::sole-payload-kind` / `:c::ty-node-kind` decide only the KIND (`vec:`,
`str`, `rec:`, `fn:` short-circuit; only a bare enum reference falls back to `:c::ty-node`, bounded because a type
cannot be its own unwrapped payload); `:c::enum-tier` calls them. Fixtures: `f209-tier1-self-vec.wat` agrees
(`1`), and the new `f209-tier1-self-vec-build.wat` (builds a `T.Node`, matches both arms, drops it) agrees (`1`),
both ways.

## F2 — the count word is a count: FIXED
Root: `vec_conj_own` path 4 wrote `:c::arm-own` (`0x1_00000001`) into the count word. Fix: a third tag value
`:c::vec-flat-own` (2) in the tag word `[p-16]`; the count word gets `1`; path 2's test is "tag `vec-flat-own` AND
count 1". `:c::arm-own` removed. **Every reader of `[p-16]`** (search: `:c::vec-flat`, `:c::vec-tree`,
`:c::varr-ptr`, and hand-encoded hex with an `f0` disp8): `rt-vec-conj-own`'s head test and `rt-vec-conj`'s
head/to-push now ask `== vec-tree`; `:c::read-out`'s `Read.Elem` inline hex (`488378f000` / `0f85…`) now asks
`vec-tree` (`…01`, `0f84`); `:c::vec-glue-body` already asked `vec-tree`. Also: a bare `+56` offset feeding
`rt-bump`'s out-of-memory call in path 3 would have gone stale when the test's length changed; now computed.

## F3 — recursion through a Vector is recursion: FIXED, at TWO roots
`:c::shape-children` had no `vec:` arm (the brief's root) — AND `:c::shape-only` filtered a type's fields to
`rec:`/`henum:` BEFORE `:c::shape-children` saw them, so the first fix alone changed no byte. Found by measurement:
with both, `drop-vec-cycle.wat`'s glue census goes from 3 entries to 2 and its binary from 4,551 to 4,433 bytes —
`T`'s self-calling glue is gone. Types that lost glue: `:user::Val` (`elf/src/matchval.wat`) and `:user::T`
(the three probe fixtures).

**The F3 gate could not show the transition.** `drop-vec-cycle.wat` runs under `ulimit -s 256` with F3 off AND on
(depths 2 … 2,000,000). gdb: at the whole-tree drop the tree's count is **2**, not 1, so no glue runs at the top
either way — `user/nest`'s loop returns `acc` from its base arm with an increment. That is **F-210**, left for the
next strike. The mechanism F3 removes was confirmed directly: with F3 off, `T`'s glue and `vec:T`'s glue call each
other (`call`/`ret`, not a tail call), and a breakpoint on `vec:T`'s glue fired N times during the build.

## F4 — no bare 13: FIXED
Both comments carry the derivation (`:c::node-arity`, 5 bits a level, a 63-bit length, ⌈63/5⌉, log₃₂ in
practice); the first comment's wrong claim about Vectors is replaced by F3's rule.

## Regressions
Every `elf/probe/*.wat` except `drop-vec-cycle` / `drop-cons`, both builds: 66 agree; the same 25 do not, and all 25
fail identically on unmodified HEAD (refusal fixtures, reader fixtures, and older open shapes) — none is a regression.

## Gates — the orchestrator's runs
`WAT_DROP_CHECK=1 tools/bootstrap.sh` → fixpoint, 508,925 bytes. `tools/verify.sh` → `verify: ok` (408,007).
`WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok` (508,925), zero stops. `f209-tier1-self-vec`, `-build`,
`drop-3b-recs`, `drop-conj`, `drop-vec-cycle` agree both ways.
