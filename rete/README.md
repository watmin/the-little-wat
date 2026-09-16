# wat's rete, against clara-rules

wat ships a production rule engine — `defrule`, `defquery`, a `Session` with alpha, beta and
production memories, negation, existence, nine accumulators, and a native Rust implementation
beside a pure-wat reference for every fire and insert verb. 134 verbs under `:wat::rete::`, 4154
lines of wat.

No suite here had touched it. Neither has any documentation: a word-boundary search for
`\brete\b`, `:wat::rete::` or `defrule` finds **zero** hits in `USER-GUIDE.md`,
`WAT-CHEATSHEET.md`, `CLOJURE-ROSETTA.md` and the docs `README.md` (F-065). Everything below was
recovered from `wat/rete/syntax.wat`, `src/rete/collect.rs` and the fixtures in
`wat-rs/tests/rete/`.

The oracle is **clara-rules**, the Clojure forward-chaining engine — the counterpart a Clojure
reader would arrive with, and the one `CLOJURE-ROSETTA.md` never mentions. The rules are ours,
written twice; nobody's code is ported. `tools/rete-oracle.sh` fetches clara through the
`clojure` CLI and pins the version.

## Cases (2026-09-15, wat-rs `a3218644d`)

| case | what it exercises | results | wat |
|---|---|---|---|
| r01-chaining | a guarded join, forward chaining, negation over a derived fact, existence, accumulation | 8, all matching clara | 0.57 s |
| r02-retraction | retracting a support: transitively, partially, and put back again | 8 — seven matching clara, one a documented difference (F-066) | 0.71 s |

The time is the whole run, wat's 0.29 s of startup included — so compiling the network, inserting
nine facts, computing the closure and reading four queries costs a few hundred milliseconds.

## What the first case showed

The engine is **correct**, on every question asked, first run:

- **Forward chaining works.** The derived `Shippable` feeds the rule that derives `Invoice`, so
  `fire-rules` computes a closure rather than one pass. Its source says why:
  `fire-rules$oracle` "delegates to fire-stratified … within each stratum fire-stratified still
  uses fire-fixpoint".
- **Negation over a derived fact comes out right** — `(:wat::rete::not (:sc::Hold (?id <- :id)))`
  applied to a `Shippable`. Stratification is what makes negation-over-derived correct, and it is
  the reason `fire-rules` is not a bare fixpoint.
- **`exists` is not a join.** Two suppliers for one part derive one `Sourced`, not two.
- **Accumulators see derived facts.** `(?n <- (:wat::rete::acc::count) :from (:sc::Shippable))`
  counts 2.

## The surface, since nothing else writes it down

```wat
(:wat::core::defrecord :sc::Order [id <- :wat::core::i64 part <- :wat::core::String])

(:wat::rete::defrule :sc::shippable
  :when [(:sc::Order (?id <- :id) (?part <- :part))
         (:sc::Stock (?part <- :part) (?qty <- :qty))
         (:wat::rete::where (:wat::rete::i64::> ?qty 0))]
  :then [(:sc::Shippable :id ?id :part ?part)])

(:wat::rete::defquery :sc::q-Shippable :params [] :when [(?f <- :sc::Shippable)])
```

- **facts** are `defrecord`s, not `defstruct`s — a fact is a `:wat::core::Record`;
- **`(?var <- :field)`** binds a field; the same `?var` twice is a join;
- **condition wrappers**: `(:wat::rete::where expr)`, `(:wat::rete::not (…))`,
  `(:wat::rete::exists (…))`, and `(?n <- (:wat::rete::acc::count) :from (:Record))`;
- **guards are type-namespaced**: `:wat::rete::i64::{< <= = > >= not= mod quot rem}`, and the
  same shape for `f64`, `string`, `keyword`, `bool`; plus `:wat::rete::core::{and or not if let
  match cond}` and `enum::=`. rete has its own `cond` and `if` on purpose;
- **accumulators**: `count`, `sum`, `min`, `max`, `mean`, `distinct`, `all`, `group-by`,
  `gather-vals`;
- **running it**: `(:wat::rete::collect-rules :ns)` reflects a namespace's rules,
  `compile-all rules queries` builds the `Session`, `insert` / `insert-all` add facts,
  `fire-rules` computes the closure, `query` reads a `(PersistentVector :- [PersistentMap])`
  whose keys are binding names **with** the question mark — the fact bound as `(?f <- :Type)`
  comes back at `"?f"`;
- **five fire verbs**: `fire-rules` (the public one, stratified), `fire-once`, `fire-fixpoint`,
  `fire-stratified`, `fire-rules-explain`. Nothing documents which to reach for; `fire-rules` is
  the answer.

## What retraction showed

r01 inserted facts and never took them back; `r02-retraction.wat` asks what happens when a
support goes away. `:wat::rete::retract` takes a session and a fact and drops every fact equal to
it **by value** (`wat/rete/oracle/insert.wat:77`), and the closure changes on the next
`fire-rules`.

The two engines get there differently: clara tracks dependencies, while wat recomputes —
"retract-then-fire recomputes the full closure from the reduced input, so consequences vanish
transitively" (`wat/rete/oracle/fire.wat:360`). **Seven of eight scenarios agree anyway**: a
derived fact goes with its support, it goes *transitively* (taking what was derived from it),
re-inserting restores the whole closure, retracting one of two supports leaves the fact standing,
retracting both clears it, and retracting an unrelated fact changes nothing.

The eighth diverges, and it is the interesting one (F-066). Two `Stock` lines match one `Order`,
so the rule fires twice and both firings derive the **identical** `Shippable`:

| | wat | clara |
|---|---|---|
| identical derived facts kept | **1** | **2** |
| `acc::count` over them | **1** | **2** |
| derived facts when the firings carry *different* payloads | 2 | 2 |

Both engines fire the rule once per support — the last row proves it — so this is a **collapse,
not a missing join**. wat's closure is a *set of facts*; clara's working memory is a *bag of
derivations* that happen to be equal. Each engine's accumulator then reports what that engine
holds, which is why the difference shows up twice rather than once.

It matters to anyone writing a rule that counts or sums over derived facts: in wat, "how many
ways was this concluded?" cannot be asked — the answer is always one. In clara that is the
default and distinctness is the thing you ask for. Neither is wrong, and nothing tells a reader
which they are getting, because nothing documents the rete at all (F-065).

`oracle/rete/r02-retraction.expected` therefore holds **wat's** answers, with clara's printed
beside them by `probes/rete/retraction-scenarios.wat`. Making the two agree would have hidden the
only interesting thing in the case.

## wat against itself: the native/oracle differential

Every fire and insert verb has two mouths — `fire-rules` reaches the Rust kernel, and
`fire-rules$oracle` is pure wat, which `wat/rete/oracle/fire.wat:356` calls **"the SPEC /
differential oracle"**. They are meant to agree, so this is a check wat can run on itself with no
other language in the room. It needs no oracle script and no clara.

They disagree (F-067). On a rule that counts a derived fact:

| fired with | tally values |
|---|---|
| `fire-rules` (native) | `2` |
| `fire-rules$oracle` (the SPEC) | `0\|2` |
| `fire-once` (native) | `0` |
| `fire-once$oracle` | *no rows at all* |
| `fire-fixpoint` | `0\|2` |
| `fire-stratified` | `0\|2` |

The accumulator runs on the first pass, before anything is derived, and asserts `n = 0`; the
next pass asserts `n = 2`; and because a closure is a set of facts (F-066), both survive. Only
the **bare** folds do this — `count` and `sum` leak a `0`, while `min` and `max` don't, because
an empty `Option` fold is dropped rather than asserted (`accum-pass.wat:16`).

What makes it matter beyond an internal discrepancy: `fire-fixpoint` and `fire-stratified` are
both public and user-callable, and they are the verbs a reader would reach for by name in a
forward-chaining engine. They silently return a superset of the truth, and nothing documents any
of this (F-065). That `fire-stratified` leaks locates the mechanism too — `fire-rules$oracle`
delegates to it, and each stratum still runs a fixpoint inside.

There is a second divergence in the same family, found by chasing an output line that looked
wrong. Counting rows instead of joining values:

```
fire-once        (native)  shippable rows: 2  tally rows: 1  derived facts: 3
fire-once$oracle           shippable rows: 0  tally rows: 0  derived facts: 3
```

Both derive the same three facts into production memory, but the oracle mouth answers **no query
rows at all** — the conclusions are there and nothing can read them.

Insertion, by contrast, is clean: `insert-all` and `insert-all$oracle` both leave 7 facts, and
all four insert×fire crossings agree. The divergence is confined to the fire path.

`fire-rules-explain` works and carries real provenance — a `DerivationNode` tree where `rule` is
`Some(name)` for a derived fact and `None` for an asserted leaf. Two support entries for a
two-layer derivation, and the same conclusions as a plain fire
(`probes/rete/explain-support.wat`). Another capability nothing tells you about.

**A spelling that cost me an hour, since nothing writes it down:** an accumulator's operand is a
`?`-variable bound in the `:from` condition — `(acc::sum ?q) :from (:R (?q <- :qty))` — not a
field keyword. `(acc::sum :qty)` raises `acc: var unbound` from `wat/rete/acc.wat:83`, deep in
wat's own source, where it reads like a defect in wat rather than a mistake in your rule.

## Running

```
tools/rete-oracle.sh r01-chaining   # clara writes oracle/rete/r01-chaining.expected
wat rete/r01-chaining.wat           # the same rules in wat, checked against it
./run.sh                            # every case, with every chapter
```
