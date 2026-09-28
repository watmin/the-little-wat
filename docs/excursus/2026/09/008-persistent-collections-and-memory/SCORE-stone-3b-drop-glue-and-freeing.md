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
