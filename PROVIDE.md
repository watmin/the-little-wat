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
