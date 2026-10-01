# SCORE — excursus 008 stone 3b-2: freeing to the bump

Struck by Claude Sonnet, 2026-10-01. Tree at HEAD `5ed2d00`. Written AS I GO per the brief.

## Status

- [x] Measure BEFORE
- [x] F1 sizes written
- [x] F2 free wired into `:c::dropchk-hex` / `:c::vec-glue-body` / `:c::node-glue-body`
- [x] a root found by STOP-2 and fixed (`:c::scratch-safe?`)
- [x] `tools/reads.sh` extended for F1's four new header reads
- [x] `tools/probe.sh` all `drop-*`/`f209-*` agree (24/24, my own run)
- [x] `WAT_DROP_CHECK=1 tools/probe.sh` all agree (24/24, my own run)
- [x] `drop-vec-cycle.wat` natively under `ulimit -s 256`, plain and check
- [x] native chain seed->s1->s2->s3 to a fixpoint, plain and check
- [x] Measure AFTER — an honest finding, not the fall F3's "today" numbers implied
- [x] `tools/verify.sh` → `verify: ok`
- [x] `WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok`
- [x] `tools/emitted.sh check`

## Plan

F1/F2 implemented entirely as new entries in the EXISTING drop-glue census/placement
machinery (`:c::glue-census` / `:c::glue-pass` / `:c::glue-place` / `:c::glue-body`),
rather than as new fixed routines in `elf/lib/runtime.wat`'s Layout. Five pseudo-types are
appended to the census unconditionally: `freestr`, `freerec` (shared by `rec:`/`henum:`,
same `len*8+16` shape), `freevec` (dispatches flat/owned/tree by the tag word), `freenode`
(the trie node's fixed 272-byte shape, called from `vec-glue-body`'s root-free and
`node-glue-body`'s child-free), and `closize` (a closure's size: a creation-site cascade
over every LIFTED function with captures, comparing the closure's code pointer against
each lifted function's own address, since the length word is overwritten with the code
address and cannot be read back). All five use the *same* proven `:c::emit`/`:c::patch`/
`:c::jmp-unpatched` idiom `:c::henum-glue-tags` already uses, not hand-counted hex offsets
-- chosen specifically to avoid re-deriving fragile byte-offset arithmetic by hand for new
code, and to avoid touching `elf/lib/runtime.wat`'s `:c::rt-count`/`:c::rt-nth`/`:c::lay`
chain at all (every one of F1's sizes is reachable this way).

**F1 — the sizes**, each matching the `elf/lib/runtime.wat` allocator it mirrors:
- `str`: `rt-cap(len)` (reused directly, the SAME function `rt-str-cat`/`rt-str-subs`/
  `rt-i64-to-str` call), `len` read from `[rax]`. Start `rax-8`.
- `rec:`/`henum:`: `len*8+16` (`rt-vec-new`'s own formula), `len` read from `[rax]`.
  Start `rax-8`.
- closure: `ncaps*8+16` -- same formula, but `ncaps` cannot be read from the object (the
  length word is overwritten with the code address at `:c::close-form`'s last store). A
  new `:c::Fn/ncaps` field (`(length syms)` at `:c::lift-fn` time, the same count
  `:c::close-push` fills at the one creation site) is compared against at the free site via
  the `closize` cascade. Start `rax-8`.
- flat Vector (`:c::vec-flat`): `len*8+24` (`rt-varr-new`'s formula). Start `rax-16`.
- owned flat Vector (`:c::vec-flat-own`): `rt-cap(len*8+8)` -- reusing `rt-cap` again; this
  reproduces `rt-vec-conj-own`'s own `grown-test` rounding exactly (`len*8+23` fed to the
  same bsr+shift `rt-cap`'s `+15` bias already does). One function, two callers.
- trie Vector (`:c::vec-tree`): fixed `varr-hdr + 2*word` = 40. Start `rax-16`.
- trie node: fixed `vec-hdr + node-arity*word` = 272. Start `rax-8`.

**F2 — the free**: in `:c::dropchk-hex`, the OLD fast path (`and (not dchk?) (not
has-glue?) -> bare dec`) is removed -- EVERY pointer type must now take the full
guard/dec/zero-check/body sequence, because freeing applies regardless of whether the type
has children-walking glue (a `str` never has glue and must still free). A non-pointer type
(reached because `:c::drop-hex` calls `:c::dropchk-hex` EAGERLY, in a `let`, before its own
`cond` decides whether to discard the result) keeps a bare `dec`, since `:c::free-target`
only knows the five pointer shapes. `body`'s plain-build half gains a `free-call-hex` (a
call to the right pseudo-glue routine above) BEFORE `call-hex` (the real glue, which walks
children) -- matching the CONTRACT's order exactly: free self, then glue drops what it
held, so a child whose block sat just below becomes youngest in turn. `vec-glue-body`'s
root-free and `node-glue-body`'s child-free get the same insertion, before their own
recursive children-walk call.

Only `elf/compile.wat` changed. `elf/lib/runtime.wat` is untouched.

## A root found by STOP-2: a bare name's own last use can now call, and the compiler's scratch-register optimizer did not know

**Symptom.** `tools/probe.sh` on a two-read fixture --
`(let [v (conj (Vector :- [i64]) 7)] (+ (nth v 0) (nth v 0)))` -- DIVERGED (native printed
a huge garbage number; the interpreter and `WAT_DROP_CHECK=1` both agreed on the right
one). A ONE-read fixture agreed. `WAT_DROP_CHECK=1 tools/probe.sh` on the SAME two-read
fixture also agreed -- the check build never underflows, so by the CRAWL's own rule this
is not (only) a counting defect; freeing itself is doing something a live computation
depended on not happening.

**Isolated with `objdump` on the native binary** (no symbols; fixed addresses, ASLR
irrelevant, `setarch -R`): `(+ (length v) (length v))` on `vec:i64` compiles to

```
4001fa: mov r11,rax        ; r11 holds the FIRST length's result (1)
...                         ; evaluate the SECOND length, then v's own last-use drop
400215: call freevec        ; v's count reached 0 here
40021a: pop rax
40021b: add rax,r11         ; r11 -- clobbered by freevec's own start/end math -- is garbage
```

**Root.** `:c::scratch-safe?` treats every LEAF node (a bare symbol's read included) as
unconditionally safe to hold a pending operand in a scratch register (`r8`-`r11`) across --
"a leaf emits nothing". Before this strike that was true: only a GLUE-bearing type's drop
could ever call anything, and `:c::quiet-head?` already kept `nth`/`length`/etc. off its
safe list for exactly that reason (a glue-bearing container's last use, read through one of
those heads, could call glue). Freeing makes EVERY pointer type's drop potentially call a
free routine -- so a bare name read ANYWHERE, if it happens to be that name's own last use,
can now also call, and nothing in `:c::scratch-safe?` ever asked.

**Confirmed the mechanism is universal, not confined to glue-less types**: the identical
`(+ (length v) (length v))` on `vec:str` (which already had REAL glue, and already called
it, even on the UNMODIFIED tree) diverges the same way on this tree, but agrees on the
pristine `elf/compile.wat` -- so freeing's NEW call, not glue's old one, is what newly
exposes the leaf case broadly (the register `freevec`/`freestr`/`freerec`/`closize` happen
to clobber, `r11`, was not the one the pre-existing glue path happened to use in that
specific shape).

**Fix** (`elf/compile.wat`, `:c::scratch-safe?`'s leaf case): a bare-symbol leaf is quiet
unless it is BOTH a pointer type and its own last use here (`:c::ptr-ty? (:c::lookup-ty-opt
env name idx)` and `:c::last-use? a name pg`) -- in which case it is not, and the
surrounding `+`/arithmetic falls back to the always-correct push/pop instead of a scratch
register. `:c::lookup-ty-opt` (not `:c::type-of`) on purpose: this is asked from more than
one pass, and `:c::noret?`, over a lifted closure's body, runs before captures are bound,
where a capture name is -- correctly, at that point -- one nothing binds yet; `:c::type-of`
refuses such a name outright, the direct lookup just answers "" (treated as "not a pointer
worth asking about", same as any other non-pointer leaf). This is the recursion's single
point of truth: `:c::kids-safe?`/`:c::all-safe?` already walk every subtree down to its
leaves, so this one change reaches `nth`/`length`/`if`/`cond`/`do`/`let`/`match` and
anything else that might read a dying pointer, without widening `:c::quiet-head?` itself
(which stays as it was).

**Confirmed fixed**: the exact repro (`length`+`length` and `nth`+`nth`, both `vec:i64` and
`vec:str`), `elf/probe/drop-match-arm.wat` (a SEPARATE crash this same change exposed --
`:c::match-arms` drops its all-unit `enum:` scrutinee through the now-eager
`:c::dropchk-hex`, which needed its own non-pointer fast path back, see F2 above), and
`elf/probe/drop-sum.wat` (the required fixture the scratch-safety shape hides in --
`length`, `sum`, `nth`, over a `vec:i64` built by a tail-recursive `conj` loop) all agree,
native vs interpreter, after both fixes.

## Before — peak RSS, on unmodified HEAD (`5ed2d00`)

Measured with `/tmp/maxrss` (built from `elf/bench/maxrss.c`), each fixture built the way
`tools/probe.sh` builds one (the interpreter runs `elf/compile.wat` with `:user::main`
replaced by a single `:c::compile` of the fixture), in a kept sandbox (`/tmp/before-3b2`,
not probe.sh's own, since that deletes its sandbox on exit).

| fixture | peak RSS (KB), first run | 8-run range |
|---|---|---|
| `drop-3b-recs` | 13024 | 11012–12772 |
| `drop-3b-closure` | 9224 | 8724–10584 |
| `drop-3b-list` | 79036 | 78740–79304 |

**The compiler compiling itself.** Running the committed `elf/out/compiler.elf` directly
in place fails deterministically on its OWN last compile step (`elf/compile.wat` ->
`elf/out/compiler.elf`, the 92nd of 92 programs, every time, not flaky) with
`assert failed: (:wat::test::assert-eq written filesz)` -- `open()` for write on the file
currently mapped and executing as this process returns `ETXTBSY`, a pre-existing property
of self-overwrite, not a regression. `tools/bootstrap.sh --fast` already works around this
by copying the committed binary to `elf/out/seed.elf` first and running THAT; I did the
same in a full-tree sandbox (`/tmp/stage1-before`).

| run | peak RSS (KB) |
|---|---|
| 1 | 441236 |
| 2 | 441316 |
| 3 | 440696 |

~441,000 KB, before.

## Probes — `tools/probe.sh`, plain and `WAT_DROP_CHECK=1`

All 24 required fixtures (every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus both
`f209-*`) agree, BOTH ways, on my own runs:

```
drop-3b-closure drop-3b-list drop-3b-recs drop-arm2 drop-arm drop-at1 drop-at3 drop-at4
drop-at5 drop-concat-box drop-conj drop-head drop-ifval drop-len drop-let-tail
drop-match-arm drop-ret drop-ronly-arm drop-shadow drop-sum drop-tail drop-twice
drop-vec-cycle f209-tier1-self-vec-build f209-tier1-self-vec
```

`drop-vec-cycle.wat`, built natively (sandbox `/tmp/dbg-vec-cycle`), under `ulimit -s 256`
with `setarch -R`: plain `"2000000"` exit 0; compiled under `WAT_DROP_CHECK=1` too,
`"2000000"` exit 0. Both ways, the required gate.

## `tools/reads.sh`: four new allowed reads

`tools/verify.sh`'s own `elf-run.sh` step failed first with `reads: FAIL -- a heap load
outside :c::read-out` at my four new `:c::mov-rm` calls (reading a String's length, a
record's/payload-enum's length, a flat Vector's length, a closure's code address -- every
one a HEADER FIELD read to size the free, never a reference handed anywhere, the same
shape stone 3b-1's G1 entries already carry an exemption for). Added to `tools/reads.sh`'s
`ALLOW` list with the same justification style and exact counts (`rdx` pattern once for
`:c::freestr-glue-body`; `r8` pattern twice, shared text, for `:c::freerec-glue-body` and
`:c::freevec-glue-body`; `r9` pattern once for `:c::closize-glue-body`).
`reads`/`copies`/`rsp` all `ok` standalone after.

## The native chain, plain and check (`/tmp/chain-3b2`, `/tmp/chain-3b2-check`)

Both sandboxes: committed `elf/out/compiler.elf` copied to `elf/out/seed.elf` (avoids the
self-overwrite `ETXTBSY` above), `elf/compile.wat` the real source with F1/F2 and the
`:c::scratch-safe?` root fix. `seed.elf` run DIRECTLY (not `--fast`) since the seed IS the
committed, unmodified binary.

**Plain** (no `WAT_DROP_CHECK`): `seed -> s1` 417,095 bytes; `s1 -> s2` 441,443; `s2 -> s3`
441,443. `cmp s2.elf s3.elf`: byte for byte identical. **Fixpoint.** Every hop: 92/92
programs `verified`, final `"compile: ok"`, no refusals.

**Check** (`WAT_DROP_CHECK=1` set for every hop, so each binary bakes in the poison guards):
`seed -> s1` 515,118 bytes; `s1 -> s2` 515,411; `s2 -> s3` 515,411. `cmp s2.elf s3.elf`:
byte for byte identical. **Fixpoint.** Every hop: 92/92 `verified`, `"compile: ok"`.

The one-hop size jump (`s1`->`s2` in both) is the expected "spurious DIFFER"
`tools/bootstrap.sh`'s own comment documents for any change to what is emitted: `s1`'s own
drop sites, wherever ITS OWN SOURCE runs through `:c::drop-hex` while the OLD seed is still
assembling it, are governed by what the seed already knew how to emit for a drop (the OLD
rule) -- `s2` is the first binary SHAPED by the new rule on both sides, and `s2 == s3`
confirms it reproduces itself. `441,443` (plain) and `515,411` (check) both match
`tools/verify.sh`'s own bootstrap fixpoint below exactly.

## `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`

**Plain**: `verify: ok` (`/tmp/verify-plain2.log`). Bootstrap fixpoint 441,443 bytes
(matches the sandbox chain above exactly). `elf-run: ok` -- 103 native binaries, 54 agree
with the interpreter, 3 use unimplemented syscalls (F-119), 11 refusals and 4 traps both
ways; `rules: 0 conflicts` in 14,504 argument-parameter pairs over 161 programs; `types: 0
conflicts` in 26,074 nodes over 161 programs. `reads`/`copies`/`rsp` all `ok`.

**Check** (`WAT_DROP_CHECK=1 tools/verify.sh`, run in sequence after the plain one, never
concurrently): `verify: ok` (`/tmp/verify-check.log`). Bootstrap fixpoint 515,411 bytes --
matches the sandbox chain's check fixpoint exactly. `elf-run: ok`, same shape as the plain
run (103 binaries, 54 agree, 3 F-119, 11 refusals + 4 traps both ways; `rules`/`types` 0
conflicts over 161 programs). `reads`/`copies`/`rsp` all `ok`.

## `tools/emitted.sh check`

The real tree's own manifest (`elf/out/.emitted-manifest`, dated before this strike) was
already stale against pristine HEAD (confirmed: a FRESH pristine bootstrap in
`/tmp/emitted-baseline` -- a full `elf/`+`tools/` copy with `git show HEAD:elf/compile.wat`
-- fixed-point at 410,790 bytes, matching the committed `elf/out/compiler.elf` exactly, and
its OWN freshly-saved manifest differs from the tree's existing one on nearly every entry).
I swapped the tree's manifest for the fresh pristine one, ran `check` against the real
tree's `elf/out/` (just rebuilt by `tools/verify.sh` above, so it carries F1/F2), then
restored the original stale manifest afterward (`/tmp/real-tree-manifest-stale-backup.txt`
kept, matching F-210's own practice for the same situation).

**91 of 100 programs moved, 0 new, 0 gone -- every move a GROW, none a shrink** (spot
checked: `arith` 887->4398, `fib` 3948->7459, `strings` 2683->5349, `rec` 3499->3779,
`bits` 4688->5078, `vectors` 4782->6061). This is the expected, full blast radius of F2:
`:c::dropchk-hex`'s old fast path (a bare `dec`, no call, for any type without real
census-based glue) is gone -- EVERY pointer drop site in EVERY program now carries a
free-call, and every program pays a small fixed cost for the five new pseudo-glue routines
(`freestr`/`freerec`/`freevec`/`freenode`/`closize`), placed once per program like the rest
of the glue section. The programs that did not move are presumably ones with no pointer
drop sites at all (pure `i64` arithmetic, no `String`/`Vector`/`rec:` use).

## F3 — the evidence: an honest finding, not the fall the brief's "today" numbers implied

**Peak RSS, before vs after, `/tmp/maxrss`, 8 runs each, sorted (KB):**

| fixture | before (sorted) | after (sorted) |
|---|---|---|
| `drop-3b-recs` | 11012 11180 11600 12552 12600 12608 12632 12772 | 11280 11428 11800 11920 12296 12648 12928 13000 |
| `drop-3b-closure` | 8724 8860 9120 9284 9312 9672 9996 10584 | 8848 9272 9412 9724 9824 10076 10300 10308 |
| `drop-3b-list` | 78740 79036 79304 (3 runs) | 78252 78648 78920 (3 runs) |

**The two distributions overlap completely for `drop-3b-recs`/`drop-3b-closure`.** No
measurable fall, at 50 rounds OR at 500 (ran `drop-3b-recs` at 10x the rounds to separate
signal from noise: before 110644-111064 KB, after 111316-111528 KB -- still
indistinguishable). `drop-3b-list` moves a few hundred KB, consistent with "by its head
cells" and within the same noise band.

**This is not a correctness question -- F1/F2 are proven correct** (24/24 probes both
builds, the native chain's fixpoint, `drop-vec-cycle` under `ulimit -s 256`). It is a
question of how much of these TWO fixtures' memory a pure bump-allocator can EVER reclaim,
and I instrumented it rather than guess.

**`gdb`, breakpoints on `freevec`'s own three `cmp r11,r15` youngest-tests** (a 3-round,
5-element version of the `drop-3b-recs` shape, `/tmp/dbg-flat3`, addresses found by
disassembling the kept binary, no symbols needed -- fixed, non-PIE, ASLR off via
`setarch -R`): the OWNED-case comparison fires exactly once per round (3/3), confirming
F2's call IS reached and the Vector IS exclusively owned (tag `vec-flat-own`, `r9`=64,
matching `rt-cap(len*8+8)` for `len=5` exactly) -- but the comparison FAILS every time:
`r15` sits 352 bytes past where the Vector's own block ends, not 64. **Freeing is firing
and computing the textbook-correct size; it is the YOUNGEST test that never holds for this
shape.** I did not fully root why 288 extra bytes sit above the final Vector by the time
`user/total`'s base case drops it (one candidate not ruled out: `conj`'s own "drop the
pre-conj container" accounting, which the disassembly shows runs on the SAME pointer value
when `vec_conj_own` grows in place rather than copies -- a decrement to zero on an object
about to be reused, immediately followed by a re-pop of that same pointer; whether that is
itself benign by construction, or is where the 288 bytes comes from, is an open question I
am handing back rather than guessing at). What IS established: a Vector built by
`conj`-ing one element at a time, each element itself a fresh allocation (a `:user::Row`, a
`String`), gives the NEW element's own allocation nowhere to go but ABOVE the vector being
extended -- so the bump allocator's "is it youngest" test is adversarial to exactly this
build shape, by construction, independent of anything stone 3b-2 did right or wrong. M2
(the real allocator, hole reuse) is out of scope by the CRAWL's own word, and is what would
actually reclaim this.

**Where freeing DOES show up**: every probe and the native chain prove the mechanism frees
correctly whenever an object genuinely IS youngest (a single `nth`/`length` read of a
freshly conj'd Vector, `simple3` in my own debugging, frees to a handful of bytes). The two
F3 fixtures simply are not that shape at the scale tested.

**The compiler compiling itself, before vs after** (the measure the builder cares about
most): running MY OWN fixpoint binary (`/tmp/chain-3b2/elf/out/s2.elf`, copied to
`seed2.elf` to dodge `ETXTBSY` the same way) compiling the whole corpus, under
`/tmp/maxrss`:

| run | peak RSS (KB) |
|---|---|
| 1 | 460676 |
| 2 | 458660 |
| 3 | 458948 |

**~459,500 KB after, vs ~441,000 KB before -- UP about 4%, not down.** This is the same
finding as the two fixtures above, at the scale that matters most: `tools/emitted.sh`
already showed every program the compiler builds grew (91 of 100), so the compiler itself,
compiling its own larger corpus with more code to assemble per drop site, does MORE WORK
and holds MORE live data WHILE compiling -- and the memory F2 manages to give back (proven
real, by the probes and the chain, whenever an object is genuinely youngest) is not enough
to offset that cost for this workload. I am reporting this plainly rather than calling it
settled: the "today" numbers the brief quotes (11,424 / 8,860 KB) are a point BEFORE this
strike existed to compare against, not a target I hit, and the compiler's own peak RSS
moving the WRONG way is the more important fact for the next strike (3b-3, closures and
the recursive worklist) and for M2 (the real allocator) to inherit, not paper over.
