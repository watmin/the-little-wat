# Excursus 001 — reclamation beyond scope

**Status: 2026-09-23.** **Stones 0, 0a and 0b LANDED.** F-188 is closed -- NINE doors -- with
every read out of a container going through `:c::read-out` (checked by `tools/reads.sh`), and its
cost (F-189) is 71% recovered in INSTRUCTIONS by guarding each type only against what it can be --
but stone 0 costs ~5-7% in TIME, and 0b's time recovery is inside the measured 1.8% layout floor
(F-192). The remaining ~5% of cycles is recorded, unexplained; the memory touch is the hypothesis. **Stone 1** -- the caller-side release -- is
next: it stays HELD on `excursus-001-stone-1` until it is rebased onto `main`, takes an
`allocates?` gate, and gets a real flatness gate in `mem.sh` §7.

> Builder: *"i explicitly do not want a gc that pauses anything.. can we do this inline as we make
> forward progress in programs?"* — and, on ordering: *"do the hard, correct thing first and
> everything downstream inherits it?"*

## What already exists — the reason this is small

**Read this table before proposing anything.** F-187 exists because I did not: I reported that
reclamation did not exist, designed a three-strike arc on the belief, and was wrong. It has
shipped since C-120.

| capability | where it lives, today | evidence |
|---|---|---|
| a heap free | statement-boundary release: mark `r15`, restore `r15` | `elf/compile.wat:3652` — the section is titled *"Why a bump allocator can free"* |
| its emission | `push r15;push r15` / `pop r15;pop r15`, 8 bytes, nests for free | `elf/compile.wat:3805` `:c::seq`, gated on `drop?` |
| its soundness gate | a statement that transitively reaches `poke` is not released | `:c::releasable?` = `(not (calls-poke? a pg))`, a fixpoint over `Prog/fns` |
| a bounds check | every allocator compares against the limit at `r14+8`, calls `oom()` | `elf/lib/runtime.wat:526`, `:983` |
| "is this the youngest allocation?" | a 2-instruction runtime test, already load-bearing | `elf/lib/runtime.wat:563`, `vec_conj_own` path 3 |
| liveness | *does `name` get read anywhere that runs AFTER this point* | `elf/compile.wat:2787` `:c::live-after` |
| escape, on parameters | *the parameters of this function that nothing ever retains* | `elf/compile.wat:2946` `:c::ronly-of`, stored in `Prog/ronly` |
| freshness | `concat`/`subs`/`to-string` write a new block on every path | `elf/compile.wat:2995` |
| the instrument | peak RSS, `ru_maxrss`, six sections incl. *"does the release free anything still live?"* | `tools/mem.sh`, dated 2026-09-18 |

So this excursus builds **no allocator, no collector, no analysis, and no instrument.** It is one
composition of things already here.

## The limit, stated where the release is

`elf/compile.wat:3681` draws its own boundary and names the next move:

> *"Anything whose allocation ESCAPES upward still accumulates… Freeing those needs reachability,
> not scope — a collector, or **a caller-side release at every call whose return type is not a
> pointer. The second is the next thing to build** and is the same idea one level up; the first is
> a different program."*

## Stone 1 — the caller-side release. DRAWN.

A call whose callee's **declared** return type is not `ptr-ty?` cannot hand back anything pointing
into what it allocated. So the caller marks `r15` before it and restores after — C-120's idiom,
one level up from statements to calls.

The fixture is `elf/src/escape.wat`, in the corpus, agreeing both ways, **measured leaking before
the brief was written** — 63.8 bytes/iteration, linear:

| n | peak RSS | bytes/iteration |
|---|---|---|
| 1,000,000 | 62.4 MB | 63.2 |
| 2,000,000 | 123.8 MB | 63.8 |
| 3,000,000 | 184.7 MB | 63.8 |

`optmh.elf` at 610.9 MB against `optm.elf`'s 2.1 MB (F-185) is the same gap at scale.

## Two facts the crawl pinned that are NOT written down elsewhere

1. **`:c::live-after` is name-keyed.** Its signature takes `name <- String`, so it answers about
   *named bindings only*. An anonymous temporary — `optmh`'s `(user/pick s i)` inside a `match` —
   **cannot be asked about at all.** Any design that assumed "ask liveness about the temporary" is
   not reachable with today's machinery. This killed the first version of this excursus.
2. **The reservation was never the cost.** The heap is 1.9 GB of `MAP_ANONYMOUS|MAP_PRIVATE`,
   committed lazily: `optm.elf` maps all of it and is 2.1 MB resident. 64 GB maps for free on this
   box (measured); 1 TB is refused by the overcommit heuristic. Raising the ceiling is free and
   fixes nothing, so it is not drawn.

## The one candidate NOT drawn — releasing to the OS

`madvise(MADV_DONTNEED)` returns physical pages and is one syscall. It is **deliberately not a
stone**: with the bump pointer rewound, the pages above `r15` are already reusable, so returning
them buys RSS-as-reported and not a single allocation. It is recorded here so the case for it
stays honest — the motivation is cosmetic until something measures otherwise.

## Not drawn — `own?` keyed on the binding rather than the spelling

`own?` asks `linear?` about a parameter by its NAME, and `:c::occ` counts a name's occurrences
straight through a shadowing `let` -- so a shadowing binding's uses are charged to the parameter.
That can only OVER-count, which is conservative, but it could cost a genuinely linear parameter its
in-place growth -- the F-141 quadratic. Probed before briefing (2026-09-23): two programs identical
except the spelling of one inner `let` binding (`acc`, shadowing the linear accumulator, against
`b`), `conj` in a loop at n = 2000/4000/8000. Both flat at ~2.1 MB; **the two binaries are
byte-identical.** The spelling changes nothing emitted, so there is no failing probe, and by
examinare's rule there is no stone. After stone 0 correctness does not rest on `own?` at all -- it
rests on the count being complete, which is what stone 0a is for.

## What a collector would be, and why it is not this

Anything whose allocation escapes *upward through a return of pointer type* needs reachability,
not scope. That is a different program, it is the thing the builder ruled out — *"i explicitly do
not want a gc that pauses anything"* — and nothing in this excursus moves toward it.
