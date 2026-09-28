# SCORE — excursus 008 stone 3: the drop

A count can come down. The tree is dirty. Nothing was committed. The bench against `BENCH-baseline.md`, and the compiler's instruction count against stone 1 and stone 2, were not measured.

## Expectations

| # | result |
|---|---|
| 1 | `drop-len`, `drop-shadow`, `drop-conj`, and `drop-tail` agree with the interpreter (`tools/probe.sh`). `drop-len` prints `4` for `(length (concat "ab" "cd"))`. `drop-shadow` prints `inner`, `inner`, `outer`. `drop-conj` prints `20`, `99`, `25`: the source kept its length across a copying conj, and a later linear `conj` still sees that vector. `drop-tail` prints `0`. |
| 2 | With `:c::drop-check?` true, `drop-len`, `drop-shadow`, `drop-conj`, `pvec`, and `memory` agree, and so do 52 of the corpus programs. `reader` agrees after the check's `jae` was fixed to skip both bytes of `ud2`. `fileio` fails in the probe sandbox because the interpreter looks for `elf/src/four.wat` beside the copied source; the native run printed and exited 0. The check is off in the tree that bootstrapped. |
| 3 | An extra drop of the conj source before the call, with the check on, did not print `20`/`99`/`25`. The native run was killed at 60 seconds. The interpreter printed the three numbers. The extra drop was reverted. |
| 4 | Not shown. `:c::rt-drop1` is an iterative walk of one pointer field and stops below a page, but `:c::emit-drop` does not call it. Wiring it to every one-pointer record followed string bytes and `reader` did not finish. A `let` cannot name a cell in its own initialiser, so a 100,000-deep `Cons` has no terminator in this language's `let`. |
| 5 | `drop-conj` agrees, which is the value half: a copying `conj` of a name that is still live does not change that name's later length. The count returning to 1 and the next `conj` growing in place was not measured separately from the value. |
| 6 | Bootstrap reached a fixpoint at 319,048 bytes (`stage1 == stage2`, 102 binaries byte-identical, stage 1 in 1,249 ms, 691× the interpreter). `tools/elf-run.sh` then exited 0: 103 native binaries, 54 agree, `reads: ok`, `copies: ok`, `rules: 0`, `types: 0`. The first `verify.sh` of this tree stopped in elf-run because `:c::count-hex` had 3 callers and the gate expected 2. `tools/reads.sh` now expects 3: `:c::share`, `:c::read-out`, and the copying `conj`. |
| 7 | The decrement is `:c::dec-hex` (`48ff48f8`), emitted only from `:c::drop-hex`. Callers go through `:c::emit-drop`. |
| 8 | `tools/bench-coll.sh` was not run. |
| 9 | Not measured. The self-hosting compiler grew from 304,181 bytes to 319,048. That is size, not the instruction count. |

## What the drop does

`:c::drop-hex` decrements `[rax-8]`. A count of zero is a literal and is skipped. A value outside the bump (`r14` .. `r15`) is skipped: a negative register and a code address both faulted stage 1 before this guard (`cmp [rax-8], 0` at `rax = -691`, then a write into the text at `0x40028e`). A check build compares the count with 1 and executes `ud2` when it is already below one. `:c::drop-check?` is false.

A copying `conj` of a name that is not linear increments that name, then drops the source after `vec_conj`. A linear name is not incremented and is not dropped there; `vec_conj_own` may extend it. `(length <temporary>)` drops the temporary after the load. A discarded `concat`, `subs`, `conj`, `assoc`, or `to-string` is dropped. An unused `let` binding whose type is a pointer is dropped. A self tail call drops a pointer parameter the call does not mention.

`assoc` and `concat` do not yet drop their source on the copy path. A `match` scrutinee is not dropped at arm entry. A closure's captures are not dropped with the closure. `:c::emit`'s `assoc` on `:c::Out` was not remeasured, so it is not known whether it now takes `rt-slot-set-own`.

## D4 and D6

A zero count does not give bytes back to `r15`. The region release is unchanged: a non-final statement still restores the bump, and that rewind does not decrement a reference the statement held into an older object. Those counts stay high. Memory the region does not cover is not freed when its count hits zero.

## Emission

`tools/emitted.sh check` reports 30 of 100 programs moved and 0 new. They are the programs that conj, concat, or discard an allocating form (`pvec`, `vectors`, `strings`, `reader`, `freed`, `linear`, and the rest of that list). `arith` is not among them. The manifest was not adopted.

## Re-strike (3a) — 2026-09-27

The heap-range guard is gone from `:c::drop-hex`. The `-691` and `0x40028e` values were not pointer-typed residents of the text or of a negative register. They were stale loads: a let binding in `r8`–`r11` reloaded after a call reused the register, and a stack binding reloaded with the raw frame displacement instead of `:c::fp`. A register let is spilled to its frame slot when it is bound. A pointer parameter that lives in a register is spilled past the let slots on entry to the body, which is also where a tail back edge lands. A drop reloads that slot. A count of 0 is still skipped by the literal guard. Nothing in this strike is a pointer that legitimately lives outside the heap except that literal.

Placements added, on top of the ones already credited:

- A name's last *textual* occurrence is recorded once per function. Asking `:c::live-after` at every share did not finish stage 0 in 40 minutes. A drop at the textual last occurrence is later than the last use on a path that stopped earlier, which leaks, and is not earlier.
- A copying `assoc` and a copying `concat` increment a named source that is not linear, then drop that extra, and drop the binding too when the occurrence is the textual last. Same shape as copying `conj`.
- A `match` subject is shared unless that occurrence is the textual last. Each arm drops it after the fields are counted out, except tier 1, where the payload *is* the subject and the binding holds it.
- An `if` arm drops a pointer name the other arm uses, when that name's last occurrence is inside the `if`.
- An unused pointer parameter is dropped on the way to `ret`, and the return value in `rax` is kept. The first check-on stage 1 segfaulted because that drop loaded the parameter over the value about to be returned.
- A read-only parameter is not dropped at a nested `nth` or `length`. Its tail pass-through does not increment, so a drop there frees the object the next iteration still holds. `user/sum` in `drop-sum` is that shape: the check executed `ud2` until the read-only exception.

`:c::count-hex` now has 6 call sites: `:c::share`, `:c::read-out`, copying `conj`, copying `concat`, and copying `assoc` twice (the register form and the stack form). `tools/reads.sh` expects 6. Closures' captures and giving bytes back to the bump are still 3b. The region release is unchanged.

The early-drop mutant is a count taken from 2 to 1. That is not an underflow, so `ud2` does not run. The following in-place growth is legal for a count of 1 and mutates an object another name still holds; the walk then does not return, and the 60-second kill is that hang. A check of the count cannot tell this from a real release of one holder. A fixture of the bug would be that mutant, and it is not in the tree. `drop-conj` is the fixture that stays agreed when the source is not dropped early: `20`, `99`, `25`.

Probes with `:c::drop-check?` true, via `tools/probe.sh`: `drop-len`, `drop-shadow`, `drop-conj`, `drop-tail`, `drop-arm`, `drop-sum`, `drop-twice`, `drop-ret`, `pvec`, `vectors`, `strings` agree with the interpreter. `pvec` includes `9|9|3`.

`tools/verify.sh` does not pass. With the check on, stage 0 produced a 374,079-byte compiler and stage 1 did not finish (`asm::fits?` failed; an earlier build of the same tree segfaulted in `nth` before the return-value drop preserved `rax`). With the check off, stage 0 produced a 359,418-byte compiler and stage 1 stopped in the same assert: `fits?` was given `n = 0xffff8017499e8e06` and width 4. That is not a displacement. elf-run was not run. `:c::drop-check?` in the tree is false. Nothing was committed. The bench was not run.

## Round 2 — 2026-09-27

`:c::eval-seq` is the evaluation order the code generator emits. An indirect call evaluates its arguments, then its head. The head is loaded into `rax` and called with `call [rax]`, so evaluating the head first would lose it to the next argument. A computed head, and a symbol that is neither an operator nor a top-level function, is in that sequence after the arguments. `:c::last-walk` walks a list in this order. `:c::live-after` already asks `:c::eval-seq`. `:c::last-use?` answers the drop question and stays false on a doubt, and when the `last` class is off. In-place mutation asks `:c::live-after`, where an extra successor only declines the mutation. `elf/probe/drop-head.wat`, the form `(f (user/call f 7))`, prints `7` under the interpreter. That order left stage 1 red: the compiler was 361,043 bytes and stage 1 still stopped in `asm::fits?` with the same width-4 assert.

`:c::drop-on?` is one switch per class. Stage 1 here means the compiled compiler compiling itself.

| class | stage 1 |
| --- | --- |
| all off | pass, 338,519 bytes, 1s |
| temp | pass, 339,226 bytes, 2s |
| discard | pass, 338,519 bytes, 2s |
| last | pass, 335,102 bytes, 2s |
| match | pass, 338,629 bytes, 2s |
| if | pass, 351,603 bytes, 1s |
| ret | pass, 338,577 bytes, 2s |
| tail | pass, 338,519 bytes, 2s |
| let | pass, 338,555 bytes, 2s |
| copy | SIGSEGV after 99s, 341,000 bytes |
| all on, before the fix below | SIGSEGV after 308s, 352,038 bytes, in the vector walk on a null node |

Inside `copy`, `conj` passes (338,812 bytes, 1s) and `assoc` passes (339,175 bytes, 2s). `concat` is the SIGSEGV (339,643 bytes, 97s). The halving by function name was not run. The path is the emitter, and every function that concatenates a non-linear string takes it.

Copying `concat` saved the first argument with a raw `push rax` and restored it in `:c::drop-saved` with a raw `pop`. Neither updated `:c::Out/sp`. The frame pointer is kept only for `clone`, so a local is addressed from `rsp`. Those eight bytes stayed live through `:c::cat-fold`, which evaluates the later arguments, and those loads were one slot off. `conj` and `assoc` push immediately before the call and pop immediately after, and nothing in that window addresses `rsp`. The push is now `:c::push` of 8 and the restoring pop is `:c::popn` of 8.

With that fix and every class on, the compiler compiles itself: 352,091 bytes, stage 1 in 1s.

`tools/verify.sh` with `:c::drop-check?` false reaches the fixpoint. Stage 0 wrote a 362,792-byte compiler in 1,098,469 ms (the tool counted 103 files in `elf/out`). Stage 1 did the same work in 1,974 ms. 102 binaries were byte-identical. Stage 1 equals stage 2 at 362,792 bytes. elf-run exited 0: 103 native binaries, 54 agree, `reads: ok`, `copies: ok`, `rules: 0`, `types: 0`.

`tools/emitted.sh check` reports 84 of 100 programs moved and 0 new. The manifest was not adopted. The 16 that stayed are `arith`, `divzero`, `dz`, `exit42`, `extremes`, `four`, `greet`, `grow2000`, `grow4000`, `grow8000`, `hello`, `onec`, `one`, `overflow`, `ovf`, and `thread`. They do not drop a heap value and do not copying-concat. The 84 moved because a drop was emitted, or a copying concat now counts the saved source in the stack depth, which changes the rsp-relative displacement of every later local.

`:c::drop-on?` is still in the tree, every class `true`. `:c::drop-check?` in the tree is false.

The same source with `:c::drop-check?` true, built in a sandbox whose `elf/out` started empty, wrote a 377,543-byte compiler (92 binaries). Stage 1 died with SIGILL on the check's `ud2`. At the fault, `rax` was a heap pointer and `[rax-8]` was 0. The surrounding instructions increment one argument, call, and then drop a different stack slot. elf-run was not run on that build. The check-off fixpoint does not see this decrement. Nothing was committed. The bench was not run. Closures and giving bytes back to the bump are still 3b.

## Round 3 — 2026-09-28

**R6 — the double drop, found at its root.** Reproduced the round-2 crash in a fresh sandbox
(`/tmp/stone3a-r3-checkon`, this tree with only `:c::drop-check?` flipped true, built by the
interpreter): stage 1 dies with `ud2` at the same shape. Under gdb (`/tmp/stone3a-r3-gdb.log`),
the fault is inside a repeated pattern that decodes to `(:wat::core::assoc EXPR :sp ...)` --
`mov $4,%rcx` (field index 4) and `movabs $0x78e,%r11` (`:c::Out`'s pointer-field mask: fields
1,2,3,7,8,9,10 set = 0x78e) name `:c::Out`'s `:sp` field exactly, and the immediately preceding
`add`/`sub 0x30(%rsp),%rax; jo` pair is `:c::push`/`:c::popn`'s own bodies
(`elf/compile.wat:314-317`, unchanged): `(:wat::core::assoc (:c::emit o hex) :sp (+ or - sp n))`.
The box being assoc'd, `(:c::emit o hex)`, is a compound EXPRESSION, not a symbol.

The root, in `:c::assoc-form` (`elf/compile.wat:4696-4741`, and the identical shape in
`:c::conj-form`, `elf/compile.wat:2705-2745`): the INCREMENT that protects a still-live named
source is gated on `(:wat::core::and sym? (:wat::core::not own?))` -- correctly nothing for a
non-symbol box, since a fresh expression result already carries exactly the one reference its
evaluation produced. But the matching DROP after the call was gated on `own?` ALONE (`(if own?
called (:c::drop-saved ...))`), which is true whenever `sym?` is false too -- so every
`(:wat::core::assoc EXPR :field val)` on a non-symbol `EXPR` decremented a reference that was
never incremented, an unconditional double drop wherever this compiler's own source (or any
compiled program) chains an `assoc`/`conj` directly onto a call result rather than a `let`-bound
name. `:c::push` and `:c::popn` are exactly this shape, called thousands of times, which is why
stage 1 died compiling `elf/compile.wat` itself specifically.

**Fix**: both sites now gate the extra push-before-the-call and the trailing `:c::drop-saved`
on the SAME condition as the increment (`extra? = sym? && not own?`), dropping only when a
reference was actually taken. The runtime-routine choice (`:at-slot-own` vs `:at-slot`,
`:at-vconj-own` vs `:at-vconj`) is unchanged -- still gated on `own?` alone, since that question
(may this mutate in place) is independent of whether the source was a name.

D5, the check as ONE command: `:c::drop-check?` (`elf/compile.wat:4180`) is already exactly
this -- an environment-shaped compile-time switch, off by default, no source edit needed to
flip it for a gate run (only a one-line `sed`, as this strike and round 2 both did). It was not
converted to read an actual environment variable in this round; say so plainly, since D5's own
text calls for "an environment switch" and this is a compile-time constant toggled by editing
the one-line function body, not `getenv`. Whether that distinction matters was not settled here.

**Verification, still running when this was written**: three interpreter builds were started in
parallel and had not finished: (1) `tools/verify.sh` on the real tree with the check off
(`/tmp/stone3a-r3-verify-main.log`), (2) a fresh sandbox (`/tmp/stone3a-r3-checkon-fixed`) with
the fix AND `:c::drop-check?` true, built from empty via the interpreter
(`/tmp/stone3a-r3-checkon-fixed-stage0.log`), to confirm stage 1 no longer traps, and (3) a
function-address dump of the pre-fix source (`/tmp/stone3a-r3-addrmap.log`) meant to corroborate
the gdb reading independently. **None of the three had produced a final result before this
report was written.** The fix is argued from the disassembly and the source reading above, not
yet from a green check-on bootstrap or a zero-underflow corpus run. This is not a STOP -- the
root is traced to a specific placement defect with file:line and a mechanism, not an
unexplained underflow -- but the gate numbers this round's deliverable asks for (zero
underflows, `tools/verify.sh` ok) are NOT YET CONFIRMED and must be read from the three logs
above (or re-run) before this round is treated as landed.

**R7 — the rsp rule is now a gate.** Two more raw, untracked push/pop pairs, exactly the class
the copying `concat` fix (round 2) closed: `:c::drop-saved` (`elf/compile.wat:4520-4533`, was
`(:c::emit o "59504889c8")` -- a raw pop rcx / push rax / mov rax,rcx -- followed by a bare `"58"`
pop) and the `length` branch's drop (`elf/compile.wat:2605-2614`, was
`(:c::emit o1 "4889c1488b00504889c8")` with a bare closing `"58"`). Both were harmless today only
because nothing between the push and the pop addressed rsp -- the exact condition the `concat`
bug broke. Both now decompose into `:c::pop-rcx`/`:c::push-rax`/`:c::pop-rax` calls wrapped in
`:c::push`/`:c::popn`, byte-identical output, confirmed by a full byte-scan of every hex literal
in the file before and after (only the two targeted literals changed).

Climbed to the gate rung: `tools/rsp.sh` (new), in the shape of `tools/reads.sh`. It parses
`elf/compile.wat` into a real (comment- and string-aware, backslash-escape-aware) token tree,
finds every hex string literal that decodes to a push/pop-of-a-GPR opcode byte (0x50-0x5f), and
fails unless that literal is lexically inside a `(:c::push ...)` or `(:c::popn ...)` form --
tracking nesting through parens/brackets/braces and through `:wat::string::concat`, not just
"same line". One named, counted exception: the function prologue's own `push rbp`
(`elf/compile.wat:7065` at the time of writing, looked up by grep so it tracks if the line
moves), which runs before `:c::Out/sp` starts counting and is accounted for through `:c::fk`
instead; its matching `pop rbp` is folded into `leave` (`"c9"`, not in the flagged byte range).
Wired into `tools/elf-run.sh` right after `tools/copies.sh`. Proved the gate: planted the OLD
raw `:c::drop-saved` body as a mutant, ran `tools/rsp.sh`, got `FAIL -- ... a raw push/pop byte
... does not reach :c::push/:c::popn` at the mutated line, then reverted and confirmed green
again. `tools/rsp.sh` passes on the tree as fixed for R6 too.

**R8 — `:c::drop-on?` no longer exists.** All nine classes (`temp discard last copy match if
ret tail let`) were `true` in every shipped build; the `(:else false)` catch-all a typo could
reach was live but never actually exercised. Chose to remove the switches from the tree rather
than close the set, per the option WEIGH's round-2 text already named ("keep the switches out
of the final tree"): they were round-2's bisection tooling, that bisection is done, and D5
already gives a real, permanent, similarly-shaped compile-time switch for the one check this
stone still needs live. Every one of the 14 call sites was simplified algebraically to what it
reduces to with every class `true` (e.g. `(:wat::core::and (:c::drop-on? "copy") X)` -> `X`;
`(:wat::core::or own? (:wat::core::not (:c::drop-on? "copy")))` -> `own?`), and
`:c::drop-on?`'s definition deleted. Verified with `tools/bootstrap.sh --fast`: fixpoint reached,
compiler 361,259 bytes (down from 362,792 -- the dead per-class branching cost real bytes), all
102 other binaries byte-identical to before the removal.

**Numbers actually in hand at the time of writing**: `tools/rsp.sh` and `tools/reads.sh` both
`ok` on the fixed source (source-only checks, fast). `tools/bootstrap.sh --fast` after R7+R8
alone (before the R6 fix) reached a fixpoint at 361,259 bytes with all other binaries
byte-identical. `tools/bootstrap.sh --fast` after the R6 fix was ALSO applied reported 7 of 102
binaries DIFFER against the stale seed (`compiler.elf count-vec.elf fn-share.elf fnvec.elf
fn-vecpass.elf matchval.elf pvec.elf`) and failed its own fixpoint check -- expected per
`--fast`'s own documented limitation (two generations from a stale, pre-fix seed cannot show a
real codegen change has converged; only the interpreter-seeded full bootstrap can). The full,
non-`--fast` `tools/verify.sh` and the check-on corpus run are the pending (1) and (2) above.
Compiler size, fixpoint byte count, underflow count, and `tools/emitted.sh check`'s move count
for this round are NOT reported here because the runs that produce them had not finished.
Nothing was committed.

## Round 4 — 2026-09-28

**R9 — the root round 3 named (F-208's class again) is fixed at the evaluation-order
definition, not by re-tightening the drop's gate.**

1. Reverted round 3's R6 gate. `:c::conj-form` (`elf/compile.wat:2711` region, the fix at what
   is now line ~2737) and `:c::assoc-form` (`elf/compile.wat:4701` region, fix at ~4753) had
   gated the copy's post-call drop on `extra? = sym? && not own?` -- the same condition that
   gates the pre-call INCREMENT. That stopped dropping a non-symbol box (a temporary: `(mk 3)`
   in at1, `(user/emit o "ab")` in at3) even though D3 says a copying `conj`/`assoc`/`concat`
   takes ownership of its source and drops it once, always, when the copying (not `own?`)
   routine runs. Both sites, and `(:c::concat? head)`'s copy path (`elf/compile.wat:2564`, fix
   at ~2578, which had the identical unstated bug though round 3 never named it), now gate the
   push-for-later-drop and the post-call `:c::drop-saved` on `drop? = (not own?)`. The
   increment stays gated on `sym? && not own?` (unchanged) -- a fresh or already-counted
   non-symbol box needs no protective increment, only the one drop of its own reference.
   Because `own?` is defined as `sym? && linear?` for `conj`/`assoc` (always false for a
   non-symbol box) and `rm?` (the register-resident fast path in `:c::assoc-form`) implies
   `sym?` (`:c::remat?`), `drop?` agrees with the old `extra?` in every case that used to fire;
   it only newly fires for a non-symbol box.

2. `:c::eval-seq` (`elf/compile.wat:3805`) now has one more clause, mirroring the existing
   F-208 fix for an indirect call's head: when the head is a consuming built-in
   (`:c::write-head?` -- `conj`/`assoc`/`concat`) and the form has a box (kid 1), the box's
   node is placed LAST in the sequence -- after every other kid -- instead of first. This is
   where the generator actually uses it: box is pushed, the rest of the form is evaluated, then
   box is popped and handed to the runtime routine (`vec_conj`/`slot_set`/`str_cat`) that
   consumes it. `:c::last-walk` (which calls `:c::eval-seq` directly) and `:c::live-after`
   (via `:c::live-seq`, which also calls `:c::eval-seq`) both consult this, unchanged
   themselves -- no walk re-derives the order.

   How the two consumers read the change, and why each stays on its safe side (R5):
   - **Drop placement** (`:c::last-use?`, via `:c::Prog/lasts` built by `:c::last-walk`): if
     the box's name also occurs textually inside the form's other kids (`emit`'s
     `(:wat::core::assoc o :code (:wat::string::concat (:user::Out/code o) h))`, box=`o`
     occurring again inside the value), that inner occurrence is now recorded as happening
     BEFORE the box's own (now-last) occurrence, so it is correctly answered "not last" by
     `:c::last-use?` -- no early named-binding drop fires there. The box's own occurrence
     becomes the recorded last node for that name, so `(:c::last-use? box name pg)` at the
     call site (already how `conj-form`/`assoc-form`/`concat-form` decide `:c::drop-saved`'s
     `twice?`) now answers correctly. This can only make a drop happen LATER than before
     (never earlier): the only node whose position moved is the box's own, and it moved from
     first to last, so it can only newly count as "after" some other occurrence, never stop
     counting as "after" one it already was.
   - **In-place mutation** (`:c::linear?` / `:c::dead-after-write?`, via `:c::live-after`
     which shares the same `:c::eval-seq` call): the identical move means `:c::live-after`
     can only start answering `true` ("still live") in MORE cases than before for the box's
     own name (any `u` that used to sit after the box's old early position but before the
     value now sees the box's occurrence as coming after it too) -- never fewer. An extra
     "still live" only DECLINES a would-be `own?`/linear classification; it can never
     manufacture one that wasn't there, so mutation-in-place safety is unaffected in the
     unsafe direction. The cost, if any, is fewer names proven linear (fewer in-place
     mutations taken), not a wrong one taken.

3. Confirmed by inspection: `:c::write-head?` (`elf/compile.wat:3892`) is exactly
   `conj?`/`assoc?`/`concat?`, and `:c::drop-saved` (three call sites total, grepped) is
   called only from these three forms. No other consuming built-in evaluates a box, then its
   arguments, then calls.

4. `probe-3a-at{1,3,4,5}.wat` copied into `elf/probe/` as `drop-at1.wat` .. `drop-at5.wat`
   (numbering kept). All four, on `tools/probe.sh`, agree with the interpreter -- both with
   `WAT_DROP_CHECK` unset and with it set to `1` (see R10):

   | probe | check off | check on |
   |---|---|---|
   | drop-at1 | agree `5\|"3"` | agree `5\|"3"` |
   | drop-at3 | agree `1\|"ababab"` | agree `1\|"ababab"` |
   | drop-at4 | agree `8\|"xab"\|0\|"x"` | agree `8\|"xab"\|0\|"x"` |
   | drop-at5 | agree `8\|"xab"\|"x"` | agree `8\|"xab"\|"x"` |

   at4 no longer prints the wrong `"xab"` for `o`'s code (it now agrees with the interpreter's
   `"x"`), and at5 no longer hangs, under the check either way. The previously-passing probes
   (`drop-len`, `drop-shadow`, `drop-conj`, `drop-tail`, `drop-arm`, `drop-sum`, `drop-twice`,
   `drop-ret`, `drop-head`) and the three corpus programs `pvec`, `vectors`, `strings` were
   re-run in a `/tmp` sandbox with both R9 fixes and R10's switch in place, check on and off:
   all still agree (no regression). `tools/rsp.sh` and `tools/reads.sh` both report `ok` on the
   real tree with these changes (`reads.sh`'s six `:c::count-hex` call sites are unchanged by
   this round -- only the gating booleans around them changed, not their count).

**R10 — the check became a real environment switch, `WAT_DROP_CHECK`.**
`:c::drop-check?` (`elf/compile.wat:4207`) no longer returns a hardcoded constant. It now reads
`/proc/self/environ` through `:wat::io::read-file` -- the same primitive this compiler already
uses to read its own source, so it needs no new runtime plumbing -- and asks
`:wat::string::contains?` whether it holds the literal substring `"WAT_DROP_CHECK=1"`. This
answers correctly on every stage: the interpreter's own process has an environ, and so does
every compiled stage (stage 1 compiling stage 2, etc.), each inheriting whatever environment
launched it, with no explicit propagation needed. `:c::rt-slurp` (the routine behind
`:c::rt-io-read-file`) already loops on `read` until it returns nothing rather than trusting
`stat`'s reported size, which matters here specifically because procfs files report size zero;
a size-trusting reader would silently see the switch as always off. Confirmed NOT a no-op: the
same probe source (`drop-at1.wat`) compiled twice, once with `WAT_DROP_CHECK` unset and once
with it set to `1`, produced ELF binaries of different size (3491 vs 3509 bytes) and a
byte-scan for the `ud2` opcode (`0f0b`) found 0 occurrences unset and 2 occurrences set. Off is
still the default (an unset variable, or one not exactly `WAT_DROP_CHECK=1`, leaves `contains?`
false). The initial-stack `envp` (argv/argc/envp at `_start`) was NOT used -- this compiler's
entry stub does not capture the incoming `rsp` for that purpose, and reading `/proc/self/environ`
needed no change to it.

**Verification status at the time this was written.** Three long-running checks were started
in parallel and had NOT finished when this executor's session was ended and this report was
forced:

1. `tools/verify.sh` on the REAL tree with the check off (default, `WAT_DROP_CHECK` unset) --
   `/tmp/stone3a-r4/real-verify-off.log`, still in "stage 0: the interpreter runs the
   compiler" when last read.
2. A `/tmp` sandbox (`/tmp/stone3a-r4/dev`, a full copy of this tree with the R9+R10 source
   changes applied) running `tools/bootstrap.sh` (the full, non-`--fast` chain) with the check
   off -- `/tmp/stone3a-r4/bootstrap-off.log`, also still in stage 0.
3. A second `/tmp` sandbox (`/tmp/stone3a-r4/checkon`, an identical copy) running
   `tools/bootstrap.sh` with `WAT_DROP_CHECK=1` in its environment -- confirming the check-on
   path reaches its OWN fixpoint (not just that individual probes agree) --
   `/tmp/stone3a-r4/bootstrap-on.log`, also still in stage 0.

**None of the three had produced a final result.** This round's required landing numbers --
`tools/verify.sh`'s two final lines (check off and check on), the compiler's size at the
fixpoint, the underflow count over the whole corpus + bootstrap under the check, and
`tools/emitted.sh check`'s move count and explanation -- are NOT available and are not
reported here. What IS confirmed, from the interpreter-driven probes above (which compile the
same way `tools/verify.sh`'s stage 0 does, just for one program at a time): both R9 fixes
individually correct the exact wrong-value (at4) and hang (at5) failures round 3 left, under
the check, without regressing any previously-agreeing probe or corpus program tried; and R10's
switch is a real, verified-by-byte-scan environment toggle, not a source edit. This is not a
STOP -- no probe failed for an unexplained reason, no in-place-mutation safety argument could
not be stated, and no trap was seen that could not be traced to a placement -- but the actual
gate runs this round's deliverable asks for (a clean `verify: ok` both ways, zero `ud2`, the
fixpoint byte count, the emitted-move explanation) are UNCONFIRMED and must be read from the
three logs above (or re-run to completion) before this round is treated as landed. Nothing was
committed; the tree is left dirty with the R9 and R10 source changes plus the four new probe
files (`elf/probe/drop-at1.wat` .. `drop-at5.wat`).

## Round 5 — 2026-09-28

**R11 — done.** The environment is read once. `:c::Prog` gained a field, `dchk <-
:wat::core::bool` (`elf/compile.wat:1207-1210`), set from `(:c::drop-check?)` in `:c::empty-prog`
(`elf/compile.wat:1275`, called exactly once per compile — confirmed the only call site). `:c::drop-hex`
(`elf/compile.wat:4239`) now reads `(:c::Prog/dchk pg)` instead of calling `:c::drop-check?` itself.
`:c::drop-check?` also now matches the WHOLE NUL-separated environ entry, not a substring:
`:c::envvar-set?` (`elf/compile.wat:4212-4222`, new) scans `/proc/self/environ` byte-by-byte for `\0`
boundaries and compares each entry for EQUALITY against `"WAT_DROP_CHECK=1"`. Round 5's own finding —
`contains?` wrongly matched `XWAT_DROP_CHECK=1` and `WAT_DROP_CHECK=10` — is fixed: probed directly
(`/tmp` sandbox, native compile of `elf/probe/drop-at1.wat`) with `WAT_DROP_CHECK=1` (exact) → 2 `ud2` in
the output; with `WAT_DROP_CHECK=10` or `XWAT_DROP_CHECK=1` set → 0 `ud2`, same 3491-byte output as
unset. Stage 1 time, one sample each, same machine: round 5's own regression (before R11) was 3,220 ms;
after R11 (and after R12's revert below, so this is the final tree) it is **1,725 ms** — better than
round 3's original pre-check baseline of 1,974 ms, and far below round 5's 3,220 ms. Fixpoint at
367,987 bytes, check off (see the real-tree gate below).

**R12 — NOT landed. STOP: the root is not traced.** The crash the WEIGH names (`rip 0x4398d7`,
`[rax-8] = 0`) was traced to its exact source: the function is `:c::seq` (`elf/compile.wat:5604-5621`,
the sequencing walk — "a sequence of forms; the last one's value is the value of the whole, and every
form before it gives its allocations back"), a self-tail-recursive function of nine parameters `[ks i o
env pg rt tb slot tc]`. Confirmed by an address map (a driver compiling `elf/compile.wat` through
`:c::place` and printing `:c::Fn/name`/`:c::Fn/addr`, matched against a disassembly of the check-on
stage-0 binary): `:c::seq` occupies exactly the range containing the trap address, and its compiled
prologue (`sub $0x80,%rsp; push rbx,r12,r13,rbp; mov 0xe8/0xe0/0xd8/0xd0(%rsp)→rbx,r12,r13,rbp`) matches
the WEIGH's own description byte for byte. The base-case arm (`i >= (length ks)`, taken when the `jl`
to the recursive arm is NOT taken) drops **five** stack-resident values in a row, not three as the
first sighting described (the first three, at `0xb0`/`0xc8`/`0xd0(%rsp)`, are what the check-on `ud2`
reaches before the process dies; two more follow, at `0x50(%rsp)` and `0x68(%rsp)`, which is where `r13`
and (past the frame) a further parameter were spilled). All five are `:c::seq`'s own parameters `ks`,
`env`, `pg`, `rt`, `tc` — the ones its base case (`(if (>= i (length ks)) o (let [...] (:c::seq ...)))`)
never mentions, because the `then` arm is bare `o`; the `:c::arm-dead?`/`:c::drop-arm` machinery (`a
name dead in one if arm`) sees they occur only in the sibling (recursive) arm and drops them here.

Two hypotheses were tested and BOTH refuted:

1. **Displacement defect (the round-2 class).** Refuted by inspection: `0xb0`/`0xc8`/`0xd0`/`0x50`/`0x68`
   are not garbled offsets. `0x50` and `0x48`(spilled, not dropped — see below) are exactly where `r13`
   and `rbp` were spilled two instructions after entry (`mov %r13,%rax; mov %rax,0x50(%rsp)`); the drop
   reloads the SAME slot the spill wrote, same mechanism as every other drop in this tree. The three
   `0xb0`/`0xc8`/`0xd0` slots are the CALLER's stack-passed argument slots (this function takes its
   parameters on the stack, `na = 0`), reloaded directly rather than through the spill copies — also
   consistent, not garbled. The values read at each site are the right pointers (`ks`, `pg`, `rt` etc.,
   confirmed by which function occupies this address range and which parameters it declares). This is
   not a displacement bug.
2. **A read-only parameter needs the same exemption `:c::drop-if-last` already has.** `:c::drop-if-last`
   (`elf/compile.wat:4423-4432`) already declines to drop a name that is `:c::ronly?` — a parameter whose
   ONLY uses, throughout the whole function, are `(nth name i)`, `(length name)`, or passing itself
   unchanged at the same slot in a self-tail-call (`:c::read-only-all?`, `elf/compile.wat:3977-4018`).
   `:c::arm-dead?`/`:c::drop-arm` (`elf/compile.wat:4522-4550`) have no such exemption, and `:c::seq`'s
   `ks`/`env`/`pg`/`rt`/`tc` are passed through unchanged on every recursive call — the same shape. A fix
   adding `(:wat::core::not (:c::ronly? pg name 0))` to both predicates was written and probed (all
   fourteen `elf/probe/drop-*.wat` probes agree, both check off and on; a new fixture,
   `elf/probe/drop-arm2.wat` — a self-tail-recursive walker whose last parameter is a read-only record the
   caller keeps using after the walk returns — also agrees, both ways). **This hypothesis is FALSE**:
   `:c::seq` passes `ks`/`env`/`pg`/`rt`/`tc` to `:c::expr`/`:c::releasable?`/`:c::discard-ptr?` as
   ordinary call arguments, not only through `nth`/`length`/self-pass-through, so
   `:c::read-only-all?`'s generic clause (a bare mention of the name anywhere else RETAINS) already marks
   every one of the five names NOT read-only. Confirmed by disassembly: with the fix in the tree,
   `:c::seq`'s compiled base case is BYTE-IDENTICAL to without it — `:c::ronly?` already answers false
   for all five, so the added conjunct never fires here. It was reverted (`elf/compile.wat`'s
   `:c::arm-dead?`/`:c::drop-arm` are back to their round-4 shape) rather than left as inert, misleadingly
   commented code; `elf/probe/drop-arm2.wat` was kept (a real, currently-passing probe of the read-only
   tail-recursive-context shape, both ways) since it does no harm and may be useful later, but it does
   **not** reproduce this crash — say so plainly, it was written under the now-refuted hypothesis.

**The crash is real and reproduces on a clean, from-scratch pipeline** — not an artifact of a stale seed
or a leftover sandbox. Three independent stage-0(interpreter)→stage-1(native) runs from the fixed source
all crash the same way: the original `/tmp/stone3a-r4/checkon` capture (round 5's own, `rip 0x4398d7`), a
full from-scratch sandbox rebuild (round 5 executor's own, `rip 0x439a27`), and the REAL TREE's own
`WAT_DROP_CHECK=1 tools/verify.sh` run (below, `rip 0x4392bd`). All three addresses fall in the same
instruction shape at the same offset from `:c::seq`'s own entry; they differ only because each build's
total byte count differs slightly. **What was NOT resolved**: why the FIRST successful compile of
`elf/compile.wat` by a freshly-built check-on native compiler (stage 0→stage 1, inside one
`tools/bootstrap.sh` run) reaches a clean, self-reproducing fixpoint with zero traps, while a SECOND,
independent invocation of that exact same binary (copied, same source, same or a different environment)
on the exact same task reliably traps or hangs. This was observed directly: a copy of a
freshly-fixpointed check-on `compiler.elf`, re-run by hand on its own unchanged source, crashed or hung
every time (`/proc/<pid>/io` showed billions of bytes passed to `write()` with the target file never
growing — not the runaway-allocation it first looked like from `VSZ`, which is a fixed ~93 GiB reservation
seen on unrelated healthy processes too). Whatever is happening on a REPEAT invocation was not chased
down; it may be a separate defect (a bug that manifests only when compiling INTO a tree that already
holds THAT SAME output) or the same one manifesting more reliably under it. `tools/verify.sh` itself
only ever invokes stage 1 ONCE per run, matching the pattern that failed cleanly (a single, well-defined
`ud2`), not the repeat-invocation hang — so the number below is the real gate's own result, not an
artifact of my extra manual reruns.

A candidate lead for the next round, NOT confirmed: `:c::compile-fn` (`elf/compile.wat:~7150-7210`)
shadows its own `pg` parameter — `pg (:wat::core::assoc (:wat::core::assoc ... pg ...) ...)`, ten
nested `assoc`s reusing the name `pg` for a new, derived value — before calling `:c::seq` with the
shadowed `pg`. `:c::last-walk`/`:c::occ` are explicitly NAME-based, not scope-based (confirmed by
reading `:c::last-note`/`:c::last-put`: they record "the last node with this TEXT", with no notion of
which `let` bound it) — the exact class the "shadowed name" fixture (`drop-shadow.wat`) exists to probe,
but that fixture is a simple single-shadow case, not "a function's OWN parameter shadowed then handed to
a self-tail-recursive callee that separately owns an identically-named parameter". Whether this
interacts with `:c::seq`'s bookkeeping was not established either way in the time available — reported
as a lead, not a finding.

**STOP.** Per the WEIGH's own trigger: the trap's root cannot be traced to a placement or displacement
defect with the confidence the earlier rounds' fixes had. Both hypotheses this round tested are refuted;
what remains is one unconfirmed lead. `WAT_DROP_CHECK=1 tools/verify.sh` does not land this round.

**R13 — done, proven.** `tools/bootstrap.sh` sourced `tools/sums.sh` and removed the stamp
(`rm -f "$STAMP"`) only after stage 0 (or the `--fast` seed run) had already rewritten `elf/out`
(originally right before `tools/gen-refuse.sh`, well after both branches of the stage-0
`if`/`else`). Moved both lines to immediately after `ms ()`'s definition, before the `if [ -n
"$FAST" ]` branch — so the stamp is gone before ANY write into `elf/out`, `--fast` or not. Proved
with the exact mutant the WEIGH names: in a sandbox with a valid stamp (`buildsum` written
directly, matching the unchanged source), a `tools/bootstrap.sh` run was killed (`kill -9` on the
interpreter) partway through stage 0. With the OLD (git `HEAD`) placement, the stamp survived the
kill untouched, and `SKIP_BUILD=1 tools/elf-run.sh` WRONGLY ACCEPTED the half-rewritten
`elf/out/` (`elf-run: SKIP_BUILD=1 on the bootstrap-verified build (ad51cc5d...)`). With the FIXED
placement, the identical kill left NO stamp, and the same command correctly REFUSED (`elf-run:
REFUSED -- SKIP_BUILD=1 but elf/out/ is not the verified build of this tree (no stamp vs
ad51cc5d...)`).

**The real-tree gates.**

- `tools/verify.sh` (check off): **`verify: ok`**. Two full runs from empty-ish `elf/out` both
  reached a fixpoint (`stage1 == stage2, byte for byte`) and `elf-run: ok`/`rules: 0
  conflicts`/`types: 0 conflicts`. The first (with R12's since-reverted `ronly?` addition still in
  the tree) fixpointed at 366,308 bytes; the final tree (R12 reverted) fixpoints at **367,987
  bytes**, stage 1 in 1,725 ms (524× the interpreter, which took 905,118 ms / ~15.1 min for the
  103-program corpus). The two `ronly?`-conjunct runs differing by 1,679 bytes despite the crash
  site being byte-identical either way means the conjunct DID change output somewhere else in the
  compiler (not investigated — the addition was already reverted by the time this was noticed);
  see R12 above for why it was reverted regardless.
- `WAT_DROP_CHECK=1 tools/verify.sh`: **FAILS.** Stage 0 (interpreted) succeeds, writing a
  382,652-byte check-on compiler. Stage 1 (that compiler, native, compiling everything again)
  dies on `ud2` — `rip 0x4392bd`, the same `:c::seq` base-case shape as above.
  `bootstrap: bootstrap FAILED (exit 1) -- elf-run not run`. This is the R12 STOP's direct
  consequence; the corpus-wide underflow count this round's deliverable asks for was not obtained
  because the run does not reach `elf-run.sh`.

**Probes.** All fourteen `elf/probe/drop-*.wat` fixtures — `drop-arm`, `drop-arm2` (new this
round), `drop-at1`, `drop-at3`, `drop-at4`, `drop-at5`, `drop-conj`, `drop-head`, `drop-len`,
`drop-ret`, `drop-shadow`, `drop-sum`, `drop-tail`, `drop-twice` — agree with the interpreter via
`tools/probe.sh`, check off AND on (`WAT_DROP_CHECK=1`). `elf/probe/drop-cons.wat` (present in the
tree, untracked, not created this round) is excluded: `user/seed` there is unconditionally
self-recursive with no base case (`(:user::Cell :k -1 :nxt (user/seed))`), so it cannot terminate
under either the interpreter or the native compiler; it predates this round (D1's recursive-drop
fixture, out of scope — 3b) and is not part of this round's gate.

**`tools/emitted.sh check`**: 84 of 100 programs moved, 0 new — identical to round 2's own number.
Nothing in R11 or R13 changes what a check-off build emits for the corpus (R11 only moves WHEN the
environment is read, not what a check-off build does with the answer; R13 only changes
`tools/bootstrap.sh`'s own stamp timing). R12 was reverted to its round-4 shape, so it also emits
what round 4 emitted. The 84/100 move is round 2's own, already-explained number (conj/concat/copy
paths and drops now counted in the stack depth), not something this round changed further.

**Underflow count.** Zero across: the whole corpus and every `elf/probe/drop-*.wat` (excluding
`drop-cons.wat`, out of scope) under `tools/probe.sh` with `WAT_DROP_CHECK=1`, check-off
`tools/verify.sh`'s full run (no check compiled in — not applicable), and stage 0 of the check-on
`tools/verify.sh` run (the interpreted compile that WROTE the check-on binary). Exactly ONE
underflow was observed this round: stage 1 of the check-on run, `:c::seq`'s base case, the same
site every time. The corpus-wide check-on count (compiling every corpus program, not just
`elf/compile.wat`, under the check) was not obtained because that requires `elf-run.sh`, which the
failed bootstrap never reaches.

**Left in the tree, uncommitted:** R11's `:c::Prog/dchk` field and `:c::envvar-set?`/updated
`:c::drop-check?`/`:c::drop-hex` (elf/compile.wat); R13's reordered `tools/bootstrap.sh`;
`elf/probe/drop-arm2.wat` (new, agrees, does not reproduce the R12 crash). `:c::arm-dead?` and
`:c::drop-arm` are back to their round-4 bytes (the tried-and-refuted `ronly?` conjunct removed).
Nothing committed.

## Round 6 -- 2026-09-28

**R14 -- bisected by function, in sandboxes only; converges to `:c::seq` alone at step 1.**

Method, per the WEIGH: `elf/out/compiler.elf` (the real tree's proven check-off build,
367,987 bytes) copied into a sandbox (`/tmp/stone3a-r6/b1`, deleted at the end of this round) as
the `--fast` seed. `:c::emit-drop` (`elf/compile.wat:4386`, the single funnel every drop call
site passes through -- 2621, 4407, 4576, 4578, 5003, 5631) was restricted, in the SANDBOX source
only, to a hardcoded set of function names keyed on `(:c::Prog/cur pg)`:

```
(:wat::core::defn :c::r14-allowed? [name] -> bool (= name ":c::seq"))
(:wat::core::defn :c::emit-drop [t o pg rt] -> :c::Out
  (if (:c::r14-allowed? (:c::Prog/cur pg)) (:c::emit o (:c::drop-hex t pg)) o))
```

Caught directly: the sandbox's `--fast` SEED RUN overwrites `elf/out/compiler.elf` with a
check-on build even when stage 1 later traps and the overall bootstrap fails -- the first
attempt silently reused this polluted seed for the next step until the byte count in stage 0's
own log line was checked against the proven 367,987. Fixed by restoring `elf/out/` from a
pristine copy of the proven build before every step.

| step | set | result |
|---|---|---|
| 1 | `{:c::seq}` alone (nothing else in the whole compiler emits any drop) | **TRAP** -- `ud2`, confirmed under gdb at `0x439acb`, `decq -0x8(%rax)` immediately after: same shape as round 5's crash |

Step 1 converged: `:c::seq`'s own drops, with every other function's drops disabled, are
sufficient to reproduce the crash. No halving of the remaining ~917 functions was needed (the
WEIGH's "about ten builds" is an upper bound; this took one).

**Finer than the WEIGH asked, same infrastructure.** Round 5 found the base case
(`elf/compile.wat:5616`, via `:c::drop-arm` at `elf/compile.wat:4553`) drops five names at once:
`ks`, `env`, `pg`, `rt`, `tc`. With `cur=":c::seq"` still the only function allowed to emit any
drop, `:c::drop-arm`'s own call to `:c::drop-kept` was additionally gated on the dropped
binding's name (a second predicate, `:c::r14-name-ok?`), one name at a time:

| name alone (only drop site active in the whole corpus compile) | result |
|---|---|
| `ks` | TRAP |
| `env` | TRAP |
| `pg` | TRAP |
| `rt` | TRAP |
| `tc` | TRAP |

All five, independently, with nothing else dropping anywhere in the whole 103-program corpus
compile, reproduce the trap. This rules out a mismatch BETWEEN the five (one masking or
compensating for another): each one alone is already wrong. It points at something common to how
the base case treats a self-tail-recursive pass-through parameter, or a defect common to all
seven of `:c::seq`'s own call sites (`elf/compile.wat:2485, 5012, 5138, 5144, 5458, 5638, 7204`).

**STOP -- the root is not traced.** Per the round's own STOP condition. Reasoned through and
NOT confirmed (no sandbox test reached a mechanistic account of an UNDERFLOW, as opposed to a
leak, so nothing here was tried as a fix):

- `:c::compile-fn` (`elf/compile.wat:6998-7206`, the function that calls `:c::seq`) rebinds its
  OWN parameter `pg` under the SAME name partway through its body (`elf/compile.wat:7157`, a
  `let` binding named `pg` built from a chain of ten `assoc`s, shadowing the incoming parameter
  `pg`). `:c::last-walk`/`:c::occ` (`elf/compile.wat:3694-3705, 4301-4335`) are confirmed
  NAME-based, not scope-based, by direct reading of `:c::occ`'s `:else` clause (no `let` special
  case; a shadowed name is summed exactly like any other mention) -- this was an unconfirmed lead
  in round 5. Traced by hand: every "pg" occurrence AFTER the rebinding (`:ronly`, `tc`, `bound`,
  `o2`, and the final `do`, including the `:c::seq` call itself at line 7199) correctly finds its
  own true last occurrence at `:c::drop-unused-params`'s `pg` (line 7203), so the call to
  `:c::seq` is correctly treated as a non-last use (a share, not a move) -- no bug traced on that
  path. The ORIGINAL parameter's true final use (line 7167, fed into the first `assoc`) IS
  wrongly marked non-last (later "pg" mentions exist in text, though they are the rebound value)
  -- a real, traceable defect (an unnecessary share forcing `assoc` to copy instead of mutate in
  place, and an orphaned reference on the original object), but it predicts a LEAK, not the
  observed underflow, so it was not pursued further as this round's root. Reported as a firmer
  lead for round 7 than round 5 left it, not as a finding.
- A per-iteration hand-count of `:c::seq`'s own loop body was attempted: each pass-through
  parameter is used at least once as an ordinary, non-last call argument (to
  `:c::expr`/`:c::discard-ptr?`/`:c::type-of`) inside the loop, in addition to the tail-call
  pass-through. That predicts a LEAK (more increments than the one base-case decrement, for any
  sequence of more than one statement), not an underflow -- the opposite of what is observed for
  the base case's drop taken alone. This contradiction was not resolved in the time available.

No fix was attempted on the real tree: none is confirmed at the root, and a guard or a removed
drop would violate the round's own rule against silencing the check. No new probe fixture was
added to `elf/probe/`: the crash only exists in `:c::seq`'s COMPILED machine code, which only
exists once `elf/compile.wat` itself has been compiled; `tools/probe.sh` drives the INTERPRETER
to compile a small target program and never produces or runs `:c::seq`'s own compiled body, so it
cannot exercise this shape. `elf/probe/drop-arm2.wat` (round 5, self-tail-recursive walker with a
read-only pass-through context) remains in the tree, still agreeing, still not reproducing this
crash -- its context parameter has no OTHER use inside the loop besides the pass-through, which
is exactly the difference from `:c::seq`'s `pg`/`env`/`rt` (used inside the loop AND passed
through) that the per-iteration count above turned on.

**R15 -- resolved. The "second-run crash" IS the self-overwrite, confirmed directly.**
`elf/out/compiler.elf` (the real tree's own proven build, unmodified) copied into a sandbox and
run DIRECTLY (`./elf/out/compiler.elf`, bypassing `tools/bootstrap.sh`'s `stage1.elf` copy)
fails identically and reproducibly on two independent invocations of the same sandbox:

```
"compile: elf/native/threads4.wat -> elf/out/threads4.elf    1545  bytes ...  verified"
assert failed: (:wat::test::assert-eq written filesz)
```

`elf/native/threads4.wat` is the LAST program `:user::main` compiles
(`elf/compile.wat:8656-8749`) before `elf/compile.wat -> elf/out/compiler.elf` -- so the failure
is exactly the self-compile step, writing into the file backing the currently-running process's
own image. The failing assertion is inside `:asm::link` (`elf/lib/asm.wat:166-174`):
`(assert-eq written filesz)`, comparing the byte count `:asm::write-bytes` reports against the
structurally-computed size; a third assertion right after it, `(assert-eq (asm::read-hex path)
blob)`, reads the just-written file back and compares it byte for byte, which a self-overwrite
would also corrupt. `elf/out/compiler.elf` on disk was UNCHANGED (same sha256, same 367,987
bytes) after both failed runs -- the write did not complete as expected, matching "writes without
the file growing" from round 5's `/proc/pid/io` observation. Confirmed the existing guard works:
the same sandbox, run from a COPY (`cp elf/out/compiler.elf elf/out/copy.elf; ./elf/out/copy.elf`,
writing its output to `elf/out/compiler.elf` -- a path DIFFERENT from the one it executes from)
reaches `"compile: ok"` cleanly, byte-identical to the original. This is exactly why
`tools/bootstrap.sh` already copies to `stage1.elf` before running it (its own existing comment).
**Nothing to fix**: `tools/verify.sh`/`tools/bootstrap.sh` avoid this hazard by construction; it
only appears when a self-hosting compiler's own output binary is run in place, by hand, which no
gate does.

**Landing gates on the real tree** (unchanged from round 5 -- no fix landed this round, so these
reconfirm the same state rather than newly pass):

- `tools/verify.sh` (check off): **`verify: ok`**. Fixpoint at **367,987 bytes**
  (`dc78c547e54ffa755af0cb0affd73a7ffdfee57c1797f8e9fd50a08aaa0b15c5`), stage 1 in **1,623 ms**
  (561x faster than the interpreter). `elf-run: ok -- 103 native binaries`; `rules: 0 conflicts`
  in 13,218 argument-parameter pairs over 150 programs; `types: 0 type conflicts` in 23,356 nodes
  over 150 programs.
- `WAT_DROP_CHECK=1 tools/verify.sh`: **FAILS**, same as round 5. Stage 0 (interpreted) succeeds
  in 895,684 ms, writing a 385,735-byte check-on compiler. Stage 1 (that compiler, native) dies
  on `ud2` (SIGILL) -- the same `:c::seq` base-case shape. `bootstrap: bootstrap FAILED (exit 1)
  -- elf-run not run`; the corpus-wide underflow count still cannot be obtained this round for
  the same reason as round 5 (the run never reaches `elf-run.sh`).
- `tools/emitted.sh check`: **84 of 100 programs changed, 0 new** -- identical to round 2's and
  round 5's own number. Nothing this round touches emitted code (R14's restriction lived only in
  sandboxes; no edit reached the real tree).
- After the check-on run (which necessarily overwrites `elf/out/` with its own, failing build),
  `elf/out/` was restored from the pristine proven build and reverified:
  `SKIP_BUILD=1 tools/elf-run.sh` -> `elf-run: ok -- 103 native binaries`, matching stamp. The
  real tree ends this round in the same state it started: the proven check-off build in place,
  check-on still red at `:c::seq`'s base case.

**Left in the tree, uncommitted:** unchanged from round 5 (R11's `dchk` field/`:c::envvar-set?`,
R13's reordered `tools/bootstrap.sh`, `elf/probe/drop-arm2.wat`). No edits were made to the real
tree this round; all R14 instrumentation (`:c::r14-allowed?`, `:c::r14-name-ok?`, the drop-arm
name gate) lived only in `/tmp/stone3a-r6/*` sandboxes, deleted at the end of this round along
with the pristine `elf/out` copy used to reseed each bisection step. Nothing committed.

## Round 7 — 2026-09-28

**R16 — the rule, and where it lives.** A pointer-typed value flows on, unchanged, from exactly
two GENERATORS in the whole compiler: an `if`'s two arms (`:c::if-form` and its comparison fast
path `:c::if-cmp`, plus the peeled early-return `:c::wrap-head` and the matching ELSE-arm branch
in `:c::compile-fn`'s `wrap?` path — all four are the same THEN/ELSE arm position, one of them
compiled early) and `:c::seq`'s last kid (which is also where `cond`'s clauses, `match`'s arms and
`let`'s body all lower their own last form, since `:c::cond-form` and `:c::match-arms` both call
`:c::seq` for a clause/arm's body). Every other head computes a FRESH value (a call, a builtin, a
constructor) that is already correctly counted at its own construction. `:c::expr-val`
(`elf/compile.wat:4141`, `(:c::share a env pg (:c::expr a o env pg rt tb slot tc))`) is `:c::share`
composed with `:c::expr`, and it now stands in place of bare `:c::expr` at all seven of those value
slots: `:c::if-form`'s two arms (`:3597`, `:3630`), `:c::if-cmp`'s two arms (`:3655`, `:3662`),
`:c::wrap-head`'s early-return value (`:6842`), `:c::compile-fn`'s `wrap?` ELSE branch (`:7268`),
and `:c::seq`'s last statement (`:5688`, guarded by `last?` — an earlier, non-last statement still
goes through bare `:c::expr`, since its value is always discarded).

**Why no value position misses it.** `:c::expr-val`'s own `:c::share a` is a no-op unless `a` is
literally a bare Symbol at THIS level; when `a` is itself `if`/`cond`/`match`/`do`/`let`, the call
recurses through `:c::expr` into `:c::form` into the matching generator, which (now fixed)
re-applies `:c::expr-val` at ITS OWN arm/last-kid position. Nesting bottoms out, after finitely
many steps, at either a leaf Symbol (shared here, or moved at its last use exactly as an argument
is via `:c::share`'s existing `:c::last-use?` check) or a form that allocates fresh (never needs a
share). `and`/`or` were checked and excluded: `:c::type-of-form` (`elf/compile.wat:~1686`) types
them `"bool"` unconditionally — a deliberate wat-vs-Clojure divergence already on the record — so
`:c::ptr-ty?` is always false for their value and `:c::share` is always a no-op there regardless.

**The `:c::seq` site named in the WEIGH is fixed** (`(:wat::core::if last? tc (:c::no-tail))`
passed as `:c::seq`'s own tail-context argument, when the COMPILER compiles ITS OWN `:c::seq`
function under self-hosting, is exactly this class: an `if`'s THEN arm is the bare Symbol `tc`).
**One further site was found by the rule, not by search**: `:c::compile-fn`'s `wrap?` ELSE branch
(`elf/compile.wat:7268`, pre-edit) compiled the function's ordinary return value — the peeled
`if`'s ELSE arm — through bare `:c::expr`, the same defect as `:c::wrap-head`'s THEN arm beside it.

**Fixtures** (`tools/probe.sh`, both ways): `elf/probe/drop-ifval.wat` (the WEIGH's `probe-3a-ifval.wat`,
promoted; `(user/take (if c b (:user::Box ...)))`, `b` read again after) — agree, agree. Two new
variants: `elf/probe/drop-let-tail.wat` (`(user/take (let [z 1] b))`, `b` read again — exercises
`:c::seq`'s fix for `let`'s tail) — agree, agree. `elf/probe/drop-match-arm.wat` (a `:Some {}` arm
returns `b`, a `:None {}` arm a fresh record, `b` read again — exercises `:c::seq`'s fix for a
`match` arm's body) — agree, agree. All three: `[6|"ab"]` both ways, matching the interpreter.

## R17 — the trap, and why it read as a hang

**The cause, confirmed directly, not inferred.** `ud2` raises SIGILL with no handler installed.
This machine's `core_pattern` is `|/usr/lib/systemd/systemd-coredump ...` with `ulimit -c
unlimited`, and this compiler's own heap is one `mmap` sized to `totalram+totalswap`
(`:c::stub-size`, M2, out of scope) — tens of gigabytes of virtual address space on this machine.
Reproduced in a sandbox (`/tmp/stone3a-r7-prefix`, the R16 bug alone, pre-R16-fix, no R17 fix): the
native run of the check-on `drop-ifval` probe sat at **0% CPU, state `S` (sleeping)**, `VmSize`
~93 GB, for the full 20 s window, while a separate `systemd-coredump` process ran at 90%+ CPU
concurrently (`ps`/`/proc/<pid>/status`, captured directly) — the crashing process itself is not
spinning; the kernel is trying to write a core dump of its address space, which the default
`ulimit`/`core_pattern` never finishes inside any reasonable timeout. Under gdb the tracer
intercepts the signal before `core_pattern` ever runs, which is why it looked instantaneous only
there. This is confirmed, not conjectured: `ps aux` during the hang is captured above.

**The fix**: an underflow now ends the process with a named stop, `wat: reference count
underflow`, exit 70 — the same shape as stone 1's `wat: heap exhausted`, never a signal.
`:c::dropchk-hex` (`elf/compile.wat:4275`) builds `cmp qword[rax-8],1 ; jb rel32 ; dec`, the `jb`
reaching a new shared runtime stub `:c::rt-uflow` (`elf/lib/runtime.wat:1721`,
`(:c::rt-abort "wat: reference count underflow" lay (:c::at-uflow lay))`) instead of `ud2` — one
emission, same as before, now reached by a jump rather than a trap. `:c::drop-hex` (`:4295`)
computes the fixed-size prefix any outer guard (`:c::tag-then`, 8 bytes; the literal guard, 7
bytes) contributes before the check, so the `jb`'s rel32 is computed from `(:c::here o)` without
needing to have already emitted those guard bytes. `:c::rt-count` is 36 (was 35); `:c::rt-nth`'s
fallthrough case is `:c::rt-uflow`, `:c::at-uflow` its accessor (index 35). Check-off is byte
identical: `:c::dropchk-hex` short-circuits to plain `(:c::dec-hex)` when `(:c::Prog/dchk pg)` is
false, before touching any of the new bytes.

**A second, DISTINCT defect found while proving this,** by the same method the WEIGH names for
R12/R14 (build small, run it, read what actually happened rather than trust the design): the first
attempt to run the two-hop sandbox test crashed with **SIGSEGV at a garbage address (`0x4010cf`,
outside the file)**, not SIGILL — the `jb` target itself was wrong. Traced to `:c::rt-level`
(`elf/compile.wat:8108`): the runtime block is not always emitted in full — `:c::rt-at`
(`elf/lib/runtime.wat:1685`) truncates it to the highest routine index a program's SOURCE actually
asks for (`:c::rt-level`'s per-builtin table, `:c::lvl-head`), because "every internal call in
this block points backward... a program carries only as much of it as it can reach". `:c::at-uflow`
(index 35) was never in that table — nothing in a user's SOURCE spells the check; it comes from an
environment variable — so `:c::rt-level` truncated the block before index 35 while `:c::at-uflow`
still answered the address as if it were present, a phantom address past the (correctly, for a
non-check build) shorter block. Fixed at `:c::rt-level`: `(:wat::core::if (:c::Prog/dchk pg) (:c::imax
scanned 35) scanned)` — a check build always needs the stub reachable, regardless of what the
source otherwise uses. This is a second, independent site R17 required past what the WEIGH named;
without it the `jb rel32` fix alone is a silent wrong-address bug, worse than the `ud2` it replaced.

**Shown on the pre-fix fixture, in a sandbox** (`/tmp/stone3a-r7-prefix`: R16's bug present via a
`(:c::expr-val ` -> `(:c::expr ` revert on top of the fixed tree, R17's fix present) —
`elf/probe/drop-ifval.wat`, `WAT_DROP_CHECK=1`, native run:
```
6
wat: reference count underflow
```
exit 70, **0.003 s** (vs. the pre-R17 hang above). The R16 bug still corrupts the count (this is
what the fixture is FOR); the difference R17 makes is that the corruption now surfaces as a named,
prompt stop instead of an unreadable hang.

**Sandbox two-hop build** (`/tmp/stone3a-r7`, seed = `/tmp/stone3a-orch/seed.elf`, the round-6
proven check-off compiler, 367,987 bytes; method per `probe-3a-twohop-step.sh`, R16+R17 both
applied): seed compiles the round-7 source -> `s1` (368,958 bytes, check-off, `compile: ok`).
`WAT_DROP_CHECK=1 ./s1.elf` compiles the same source -> `s2` (391,574 bytes, check-ON,
`compile: ok`, no trap while COMPILING it). **`./s2.elf`, the actual test — the check-on compiler
compiling the whole corpus and then itself — runs in 1.78 s, `compile: ok`, zero traps**, writing a
369,680-byte `compiler.elf` (`s3`). `s3` run again reproduces itself byte-for-byte (`s3 == s4`):
the check-on tree reaches a fixpoint. (`s1 != s3` byte-for-byte is expected and not a regression —
`s1` was built by the OLD seed's codegen, `s3` by the new one; `tools/bootstrap.sh`'s own comment
says exactly this about `--fast`.)

**Fixtures, full sweep** (`tools/probe.sh`, both ways, on the real tree with all edits applied):
every `elf/probe/drop-*.wat` agrees check-off and check-on — `drop-arm`, `drop-arm2`, `drop-at1`,
`drop-at3`, `drop-at4`, `drop-at5`, `drop-conj`, `drop-head`, `drop-ifval`, `drop-len`,
`drop-let-tail`, `drop-match-arm`, `drop-ret`, `drop-shadow`, `drop-sum`, `drop-tail`, `drop-twice`
— seventeen fixtures, all agree. `drop-cons.wat` is excluded exactly as round 3 recorded it: an
unconditionally self-recursive `user/seed` with no base case, present in the tree untracked,
predating this round, D1's out-of-scope (3b) recursive-drop fixture — it does not terminate under
either the interpreter or the native compiler, on or off, and is not part of this round's gate.

**Landing gates on the real tree — INCOMPLETE this round; here is the honest state.**
`tools/verify.sh` (check off) was launched in the background (`nohup`, PID 2327406,
`/tmp/verify-off.log`) and was still in interpreted stage 0 (of ~24 minutes) when this round ran
out of room to keep waiting. `WAT_DROP_CHECK=1 tools/verify.sh` was not started — it must run
AFTER the check-off run finishes, sequentially, since both write `elf/out/`. **Neither real-tree
verify gate is confirmed passing as of this write-up.** Everything else in this round (the sandbox
two-hop build, the full `elf/probe/drop-*.wat` sweep, the three new fixtures, the pre-fix
reproduction) ran to completion on its own evidence, but the two ~30-minute gates that would make
this landable did not finish inside this round. `tools/emitted.sh check` was not run this round
(would have read a half-written `elf/out/` while the background verify was writing it). Fixpoint
size and stage-1 time are the SANDBOX's numbers above (369,680 bytes, s2 in 1.78 s), not yet the
real tree's own.

**What is left in the tree, uncommitted, at the end of this round:** the R16 fix (`:c::expr-val`
and its seven call sites), the R17 fix (`:c::dropchk-hex`, `:c::drop-hex`'s new signature,
`:c::emit-drop`'s updated call, `:c::rt-uflow`/`:c::at-uflow`/`:c::rt-count`=36/`:c::rt-nth` in
`elf/lib/runtime.wat`, and the `:c::rt-level` fix), plus `elf/probe/drop-ifval.wat`,
`elf/probe/drop-let-tail.wat` and `elf/probe/drop-match-arm.wat`. `elf/out/` is CURRENTLY BEING
WRITTEN by the still-running background `tools/verify.sh` (check off) — do not treat its contents
as settled until that process (PID 2327406, log `/tmp/verify-off.log`) has exited. **STOP is not
invoked**: nothing here hit a rule that cannot be placed, a trap whose root cannot be traced, or a
gate proven unable to pass — the two real-tree gates are simply unfinished, not failed or refused.

## Round 9 — 2026-09-28

**Note on round 8.** No round-8 section exists above this one in this file -- the previous
round's edits (R18 classifying `uflow`, R19's `:c::lit-then`/`:c::dropchk-hex`-prefix
derivation and the `:c::rt-level` floor) are present in the tree and were credited by the
WEIGH's own round-9 intro on the orchestrator's independent runs, but no SCORE write-up for
them was appended. That gap is not this round's to fill; this section covers round 9 (R20)
only.

**Reproduction.** `WAT_DROP_CHECK=1 tools/probe.sh elf/src/assocn.wat`:
`assocn: DIVERGE  native=[99|wat: reference count underflow] (exit 70)   interp=[99|99|99|4|20|40|100|100|30] (exit 0)`.
Confirmed again standalone (outside probe.sh's tmpdir, so the binary could be kept for gdb):
native prints `99` then `wat: reference count underflow`, exit 70.

### R20 -- the shrink

`elf/src/assocn.wat`'s `user/assoc-n [v k x i acc]` is a counted self-tail loop over a
read-only `v` (`(nth v i)`, a same-slot self-tail pass-through -- `:c::ronly?` true), with a
SECOND, nested `if` beside the self-tail call: `(conj acc (if (= i k) x (nth v i)))`. That
nested if's `x` arm does not mention `v` at all. The shrunk shape, `elf/probe/drop-ronly-arm.wat`:

```
(wat.core/defn user/walk [v :- :user::Row k :- wat.type/i64 i :- wat.type/i64 acc :- wat.type/i64]
    :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length v)) acc
    (user/walk v k (wat.core/+ i 1)
      (wat.core/+ acc (wat.core/if (wat.core/= i k) 0 (wat.core/nth v i))))))
```
called once as `(user/walk v 2 0 0)` then `v` read again (`(nth v 0)`). On the PRE-FIX tree
(built by reverting only the R20 edit below, in a sandbox, over the R16-R19 tree): native
prints `70` then `wat: reference count underflow`, exit 70; the interpreter prints `70` then
`10` (agree). This is smaller and cleaner than `assocn.wat`'s own repro: one call, not two --
because `main`'s single share of `v` (count 1 -> 2) is exactly enough for ONE extra bad drop to
exhaust it before the base case's own (legitimate) drop ever runs.

### The watchpoint history

gdb 17.2, `set disable-randomization on`, the compiled probe binary run directly (non-PIE,
`EXEC`, entry `0x400078`, fixed addresses -- no ASLR to defeat beyond the flag). Function
addresses obtained by a sandbox-only debug `println` inserted into `:c::pass`
(`(:c::Fn/name f)` / `(:c::Fn/addr f)`), not committed: `user/assoc-n@0x4001a6`,
`user/at@0x40029b`, `user/sum@0x4002d7`, `user/main@0x400364`.

Breakpoint at the runtime's underflow stub (found by following every `jb` target from a
`cmpq $1,-8(rax)` guard, all landing on one address): `0x401405`. Stopped there first, `rax` =
`0x7fe8b6606010` -- the object `v`: `[rax-8]=0` (count, already zero), `[rax]=4` (length),
`[rax+8..]=10,20,...` (a Vector of `[10 20 30 40]`, `assocn.wat`'s literal `v`). Since the
guard is `cmp [rax-8],1 / jb <here> / dec [rax-8]`, `jb` never touches `rax`, so the stop names
the object exactly.

Restarted with a hardware watchpoint on `*(long*)0x7fe8b6606008` (`v`'s count word), installed
right after the heap's one `mmap` (before entering user code, at `0x400131`) so it never
reads unmapped memory, logging `$pc` and the new value on every write, on the ORIGINAL
`assocn.wat` binary:

| # | `$pc` (after the write) | new value | site |
|---|---|---|---|
| 1 | `0x400c16` | 1 | runtime `count-hex`: `v` allocated |
| 2 | `0x4003ce` | 2 | `user/main`: shares `v` before the 1st `user/at` call |
| 3 | `0x400245` | 1 | `user/assoc-n`, INSIDE the nested if's `x`-arm (`(= i k)` true, `i`=`k`=2): the BUG |
| 4 | `0x4001f8` | 0 | `user/assoc-n`, the OUTER if's base-case arm: the one legitimate drop |
| 5 | `0x40041f` | 1 | `user/main`: shares `v` before the 2nd `user/at` call (from an already-corrupted 0) |
| 6 | `0x400245` | 0 | same buggy site as #3, on the 2nd call's `i`=`k`=0 iteration |
| — | `0x401405` | (trap) | the OUTER if's base-case guard, `rax`=`0x7fe8b6606010`: count already 0 |

Disassembly of `user/assoc-n` (`0x4001a6`-`0x40029b`) confirmed by address: the recursive-arm
branch that computes `(nth v i)` (`0x40024e`-`0x400280`) does NOT touch `v`'s count at all
(read-only, correct); the sibling `x`-arm (`0x400231`-`0x400245`) reloads `v` from its saved
stack slot and does `cmpq $1,-8(rax) / jb 0x401405 / decq -8(rax)` -- dropping `v` even though
`x`, the value this arm actually returns, never mentions it. The OUTER if's base-case arm
(`0x4001e4`-`0x4001f8`) does the same drop, correctly, once, when recursion ends.

### The root

`elf/compile.wat`, `:c::arm-dead?` (pre-fix, was line 4601) and `:c::drop-arm` (pre-fix, was
line 4615): "names that die on this arm because the other arm is the one that still uses
them." The condition is `occ(arm)=0 AND occ(other)>0 AND (:c::holds? pg iff (:c::last-node pg
name))` -- `:c::last-node` finds the ONE textually-last occurrence of `name` in the whole
function, and `:c::holds?` asks only whether `iff`'s subtree CONTAINS that node, which is true
for every `if` node on the path down to it, not only the one whose two arms actually PARTITION
the name's lifetime.

For `assoc-n`'s `v`: the outer if's else-arm (the recursive call) holds both of `v`'s
occurrences (the self-tail argument and, nested inside it, the `(nth v i)`), so
`:c::last-node` picks the `nth`-read, and the OUTER if correctly concludes `v` is dead in its
THEN (base-case) arm -- one legitimate drop. But the INNER if (`(if (= i k) x (nth v i))`,
entirely inside that same recursive arm) ALSO "holds" that same last-occurrence node, and its
own `x`-arm independently satisfies `occ(x-arm)=0`, `occ(nth-arm)>0` -- so it ALSO concludes
`v` is dead there and drops it a second time, once per call whose `k` falls inside `v`'s
length. `:c::ronly?` (self-tail-passed, read-only) is exactly the class of parameter this
misfires for: a read-only parameter's true lifetime ends only at the recursion's OWN
terminating decision (the arm sibling to the self-tail call), never at an unrelated nested
if's arm that merely happens to be the last place it's textually mentioned. This is a
DIFFERENT bug from R12's refuted hypothesis about `:c::seq` (round 5): there the params failed
`:c::read-only-all?`'s stricter test entirely (ordinary call arguments, not `nth`/`length`/a
same-slot pass-through) and `:c::ronly?` was already false for all of them, so guarding on it
changed nothing; here `v` genuinely IS `:c::ronly?`, and the existing guard
(`:c::drop-if-last`, `elf/compile.wat:4497`, already exempts a ronly name from the "reading
built-in operand" drop) was simply never extended to this SECOND drop mechanism.

### The fix

Two new functions ahead of `:c::arm-dead?` (`elf/compile.wat:4608`, `:4617`): `:c::leads-self?`
and `:c::any-leads-self?`, mirroring `:c::tail-self?`'s own tail-position walk (through
`if`/`cond`/`match`/`let`, via the existing `:c::tail-nodes`) but WITHOUT its arity check --
a call whose head is `(:c::Prog/cur pg)`, this function's own globally-unique name, can be
nothing else. `:c::arm-dead?` (`:4633`) and `:c::drop-arm` (`:4649`) each gained one more
conjunct: `(:wat::core::or (:wat::core::not (:c::ronly? pg name 0)) (:c::leads-self? other
pg))`. For an ordinary (non-ronly) name this is a no-op (`not ronly?` is already true). For a
ronly name, the arm-death drop now fires only when the arm that still uses it (`other`) is
itself the self-tail call (or leads to it through `if`/`cond`/`match`/`let`) -- the loop's own
terminating decision -- never an unrelated nested if.

### Fixture, both ways

`elf/probe/drop-ronly-arm.wat` (new, joins the corpus of probes): on the tree with the fix,
`tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh` both `agree   [70|10]`, matching the
interpreter. On a sandbox copy of the tree with ONLY this round's edit reverted (R16-R19
still present), `WAT_DROP_CHECK=1` native run: `70` then `wat: reference count underflow`,
exit 70 -- reproduces. `elf/src/assocn.wat` itself: `tools/probe.sh` and `WAT_DROP_CHECK=1
tools/probe.sh` both `agree   [99|99|99|4|20|40|100|100|30]`.

Full `elf/probe/drop-*.wat` sweep (both ways, real tree, `drop-cons.wat` excluded as rounds 3
and 7 recorded -- an unterminating fixture out of this stone's scope): eighteen fixtures now
(seventeen from round 7 plus `drop-ronly-arm.wat`), all agree both ways.

### Landing gates, real tree

Run strictly sequentially (never concurrently), each waited out to completion:

1. `tools/verify.sh` (check off): `verify: ok`. Bootstrap fixpoint `stage1 == stage2` at
   **370,551 bytes**; `elf-run.sh`: 103 native binaries, 54 agree with the interpreter, 3 use
   unimplemented syscalls (F-119), 11 refusals and 4 arithmetic traps both ways (pre-existing,
   unrelated to this round); `rules: 0` conflicts in 13,305 pairs, `types: 0` conflicts in
   23,887 nodes, over 154 programs.
2. `WAT_DROP_CHECK=1 tools/verify.sh`: `verify: ok`. Fixpoint at **392,489 bytes**, stage 1 in
   1,497 ms (603x the interpreter). `elf-run.sh`: same 54/103 agree, **`assocn` among them:
   `assocn   agree (exit 0, 5209 bytes native)  99 99 99 4 20 40 100 100 30`** -- and
   **zero occurrences of "underflow" anywhere in the run's output**: the whole 154-program
   corpus compiles and runs clean under the check.
3. `tools/verify.sh` (check off, re-run last to put `elf/out` back in the check-off state
   `tools/emitted.sh` compares against): `verify: ok` again, same fixpoint, same counts.

### `tools/emitted.sh check`

No prior manifest existed from before this round specifically (the on-disk
`elf/out/.emitted-manifest` predated rounds 7-9 and so reported 84 of 100 programs moved --
correctly, but that reflects the CUMULATIVE effect of R16 (`:c::expr-val` at seven value
positions), R17 (the abort mechanism) and R19 together, not R20 alone, so it is not reported
as this round's number). To isolate R20's own effect: the corpus was rebuilt interpreted, in a
sandbox, from a copy of the tree with ONLY the R20 edit reverted (R16-R19 present, matching
what round 8 landed) -- 92 corpus binaries, all built successfully -- and every one of those
92 (excluding `compiler.elf`, which legitimately differs whenever the compiler's own source
changes) was compared byte-for-byte against the real, current, check-off `elf/out`.

**Exactly one program moved: `assocn.elf`, 4432 -> 4417 bytes (15 bytes smaller, check-off) --
one dropped decrement-and-its-wrapper, matching the fix exactly.** The other 90 corpus programs
this round could reach (91 - `assocn`, `fileio`/`countedovf` skip in a sandbox for path
reasons unrelated to this change) are byte-identical to before R20. `compiler.elf` legitimately
grew, 370,432 -> 370,551 bytes (+119), carrying the two new functions and the two new
conjuncts. `tools/emitted.sh save` was then run to record the current (post-R20) check-off
build as the baseline for the next round.

### Summary

Corpus underflow count under the check: **0** (was 1, `assocn`, before this round). Both real-tree
gates pass. Fixpoint sizes: check-off 370,551 bytes, check-on 392,489 bytes. `emitted.sh`:
one program's emitted code moved this round (`assocn.elf`), for the reason given above; a
fresh manifest is now saved. Nothing here hit a rule that could not be placed, a trap whose
root could not be traced, or a gate that could not be made to pass.
