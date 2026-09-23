# BRIEF — stone 1: a call that returns no pointer releases what it made

> The heap release has shipped since C-120 and frees 2.9x. It is **scope**-based, so it reaches a
> discarded statement and nothing else. `elf/src/escape.wat` leaks **63.8 bytes/iteration,
> linearly**, with the right answer at every n.

## THE DEFECT — one class, and the compiler already named it

`:c::seq` marks `r15` before every non-final form of a sequence and restores it after. That is
every allocation the release can reach. An allocation made *inside a call* is never a discarded
non-final form, so it is never reached:

```
elf/src/escape.wat:6   (user/len s) is an OPERAND of +, not a statement    ⛔ never marked
elf/src/escape.wat:6   inside user/len, the concat is the FINAL form       ⛔ never marked
elf/bench/optmh.wat    the same shape at scale -- 610.9 MB, live set 16 B  ⛔ F-185
```

`elf/compile.wat:3684`, in the compiler's own prose:

> *"Freeing those needs reachability, not scope — a collector, or **a caller-side release at every
> call whose return type is not a pointer. The second is the next thing to build** and is the same
> idea one level up; the first is a different program."*

★ **The recurring class in this repo is a silent wrong answer that passes every oracle** — F-168,
F-170 and F-180 were all green everywhere while being wrong, and F-187 was a finding written on a
stale comment. Five times this session an oracle said yes to something wrong. A green bootstrap is
necessary here and is not sufficient; row 1 of EXPECTATIONS exists because of that.

## THE RULING — builder, 2026-09-23

> *"i explicitly do not want a gc that pauses anything.. can we do this inline as we make forward
> progress in programs?"*

A caller-side release is inline by construction: the decision is made at compile time, the cost is
two pushes and two pops, and there is no phase, no scan and no safepoint.

## THE EXAMPLE TO COPY — it is three lines, already written

`elf/compile.wat:3805`, `:c::seq`. Read it before anything else; your emission is this shape at a
call site rather than a statement:

```
o1 (if drop? (:c::push o "41574157" 16) o)          the mark
o2 (:c::expr a o1 …)                                the work
o3 (if drop? (:c::popn o2 "415f415f" 16) o2)        the release
```

## READ IN ORDER

```
elf/compile.wat:3652-3690   THE PATTERN. The section "Why a bump allocator can free", its
                            soundness argument (a let slot is out of scope at the end of a
                            statement; poke is not), and the paragraph naming THIS work.
elf/compile.wat:3800-3816   :c::releasable? and :c::seq -- the worked reference above.
elf/lib/runtime.wat:558-585 vec_conj_own's four paths. Path 3 is STOP-1. Read the prose.
elf/lib/runtime.wat:526     rt-bump: r15 is the bump pointer, r11 the candidate top, and the
                            commit is `mov-rr r11 r15`. A rewind is one mov.
elf/src/escape.wat          the fixture. It must go FLAT in n.
tools/mem.sh                the instrument. Six sections; §1 is "does the release free
                            anything still live?" and it is the one that catches this wrong.
```

`:c::call-user`, `:c::ptr-ty?` and `:c::calls-poke?` you locate yourself — **the predicate is not
written in this brief on purpose.** Derive its shape from `:c::releasable?`, which is the same
question one level down.

## THE WORK

1. **Decide releasability at the call site from the callee's DECLARED return type.** `Fn/ret`,
   through `:c::ptr-ty?`. Not the runtime value, not the argument types.
2. **Reuse `:c::calls-poke?`.** The `poke` hazard is identical one level up and the fixpoint over
   `Prog/fns` already exists.
3. **Emit the mark before argument evaluation and the release after the call returns**, in the
   order `:c::seq` already establishes.

## STOP TRIGGERS

- **STOP-1 — you are about to assume `share` protects a caller's vector.** `vec_conj_own` path 3
  (`elf/lib/runtime.wat:563`) extends the heap over a vector whose last element *"ends exactly at
  the heap top"*. C-120 is safe from this because the in-place paths are gated on a PROVED last
  use, so nothing observes the extension afterwards. Path 2 keys on `arm-own`, which `:c::share`
  defeats — **path 3 keys on `heap-arm`, and it is NOT established that `share` closes it.** If a
  callee can extend a caller's vector in place, a caller-side restore frees the extension while
  its length still counts it. **Prove path 3 is closed, with a citation, or STOP and report.**
- **STOP-2 — you are about to infer a return type from a function body.** If the declared type is
  not available at the call site, STOP.
- **STOP-3 — you are about to re-run a red to see whether it passes.** Capture it and report it.
  There is no such thing as a known flake here.
- **STOP-4 — the release turns out to need a guard you invent.** A guard invented to make a hazard
  go away is the patch, not the stone. STOP and report the hazard.

## OUT OF SCOPE, AFFIRMATIVELY

Pointer-returning calls (that is reachability — a collector, a different program) · tail calls (no
return point at which to restore) · intrinsics `concat`/`subs`/`to-string` (they ARE the
allocation, not a call over one) · `madvise` release to the OS (DESIGN records why it is not
drawn) · raising `:c::heap-bytes` (free, and fixes nothing).

## METHOD

Work in `/home/watmin/Work/holon/the-little-wat`. Every wat run takes `timeout -s KILL`. The tree
stays untouched while `tools/bootstrap.sh` or `tools/elf-run.sh` is running — both hash sources
and a mid-run edit produces a stale-fixture red. Every text replacement in an edit script asserts
it matched. `cond` arms are `(:else …)`; this dialect has no `_` and no catch-all.

**Leave the tree dirty and do not commit** — the orchestrator weighs the kill against its own read
of the disk and makes the commit. Write `SCORE-stone-1-caller-side-release.md` beside this file,
one section per EXPECTATIONS row, each with the command's real output pasted in.
