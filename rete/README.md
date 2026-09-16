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

Facts here are inserted and never retracted. clara does truth maintenance and wat's rete may
differ, so retraction is a separate question and is not asked yet.

## Running

```
tools/rete-oracle.sh r01-chaining   # clara writes oracle/rete/r01-chaining.expected
wat rete/r01-chaining.wat           # the same rules in wat, checked against it
./run.sh                            # every case, with every chapter
```
