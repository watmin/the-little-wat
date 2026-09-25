# SCORE — excursus 006 stone 1: a macro says what it returns

Nothing is committed on `the-little-wat`. The binary is `CARGO_TARGET_DIR=/home/watmin/.cache/wat-macro-006`. Every `wat` run was `timeout -s KILL`.

## Row 0 — 004 is parked

`origin/the-little-wat-004-eval-step` is `f9ae53550`, message `WIP excursus 004 stone 1 re-strike -- parked for 006`. `the-little-wat` was clean at `75fcc7638` before this strike. The diff on `the-little-wat` is `src/check.rs`, `src/distribution/mod.rs`, `src/freeze.rs`, `src/kernel/source.rs`, `src/macros/expand.rs`, `src/macros/parse.rs`, `src/macros/registry.rs`, `src/macros/tests.rs`, `src/runtime.rs`, and `tests/macros/probe_macros_unbounded_depth.wat`. No `step_form`, no `NoProgress`, no `peel_fn_form`, no nextest override, no nth time-limit.

## The renderer

`value_to_watast` writes a record in declaration order, an enum as `(:path.Variant {:field value})`, `Option` and `Result` in that shape, a `Vector` / `PersistentVector` / `HashMap` / `PersistentMap` / `HashSet`, a named function with no capture as its keyword, and a closure as `(fn [p <- :T] -> :Ret body)` with captures substituted. A char is a `CharLit`. The catch-all is still `TypeMismatch`, `expected` `"a form"`, `got` that value. `src/kernel/source.rs` now says a `Frame` value renders as its constructor; `macro-call-site` still returns the form.

`rendered_record_fields_follow_declaration_order` asserts the record keywords by position (`:user::P`, `:a`, `3`, `:b`, `4`), the enum as keyword `:user::Opt.Some` plus a map pair `:value` / `7`, the keyword `:user::inc`, and a vector of length 2. Reversing the field zip failed that test: the list was `:user::P`, `:b`, `4`, `:a`, `3`. The zip is declaration order again. The test passed after the revert.

## The mandate, the checker, the boundary

The parser no longer requires the return to be `:wat::WatAST`. A keyword, a symbol, or a type form parses through `parse_type_node` and is stored on `MacroDef.ret_type`. A parameter is still `:wat::WatAST`. A rest parameter is still `(:wat::core::Vector :- [:wat::WatAST])`.

`check_program` takes the macro registry. After the `defn` bodies, `check_registered_macros` builds a `Function` whose parameters are forms and calls `check_function_body` on every registered macro. `:wat::core::macro-error` is `∀T. String -> :T`, the same polymorphic return as `assertion-failed!`.

The expansion boundary still calls `value_to_watast`. Its comment is the contract: a value with no syntax is the only refusal left there. `program_body_producing_non_ast_rejected` now drives `check` on

```
(:wat::core::defmacro :my::m [] -> :wat::WatAST
  (:wat::core::Vector :- [:wat::core::i64] 1 2))
```

and asserts `ReturnTypeMismatch` for `:my::m`, expected `:wat::WatAST`, got `(:wat::core::Vector :- [:wat::core::i64])`. That test passed.

`:t::deep-answer` in `tests/macros/probe_macros_unbounded_depth.wat` now declares `-> :wat::core::i64`. A `--check` of that file does not mention `:t::deep-answer`.

## What the first check refuses

One program whose own macro is an honest `-> :wat::core::i64` returning `42` (`probes/macro-returns-int.wat`) is `70 type-check errors`. None of them are in that probe. The same seventy are the standard library, on every program measured (`macro-returns-int.wat`, `probe_macros_unbounded_depth.wat`). The untyped probe and the lying declaration add their own errors on top (72 and 71).

Nine existing macros. The numeric stop is more than ten, so that stop does not fire. These nine are `defn`, `defservice`, `format`, both `defrecord`s, `defstruct`, `extend-surface`, `kwargs-lower`, and `assertion-failed!`. Rewriting them was not started. The 2,616-file sweep was not run: every file in it loads this library, and the library already refuses. The floor was not run for the same reason. The honest fixtures were written and do not reach `main`; startup exits 3 on the seventy.

| macro | where | what the checker says |
|---|---|---|
| `:wat::core::defn` | `wat/core.wat:755`, `:761`, `:790` | `:wat::keyword::to-string` expects `:wat::core::keyword`, got `:wat::WatAST` |
| `:wat::core::kwargs-lower` | `wat/core.wat:540` | same `to-string` |
| `:wat::core::defstruct` | `wat/core.wat:2048` | same `to-string` |
| `:wat::core::extend-surface` | `wat/core.wat:2093` | same `to-string` |
| `:wat::core::defrecord` | `wat/Record.wat:171` | same `to-string` |
| `:wat::holon::defrecord` | `wat/Record.wat:267` | same `to-string` |
| `:wat::service::defservice` | `wat/service.wat:186`, `:234`, `:367`, `:470`, `:471`, `:839`, `:870`, `:875` | same `to-string` |
| `:wat::service::defservice` | `wat/service.wat:1289` | `if` else-branch expects `:wat::core::keyword`, got `:wat::WatAST` |
| `:wat::service::defservice` | `wat/service.wat:2683`, `:2807` | `:wat::core::nil` is a type keyword in value position; the form is an unquote, so it is live at expansion |
| `:wat::service::defservice` | `wat/service.wat:2707`, `:2831` | `if` else-branch: a process impl function against a thread impl function. The same span is reported once per expanded service (`hologram-svc`, `lru-svc`, `stderr-svc`, `stdin-svc`, `stdout-svc`, `mem-store`, `sqlite-store`, `journal`, `span`) |
| `:wat::core::format` | `wat/core.wat:1725` | `to-string` on a `WatAST` |
| `:wat::core::format` | `wat/core.wat:1783–1792`, `:1913`, `:1921–1928` | a fold accumulator declared `:wat::core::Tuple` whose body is a real tuple `:(String, String)`; `first` / `second` refuse `:wat::core::Tuple`; `conj` expects `:wat::core::Tuple` and gets `:(String, String)` |
| `:wat::kernel::assertion-failed!` | `wat/kernel/assertion.wat:69` | `if` else-branch expects `(:wat::core::Vector :- [(:wat::core::Vector :- [:wat::WatAST])])`, got `:wat::WatAST` |

`keyword/to-string` accepts a keyword form at expansion (`Value::wat__WatAST` of a keyword) and a keyword value. The scheme only names the keyword. There is no union in `TypeExpr`, so one parameter type cannot say both. That is the same `check_function_body` a `defn` uses.

## The probes

`wat --check probes/macro-declared-form-returns-int.wat` exits 1. Among the 71 errors:

```
:my::answer: body produces :wat::core::i64; signature declares :wat::WatAST
```

`wat --check probes/macro-body-untyped.wat` and `probes/macro-unused-arm.wat` each add:

```
:wat::string::length: parameter #1 expects :wat::core::String; got :wat::core::i64
:wat::core::if: parameter else-branch expects :wat::WatAST; got :wat::core::i64
```

The span is the probe. The callee is named. `ReturnTypeMismatch` is the arm that names the macro; these two are `TypeMismatch` on the call.

`probes/macro-returns-int.wat`, `macro-returns-vector.wat`, `macro-returns-record.wat`, and `macro-returns-enum.wat` were each run. All four exit 3. The i64 probe contributes no error of its own. The runs do not print the values, because startup stops on the nine macros above.

## Rows

| # | result |
|---|---|
| 0 | **MET.** `origin/the-little-wat-004-eval-step` exists. `the-little-wat` was clean before this strike. |
| 1 | **Not measured.** The four fixtures exit 3 before `main`. |
| 2 | **MET as a diagnostic.** `:my::answer: body produces :wat::core::i64; signature declares :wat::WatAST` is in the check output, together with the seventy library errors. |
| 3 | **MET as a diagnostic.** Both probes are refused. The bad call is `:wat::string::length` on an `i64`, and the `if` else-branch. The message names the callee. The macro name is the `defmacro` that contains that span. |
| 4 | **Stopped on the nine.** `:t::deep-answer` declares `-> :wat::core::i64` and is absent from that file's 70 errors. The library nine are in every program. |
| 5 | **MET.** `program_body_producing_non_ast_rejected` passed. |
| 6 | **MET, mutant reverted.** The render test passed. The reversed zip failed it and was reverted. The test passed again. |
| 7 | **Not run.** Every freeze type-checks the nine. |
| 8 | **MET.** The diff has no stepper. |
