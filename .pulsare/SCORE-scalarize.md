# SCORE — scalarise, stopped

Tree `535c8d2`. Stop trigger 1. No change to `elf/compile.wat`.

The shape in `elf/bench/rec.wat` is the one the brief names. `:b::step` returns
`wat.type/i64`. `s` is read as `(:b::St/a s)` in the base and inside the
`assoc`, and written by `(assoc s :a …)`. Nothing else names it. The register
it already has can hold the field, and the tail jump does not have to change
the calling convention to do that.

## What the three analyses can say

`:c::occ` counts mentions of a name. The arms of an `if` are maxed, everything
else is summed. It does not say what the mention is.

`:c::live-after` asks whether a name is read after one write node.
`:c::dead-after-write?` is that plus "exactly one write." `:c::linear?` is
`occ <= 1` or that. This is why `rec` already reaches `slot_set_own`: the
field read is an argument of the `assoc`, so it is not a read after the write,
and the base-case read is the other arm.

`:c::none-mention?` is `occ = 0` over a range of children. It can say a subtree
does not name `s`. It cannot say the mentions that remain are all the same
field.

## What they cannot say

Scalarisable is a claim about the shape of every occurrence: a field read of
one `f`, or an `assoc` of that same `f`, and nothing else. None of the three
looks at the head of the form the name sits in. Composing them does not
produce it.

`linear?` in particular would admit shapes this transform must refuse:

- `(if (= i n) s (step (assoc s :a …) …))` — the record is returned from the
  other arm. `live-after` does not see across arms, so the name is linear, and
  scalarising would return the field where the caller expects the record.
- `(println s)` before the one `assoc` — the use is before the write, so it is
  not live-after either. The record escapes. `linear?` still holds.

Both are one write of one field plus a mention the three analyses cannot
classify. A walk that classifies each occurrence — read of which field, assoc
of which field, or other — is the missing analysis. It is not a composition of
`:c::occ`, `:c::live-after` and `:c::none-mention?`. Stop trigger 1 says not to
write it.

## The other two triggers

Trigger 2 is why the missing walk matters. Two hot fields already fail
`linear?` (`:c::mut-site` returns −2 for two writes). An escaping record does
not. Gating on `linear?` would let trigger 2's case through.

Trigger 3 does not fire. The tail target is `base + codelen` of the prologue,
set before the body is compiled (`elf/compile.wat`, the `:c::TC` built from
`o1`). An entry `mov FIELD(%p), %p` placed in that prologue runs on the call
from `main`, which still passes a pointer, and the back edge jumps over it
carrying the field. The convention does not have to change. That placement is
useless without the test that says the register holds a field and not a
pointer, so it was not emitted.

`recflat` remains the ceiling. `rec` is unchanged.
