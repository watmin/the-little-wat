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
