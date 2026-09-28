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
