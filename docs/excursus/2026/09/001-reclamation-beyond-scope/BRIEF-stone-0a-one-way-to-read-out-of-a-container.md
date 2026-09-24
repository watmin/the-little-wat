# BRIEF — stone 0a: there is one way to read a pointer out of a container, and it counts

> Stone 0 closed F-188 by adding `:c::count-read` at every site that reads a pointer out of a heap
> container. It is correct TODAY. Nothing makes it correct TOMORROW: the next read verb — a map
> `get`, on the REPL's precursor list — can load a pointer without counting it, and F-188 re-opens
> silently. This stone takes that from a convention to a structure.

## THE DEFECT — the decision to count is spread by convention

A read out of a container is emitted in several spellings, and each had `count-read` bolted on by
hand in stone 0:

```
nth, array arm      raw hex  "488b44c808"                  elf/compile.wat:~1860-1885
nth, trie arm       a call into the runtime (at-tget)      same site
field accessor      THREE arms: mov-rr / mov-rm / load-at   elf/compile.wat:~1905-1928
match payload       load-at, tiers 2 and 3                  elf/compile.wat:~3350-3365
```

**The evidence that forgetting at one site re-opens doors is already on disk** — stone 0's SCORE,
row 8: each site was ablated and rebuilt, and `elf/src/borrowed.wat` diverged on exactly that
site's lines. So the failure mode is real, measured, and currently one missed call away.

★ **This is the session's own rule, one more time:** *wherever two parts of the compiler must agree
about a form, the agreement is ONE function both call.* It produced `tail-nodes`, `eval-seq`,
`quiet-nodes`, `self-slots`, `variant-arg`, and — in stone 0 — `:c::count-hex`, which already makes
the BYTES of a count one function. The DECISION to count is still N functions.

## THE RULING — builder, 2026-09-23

> *"are we doing somthing many ways when it should be one way?"* … *"0a is named next"*

## THE CONTRACT DECISION — pinned

**Every read of a value out of a heap object is emitted by one function that takes the value's
TYPE as a required argument and counts by construction.** A site states what it read; it does not
decide whether to count. An unknown type is a `:c::fail`, never a default — which removes the
`match` site's fail-open fallback (`elf/compile.wat` ~3357 and ~3363: an unresolvable field index
becomes `"i64"`, which emits NO count) as a consequence, not as a separate edit.

## READ IN ORDER

```
docs/excursus/.../SCORE-stone-0-count-at-the-read.md   the census of read sites, and the ablation
elf/compile.wat  :c::count-hex, :c::count-read          the bytes, and the one caller stone 0 added
elf/compile.wat  the nth site                           array arm + trie arm
elf/compile.wat  the record field accessor              all three arms, including the scalarised one
elf/compile.wat  :c::match-form's payload binding       and its two fail-open fallbacks
elf/src/borrowed.wat                                    the oracle: one marked line per site x door
```

Line numbers moved in stone 0; find each by its name. **How the load and the count become one
function is yours to derive** — the trie arm's load happens inside the runtime, so "one emitter" may
mean one function that owns the count for every read kind rather than one that also owns every
load. Say in the SCORE which it is and why.

## THE WORK

1. **One function, required type, counting by construction**, through which every read out of a
   heap object goes. `:c::count-read` stops being something a site can choose to call.
2. **Its prose names the obligation for the next read verb** — a map `get`, `first`, anything that
   answers a value held by a container — so the next person who adds one finds the door in the
   function they have to call.
3. **Report the rung reached, honestly.** A CONVENTION ("call this"), a CHECK (something fails when
   a site bypasses it), or UNREPRESENTABLE (a read cannot be written down without it). The material
   may not allow the top rung in this dialect; if so, say which rung was reached and what would be
   needed for the next.

## STOP TRIGGERS

- **STOP-1 — you are about to change what any program emits.** This is a refactor of the compiler's
  structure. Every corpus program's bytes are identical before and after; `tools/emitted.sh` moving
  anything but the compiler itself means behaviour changed. STOP and report which program moved.
- **STOP-2 — you are about to drop or skip a count anywhere**, including where it "cannot matter".
  That is F-188 re-opening.
- **STOP-3 — you are about to keep a default type for an unknown.** Unknown is `:c::fail`.
- **STOP-4 — a red.** Capture it; never re-run it.

## OUT OF SCOPE, AFFIRMATIVELY

Stone 0b's cheaper guard · the cost (F-189) · `own?`/`linear?` keyed on the binding (probed and found
to emit identical bytes — see the 0a note in FINDINGS F-191; not drawn) · F-190 and F-191 ·
`elf/lib/runtime.wat`.

## METHOD

`/home/watmin/Work/holon/the-little-wat`, branch `main`. `timeout -s KILL` on every wat run; tree
untouched while `bootstrap.sh`/`elf-run.sh` run; every replacement asserts it matched; `cond` ends
in `(:else …)`; bootstrap without `--fast`. **Every number in the SCORE is one you measured.**
**Leave the tree dirty; do not commit.** Write `SCORE-stone-0a-one-way-to-read-out-of-a-container.md`
beside this file, one section per EXPECTATIONS row, output pasted in.
