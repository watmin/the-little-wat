# BRIEF — scalarise a non-escaping record parameter into its own register

Tree `535c8d2`. Your SCORE-losses was right and I verified it: `elf/bench/rec.wat`'s
`:b::step` returns `wat.type/i64`, not `:b::St`. The record does not escape. Its only uses
are one field read and one `assoc` on that same field. The pointer is dead the moment the
field occupies the register the pointer had — no spare required, and the four-parameter
cliff F-150 refused does not apply to this shape.

## The work, in one paragraph

Teach the compiler that a record parameter whose only uses are field reads and `assoc`s on
a single field, and which never escapes, can be represented BY THAT FIELD in the register
the parameter already owns. The entry loads the field once from the incoming pointer; a
field read becomes a register read; the `assoc` becomes a register write; the tail call
passes the new field value. `elf/bench/recflat.wat` is what the output should look like.

## The rooms, read in order

- `elf/bench/rec.wat` — the target. `:b::step` is the whole shape: one record parameter,
  one field, returns the field.
- `elf/compile.wat:3098` `:c::param-env` — where a parameter is bound to a register index
  and a type. The scalarised parameter still takes its register; what changes is what lives
  in it and what its type says.
- `elf/compile.wat:2343` `:c::assoc-form` — emits the `slot_set` / `slot_set_own` call. For
  a scalarised record this becomes a register move and nothing else.
- `elf/compile.wat:965` — the field-read arm (`:c::acc-index`), currently `mov d(%reg),%rax`
  after C-183. For a scalarised record the field IS the register.
- `elf/compile.wat:2104` `:c::occ`, `:2176` `:c::live-after`, `:2250` `:c::linear?`,
  `:2873` `:c::none-mention?` — the analyses that already exist. **Build the escape test out
  of these rather than writing a fourth**; C-176 and F-158 both turned on their exact
  semantics, and a second opinion that disagrees with them is a bug generator.
- `elf/compile.wat:780` `:c::rec-index`, `:786` `:c::field-index`, `:892` `:c::rec-name-of` —
  how a record type resolves to its fields.

## Sketch

    is-scalarisable(param p of record type R, function body B):
      every occurrence of p in B is either
        (:R/f p)            a field read, same f every time
        (:wat::core::assoc p :f v)   an assoc on that same f
      and p appears in no other position — not returned, not an argument to
      another call, not stored, not compared
    then:
      entry:      mov FIELD_OFFSET(%p_reg), %p_reg     once
      field read: %p_reg
      assoc:      the value, into %p_reg
      tail call:  the new field value into %p_reg

## Blast radius

`elf/compile.wat` only. No change to `elf/lib/x86.wat` or `elf/lib/runtime.wat` — this emits
instructions that already exist. No new record layout, no runtime routine.

## STOP triggers

1. **If the escape test needs a new analysis rather than a composition of `:c::occ` /
   `:c::live-after` / `:c::none-mention?`, STOP** and say what is missing. Do not write a
   fourth liveness.
2. **If a record with two hot fields, or one that escapes, reaches the transform, STOP.**
   That is the general case and it wants the allocator F-150 named. This is the one-field
   non-escaping case only.
3. **If the entry-load has nowhere to go because the caller's convention disagrees, STOP.**
   `main` calls `step` with a pointer; the loop carries a field. Say so rather than changing
   the calling convention to make it fit.

## Expectations — fixed before the strike

| what | command | expected |
|---|---|---|
| the compiler still reproduces itself | `./tools/bootstrap.sh` | byte-identical fixpoint |
| nothing else moved | `./tools/emitted.sh check` | only `rec.elf` (and any other program of this shape) |
| answers unchanged | `./tools/elf-run.sh` | 30/30 agreeing, same refusals and traps |
| `rec` gets faster | `taskset -c 0 perf stat -e cpu_core/instructions/,cpu_core/cycles/ ./elf/out/rec.elf` | toward `recflat`: 8.00 ins/it, ~1.50 cyc/it |
| `rec1` and `recflat` unchanged | same | 14.00 / 2.34 and 8.00 / 1.50 |

**No cycle figure is predicted beyond "toward recflat".** Six attempts at `triple` this
session each removed work and moved cycles the wrong way; report uops, retiring slots,
slots and cycles separately and say when `slots/cycles` is not 6.

Trap-door risk named: `rec.wat`'s record is CONSTRUCTED in `main` and passed in. If the
transform makes the constructor dead, `main` may allocate a record nobody reads. That is
correct but wasteful, and it is a separate finding, not a reason to widen this strike.

## Prior shape to copy

`C-176` (liveness over mention-counting) is the closest comparable: an analysis added to
`compile.wat`, gated narrowly, verified by the fixpoint plus `elf-run`. `F-158` is the
cautionary one — its mechanism was right and every number attached to it was invented.
