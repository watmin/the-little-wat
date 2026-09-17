# EOPL — *Essentials of Programming Languages*, Friedman & Wand — NEXT.md §9

The big uncovered Friedman. Chosen for what it stresses: **wat as a language host**, which is what
the rest of the roadmap sits on.

The book's method is to build one language (LET → PROC → LETREC) and then change only how it is
*executed*. That makes it unusually good for this repository: the same program run two ways is a
controlled experiment, and the difference between the two is a property of wat rather than of the
port.

## Scope

**14 of the book's 22 languages and topics are done; chapters 4, 5, 6 and 8 are complete.** NEXT.md §9
carries the full table, including the items still outstanding inside chapters that were previously
reported as complete. What is here is chapter 3's LETREC language, all of chapter 4 (EXPLICIT-REFS,
IMPLICIT-REFS, call-by-reference, MUTABLE-PAIRS and the three parameter-passing disciplines),
chapter 5's CPS interpreter, exceptions and threads, and chapter 7's checker and type
reconstruction — one language, four machines, a store and a type system. EOPL is nine chapters;
see NEXT.md §9 for the table of what is left. **No skipping** (builder's ruling, 2026-09-16):
duplication is cheaper than an omission.

## Chapters (2026-09-16, wat-rs `a3218644d`)

| chapter | machine | result |
|---|---|---|
| 3 | direct recursion on the host stack | correct; **segfaults between interpreted depth 40000 and 50000** (F-099) |
| 4 | EXPLICIT-REFS: a store | ports; and mutable state priced three ways — **threaded map 10610 ns, Lru cell 35034, service ~448000** (C-066) |
| 4 | by-value / by-name / by-need | all three agree; by-name is **O(n²)** where by-need is **O(n)** — 460× at depth 1200 (C-062) |
| 4 | IMPLICIT-REFS + call-by-reference | the same program answers **0 by value, 99 by reference**; a non-variable argument answers 99 under both (C-068) |
| 4 | MUTABLE-PAIRS | a pair is two adjacent cells — aliased 99, rebuilt 1, no new store machinery (C-069) |
| 5 | continuation defunctionalized + trampoline | correct; reaches **300000** and is bounded by the heap (C-061) |
| 5 | exceptions: a handler as a continuation frame | installing one costs **4 transitions**; unwinding is O(depth); wat's own catch is a 1.44 ms thread spawn (C-065) |
| 5 | threads: a scheduler on continuations | a real mutex, and the lost update on demand — 40/80 at slice 1, 80/80 at slice 1000 (C-064) |
| 6 | CPS transformation, source to source | the SAME direct interpreter dies at **n=25000** on the source and reaches **100000** on its transform (C-070) |
| 6 | registerization | `step`/`drive` is **~1.9× slower** than mutual tail calls — it must allocate the State it returns (F-105) |
| 8 | SIMPLE-MODULES / OPAQUE-TYPES | one word — `opaque t` vs `transparent t = int` — decides whether the outside may do arithmetic (C-071) |
| 8 | parameterized modules (functors) | the same module satisfies a `zero : int` requirement transparent and **fails it sealed** (C-071) |
| 7 | **CHECKED**: a checker over annotations | rejects wrong annotations the inferencer cannot see (C-067) |
| 7 | type reconstruction by unification | 5 types inferred and cross-checked against the evaluator; 5 rejections **including the occurs check** (C-063) |

## What chapter 5 settled

F-099 says a non-tail recursion past ~110000 frames segfaults with an empty stderr. A direct-style
interpreter turns the **interpreted** program's depth into wat's depth, so that ceiling lands on
the *user's* program — at roughly 45000 interpreted frames, because each interpreted call costs
several host frames.

Chapter 5's defunctionalized continuation moves that depth into the heap and the trampoline keeps
the host stack constant. **In wat this is not a presentation choice.**

## The accident worth keeping

The first test program was tail-recursive in the interpreted language, and the direct machine
handled it at every depth. wat's TCO is preserved *through* the interpreter: an interpreted tail
call lands in tail position inside `value-of`, so the host collapses that frame too. The ceiling
exists only for interpreted recursion that must return — and the test had to be rewritten (the
recursive call moved inside a `Diff`) before the two machines could be distinguished at all.

## Running

```
wat eopl/ch05-cps-interpreter.wat
./run.sh eopl
```

## What chapter 4 settled

A calling convention sounds like a deep property of a language. Written out, **call-by-reference
is one predicate** — *is this argument expression a bare variable?* — and a two-variant enum.
Everything else is shared with call-by-value.

The other half of the definition is the row that is easy to leave out: when the argument is an
expression rather than a variable, the two conventions **must agree**, because there is no cell to
alias. `ch04-implicit-refs.wat` prints both rows for that reason.

And all of it is built in a language with no mutation. The store is threaded as a value and
returned in the answer — which is also, exactly, the fourth component a CEK machine carries. Three
of these chapters (`cps.wat`, `threads.wat`, `implicit.wat`) now have the shape that work wants.

## What chapter 6 settled

Chapter 5 changed the machine; chapter 6 changes the **program**. In Scheme that is a theorem you
take on faith, because the host stack grows. wat has a ceiling to hit, so it can be measured: one
program, one interpreter, before and after.

Two of my own metrics had to be thrown away first, and the numbers that show why are printed by
`ch06-cps-transform.wat` rather than smoothed over. "Every call becomes a tail call" is **false**
in this encoding — LETREC procedures take one argument, so the continuation is curried and
`((f a) k)` contains a real non-tail call. The property that does hold is a **grammar**: every
operator and operand is a SimpleExp. Source 2 violations, output 0.

And registerization — the shape a CEK evaluator would naturally take — turns out to **cost** here,
about 1.9×, because `step : State -> State` must allocate the state it returns. It is a choice
rather than a necessity, because wat's TCO spans **mutual** tail calls (10,000,000 verified), which
many implementations do not.

## What chapter 8 settled

NEXT.md flagged chapter 8 as the closest to wat's own design, and the port says precisely what
wat has and lacks.

wat has the **distinctness** half. `:wat::core::newtype` refuses arithmetic on the type and
refuses a raw `i64` where the type is wanted — both at startup, both directions. A `typealias`
does neither; it is an alias.

wat lacks the **sealing** half. `newtype` auto-mints a constructor at the bare name and an
accessor at `<Name>/0`, and both resolve from any namespace, so anyone can unwrap and rewrap.
EOPL's `opaque t` gives the outside a name and nothing else. That has no wat spelling (F-106).

The chapter's own positive control is worth keeping in mind when reading the table: a sealed
module's **own** operations keep working, and `to-int` is the hole the interface deliberately
leaves. Abstraction hides; it does not forbid. A checker that rejected those rows too would be
rejecting everything and proving nothing — which is exactly the bug the functor row caught in my
first `satisfies?`.
