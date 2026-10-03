# WEIGH — the retention sites

## Round 1 (2026-10-02)

**Credited.** The census names its holders (`hold` lines by record type); the owning `assoc` was the class for the
orphan `:c::Buf`s and unreachable `:c::Out`s (the owning path overwrote a pointer field without dropping the old value,
and the copying path did not drop the source) — now it drops the displaced field and drops the source on the copy;
`:c::last-let` walks a `let`'s rebinding; the silent `cond` clause drops a name its body does not mention. Gates on
Grok's runs: both `tools/verify.sh` runs `verify: ok` (plain 584,491 bytes; check 702,794), 32 fixtures both ways,
reads/copies/rsp clean. `rd/add` and `:c::buf-add` are absent from the self-compile census.

**The measurement, on my own runs, the SAME input as `NOTE-M2-landed.md` (main's `956b4bb` tree):**

| | old main | M2 landed | this strike |
|---|---:|---:|---:|
| peak RSS (KB) | 446,156 – 446,324 | 298,232 – 298,460 | **67,572 – 68,656** |
| user instructions | 6.233 – 6.237 B | 8.416 – 8.417 B | 11.147 – 11.150 B |
| user cycles (pinned) | 2.849 – 2.889 B | 3.400 – 3.421 B | 4.64 – 5.19 B |

The SCORE's R3 table measured a DIFFERENT input (this tree) against the NOTE's `956b4bb` figures; on the same input the
memory is −85% against the old main and −77% against M2, and the instructions +32% against M2.

**Not landable — two things:**

## R1 — the `cond` drop is gated by three names

`:c::cond-name-dead?` drops only `rec::c::TC`, `rec::c::Prog`, `rec::c::Out`. The general rule — every pointer, or every
`rec:` as `:c::and-name-dead?` uses — makes the compiler that contains it fail: SIGSEGV in a free-list pop with `r9 = -1`,
`:ty-fail` on the unwind (`/tmp/ret-dc-b.elf`). Three names that exist only because the general rule crashes are a GUARD
around a defect, and they leave a user's records (`:user::TC`) without the drop. Root the crash: a block freed while still
in use, or a list corrupted — the free list's `r9 = -1` is the evidence. Under `WAT_DROP_CHECK=1` nothing is reused, so the
check build should stop where the plain one corrupts (a poisoned object used): run the general rule under the check chain
first. Then the drop applies to every pointer type the census can show is dead, with no list.

## R2 — `drop-shadow.wat` comes back

It was rewritten from the shadowed-String program (`inner`, `inner`, `outer`) into a record-rebinding program. A fixture
is not rewritten to cover something new: restore it from `git show HEAD:elf/probe/drop-shadow.wat`, and put the
rebinding shape in its own file (`drop-let-rebind.wat`). Both agree both ways.

## R3 — say where the instructions went

+32% instructions over M2 on the same input. Name what was added per drop site and per free (the owning `assoc`'s
save/load/drop/restore, the clause drops, list traffic), so the performance stone starts from a cost table.

## After the reboot (2026-10-02, 22:52)

An unexpected reboot. `/tmp` is a tmpfs: every sandbox and seed binary under `/tmp` is gone (`/tmp/ret-*`). The
tree is intact and shows round 2 under way: `elf/probe/drop-shadow.wat` is restored (no longer modified) and
`elf/probe/drop-let-rebind.wat` exists. Continue round 2 (R1 the `cond` drop's crash, R2 confirmed, R3 the cost
table) from the tree as it is; rebuild any seed you need from `elf/out/compiler.elf` (check its stamp first) or by a
full `tools/bootstrap.sh`. Put sandboxes you want to survive a reboot under `/var/tmp`, not `/tmp`.

---

## Round 2, weighed (2026-10-03)

**Credited.** The three-name gate is gone; the clause drop covers every `rec:`. R1's root — a last use in an EARLIER
clause's test, then this clause's body drop: two decrements, the second writing `link-1` into a freed block's count word,
popped by the next allocation — fixed with `:c::earlier-test-last?`. `drop-shadow.wat` restored; the rebind is
`drop-let-rebind.wat`. R3's table is the cost map the performance stone needs: every `:c::emit-drop` is 1.816 B of
11.354 B instructions; clause drops 307.6 M (and the only named piece that moves RSS, +12 MB without it); `and`/`or`
88.8 M; `assoc` 38.4 M. Peak RSS 64,108 – 65,244 KB on main's tree.

**Not landable — the safety net has a hole, and the gate moved instead of closing:**

## R1 — the check build must catch a decrement of a dead object

Grok's own finding: poison is −1, and the decrement guard is `cmp [rax-8], 1; jb` — UNSIGNED, so −1 is far above 1 and a
second decrement of a dead object passes. That is why `WAT_DROP_CHECK=1` compiled the double drop clean. The check is the
one gate for "a drop placed too early"; it must stop on EVERY decrement or increment of a poisoned object. Fix the guard
(say how — a signed compare, or an explicit poison test — and why no dead object can pass it), and prove it with a mutant:
an extra drop of a dead record stops under the check with `wat: reference count underflow`.

## R2 — then let the check find the string / vector fault

"Strings, vectors, and functions stay out: `(length (conj v 99))` faults when a clause drop meets the temporary `conj`
already consumed." That is a kind gate around a known double drop. With R1's guard, run the clause drop over EVERY pointer
kind under the check chain: it now stops where the plain build faults. Root it, fix it, remove the `rec:` restriction.

## R3 — the gates, re-run

Both rounds changed the compiler after round 1's `verify: ok`. `tools/verify.sh` and `WAT_DROP_CHECK=1 tools/verify.sh`,
in sequence, on the final source; then the same-input measurement (main's `956b4bb` tree) once more.

## After the second reboot (2026-10-03, 01:02)

Another unexpected reboot, during round 3 (`elf/compile.wat` last written 00:00). The tree is intact; anything under
`/tmp` is gone, `/var/tmp` survived. Continue round 3 from the tree as it is: R1 the check build catching a decrement of
a dead object, R2 the clause drop over every pointer kind, R3 both verifies and the same-input measurement.
