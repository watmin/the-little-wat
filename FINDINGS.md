# Findings

Every place wat fell short of what a chapter needs, and every place it didn't.

## Classes

- **GAP**: wat cannot express something it arguably should. A candidate for wat-rs work.
- **REFUSAL**: wat deliberately excludes it (a stated doctrine). Record the doctrine and the
  canonical wat route; do not file it as a bug.
- **CLEAN**: the chapter ports directly.

## Entry format

Each entry names: the book and chapter; what the chapter needs; what wat did, with the
checker's or runtime's diagnostic quoted verbatim; the class; and the repro file under
`wat-tests/`. An entry without a repro that runs is a prediction, not a finding.

## Findings

### F-001: a debug build of any wat runtime panics during setup of its type registry

- **Where:** before any book, on the outside-consumer path. A minimal sibling crate
  (`wat::test! {}`) runs one trivial deftest under `cargo test`, which uses cargo's default
  debug profile.
- **What happened** (2026-09-14, wat-rs `a3218644d`), verbatim:
  ```
  thread 'wat-test:::friedman::smoke::one-plus-one' panicked at /home/watmin/Work/holon/wat-rs/src/types.rs:660:9:
  builtin leaf :wat::core::Option already registered as a structured TypeDef
  ```
- **Root cause** (read in wat-rs source this session):
  - `src/types.rs:1507` has registered `:wat::core::Option` structurally from `wat/core.wat`'s
    `defenum` since `1bdebac54` (2026-09-06, arc 296 H-3, "Option and Result live in wat").
  - `src/check.rs:1009–1011`: `BARE_CONTAINER_HEADS` still lists `Option` and `Result`.
  - `src/types.rs:2556` passes every `BARE_CONTAINER_HEADS` entry to `register_builtin_leaf`.
  - Its `debug_assert!` (`src/types.rs:660`) refuses a name already in `types`. `Result`
    would trip the same assert once `Option` is fixed.
  - Release builds compile `debug_assert!` out, and wat-rs's floor runs only `--release`, so
    the floor never sees it.
- **Class:** GAP. This is a wat-rs bug, not a language limit. Relay it to wat-rs; don't patch
  it from this repo.
- **Workaround here:** test in release (`cargo test --release`), as wat-rs's floor does. The
  same smoke deftest passes there: `deftest_friedman_smoke_one_plus_one ... ok`, 1 passed.
- **Repro:** `wat-tests/smoke.wat` under plain `cargo test`.

### F-002: a `.wat` file added to `wat-tests/` is never run, and the suite stays green

- **Where:** the outside-consumer path, `wat::test! {}`.
- **What happened:** two files were added to `wat-tests/` in an already-built crate.
  `cargo test --release` finished in 0.22s without recompiling. It ran only the old deftest
  and reported `1 passed`, all green. The new files were never discovered.
- **Root cause** (read in wat-rs source this session):
  - The macro lists `wat-tests/` once, when it expands (`crates/wat-macros/src/discover.rs:273`).
  - It marks each file it found with `include_bytes!` (`crates/wat-macros/src/lib.rs:969–995`).
    So cargo notices when an existing file's contents change.
  - Nothing tells cargo to watch the directory itself, so a new or removed file triggers
    nothing.
  - The comment there says "including adding/removing deftests", which holds only for
    deftests inside files that already exist.
  - Inside wat-rs this is hidden: any `src/` edit recompiles the test crates anyway.
- **Class:** GAP (a wat-rs bug). It produces a false green, the worst kind of failure.
- **Fixed here:** `build.rs` re-runs whenever `wat-tests/` changes and exports the file
  listing, which `tests/test.rs` reads with `env!`. Verified 2026-09-14 by adding
  `wat-tests/smoke-rebuild.wat` to a built crate with nothing else touched: cargo
  recompiled, and 3 tests ran where there had been 2.
- **Repro:** add any `.wat` deftest file with `build.rs` removed.

### F-003: a deftest spelled `wat.test/deftest` is silently skipped

- **Where:** deftest discovery, the syntax migration's blast radius.
- **What happened:** `wat-tests/smoke-clojure-deftest.wat` defines
  `(wat.test/deftest friedman.smoke/clojure-deftest …)`. Discovery found zero tests in it,
  with no error or warning, and the suite passed.
- **Root cause:** discovery accepts only a keyword head (`discover.rs:323`) matching one
  of the four `:wat::test::deftest*` strings (`:355–358`), with a keyword name (`:360`).
  A symbol head never matches.
- **Class:** GAP. ⚠ **Relay this to the codemod work:** a codemod that respells deftests
  to `wat.test/deftest` before discovery accepts symbol heads would silently drop every
  converted test. The suite would go quiet and stay green.
- **Here:** deftests stay in the keyword spelling until discovery accepts the new one.
- **Repro:** `wat-tests/smoke-clojure-deftest.wat` (adds zero tests; check the count).

### C-001: the Clojure/EDN `defn` spelling works

- `(wat.core/defn u/some-fn [x :- wat.type/i64 y :- wat.type/i64] :- wat.type/i64 (wat.core/+ x y))`
  type-checks and runs. `(u/some-fn 40 2)` equals 42 (`deftest_friedman_smoke_clojure_defn ... ok`).
- **Class:** CLEAN.
- **Repro:** `wat-tests/smoke-clojure-defn.wat`.

### C-002: a fully Clojure/EDN program runs under the `wat` binary and asserts loudly

- `(wat.core/defn user/main [] :- wat.type/nil …)` is found and run as the entry point.
- `wat.test/assert-eq` works in a program. On failure it exits **2**, with a structured
  `#wat.kernel/AssertionFailure` naming `:actual`, `:expected` and the file and line.
  The negative control, `probes/assert-fail.wat`, asserts 42 = 43 on purpose.
- This is why the chapters are programs run as `wat <file>` rather than deftests: no
  second build of wat, and F-001 to F-003 don't apply.
- **Class:** CLEAN.
- **Repro:** `probes/main-symbol.wat`, `probes/assert-pass.wat`, `probes/assert-fail.wat`.

### C-003: cons on quoted lists works as quasiquote plus splice

- `(wat.core/quasiquote (~x ~@l))`, with `x` = `'x` and `l` = `'(a b c)`, equals
  `'(x a b c)`.
- It also takes a list as the first element: `` `(~'(a) ~@'(b)) `` equals `'((a) b)`.
- **Class:** CLEAN.
- **Repro:** `probes/sexp-cons.wat`.

### F-005: the Clojure/EDN spelling has no name for types outside `wat::core`

- **Where:** type annotations in a `wat.core/defn`. Every S-expression function needs one,
  because the S-expression type is `:wat::WatAST`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `wat.type/WatAST` is refused: `annotation names unknown type :wat::core::WatAST`.
    `wat.type/X` always means `:wat::core::X`.
  - `wat/WatAST` is refused too. The resolver reads it as `:wat::WatAST` but
    classifies it as `namespaced symbol ref — not a builtin, not a registered function
    (arc 251)`.
  - The keyword `:wat::WatAST` works in the `:-` slot of a Clojure/EDN defn.
- **Verified spellings:** `wat.type/i64`, `wat.type/bool`, `wat.type/String` and
  `wat.type/nil` work. Only `WatAST` was tested among the non-core types; `HolonAST` and
  the `wat::kernel` types are expected to behave the same but are unverified.
- **Class:** GAP, in the syntax-migration surface. ⚠ Relay to the codemod work: there is no
  symbol spelling for a type outside `wat::core` yet.
- **Here:** type slots use the keyword `:wat::WatAST` for now.
- **Repro:** `probes/type-watast-core.wat`, `probes/type-watast-slash.wat` (both refused),
  `probes/type-watast-kw.wat` (works).

### F-006: an unknown-type error points into the checker's own Rust source

- **What happened:** the type error for `wat.type/WatAST` carries
  `:location #wat.core/Span {:file "src/check.rs" :line 15141 :col 13 :end #wat.core/Option.None {}}`.
  That is a line in wat-rs's checker, not the offending line of the user's `.wat` file.
  The user is told what is wrong but not where.
- **Class:** GAP (diagnostic quality). Other startup errors here point at the user's file
  correctly (e.g. F-004's, and F-005's `wat/WatAST` case).
- **Repro:** `probes/type-watast-core.wat`.

### C-004: Little Schemer ch 1 (Toys) ports cleanly

- `atom?`, `car`, `cdr`, `cons`, `null?` and `eq?` are defined over quoted S-expressions
  (`:wat::WatAST`), with 15 checks. Output: exit 0, `"little-schemer ch01 toys: ok"`.
- Everything is a thin wrapper over a wat primitive:
  - `atom?` is `ast-kind` ≠ `"list"`
  - `car` is `first`, `cdr` is `rest`
  - `cons` is quasiquote plus `~@`
  - `null?` is `empty?`, `eq?` is `=`
- The only friction was writing the empty list (F-004) and the type spelling (F-005).
- **Class:** CLEAN, with F-004 and F-005 as workarounds.
- **Repro:** `books/little-schemer/ch01-toys.wat`.

### F-004: an empty list inside `wat.core/quote` is refused as a retired unit literal

- **Where:** Little Schemer throughout. `'()` is the book's most common value.
- **What happened** (2026-09-14, wat-rs `a3218644d`), verbatim:
  > `bare unit value '()' is retired (arc 179); `nil` is the sole unit value. An empty list literal `()` in expression position is no longer a second spelling of unit.`
- **Scope** (verified):
  - `(wat.core/quote ())` is refused.
  - `(wat.core/quote (a () b))` is refused. So is `()` anywhere inside symbol-quoted data.
  - `(:wat::core::quote ())`, the keyword spelling, **works**: `ast-kind` is `"list"` and
    `empty?` is `true`. So only the Clojure spelling of quote is affected.
- **Root cause** (partly read):
  - `infer_quote` (`src/intrinsic/special/quote.rs:97–99`) states its argument "is DATA, not an
    expression — the type checker does not recurse into it."
  - The error is raised in one place only: `infer_list`, on an empty list
    (`src/check.rs:2613–2620`).
  - So with the symbol spelling, some checker path infers the quoted contents before (or
    instead of) reaching `infer_quote`. Which path: **unverified**.
- **Class:** GAP. Arc 179 retired `()` in *expression* position; quoted data is not an
  expression. ⚠ Relay to the codemod work: respelling `:wat::core::quote` as
  `wat.core/quote` turns every quoted empty list from working into a startup error. That
  failure is loud, unlike F-003.
- **Workarounds here:**
  - Build it as `(wat.core/rest (wat.core/quote (x)))`: ch 1's `ls/empty-list`. This one
    survives the respelling.
  - The keyword `(:wat::core::quote ())` works today, but breaks once respelled.
- **Repro:** `probes/quote-empty-symbol.wat` and `probes/quote-empty-nested.wat` (refused);
  `probes/quote-empty-keyword.wat` (works).

### C-005: the Y combinator works (Z, typed through a self-referential struct)

- **Where:** Little Schemer ch 9 derives Y; the applicative-order form is Z.
- **What happened** (2026-09-14): `probes/z-combinator.wat` exits 0 and prints `120`,
  factorial of 5 through Z. No function in it refers to itself by name.
- **How:** `(:wat::core::defstruct :u::Knot [unroll <- [:u::Knot :-> [i64 :-> i64]]])`
  is a struct whose only field is a function that takes the struct itself. This is the
  standard typed stand-in for self-application (Haskell: `newtype Mu a = In (Mu a -> a)`).
  wat accepts the self-referential type, function-typed fields, closures and higher-order
  calls.
- The textbook `(lambda (x) (x x))` cannot be written directly. A `fn` parameter must be
  annotated, and `x` would need an infinite type. That is true of every
  annotation-required typed language, so it is not a wat gap.
- This **overturns the prediction** made from ITERATION-PATTERNS.md: anonymous recursion
  works.
- **Class:** CLEAN.
- **Repro:** `probes/z-combinator.wat`.

### F-007: an unknown bare call name passes the checker and fails only at runtime (found via a self-calling let-bound fn)

- **Where:** Seasoned Schemer ch 12's `letrec` job: a local helper that recurses.
- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/letrec-let-bound-fn.wat`
  binds `fact` to a `fn` whose body calls `fact`. Startup (type check) **accepts** it. The
  run then dies, exit 1:
  ```
  #wat.runtime/UnboundSymbol {:message "unbound symbol: fact" :location … {:file "probes/letrec-let-bound-fn.wat" :line 10 :col 33 …} :name "fact"}
  ```
- **Why it matters:** local self-recursion being refused is doctrine
  (ITERATION-PATTERNS.md: "Anonymous local recursion — NOT SUPPORTED"). The problem is
  where it is refused. The checker lets through a program the runtime cannot run. An
  unresolved name should be a startup error; the checker and runtime disagree on it.
- **Scope: wider than letrec.** A call to a name that exists *nowhere* behaves the same
  way. Probed 2026-09-14:

  | where the unknown call sits | caught |
  |---|---|
  | bare `(zzz 5)` directly in `main` | only at runtime, exit 1 (`probes/unknown-bare-in-main.wat`) |
  | bare `(zzz n)` in a top-level `defn` body | only at runtime (`probes/unknown-bare-in-defn.wat`) |
  | bare `(zzz n)` in a let-bound `fn` body | only at runtime (`probes/let-fn-unknown-symbol.wat`) |
  | bare `(h n)`, `h` bound *later* in the same `let` | only at runtime (`probes/let-fn-later-binding.wat`) |
  | namespaced `(u/zzz n)` in a let-bound `fn` body | **at startup**: `namespaced symbol ref — not a builtin, not a registered function (arc 251)` (`probes/unknown-ns-in-fn.wat`) |

  So a **bare** (non-namespaced) call head is not resolved at startup anywhere, while a
  namespaced one is resolved everywhere. The `letrec` case is one instance. A typo in any
  bare call passes the check and fails only when that line runs. Mechanism (unverified):
  an unknown bare head likely gets a fresh type variable, not an error.
- **The fix is independent of `letfn`:** a bare call head must name something in scope (a
  `let` binding or a `fn` parameter), or startup fails, as namespaced references already do.
  Under the Clojure/EDN syntax bare names are *only* ever locals, so every unresolved bare
  head is a typo.
- **Class:** GAP (checker/runtime disagreement). Refusing local self-recursion is doctrine;
  refusing it (and every other unbound bare name) only at runtime is the gap.
- **Repro:** `probes/letrec-let-bound-fn.wat`, plus the four scope probes above.

### R-001: a named fn, `(fn fact [n] …)`, is refused

- **What happened:** refused at startup, located:
  `malformed :wat::core::fn form: fn signature: expected a vector [name <- :T ...] as the args-vector; got symbol`
  (`probes/letrec-named-fn.wat`, line 6).
- **Doctrine:** ITERATION-PATTERNS.md, "Anonymous local recursion — NOT SUPPORTED …
  If your function deserves to recurse, it deserves a name." There is no `letrec` or `letfn`
  either (none appears in the checker or stdlib).
- **Canonical route:** a top-level `defn`, taking as parameters whatever the local helper
  would have closed over. Or Z (C-005), now proven.
- **Class:** REFUSAL.
- **Repro:** `probes/letrec-named-fn.wat`.

## Predicted, unverified

Read from wat-rs's docs on 2026-09-14. Several of those docs have fallen behind the code, so
each of these stays unverified until a repro runs against the current substrate.

| Book / chapter | Needs | wat-rs doc says | Expected class |
|---|---|---|---|
| ~~Little Schemer ch 9~~ | Y combinator (anonymous recursion via self-application) | no anonymous local recursion (ITERATION-PATTERNS.md) | **overturned: Z works through a self-referential struct, see C-005** |
| ~~Seasoned Schemer ch 12~~ | `letrec` | "NOT IN WAT" (ITERATION-PATTERNS.md) | **verified: named fn refused (R-001); let-bound self-reference fails only at runtime (F-007)** |
| Seasoned Schemer ch 13–14 | `letcc` / call/cc | not mentioned anywhere in the docs | GAP or REFUSAL |
| Seasoned Schemer ch 15–17 | `set!`, closures carrying state | "mutation-free by construction" (CLOJURE-ROSETTA.md) | REFUSAL |
| ~~Little Schemer throughout~~ | lists mixing atoms and lists | collections are monomorphic; `:Any` is banned | **resolved: quoted forms (`:wat::WatAST`) are the route, see C-004** |
