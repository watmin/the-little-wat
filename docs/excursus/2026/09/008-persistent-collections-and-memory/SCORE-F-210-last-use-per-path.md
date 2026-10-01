# SCORE — F-210: a last use is the last on its PATH

Struck by Claude Sonnet (2026-09-30). Written AS I GO per the brief's instruction.

## L1 — the set, one backward walk

`:c::Prog/lasts` is now a SET of last-use nodes, built by one backward walk over the same
order `:c::eval-seq` already defines, with `if`/`cond`/`match` as branches whose arms are
alternatives (not sequential).

**Record:** `:c::LastW [live <- Vector<String> lasts <- Vector<i64>]` (`elf/compile.wat:4490`).
`live` is the set of names a later read of which still lies ahead on the path being walked;
`lasts` is the growing set of last-use node ids.

**Leaf:** `:c::last-leaf` (`4541`) — a Symbol is a last use exactly when its name is not
already in `live` (first encounter walking backward == last occurrence walking forward).

**Dispatcher:** `:c::last-walk` (`4547`) — Symbol -> `:c::last-leaf`; List whose head is `if`
(arity >= 4) -> `:c::last-if`; `cond?` -> `:c::last-cond`; `match?` -> `:c::last-match`; every
other List -> `:c::eval-seq`'s order, reversed, via `:c::last-kids` (`4572`, now `[pg ks i
floor w]`, walks `ks[floor..i]` right to left); Vector/Map -> `:c::kidsof`'s order, reversed
(no branch can occur inside one).

**Branches**, all the same shape — walk each arm from the SAME incoming `live` (arms are
alternatives: one arm's reads do not make another arm's reads non-last), thread `lasts`
from one arm to the next so nothing already found is lost, then walk whatever always runs
(the condition / a clause's test / the subject) against the JOIN of every arm's `live`
(live if live on ANY arm — the same rule `:c::live-after` already applies to an `if`):
- `:c::last-if` (`4579`): `ks[2]` (then) and `ks[3]` (else) from `w`, joined, then `ks[1]`
  (condition) from the join.
- `:c::last-cond` (`4593`): recurses exactly as `:c::cond-form` does, one clause at a time —
  clause `i`'s body (`cks[1..]`) from `w`, joined against the recursive call for clause
  `i+1` (also from `w`, carrying `lasts` forward), then the test `cks[0]` from the join.
  `:else`'s body is the base case — no sibling to join against.
- `:c::last-match` / `:c::last-match-arms` (`4611`, `4615`): every arm (`aks[2..]`, since
  `aks[0]` is the pattern keyword and `aks[1]` a NEW binding, neither a read) folded from the
  SAME `w` (not chained, since all arms are reached directly from one dispatch), then the
  subject `ks[1]` from the join.

**`:c::last-node` is gone.** Its two callers, `:c::arm-dead?` and `:c::drop-arm`
(`elf/compile.wat:5402`, `5418`), asked whether the single global last mention of `name` fell
inside the whole `if` (`(:c::holds? pg iff (:c::last-node pg name))`). With the SET, the
sharper and still path-correct question is asked directly — `:c::last-dies-in? pg name other`
(`4528`): does `other` (the sibling arm, which `occ other name pg > 0` already established
holds an occurrence) hold one of `name`'s OWN last-use nodes? If so, nothing after it on that
arm's path — which includes everything after the `if` too, since the arm's own backward walk
started from what was live there — reads `name` again. New helper `:c::last-in-sub?`
(`4519`) scans `:c::Prog/lasts` for an entry whose text is `name` and which `:c::holds?` lies
inside `sub`.

**`:c::last-use?`** (`4507`) is now membership of node `a` in `:c::Prog/lasts` via a new
`:c::index-of-i64` (`4493`, the i64 twin of `:c::index-of-str`) — no longer a name-keyed
lookup followed by a single-node equality check, since a name can now have more than one
entry in the set. Signature unchanged (`name` param kept, unused) so every one of its seven
call sites is untouched.

**Top-level build** (`elf/compile.wat:8058`): `:lasts (:c::LastW/lasts (:c::last-walk pg node
(:c::LastW :live (Vector :- [String]) :lasts (Vector :- [i64]))))`.

**Syntax fixed on first probe:** `:c::vcat` takes 3 arguments (`a b i`), not 2 — all three
call sites (`4584`, `4603`, `4623`) missed the `0` start index; the interpreter's type
checker caught it immediately (`ArityMismatch`) on the very first `tools/probe.sh` run
(`drop-ifval`), before any semantic question was asked. Fixed, asserted by grep, re-ran: agrees.

## Probes — `tools/probe.sh`, check OFF

All 25 required fixtures (every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus both
`f209-*`) **agree**:

```
drop-3b-closure: agree   ["1188895"]
drop-3b-list: agree   ["99999000000"]
drop-3b-recs: agree   ["744500"]
drop-arm2: agree   ["6"|"7"]
drop-arm: agree   ["3"]
drop-at1: agree   [5|"3"]
drop-at3: agree   [1|"ababab"]
drop-at4: agree   [8|"xab"|0|"x"]
drop-at5: agree   [8|"xab"|"x"]
drop-concat-box: agree   ["4abcd4!"]
drop-conj: agree   ["20"|"99"|"25"]
drop-head: agree   ["7"]
drop-ifval: agree   [6|"ab"]
drop-len: agree   ["4"]
drop-let-tail: agree   [6|"ab"]
drop-match-arm: agree   [6|"ab"]
drop-ret: agree   ["3"]
drop-ronly-arm: agree   [70|10]
drop-shadow: agree   ["inner"|"inner"|"outer"]
drop-sum: agree   ["4006000"]
drop-tail: agree   ["0"]
drop-twice: agree   ["3"|"3"]
drop-vec-cycle: agree   ["2000000"]
f209-tier1-self-vec-build: agree   [1]
f209-tier1-self-vec: agree   ["1"]
```

## Probes — `WAT_DROP_CHECK=1 tools/probe.sh`, check ON

All 25 **agree**, byte-identical output to the check-off run above (including
`drop-vec-cycle: agree ["2000000"]`, the fixture that carries F-210's own evidence — but an
agree here is NOT yet proof of the fix: the OLD bug is an OVER-count (the value is never
freed), which the check cannot see either, since nothing ever underflows. L3 below is where
the count itself is read.

## A second defect, found by the native chain before L3: `:c::vcat` at a branch join is exponential

Before L3, the brief's step 3 asks for a native self-compile chain under the check (seed ->
s1 -> s2 -> s3) in a sandbox (`/tmp/f210-sandbox`, built from a full `elf/` + `tools/` copy of
the real tree plus the committed `elf/out/compiler.elf` as the seed). `WAT_DROP_CHECK=1`,
seed compiling the new source (`seed.elf` -> `elf/out/compiler.elf`, 512,012 bytes) succeeded
in seconds. The next hop -- that NEW compiler compiling itself again -- hung: `ulimit -v`
capped at 4 GB and 16 GB both died identically, right after `elf/src/nnegsub.wat`, with `wat:
heap exhausted`; uncapped, RSS passed 24 GB and climbed.

**Isolated with `tools/probe.sh` (interpreted, no native chain needed): `elf/src/select.wat`
alone hangs past 60 s** (every required probe fixture is small; this file is not in the
required list and was never exercised). Bisection by hand (trimming functions and call sites
out of `select.wat` into scratch fixtures under `/tmp/f210-sandbox`) found the exact trigger:
six tiny self-tail-recursive functions (`user/mx`, `clamp`, `wrap`, `down`, `same`, `wide`,
each one `if` or three), each called once from `main`, compiles in ~7 s; adding a SECOND call
to `user/clamp` (`(user/clamp 4 500)`, no unusual literal) was enough to make it hang.

**Root, found with a debug build instrumented to print `:c::LastW/live`'s length at every
`:c::last-kids` step (`/tmp/f210-sandbox/dbgbox`):** `:c::last-if`'s join
`(:c::vcat (:c::LastW/live wt) (:c::LastW/live we) 0)` is a bare concatenation, not a set
union. `main`'s own body is a flat sequence of `println` calls with literal arguments and
tracks no names at all -- but a self-tail-recursive loop called with a LITERAL iteration count
gets unrolled (inlining, before either pass sees a node) into one nested `if` per iteration.
Confirmed by instrumenting `:c::last-walk`'s dispatch to print each node's head: the trace
inside `user/main` shows `HEAD=wat.core/if len=4` repeating, nested, once per unrolled level.
Both `wt.live` and `we.live` already carry nearly the same names forward from the incoming
`live`, so `:c::vcat` DOUBLES the live set at every level instead of staying bounded by the
handful of distinct names in scope: measured climbing 18 -> 20 -> 40 -> 42 -> 84 -> ... one
join at a time, i.e. `O(2^depth)` -- "heap exhausted" or an effectively endless hang for any
unroll past a few dozen levels (`user/wide 100 ...` unrolls to 100).

**Fix:** `live` is a SET -- `:c::last-leaf` only ever asks membership of it -- so the join
must dedupe. New `:c::live-union` (`elf/compile.wat:4540`) conjs an element of `b` into `a`
only when `:c::index-of-str` does not already find it there; the three join sites
(`:c::last-if`, `:c::last-cond`, `:c::last-match-arms`) now call it instead of `:c::vcat`.
`lasts` itself was never the problem -- it threads sequentially (one append per leaf, no
duplication at a join) and stayed small (6-16 entries) even while `live` exploded.

**Confirmed fixed:** the exact hanging repro (`/tmp/f210-sandbox/sel-11.wat`) and the full
`elf/src/select.wat` both now agree in ~7 s, matching the unmodified-HEAD baseline (9.3 s,
measured directly against `git show HEAD:elf/compile.wat`). All 25 required probes re-run
after the fix, check OFF and ON: byte-identical to the pre-fix (L1-only) runs above, both
still 25/25 agree.

## The native chain, redone with the fix: seed -> s1 -> s2 -> s3, `WAT_DROP_CHECK=1`

Sandbox `/tmp/f210-sandbox` (full `elf/`+`tools/` copy, `elf/out/compiler.elf` from the real,
committed HEAD kept as `elf/out/seed.elf`, 508,925 bytes), `elf/compile.wat` refreshed to the
post-`:c::live-union`-fix source:

- `seed.elf` compiles the fixed source -> `s1.elf` (512,374 bytes). Every one of the 92
  programs it builds (the whole `:user::main` corpus, `compiler.elf` among them) prints
  `verified`; `compile: ok`. Seconds, not a hang.
- `s1.elf` compiles the SAME source -> `s2.elf` (507,634 bytes -- smaller: `s1` still carries
  whatever the OLD seed emitted for the drops the fix changes, `s2` is the first binary built
  BY the fix, matching `tools/bootstrap.sh`'s own documented one-run "spurious DIFFER" after
  a change to what gets emitted). 92/92 verified, `compile: ok`.
- `s2.elf` compiles the source again -> `s3.elf` (507,634 bytes). 92/92 verified, `compile: ok`.
- **`cmp s2.elf s3.elf`: byte for byte identical. Fixpoint.** No stop, no STOP-2/STOP-3.

## L2 — every consumer still holds

Every call site of `:c::last-use?` (there are seven, plus `:c::arm-dead?`/`:c::drop-arm`'s
replacement of `:c::last-node`) asks the SAME question of a specific node `a`: "does the value
read here die right here, on the path that reaches it?" That is exactly what SET membership in
`:c::Prog/lasts` answers, whether the set holds one entry for `a`'s name or several on
different arms. Checked each:

- **`:c::share`** (`4192`) and everything built on it -- **`:c::expr-val`** (`:c::share`
  composed with `:c::expr`, called at every value position: an `if`'s two arms, `:c::seq`'s
  last kid) and **`:c::tail-share`** (`4134`, `:c::share`'s self-tail-argument wrapper, with
  its own read-only-pass-through exemption checked FIRST and unaffected by `:c::last-use?`
  either way). `:c::share` skips the increment -- a MOVE -- exactly when `a` is a last use.
  For a value returned from one arm of an `if` (F-210's own shape), each arm's own occurrence
  is now its own last use; whichever arm actually runs at runtime is the only one whose move
  happens, so two "last uses" of the same name on two arms never double-move a reference that
  was only incremented once.
- **The "twice?" sites** -- `:c::drop-saved`'s `twice?` argument at three call sites (`2650`
  copying `concat`'s source, `2815` a copying `conj`'s box, `5693` a copying `assoc`'s box):
  each asks whether THIS occurrence -- now placed at the call by `:c::eval-seq` (R9) -- is also
  the name's own last use, in which case the binding's reference is dropped a second time on
  top of the copy's own extra. Same per-occurrence question, same answer.
- **`:c::drop-if-last`** (`5276`) and the `length`/`strlen` drop decision (`2666`): drop a named
  pointer immediately after a READ (not a move) exactly when this read is the name's last use
  AND it is not `:c::ronly?`. Path-correct for the same reason as `:c::share`.
- **`:c::arg-shares?`** (`6635`): an argument that needs an increment (not at its last use)
  takes the slower "through rax" path instead of a direct register-to-register move. Same
  question, same per-occurrence answer.
- **`:c::drop-arm` / `:c::arm-dead?`** (`5402`, `5418`) -- the one consumer that is NOT a
  `:c::last-use?` call at all, and is DISJOINT from it by construction: it fires when `name`
  has ZERO occurrences in `arm` (so there is no last-use node inside `arm` to ask about) but at
  least one in the sibling `other`. The question is whether `arm`, which never reads `name`,
  must still actively release the reference it is holding -- answered by the NEW
  `:c::last-dies-in?` (`4528`): does `other` hold one of `name`'s own last-use nodes? Replaces
  the old single-node `(:c::holds? pg iff (:c::last-node pg name))` ("the global last mention
  falls somewhere inside the whole `if`") with the sharper, still-correct "the specific
  occurrence in the sibling arm IS that arm's own last use" -- which also correctly stays silent
  when `other`'s occurrence is NOT its last use (something after the whole `if` still reads
  `name` on that path), exactly where the old approximation could still only say "somewhere in
  the if", never which arm.
- **The read-only pass-through rule** (`:c::ronly?`, used by `:c::tail-share`,
  `:c::drop-if-last`, `:c::arm-dead?`/`:c::drop-arm`'s R20 exemption): unaffected by this strike
  -- `:c::ronly?` is a purely syntactic scan of a parameter's own occurrences (only `nth`,
  `length`, and a same-slot self-tail pass-through count as safe) and never consults
  `:c::last-use?` or `:c::Prog/lasts` at all.

**STOP-1 not hit.** No consumer's correctness depended on the OLD one-node answer; every one
asks a per-occurrence question that the SET answers at least as precisely, and `:c::arm-dead?`
more precisely (it can no longer be fooled by a last mention that happens to fall inside the
`if` syntactically but on the wrong arm).

## L3 — the evidence

**The loop-returned value's count at its caller, gdb on `[p-8]`.** `elf/probe/drop-vec-cycle.wat`
compiled to a native check-ON binary with the fixed compiler (`/tmp/f210-sandbox/s3.elf`, the
fixpoint binary from the chain above): `user/nest`'s `(if (= i 0) acc (user/nest ... (Node
{:kids (conj (Vector) acc)})))` builds a 2,000,000-deep tree and returns it; `user/build-and-drop`
binds it to `t` and its body is just `n`, so `t` is dropped, unread, right after the call. Disassembled
(no symbols; the binary is `EXEC`, fixed addresses, ASLR irrelevant to its own text) and
located the exact site at `user/build-and-drop`'s call site:

```
0x4002e2: call 0x4001a6        ; user/nest(2000000, Leaf) -- returns t in rax
0x4002eb: mov  r12,rax
0x4002f1: mov  [rsp+0x10],rax  ; t saved
...
0x4002fa: mov  rax,[rsp+0x18]  ; t reloaded (the push at 0x4002f6 shifted the offset)
0x400307: cmp  QWORD PTR [rax-0x8],0x1   ; the drop guard -- t's OWN count
0x40030c: jb   0x4011e6                  ; underflow trap (check build)
0x400312: dec  QWORD PTR [rax-0x8]       ; the decrement
...
0x400326: call 0x400895                  ; glue, only once count hits 0
```

Breakpoint at `0x400307` (right before the guard/decrement), `ulimit -s 256`, `setarch -R`
(ASLR off), the real tree's gdb method:

```
Breakpoint 1, 0x0000000000400307 in ?? ()
$1 = 0x7fe8c0ddebe8
0x7fe8c0ddebe0:	0x0000000000000001
$2 = 1
```

**`[rax-8] = 1`.** The loop-returned value reaches its caller with count 1, not 2 -- F-210's
exact defect, fixed. `continue`: the decrement brings it to 0, the glue at `0x400895` runs
(frees the whole 2,000,000-deep tree), the program prints `"2000000"` and exits normally --
confirmed both under gdb and standalone (`( ulimit -s 256; setarch -R ./elf/out/drop-vec-cycle.elf )`,
exit 0, `"2000000"`).

**The F3-revert mutant.** F3 (stone 3b-fix) is `:c::shape-children`'s `vec:` arm (recognizing
`vec:T` as an edge to `T`, so `:c::cyclic?` correctly sees `:user::T` as cyclic and gives it
NO self-calling glue -- "its own glue would otherwise call itself once per level of the user's
DATA, unbounded, against the ruling that drops are iterative", per the comment at
`elf/compile.wat:4907`) plus `:c::shape-only` carrying `vec:` through its own filter so that
arm is ever reached. Reverted both in the SANDBOX copy only (`/tmp/f210-sandbox/elf/compile.wat`;
`elf/compile.wat.fixed.bak` kept the real, unmutated source alongside it): `:c::shape-only`
back to `rec:`/`henum:` only, `:c::shape-children`'s `vec:` arm removed. Rebuilt
`drop-vec-cycle.elf` with the mutant compiler (interpreter-driven, `WAT_DROP_CHECK=1`).

At the fixture's own depth (2,000,000) the mutant binary neither finished nor crashed within
30 s (default stack) or under `ulimit -s 256` -- consistent with `:c::cyclic?` missing the
Vector edge and `T`'s glue and `vec:T`'s glue now calling EACH OTHER (`call`/`ret`, not a tail
call) once per level, exactly the mechanism the comment warns about, just slow enough at this
depth that 30 s was not conclusive by itself. Cut to depth 50,000 (`elf/src/drop-vec-cycle-small.wat`,
`sed 's/2000000/50000/'`) to get a fast, legible answer:

```
bash -c 'ulimit -s 256; setarch -R ./elf/out/drop-vec-cycle-small-mutant.elf'
# timeout: the monitored command dumped core
coredumpctl info
#   Signal: 11 (SEGV) si_code: SEGV_MAPERR
#   Stack trace of thread: #0 0x0000000000400382 ...
```

**`SIGSEGV`, `SEGV_MAPERR` -- a stack overflow**, at a depth 40x smaller than the fixture the
fixed compiler (depth 2,000,000, same `ulimit -s 256`, confirmed above under L3's first
measurement) runs to completion. With the default 8 MB stack the SAME depth-50,000 mutant
binary completes (`"50000"`, exit 0) -- the overflow is specifically the TINY stack, which the
FIXED binary's iterative (non-recursive) glue does not need at any depth tested, and the
MUTANT's call/ret-per-level glue does. F3 is load-bearing at last. Not reverted on the real
tree; the mutant lived only in the sandbox copy and was discarded after this measurement.

## Gates — the real tree

`nohup tools/verify.sh > /tmp/verify-check-off.log 2>&1 &`, waited with repeated `timeout 590
tail --pid=<PID> -f /dev/null`. **`verify: ok`.** Stage 0 (interpreter) -> stage 1 fixpoint:
"stage1 == stage2, byte for byte (410,790 bytes)". `elf-run: ok -- 103 native binaries. 54
agree with the interpreter; 3 more use syscalls it has no implementation of (F-119); 11
refusals and 4 traps, both ways. rules: 0 conflicts in 14,252 argument-parameter pairs (14,175
equal, 77 a variant to its enum) over 161 programs. types: 0 type conflicts in 25,649 nodes
both typed (25,649 agree, 0 refined) over 161 programs."

`WAT_DROP_CHECK=1 tools/verify.sh` next, same method. **`verify: ok`.** Fixpoint: "stage1 ==
stage2, byte for byte (507,634 bytes)" -- matching, byte for byte, the sandbox native chain's
own `s2`/`s3` fixpoint above (section "The native chain, redone with the fix"). `elf-run: ok`
-- identical shape to the check-off run: 103 native binaries, 54 agree with the interpreter, 3
use unimplemented syscalls (F-119), 11 refusals and 4 traps both ways; rules 0 conflicts over
161 programs; types 0 conflicts over 25,649 nodes.

## `tools/emitted.sh check`

The tree's own manifest predates this strike by two days (stone 3a's landing, Sep 28) and
would conflate every change since with this one, so the baseline had to be rebuilt: in
`/tmp/f210-sandbox`, the COMMITTED seed (`elf/out/compiler.elf` from real HEAD) compiling
`git show HEAD:elf/compile.wat` (check off) reproduces the known pristine-HEAD fixpoint
exactly (`408,007` bytes, matching `SCORE-stone-3b-fix-the-discovered.md`'s own number) --
confirmation the baseline is faithful. Its manifest, copied into the real tree in place of the
stale one, checked against a check-OFF rebuild of the real tree with the fix
(`tools/bootstrap.sh --fast`, seeded from the just-verified check-on compiler, fixpoint
410,790 bytes, matching the check-off `tools/verify.sh` run above): **31 of 103 programs
changed** (plus three `GONE` entries -- `drop-vec-cycle*.elf` -- that are leftovers of this
strike's OWN ad hoc sandbox probing caught in the baseline manifest's capture, not real-tree
programs; noise, not a finding). The original stale manifest was restored afterward.

**Both directions, both correct, by consumer:**
- **Shrinks** (most of the 31: `asmbits` -44, `fn-twice`/`freed`/`strbuild`/`strbuild2`/
  `strings`/`strown`/`strverbs` -11 each, `assocn`/`count-own`/`count-trie`/`deepvec`/`linear`/
  `moved`/`rec1`/`vecsum`/`vectors` -4 each, `borrowed` -8): `:c::share` now skips an increment
  it used to emit -- the exact F-210 shape, a value shared in one arm no longer pays for a
  reference it was about to move anyway.
- **Grows** (`cat32000` +19, `catx` +31, `grow2000000`/`grow200000`/`grow20000` +12 each,
  `memory` +45, `pass20000`/`pass80000` +60 each, `pvec` +8, `reader` +19): `grow20000.wat`
  (and `pass20000`/`pass80000`, its `user/add`-indirected twin) is `(if (= n 0) (length acc)
  (user/grow (- n 1) (user/add acc n)))` -- `acc` read by `length` in the THEN arm, used again
  in the ELSE arm's recursive call. The `length`/`strlen` drop decision (`elf/compile.wat:2666`,
  the same shape as `:c::drop-if-last` but its own inline check) asks the same `:c::last-use?`
  question; under the OLD one-node answer, the ELSE arm's mention (later in eval-seq order) WAS
  the global "last", so the drop never fired in the THEN arm -- a missed drop, a LEAK, every
  time the loop's `n` reaches 0. The fix makes the THEN arm's own read its own last use on ITS
  path, and the drop now correctly fires: more bytes, a leak closed, same root cause as the
  shrinks above, surfacing through a READ-site drop instead of `:c::share`'s move.

Fewer increments is the general direction (most of the 31 are shrinks), but not the only
correct one: a previously-missed drop at a READ site (not a move) is just as much F-210, and
costs bytes rather than saving them. Both are measured, both explained; nothing unaccounted
for.

