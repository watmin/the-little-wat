# CRAWL — excursus 008 stone 3b: drop glue per type, and freeing

2026-09-28, against `586907a` (3a landed). The orchestrator's read of the ground before the strike is drawn.
3a made every count come DOWN at the right place; nothing happens at zero yet. 3b is what happens at zero:
drop what the object holds (drop glue), then give its bytes back (freeing). The builder's rulings stand
(`CRAWL-M1-the-count-comes-down.md`): one discipline, the count; drops synchronous and ITERATIVE; per-type
drop glue; no GC, no pauses; "very close to what rust feels like".

## What the disk says

**Every object kind, and what it holds** (`elf/lib/runtime.wat:1882-1955`, the layout block):

| kind | allocation | pointer at | holds | size known from |
|---|---|---|---|---|
| String | `[count][len][bytes]` | `len` | nothing | `len` |
| record | `[count][len][field…]` | `len` | the pointer fields — the record's mask, known per type (`:c::ptr-mask`) | `len` |
| flat Vector | `[flat=0][count][len][elem…]` | `len` | its elements when the element type is a pointer | `len`, but an `arm-own` block was given a power-of-two capacity (`vec_conj_own`) |
| trie Vector | `[tree=1][count][len][shift][root]` | `len` | the root node | fixed |
| trie node | `[count][32][slot×32]` (`rt-node-new`, `:747`) | the arity word | 32 child NODES (interior) or 32 elements (leaf, `shift == 5`) | fixed |
| closure | `[count][code][cap…]` (`:c::close-form`) | `code` | its captures | NOT in the object: the length word is overwritten with the code address |
| payload enum (tier 3) | a heap block with the tag in slot 0 | — | the payload | per variant |
| literal | count 0, in the data tail | — | never dropped — the literal guard | — |

**The children's counts are true.** A copied node counts its children (`rt-node-copy`, `:768`,
`count-span` under r11); `slot_set` counts a copied record's pointer fields (the r11 mask, stone 2); a
capture is shared when it is stored (`:c::close-push`); a read out of a container counts (`:c::read-out`,
F-188). So when an object dies, each pointer it holds carries one reference that is the object's to give
back. That is what drop glue decrements.

**What exists for 3b already:** `:c::rt-drop1` (`runtime.wat:1704`) — raw hex, a one-pointer-field walk that
stops when a field is `< 0x1000`: a GUESS that a small word is not a pointer. Nothing calls it
(`:c::emit-drop` emits only the decrement). The glue per type needs no guesses: the compiler knows every type
at every drop site. It retires.

**The youngest-object test exists once:** `vec_conj_own` path 3 — "its last element ENDS EXACTLY AT THE HEAP TOP"
(`runtime.wat:622`). D4's freeing is the same question asked of any object: does it end at `r15`?

## What this settles, and what it leaves

1. **Glue is per TYPE, from the compiler.** For `vec:T` the glue drops each element with `T`'s glue (flat), or the
   root node (trie; the node glue recurses by level — depth ≤ 13 for a 64-bit index, so recursion there is
   bounded); for `rec:R` the pointer fields by the mask, each with its field type's glue; for a payload enum by
   the tag. A type with a free variable (`…;?`, `:c::free-ty?`) cannot name its elements' glue: those
   elements are NOT dropped (a leak — late, never early). The census of how many drop sites that is comes first.

2. **A closure's glue cannot come from its type.** Two closures of one `fn:` type capture different things, and
   the object no longer says how many. The glue belongs to the CREATION site (the lifted function, whose `Cap`
   list is known): reach it from the object — e.g. a glue address one word before the lifted function's code,
   which the closure's `code` word already points at. A static closure has count 0 and is never dropped.

3. **Iterative, without allocating and without a stack that grows with the data.** A 100,000-deep `Cons` list must
   drop flat. A dead object's COUNT WORD is free the moment it reaches zero (nothing live holds it). So the
   worklist can be INTRUSIVE: a dead object waiting to be walked is linked through its own count word. A
   self-recursive type (one glue) needs only the link; a group of mutually recursive types needs the link plus
   which member it is, which fits in the pointer's unused high bits. Zero allocation during a drop (a drop that
   could run out of memory would be absurd), zero stack growth, and every recursive shape — a list, a tree,
   mutual recursion — walks in a loop.

4. **Freeing (D4) is to the bump, when the object is the youngest**: its end equals `r15`, so `r15` comes back
   to its start. A structure built front to back then frees back to front in one cascade: when the parent goes,
   the child it held becomes the youngest in turn. Any other dead object stays where it is until M2's allocator.
   An `arm-own` vector's end is its CAPACITY, not its length: freeing must compute the size the allocator gave.

5. **The check build must see a use after free.** With freeing, an under-count stops being an underflow and
   becomes reuse: the bytes belong to a newer object, and a stale drop decrements THAT object's count (round 7
   showed exactly this). So in the check build, a freed object is POISONED — its count word set to a value no
   live object has — and every increment and decrement refuses it with a named stop.

6. **The region release (C-120) still rewinds.** It restores `r15` at a statement boundary; a drop that freed to the
   bump inside the statement lowered `r15` below the mark, and the restore raises it back — harmless, the bytes
   above are dead. It retires LAST, as ruled; 3b neither relies on it nor removes it.

## The census — run (2026-09-28, sandbox `/tmp/stone3b-census`, a traced compiler two hops from the seed)

Every drop site the compiler emits across the corpus and itself (4,504 emissions — each program is compiled in
two passes), by the type it drops:

| kind | emissions | glue |
|---|---|---|
| `str` | 1,736 | none — free the bytes |
| `vec:` | 1,572 | by element type; 7 of the 11 vector types hold pointers (`vec:str`, `vec:rec:…`, `vec:vec:i64`, `vec:fn:…`, `vec:henum:…`) |
| `rec:` | 1,100 | by the record's mask |
| `henum:` | 48 | by the tag |
| `fn:` | 38 | by the creation site (§2) |
| `enum:` (all-unit) | 10 | none — not a pointer; `:c::drop-hex` already emits nothing |

**Zero** drop sites have a free type (`;?`): every drop can name its glue, so §1's leak does not arise today.
55 distinct types. **None of the compiler's own types is recursive** (its records nest to a fixed depth:
`Prog` → vectors of `Fn`, `Rec`, `Src` …), so cross-type recursion in the glue is bounded by the type nesting,
and the intrusive worklist (§3) is for a user's self- or mutually-recursive type — the `Cons` list, the tree —
which only the fixtures below exercise.

## The probe before the brief

- **The disconfirming shape:** a 100,000-deep `Cons` list (it needs a terminator, which 3a's `drop-cons.wat` lacked
  — a variant `Nil`), dropped whole; a Vector of records of Strings; a closure capturing a String, dropped.
  Before 3b each leaks and agrees. After it, each agrees, peak RSS falls, and the stack stays flat.

## Out of scope — rejected for 3b

The allocator that reuses holes (M2) · pages back to the OS (M4) · retiring the region release · maps and sets.
