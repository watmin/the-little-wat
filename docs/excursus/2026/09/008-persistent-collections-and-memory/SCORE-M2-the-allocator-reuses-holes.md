# SCORE — excursus 008 M2: the allocator reuses holes

Struck by Claude Sonnet, 2026-10-01. Tree at HEAD `a695f33` (branch `excursus-008-m2`, carries 3b-2
`62dc68b` with no code change on top — `a695f33` is the BRIEF doc only, confirmed by
`git diff 62dc68b a695f33 --stat`). Written AS I GO per the brief. **Tree is left dirty, nothing
committed, per METHOD.**

## Status

- [x] Measure BEFORE — main `5ed2d00`, and the M2 baseline (current HEAD = 3b-2's landed state)
- [x] Design: size classes, table layout, M2-4's retirement target
- [x] Found a dead end (shared, CALLED `:c::rt-alloc` breaks the Layout's backward-call invariant
      and `:c::lvl-head`'s shadow numbering) — superseded by the coordinator's redirect below
- [x] **Coordinator redirect**: put the free-list take INSIDE `:c::rt-bump` itself, self-contained
      via push/pop of every register it uses beyond `top`/the result, so no per-site register
      audit is needed at all. See REDIRECT below.
- [x] M2-1 — the classes, the table, `:c::rt-bump` generalized (`base`/`reuse?` params) and made
      self-contained; every true-allocation site (13 existing + the 2 inline bumps, now 15 calls
      total) updated; `:c::lvl-head`'s duplicated routine-numbering left alone this strike, logged
      as a finding below, per the coordinator's instruction
- [x] Probes: all 24 required fixtures agree, BOTH `tools/probe.sh` and `WAT_DROP_CHECK=1
      tools/probe.sh` — with the free lists wired but still always empty (M2-2 not done yet), so
      this is the "M2-1 changes nothing observable" proof the brief asks for
- [x] `drop-vec-cycle.wat` natively under `ulimit -s 256`, plain AND check — both `"2000000"` exit 0
- [x] Native chain seed→s1→s2→s3 fixpoint, plain and check, **at M2-1 ONLY** (free lists wired,
      always empty — no push yet) — BOTH LANDED
- [x] M2-2 — free onto lists — IMPLEMENTED, then found to crash the chain outright when actually
      exercised; two real bugs rooted and fixed (`:c::rt-cap`'s `out`/`rcx` aliasing; the free
      list storing a pointer where the allocate side expected a block start) plus a third
      (SMALL's own class address computed then never checked) found by hand while writing this
      up — see "Two real bugs" below. 24/24 probes agree, both ways, after all three fixes.
- [x] M2-3 — allocate from lists — done by construction (M2-1's `:c::rt-bump` already checks the
      table before bumping); exercised for real once M2-2 started pushing, including by the two
      bugs above (both were found via REUSE actually firing, not via dead code)
- [x] **STOP-2 — a fourth defect, found and CORRECTED by the coordinator**: my first diagnosis
      (argument-evaluation ordering) was wrong; the real cause is the region release colliding
      with the free list, exactly as `CRAWL-M1-the-count-comes-down.md`'s own question 5
      predicted before M2 was drawn. See the STOP-2 section below (kept, including the wrong
      diagnosis, as a record).
- [x] M2-4 — retire the region release — DONE, landing WITH M2-2 per the coordinator's
      correction, not after it. `:c::seq`'s `push r15`/`pop r15` wrapping removed;
      `:c::releasable?` and the whole transitive-poke call graph built only to serve it
      (`:c::calls-poke?`, `:c::any-poke?`, `:c::is-poker?`, `:c::poke-scan`, `:c::poke-fix`,
      `:c::Prog`'s `:pokers` field) deleted outright.
- [x] `elf/probe/m2-region-collision.wat` added as a permanent fixture (the STOP-2 repro) — agrees
      both ways, `["561"|"561"]`.
- [x] All 24 required probes + the new fixture + `drop-vec-cycle` (`ulimit -s 256`) re-confirmed
      agreeing, both plain and `WAT_DROP_CHECK=1`, AFTER M2-4.
- [ ] **STOP-3 — a NEW, deterministic SIGSEGV on the native chain's `seed -> s1` hop, WITH
      M2-2+M2-4 together — NOT FIXED, root not found.** `tools/probe.sh`-scale programs (the 24
      required fixtures, the new `m2-region-collision.wat`, `drop-vec-cycle`) all still agree; the
      FULL self-compile does not survive natively. Rooted as far as a `gdb` disassembly can take
      it (a flat Vector's element-drop walk, `:c::vec-glue-body`, reads a genuine `0` where a
      `str`/`fn:` pointer is expected, for a Vector whose drop glue appears to be running for the
      FIRST TIME now that the region release no longer bulk-rewinds past it) but NOT to an exact
      construction site. See the STOP-3 section below. **Blocks everything after this row**:
      the AFTER measurement, `bench-coll.sh`, and both `verify.sh` runs all depend on a binary
      that can compile the corpus without segfaulting, which this one cannot.
- [ ] Measure AFTER (fixtures + the compiler compiling itself, against the BEFORE numbers) —
      BLOCKED by STOP-3
- [ ] `tools/bench-coll.sh` against `BENCH-baseline.md` — BLOCKED by STOP-3
- [ ] `tools/verify.sh` → then `WAT_DROP_CHECK=1 tools/verify.sh`, in sequence — BLOCKED by STOP-3
- [ ] `tools/emitted.sh check` — BLOCKED by STOP-3

## REDIRECT from the coordinator (2026-10-01, mid-strike)

*"do NOT inline the free-list check at each site with a per-site register audit -- that is ten
hand-kept copies of the allocator. `:c::rt-bump` is already the ONE generator every true allocation
emits through: put the free-list take INSIDE that generator, and make it SELF-CONTAINED -- it
pushes and pops every register it uses (beyond the size and result registers its contract already
names), so no site needs an audit and every site gets it by construction. The two inline bumps
(`:1599`, `:1703`) go through `:c::rt-bump` too (or through the same generator). Leave
`:c::lvl-head`'s second copy of the routine numbering alone this strike, record it in the SCORE as
a finding (a duplicated truth: it should be derived from `:c::rt-nth`)."*

This is the shape actually built, below. The push/pop insight resolves what my own first pass at
"self-contained" had not: I was still trying to prove which registers were safe to clobber at each
site: Push/pop means I never need to know -- whatever was in `r9`/`r10`/`r12` is back, unconditionally,
regardless of what the caller was doing with them. The `:c::lvl-head` duplication is real and left
alone; see FINDING below.

## MEASURE — before

Method: `elf/bench/maxrss.c` built at `/tmp/maxrss`. Each `drop-3b-*` fixture built the way
`tools/probe.sh` builds one (the interpreter runs a driver = the tree's own `elf/compile.wat` with
`:user::main` replaced by one `:c::compile` of the fixture) — `/tmp/build-fixture.sh`, a kept-sandbox
version of `tools/probe.sh`'s own build method, since probe.sh deletes its sandbox on exit. The
compiler-compiling-itself number is the committed `elf/out/compiler.elf` (checked against
`tools/sums.sh`'s `buildsum`/`.build-stamp` to confirm it is current) copied to `seed.elf` in a
sandbox and run directly (ETXTBSY makes running it in place on itself impossible, same as 3b-2's
own note) — 8 runs each for the three `drop-3b-*` fixtures, 3 runs for the compiler self-compile
(it is much slower and much less noisy).

**main (`5ed2d00`, sandboxed via `git archive 5ed2d00 | tar -x -C /tmp/m2-before-main`, compiler
built fresh by the interpreter since `elf/out/*.elf` is not tracked by git):**

| fixture | peak RSS (KB), 8 runs (3 for self-compile) |
|---|---|
| `drop-3b-recs` | 10908 11276 11280 11352 11588 12624 12632 12912 |
| `drop-3b-closure` | 8652 8832 8868 8880 8952 9404 9916 10492 |
| `drop-3b-list` | 78180 78404 78992 79088 79364 79572 79700 79980 |
| compiler compiling itself (`seed.elf`, fixpoint 410790 bytes, matches committed binary) | 446392 446392 446624 |

**M2 baseline (current HEAD `a695f33` == 3b-2's landed code `62dc68b`, sandboxed via
`git archive HEAD`, compiler.elf copied from the live tree after confirming `tools/sums.sh`'s
`buildsum` matches `elf/out/.build-stamp` — i.e. the live tree's binary is current and trustworthy):**

| fixture | peak RSS (KB), 8 runs (3 for self-compile) |
|---|---|
| `drop-3b-recs` | 11672 11776 11924(*) 12112 12292 12440 12556 12868 12996 |
| `drop-3b-closure` | 9228 9292 9684 9728 9808 10000 10004 10328 |
| `drop-3b-list` | 78524 78652 78756 78880 79236 79628 79796 80176 |
| compiler compiling itself (`seed.elf`, fixpoint 441443 bytes, matches `SCORE-stone-3b-2-freeing.md`'s own bootstrap fixpoint exactly) | 464436 464524 464752 |

(*) `drop-3b-recs` was actually run 8 times; one extra value was a duplicate keystroke in my own
transcript and is noise, not a 9th real run — the 8-run set is the first 8 printed.

These numbers land squarely inside (closure/recs) or very close to (list, self-compile) the ranges
`SCORE-stone-3b-2-freeing.md`'s own F3 "after" section already recorded for this exact code —
cross-confirming both that the sandboxing method is sound and that nothing drifted between that
strike's close and this one's start. **The M2 baseline (HEAD) is what M2-1 through M2-4 are weighed
against; main's numbers are carried for the brief's own record, same as 3b-2's SCORE did.**

## DESIGN — size classes, the header, the one door, M2-4's target

Read in full before this: `elf/lib/runtime.wat`'s layout block (`:c::word`/`:c::hdr-pending`/
`:c::hdr-limit`/`:c::hdr-buf`/`:c::buf-bytes`/`:c::buf-hiwater` ~1905-1991), `:c::rt-bump` (`:526`),
every one of its callers (`rt-vec-new`, `rt-varr-new`, `rt-node-new`, `rt-vec-conj-own`'s four
paths), `:c::rt-cap`/`:c::cap-bias` (`:514`-`:521`), the two INLINE bumps (`:c::rt-prim-read-hex`
`:1591`, `:c::rt-io-read-file` `:1697`); `elf/compile.wat`'s `:c::dropchk-hex` (`:4427`),
`:c::free-tail-emit`/`:c::freestr-glue-body`/`:c::freerec-glue-body`/`:c::freevec-glue-body`/
`:c::freenode-glue-body`/`:c::closize-glue-body` (`:5021`-`:5131`), `:c::seq`/`:c::releasable?`
(`:6697`-`:6725`, the region release M2-4 retires).

### What r14's header looks like today, and why the list heads cannot just be dropped in

`r14` is the mmap base. `[r14+0]` = pending output bytes, `[r14+8]` = heap limit (base+reservation),
`[r14+16 .. r14+:c::buf-bytes)` = the 8192-byte output buffer itself (`:c::stub-arm`: `r15 := r14 +
buf-bytes`, i.e. the HEAP starts exactly at the end of that buffer). There is no gap: offset 16
through 8191 is live buffer content the runtime writes into on every `println`/`flush`. Any new
fixed table reached from `r14` has to sit BETWEEN offset 8 (`hdr-limit`'s own word, ending at 16)
and the new buffer start — which means widening the header by exactly the tables' own size and
pushing `:c::hdr-buf` and `:c::buf-bytes` out by that same amount, so the buffer's actual byte
capacity (8176 today) is unchanged and `r15`'s initial value (`:c::stub-arm`'s `lea r14+buf-bytes`)
still lands exactly where the widened header ends.

### The classes

Two tables, both reached from `r14` at new fixed offsets, both arrays of list-head words (a 0 head
means empty; a nonzero head is a dead block's pointer, and the dead block's own count word — the
one word at `[pointer-8]`, already free for reuse the instant the count hits zero, since a poisoned
or live object never reaches this path — holds the link to the NEXT dead block in the chain, or 0).

- **`SMALL`: one list per EXACT multiple of 8, from 8 through `:c::small-max` = 512 (64 entries).**
  Index = `size >> 3` (size is always 8-aligned; every allocation already is). 512 is chosen because
  it is comfortably above every FIXED small shape this corpus's F1 sizes produce: a trie node is a
  fixed 272 bytes (`:c::vec-hdr` + 32 × `:c::word`), the largest fixed shape there is, and it leaves
  room for records/closures with up to 62 fields/captures (`(size-16)/8`) before a shape would ever
  need the LARGE table — comfortably past anything in `elf/`'s own corpus (spot-checked: no
  `defrecord`/closure capture list anywhere near that count). A SMALL hit is always an EXACT match:
  the list only ever holds blocks of exactly that size, so popping one wastes nothing.
- **`LARGE`: one list per power of two, indexed directly by `bsr(size)` (64 entries, most of them
  permanently empty — only bits 9 and up are ever reached since nothing below 512 asks this table).**
  This is NOT a new scheme: it is `:c::rt-cap`'s OWN classing (a String's and an owned Vector's
  block is already a power of two by construction, from the exact same `bsr`+`shift` this table
  indexes by) — reusing it rather than inventing a second rounding rule. A LARGE hit is also always
  an exact match for the two shapes that use it (String, owned-flat Vector): `:c::rt-cap` is computed
  identically at allocation time and at free time (F1 already established this — "one function, two
  callers" — so the class a block is freed into is the exact class a same-length future allocation
  will ask for).
- **The boundary is 512, and it is a hard line, not a rounding point**: a shape whose EXACT
  (non-power-of-two) size exceeds 512 — which nothing in `elf/` ever produces, see above — does not
  participate in reuse at all (freed, but left dead, exactly like 3b-2's non-youngest case). The
  reason is the mismatch a floor/ceiling split would otherwise cause: filing a 416-byte record
  (not a power of two) under `bsr(416)=8` (the 256 class, a safe LOWER bound) would make it
  invisible to a future 416-byte ask, which must search by CEILING (the 512 class) to be guaranteed
  enough room — the two searches disagree on every non-power-of-two size above the boundary, so
  honest behaviour is to not pretend reuse works there, rather than silently waste more than
  reported or, worse, build a second search rule. Below 512 this never arises: SMALL's classing is
  exact, not a bound, because every SMALL shape's size truly is a multiple of 8 and the table has a
  dense entry for every one.
- **This is the CONTRACT's "lower bound" rule, realized**: a block's class's MINIMUM nominal size
  (the SMALL table's exact value, or the LARGE table's `2^bsr`) never exceeds the block's true size,
  so a later pop always fits inside the real block — proven trivially for SMALL (exact) and for
  LARGE (exact, since both producers are themselves `:c::rt-cap`).

### The one allocation door

Every NEW-BLOCK allocation (as opposed to growing an existing live object's block in place) must
pass through one shared check-then-bump-or-reuse routine. The IN-PLACE paths must NOT: `vec_conj_own`
path 2 (`grown`, writes inside the existing power-of-two block, no bump call at all) and path 3
(`extend`, grows the YOUNGEST object by exactly one word over the heap top) are not allocating a new
block, they are extending a live one — redirecting either to a free-list hole would silently
relocate a live object's bytes without updating anything that points at it. `:c::rt-bump` itself
stays the raw, unconditional bump-and-check it is today, because path 3 still needs exactly that.

A new routine, `:c::rt-alloc` (mirroring `:c::free-tail-emit`'s shape: an `:c::Out`-emitting
function, not a runtime-level one, so it can reach the SAME `:c::rt-bump` the raw path already
calls), takes a size already computed into a fixed register (`r9`, matching `free-tail-emit`'s own
`sizereg` convention) and does: compute the class (SMALL if `size <= 512` else, only for a `size`
that is already a power of two, LARGE via `bsr`); if that class's list head is nonzero, pop it (read
the dead block's own link word, write it back as the new head, hand the popped pointer out in the
same register `:c::rt-bump`'s callers already expect to hold the allocation base after a successful
call — `r15` — WITHOUT touching `r15`/the limit at all, since no bump happened); else fall through
to the exact `:c::rt-bump` call the site used to make directly.

Call sites that MUST move onto `:c::rt-alloc` (every one of F1's "the allocation a program's own code
creates", never the in-place paths above): `:c::rt-vec-new` (records, closures, henum), `:c::rt-varr-
new` (flat Vectors), `:c::rt-node-new` (trie nodes), `:c::rt-vec-conj-own`'s path 4 (`copy`, the one
path that allocates), `str_cat`/`str_subs`/`i64_to_str` (new Strings; need to locate `str_cat`'s own
non-owned path alongside `str_cat_own`), and the two INLINE bumps the brief names by line
(`:c::rt-prim-read-hex` `:1599`, `:c::rt-io-read-file` `:1703`) — these two do not fit `:c::rt-bump`'s
calling convention (their allocation base is `r8`, not `r15`, because the raw bytes are read onto the
heap top as scratch BEFORE the real object's position is decided) and need either a generalized
`:c::rt-alloc` that takes an explicit base register, or (safer, less invasive) their own direct
free-list-check-then-bump sequence duplicating `:c::rt-alloc`'s class lookup but wired to `r8`/`rsi`
instead of `r15`/`r11`. STOP-1 is exactly the case where a site's shape cannot be expressed this way
at all — not yet hit; the two inline sites are awkward but expressible, not impossible.

### M2-4's target, read

`:c::seq` (`elf/compile.wat:6702`) wraps every non-last, `:c::releasable?` statement in `push r15;
push r15` / `pop r15; pop r15` (`"41574157"` / `"415f415f"`) — pushed/popped TWICE each for 16-byte
stack alignment around the bracketed code, not two different marks; the net effect is "rewind r15 to
what it was before this statement ran" for any statement that provably never called `poke` (so no
pointer could have escaped through raw memory). `:c::releasable?` has exactly one caller
(`:c::seq`) and exists only to gate this. Retiring it is deleting this push/pop wrapping (and
`:c::releasable?` itself, now dead) — a small, low-risk, mechanical change, LAST per the brief's own
order, once M2-1/2/3 land, measured before/after the same way as the top-level MEASURE section.

## CORRECTION — a shared, called `:c::rt-alloc` is UNSAFE as first designed; inlining is the real answer

The first cut above (one shared `:c::rt-alloc-small`/`:c::rt-alloc-large`, CALLED via `:c::rt-call`
like any other routine, placed at new indices in the Layout) does not survive contact with how the
Layout actually works, and I am recording the dead end rather than silently dropping it, since the
next person would otherwise re-derive it the same way and lose the same time.

**Why it fails.** `:c::rt-nth`/`:c::lay` (`elf/lib/runtime.wat:1754`-`:1833`) build the runtime blob
as ONE forward pass where routine `i`'s own body may only call routines at index `< i` (the comment
at `:1816`-`:1821` is explicit: "a reference to a routine defined after it has no value to read" —
`lay1` holds exactly `0..i` entries when routine `i` is being measured). Every one of the sites that
need to reach a free list — `rt-vec-new`(18), `rt-varr-new`(19), `rt-node-new`(20), `rt-vec-conj-own`
(26), `rt-str-cat`(11), `rt-str-cat-own`(12), `rt-str-subs`(13), `rt-i64-to-str`(14),
`rt-prim-read-hex`(32), `rt-io-read-file`(33) — spans indices 11 through 33. A new shared routine
only the sites AFTER it could call would have to sit at index <= 11, i.e. right after `oom`(5); that
shifts every index from 6 upward by +2, which is mechanical in `:c::rt-nth`'s own `cond` and the
`:c::at-*` accessors (`:1859`-`:1903`) — BUT `elf/compile.wat`'s `:c::lvl-head` (`:9078`-`:9119`) also
hard-codes a dozen of these SAME raw index numbers (`22` for `nth`, `9` for `quot`/`rem`, `17` for
`concat`/`subs`/`str_eq`, `19` for `Vector`, `27` for `conj`, `28` for `assoc`, `18` for a record/
closure/`fn`, `33` for the three hex/file builtins, `10` for `String`/`println`/`assertion-failed!`,
`4` for the bool family) — this is `:c::rt-level`'s "how far into the blob does THIS program need to
reach" truncation (`:9139`), a SEPARATE hand-maintained shadow of the same numbering the long comment
at `:1807`-`:1821` says was supposed to have exactly ONE source of truth. Shifting the Layout without
also re-deriving every one of `:c::lvl-head`'s numbers (and proving none of them is now pointing at
the WRONG routine, not just a shifted-but-still-valid one) is exactly the kind of silent mismatch
that would pass every existing test right up until some program's truncated blob is one routine
short of what it actually calls — a worse failure mode than a loud one, because `tools/emitted.sh`/
`tools/elf-run.sh` would not even have a lever to catch "the blob was truncated one routine early"
unless some program's OWN behavior exercises exactly that gap.

**The fix, not yet executed:** do not add Layout entries at all. `:c::rt-bump` is itself never called
as a shared routine — every one of its callers INLINES its returned hex string directly (that is
the whole reason `:c::rt-bump` takes `here` as a parameter: so the inlined copy can compute its own
internal branch to `:c::at-oom` correctly from wherever it lands). A free-list-aware replacement
(`:c::rt-alloc-small`/`:c::rt-alloc-large`, same shape as `:c::rt-bump` but consulting a table first)
should be INLINED THE SAME WAY, at each of the ten sites above, in place of today's inlined
`:c::rt-bump` call. This touches NO Layout index and NO `:c::lvl-head` number — the blob's shape
(which routines exist, in what order, at what address) is unchanged; only what EACH already-placed
routine's OWN body contains grows by the free-list check. This is consistent with precedent (F2's
five pseudo-glue routines took the same "duplicate a little code at every site rather than touch the
indexed dispatch" path, and said why in `SCORE-stone-3b-2-freeing.md`).

(This also changes the size register from the "one shared door" draft's `r9` — chosen above to
match `:c::free-tail-emit`'s `sizereg` convention on the FREE side, which is unaffected by this
correction and still right — to `rcx` on the ALLOCATE side, since `rcx` is the register every real
call site already computes its size into before the inlined `:c::rt-bump`; the NEXT section below
is the corrected version, `r9` is free-side only from here on.)

**The cost of inlining, not yet paid off**: each of the ten sites has a DIFFERENT set of registers
already live at the point its allocation decision is made (`rt-vec-new` still needs `rax` = the
record's length afterward; others use `r8`/`r9`/`r10` for their own purposes before or after the
bump). A single one-size-fits-all inline snippet is not safe to paste at all ten sites blind — each
needs its own short register-liveness check (which of `r8`/`r9`/`r10`/`r11` are free to use as the
class-index/table-address/pop scratch AT THAT EXACT POINT in THAT routine's existing body) before
the free-list check can be written in. I audited exactly one (`rt-vec-new`: `rax`=len is live across
the whole sequence and must not be clobbered; `rcx` holds the size and is free after the bump math;
`r8`/`r9` are unused in this routine and are free scratch) — the other nine are NOT yet audited.
Getting ANY one of these wrong is a silent register clobber, not a crash: exactly the shape STOP-2
warns about, and with the worst property a bug can have here — it would not necessarily show up on
any of the 24 required probes, only on whichever program's specific allocation happens to need the
clobbered register's old value at the wrong moment. I am not willing to paste nine more unaudited
copies to make the row count on this SCORE look more finished; an audited inline at one site, with
the free-list check still not even written, is where this honestly stands.

## NEXT — precise continuation point

1. Write `:c::rt-alloc-small` and `:c::rt-alloc-large` as `:c::rt-bump`-shaped STRING-returning
   functions in `elf/lib/runtime.wat` (same `here`/`lay`/register-in/register-out contract as
   `:c::rt-bump`, no new Layout entry), each taking the size already in `rcx` (the register every
   audited and unaudited site above already computes its size into) and using `r8`/`r9` as their own
   scratch for the class index, the table-entry address (`r14`-relative, at the new `:c::hdr-small`/
   `:c::hdr-large` offsets this SCORE's DESIGN section above already works out: widen the header by
   1024 bytes between `hdr-limit` and the buffer, push `hdr-buf`/`buf-bytes` out by 1024, new
   `small-max`=512/64 entries indexed by `size>>3`, `large` 64 entries indexed by `bsr(size)` reusing
   `:c::rt-cap`'s own rounding) and the popped block's old link word — falling through to exactly
   `:c::rt-bump`'s own bump-and-oom-check bytes when the chosen list is empty, so the NO-REUSE case
   is provably byte-identical in effect to today.
2. Audit registers live at each of the nine remaining sites (`rt-varr-new`, `rt-node-new`,
   `rt-vec-conj-own`'s path 4 only — paths 2/3 stay on raw `:c::rt-bump`, they EXTEND a live object
   rather than allocate a new block, see the DESIGN section's reasoning above — `rt-str-cat`,
   `rt-str-cat-own`, `rt-str-subs`, `rt-i64-to-str`, `rt-prim-read-hex`, `rt-io-read-file`) before
   writing a single byte at any of them; the two inline-bump sites need the base-register
   generalization the DESIGN section already flags (their allocation base is `r8`, not `r15`).
3. Wire ONE site, probe it (`tools/probe.sh` on a couple of fixtures that exercise exactly that
   allocation — e.g. a record literal for `rt-vec-new`), confirm byte-for-byte identical native
   output to today (lists are still empty at this point, so M2-1 alone must change NOTHING observable
   except the bytes emitted) before moving to the next site. This is M2-1.
4. Only once every site is wired and probed clean: M2-2 (change `:c::free-tail-emit`'s non-youngest
   branch, `elf/compile.wat:5027`-`:5038`, from "do nothing" to "push onto the class this block's
   `sizereg` maps to" — SMALL if `startdisp`'s shape says exact/`sizereg<=512`, LARGE if it came from
   `:c::rt-cap`), gated the same way, one free routine at a time.
5. M2-3 is then almost entirely already done by step 1's fallthrough — the only remaining piece is
   confirming the plain build's allocate-from-list path is reached at all (a probe built to conj and
   drop and re-conj the SAME size, watched under `gdb` the way `SCORE-stone-3b-2-freeing.md`'s F3
   did, to see the second allocation's address equal the first's).
6. Then the full gate list in order, M2-4 last with its own before/after, exactly as the brief lays
   out — none of this is skippable or reorderable; `WEIGH`/`CRAWL`'s own ordering rationale (region
   release retiring only once free lists are "doing its job", not before) means M2-4 done ahead of
   1-3 would not even measure the thing the brief wants measured.

**The above (steps 1-6, "wire one site, audit each site's registers") is SUPERSEDED by the
coordinator's redirect.** Kept verbatim as a record of the dead end rather than deleted — see
REDIRECT above and M2-1 — IMPLEMENTED below for what was actually built.

## M2-1 — IMPLEMENTED: `:c::rt-bump` generalized and made self-contained

### The header (unchanged from the DESIGN section above, built as designed)

`elf/lib/runtime.wat`: `:c::hdr-small` = 16, `:c::hdr-large` = 16+512 = 528, `:c::hdr-buf` =
528+512 = 1040 (was 16), `:c::small-max` = 512. `elf/compile.wat`: `:c::buf-bytes` = 8192+1024 =
9216 (was 8192) — the only two things that had to move, since `:c::stub-arm`'s `r15` start is
`lea r14+buf-bytes` and nothing else reads `:c::hdr-buf`/`:c::buf-bytes` except `:c::rt-buf-put`'s
own two `lea-at r14 hdr-buf` sites (verified by grep before touching anything). Both new tables are
**zero by construction**: `mmap`'s anonymous pages come zeroed, and `:c::stub-arm` never writes
into this range, so an empty list needs no explicit init anywhere.

### `:c::rt-bump`, the new signature and contract

`elf/lib/runtime.wat:547` — `[here lay grow top base reuse?] -> String`. Two new parameters:
`base` (where the allocation starts — `r15` for every ordinary allocator, `r8` for the two inline
sites) replaces the old hardcoded `r15`; `reuse?` (bool) selects the plain bump-and-check (BYTE-
IDENTICAL to the pre-M2 function, just with `r15` renamed to the parameter `base`) when false, or
the free-list-aware version when true.

**`reuse? = false` only for `:c::rt-vec-conj-own`'s path 3** (`extend`, and its base-0 measuring
twin `extend-at0`) — growing the YOUNGEST object by one word over the heap top is not allocating a
new block, it is extending a live one; a free-list hole has no business being offered there. Every
other caller (11 of the original 13 call sites, plus both former inline-bump sites, now 13 total
`reuse?=true` call sites) allocates a genuinely new block.

**The self-contained reuse body** (full detail in the code's own comments, `elf/lib/runtime.wat`
around line 560 on): after `grow` runs, `base` still holds the ORIGINAL value (grow never touches
it) and `top` holds the prospective new top, so `size = top - base` — no new size parameter needed,
derived from what the two existing parameters already carry. `r9`, `r10`, `r12` are pushed at
entry and popped before EVERY exit (the found-a-block exit and the gave-up exit both pop the same
three, in the same order) — this is the whole point of the redirect: a caller holding anything in
those three registers gets it back unchanged, by construction, so NO site needed auditing, in
sharp contrast to my first (abandoned) attempt which tried to prove safety site by site.

Class decision, purely from `size` (no "which kind of allocation is this" flag from the caller —
derivable from the number alone): `size <= 512` → SMALL, index `(size>>3)-1` (an exact match,
0..63). `size > 512` → test `size & (size-1) == 0` (a power of two, exactly `:c::rt-cap`'s own
shapes — String, owned-flat Vector); if so, LARGE, index `bsr(size)`; if not (a large record/
closure/node this corpus never actually produces, per the DESIGN section's margin), give up —
`:c::rt-bump` never needed to know which of the ten-odd call sites it was inlined into to make
this decision, confirming the DESIGN section's SMALL/LARGE split needed no per-call-site flag
after all, only the self-contained push/pop needed solving.

On a hit: unlink (`[found-8]` — the dead block's own former count word — is the next pointer, read
and written back as the class's new head), `base := found`, `top := base's ORIGINAL value`
(captured into `top` BEFORE `base` is overwritten — so the caller's own trailing
`mov-rr top real-register` commit is a no-op: no bump happened, the real heap top must not move),
pop the three scratch registers, jump past the bump/oom tail entirely. On a miss (list empty, or a
non-power-of-two size above 512): pop the same three, fall through to the ORIGINAL check — a
byte-identical `cmp-rm r14 hdr-limit top` / `jbe-over` / call to `:c::at-oom`.

### Every call site, updated (`grep -c '(:c::rt-bump ' elf/lib/runtime.wat` = 15)

13 pre-existing calls (`:c::rt-str-cat` `:160`, `:c::rt-vec-new` `:646`, `:c::rt-vec-conj-own`'s
`extend-at0` `:756` and `extend` `:810` — both `(:c::r15) false` — and its `copy` `:825`,
`:c::rt-varr-new` `:870`, `:c::rt-node-new` `:886`, `:c::rt-tree-push` `:1106`,
`:c::rt-tree-from-arr` `:1161`, `:c::rt-vec-conj` `:1220`, `:c::rt-slot-set` `:1287`,
`:c::rt-str-subs` `:1331`, `:c::rt-i64-to-str` `:1443`) each gained `(:c::r15) true` (11 of them) or
`(:c::r15) false` (the 2 extend sites) as trailing arguments — mechanical, since `base` is `r15`
for every one of them (confirmed: the ORIGINAL hardcoded `mov-rr r15 top` read from `r15`
UNCONDITIONALLY at every site, including the two with `top` in `rcx`/a different register than
`r11` — `base` and `top` are independent parameters, this was never actually tied to `r11`).

**The two inline bumps, converted to call `:c::rt-bump`** (`base`=`r8`, `top`=`rsi`): both
`:c::rt-prim-read-hex` and `:c::rt-io-read-file` previously computed `:c::rt-cap`'s result directly
into `top` (`rsi`) and then ADDED `base` (`r8`) into it — the reverse order from `:c::rt-bump`'s own
`base := top; top += size`. Fixed by moving `:c::rt-cap`'s OUT register to `rcx` (scratch moves to
`r9`, freeing `rcx`) so `grow` becomes the plain `add-rr rcx top` shape `:c::rt-bump` already
expects; confirmed `rcx`'s pre-bump value is dead in both functions afterward (overwritten fresh
before its next read in both cases) before making this change, not assumed.

### Gates run so far (all green)

`tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh`, all 24 required fixtures (every
`elf/probe/drop-*.wat` except `drop-cons.wat`, plus both `f209-*`): **agree, both ways, on the
first run** — meaningful because at this point the free lists are wired but NEVER PUSHED TO (M2-2
isn't built yet), so every single call takes the "list empty, fall through to the ORIGINAL check"
path; this is exactly the brief's own implied test that M2-1 alone changes nothing OBSERVABLE
(it changes the bytes emitted — the header widened, `:c::rt-bump`'s body is longer — but not
behavior), and 24/24 agreeing both ways on the first attempt is strong evidence the branch-offset
arithmetic in the new reuse body (five separate forward jumps, all computed via `hexlen` sums, none
hand-counted) is correct, not merely untested.

`elf/probe/drop-vec-cycle.wat`, native, `ulimit -s 256`, `setarch -R`: plain `"2000000"` exit 0;
`WAT_DROP_CHECK=1`-built `"2000000"` exit 0. Both agree with the required answer.

## A root found by the native chain: `:c::rt-cap`'s OUT can never be `rcx`

STOP-2's own shape, caught by the very first real test heavier than the 24 probes. `seed.elf`
(the native binary compiled from the M2 source) compiling the whole corpus a second time (the
first chain hop) failed: `"compile: no user/main"`, exit 70 — a program the compiler was asked to
build came back with no entry point found, which smelled of corrupted file content rather than a
missing function. None of the 24 required probes or `drop-vec-cycle` caught it, because none of
them read a file bigger than `:c::small-max` (512) through `wat.io/read-file`/`prim/read-hex` —
and the self-compile reads EVERY source file in `elf/`, several of them (`elf/compile.wat` itself,
chiefly) far larger than that.

**Isolated** with a two-line driver reading a large file and printing `(:wat::string::length ...)`
natively vs interpreted: diverged. Root: `:c::rt-prim-read-hex`/`:c::rt-io-read-file`'s conversion
to call `:c::rt-bump` moved `:c::rt-cap`'s OUT register to `rcx` (to free `rsi`/`top` for
`:c::rt-bump`'s own `grow`/`top` convention) — but `:c::rt-cap`'s OWN body (`elf/lib/runtime.wat`
`:515`-`:521`) hardcodes `rcx` as `bsr-rr`'s destination AND relies on it staying there as
`shl-cl`'s implicit shift count; writing `out`'s literal `2` into `rcx` first (when `out IS rcx`)
clobbers the just-computed shift amount before `shl-cl` ever reads it, so the capacity comes out as
a small, wrong, CONSTANT (always `2 << (whatever CL last held)`) wherever this path fired for
anything requiring the LARGE size class. This is an "allocated too SMALL" bug, not a free-list bug
at all — it existed independent of M2's reuse logic, in the plain bump-and-check path, purely from
the register reassignment; it would have fired on ANY String read from a file past `:c::rt-cap`'s
smaller end once the allocation undershot the data actually written.

**Confirmed with a minimal, UTF-8-free repro** (a 2000-byte ASCII file; `/tmp/ascii2000.txt`): before
the fix, this diverged too (not shown in the SCORE, caught, fixed, and re-confirmed agreeing,
`"2001"` both ways, in the same session). An EARLIER large-file repro using `elf/compile.wat` itself
as the test input was a RED HERRING I nearly chased down the wrong path: `elf/compile.wat` contains
a handful of decorative non-ASCII characters in its own prose comments (arrows, etc.), and
`:wat::string::length` counts BYTES in the compiled runtime but UTF-8 CODEPOINTS in the interpreter
— a pre-existing, unrelated-to-M2 property (confirmed with `python3 -c` decoding: 640299 bytes,
640277 codepoints, exactly the gap seen) that would have diverged on this input with or without any
of my changes, since source literals containing non-ASCII cannot even be compiled by this language
at all (`:asm::ascii`'s "not encodable" refusal) and nothing in the committed corpus reads a file
containing one and asks for its character length. Ruled out by testing a clean ASCII file instead
before concluding the REAL bug (the `rcx` aliasing) was fixed.

**Fix** (`elf/lib/runtime.wat`, both converted sites): `:c::rt-cap`'s `scratch` stays `rcx`
(read, then immediately overwritten by `bsr-rr` itself, so a transient use is fine) and `out`
moves to `r9` instead (confirmed not a documented output of `:c::rt-slurp`, and not needed again
before being overwritten in both callers) — `grow` becomes `add-rr r9 top`, the same shape
`:c::rt-bump` already expects, with `rcx` never touched by the size computation at all.

**Native chain fixpoint (plain and check) — LANDED, with the fix.** Both sandboxes rebuilt from
scratch (stage 0 via the interpreter, then `seed -> s1 -> s2 -> s3` natively).

**Plain** (`/tmp/chain-m2`): stage 0 (interpreted) built `compiler.elf` at 445731 bytes (92/92
verified). `seed` (445731) `-> s1` (445731, `rc=0`, 92 verified) `-> s2` (445731, 92 verified) `->
s3` (445731, 92 verified). `cmp s2.elf s3.elf`: byte for byte identical. **Fixpoint — and the
FIRST hop already matches the seed exactly**, unlike 3b-2's own chain (which saw one hop of
"spurious DIFFER" from a changed drop rule) — M2-1 alone changes no program's EMITTED bytes YET
(the free lists are wired but never populated), so there is no shape change for the fixpoint to
re-settle into, which is the expected, confirming result.

**Check** (`/tmp/chain-m2-check`, `WAT_DROP_CHECK=1` exported for EVERY hop — the one method
mistake caught immediately: running a check-built `seed.elf` WITHOUT re-exporting the variable at
each invocation silently produces PLAIN output, since `:c::drop-check?` reads the COMPILING
process's own `/proc/self/environ` at runtime, not something baked into the binary permanently —
the first `s1` attempt came back at the PLAIN size, 445731, until `WAT_DROP_CHECK=1` was put back
in front of the invocation; `SCORE-stone-3b-2-freeing.md`'s own chain section names this same
exact trap). Stage 0 built `compiler.elf` at 520277 bytes (92/92 verified). `seed` (520277) `->
s1` (520277, 92 verified) `-> s2` (520277, 92 verified) `-> s3` (520277, 92 verified). `cmp s2.elf
s3.elf`: byte for byte identical. **Fixpoint.**

## M2-2 — IMPLEMENTED: push onto the list when not youngest

`elf/compile.wat`'s `:c::free-tail-emit` (`:5039` area) — the shared tail every one of the five
free pseudo-routines (`freestr`/`freerec`/`freevec`/`freenode`/`closize`) ends with. Before M2-2,
the NOT-youngest branch (the `jcc` that skips the rewind) landed straight on `ret`: nothing. Now
it runs the SAME class decision `:c::rt-bump`'s allocate side makes, reusing `sizereg` (still
exact — the youngest test's own `add-rr` only READ it, never wrote it): `size <= :c::small-max`
→ SMALL, index `(size>>3)-1`; else, only if `size` is already a power of two → LARGE, index
`bsr(size)`; otherwise give up (stays dead, exactly as before M2). On a hit: unlink is not
needed (this is a PUSH, not a pop) — `[r10+0] := the list's current head` (where `r10` is the
block's own START, preserved from the youngest test's own `o1`, NOT `rax` — see the FIRST bug
below), `[table slot] := r10` (the new head). Three separate `ret`s now (youngest / pushed /
given-up), each reached by its own patched jump, mirroring `:c::freevec-glue-body`'s existing
"three independent cases, each its own `ret`" precedent.

This is the FULL M2-2 — one function, reached from all five free routines, no other code changed.
`:c::dropchk-hex`'s own comment ("none of the five free routines ever touch `rax`") still holds:
the new code only READS `rax` indirectly (via `startdisp` at `o1`, unchanged from before M2) and
never writes it.

## Two real bugs found by going past the 24 probes — a native chain, then a targeted repro

Neither of these showed up in the 24 required probes or `drop-vec-cycle` (below). Both showed up
the moment something HEAVIER actually exercised the reuse path at scale — the native chain, and
then a two-line repro built to isolate it once the chain's own crash pointed at "something near a
file read." Recording both in full, including the dead ends, per the brief's own STOP-2 method
("root it, never paper it") and the house rule about a red being data.

**Bug 1 — `:c::rt-cap`'s `out` can never be `rcx`.** The native chain's `seed -> s1` hop (plain)
segfaulted reading `/proc/self/environ` (`:c::drop-check?`'s own read, through the exact two
routines M2 converted from inline bumps to `:c::rt-bump` calls). Isolated with
`/tmp/ascii2000.txt`, a clean ASCII 2000-byte file, read natively vs interpreted: diverged on the
byte count (confirmed the UTF-8-in-`elf/compile.wat`'s-own-comments angle was a RED HERRING first
— `:wat::string::length` counts bytes compiled, codepoints interpreted, a PRE-EXISTING, unrelated
gap that this session nearly chased). Root: `:c::rt-cap`'s `bsr-rr`/`shl-cl` pair hardcodes `rcx`
as the shift count INTERNALLY, regardless of what `scratch`/`out` the caller names — my first pass
at `:c::rt-prim-read-hex`/`:c::rt-io-read-file` moved `out` to `rcx` (to free `rsi`/`top` for
`:c::rt-bump`'s convention), and `mov-ri out 2` (when `out` IS `rcx`) overwrites the shift count
`bsr-rr` just computed, one instruction before `shl-cl` reads it — the capacity comes out as a
small, wrong CONSTANT. **Fixed**: `out` moved to `r9` (not a documented `:c::rt-slurp` output,
confirmed free in both callers), `scratch` stays `rcx` (read then immediately overwritten by
`bsr-rr` itself, so a transient use is fine).

**Bug 2 — the free list stored a POINTER but the allocate side treated the popped value as a
BLOCK START.** After Bug 1's fix, the chain still crashed (SIGSEGV, confirmed under `gdb`+
`setarch -R`, non-PIE so the fault RIP maps straight to a file offset with no symbols needed) --
this time inside an `inc [rax-8]` with `rax` holding bytes that decode as an ASCII fragment of
`/proc/self/environ` content, i.e. a REFERENCE COUNT INCREMENT reached through what used to be a
heap pointer and was now garbage. Root, found by a hardware watchpoint on a specific free-list
table slot (`r14+:c::hdr-large+10*8`, the class a 1024-byte String/Vector lands in) across a
`/tmp/large-reuse-probe.wat`-family of fixtures narrowed down to two lines
(`/tmp/large-reuse-probe5.wat`): `:c::free-tail-emit` pushed `rax` (the type-specific POINTER --
`:c::vec-ptr`/`:c::varr-ptr` bytes PAST the block's real start) as the list entry, while
`:c::rt-bump`'s found-body handed the popped value back as `base` (which every other path treats
as a true BLOCK START, matching the youngest path's own `mov-rr r10 r15`). Popping what the free
side thought was a pointer, as a base, is off by exactly that type's own header offset -- 8 bytes
for most types, which is small enough that the write still landed INSIDE the block (corrupting a
sibling's header 8 bytes along, the "562"/"563" symptom this bug alone produced) rather than
outside it. **Fixed**: `:c::free-tail-emit` now keeps `r10` (the block START, computed once at
`o1` and never touched again) all the way to the push, using `r11` (not `r10`) for the
class/slot-address math, and `r8` as a third scratch for the "current head" temporary; the link
lives in `[r10+0]`, the block's own first word, which is ALWAYS inside the block for every type
(unlike `[rax-8]`, which is only inside the block for `str`/`rec`/node/closure, not for a Vector,
whose pointer sits a further 8 bytes in). `:c::rt-bump`'s `found-body` reads the link from
`[r9+0]` to match (was `[r9-8]`).

**A third bug, found while re-deriving the SMALL path by hand to write this up**: `small-section`'s
own unconditional jump (`(:c::jmp-over large-decide)`) measured `large-decide`'s FULL length,
which includes `have-slot` — so a SMALL request's own freshly-computed class address was always
abandoned unread, landing straight at `pop-then-tail` without ever checking the list. Fixed by
splitting `large-decide` into `large-only` (the LARGE test and class calc alone, what SMALL's jump
needs to skip) and `large-decide = large-only ++ have-slot` (what LARGE itself falls into). This
one never crashed anything — SMALL requests simply never found what `:c::free-tail-emit` had
correctly pushed for them, a missed win rather than a safety bug — but it is exactly the kind of
mistake the coordinator's "no site needs auditing" redirect does NOT protect against: self-
containment guards register correctness, not control-flow correctness, and this was the latter.

**Gates after all three fixes**: all 24 required probes, `tools/probe.sh` and `WAT_DROP_CHECK=1
tools/probe.sh`, agree (rerun fresh after each fix; the fixture set does not happen to exercise
SMALL reuse directly, so bug 3's own fix was confirmed by a dedicated probe --
`/tmp/small-reuse-probe.wat`, `i64::to-string` called twice then a third longer one, all agreeing
-- not by the required 24 alone). The check build never reaches `:c::free-tail-emit`'s free call
at all (`:c::dropchk-hex`'s `free-hex` is the empty string when `dchk?` is true), so none of these
three bugs could ever have shown up there, consistent with the CONTRACT's "the check build reuses
nothing."

**A first RSS read (8 runs each, same method as the top-level MEASURE section) — mixed, matching
3b-2's own honest finding rather than a clean win**:

| fixture | before (M2 baseline, 8 runs) | after M2-1+M2-2 (8 runs) |
|---|---|---|
| `drop-3b-recs` | 11672–12996 | 10284–11912 |
| `drop-3b-closure` | 9228–10328 | 9104–10448 |
| `drop-3b-list` | 78524–80176 | 78780–79872 |

`drop-3b-recs` moved down (center of the distribution shifted, ranges now mostly non-overlapping
on the low side). `drop-3b-closure` and `drop-3b-list` show NO clear movement — ranges still
overlap almost completely. This is consistent with `SCORE-stone-3b-2-freeing.md`'s own F3 finding
about WHY: these two fixtures' build shape (`conj`-ing fresh elements that land ABOVE the
container being extended) means the container is essentially never revisited as a same-size hole
by a LATER allocation in these specific access patterns -- freeing it onto a list is necessary but
not sufficient for THESE shapes to show a measured win; the list only pays off when a LATER
allocation of the SAME class actually asks again before the heap would otherwise have grown past
it. The compiler's own self-compile (the measure the builder cares about most, per the brief) is
the real test, running now -- see below.

## STOP-2, CORRECTED — the region release, not argument liveness: exactly the collision the M1
## crawl named before M2 was ever drawn. RETIRED (M2-4), landing WITH M2-2.

My first diagnosis (below, kept as a record of the dead end rather than deleted) guessed
argument-evaluation ordering. **That was wrong.** The orchestrator ran the same repro on a
sandbox copy of this dirty tree with `:c::releasable?` forced to return `false` (so `:c::seq`
never wraps a statement in the region release's `push r15`/`pop r15` at all) — and the fixture
AGREES, `["561"|"561"]`, with nothing else changed. The real mechanism, confirmed, is exactly
what `CRAWL-M1-the-count-comes-down.md`'s own question 5 warned about before M2 was drawn:

> "Once M2 puts freed objects on free lists, a region rewind past a freed object leaves a
> free-list entry pointing into rewound memory. Either the region release becomes a special
> case of the count, or M2's free lists never hold region memory -- decided before either is
> built." ... "the region release retires -- LAST, not first... it stays until M1's drops cover
> what it covers... and then it is removed."

**What actually happens, in `elf/probe/m2-region-collision.wat`** (the fixture this repro became,
below): `user/main`'s body is `(do STMT1 STMT2)` — `STMT1` (the first `println`) is a NON-FINAL
statement, so `:c::seq` wrapped it in the region release (it calls no `poke`, so
`:c::releasable?` said yes). INSIDE `STMT1`, the outer `concat`'s own source-drop frees
`build70x8()`'s 560-byte block — not youngest, so M2-2 correctly pushes it onto its free-list
class. Then `STMT1` ENDS, and the region release's own `pop r15` (`:c::seq`'s `"415f415f"`)
rewinds the bump pointer back to where it was BEFORE `STMT1` ran — which is BELOW the block M2-2
just pushed. `STMT2` (the second `println`) now starts bumping fresh allocations from that
rewound `r15`, landing `(wat.i64/to-string 5)`'s own small allocation on TOP of bytes the free
list still believes it owns — one block, two owners, corrupting the first one's header before
the free list ever gets a chance to hand it back out. Native (pre-M2-4): `["561"|"2"]`.
Interpreter: `["561"|"561"]`. `WAT_DROP_CHECK=1` native (pre-M2-4): `["561"|"561"]` — agreeing
with the interpreter despite the SAME push happening, because the check build's drop never
rewinds `r15` at all under `:c::releasable?`'s gate the same way plain's commit does — the
disagreement is real STOP-2, a live block's bytes reused out from under it, not a counting
defect.

**Fixed**: M2-4 retires the region release, landing WITH M2-2 rather than after it, per the
coordinator's correction — `:c::seq` no longer wraps anything in `push r15`/`pop r15`;
`:c::releasable?` and the whole transitive call-graph it was the only reader of
(`:c::calls-poke?`, `:c::any-poke?`, `:c::is-poker?`, `:c::poke-scan`, `:c::poke-fix`, and
`:c::Prog`'s `:pokers` field) are deleted outright, not merely bypassed — nothing else in
`elf/compile.wat` ever read any of them (confirmed by grep before removing each one). The count
is now the ONLY reclamation discipline, exactly C's own settled shape from the CRAWL's own
four-questions table. `elf/probe/m2-region-collision.wat` (this repro, committed as a permanent
fixture) now agrees both ways: `["561"|"561"]`, plain and `WAT_DROP_CHECK=1`.

### The dead end, kept as a record (argument-liveness ordering — NOT the cause)

Found while re-running the 24 probes clean and about to move to the native chain again. I rooted
it with a hardware watchpoint (`gdb` + `setarch -R`, no symbols needed — the ELF is a single
non-PIE `LOAD` segment at `0x400000`, so `file offset = vaddr - 0x400000` directly) on the
`:c::hdr-large` slot for class 10 (1024-byte blocks) and saw: `build70x8()`'s 560-char result
created at address `A`; `A`'s count reaching zero (a correctly-counted drop — confirmed via
`WAT_DROP_CHECK=1` agreeing, so the count itself was never wrong); `A`'s block reused by
`i64/to-string`'s own small allocation; the OUTER `concat` then reading `A`'s now-corrupted
header. I concluded the COMPILER was dropping `A` (the first `concat` argument) before the
second argument was evaluated and the call had actually read `A`'s bytes — a plausible-sounding
story that fit every observation I'd made, and was still wrong: the actual drop IS correctly
placed (after both arguments are evaluated and the call has run); what corrupts `A` is the
SURROUNDING STATEMENT's region release rewinding past it afterward, not the drop itself firing
early. The lesson, for whoever reads this next: agreeing with every observation I had made is
not the same as being the only hypothesis that does, and I had not yet tried disabling the ONE
other mechanism (`:c::releasable?`) that could independently move `r15` — which is exactly what
the orchestrator tried first.

## STOP-3 — a NEW, deterministic SIGSEGV on the native chain's first hop, root NOT found,
## NOT fixed. Handing back rather than guessing.

Found running the native chain (plain) with M2-2+M2-4 together, exactly as instructed. Stage 0
(interpreted) built `seed.elf` (444598 bytes, 92/92 verified — SMALLER than the M2-2-only build
at 447607 bytes, consistent with the region-release's own code shrinking out). `seed.elf`,
**run natively to compile the corpus a second time (the `seed -> s1` hop), segfaults** —
deterministic across repeated runs (confirmed twice), `rc=139`, under both plain `timeout` and
`setarch -R` + `gdb`.

**This is a DIFFERENT crash from the STOP-2 one above** — that one is fixed and gated; this one
appeared only once BOTH M2-2 and M2-4 were in place together and the native chain (not just the
24 probes, the new fixture, or `drop-vec-cycle`) actually ran. None of the required gates exercise
it; the self-compile does.

**What I found, rooted with the same `gdb` + `setarch -R` technique as before** (non-PIE, single
`LOAD` segment at `0x400000`, so `file offset = vaddr - 0x400000`, no symbols needed):

- The fault instruction, at every reproduction, is `cmp qword [rax-8], 0` with `rax = 0` — reading
  8 bytes before address zero, an immediate SIGSEGV. This is `:c::lit-then`'s own literal guard
  (the exact byte shape `48 83 78 f8 00 74 ..`), part of `:c::drop-hex`/`:c::emit-drop` for a type
  `:c::maybe-literal?` answers `true` for — which is ONLY `str` (String) or `fn:` (closure), never
  a `rec:`/`vec:`/`henum:`.
- The instruction immediately BEFORE it, every time, is `mov rax, [rbx + r12*8 + 8]` — reading
  slot `r12` of an array at `rbx`, with NO `test rax,rax`/`jz` in between. This is
  `:c::vec-glue-body`'s FLAT (non-tree) array walk (`elf/compile.wat` `:5361`-`:5362`:
  `(:c::rm "8b" (:c::rax) (:c::rbx) (:c::r12) 8 8)` then `(:c::emit-drop elem o14 pg rt)`,
  unconditionally — a flat Vector's slots `0..length-1` are all supposed to be genuinely written,
  so this walk, unlike `:c::node-glue-body`'s trie-node walk (which DOES `test-rr`/`jz` before
  touching a child slot, because an interior trie node legitimately has unused zero slots), never
  checks for zero.
- Conclusion: **some flat Vector whose element type is `str` or `fn:` holds a genuine raw `0` at
  one of its live slots** (index `r12`, within `[0, length)`), and this Vector's drop glue is
  running for the FIRST time ever — `:c::hdr-pending` (the output buffer's own pending-byte count)
  reads `0` at the crash, and the log file has ZERO bytes in it, meaning NOTHING has been printed
  or flushed yet — so this fires very early, plausibly during the very first `(:c::compile ...)`
  statement in `:user::main`'s own ~94-statement body (`"elf/src/four.wat"`, a two-line, trivial
  target program — ruling out the TARGET source as the cause, since compiling an equivalently
  trivial program through `tools/probe.sh` natively has never failed this way). The likeliest
  reading: a `Vector<String>` or `Vector<fn:...>` somewhere in the COMPILER'S OWN internal
  bookkeeping (`elf/compile.wat` is self-hosting, so `:c::Prog`/`:c::Fn`/etc. are ordinary target
  records once `elf/compile.wat` compiles itself, subject to the exact same count/glue machinery
  being debugged) carries a slot that was never actually written with a real value, and this
  specific drop path was NEVER EXERCISED before M2-4 because the region release was bulk-rewinding
  past it (a whole statement's temporaries reclaimed by moving `r15`, never running a single
  per-element glue call) rather than letting the count reach zero and the real walk run. If true,
  this is close to exactly what `CRAWL-M1-the-count-comes-down.md`'s own phrasing warned about —
  "[the region release] stays until M1's drops cover what it covers... removing it early blows
  memory" — except the gap it is covering here looks like a CORRECTNESS gap, not only a memory
  one.

**I did not find the exact construction site.** Narrowing attempts, each costing real time without
a conclusive answer:
- Isolating "compile `elf/compile.wat` alone" (the self-hosting case, bypassing the other ~93
  files) via the interpreter, to get a faster repro loop — the interpreted compile alone did not
  finish inside 900s (killed), so I could not even get to the point of testing the native result.
- A hardware watchpoint on the output buffer's pending-count confirmed zero bytes printed, which
  narrows WHEN (very early) but not WHICH Vector.
- I considered, and could not rule out within the time available, whether removing `:c::Prog`'s
  `:pokers` field (part of this same M2-4 change, since it was read only by the retired
  `:c::poke-scan`/`:c::releasable?` machinery) shifted something positional elsewhere — but
  `:wat::core::assoc`/record field access in this language is name-keyed, not offset-keyed, and I
  found no code that counts or indexes `:c::Prog`'s fields numerically, so I consider this UNLIKELY
  but not excluded.

**Why I am stopping here rather than continuing to guess**: this is now a question about the
COMPILER'S OWN internal data model (which `Vector<String>` or `Vector<fn:>`, built where, ends up
with an unwritten/zero slot) — a different subsystem than anything M2 built or than the region-
release removal itself touches mechanically. Guessing at a fix in code I have not traced to its
root is exactly what the brief's STOP-3 ("a gate you cannot pass at the root... never re-run a red
hoping for green") and the project's own standing feedback ("a bare `.replace` that misses is a
silent no-op," "never paper over, root it") forbid. The evidence above is real and reproducible;
the exact line is not yet found.

**State of the tree**: M2-1, M2-2, and M2-4 (the region-release retirement) are all IN; the STOP-2
repro (`elf/probe/m2-region-collision.wat`) is a committed fixture and agrees both ways; all 24
required probes, that fixture, and `drop-vec-cycle` (`ulimit -s 256`) agree, both plain and
`WAT_DROP_CHECK=1`. The native chain has NOT reached a fixpoint — `seed -> s1` segfaults on the
PLAIN build (confirmed twice). I have not run the check-build chain to completion (its own stage 0
was killed once by an earlier, too-short timeout, and I have not re-run it, since there is no
plain fixpoint to compare it against yet). `/tmp/chain-m2f/elf/out/seed.elf` is preserved
(444598 bytes, `gdb`-reproducible) for whoever continues this.

## FINDING — `:c::lvl-head` is a second, hand-kept copy of `:c::rt-nth`'s routine numbering

Left alone this strike, on the coordinator's instruction, and recorded rather than silently
noticed-and-ignored: `elf/compile.wat:9078`-`:9119`'s `:c::lvl-head` hard-codes roughly a dozen of
the SAME raw integers `elf/lib/runtime.wat:1754`-`:1833`'s `:c::rt-nth`/`:c::lay` assign each
routine (`22` for `nth`→tree_get, `9` for `quot`/`rem`, `17` for `concat`/`subs`/`str_eq`, `19` for
`Vector`, `27` for `conj`, `28` for `assoc`, `18` for a record/closure/`fn`, `33` for the hex/file
builtins, `10` for `String`/`println`/`assertion-failed!`, `4` for the bool family) — used to
decide how much of the runtime blob a given program's own emitted call sites require
(`:c::rt-level`, `:9139`, the dead-code-trimming "prefix" truncation `tools/bootstrap.sh`'s own
comment calls out). The long comment at `elf/lib/runtime.wat:1807`-`:1821` explicitly says the
POINT of the `:c::lay`/`:c::rt-nth` accumulation was that a routine's order lives in exactly ONE
place ("it used to be in three... the other two are derived from this one now, so a routine cannot
be inserted in one order and addressed in another") — but `:c::lvl-head` IS a fourth, independent
hand-kept copy that comment did not anticipate, because it predates needing to ever INSERT a
routine in the middle of the sequence (M2 did not need to, having gone with inlining instead — but
the NEXT person who ever does insert one will hit this). `:c::lvl-head`'s numbers should be
DERIVED from `:c::at-*` accessor names (e.g. a small lookup table of symbolic names, not raw
integers) or from `:c::rt-nth` itself, not retyped by hand — but that is a separate strike's work,
not this one's, per the coordinator's instruction to leave it alone here.

## Round 2 (2026-10-01, Claude Sonnet) — STOP-3 rooted and fixed

Picked up exactly where round 1 left off: `/tmp/chain-m2f/elf/out/seed.elf` (444598 bytes,
round 1's own preserved binary) copied to a fresh sandbox (`/tmp/chain-m2-exec`) and
reproduced first — deterministic SIGSEGV on `seed.elf` compiling the corpus a second time,
confirmed 3 runs, `rc=139` under plain `timeout` and under `setarch -R`+`gdb`.

### R1 — the forensic method the WEIGH asked for, done

`setarch -R gdb -batch -ex run` on the crashing binary: fault at `0x45fdd2`
(`cmpq $0x0,-0x8(%rax)` with `rax=0`), `rbx` (the object pointer, call it `P`) =
`0x7fe8b666d7d0` — **deterministic across reruns** (non-PIE, `setarch -R`, same corpus,
same binary), confirmed by rerunning 3 times and seeing the identical address each time.
`x/4gx $rbx-16`: `[P-16]=0`, `[P-8]=0` (count), `[P]=9` (length), `[P+8]=0`.

Per the WEIGH's own method: hardware watchpoints on `P`, `P-8`, **and `P-16`** (the WEIGH
named `P`/`P-8`; `P-16` was added once the first pass showed the dispatcher reads it — see
below), set from `starti` (before the heap even exists), logging every write with `$pc`.
Full capture, in order:

| pc | address | value | meaning |
|---|---|---|---|
| `0x461390`→reported at `0x461398` | `P-16` | `1` | creation: `:c::vec-tree` tag written |
| `0x461390`→`0x461398`(dup slot) | `P-8` | `1` | creation: count := 1 |
| `0x4613a0`→`0x4613a3` | `P` | `9` | creation: length := 9 (9-element tree Vector — valid for `vec-tree`, since `:c::arr-max`=8 is only a FLAT Vector's limit) |
| `0x412896` | `P-8` | `2` | a second reference taken (shared) |
| `0x412805` | `P-8` | `1` | one reference dropped |
| `0x45f420` | `P-8` | `0` | the LAST reference drops — this object's own count reaches zero here |
| `0x46070f`→write completes at `0x46070c` | `P-16` | `0` | **`:c::free-tail-emit`'s own push: `[r10+0] := old-head`, `r10 = rax - :c::varr-ptr = P-16`** |
| (none) | — | — | crash at `0x45fdd2`, no further write to any of the three words |

Cross-checked against `objdump -D -b binary -m i386:x86-64 --adjust-vma=0x400000` on the
same `seed.elf` (no symbols needed, single non-PIE `LOAD` segment, same technique round 1
used): `0x46069f` is confirmed as `:c::freevec-glue-body`'s inlined TREE branch (`cmpq
$1,-0x10(%rax)` — the `:c::vec-tree` tag test, `jne` past the fixed-size path if not equal;
`mov $0x28,%r9` — the fixed 40-byte size, `:c::varr-hdr`(24)`+2*:c::word`(16); `lea
-0x10(%rax),%r10` — `r10 := rax - 16`, matching `startdisp = -:c::varr-ptr`); its own
`:c::free-tail-emit` SMALL-classifies 40 (`<= 512`) and lands on the SAME shared have-slot
tail as the LARGE path (`0x460709`-`0x460712`: `mov (%r11),%r8; mov %r8,(%r10); mov
%r10,(%r11); ret`), which is exactly the three-instruction push `:c::free-tail-emit`'s
source (`elf/compile.wat:5086`-`5088`) describes. `0x45fd88` (the dispatcher `:c::
vec-glue-body` re-enters through) and `0x45fdbf`-`0x45fdd2` (the flat-array walk) match
`elf/compile.wat:5319` (`cmp-mi rbx -16 vec-tree`) and `:5361`-`:5362` exactly.

### ROOT — not a size-class mismatch: the free's own link write clobbers the tag the real
### glue still needs, because `:c::dropchk-hex` frees before it walks

**This is NOT the WEIGH's own guess** ("a freed block was listed under a class LARGER than
its true size, and an allocation from that list ran past the block's end into its live
neighbour"). The gdb trace above rules that story out directly: there is no SECOND
allocation anywhere in the log between the free (`P-8:=0` at `0x45f420`) and the crash —
only ONE more write, to `P-16`, and it is the free's OWN push, not a reuse. The actual
mechanism is simpler and does not involve two objects colliding at all:

`:c::free-tail-emit` (the shared push logic 3b-2/M2-2 built, `elf/compile.wat:5048`) always
writes the free-list link into **`[r10+0]`, the dying block's own FIRST word** (`r10` is
computed once, at entry, as `rax + startdisp`). For every Vector kind — flat, owned-flat,
AND tree — `startdisp = -:c::varr-ptr = -16`, so that first word is `[rax-16]`: **the exact
same word `:c::vec-glue-body`'s own dispatch (`elf/compile.wat:5319`, `cmp-mi rbx -16
vec-tree`) reads to decide whether to walk this Vector as a tree or as a flat array.**
`:c::dropchk-hex` (`elf/compile.wat:4425`) ran these in the order 3b-2 chose before M2 ever
existed — **free first (`free-hex`), then the real glue (`call-hex`)** — reasoned, at the
time, as "free self, then glue drops what it held, so a child whose block sat just below
becomes youngest in turn." Before M2, that free was a no-op for anything but the youngest
object, so the order was unobservable. M2-2 turned "free" into a real memory write for the
non-youngest case, and for Vectors specifically, that write happens to land on the one word
the VERY NEXT call (`call-hex`, i.e. `:c::vec-glue-body`) still depends on. In this exact
trace: the tag was written `1` (tree) at creation and never touched again until the free's
own push overwrote it with `0` (this size class's list happened to be empty, so the "old
head" value pushed in as the link was `0`) — so `:c::vec-glue-body`'s re-read a few
instructions later sees `0 != 1`, takes the FLAT branch on a 9-element TREE Vector (9 is
valid for a tree, invalid for flat — `:c::arr-max` is 8 — matching the WEIGH's own
observation that the length looked "too big for a flat Vector," which was the right
symptom pointing at the wrong mechanism), and walks 9 nonexistent inline "elements" that
are actually the tree's own `shift`/`root` words and whatever heap bytes follow, dropping
garbage as pointers until one dereferences cleanly into a fault.

Every OTHER pointer kind's block start is `rax - :c::vec-ptr` (= `rax-8`), which is the
COUNT word — already spent (0) by the time free runs, and never read again by that type's
own glue (`:c::rec-glue-fields` reads FIELD values at `rax+8` onward, never the count or a
tag). So the free-before-glue order was, and remains, harmless for records, closures,
and strings — this is a Vector-only hazard, but the FIX below is not Vector-only, because
nothing about reversing the order breaks any OTHER kind either (see below), and a uniform
fix needs no per-kind branch (no guard, per house rule).

### FIX — `call-hex` before `free-hex`, unconditionally, `elf/compile.wat`'s `:c::dropchk-hex`

Reordered `body`'s concatenation from `free-hex ++ call-hex ++ poison` to
`call-hex ++ free-hex ++ poison`, and re-derived the two embedded CALL instructions'
relative-offset bases to match (`call-hex`'s own `push-rax`/`e8 rel32`/`pop-rax` now begins
right after `zskip`, `free-hex`'s bare `e8 rel32` now begins right after `call-hex` ends —
same total byte count either way, so `zskip`'s own `br-over` length is unaffected and
needed no change). Confirmed BEFORE touching anything that `call-hex` already wraps itself
in `push-rax`/`pop-rax` specifically because a glue routine returns with `rax` pointing at
whatever it last touched, not the dying object (`elf/compile.wat`'s own pre-existing
comment) — so by the time `free-hex` now runs, `rax` is already restored to the correct
dying-object pointer by `call-hex`'s own `pop-rax`, exactly what `free-hex` needs. No
change to `:c::free-tail-emit`, `:c::freevec-glue-body`/`freestr`/`freerec`/`freenode`/
`closize`, or any size computation anywhere — the size functions were never wrong; F1's
sizes and M2-2's classing both proved correct the moment the walk read the right word.
Checked, not assumed: `:c::node-glue-body`'s own inner free-before-walk (the trie ROOT node
freed via `freenode` before its children are walked, `elf/compile.wat:5346`-`5347`) does
NOT have this hazard — `freenode`'s `startdisp = -:c::vec-ptr = -8`, the (already-spent)
count word, same as records — so it is left exactly as it was, correctly, no further change
needed there.

### Gates re-run after the fix, on the real tree (`elf/compile.wat`, `excursus-008-m2`)

All 25 (every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus both `f209-*`, plus the
new `m2-region-collision.wat`): **25/25 agree, `tools/probe.sh`, first run after the fix.**
Same 25, **`WAT_DROP_CHECK=1 tools/probe.sh`: 25/25 agree**, first run.

`elf/probe/drop-vec-cycle.wat`, built the round-1 way (`/tmp/build-fixture.sh`/
`/tmp/build-fixture-check.sh`, since `tools/probe.sh` deletes its own sandbox and this needs
the binary kept to run under `ulimit`), run natively under `ulimit -s 256` + `setarch -R`:
**plain `"2000000"` exit 0; `WAT_DROP_CHECK=1` (exported at run time too, not just build
time — the same trap round 1's own SCORE already named) `"2000000"` exit 0.**

Native chain (plain), fresh sandbox (`/tmp/chain-m2-r2`, full `tools/bootstrap.sh`, not
`--fast`, since this is a source change) — **in progress as this is being written**; see
the fixpoint result appended below once it lands.

### Still open at this point in round 2

- [ ] Native chain to a fixpoint (plain), `/tmp/chain-m2-r2` — running
- [ ] Native chain to a fixpoint (check)
- [ ] Measure AFTER (the 3 `drop-3b-*` fixtures + compiler-compiling-itself peak RSS, against
      the BEFORE numbers already in this SCORE)
- [ ] `tools/bench-coll.sh` against `BENCH-baseline.md`
- [ ] `tools/verify.sh` then `WAT_DROP_CHECK=1 tools/verify.sh`, in sequence
- [ ] `tools/emitted.sh check`

## Orchestrator's runs after round 2 (2026-10-01)

**Gates:** `tools/reads.sh` flagged the free path's read of a free list's head (`elf/compile.wat:5103`) — the
allocator's own table, reached from r14, not a container — added to its ALLOW list with that reason. Then
`WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok` (518,778 bytes); `tools/verify.sh` → `verify: ok` (444,609 bytes,
elf-run 103 binaries, 54 agree). **M2 is correct.**

**Peak RSS after M2 — same method as the before tables (`/tmp/build-fixture.sh`, `/tmp/maxrss`):**

| measure | main `5ed2d00` | 3b-2 `62dc68b` | M2 (this tree) |
|---|---|---|---|
| `drop-3b-recs` (8 runs, KB) | 10,908 – 12,912 | 11,672 – 12,996 | 10,384 – 12,020 |
| `drop-3b-closure` | 8,652 – 10,492 | 9,228 – 10,328 | 8,832 – 10,392 |
| `drop-3b-list` | 78,180 – 79,980 | 78,524 – 80,176 | 78,408 – 80,112 |
| the compiler compiling itself (3 runs) | 446,392 – 446,624 | 464,436 – 464,752 | **511,032 – 512,056** |

**The target is missed.** The fixtures do not move outside their noise; the compiler's own peak RSS is about 15%
ABOVE main's. Freeing is correct and reuse happens, but it does not cover what the region release used to give
back, and a growing structure's next copy is never its predecessor's size class. Not landed; see `WEIGH-M2.md`.
