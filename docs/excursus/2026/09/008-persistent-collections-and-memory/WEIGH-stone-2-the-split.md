# WEIGH — excursus 008 stone 2: the contract holds; STOP-2 fired, and its split is owed

2026-09-27.

## Credited

`poke` of a pointer refused at compile time (`compile: cannot compile poke of a pointer`), the thread
programs agreeing; the four pointer-copying routines, `tree_push`'s leaf walk and the old-root store all
increment, `rt-cpath` correctly classified as bytes; the compiler tells the runtime which slots are
pointers (`r10`, `r11`) so a large `i64` is never mistaken for one — a record over 64 fields is a named
compile failure; `tools/copies.sh` in `elf-run`, its plant refused; gates zero; a fixpoint at 304,181
bytes; programs that copy no pointer slot byte-identical (`arith.elf`). The three defects the first red
run exposed (`r10` clobbered across `node_new`; `rdx`/`r11` not restored by `node_copy`; the pad popped
into `rax`) were this strike's own and are disclosed. The mutants not diverging is ACCEPTED with its
reason: nothing drops yet, so no printed value depends on an increment until stone 3.

## Back — STOP-2's split

Instructions **+10.22%** (303,213,642) for the compiler compiling the corpus. The brief's STOP-2 asks for
the split per routine; the SCORE gives none. The builder cannot accept or refuse a cost whose parts are
unseen. So:

1. **The split**: rebuild the compiler five ways, each with ONE routine's increments removed (the
   stone-1 fixpoint and the full stone-2 fixpoint are the two ends), same input, same method — the
   instruction delta each routine accounts for. `perf record` on the stone-2 compiler, if it attributes
   cleanly, is a cross-check, not a substitute.
2. **The hottest sites**: for the top routine, which CALL SITES in the compiler drive it (the orchestrator's
   unmeasured guess: `assoc` on `:c::Prog` / `:c::Out`, each copy now incrementing every pointer field).
3. **What would recover it, as data, not a change**: whether those sites could use an existing in-place
   path (`slot-own`, as `conj` has `vec_conj_own`) — say what it would take; change nothing.

Append a section to the SCORE; the tree stays as it is.

---

# Round 2 — the split says the increments are not the cost (2026-09-27)

Measured by the strike: the five routines' increments together account for **11,253,471** instructions —
**3.7%** of the +303,213,642. `perf record` lands on string equality and `concat`, not the counting walks.
**About 292 million instructions (96% of the rise) are unattributed.** An unexplained 10% can hide a
defect — this strike's first run exposed three — so it cannot be accepted as "the price of counts".

**The orchestrator's unmeasured suspicion:** the PLUMBING added to every call, not the counting — every
conj site loading the pointer flag into `r10`, every assoc site loading the mask into `r11`,
`tree_from_arr` saving and reloading `r10` around every push, `node_copy` saving/restoring `rdx`/`r11`,
and any walk that now visits slots even when its flag is 0.

**Owed:** attribute the other ~292 million — by routine, from `perf record` sample addresses mapped onto
the runtime layout's entry offsets (`:c::at-*`), comparing the stone-1 and stone-2 compilers on the same
input; and by call-site plumbing (a compiler with the flag/mask loads but no runtime change, if that
isolates it). Say where the 292 million are, and whether any of it is a defect rather than a cost.

**Credited as data, and carried to stone 3:** `:c::emit`'s `assoc` on `:c::Out` cannot take
`rt-slot-set-own` because a record passed on arrives with count ≥ 2 (`:c::share` increments it) and
`linear` names parameters only. Stone 3's settled ownership rule MOVES a last-use argument (no
increment), which would put that `assoc` on the in-place path.
