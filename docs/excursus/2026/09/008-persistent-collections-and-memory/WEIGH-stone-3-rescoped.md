# WEIGH — excursus 008 stone 3: re-scoped — this strike becomes 3a, placement correct and checked

2026-09-27. The SCORE is honest about being partial, and that is credited. It cannot land: a misplaced
decrement makes a count TOO LOW, and a count of 1 licenses in-place mutation while another holder still
has the value — silent corruption. Until every drop is placed correctly and the WHOLE corpus runs clean
under the underflow check, decrements are unsafe to ship. The stone is too large for one strike, so:

- **3a (this tree, re-strike):** placement, correct and checked — R1–R3 below.
- **3b (drawn after 3a lands):** D1 drop glue per type with a worklist for recursive types, and D4
  freeing (to the bump when youngest).
- **then the bench** against `BENCH-baseline.md`, and the compiler's cost against stones 1 and 2.

## Credited so far

The decrement `:c::dec-hex` emitted only from `:c::drop-hex` through `:c::emit-drop` (one emission); drops
for a reading built-in's temporary (`drop-len`), a discarded allocating statement, an unused pointer
binding, a tail-call parameter not passed on, the copying `conj`'s source; the check build (`ud2` on
underflow) with its `jae` fix; `tools/reads.sh`'s third `count-hex` caller justified; fixpoint 319,048;
gates zero. The early-drop mutant diverged (a hang the check did not trap — see R2).

## R1 — remove the heap-range guard, and find the root

`:c::drop-hex` skips any value outside `r14`..`r15`, added because drops reached `rax = -691` and a code
address (`0x40028e`). A drop is emitted only for a value whose TYPE is a pointer, and the compiler knows
every type — so each of those was an emission site dropping a non-pointer (or a raw code address where
stone 2 made every function value an object). The guard hides the defect; extirpare forbids it. Remove
it; find each site that emitted a drop for a non-pointer (the check build and the stage-1 fault will name
them); fix the site. A literal (count 0) stays skipped by the literal guard, as stone 6 of 002 derived.
**STOP** if a pointer-typed value can legitimately lie outside the heap other than as a count-0 literal.

## R2 — the check is the gate, over EVERYTHING

Run the whole corpus and the compiler's own bootstrap with `:c::drop-check?` on: zero underflows. The
early-drop mutant hung instead of trapping — say why the check did not see it (a count taken from 2 to 1
is not an underflow; the corruption came from in-place growth at count 1). Add the check that WOULD see
it, or a fixture that shows it, or say why neither exists.

## R3 — complete the placements

Named bindings and parameters at their LAST use (`:c::live-after`), not only unused ones; `assoc` and
`concat` copy paths drop their source like `conj`'s; the `match` scrutinee at arm entry; a name dead in
one `if` arm at that arm's start. Closures' captures belong with drop glue (3b) — leave them.

Then `tools/verify.sh`, and append a re-strike section to the SCORE. Commit nothing.

---

# Round 2 — the drops corrupt the compiler itself (2026-09-27)

**Credited:** R1 done at the root — the `-691` / `0x40028e` drops were STALE RELOADS (a register let
reloaded after a call reused the register; a stack binding read with the raw frame displacement), fixed by
spilling register lets when bound and pointer parameters on entry; the guard is gone. R3's placements
(copying `assoc` / `concat`, the `match` subject, `if` arms, unused parameters kept off `rax`, read-only
parameters exempted at tail pass-through — which the check caught with `ud2`). R2's answer on the mutant
(2 -> 1 is a legal release; no count check can see it). Eleven probes agree with the check on.

**Not landable:** stage 1 — the compiled compiler — dies in `asm::fits?` on `0xffff8017499e8e06`, check on
or off. The signature of a drop placed too early somewhere in the compiler's own code: a count reaches 1
while another holder remains, something grows in place, memory is corrupted — the case the underflow check
cannot see.

**A named candidate class — evaluation order ≠ textual order.** Drops sit at a name's last TEXTUAL
occurrence, but `:c::call-indirect` pushes the arguments FIRST and evaluates the head SECOND ("the
arguments are pushed first and the target loaded second"): in `(f (g f))` the textual last `f` is in the
argument, evaluated before the head `f` — a use after drop. Every form whose evaluation order differs from
its text is the same class (check the binary-operator fold's operand order too). **The last occurrence must
be the last in EVALUATION order** — derive it from the order the code generator emits, not the text.

**Find the site systematically, not by hunting:**
1. **Per-class switches**: one compiler flag per drop class (temporaries, discarded statements, last-use
   names, copying `conj`/`assoc`/`concat` sources, `match` subjects, `if` arms, `ret`, tail parameters).
   Build stage 1 with ONE class on at a time — stage 1 compiling the compiler is the test. The class that
   fails is the class.
2. **Then by function**: within that class, enable drops only for functions in a name range and halve —
   the site falls out in ~9 builds.
3. Fix the ROOT the site shows (as R1 did), keep the switches out of the final tree or behind the check
   build, and run `tools/verify.sh` to the fixpoint.

Append a round-2 section to the SCORE. Commit nothing.

---

# Round 2, amended — the root is found in the source (2026-09-27)

**F-208**: `:c::eval-seq` omits a call's HEAD (kids from index 1), and `:c::call-indirect` evaluates the
arguments before the head — so in `(f (g f))` the argument's `f` is taken as last, dropped, and the head is
then called on it. This is not a candidate; it is on the page. Fix the CLASS, not the site:

- **R4 — one definition of evaluation order.** A single function answers, for every form, which children
  run and in what order — the head INCLUDED, and exactly the order the code generator emits (for an
  indirect call: arguments, then head — or change the generator to head-first; say which and why).
  `:c::live-after`, the drop placement, and every other walk that asks "what runs after this" consult it;
  no walk re-derives it.
- **R5 — each consumer states its safe direction.** "May I mutate in place" is safe when liveness
  OVER-counts; "may I drop" is fatal when it UNDER-counts. Where a consumer needs the other direction than
  the walk gives, it says so at the call.

The bisection by class and by function remains the fallback for any failure R4 does not explain. Then
`tools/verify.sh` to the fixpoint.

---

# Round 3 — the stage-1 corruption is gone; the check finds a double drop (2026-09-27)

**Credited:** R4 — `:c::eval-seq` is the generator's order, the head after the arguments for an
indirect call (`:c::value-head?`), and the reason the generator stays arguments-first is on the page;
`:c::last-walk` and `:c::live-after` both consult it; `elf/probe/drop-head.wat` is the F-208 shape.
R5 — `:c::last-use?` is the drop question and says its safe direction (a doubt leaves it false);
in-place mutation keeps `:c::live-after`. The bisection by class was run and named `copy` → `concat`,
and the root was found: an untracked `push rax` shifted every rsp-relative local through
`:c::cat-fold`. The check-off tree reaches the fixpoint at 362,792 bytes and elf-run is clean.

**Not landable.** Expectation 2 is the landing gate: the compiler under `:c::drop-check?` dies on `ud2`
with a heap pointer whose count is already 0. A heap object starts at 1; zero on the heap means one
decrement more than the increments. The check-off fixpoint passing is not evidence against it — with
nothing freed yet, a count of -1 is invisible. In 3b, when zero frees, it is a use-after-free.

## R6 — the double drop, to its root

The site as reported: *"increment one argument, call, then drop a different stack slot"*. That is the
signature the `concat` fix just showed — a displacement off by a slot — so test that hypothesis first
against the stack depth at that site; if it is not that, find which of the two references the extra
decrement belongs to. Fix the root the site shows. Then the check build must be ONE command, not a
source edit (the BRIEF's D5: an environment switch, off by default), so it can be run as a gate:
the compiler's own bootstrap under it AND the whole corpus — zero underflows.

## R7 — the rsp rule becomes a gate

`elf/compile.wat:305`: *"Every instruction that moves rsp goes through one of these and nothing else may
move it."* That is a convention, and it failed. It still fails in two more places the crawl found:
`:c::drop-saved` (`"59504889c8"`, a raw pop and push) and the `nth` drop at `elf/compile.wat:2605-2609`
(`"...504889c8"` a raw push, then a raw `"58"`). Both are harmless TODAY only because nothing between
the push and the pop addresses rsp — the exact condition `concat` broke. Climb the ladder: every
rsp-moving opcode reaches the output through `:c::push` / `:c::popn` and a gate (in the shape of
`tools/reads.sh`) fails the build on any other; or the emitter makes a raw one unwritable. Say which
rung and why.

## R8 — `:c::drop-on?` has a catch-all

`(:else false)` on a string: a misspelled class silently turns its drops OFF, and nothing says so —
exactly the silent default this compiler refuses everywhere else (no `_`, no catch-all; unknown is
`:c::fail`). Either the switches leave the tree, or they become a closed set a typo cannot reach.
Say which.

Then `tools/verify.sh` (check off) and the check build over bootstrap + corpus, both on your own runs.
Append a round-3 section to the SCORE. Commit nothing.

---

# Round 4 — R6's fix is refuted; the root is the consuming call's place in evaluation order (2026-09-28)

The executor changed: Grok is out of credits for some days, and round 3 was struck by Claude Sonnet.

**Credited, on my own runs:** R7 — `tools/rsp.sh` is wired into `tools/elf-run.sh`; it passes the tree,
and a mutant I planted (`"488b0050"` at `elf/compile.wat:2612`) fails it naming the line. The two raw
pairs route through `:c::push` / `:c::popn`. R8 — `:c::drop-on?` is gone (0 references).

The round-3 tree passes `tools/verify.sh` with the check off (my run, `verify: ok`, `rsp` inside it). That is
necessary and not sufficient: at4 below is a wrong answer that tree computes.

**R6's fix is refuted.** It stops dropping the source of a copying `assoc` / `conj` whenever that
source is not a symbol, reasoning that such a source "was never incremented". But a temporary's own
allocation IS its one reference, and a copying built-in consumes it (D3). Dropping it once is correct.
The probes are kept in this directory, `probe-3a-at*.wat`, run via `tools/probe.sh`:

| probe | shape | HEAD (no drops) | 3a before the fix, check on | 3a with the fix, check on |
|---|---|---|---|---|
| at1 | `(assoc (mk 3) :sp 5)`, a temporary | — | agree | — |
| at3 | `(assoc (emit o "ab") :sp i)` in a loop, `o` dead after | agree | agree | — |
| at4 | `(assoc (emit o "ab") :sp 8)`, `o` printed after | agree | hang (killed) | **WRONG: `o` prints `"xab"`, not `"x"`** |
| at5 | `t (emit o "ab")`, `(assoc t :sp …)`, `o` printed after | agree | hang (killed) | hang (killed) |

A temporary source is dropped safely (at1, at3). What breaks is `emit`'s
`(assoc o :code (concat (:user::Out/code o) h))` when the caller still holds `o`. The fix leaves at5
hanging (a named source it never touches) and turns at4 into a silent wrong answer.

**The root, read from the source.** `o` is `:c::linear?` in `emit` (one write; the read comes before it),
so the box takes `o` WITHOUT an increment. `:c::eval-seq` says `(assoc o :code V)` runs `o`, then `V`,
so the `o` inside `V` is the last use, and the drop fires there: the count goes 2 → 1. Only then does
the consuming call run (`slot_set_own`); it sees count 1 and writes in place over the object main
still holds. This is F-208's class again: **the generator uses the box at the CALL, after the value,
but the evaluation-order definition puts the box first.** The consume is an event of its own, and R4's
one definition does not contain it.

## R9 — revert R6's gate; put the consume where the generator puts it

1. Restore the drop of a non-symbol source after a copying `conj` / `assoc` / `concat` (D3).
2. In the one evaluation-order definition, a consuming built-in's source is used at the CALL, after
   every other argument, as an indirect call's head is. The drop walk (`:c::last-walk` / `:c::last-use?`)
   then cannot place a drop of the source's name inside the value, because the consume comes later.
   Say how in-place mutation (`:c::linear?` / `:c::dead-after-write?`) reads this, and that it stays
   on its safe side (R5).
3. Every consuming built-in, not only `assoc`: `conj`, `concat`, and any other that evaluates a box,
   then its arguments, then calls.
4. at1, at3, at4 and at5 agree with the check on. Move them into `elf/probe/` as `drop-at*.wat`.

## R10 — the check as one command

D5 asks for a switch the compiler reads (an environment variable, off by default), not a source edit.
The gate run is `tools/verify.sh` under that switch: the bootstrap plus the whole corpus, zero `ud2`.
That run is what lands 3a. So is `tools/verify.sh` with the check off.

Append a round-4 section to the SCORE. Commit nothing.

---

# Round 5 — R9 holds; the check finds another over-drop; R10 reads the environment on every drop (2026-09-28)

**Credited, on my own runs:** R9. `:c::eval-seq` puts a consuming built-in's box LAST (`elf/compile.wat:3811-3821`),
as the indirect call's head; the D3 drop of a temporary source is restored for `conj`, `assoc` and `concat`.
`elf/probe/drop-at{1,3,4,5}.wat` agree with the interpreter through `tools/probe.sh`, check off AND on
(`WAT_DROP_CHECK=1`): at4 prints `"x"`, at5 finishes. The sandbox bootstrap with the check off reaches the
fixpoint, 367,645 bytes (`/tmp/stone3a-r4/bootstrap-off.log`).

**Not landable:** the sandbox bootstrap with the check on (`/tmp/stone3a-r4/bootstrap-on.log`): stage 0 wrote a
385,393-byte compiler; stage 1 died on `ud2`. Captured under gdb, kept here as `gdb-3a-r4-checkon.txt`:
`rip 0x4398d7`, `[rax-8] = 0`. The site: a function whose four parameters arrive on the stack
(`mov 0xe8/0xe0/0xd8/0xd0(%rsp)` into rbx, r12, r13, rbp), spills three to `0x60`, `0x50`, `0x48(%rsp)`, tests
`(>= i (length v))` (r12 against `[rbx]`), and in the arm taken drops three stack slots in a row —
`0xb0`, `0xc8`, `0xd0(%rsp)` after one push, i.e. `0xa8`, `0xc0`, `0xc8` from the body's rsp. Those are not the
slots the spills wrote. Either the drops read the wrong slots (a displacement defect, the round-2 class), or
they are right and this object is the VICTIM of an earlier over-drop elsewhere. The trap names where the
count was found at zero, not who took it there.

**R10 costs every build.** `:c::drop-check?` (`elf/compile.wat:4207`) reads `/proc/self/environ` on every
call, and `:c::drop-hex` calls it for every drop emitted: I/O hidden inside a predicate that reads as pure,
thousands of times per compile. Stage 1 went from 1,974 ms (round 3) to 3,220 ms. And `contains?` matches
`XWAT_DROP_CHECK=1` and `WAT_DROP_CHECK=10`.

## R11 — the environment is read once

Read it ONCE, where the compile begins, and carry the answer in `:c::Prog` (or the layout); `:c::drop-hex`
reads the field. Match the whole entry (the environ is NUL-separated: the entry equals `WAT_DROP_CHECK=1`).
Measure stage 1's time before and after.

## R12 — the over-drop at `0x4398d7`, to its root

1. Name the function at `0x4398d7` (an address map of the check-on stage 0 compiler, or the shape above
   read against the source).
2. Decide: are the three drop slots the right ones? If not, it is a displacement defect — fix its root, and
   say why `tools/rsp.sh` could not see it. If they are, find who dropped the object first: shrink the
   function's shape into a `tools/probe.sh` fixture that traps under `WAT_DROP_CHECK=1`, then fix the placement.
3. A fixture for the shape goes into `elf/probe/`.

Then the landing gates on the real tree: `tools/verify.sh` (check off) and `WAT_DROP_CHECK=1 tools/verify.sh`,
both `verify: ok`, zero `ud2`. Append a round-5 section to the SCORE. Commit nothing.

## R13 — the stamp is removed before `elf/out` is touched

`tools/bootstrap.sh` removes `elf/out/.build-stamp` at line 88, but stage 0 (line 55, and `--fast` at line 37)
has already rewritten `elf/out` by then. A bootstrap killed in stage 0 on UNCHANGED sources leaves a stamp
that still matches, over half-rewritten binaries, and `SKIP_BUILD=1 tools/elf-run.sh` accepts them. (Found
2026-09-28: a killed verify left a stamp; it was stale only because the sources had also changed.) Remove
the stamp before the first write to `elf/out`, and prove it with the mutant that shows the hole: a bootstrap
killed mid-stage-0 on unchanged sources, then `SKIP_BUILD=1 tools/elf-run.sh` must REFUSE.
