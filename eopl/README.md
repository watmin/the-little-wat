# EOPL — *Essentials of Programming Languages*, Friedman & Wand — NEXT.md §9

The big uncovered Friedman. Chosen for what it stresses: **wat as a language host**, which is what
the rest of the roadmap sits on.

The book's method is to build one language (LET → PROC → LETREC) and then change only how it is
*executed*. That makes it unusually good for this repository: the same program run two ways is a
controlled experiment, and the difference between the two is a property of wat rather than of the
port.

## Scope

**This is ~15% of the book.** What is here is a slice of chapter 3 (the LETREC language) and a
slice of chapter 5 (the CPS interpreter) — two machines over one language. EOPL is nine chapters;
see NEXT.md §9 for the table of what is left and why chapter 7 (types) is the most valuable of it.

## Chapters (2026-09-16, wat-rs `a3218644d`)

| chapter | machine | result |
|---|---|---|
| 3 | direct recursion on the host stack | correct; **segfaults between interpreted depth 40000 and 50000** (F-099) |
| 5 | continuation defunctionalized + trampoline | correct; reaches **300000** and is bounded by the heap (C-061) |

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
