# BRIEF — stone 0: a pointer read out of a container is counted at the read

> Stone 1 is struck and HELD on branch `excursus-001-stone-1`. It is correct, and it cannot land:
> it widens a silent wrong answer that is already at HEAD. This stone closes that answer at its
> root. F-188 is the finding; read it first.

## THE DEFECT — one root, two doors, both reproduced at HEAD

```
elf/probe/callrel-borrow.wat   door 1   interp 30|240000|3|1|30   HEAD 30|240000|4|1|99   ⛔
elf/probe/own-shadow.wat       door 2   interp 30|3|30            HEAD 30|4|99            ⛔
```

A value stored into a container is stored by MOVE and keeps count 1. Read back OUT, it is
indistinguishable from an owned value, so `vec_conj_own` path 3 extends a LIVE element in place.
The compiler diagnosed this itself, `elf/compile.wat:2989`:

> *"A field read is not a temporary. It is a BORROWED pointer into a container that is still alive
> — and its share count really is 1, because a fresh value stored into a container is stored by
> MOVE: `:c::share` increments symbols only."*

★ **This is the F-168/F-170/F-180 class — a wrong answer that passes every oracle.** Bootstrap
was byte-identical with this bug in it. `mem.sh` §1 was green with it in it. The two probes above
are the only oracles that see it, and they are the bar.

## THE RULING — the fix is at the READ, and the probes chose it

Three fixes were candidates. The two probes discriminate between them exactly (F-188's table):
sharing borrowed arguments at the call site closes door 1 and leaves door 2 open; making `own?`
binding-aware closes door 2 and leaves door 1 open. **Raising the count at the moment a pointer is
read out of a container closes both** — and every door not yet found, because it acts where the
borrowed pointer is born rather than where it is consumed.

## THE EXAMPLE TO COPY

`:c::share`, `elf/compile.wat:3033`. The increment already exists with both of its guards — a
string literal's count is 0 and lives in a read-only segment; a unit enum variant is a small
integer, not a pointer. Your increment is that one, applied to a value that is not a Symbol.
Read its guard prose in full before emitting anything.

## READ IN ORDER

```
docs/excursus/2026/09/001-reclamation-beyond-scope/DESIGN.md       what already exists
FINDINGS.md F-188                                                   the finding, both doors
elf/compile.wat:2985-3016   the diagnosis, and :c::fresh-str? -- the String form of this class,
                            closed at the concat site; the Vector form was never closed
elf/compile.wat:3025-3060   :c::share -- the increment and its two guards
elf/compile.wat:1859        nth                         <- a read out of a container
elf/compile.wat:1900        the record field read       <- a read out of a container
elf/compile.wat:3380        :c::match-form's payload bindings <- a read out of a container
elf/compile.wat:1880-1895   the conj site and own? -- where the bug fires. You are NOT fixing it here
elf/lib/runtime.wat:558-585 vec_conj_own's four paths; path 3 is the one that fires
```

Whether those three are ALL the sites is yours to establish — the list is the orchestrator's
crawl and it is not a proof.

## THE WORK

1. **At every site where a POINTER-typed value is read out of a heap container, raise its count**,
   with `:c::share`'s guards. An `i64` element read is untouched — `:c::ptr-ty?` decides.
2. **Add `elf/probe/own-shadow.wat` and `elf/probe/callrel-borrow.wat` to the proof** — both must
   AGREE with the interpreter afterwards. Decide with the SCORE whether either belongs in the
   corpus (`elf/src/` + `COMPARED`) so `elf-run` guards it permanently; say which and why.
3. **Probe the String form.** `:c::fresh-str?` closed strings at the concat site. Write the String
   analog of door 1 and door 2 and report whether it agrees at HEAD. If it diverges, that is a
   THIRD door — report it by name, do not absorb it.

## STOP TRIGGERS

- **STOP-1 — you are about to fix it at the `conj` site.** The conj site sees a linear parameter
  and cannot know where the value came from. A gate there is a stem. The root is the read.
- **STOP-2 — you are about to share at the CALL site.** That closes door 1 and leaves door 2 open;
  `own-shadow.wat` proves it. If the read-site fix turns out impossible, STOP and report why.
- **STOP-3 — the cost is large.** Every pointer read out of a vector now writes a word. If the
  compiler compiling the corpus (`tools/cc-time.sh` or the instruction count the SCORE uses) moves
  more than +5%, or any `vs-c.sh` row moves more than +5%, STOP and report the numbers. Do not
  narrow the rule to get under the bar — a narrower rule re-opens a door.
- **STOP-4 — a bootstrap or elf-run red.** Capture it and report it. Never re-run a red.

## OUT OF SCOPE, AFFIRMATIVELY

Stone 1 and its branch · the caller-side release · `:c::allocates?` · anything in
`elf/lib/runtime.wat` (the runtime is correct; it is being handed the wrong count).

## METHOD

`/home/watmin/Work/holon/the-little-wat`, branch `main`. `timeout -s KILL` on every wat run.
The tree is untouched while `tools/bootstrap.sh` or `tools/elf-run.sh` runs. Every replacement
asserts it matched. `cond` ends in `(:else …)`; no `_`, no catch-all. Bootstrap without `--fast`.
**Leave the tree dirty and do not commit.** Write `SCORE-stone-0-count-at-the-read.md` beside
this file, one section per EXPECTATIONS row, real output pasted in.
