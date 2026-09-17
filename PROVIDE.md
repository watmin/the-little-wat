# What users shouldn't have to write

A running list, started 2026-09-14, of things these ports had to build themselves that wat
should arguably provide. Some belong in the stdlib, some in the checker, and some in
optional libraries. FINDINGS.md records what went wrong. This file asks something
narrower: **what would a user reasonably expect to find ready-made?**

Each entry names what we wrote (file and size), why a user shouldn't have to, a suggested
shape, and the evidence. Where an entry says wat lacks something, that was checked against
wat-rs at `a3218644d`, never predicted from its docs. Suggested shapes are proposals only;
the names and the design are the builder's call.

**Status legend:** open · decided (with the decision) · done (with the wat-rs commit).

## Index

| # | What | Where it would live | Status |
|---|---|---|---|
| P-001 | Fair interleaving of lazy streams | stdlib, `:wat::stream` | open |
| P-002 | A generic mutable cell service, `Cell :- [T]` | stdlib service | open |
| P-003 | `when`, `if-let` | core forms | open |
| P-004 | `letfn` (local, possibly recursive, fns) | core form | open (builder's call, R-001) |
| P-005 | `cons` on quoted lists | core | open |
| P-006 | Variant constructors that widen to their enum | checker (F-019, F-020) | open |
| P-007 | A fast default accumulator | runtime or stdlib (F-023) | open |
| P-008 | Helper functions a macro may call while expanding | macro system (R-004, F-021) | open |
| P-009 | Evaluation that a signal can stop | runtime (R-005) | open |
| P-010 | A relational (miniKanren) library | optional library | open |
| P-011 | A mutable graph/arena store | optional library, if at all | open |
| P-012 | Tuple patterns in `match` arms, exhaustive over the product | checker (F-027) | open |
| P-013 | Generic functions over a surface, for any type that implements it (functors) | checker (F-029) | open |
| P-014 | A WatAST whose children are shared, not copied | runtime (F-033) | open |
| P-015 | Bit operations on integers | core (F-035) | open |
| P-016 | A seeded, pure random number generator | stdlib (F-036) | open |
| P-017 | Clojure core's small functions (`inc`, `comp`, `partial`, `merge`, `group-by`, set operations …) | stdlib (C-030) | open |
| P-018 | A set that shares structure, to go with `PersistentMap` and `PersistentVector` | stdlib (F-057) | open |
| P-019 | An ordered collection: a sorted map or set, a priority queue, a heap | stdlib (F-056) | open |
| P-020 | An improper list — or a reader that refuses at the dot instead of admitting a symbol named `.` | core/reader (F-059) | open |
| P-021 | A regex that reports what it matched: `find`, `captures`, `replace`, split-on-pattern | stdlib, `:wat::regex` (F-061) | open |
| P-022 | A String's characters, and the operations built on them (`index-of`, `replace`, `split-lines`, `blank?`, `reverse`) | stdlib, `:wat::string` (F-062) | open |
| P-023 | A catch that doesn't spawn a thread, outside `:wat::test::` | core or stdlib (F-063) | open |
| P-024 | A way to say "every other outcome is a failure" once, when calling a service | core or stdlib (F-069) | open |

## Stdlib

### P-001: fair interleaving of lazy streams

- **What we wrote:** `rs/mplus` and `rs/bind` (`books/reasoned-schemer/lib/ch10-under-the-hood.wat:124–142`),
  plus an encoding for suspension: a stream of `Option`, where `None` means "yield here".
  With it, a branch that never answers cannot starve its siblings.
- **What wat has:** the stream primitives (`:wat::stream::cons`, `empty`, `lazy`, `next`),
  plus lazy `map`, `filter`, `take`, `take-while`, `drop-while`, `keep`, `remove` and
  `map-indexed`. There is no `interleave`, `mapcat`, `lazy-cat`, `iterate` or `repeat`
  (0 hits in `src/check.rs` or `wat/`).
- **Why users shouldn't write it:** every search-shaped program needs it: logic
  programming, backtracking parsers, generators, test-case enumeration. Fairness is subtle,
  and the answer order depends on exactly how it is done (`oracle/` exists to check that).
  A user who writes `mapcat` naively gets a depth-first search that hangs on the first
  infinite branch.
- **Suggested shape:** `(:wat::stream::interleave s1 s2)` and a fair
  `(:wat::stream::mapcat f s)` that alternates at suspensions, plus a way for a producer to
  yield without producing a value (`:wat::stream::suspend`), so the `Option` encoding
  isn't needed.
- **Evidence:** C-019, C-020. The engine's search is linear once it uses the stdlib's
  `filter`/`map`/`take`/`into` (F-023).

### P-002: a generic mutable cell service

- **What we wrote:** `books/seasoned-schemer/lib/cell.wat` (60 lines of code, one
  `:wat::WatAST`) and `counter.wat` (82 lines, one `i64`). Each is a defsurface, a
  defservice, a Handle-keeping struct, and outcome matching on every call, written out
  again for each payload type.
- **What wat has:** the stdlib's services are `lru-svc :- [K V]`, `hologram-svc`,
  stdin/stdout/stderr, two query stores and two telemetry services. There is no cell,
  atom, `swap!` or `reset!`. `lru-svc` shows that a generic defservice is possible.
- **Why users shouldn't write it:** "mutable state lives on services" is the doctrine, so
  the smallest piece of state is something every program meets. Clojure's `atom` is one
  word. Here it is 60–80 lines per type, and dropping the Handle silently closes the
  service.
- **Suggested shape:** `(:wat::cell::new v)`, `get`, `put!`, and `swap!` with a pure
  function, generic in `T`. `T` must be pure (the containment rule, R-002), so a cell
  cannot hold a function.
- **Evidence:** C-014; the friction entries "one mutable variable costs about 60 lines"
  and "every shape of state needs its own service".

### P-003: `when` and `if-let`

- **What we wrote:** `(if c (do …) nil)` and a `match` on an Option instead.
- **What wat has:** neither; both are `unresolved reference` (`probes/annoy/when.wat`,
  `probes/annoy/if-let.wat`).
- **Why users shouldn't write them:** they are two of the most common Clojure forms, and
  wat's Option-returning lookups (`(:a m)` returns an Option, `get` too) make `if-let` even
  more useful than in Clojure.
- **Suggested shape:** `when` over `if`; `if-let` / `when-let` that match `Option.Some`
  and bind its value.
- **Evidence:** the friction entry "Clojure core forms that do not exist".

### P-004: `letfn`

- **What we wrote:** Y with closures, and a helper's full type written out twice
  (`books/seasoned-schemer/lib/ch12-take-cover.wat`), or top-level defns.
- **What wat has:** a named `fn` is refused (R-001). A let-bound fn cannot call itself;
  that is caught only at runtime (F-007).
- **Why users shouldn't write it:** local recursion is ordinary. Without it every
  recursive helper goes top-level or pays for the Y combinator.
- **Suggested shape:** Clojure's `letfn`, with the local fns' types checked.
- **Evidence:** R-001, C-012, and the friction entry "without letrec or letfn". The
  builder has said this is optional.

### P-005: `cons` on quoted lists

- **What we wrote:** `ls/cons` as `(quasiquote (~a ~@l))`
  (`books/little-schemer/lib/ch01-toys.wat`).
- **What wat has:** `first`, `rest` and `empty?` work on quoted lists. `conj` appends to a
  Vector, and `:wat::linkedlist::conj` prepends to a List, but neither builds a
  `:wat::WatAST` list.
- **Why users shouldn't write it:** code that builds code (macros, interpreters, codemods)
  conses constantly, and the quasiquote spelling hides a copy of the whole list.
- **Suggested shape:** `(:wat::core::cons x ast-list)`.
- **Evidence:** C-003.

### P-017: Clojure core's small functions

- **What we wrote:** in the books, each by hand at its point of use: `(+ n 1)` for `inc`, a
  `fn` for every `comp` or `partial`, a fold for `merge`. In the Clojure Koans, nothing: their
  literal port stops at these names (C-030).
- **What wat has:** none of the following, under any name that the koans' refusals or the
  stdlib's registry show:
  - `inc`, `dec`, `even?`, `odd?`, `zero?`;
  - `comp`, `partial`, `complement`, `juxt`, `identity`;
  - `list`, `merge`, `merge-with`, `get-in`, `update-in`;
  - `group-by`, `partition`;
  - set union, intersection and difference (which first need a HashSet to be enumerable,
    F-046);
  - `blank?`, `index-of`, `last-index-of`, `split-lines`, a String's `reverse`, and its
    characters.

  `vals` is `:wat::hashmap::values`, and `pr-str` is `:wat::edn::write`.
- **Why users shouldn't write it:** each is a line, but every program needs a dozen, and
  each one written by hand is a place to get a type or an edge case wrong. They are also
  the words a Clojure reader expects the Clojure spelling to have. In the koans, `inc` alone
  blocks 13 rows and `dec` 11.
- **Suggested shape:** Clojure's names and argument order, typed. For example, `comp` generic
  over its functions' types; `(group-by f coll)` answering a `HashMap` of `Vector`s; the set
  operations on `HashSet`.
- **Evidence:** the Clojure Koans table in FINDINGS.md; `koans/literal/*.tsv`.

### P-018: a set that shares structure

- **What we wrote:** `(:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool])`, used as
  a set by ignoring the value — the settled squares in `aoc/day05-paths.wat`, and the same shape
  would be wanted for any visited set, seen-set or dedup pass.
- **Why:** `HashSet` copies on every `conj`, so accumulating into one is quadratic;
  `PersistentMap` and `PersistentVector` share structure and stay linear, but there is no
  persistent **set** to go with them (F-057). Moving day05's frontier to the sharing containers
  took it from 135.1 s to 20.6 s, and the settled set had to be faked as a map to `true` to get
  there.
- **Shape:** whatever `PersistentMap` is, with the value side removed — `conj`, `contains?`,
  `disj`, `length`, `empty?`, and something to enumerate it (F-046 says a `HashSet` cannot be
  enumerated today either).
- **Evidence:** F-057, F-046, `probes/aoc/persistent-insert-scaling.wat`,
  `probes/aoc/map-insert-scaling.wat`.

### P-019: an ordered collection

- **What we wrote:** a bucket per cost — Dial's algorithm — in `aoc/day05-paths.wat`, which
  works only because every step in that puzzle costs between 1 and 9. A general Dijkstra cannot
  be written that way.
- **Why:** wat has no sorted set, sorted map, priority queue or heap; only `sort` and `sort-by`
  over a whole collection (F-056). A priority queue is the data structure of shortest paths,
  schedulers, event simulation, top-k and merge — and sorting the whole frontier on every pop is
  not a substitute.
- **Shape:** at minimum a heap with `push`, `pop-min` and `peek`. A sorted map would also answer
  the "next key after k" questions that `sort` cannot.
- **Evidence:** F-056, `probes/aoc/sorted-structures.wat`, `aoc/day05-paths.wat`.

### P-020: an improper list, or a reader that says no at the dot

- **What we wrote:** nothing — this one cannot be written. PAIP chapter 12's membership clauses
  need a list with a variable tail, `(?i . ?rest)`, and they are absent from `paip/` for that
  reason. The Reasoned Schemer met the same wall and answered it by leaving quoted data
  entirely: `:rs::Term` is an enum with its own `Pair` variant, which exists precisely because
  "quoted lists can't hold a pair with a variable tail".
- **Why:** wat reads `(?i . ?rest)` as a three-element list whose middle element is a symbol
  named `.`, then prints it back as `(?i . ?rest)` — so an improper list round-trips unchanged
  while meaning something else (F-059). Anything that reads Lisp source with dotted pairs in it
  — clause heads, association lists, improper argument lists, `cons` cells generally — gets a
  form that looks right and isn't.
- **Shape:** either a real pair in the reader and in `ast->children`, or a refusal at the dot.
  Either is honest. Silently admitting a symbol named `.` into a list is the thing to stop.
- **Note:** P-010's open design point is this same gap, seen from the relational side.
- **Evidence:** F-059, `probes/paip/dotted-pattern.wat`,
  `books/reasoned-schemer/lib/ch10-under-the-hood.wat`.

### P-021: a regex that reports what it matched

- **What we wrote:** nothing — there is nothing to write it with. `:wat::regex::matches?` answers
  a bool, and that is the entire namespace.
- **Why:** every text program needs the matched text, a capture group, a position, a
  replacement, or a split on a pattern. wat can ask only whether a pattern matches somewhere. A
  group like `(foo|bar)baz` compiles and matches, and what it captured is unreachable (F-061).
- **Shape:** `find`, `captures`, `replace`, and a split on a pattern. wat-rs already depends on
  the whole `regex` crate (`Cargo.toml:111`) and already compiles it in, so this is exposure
  rather than implementation.
- **Evidence:** F-061, `probes/euler/regex-surface.wat`, `probes/euler/regex-find.wat`,
  `probes/euler/regex-replace.wat`.

### P-022: a String's characters, and the operations built on them

- **What we wrote:** `:mal::char-at` in `mal/lib/reader.wat` — a one-character `subs` — and then
  the same thing again in `aoc/day02-smoke.wat`, and again in `euler/p16-p20-p25-digits.wat`.
  wat-rs's own `format` macro writes it a fourth time, at expand time
  (`src/intrinsic/string.rs:550`).
- **Why:** a String has no characters in wat. There is no `chars`, no `:wat::char::` namespace,
  no `index-of`, `last-index-of`, `replace`, `split-lines` or `blank?`; `reverse` refuses a
  String and `split` refuses an empty separator, so a String cannot even be taken apart the long
  way round. And the substitute is expensive: about 16.7 µs a character, eight times a plain
  function call — 80000 of them cost 1.66 s (F-062).
- **Shape:** characters first, since everything else is built on them; then `index-of`,
  `replace`, `split-lines`, `blank?`, and `reverse` on a String. `split` should accept `""`.
- **Note:** the cost is not the char-indexing — 80000 `subs` calls at index 0 cost 1.34 s of the
  1.66 s. It is the per-call overhead, so a cheaper single-character read is the improvement
  that matters.
- **Evidence:** F-062, `probes/euler/char-at-cost.wat`, `probes/euler/char-at-scaling.wat`,
  `probes/euler/char-at-exponent.wat`, `probes/euler/string-split-empty.wat`.

### P-023: a catch that doesn't spawn a thread

- **What we wrote:** `:wat::test::run-thread`, in `books/little-typer/lib/pie.wat` (all 108 of
  Pie's refusals), in `probes/java/builtin-verb-as-value.wat`, and in
  `probes/learner/f64-in-failure-record.wat`. Every one of them reaches into the **test**
  namespace to do ordinary error handling, because there is nowhere else to reach.
- **Why:** `Result/try` is the `?` operator — it propagates an `Err` out of the enclosing
  function and is refused unless that function returns a `Result` — so it never recovers from a
  fault. `run-thread` is a macro that expands to `spawn-thread-program`: catching means spawning
  a thread and facing its death through a `recv`. That costs about **1.26 ms even when nothing
  fails**, against 8 µs for a plain call (F-063).
- **Shape:** a form that runs a body and answers `Ok`/`Err` without a thread — whatever wat's
  doctrine wants to call it. The pieces already exist: `Failure` is a record with a captured
  stack, and `RunResult` is already the shape of the answer.
- **Note:** the Little Typer's friction belongs here too — a death handled as data still prints
  its whole record to stderr, 806 KB for 2000 handled failures, with no flag to stop it.
- **Evidence:** F-063, F-064, `probes/err/catch-cost.wat`,
  `probes/err/try-catches-assertion.wat`, `probes/err/error-in-stream.wat`.

### P-024: one way to say "every other outcome is a failure"

- **What we wrote:** 56 match arms in 182 lines, to do five operations against a service
  (`store/q01-two-backends.wat`). wat-rs's own consumer fixture writes the same five operations
  in the same 182 lines, with a **529-character** `connect` line
  (`wat-rs/tests/rete/probe_arc278_smem_roundtrip.wat`).
- **Why:** three things compound, and none of them is wrong on its own.
  - Every call to a service answers a `RecvOutcome`, so `Message` / `Lost` / `Stopped` /
    `Closed` must be spelled at every call site, whatever the call meant.
  - Every operation then answers its own outcome enum — `Success` plus `Constraint` /
    `Transient` / `Fatal` / `RequestTooLarge` / `RequestMalformed` — of which four usually
    cannot happen at that site.
  - The dial itself cannot be factored into a helper: "a helper that returns the peer leaves the
    service thread dead" (wat-rs's own words for F-052), so `start` + `connect` is written
    inline, in full, at every use.
- **Shape:** not fewer arms — the exhaustiveness is right and is why wat catches what it catches.
  What is missing is a way to handle the uninteresting ones as a group: an `expect`-style helper
  over `RecvOutcome`, or letting an outcome enum's error variants be matched collectively with
  the failure message derived from the variant. Anything that lets a consumer write the
  interesting arm and one fallback.
- **Note:** this is the cost of the service model at its best — a well-designed contract, four
  operations, two backends. It is not a criticism of `:wat::query::Store`; every consumer of
  every service pays it.
- **Evidence:** F-069, C-038, `store/q01-two-backends.wat`, and the line counts in F-069's table.

## Checker and runtime

These are fixes, not additions, but each is something users currently write themselves.

### P-006: variant constructors that widen to their enum

- **What we wrote:** `rs/some`, a generic defn whose declared return does the widening,
  and `rs/nil`.
- **Why:** `(Option.Some {…})` keeps its narrowed type inside a vector or stream literal
  (F-019). The bare unit variant is typed as a nullary fn (F-020), and
  `(:wat::core::Some x)` is retired (`probes/some-fn-widens.wat`). So every program that
  puts a variant in a collection writes a helper.
- **Suggested shape:** widen a variant to its enum where it becomes a type argument (F-019),
  and let a bare unit variant be a value, as `:wat::core::Option.None` already is (F-020).

### P-007: a fast default accumulator

- **What we wrote:** answer lists built with `filter`/`map`/`take`/`into []` instead of
  `conj` in a loop.
- **Why:** `conj` onto a `Vector` clones it (F-023), so Clojure's `[]` + `conj` habit is
  quadratic. `PersistentVector` is the linear route, but users have to know about it.
- **Suggested shape:** don't copy when the Vec is not shared (`Arc::make_mut`), or make
  the literal `[]` persistent.

### P-008: helper functions a macro may call while expanding

- **What we wrote:** `:rs::defrel-params`, a second macro that recurses by expanding to
  itself, because `defrel` may not call a helper defn (R-004). Its parameter list is also
  carried as a marker list, because a program body cannot splice a vector form (F-021).
- **Why:** walking a list at expansion time is what macros do. Macros that do it with
  helpers are much easier to write and to read.
- **Suggested shape:** a defn that declares itself expand-time-legal (checked pure and
  total, the same F5 rule), and F-021 fixed.

### P-009: evaluation that a signal can stop

- **What we wrote:** nothing inside wat. Every timed run uses `timeout -s KILL`.
- **Why:** SIGTERM only sets a flag that programs must poll (R-005). A search, a runaway
  loop or a test that hangs cannot be stopped by Ctrl-C or SIGTERM.
- **Suggested shape:** the evaluator checks the flag at a cheap point (a call, or a loop
  back-edge) and unwinds. The doctrine "stopping is a protocol" would still hold for
  services; this covers pure computation, which has no protocol to speak.

### P-012: tuple patterns in `match` arms, exhaustive over the product

- **What we wrote:** a keyword `let` destructure and then one nested match per position.
  The Little MLer's `eq_main` becomes 16 leaf arms
  (`books/little-mler/lib/ch04-look-to-the-stars.wat`).
- **Why:** a tuple pattern at the top of an arm is refused, and a match on a tuple can be
  exhaustive only through `_` or a binder (F-027). Under the no-`_` doctrine that rules out
  tuple matching entirely. Every function over a pair of datatypes pays for it.
- **Suggested shape:** `[(p1 p2 …) body]` arms, each position a sub-pattern as they already
  are inside variant fields (`check.rs:7826`), with exhaustiveness checked over the product
  of each position's variants. The same product check would let nested arms count as
  coverage (F-028), which today they never do, even when complete. Together that is what
  would let F-025's doctrine be enforced without forcing a catch-all one level down.

### P-013: generic functions over a surface, for any type that implements it

- **What we wrote:** a dictionary for each structure, a generic struct of closures that call
  the structure's surface features (`:ml::int-ops`, `:ml::num-ops`, `:ml::sealed-ops` in
  `books/little-mler/lib/ch10-building-on-blocks.wat`). The functor is a generic fn over
  dictionaries instead of over the surface.
- **Why:** a generic fn over `(:ml::N :- [T])` refuses a non-generic type that implements
  `N` at a concrete argument (F-029). That is the shape of every "any implementation of this
  interface" function, ML's functors and Rust's `fn f<T: Trait>` alike. Writing a dictionary
  per implementation is the boilerplate surfaces exist to remove.
- **Suggested shape:** Stone 118.3-B's bind-then-unify for the plain-path arm of the
  surface-bound check too, so `NumberAsInt` binds `T` to `i64` there.

### P-014: a WatAST whose children are shared, not copied

- **What we wrote:** workarounds for F-033 in wat-Pie
  (`books/little-typer/lib/pie.wat`). A definition is bound as its core syntax and
  evaluated at each use, so closure environments don't nest every earlier definition's
  environment. We didn't rewrite the values onto native enums, which do share.
- **Why:** code-as-data is what a Lisp is for. Codemods (wat-fix), interpreters (the Little
  Schemer's ch 10, the Seasoned Schemer's ch 20), the J-Bob port and wat-Pie all walk and
  rebuild WatASTs. Each `ast->children` copies every subtree below the node, so a walk
  that should cost O(n) costs up to O(n²), and data that nests (environments in closures)
  costs exponentially.
- **Suggested shape:** children behind an `Arc` (`List(Arc<[WatAST]>)` or an `Arc` per
  child), so taking a node apart and rebuilding it share structure the way the runtime's
  `Vec(Arc<Vec<Value>>)` and `Enum(Arc<EnumValue>)` already do. Or an `ast-nth` accessor
  that clones one child, not all of them.
- **Evidence:** F-033; `probes/typer/ast-children-cost.wat`, `probes/typer/value-copy-cost.wat`.

### P-015: bit operations on integers

- **What we would have to write:** nothing we can write. Without and, or, xor or shifts,
  the operations can only be emulated with division and remainder, one bit at a time.
- **Why:** hashes, checksums, generators, flags and wire formats all need them, and the
  networking work ahead needs them first.
- **Suggested shape:** `:wat::i64::bit-and`, `bit-or`, `bit-xor`, `bit-not`, `shift-left`,
  `shift-right` (arithmetic and logical), plus `wrapping-+`, `wrapping-*` beside today's
  checked arithmetic.
- **Evidence:** F-035.

### P-016: a seeded, pure random number generator

- **What we will write:** a Park–Miller generator for the Little Learner, since F-035
  rules out the better ones.
- **Why:** sampling, initialization, shuffling and property-based tests all need one. A pure
  generator (state in, value and next state out) fits wat's immutable style and keeps runs
  reproducible.
- **Suggested shape:** splitmix64 or PCG in the stdlib, with a uniform f64 in [0, 1), an
  integer below n, and a normal; and a seed taken from the world beside `:wat::time::now`.
- **Evidence:** F-036.

## Optional libraries

### P-010: a relational (miniKanren) library

- **What we wrote:** the engine, `books/reasoned-schemer/lib/ch10-under-the-hood.wat`:
  271 lines of code. It covers terms, walk and unify with an occurs check, interleaving
  streams, reification, and the book's `run`, `fresh`, `conde`, `defrel`, `conda` and
  `condu` as macros.
- **Why not stdlib:** logic programming is a library in Clojure (core.logic) and in
  Scheme. `conda`/`condu` are impure ("thin ice" in the book's words). But wat already
  ships a Rete, which reacts forward to facts. A relational engine does the other half:
  it solves, and runs backwards. If that is a use case, users shouldn't rebuild it.
- **Open design point:** a term type. `:wat::WatAST` cannot hold a logic variable or a
  pair with a variable tail `(a . d)`, which is why the engine has its own `:rs::Term`.
- **Depends on:** P-001, and the checker fixes behind P-006 and P-008. Most of the work in
  writing the engine went into those, not into the relations.
- **Evidence:** C-019, C-020.

### P-011: a mutable graph or arena store

- **What we wrote:** `books/seasoned-schemer/lib/arena.wat` (148 lines of code). It is a
  node table on one service, with integer ids as pointers, for shared and cyclic lists and
  an interpreter's store.
- **Why it might not belong anywhere:** it was needed only for the book's `set-kdr!`
  chapter and ch 20's store. Listed so the need is on record; it is the weakest entry here.
- **Evidence:** C-016, C-018.

### P-025: `:wat::stream::collect`, and the rest of a stream vocabulary

- **What we wrote:** `probes/stream/drain.wat` — a six-line recursive drain over
  `:wat::stream::next` that turns a `Stream` into a `PersistentVector`.
- **Why it belongs in the stdlib:** it is already documented as being there.
  `USER-GUIDE.md:3709` tabulates `:wat::stream::collect` with its signature, alongside
  `map`, `filter`, `inspect`, `take` and `fold`. None of the nine stream verbs the
  user-facing documents name exists (F-088); the four that do — `cons`, `empty`, `lazy`,
  `next` — are named in those documents zero times.
- **And something needs it.** `:wat::core::filterv` has no `PersistentVector` clause
  (F-080), so the fallback is `:wat::core::filter`, which answers a `Stream`. Without a
  collect there is no supported way back to a vector, and `(length <Stream>)` type-checks
  and then dies at runtime (F-031). A user who takes wat's own advice about persistent
  containers (F-057) reaches this corner by the shortest path available.
- **Evidence:** F-088, F-080, F-031.

### P-026: a priority queue

- **What we wrote:** `okasaki/lib/heap.wat` — Okasaki's leftist heap, 60 lines: `merge` is
  O(log n), and `insert` and `delete-min` are both `merge` in disguise.
- **Why it belongs in the stdlib:** F-056 records that wat has no priority queue and **no ordered
  collection of any kind**. Dijkstra, A*, event simulation, Huffman coding and k-way merge all
  need one; `aoc/day05-paths.wat` had to hand-roll bucket queues to avoid it.
- **Verified, not assumed:** the leftist property and heap order are checked at every node after
  2000 inserts, the drain is sorted and loses nothing, and insert cost rises 1.19× across three
  doublings where O(n) would predict 8× (C-052).
- **But ship it native, not in wat.** F-097 measured a hand-written persistent set at 34–43× the
  native `PersistentMap` it would replace, because an interpreted node visit costs ~2 µs whatever
  the algorithm. The same applies here: this heap is the right *specification*, and a wat-level
  implementation is not the right *delivery*.
- **And mind F-098 if it is written in wat:** carry the payload in an enum variant, not a record.
- **Evidence:** C-052, F-056, F-097, F-098.

### P-027: a one-shot suspension cell (`Susp<T>` — `delay` / `force`)

- **What we wrote:** twelve lines of wat that memoize correctly — three forces, one evaluation,
  generic over `T` (verified at `i64` and `String`). The mutable cell underneath is
  `:wat::cache::Lru` at capacity 1, keyed 0.
- **It proves no deep substrate change is needed.** wat already exposes a mutable, thread-owned
  cell reachable from ordinary code, so a suspension is expressible *today* — the language is not
  missing a capability, only a name for one.
- **But the LRU is the wrong vehicle, on four counts:**
  1. **Semantics.** An LRU is a *bounded, evicting* cache; a suspension is a *one-shot,
     never-evicting* cell. At capacity 1 the eviction can never fire, so the recency list, the
     capacity bound and the eviction path are all dead weight carried on every access.
  2. **Cost.** A cached `force` measures **7251 ns** against **3583 ns** for a plain function call
     — **2× a call** for what should be a pointer read. Okasaki's amortization is exactly the
     thing that budget has to fit inside.
  3. **Failure modes that do not belong to a suspension.** Capacity 0 panics (F-084), the key `0`
     is arbitrary, and nothing at the type level says the cell holds exactly one thing.
  4. **Thread-owned.** `:wat::cache::Lru` is `scope = "thread_owned"`, so a suspension built this
     way cannot cross a thread boundary — a restriction a suspension has no reason to inherit.
- **What the real thing is:** one word of state, `delay` and `force`, no eviction policy, no key.
  Small enough to be a substrate type rather than a library.
- **And it does not touch `Stream`.** F-100 records that streams not memoizing is deliberate — the
  Ruby `Enumerator` pattern, which makes a retained head unleakable. This is the *other* need
  (force once **ever**, shared between accessors) and it wants its own type.
- **The type system did catch the impurity**, which is a point in wat's favour: the containment
  rule refused the `defrecord` — *"pure aggregate"* cannot hold a live handle — and forced a
  `defstruct`, exactly as `:wat::cache::HolographicLru` is one.
- **Evidence:** F-100, F-084, C-052.

#### P-027, continued: the skeleton is the spec

`okasaki/lib/susp.wat` + `llist.wat` now exercise the primitive hard enough to say exactly what it
must do. Chapters 6 and 7 are built on it and both hold their bounds (C-055, C-056).

**The surface, as used:**

| | |
|---|---|
| `delay : [:-> T] -> Susp<T>` | deferred, not yet run |
| `force : Susp<T> -> T` | run **at most once**, and **shared between accessors** — this is the whole point |
| `forced? : Susp<T> -> bool` | observable, so a test can prove incrementality rather than assume it |

**And one requirement that is not about the suspension at all:** it must be holdable in an
aggregate that *also* shares its payload. Today that is an **Impure enum** and nothing else — a
`defrecord`/`defstruct` deep-copies user-enum fields (F-098) and a Pure enum cannot hold a live
handle (the containment rule). All three of `BQ`, `LCell` and `RTQ` are Impure enums for that
reason, and neither constraint is documented.

**Why the LRU must not ship as the implementation:** chapter 7's lazy list allocates **one
`:wat::cache::Lru` per cons cell** — a 300-element front is 300 bounded evicting caches whose
eviction can never fire. At chapter 6 the stand-in was a 2× constant-factor tax; by chapter 7 it
*is* the measurement.

### P-028: a memo cell — an unbounded, non-evicting keyed table

**What a user should not have to write.** PAIP chapter 9's `memoize` (C-084) takes any function
and returns one with the same signature that remembers what it has computed. In wat that **is**
writable — a closure can capture a `:wat::cache::Lru`, verified in
`probes/paip/transparent-memoize.wat` — but the thing it captures is the wrong primitive, and in a
way that is a **contract difference rather than a tuning parameter**:

> **an LRU is allowed to forget.** At capacity 2 the probe shows the wrapper recomputing a value it
> had already produced.

For `fib` that is a performance difference. For anything memoized for **identity** — hash-consing,
interning, a canonical-form table — it is *wrong*, because the invariant being bought is "the same
input yields the very same result, always", and an evicting cache cannot promise that.

**The surface:**

| | |
|---|---|
| `memo : () -> Memo<K,V>` | a table that never evicts |
| `memo-get : Memo<K,V> -> K -> Option<V>` | |
| `memo-put! : Memo<K,V> -> K -> V -> ()` | |
| `memoize : [K :-> V] -> [K :-> V]` | the transparent wrapper, built from the above |

**Relationship to P-027.** P-027 asks for a one-shot suspension: force once *ever*, no key. This is
its keyed relative: compute once *per key*, ever. They are the same requirement — *a cell that
remembers and is not allowed to forget* — at two arities, and `:wat::cache::Lru` is the wrong
vehicle for both for the same reason.

**What the stand-in costs today**, beyond eviction: a cached read measures ~7251 ns against
~3583 ns for a plain call, so the cell is about **2× a function call** and the saving must clear
that bar before memoizing pays; `Lru` is `thread_owned`, so a memoized function cannot cross a
thread boundary; and capacity 0 panics (F-084), so every wrapper must reject or clamp it.

- **Evidence:** C-084, `probes/paip/transparent-memoize.wat`, P-027, F-084.
