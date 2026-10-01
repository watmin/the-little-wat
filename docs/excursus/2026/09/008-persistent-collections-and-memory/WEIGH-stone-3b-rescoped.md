# WEIGH — excursus 008 stone 3b: re-scoped into three strikes

2026-09-28. The first strike (Claude Sonnet) landed G6 alone — `:c::rt-drop1`, the one-field walk that
guessed a pointer from its value, is gone — and stopped before G1 for two sound reasons, both credited:

- **Glue must be CALLED, not inlined.** r8–r11 are the `let` scratch pool (`:c::Prog/nscr`) and may hold live
  values at a drop site; only a `call` carries the "r8–r11 are dead across this" convention
  (`elf/compile.wat:6357`). So glue is one routine per type, placed like a function (`:c::place`), and a
  drop site's slow path is a call.
- **G1 alone moves no number the brief measures** — freeing does.

**Refuted: the flat-Vector size disagreement.** The SCORE reads `rt-varr-new` and `rt-vec-conj` as sizing a flat
Vector differently by 8 bytes. They agree: `varr_new` allocates `len*8 + 24` (`[flat][count][len]` + elements,
`runtime.wat:729`); `vec_conj`'s copy allocates `r8*8 + 24 + 8` where `r8` is the OLD length — the `+8` is
the appended element, so it is `(len+1)*8 + 24`, the same formula. The one real exception is `vec_conj_own`
(path 4 and path 2): its block is a power-of-two rounding recomputed from the length each time (no stored
capacity), so freeing such a block must call the SAME rounding the allocator calls — one function, two callers.

**The stone was too large for one strike.** It becomes three, each gated by both verifies:

## 3b-1 — glue per type, and death is visible (this strike)

- **G1** for every NON-recursive pointer type: one glue routine per type, called from a drop site's slow path
  (count reached zero). `str` holds nothing; `rec:R` its pointer fields by mask; `vec:T` flat elements or the
  trie (nodes by level, bounded); `henum:E` the live variant's payload. A type in a recursive group (a type
  that reaches itself through its fields) gets NO glue in this strike: its references leak — late, never early —
  until 3b-3's worklist. Say which types those are (the census found none in the compiler; the list fixture is one).
- **G5 now, before any byte is reused:** under `WAT_DROP_CHECK=1`, an object whose count reaches zero is POISONED
  (its count word set to a value no live object has), and every increment and decrement refuses a poisoned
  object with a named stop, exit 70. With glue running, this is the gate that proves the glue's drops and 3a's
  placements together: any use of a dead object stops. A mutant that drops one reference early must stop.
- Gates: `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`, both `verify: ok`; every `elf/probe/drop-*.wat`
  agrees both ways. Nothing is freed; peak RSS does not move and is not expected to.

## 3b-2 — freeing (G4)

To the bump when youngest; sizes from the allocators' own functions (one function, two callers); the cascade.
The `drop-3b-recs` and `-closure` fixtures' peak RSS falls.

## 3b-3 — closures and recursive types (G2, G3)

Closure glue by creation site; the intrusive worklist through the dead object's count word; the
100,000-deep list drops in a loop with a flat stack and its peak RSS falls to about one list.

Then the bench against `BENCH-baseline.md`, and the compiler's cost against stones 1 and 2.

---

# 3b-1, round 2 — G5 works: the compiler uses a dead object (2026-09-28)

**Credited:** G5's two halves are on the page — `:c::poison-count` (-1) written when a decrement reaches zero
(`:c::dropchk-hex`), and `:c::countchk-hex` refusing an increment on a poisoned object, both only under
`WAT_DROP_CHECK=1`; the plain build's fast path is unchanged (its `--fast` fixpoint, 371,678 bytes).

**The `written` / `filesz` assert is not the finding.** When the source changes what is EMITTED, a `--fast`
bootstrap is not a fixpoint test: the seed emits with the OLD logic, so the chain needs three hops. On my own
run (sandbox `/tmp/s3b1`, the tree's G5 source, `WAT_DROP_CHECK=1` throughout):

| hop | binary | its own code has | result |
|---|---|---|---|
| seed (370,028, the committed plain compiler) → `s1` | 393,776 | the OLD check | `compile: ok` |
| `s1` → `s2` | 469,096 | poison + the increment check | — |
| `s2` → `s3` | 469,096 | | **`wat: reference count underflow`, exit 70** |

`s2` is the first compiler whose OWN code poisons dead objects, and running it stops: **somewhere the compiler
increments or decrements an object whose count already reached zero.** Before G5 such an under-count netted out
unseen (1 → 0 → 1). That is what G5 is for; it is the next root.

## R1 — the dead object's history, to its root

In `/tmp/s3b1` (keep it; `s2.elf` is there): run `s2.elf` under gdb (ASLR off) with `WAT_DROP_CHECK=1`, break at
the underflow stub (`:c::at-uflow` — its address from the layout, or catch the `exit` 70), read `rax` (the dead
object). Re-run with a hardware watchpoint on `[rax-8]` (`watch -l`, after `starti`) logging every write with
`$pc`: allocation (1), increments, the decrement to 0 and the poison (-1), then the use that stopped. Map each
`$pc` to its function (a sandbox trace of `Fn/addr` in `:c::pass`, printed while `s1` compiles `s2`). Name the
defect — which drop or which missing increment — fix its ROOT as a class, add a fixture in `elf/probe/`, and
repeat until `s2 → s3` runs and `s3 → s4` is a fixpoint. Then G1.

---

# 3b-1, round 3 — the dead object was a compound box deferred whole; one change comes back out (2026-09-28)

**Credited:** the watchpoint history (alloc 1 → a share to 2 in `rt-tree-push` → two decrements in `:c::hexlen`, the
second poisoning) and its root: `:c::eval-seq` deferred a consuming built-in's kid 1 to the END whenever the head
was `conj`/`assoc`/`concat`. That is right for the box's VALUE, used at the call (round 4 of stone 3a), but
when kid 1 is a COMPOUND expression the names inside it are evaluated FIRST, where it sits; deferring them made
an early occurrence look like the last one. The fix — defer kid 1 only when it is a bare Symbol
(`elf/compile.wat:3831`) — refines round 4's rule rather than undoing it. `elf/probe/drop-concat-box.wat`
reproduces the class (diverges under the check with the fix reverted) and agrees both ways. `tools/reads.sh`
followed `:c::count-hex`'s new signature. The chain seed → s1 → s2 → s3 is clean under the check with a fixpoint,
and both verifies are `verify: ok` (372,501 / 470,582 bytes) on the executor's runs.

**Refuted: the `:c::cat-fold` share** (`elf/compile.wat:3423-3439`). `str_cat` / `str_cat_own` COPY their right
operand (rcx) and consume only the left, the accumulator — so a folded operand is READ, like `nth`'s, and nothing
drops it after the call. Sharing it is an increment no one gives back: a leak on every `concat` of a live name.
The SCORE's own ablation shows it did not fix the crash. It is a guard, not a root; it comes out.

## R2 — take the `cat-fold` share back out

Show the fixture and the chain still pass without it.

## R3 — G1, glue per type (the rest of 3b-1)

As `3b-1` above: one CALLED glue routine per non-recursive pointer type, from a drop site's slow path (the count
reached zero); the recursive types listed and left without glue. With G5 in place, every dead object the glue
walks is poisoned under the check, so the chain under `WAT_DROP_CHECK=1` is the proof that the glue's drops are
right. Then both verifies.

---

# 3b-1 landed (2026-09-30)

**On my own runs:** `tools/verify.sh` → `verify: ok` (406,041 bytes); `WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok`
(506,342 bytes, the compiler and the whole corpus under the poison, zero stops); `drop-3b-*`, `drop-concat-box`,
`drop-ifval` agree both ways. **R2 was already done** when round 3 resumed: my grep counted a comment that still
names `needs-share?`; the executor read the tree over my message, rightly.

**G1:** a glue address table built once from declarations (`:c::glue-census`), placed between user code and the
runtime like functions (`:c::glue-place`); bodies per kind — record by mask, payload enum by tag, Vector flat or
trie, trie node by level; one call site, `:c::dropchk-hex`, on the count reaching zero. Two roots found with the
watchpoint: a glue call clobbering `rax` before the poison write; and glue walking into a trie node without
decrementing it — a node shared between Vector versions (`rt-node-copy`) was drained once per version.
`:user::L` (the list fixture) is recursive and has no glue until 3b-3. Nothing is freed yet (3b-2).

**Known, late not early:** a Vector grown in place carries `arm-own` (`0x1_00000001`); its last drop leaves
`0x1_00000000`, not zero, so its glue never runs — a leak for 3b-2 to settle with the size question.
