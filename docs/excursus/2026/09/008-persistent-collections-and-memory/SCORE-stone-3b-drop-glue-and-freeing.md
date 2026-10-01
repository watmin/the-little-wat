# SCORE — excursus 008 stone 3b: drop glue and freeing

Struck by Claude Sonnet, one round. The tree is dirty at `f9b88ab` plus one change. Nothing was
committed. **G1 (glue per type), G2 (closures), G3 (the worklist), G4 (freeing) and G5 (the
poison) are NOT implemented.** G6 is: `:c::rt-drop1`, the guess-based one-pointer-field walk,
is retired, and the layout it sat in was renumbered around its absence. That is the whole strike.
The rest of this document is why the round stopped there rather than further in, what was learned
doing the reading that would let the next round start past the census, and the concrete
architecture the reading settled on for G1–G5.

## Why the round stopped at G6

Landing G1 for even the simplest case (`rec:R`, no cycles) two ways were considered:

1. **A shared routine per type**, called from the drop site — what G1 literally asks for. This
   needs a new address table (glue routines are program-specific, so they cannot live in the
   static runtime block) placed and measured the same two-pass way `:c::place` already places
   `:c::Prog/fns` — real plumbing, not byte-arithmetic, and low risk once the closure of types
   needing a routine is known (see "the type census, precisely" below).
2. **Inlining the field walk at the drop site** — cheaper to write, wrong to ship. A drop site's
   `rax` holds the dying object, but nothing at that point guarantees any OTHER register is free
   to hold a loaded field while a nested drop runs: `r8`–`r11` are the `let`-binding scratch pool
   (`:c::Prog/nscr`), and whether they are spent at a given point in the current function is a
   fact the register allocator carries, not something `:c::drop-hex` can assume. `elf/compile.wat`
   says as much on its own terms, 6357: *"[a function's] own callees save rbx, r12, r13 and rbp
   and treat r8-r11 as dead"* — which is exactly why option 1's `call` is the safe shape and this
   inlined option is not: a `call` already has that convention; raw inline code emitted mid-function
   does not, unless it re-derives the allocator's liveness facts, which is exactly the scope this
   round did not have room to also get right. A wrong guess here is a SILENT wrong answer in a
   live user variable, not a crash — the worst kind of red to chase blind, and past the point
   where this round could still afford to find it and fix its root inside `tools/verify.sh`'s
   30-minute cycle.

Rather than ship option 2 and risk an undiagnosable red, or start building option 1's address-table
plumbing without room left to also write G4's freeing (which is what actually moves the fixtures'
RSS — G1 alone, without G4, cannot move a single number in the brief's own measure), the round
banked the one safe, real, fully-verified thing available (G6) and spent the rest of its room
reading precisely enough that the next round does not re-derive the layout math from scratch.

## Expectations, row by row

| # | result |
|---|---|
| 1 | Fixtures still agree, both ways. `tools/probe.sh` on `drop-sum.wat` and `drop-shadow.wat`, plain and `WAT_DROP_CHECK=1`: all four `agree`. The three `drop-3b-*` binaries, built in a sandbox the way `tools/probe.sh` does and run directly, print the same answers as before 3b: list `99999000000`, recs `744500`, closure `1188895`. |
| 2 | Memory does **not** come back — G4 was not attempted. Peak RSS (`elf/bench/maxrss.c`): list 78,180 KB (was 79,884), recs 11,424 KB (was 12,200), closure 8,860 KB (was 8,984). The whole of the fall is the runtime block shrinking by retiring `:c::rt-drop1` (fewer bytes for every native binary to map, not fewer bytes held live) — nothing is freed. |
| 3 | Not attempted (G3). |
| 4 | Not attempted (G5 — there is no freeing yet for a use-after-free to be a use of freed memory). |
| 5 | Both gates, on the G6 change alone: `tools/verify.sh` → `verify: ok` (stage 0 370,028 bytes, stage1==stage2 at the fixpoint, 103 binaries, 54 agree, `reads: ok`/`copies: ok`/`rsp: ok`, rules 0 conflicts, types 0 conflicts). `WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok` (391,918 bytes at the fixpoint, same shape). Both runs, in sequence, on the real tree. |
| 6 | `grep -n "rt-drop1\|at-drop1"` across `elf/compile.wat` and `elf/lib/runtime.wat`: no hits. The general literal/tag discriminator (`cmp rax,0x1000` ahead of a pointer inc/dec, `:c::tag-then`/`:c::lit-hex`) stays — that is a TYPE-known guard the compiler already knows to apply from the static type, not a runtime guess about an unknown field, and is not what G6 or the crawl's "no guess" language is about. |
| 7 | Not run. Nothing G6 touched changes what any user program's compiled code does, so `tools/bench-coll.sh` would show no cell moving that stone-bench's own numbers do not already explain, and running it would only spend a cycle proving a null result. |
| 8 | Not measured with an instrumented two-hop build. By inspection: `:c::emit-drop`/`:c::drop-hex` are byte-for-byte what they were before this round (G6 touched only `elf/lib/runtime.wat`'s static block, never the per-site emission path), so the compiler's own instruction count compiling the corpus is unchanged from stone 3a's figure. The self-hosting compiler's SIZE did move: stage-0/stage-1 fixpoint 370,028 bytes plain (was 370,551 after 3a) and 391,918 under the check (was 392,489) — 523 and 571 bytes off the static runtime block respectively. |

## The type census, precisely (for G1)

Every drop site's type is knowable WITHOUT walking drop sites at compile time: the full set that
needs a glue routine is the transitive closure, over `rec:`/`henum:` field and payload types
(not through `vec:`/`fn:` — see the trie argument below), starting from every `:c::Prog/recs`
record, every `:c::Prog/enums` heap-tiered variant, and every `vec:T`/`fn:...` type string that
appears as a record field type, an enum variant field type, or a `:c::Fn/ptys`/`:c::Fn/ret`. That
closure can be computed once, purely from declarations, before pass one begins — nothing needs
threading through `:c::Prog` as an accumulator, and `:c::drop-hex`'s call sites do not need to
change shape to discover it.

**Placement follows `:c::place` exactly.** Glue routines are program-specific (unlike the static
runtime block), so they cannot live in `:c::layout`/`:c::rt-nth`. But they can be measured with a
zero-based, self-referential layout the same way the runtime block is (`:c::layout 0` then
`:c::rebase`) — a glue routine's own length does not depend on the real addresses of the OTHER
glue routines it calls, only on the byte-width of a `call rel32`, which is fixed regardless of the
target — so the same "build once at 0, rebase once the true base is known" trick applies, sized and
placed as one more section after the user functions' code (`:c::place`'s `code-total`) and before
the runtime block. `:c::Prog` gains two parallel fields, `gtys`/`gaddrs`, filled in once, right
where `pg1`/`rt` are built today in `:c::compile-as` — every existing caller of `:c::drop-hex`
already threads `pg`, so no new parameter needs to reach any of the thousands of existing call
sites.

**The trie's own recursion needs no worklist.** A node's children are other nodes (interior) or
`T`'s elements (leaf), decided at runtime by `shift == 5`, but the DEPTH is bounded at compile time
by the index width — 13 levels for 64 bits, 5 bits a level — so a node's glue may recurse with a
plain `call`, unconditionally, and the deepest a real drop ever recurses through node glue is 13
frames. G3's worklist is for what a bounded call cannot cover: a type that is unboundedly
self- or mutually-recursive BY ITS OWN DECLARATION (a `Cons` list, a tree) — found by a cycle
in the `rec:`/`henum:` field-type graph, restricted to `rec:`/`henum:` edges (a `vec:` or `fn:`
boxing does not itself make the boxed type's OWN recursion unbounded — the vector's bound is the
trie argument just given, and a closure's captures are fixed per creation site). The compiler's own
55 types have no such cycle (the crawl's census already showed this); only a user's declared
recursive type does, and only fixtures like `drop-3b-list.wat` exercise one.

## G4 — freeing, the sizes derived and where confidence runs out

Freeing only matters on the youngest-allocation path (`end == r15`, `vec_conj_own`'s own test);
every other dead object is a no-op this stone, same as today. On that path:

- **`rec:R`** and **a closure** share one allocator (`:c::rt-vec-new`, per `:c::lvl-head`'s own
  comment, "building a closure allocates, the same routine a record uses" — level 18 for both).
  Size is exact, never over-allocated: `len*8 + 24` where `len` is the record's field count or the
  closure's capture count, both compile-time constants. No capacity ambiguity.
- **A trie node** (`:c::rt-node-new`) is a fixed `32*8 + 16 = 272` bytes, always.
- **A flat Vector** is NOT uniform: the word at `[ptr-8]` is either the plain `heap-arm` marker (1)
  — an exact-length allocation, `rt-varr-new`/`rt-vec-conj`'s copying path, no slack — or the
  `arm-own` marker (`4294967297`), which DOES carry slack from `vec_conj_own`'s power-of-two
  rounding (`:c::rt-cap`-shaped: `2^(⌊log2(len·8 + word + varr-ptr + cap-bias)⌋ + 1)`, `cap-bias
  = 15`). Reading `rt-varr-new` and `rt-vec-conj` side by side to state the EXACT plain-case byte
  count, the two formulas disagreed by 8 bytes by eye (`len*8+32` in one, `(len+1)*8+24` in the
  other, for what should be the same "N-element vector" case) and the round ran out of room to
  settle which reading was wrong before trusting either in code that frees real bytes. This is
  exactly the brief's own trap door ("if the capacity is miscomputed the other way, too much") and
  it is why G4 was not attempted rather than attempted and hoped-green.
- **A String** is uniform, unlike the vector: every heap-allocating string routine this round found
  (`str_cat`'s copying path, `str_cat_own`'s grown-copy path, `str_subs`, `i64_to_string`,
  `prim_write_hex`, `io_read_file`) sizes through `:c::rt-cap`, so a String's capacity is always
  `rt-cap(current byte length)` — no marker distinction needed the way a vector needs one. This
  reading is more confident than the vector's because every call site agreed with itself; it is
  still unverified against a live process with gdb, which is what the next round should do before
  trusting it either.

**The right next step is empirical, not more reading**: compile a tiny probe, and use gdb (ASLR
off, as the brief's own method already prescribes for the watchpoint technique) to read a real
`arm-own` vector's and a real grown String's actual heap bytes and confirm the capacity formula
against them directly, rather than resolve the 8-byte disagreement above by re-reading the same
two routines a third time.

## G2 — where a closure's glue would live, and why

A closure object (`[count][code][cap…]`) does not say what it captured; the glue belongs to the
CREATION site (the lifted function), whose `Cap` list is fixed at compile time. The chosen
location: one word immediately before the lifted function's own code — reachable as
`[closure.code - 8]`, populated by giving `:c::place` an extra prefix word for exactly the `Fn`
entries that are `:lifted` and capture something (a static closure, count 0, is never dropped, so
a non-capturing lifted function needs no such word and gets none). This reuses the address
machinery `:c::place` already has for every other function; it does not need a new table keyed a
different way from everything else the two-pass technique already places.

## G5 — the poison, chosen but not wired

A freed object's count word is set to a sentinel no live object, no literal (0), and no `arm-own`
marker (`4294967297`) can equal, and `:c::dropchk-hex`'s existing "count < 1" compare grows an
"or equals the sentinel" arm, both landing on the same `:c::rt-uflow`-shaped stop. Not wired this
round because nothing frees yet for a freed object to be poisoned.

## Stop triggers

None fired. The round did not reach code that could trip STOP-1 through STOP-4; the decision to
stop at G6 was made ahead of writing code that could produce one of them un-diagnosably (see
"why the round stopped" above).

## Left for the next round

G1 (the address-table plumbing for shared glue routines — sketched above, not started), G2
(the prefix-word extension to `:c::place`), G3 (the worklist header field and its intrusive
encoding), G4 (freeing — blocked on the vector-capacity byte count above, which wants gdb, not
more reading), G5 (the poison), and G6's remaining half (nothing else calls `rt-drop1`-style
guessing; confirmed by grep, nothing further to do there). `tools/bench-coll.sh` and the
two-hop instrumented instruction count against stones 1 and 2 are both still open, and should
follow once G4 gives them something to measure that moves.

## 3b-1 — 2026-09-28

Struck by Claude Sonnet, against `d71a769` (G6 landed, previous round). The real tree is dirty
with source edits to `elf/compile.wat` and `elf/lib/runtime.wat` only; **nothing was committed,
`elf/out/` on the real tree was never touched, and neither gate has been run on the real tree.**
All building and running below happened in a throwaway sandbox, `/tmp/stone3b1-sandbox` (an
rsync of the tree minus `target/` and `.git/`), deleted at the end of this round. G1 was **not
attempted** this round; the round spent its whole budget on G5 and found a real, reproducible
red before either gate could be attempted on the real tree.

### What was written (G5 only)

- `elf/lib/runtime.wat`: `:c::poison-count` (`-1`), beside `:c::heap-arm`/`:c::arm-own`, chosen
  because it sign-extends through `:c::mov-mi`'s 32-bit immediate to fill the whole 64-bit count
  word, and cannot equal 0 (a literal), a live count, or `:c::arm-own` (`4294967297`).
- `elf/compile.wat:4293` (`:c::dropchk-hex`): when a decrement's own existing underflow guard
  passes (count was `>= 1`) and the `dec` takes it to exactly zero, the object is poisoned —
  `cmp [rax-8],0 ; jne-over ; mov qword[rax-8],-1` appended after the existing `dec`, gated
  entirely inside the pre-existing `(:c::Prog/dchk pg)` branch so the off build's `dec` is
  untouched (still one instruction).
- `elf/compile.wat` (new, beside `:c::count-hex`): `:c::countchk-hex` — the increment's half.
  Under the check build only, `cmp [rax-8],:c::poison-count ; jz :c::rt-uflow` runs before the
  ordinary increment, reusing the SAME named stop the decrement side already had (one message,
  either direction). Wired into `:c::count-hex`, whose signature grew `o`/`rt` to reach
  `:c::at-uflow` and the current emit position, the same way `:c::dropchk-hex` already does.
- That signature growth rippled through everything between a drop site and `:c::count-hex`'s two
  callers (`:c::share`, `:c::read-out`): `:c::share`, `:c::tail-share`, `:c::read-out`,
  `:c::keys-each`, `:c::arm-binds`, `:c::bind-caps` all gained an `rt <- :c::Layout` parameter,
  and every call site of those six functions (~30, all confirmed to already have `rt` or a
  Layout-carrying caller in scope) was updated to pass it through. No new threading through
  `:c::Prog` was needed; every site already had `rt` one frame up.

### Fixture / gate results

**Plain build (`WAT_DROP_CHECK` unset):** clean. `tools/bootstrap.sh --fast` in the sandbox,
seeded from the real tree's own pre-3b-1 `elf/out/compiler.elf` (370,028 bytes), reaches the
fixpoint: 103 binaries, all byte-identical between the two native stages, compiler self-image
371,678 bytes (up from 370,028 — the new dead-under-plain-build glue code). This is real evidence
the byte-lengths introduced are internally consistent under the off build; G5 was not exercised
here (`countchk-hex`/`dropchk-hex`'s poison arm both return early when `not (:c::Prog/dchk pg)`).

**Check build (`WAT_DROP_CHECK=1`): RED, reproducible, not yet rooted.** The same `--fast`
technique (seed = the real tree's untouched, pre-3b-1 370,028-byte `compiler.elf`, run with
`WAT_DROP_CHECK=1` in its environment to compile the new source) gets through every one of the
103 corpus programs — including the last three before the compiler itself
(`elf/native/fork.wat`, `thread.wat`, `threads4.wat`, all printed `verified`) — and then, while
compiling `elf/compile.wat` itself into `elf/out/compiler.elf`, stops with
`assert failed: (:wat::test::assert-eq written filesz)` (`elf/lib/asm.wat:172`, inside
`:asm::link`): the byte count the native `write()` syscall reports differs from the blob's own
computed length. This is deterministic — re-run twice, byte-for-byte identical logs both times,
same stopping point. The other two things `:asm::link` asserts (`blob-length/2 == filesz`, and a
read-back equality) were NOT reached as failures; only the write-count one fired, meaning the
compiled BLOB is self-consistent by the compiler's own reckoning and the mismatch is between that
reckoning and what the write syscall reported.

**Ablation, to localize which half of G5 is implicated:** with `:c::countchk-hex` forced to
return `""` unconditionally (the decrement-side poison-write in `:c::dropchk-hex` left fully
active), the identical `--fast` check-build run reaches a full fixpoint — 423,814 bytes,
byte-identical between native stages, `bootstrap: ok`. This isolates the red to the
**increment-side check (`:c::countchk-hex`) specifically** — the poison-write on death, on its
own, is clean under this same test.

**What was ruled out, and what was not.** Read back every byte-length-sensitive piece of
`:c::countchk-hex` against the two-pass invariant (`:c::disp8?` on the constant `-1` and the
constant `-8` both always take the short form; `:c::hexlen` of the `cmp`/`jz` sequence is
therefore a hard constant regardless of the actual relocation value, matching how
`:c::dropchk-hex`'s own pre-existing `jb`-to-`:c::rt-uflow` guard already relies on the same
constancy) — nothing there looks wrong by inspection, and `:c::same-lens`'s own assertion (pass
one's lengths equal pass two's, checked in `:c::compile-as` on every compile) did NOT fire, which
argues the byte lengths genuinely do agree between passes. The failure is therefore either (a) a
correctness bug in `:c::countchk-hex`'s emitted bytes that is silent under the byte-length
invariant but wrong in some other way not yet identified, or (b) a latent, pre-existing,
size-dependent bug in the untouched native `:c::rt-prim-write-hex` assembly (`runtime.wat:1492`)
that only a file as large as the check build's own compiler image (a few hundred KB past what any
prior build produced) trips — this round could not tell which before running out of room. An
interpreter-based run of the identical check-build source (a completely different, Rust-backed
write path, `:prim::write-hex` in `elf/lib/prim.wat`, rather than the native syscall assembly) was
launched to distinguish the two — if the interpreter reaches the same file and writes it cleanly,
the fault is in the native write assembly, not in the new drop-check code — but a first attempt
under a 300 s budget was killed by its own timeout before reaching `elf/compile.wat` (the
interpreter takes on the order of 16 minutes for this file per the brief, and check-build code is
larger again); a second attempt with a much longer budget was still running, unconcluded, when
this round's handback was forced. **This is the open thread the next round should pick up first**,
before touching G1.

### Mutant, and both verify runs

**Not reached.** With the check build red on the way to even the FIRST gate (`tools/verify.sh`
before `WAT_DROP_CHECK=1 tools/verify.sh`, in sequence, per the brief), neither verify was run on
the real tree — starting a 30-minute `tools/verify.sh` while the check build's own much faster
sandbox probe was still red would only have produced a second, less diagnosable red at greater
cost. `tools/verify.sh` (plain) was never invoked this round, on the real tree or in the sandbox;
by the same evidence as the sandbox `--fast` plain bootstrap above there is no particular reason
to expect it red, but it was not run and is not claimed green. The mutant (drop one reference
early, check build must stop) was not built; G5's own check build does not stand up yet.

### Fixtures

Not run this round. `elf/probe/drop-*.wat` (the `drop-3b-*` three and the rest) were not probed,
plain or checked, on the real tree or the sandbox — the round did not reach a state where running
them would answer anything the corpus compile above had not already.

### Sizes

Plain compiler self-image: 371,678 bytes (sandbox, `--fast`, up from the pre-3b-1 370,028).
Check-build compiler self-image with only the decrement-side poison active: 423,814 bytes
(sandbox, `--fast`, fixpoint). No check-build size is known with the increment-side check also
active, since that combination has not reached a fixpoint.

### Left for the next round

1. **Root the `written`/`filesz` mismatch** before anything else. Finish the interpreter-based
   check-build compile of `elf/compile.wat` (background when this round stopped) to learn whether
   the native write-hex assembly (untouched, `runtime.wat:1492`) or `:c::countchk-hex`'s emitted
   bytes are at fault; if the former, this is a pre-existing bug this stone exposed by making the
   compiler's own image bigger, not a regression to unwind. If the latter, re-derive
   `:c::countchk-hex`'s byte accounting from scratch against a minimal probe rather than the full
   self-compile, where a single wrong instruction is far easier to isolate.
2. Once G5 is green both ways (including the mutant), attempt G1 for the non-recursive types in
   the order the census gives: `str` (nothing to glue), `rec:R` (the address-table plumbing
   sketched in this file's own "the type census, precisely" section, above), then `vec:T` and
   `henum:E`.
3. Neither gate (`tools/verify.sh`, `WAT_DROP_CHECK=1 tools/verify.sh`) has been run on the real
   tree this round; both remain to do, in sequence, once G5 is actually green in the sandbox.
4. The sandbox (`/tmp/stone3b1-sandbox`) used for all of this round's testing has been deleted;
   the real tree's `elf/out/` is exactly as it was before this round (untouched), and its
   `elf/compile.wat`/`elf/lib/runtime.wat` carry this round's G5 source edits, uncommitted.

## 3b-1 round 2 — 2026-09-28

Struck by Claude Sonnet, against the previous round's dirty tree (G5 landed, uncommitted). The
orchestrator's sandbox `/tmp/s3b1` (seed 370,028 bytes, `s1.elf` 393,776, `s2.elf`/`s3.elf`
469,096, `WAT_DROP_CHECK=1` throughout) was copied to `/tmp/s3b1-r2` per the brief and used for
all tracing and the first two fix attempts; it has been deleted. `/tmp/s3b1` was read but never
written. The real tree's `elf/out/` was touched only by the two `tools/verify.sh` runs at the
end (both requested by this round, both wanted).

### The dead object's history

Both hops of the sandbox's reproduction were rebuilt with a sandbox-only trace (`:c::trace-fns`,
printing `(:c::Fn/name f)`/`(:c::Fn/addr f)` for every `f` in `(:c::Prog/fns pg1)`, called from
`:c::compile-as` only when `src-path = "elf/compile.wat"`) so that `s1` printed `s2`'s own
function/address map while producing it — never committed, sandbox-only. `s2.elf`, run under
`WAT_DROP_CHECK=1` (ASLR off, ELF is non-PIE so addresses are fixed regardless), breaks at the
shared `:c::at-uflow` target (found by disassembling the flat binary and reading every
`dropchk-hex`/`countchk-hex` guard's jump target: 2,000 `jb` sites plus 4,120 `je` sites, all one
address). `rax` at
the break is `0x7fe8b664cce8`; `[rax-8]` is already `-1` (poisoned) — the stop is the
**increment-side check**, confirming the SCORE's earlier ablation. A hardware watchpoint on
`*(long*)(0x7fe8b664cce8-8)`, set after `starti`, logs:

| # | `$pc` | function (from the trace) | old → new |
|---|---|---|---|
| 1 | `0x4677c0`/`0x467a03` (rebuilds shift this) | inside the static runtime block (the String allocator `str_cat`/`str_cat_own` reaches, not a named `Fn` — it sits after the last table entry) | `<unreadable>` → `1` (allocation) |
| 2 | `0x40c392` | `:c::rt-tree-push` (`elf/lib/runtime.wat:921-930`, the `child` binding's first argument nesting `(:c::hexlen kid)` at line 923 — the compiler's own share ahead of that call) | `1` → `2` |
| 3 | `0x4123cb` | `:c::hexlen` (`elf/lib/runtime.wat:1765`) | `2` → `1` |
| 4 | `0x4123cb` (same address, a second call) | `:c::hexlen`, again | `1` → `0`, poisoned to `-1` at `0x4123da` |

No sixth event: the next touch is `:c::countchk-hex`'s read-only `cmp [rax-8],-1`, which jumps to
`:c::rt-uflow` without writing — the increment that should have run before this touch never
happened. Re-run of the whole two-hop build with the fix in place (below) reproduces the
identical four-line history at (shifted) addresses, then stops cleanly with no fifth or sixth
event: `s2` (now `s2g`) runs to `compile: ok`.

### The root

`elf/lib/runtime.wat:921-930`, `:c::rt-tree-push`'s `child` binding:

```
child (:wat::string::concat
        (:c::br-len (:c::jcc-rel8 (:c::cc-zero))
          (:wat::core::+ (:c::hexlen kid) (:wat::core::+ (:c::call-size) (:c::rel8-size))))
        kid
        (:c::rt-call (:c::at-ncopy lay)
          (:wat::core::+ a-copy (:wat::core::+ (:c::hexlen kid) (:c::call-size))))
        ...)
```

`kid` is read three times here: nested inside the first (`:c::br-len`) argument, directly as the
second argument, and nested inside the third. `:c::concat`'s own generator
(`elf/compile.wat:2569-2595`, "a left fold through `str_cat`") compiles its first argument
FIRST, unconditionally, then folds the rest via `:c::cat-fold` — arg-then-rest, never deferred.
But `:c::eval-seq` (`elf/compile.wat:3831`, the walk that builds `:c::Prog/lasts`, the table
every `:c::last-use?` call reads) special-cased every `:c::write-head?` head (`conj`/`assoc`/
`concat`) the same way: defer kid 1 to the END of the walk, matching `conj`'s real shape (box
pushed early, its OWN last-use bookkeeping only finalized at the call, after the value). For
`concat` specifically this is right only when kid 1 IS the box — a bare Symbol with nothing
inside it. When kid 1 is a COMPOUND expression, as `child`'s is, deferring its walk drags every
name buried inside it to the end too, even though those names are compiled and run FIRST, not
last. Here that name is `kid`'s occurrence inside the `:c::br-len`/`:c::hexlen` nesting (call it
`G`): bookkeeping recorded `G` as `kid`'s function-wide last mention (walked dead last, since kid
1's whole subtree was deferred), when the true last mention is a LATER argument's own nested
`:c::hexlen kid` call. `G`'s own occurrence — an ordinary function-call argument to `:c::hexlen`,
sharing exactly the way every argument does — checked `:c::last-use?` against that wrong table
entry, found itself "the answer", and skipped its share. Two real consumers (`G`'s `:c::hexlen`
call and the later one) then drop a reference that was only ever shared once.

A second, narrower defect sits beside it: `:c::cat-fold` (`elf/compile.wat:3423-3439`) never
shared ANY of its folded operands (`ks[2..N]`) at all — unlike `:c::concat`'s own first argument
and unlike `:c::conj`'s value argument, both of which call `:c::share`. A bare-Symbol operand
folded here that is not its true last use was silently under-counted regardless of the eval-seq
question. **Tried alone first, and measured wrong**: `:c::cat-fold` was fixed and the whole
two-hop chain rebuilt before `:c::eval-seq` was touched at all; the rebuild reproduced the
IDENTICAL crash, same two functions, same watchpoint shape, only the absolute addresses shifted
(a red that stayed red is still data) — proof that this defect was not the one the trace caught,
since the folded occurrence here, `kid` used directly as `child`'s second argument, is not one of
the two consumers the watchpoint recorded. It is the same CLASS, though, and the new fixture
exercises it too (`kid`'s direct occurrence is exactly this shape), so it is fixed alongside the
root rather than left for a rediscovery.

### The fix

- `elf/compile.wat:3831` (`:c::eval-seq`): the write-head reorder now also requires
  `(:c::kindv (:wat::core::nth ks 1) pg) = (:rd::Kind.Symbol {})` — it only defers kid 1 when kid
  1 IS the box, never when it is a compound expression with names of its own.
- `elf/compile.wat:3423-3439` (`:c::cat-fold`): each folded operand now computes `needs-share?`
  (a Symbol, pointer-typed, and not its last use) and only takes the direct-into-rcx fast path
  when a share is not needed; otherwise it goes through `:c::share` composed with `:c::expr`,
  the same shape `:c::expr-val` already uses elsewhere.
- `tools/reads.sh:90-95`: an unrelated, pre-existing stale check, found only because this is the
  first time `tools/verify.sh` has run on the real tree since G5 landed. G5 grew
  `:c::count-hex`'s signature (an `rt` parameter, for the increment's own poison check), so
  `:c::read-out`'s call became `(:c::count-hex t pg lo rt)`; the script's check 3 still grepped
  for the old `(:c::count-hex t pg)` and failed with `:c::read-out no longer emits
  :c::count-hex`, though it plainly still does. The pattern now matches the call as it actually
  reads. Not a correctness bug in the compiler; a maintenance gap in the gate, closed so
  `tools/verify.sh` could run at all.
- `elf/refuse-*.wat` (11 files) regenerated via `tools/gen-refuse.sh` after the `compile.wat`
  edits, per its own header ("generated rather than maintained") and `tools/elf-run.sh`'s own
  staleness check.

Refuted: neither fix is a guard on the symptom. The `eval-seq` change removes the exact
mis-ordering that produced the wrong `Prog/lasts` entry; the `cat-fold` change adds the missing
share the existing `:c::conj`/`:c::concat`-first-argument code already had. Both fixes are
one-line predicate changes to existing, already-general machinery (`:c::last-use?`, `:c::share`)
— no new drop was removed, no correct check was loosened.

### The fixture

`elf/probe/drop-concat-box.wat`, new. `user/mklen` reads a String's length; `user/main` builds
`s` by `concat`, then builds `r` from a four-argument `concat` whose first argument nests
`(user/mklen s)`, whose second argument is `s` directly, and whose third argument nests
`(user/mklen s)` again — the same "compound-kid-1-contains-a-name-used-again-later" shape as
`:c::rt-tree-push`'s `child`, at the smallest size that reproduces it. `tools/probe.sh`:
`agree ["4abcd4!"]`. `WAT_DROP_CHECK=1 tools/probe.sh`: `agree ["4abcd4!"]`. Confirmed as a real,
non-trivial reproduction by reverting both fixes in a throwaway copy of the tree and re-running
the same two commands: plain still `agree`s (the under-count nets out unseen, as G5's own SCORE
entry predicts), `WAT_DROP_CHECK=1` then `DIVERGE`s — `native=[wat: reference count underflow]
(exit 70)` against the interpreter's `["4abcd4!"]`. The throwaway copy was deleted after.

Every other `elf/probe/drop-*.wat` (21 files, `drop-cons.wat` excluded per the brief) was run
through `tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh` on the real, fixed tree: all 22
(21 pre-existing plus the new one) `agree`, both ways.

### The chain

Rebuilt in `/tmp/s3b1-r2` with both fixes applied to its `elf/compile.wat`: `seed.elf` (370,028,
pre-3b-1) → `s1g.elf` (394,624) → `s2g.elf` (471,241), all under `WAT_DROP_CHECK=1`. Running
`s2g.elf` now prints the full corpus and `compile: ok` (exit 0) — no underflow. `s2g` → `s3g`:
471,241 bytes, byte-identical to `s2g`. `s3g` → `s4g`: byte-identical to `s3g` — the fixpoint the
brief asks for, reached one hop earlier than required (`s2` was already stable). The plain
(`WAT_DROP_CHECK` unset) chain was also rebuilt as a sanity check: `seed` → `s1p` (372,459) →
`s2p` (372,975, the documented one-time `--fast` "new runtime" artifact) → `s3p` (372,975,
byte-identical to `s2p`) — a clean plain fixpoint, unaffected by the fix.

### Both gates, on the real tree, in sequence

`tools/verify.sh`: bootstrap stage 0 (interpreter) 103 binaries in 1,153,916 ms, the compiler
372,501 bytes; stage 1 == stage 2 byte for byte at the fixpoint (372,501 bytes). `reads: ok`,
`copies: ok`, `rsp: ok`. `elf-run: ok — 103 native binaries. 54 agree with the interpreter; 3
more use syscalls it has no implementation of (F-119); 11 refusals and 4 traps, both ways. rules:
0 conflicts in 13,428 argument-parameter pairs ... over 158 programs. types: 0 type conflicts in
24,276 nodes both typed ... over 158 programs.` **`verify: ok`.**

`WAT_DROP_CHECK=1 tools/verify.sh`: bootstrap stage 0 103 binaries in 1,141,265 ms, the compiler
470,582 bytes; stage 1 == stage 2 byte for byte (470,582 bytes). `reads: ok`, `copies: ok`,
`rsp: ok`. `elf-run: ok` — same shape as the plain run (54 agree, 3 syscall-gap, 11 refusals, 4
traps, both ways; rules 0 conflicts, types 0 conflicts) — **zero underflows across the whole
corpus, both stages.** **`verify: ok`.**

Both runs used `nohup ... & ; timeout 590 tail --pid=<PID> -f /dev/null` in a loop, per the
brief; neither was wrapped in a short `timeout`. Logs kept at `/tmp/verify-plain-3b1r2-b.log` and
`/tmp/verify-check-3b1r2.log` (outside the tree, not part of this round's deliverable, but left
on disk).

### What was not done

G1 (glue per type) — out of scope for this round, per the brief. `tools/bench-coll.sh` and the
two-hop instrumented instruction count against stones 1 and 2 were not run; nothing this round
touched changes what a user program's compiled code does (the fix is entirely in the
COMPILER'S own reference counting of ITS OWN internal strings), so neither would show a moved
cell. The `checker-multi` lines `rules.sh`/`elf-run.sh` print (29-32 per run, `(Option String)`
against a concrete type at specific `compile.wat`/`asm.wat`/`prim.wat` lines) are unchanged from
what a bare `tools/rules.sh` run shows on the pristine G5 tree before this round's edits — not
investigated further, since `CONFLICT`/`TYPE-CONFLICT` are the gate's own pass/fail counts and
both are 0, both runs.

### Left for the next round

G1 for the non-recursive types, in census order (`str`, then `rec:R`, then `vec:T` and
`henum:E`), per the "the type census, precisely" section of this document.

## 3b-1 round 3 — 2026-09-30

Struck by Claude Sonnet, against the previous round's dirty tree (R2's `needs-share?` already
removed from `:c::cat-fold` -- confirmed by grep before continuing; `elf/compile.wat`'s only
remaining mention of the name is the explanatory comment left in its place, not code). A
mid-task message from the coordinator asserted R2 was still outstanding; that did not match
the tree, which this round treats as the authority over any agent's claim about its state. The
session also hit an API rate limit once, immediately after the self-debug build described
below finished; nothing was lost -- the sandboxes (`/tmp/s3b1r3`, `/tmp/s3b1r3-selfdbg`) were
intact and the real tree carried only the in-progress G1 source edits, no partial writes to
`elf/out/`. Both gates below are this round's own completed runs, after the fix. Nothing was
committed; the tree is dirty.

### R2

Confirmed already done (not redone): `:c::cat-fold` (`elf/compile.wat:3410-3434`) hands each
folded operand to `:c::expr` bare, no share, matching the WEIGH's refutation. The fixture
(`elf/probe/drop-concat-box.wat`) and the four-hop chain both still pass; see below.

### G1 — where the glue lives, and how a drop site reaches it

New section in `elf/compile.wat`, `:c::emit-drop` (4513) through `:c::glue-place` (5073):

- `:c::glue-target-ty` / `:c::glue-addr` (4590, 4599) -- the one reader. `penum:` resolves to
  its sole payload type (tier 1 has no header of its own); everything else is looked up by name
  in `:c::Prog/gtys`, answering the parallel `:c::Prog/gaddrs` entry or -1.
- The census (4605-4840): `:c::census-run`/`:c::census-walk` build the transitive closure over
  `rec:`/`henum:` field and payload types from declarations alone (every record, every
  non-generic heap enum, every `Fn` signature, as seeds), `vec:`/`fn:` never contributing a
  cycle edge; `:c::cyclic?`/`:c::dfs-reaches` (4774, 4786) find self- or mutually-recursive
  shapes; `:c::glue-census` (4808) keeps the non-cyclic, non-empty shapes and pairs every
  `vec:T` (T a pointer) with a `node:T` trie-walker.
- The bodies: `:c::rec-glue-body`/`:c::rec-glue-fields` (4841) walk a record's fields by the
  mask, each through `:c::emit-drop`; `:c::henum-glue-body`/`:c::henum-glue-tags`/
  `:c::henum-glue-drop-fields` (4901) read the tag at `[rbx+8]` and dispatch, every payload tag
  tested explicitly, no positional fallthrough; `:c::vec-glue-body` (4918) walks a flat
  Vector's elements or a trie's root; `:c::node-glue-body` (4980) is the self-recursive,
  bounded-depth (≤13) trie-node walker.
- Placement: `:c::glue-pass`/`:c::glue-place`/`:c::GPassR` (5043-5073) place the whole set the
  same two-pass way `:c::place` places `:c::Prog/fns` -- measured once with every glue address
  at a placeholder (a `call rel32` is five bytes regardless of the value it carries, so the
  placeholder cannot change a length pass two would disagree with), then placed as one section
  after the user code and before the runtime block (`elf/compile.wat:9331-9424`,
  `:c::compile-as`: `gtys0`, `pg0`, `gp1`, `gaddrs`, `pg1`, `gp2`, `glue-hex`, each new binding
  named for what it threads). `:c::Prog` gained `:gtys`/`:gaddrs` (1245-1246).
- The one call site: `:c::dropchk-hex` (4349) -- unchanged in shape from G5, with one new
  condition. When a type has glue, the zero-check runs REGARDLESS of the check build (a plain
  build must also call the glue), and the call is wrapped `push rax` / `call` / `pop rax` (see
  the first bug below) before the existing G5 poison. A type without an entry is still exactly
  one `dec`, byte for byte what it was before this round.

### Which types have glue, which recursive types do not

From the compiler's own self-compile (confirmed by a sandbox debug build that printed
`:c::Prog/gtys` alongside each address): 46 entries -- 26 `rec:` shapes (`rd::Node`, `rd::St`,
`c::Buf`, `c::Cap`, `c::Out`, `c::Bind`, `c::Bnd`, `c::Fn`, `c::Rec`, `c::Enum`, `c::Alias`,
`c::Src`, `c::Prog`, `c::TC`, `c::Census`, `c::HG`, `c::GPassR`, `c::BindR`, `c::Agg`, `c::Sc`,
`c::PassR`, `c::NodeR`, `c::KidsR`, `c::LocW`, `c::KidL`, `c::Lft`) and 10 `vec:`/`node:` pairs
(elements `rd::Node`, `str`, `c::Bnd`, `c::Bind`, `c::Enum`, `c::Rec`, `c::Alias`, `c::Fn`,
`c::Cap`, `c::Src`). None excluded: the compiler's own types still have no cycle, matching the
crawl's and the first strike's census. The one recursive type in the fixtures,
`elf/probe/drop-3b-list.wat`'s `:user::L` (`:Cons [k nxt <- :user::L]`), is a direct henum-to-
itself edge and gets no glue, by design -- its references leak, late, never early, same as
before this round; the fixture still agrees both ways (below).

### Two real defects found and rooted, both via the gdb watchpoint method

**1. A glue call clobbers `rax`.** Every glue body ends its own walk with `rax` holding
whatever it last touched, exactly like any other callee in this compiler (rax is scratch, never
preserved) -- but `:c::dropchk-hex`'s poison write, emitted right after the call, assumed `rax`
still held the dying object. First found by hand-reproducing the native chain (seed → s1) and
breaking at `:c::at-uflow` under gdb: `[rax-8]` was already `-1` on arrival (the increment-side
check), and a disassembly of the record-glue call site showed the poison writing through a
`rax` the glue call had overwritten. Fixed at the one call site, `elf/compile.wat:4376-4392`:
the call is now `push rax` / `call` / `pop rax`, restoring the object before the poison. No
glue body needed to change.

**2. A trie node's own count was never decremented.** `:c::rt-node-copy`'s children are
SHARED, persistent structure -- two Vector versions can point at the same node -- which is
exactly why a node has its own `[count]` word in the layout. The first draft of
`:c::vec-glue-body` and `:c::node-glue-body` recursed into a root or child node
UNCONDITIONALLY, never touching that count, so a shared subtree's leaves could be walked (and
decremented) once per Vector version that happened to reach it, not once per reference. Found
by reproducing the native chain against the FULL corpus (not a small fixture): `s1.elf`, built
cleanly by the interpreter from this round's first draft, crashed with `wat: reference count
underflow` while compiling `elf/src/borrowed.wat` -- i.e. while running its OWN, newly-glued
`:c::PassR`/`:c::Prog`/etc. machinery natively for the first time, a case no small test program
exercises. A hardware watchpoint (gdb, ASLR off, `starti`) on the dying object's count word
showed it incremented to 6 (one alloc + five ordinary shares) then decremented six times in a
row from the SAME program counter -- inside `:c::node-glue-body`'s leaf branch -- before the
very next increment hit the poison. Disassembly of that address confirmed it: the vec-glue
root-read and the node-glue child-read each jumped straight into the next level with no
decrement of their own. Rooted by adding the same decrement/zero-check/conditional-recurse
shape every other glue call already has, at both entries (`elf/compile.wat:4930-4952`, the
root; `elf/compile.wat:5005-5029`, each interior child), each wrapped in the same
push-rax/pop-rax as defect 1. A synthetic fixture built to reproduce it directly (two live
Vector versions sharing trie structure past the 32-element first level, scratchpad-only, not
committed) did NOT reproduce the crash even on the pre-fix code -- the sharing shape the real
corpus hits is apparently narrower than what that fixture built; the defect and fix stand on the
chain reproduction and the watchpoint trace, not on that fixture, and are not reported as a
STOP because both the dead object's history and the fix were named and verified, not guessed
at.

### A third, smaller defect: a gate, not the compiler

After both fixes, `tools/elf-run.sh` (inside `tools/verify.sh`) failed a DIFFERENT check:
`tools/reads.sh` flagged five new heap-load spellings in the glue bodies as "a heap load
outside `:c::read-out`" (F-188's static audit). All five are loads of a field made in order to
DROP it as the object dies, never to keep a new reference -- not the shape `:c::read-out`
guards against. Added to `tools/reads.sh`'s `ALLOW` list with the reason for each
(`tools/reads.sh`, five new entries, one per exact spelling: `:c::rec-glue-fields`'s field read,
`:c::henum-glue-drop-fields`'s payload read, `:c::henum-glue-body`'s tag read, and
`:c::vec-glue-body`'s shift and root reads). `bash tools/reads.sh` alone: `reads: ok`.
`tools/copies.sh`/`tools/rsp.sh` were unaffected (`ok`, unchanged).

### Fixtures

All 22 `elf/probe/drop-*.wat` (every file except `drop-cons.wat`, per the brief), run through
`tools/probe.sh` and `WAT_DROP_CHECK=1 tools/probe.sh` on the real, fixed tree: all 22 `agree`,
both ways, including the three `drop-3b-*` fixtures (`"99999000000"`, `"744500"`,
`"1188895"`, matching the brief's own table) and `drop-concat-box.wat` (`"4abcd4!"`). Beyond the
required set, as extra confidence in the trie/henum paths this round added: `elf/src/matchval.wat`
(a real, self-referential tier-3 `henum` with a `Vec` variant -- `:user::Val.Vec [xs <- (Vector
:- [:user::Val])]`), `elf/src/option.wat`, `elf/src/enums.wat`, `elf/src/shapes.wat` -- all
`agree`, both ways.

### The chain

Sandbox `/tmp/s3b1r3` (deleted after), `WAT_DROP_CHECK=1` throughout: `seed` (the interpreter,
1,174,774 ms, `compiler.elf` 506,342 bytes) → `s1` (that binary, run natively: the full
103-binary corpus, `compile: ok`, no crash -- this is the run that caught defect 2 on the
PRE-fix source and confirmed clean on the fixed source) → `s1` copied to `s2`: already
byte-identical (`s1 == s2`) → `s2` → `s3`: byte-identical → `s3` → `s4`: byte-identical. Fixpoint
reached at `s1`, confirmed stable three hops further. The plain (`WAT_DROP_CHECK` unset) chain
was built the same way in the same sandbox and also reached its own fixpoint cleanly (406,041
bytes after the real-tree run below; not separately re-chained in the sandbox once the real-tree
gates were running, per the budget note in Method).

### Both gates, on the real tree, in sequence

`tools/verify.sh`: stage 0, 103 binaries in 1,213,916 ms, compiler 406,041 bytes; stage1 ==
stage2 byte for byte (406,041 bytes), "The compiler reproduces itself." `elf-run: ok -- 103
native binaries. 54 agree with the interpreter; 3 more use syscalls it has no implementation of
(F-119); 11 refusals and 4 traps, both ways. rules: 0 conflicts in 14120 argument-parameter
pairs (14047 equal, 73 a variant to its enum) over 158 programs. types: 0 type conflicts in
25384 nodes both typed (25384 agree, 0 refined) over 158 programs.` **`verify: ok`.**

`WAT_DROP_CHECK=1 tools/verify.sh`: stage 0, 103 binaries in 1,484,365 ms, compiler 506,342
bytes; stage1 == stage2 byte for byte (506,342 bytes), matching the sandbox chain's own
fixpoint exactly. `elf-run: ok` -- same shape as the plain run (54 agree, 3 syscall-gap, 11
refusals, 4 traps both ways; rules 0 conflicts, types 0 conflicts) -- zero underflows across the
whole corpus, both stages. **`verify: ok`.**

Both runs used `nohup ... & ; timeout 590 tail --pid=<PID> -f /dev/null` (repeated) or an
equivalent `until ! kill -0 <PID>` background wait, per the brief; neither was wrapped in a
short `timeout`. Logs: `/tmp/verify-plain-r3-clean.log`, `/tmp/verify-check-r3.log` (outside the
tree, left on disk, not part of the deliverable).

### What was not done

`tools/bench-coll.sh` and the two-hop instrumented instruction count against stones 1 and 2:
not run. G1 moves no number `tools/bench-coll.sh` measures by itself (freeing is G4, a later
strike) and the round's remaining room went to rooting the two defects above rather than to a
measurement neither gate asks for this strike. G2 (closures), G3 (the worklist for genuinely
recursive user types), G4 (freeing) are untouched, as scoped.

### Left for the next round

3b-2 (G4, freeing): the sizes are already derived in this document's earlier "G4" section;
nothing in this round changes that. 3b-3 (G2/G3): closures and the intrusive worklist for
recursive types like `elf/probe/drop-3b-list.wat`'s `:user::L`, still leaking by design until
then. Both remain exactly where the WEIGH left them.
