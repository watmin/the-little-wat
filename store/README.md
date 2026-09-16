# wat's Store contract, checked against itself

wat ships a backend-agnostic storage contract — `:wat::query::Store`, a DynamoDB-shaped
`(pk, sk, data)` narrow waist with named GSIs, keyset pagination, and four operations
(`ensure-schema`, `put`, `scan`, `scan-index`) — and **two services that satisfy it**:
`:wat::query::mem-store` and `:wat::query::sqlite-store`.

So this suite needs no external oracle. `wat/query/mem.wat` says the in-memory store is
"dual-purpose … a genuine in-memory backend AND the oracle sqlite will be differential-tested
against — correct-by-construction, not a canned stub". The two backends check each other.

Like the rete, the whole thing is **undocumented**: zero word-boundary hits for `:wat::query::`
across `USER-GUIDE.md`, `WAT-CHEATSHEET.md`, `CLOJURE-ROSETTA.md` and the docs `README.md`
(the same gap as F-065).

## Cases (2026-09-15, wat-rs `a3218644d`)

| case | what it exercises | results | wat |
|---|---|---|---|
| q01-two-backends | ensure-schema, a five-row put, three keyset scan pages, a GSI scan — through one `Store`-typed function, against both backends | 5, identical either side | 1.24 s |

## What it showed

- **They agree** (C-038), first run. wat-rs already asserts this inside its own harness
  (`tests/rete/probe_arc278_sqlite_store_differential.{wat,rs}`); what this adds is that the
  agreement holds for an **ordinary program** — no `deftest`, no fixture loader, no co-located
  `.rs`. That is the consumer's position.
- **A dialed peer really is the surface.** `(:st::run-ops [store <- :wat::query::Store])` takes a
  connected `mem-store` peer and a connected `sqlite-store` peer, and one body serves both — "no
  wrapper struct, no `extend-type`", as the design says. This is **not** F-029: that finding is
  about a *generic* fn over a *parametric* surface refusing a concrete implementor. Here the
  surface is non-parametric, and it works.
- **But a consumer writes more outcome arms than logic** (F-069). **56 of this file's 182 lines
  are match arms.** Every call answers a `RecvOutcome`, so `Message`/`Lost`/`Stopped`/`Closed`
  must be said at each of four ops; every op then answers its own enum, `Success` plus five error
  variants of which four cannot happen here. And the dial itself cannot be factored out — wat-rs
  puts the rule plainly: "start+connect stay inlined in each deftest (spawn scope law: a helper
  that returns the peer leaves the service thread dead)", which is F-052 in their own words, and
  why their `connect` is a **529-character line**.

  Their fixture and this case are both exactly **182 lines**. Two authors, one shaping for a test
  harness and one for plainness, doing the same five operations, arriving at the same length.
  That is a property of the contract's shape, not of either author.

- **Where the backends are meant to differ, they are not compared.** `mem-store`'s
  `ensure-schema` is a deliberate no-op; `sqlite-store`'s is where `CREATE TABLE` happens.

## Running

```
wat store/q01-two-backends.wat   # both backends, compared line for line
./run.sh store                   # this suite
./run.sh                         # everything (16 minutes)
```
