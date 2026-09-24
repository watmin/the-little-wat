# BRIEF — stone 0b: a type is guarded only against what it can actually be

> Stone 0 closed F-188 and costs the compiler **+10.64%** (F-189). The ablation says the cost is
> the GUARD — `cmp [rax-8],0 ; je` — not the increment. This stone keeps every counted site and
> removes the guard where the type makes it impossible for the guard to fire.

## THE DEFECT — one guard, applied to types it cannot protect

`:c::count-hex` (`elf/compile.wat:3068`) emits, for every pointer type:

```
cmp  qword [rax-8], 0      ; a string LITERAL has count 0 in a read-only segment
je   +4                    ; ... so writing it would fault: skip
incq qword [rax-8]
```

plus, for `penum:`/`henum:`, a `cmp rax,0x1000 ; jb` in front (a unit variant is a small integer).
The `cmp [rax-8],0` exists for exactly one reason, stated at `:3049`: *"a string LITERAL lives in
the read-only segment. Its count is zero by construction."* **Only a type that can BE a read-only
literal needs it.**

★ The two structural facts behind that, read on the disk, not assumed:

- **Only strings are literals in the data tail.** `elf/compile.wat:46` lists what the compiler
  emits: *"string literals, as VALUES: a pointer to [len:8][bytes...] in the data tail"*. A Vector
  is *"allocate and fill"*; a record has its *"slots filled"*.
- **There is no static empty Vector.** `:c::vec-form` calls the allocator (`at-varr`) for EVERY
  Vector form, zero elements included.
- **The `cmp` already dereferences `[rax-8]`.** Whatever would make `incq [rax-8]` fault already
  faults at the `cmp`, so the `je` protects against a count-0 WRITE and nothing else.

## THE PROBE — committed before this brief, and it is your premise's oracle

`elf/probe/count-bare.wat` reads an EMPTY Vector, a record, and a record's Vector field out of
containers and then touches each. It agrees today: `1|0|1|0|"t"|3`. It must agree after. If the
premise is wrong anywhere a type reaches, this is where it faults.

## THE RULING — builder, 2026-09-23

> *"draw stone 0b and send the shadowdancer"* — the recovery of F-189, **without narrowing.**

## THE WORK

1. **Derive the guard from what the type can be.** For each pointer type, the guard is the union
   of what its values can actually be: a read-only literal needs the `cmp [rax-8],0 ; je`; a
   small-integer tag needs the `cmp rax,0x1000 ; jb`; a type that can be neither is `incq [rax-8]`
   alone. **The derivation is yours**, per tier, from the representation ladder at
   `elf/compile.wat:900-975` — I have not written the table on purpose. Note that a `penum:` value
   IS its payload pointer, so what a `penum:` can be depends on what its payload can be.
2. *(The `match` site's fail-open fallback was moved into stone 0a, which removes it by construction.)*
3. **Keep every site.** `nth`, all three accessor arms, the `match` payload: all still counted.

## READ IN ORDER

```
docs/excursus/.../SCORE-stone-0-count-at-the-read.md   the ablation, the census, the orchestrator's verdict
FINDINGS.md F-189                                       the cost and its attribution
elf/compile.wat:36-50       what the compiler emits; the data tail holds string literals only
elf/compile.wat:900-975     the enum representation ladder -- what each tier's value IS
elf/compile.wat:3032        :c::ptr-ty?
elf/compile.wat:3046-3066   :c::share -- BOTH guards, and the prose saying why each exists
elf/compile.wat:3068        :c::count-hex -- where the change lands
elf/compile.wat:3095        :c::count-read
elf/compile.wat:3112        :c::maybe-unit?
```

## STOP TRIGGERS

- **STOP-1 — you are about to drop a counted site.** Any site. That is a narrowing; it re-opens
  F-188 doors, and `elf/src/borrowed.wat` will say which.
- **STOP-2 — you find a non-string pointer type whose value can be a read-only literal or live
  outside the heap.** Then the premise is wrong for that type. STOP and report it — do not guard
  it quietly and carry on, because it means the premise needs re-deriving everywhere.
- **STOP-3 — less than half of F-189 comes back.** Measure the corpus compile with three
  compilers, each built to its own fixpoint: before stone 0 (`dada88f`), stone 0 (`e0861bc`), and
  yours. F-189 is the first gap (+10.64%). If yours recovers less than half of it — i.e. it is
  still more than +5.32% over `dada88f` — STOP and report all three, instructions AND cycles. The
  remaining cost may be the memory touch at `[rax-8]` rather than the instruction count, and that
  is a different stone, not a reason to drop a site.
- **STOP-4 — a red.** Capture it, never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Counting at the STORE instead of the read · counting only types that reach an own path · stone 1
and its branch · `elf/lib/runtime.wat`. The first two are the other F-189 candidates; they are
recorded in DESIGN as not drawn, and this stone does not touch them.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, branch `main`, HEAD `e0861bc`. `timeout -s KILL` on
every wat run; the tree untouched while `bootstrap.sh` or `elf-run.sh` runs; every replacement
asserts it matched; `cond` ends in `(:else …)`; bootstrap without `--fast`. Measure user-mode
instructions AND cycles, pinned `taskset -c 0`, best of 9, interleaved; build each comparison
compiler to its own fixpoint and say so. **Every number in the SCORE is one you measured.**
**Leave the tree dirty; do not commit.** Write `SCORE-stone-0b-a-guard-for-what-the-type-can-be.md`
beside this file, one section per EXPECTATIONS row, output pasted in.
