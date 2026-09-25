# CRAWL — excursus 006: a macro says what it returns (candidate E)

The builder, 2026-09-25, weighing how excursus 004's one value-to-syntax renderer meets macros:
*"wat macros declare a ret val.. so a macro can declare it returns an int and it can be honest?"*
Four questions (in the conversation that drew this): today's mandate (`-> :wat::WatAST` for every
macro) is Honest NO -- `-> :wat::WatAST 42` is accepted; a boundary check keeping today's accepted
set (D) is Honest NO for the same reason; **E -- a macro declares what its body truly returns, the
checker holds the body to it as it does a `defn`, and the expansion is that value's syntax through
the one renderer -- passes all four.** This crawl sizes E before any brief.

## What exists (wat-rs `75fcc7638`)

- `src/macros/parse.rs` refuses any declared return but `:wat::WatAST`: *"a macro always expands
  to a form"*. `(defmacro :my::answer [] -> :wat::core::i64 42)` is refused at definition.
- `src/macros/expand.rs:1262-1285` evaluates every macro body and converts the value with
  `value_to_watast`; aggregates (record, enum, Vector, map) fail THERE, and arc 249's test
  `program_body_producing_non_ast_rejected` and `src/kernel/source.rs:97` lean on that failure as if
  it were the contract.
- **`--check` does not type-check a macro body at all (F-206).** `probes/macro-body-untyped.wat`
  passes with `(:wat::string::length 7)` in an arm; so does a macro nobody calls.

## The measurement

An instrumented HEAD build (one `eprintln!` at the conversion, `WAT_MACRO_CRAWL`, built in
`~/.cache/wat-macro-crawl`, never in the tree) ran `wat --check` over every `.wat` in both repos:
**2,616 programs, ~4.1 million expansions** (mostly the stdlib re-expanding in every program -- the
builder notes a pending wat-rs commit freezes stdlib expansion at build time).

| | count |
|---|---|
| distinct macros expanded | 934 |
| returning a `WatAST` value -- honest under `-> :wat::WatAST` | **933** |
| returning anything else | **1** -- `:t::deep-answer`, `wat-rs/tests/macros/probe_macros_unbounded_depth.wat:10`, `-> :wat::WatAST 42` |

A parse of every `defmacro` form (180 of 187 grep hits; the rest are in strings and comments): 87
quasiquote bodies, 2 quote, 84 program bodies, plus 7 declaring a HolonAST form (negative probes).
The 16 program-body macros no program expands were read by hand: each returns a form (quasiquote,
`keyword-node`, a `defn` declared `-> :wat::WatAST`, a parameter) or never returns (`macro-error`).

## What E costs, measured

1. **One declaration corrected** in the whole of both corpora: `:t::deep-answer` becomes
   `-> :wat::core::i64`.
2. **The real work is F-206**: type-checking a macro body against its declared return -- parameters
   `:wat::WatAST`, a rest parameter `(Vector :- [:wat::WatAST])`, the body held to the declaration
   like a `defn`'s. That check will be new, so its first run over the 187 macros may find latent
   type errors the expansion never reached; that count is unknown until it runs.
3. The parser's mandate drops; the boundary renders through the one renderer; arc 249's test and
   `kernel/source.rs:97` are rewritten to the stated contract.
4. Standard-library macros are checked once where their expansion is frozen (the builder's pending
   build-time freeze makes that wat-rs build time).

## Order

Excursus 004's widened renderer changes what macros accept, which is A (Honest NO) until E lands.
So **E before 004's renderer**: 004's stepping rows are credited and wait; nothing that failed a
question ships, even as an interim.
