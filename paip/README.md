# PAIP, in wat

NEXT.md's fifth acceptance test: Norvig's *Paradigms of Artificial Intelligence Programming*,
chapters 11 and 12 — unification, and a Prolog built on it. NEXT.md says these chapters are
"where quoted data versus typed data gets decided", and that is exactly what they decide here.

The code is our own implementation of what the chapters build, on both sides. Norvig's own code
is neither read nor copied, the rule the Pie and malt ports follow. The oracle is our own Scheme
(`oracle/paip/NAME.scm`), run by guile through `tools/paip-oracle.sh`, whose results the wat
chapter must print in order (`lib/check.wat`).

Guile rather than Clojure, because the subject is quoted S-expressions and guile keeps them
that way.

## Chapters (2026-09-15, wat-rs `a3218644d`)

| chapter | what it builds | results |
|---|---|---|
| ch11 unification | `variable?`, `unify`, the occurs check, `subst-bindings`, `unifier` | 25, all matching guile |
| ch12 prolog | clauses, renaming variables apart, `prove`, `prove-all`, backtracking | 33, all matching guile |

## Where quoted data runs out

Chapter 11 ports to quoted data completely, because every pattern in it is a proper list.
Chapter 12 is where the road ends. PAIP's membership clause is the classic recursive one, and
both of its heads carry a list with a **variable tail**:

```
((member ?i (?i . ?rest)))
((member ?i (?head . ?rest)) (member ?i ?rest))
```

wat's reader has no dotted pair. `(?i . ?rest)` reads as a `"list"` of *three* children — `?i`,
a symbol named `.`, and `?rest` — and then `ast->source` prints it back as `(?i . ?rest)`, so it
round-trips and looks preserved while meaning something else (F-059,
`probes/paip/dotted-pattern.wat`). The membership clauses cannot be written, so they are not in
the database and not in the oracle either.

This is the same wall The Reasoned Schemer hit, and the reason `:rs::Term` exists at all: its
chapter 10 says "Quoted lists can't hold a pair with a variable tail, `(a . d)`, so terms are
their own enum". Two ports reached it independently.

So NEXT.md §5's question — quoted data or typed data — has an answer with a line in it: quoted
data carries symbolic pattern matching as far as the improper list, and no further.

## The decision: patterns are data

The Reasoned Schemer already took the typed road. Its `:rs::Term` is a four-variant enum, and
`rs/q` converts a quoted form into it immediately — it had to, because a quoted list cannot hold
a pair with a variable tail, `(a . d)`.

PAIP asks for the other road, and wat can take it. A pattern here is an ordinary quoted form:

```
(:wat::core::quote (?x + 1))
```

and a variable is a symbol whose text begins with a question mark. Nothing is converted.
`lib/unify.wat` walks `:wat::WatAST` itself, and the chapter passed on its first run.

## What the chapter showed

- **Quoted data is a workable representation, not just a readable one.** Six primitives carry
  the whole chapter (`probes/paip/ast-as-data.wat` measures each): `ast-kind` is total and says
  `"symbol"`, `"list"`, `"int"`; `ast-name` gives a symbol's verbatim text; `ast->children`
  decomposes a list and yields nothing for a leaf; `with-children` rebuilds a node of the same
  kind; `=` is structural on nested forms; and `ast->source` prints a node back as source.
- **`ast-name` raises on anything that is not a Symbol, Keyword or StringLit.** So every
  `?`-test must check `ast-kind` first. That is the one trap in the chapter, and it is a
  documented contract rather than a defect.
- **wat prints what guile prints.** `ast->source` renders `(2 + 1)` and `(?x (f ?y))` exactly as
  guile does, so the chapter needs no printer of its own and the results compare as strings.
- **A substitution keys on the variable's name, not its node.** Two `?x` nodes read from two
  different quoted forms are different AST nodes but one variable.
- **It is a `PersistentMap`.** A unifier extends its substitution once per variable it meets,
  which is exactly the accumulation `HashMap` charges quadratically for (F-057). The lesson from
  Advent of Code, applied rather than rediscovered.
- **Failure is `Option.None`.** PAIP uses the symbol `fail`; wat has no failure marker, and an
  enum of two cases would be the typed representation these chapters exist to avoid.
- **Definition order didn't matter.** `occurs-in?`/`occurs-in-all?`,
  `unify`/`unify-variable`/`unify-all` and `subst`/`subst-all` each call a function defined
  below them, and the checker resolves it.
- **Binding lists must be sorted before printing.** `:wat::map::keys` is documented as pure and
  total but **not deterministic** — "the trie has no meaningful order" — and `:wat::hashmap::keys`
  says the same. The oracle prints sorted for the same reason.

## Running

```
tools/paip-oracle.sh ch11-unification   # guile writes oracle/paip/ch11-unification.expected
wat paip/ch11-unification.wat           # the chapter, checked against it
./run.sh                                # every chapter, with every book
```
