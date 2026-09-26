# SCORE — excursus 004 stone 1, re-strike: captured values that have syntax, and the floor deadlines

Nothing is committed. wat-rs stays dirty. the-little-wat gained this score. The binary is `CARGO_TARGET_DIR=/home/watmin/.cache/wat-step-004`. Every probe was `timeout -s KILL`. This file is the re-strike of the two refuted rows. The tree from the first strike stays.

## What a step is

A descended child is a value when `step_form` answers `Terminal` or `AlreadyTerminal` of that same form. Those arms are the fact. `is_step_canonical` is gone, so a new terminal arm is a value without a second list to update. `is_match_canonical` and `is_holon_arg_canonical` stay: one is "this scrutinee is already a constructor", the other is "this holon tree fires in one `eval`".

`StepNext` of a form equal to the input is `NoProgress`, and the message names the form. `eval-step!` and `:wat::eval::walk` both enter through `checked_step`.

A namespaced symbol head is rewritten with `ns_to_wat_path` and then stepped as that keyword, so the fire hands `eval` the keyword. A `fn` form in head position is applied by `peel_fn_form`, the same peel `eval_fn` uses, then `substitute`. A registered call substitutes its parameters and then each free symbol `closed_env` still binds, rendered by `value_to_watast`. A top-level `defn` mentions none of those, so it substitutes nothing extra. `closed_env.is_some()` is gone.

`value_to_watast` writes a value that has syntax. A record is its constructor, fields in declaration order, each field rendered the same way. An enum value is `(:path.Variant {:field value})`, a unit variant `(:E.V {})`. `Option` and `Result` use that same shape (`:value` / `:error`). A named function whose body mentions no capture is its keyword. A closure is `(fn [p <- :T] -> :Ret body)` with those captures already substituted. `Vector`, `PersistentVector`, `HashMap`, `PersistentMap`, `HashSet`, `String`, `bool`, and nil are the literal or constructor form. Map pairs and set elements are sorted by the edn text of the rendered key or element. The catch-all is still `TypeMismatch`, `expected` the fixed phrase "a form", `got` that value's own snapshot. The refusal list is below.

A record accessor's synthesized body is the class-check `if` whose success arm calls `:wat::core::type` and `:wat::core::struct-field`. Those two keywords step through `step_descend_then_fire`, beside `:wat::core::u8`. An enum map constructor whose single argument is a map is terminal once that map is a value, so the map is not β-reduced as a positional parameter. A bare field read whose receiver is already a data form fires `eval` of that one form and returns the rendered value.

## Rows the weighing credited

| # | result |
|---|---|
| 1 | **MET.** `eval-step-user-fn-kw.wat` → `[4 3]`. `eval-step-recursion.wat` → `[6 19]`. |
| 2 | **MET.** `eval-step-builtin-symbol.wat` → `[3 1]`. `eval-step-user-fn-symbol.wat` → `[4 2]`. |
| 3 | **MET.** `eval-step-let-bound-fn.wat` → `[43 4]`. The trace printed four different forms, then `TERMINAL 43` on the fourth step. |
| 4 | **MET.** `eval-step-toplevel-closure.wat` → `[15 2]`. |
| 5 | **MET, mutant reverted.** The fire arm of `step_descend_then_fire` returned `StepNext` of its input. `eval-step-builtin-kw.wat` answered `Err` kind `no-progress`, message `eval-step! made no progress on (:wat.core/+ 1 2)`. The walk ended. The arm was restored. A clean rebuild then answered `[15 2]` on the closure probe. |
| 6 | **MET.** `step_user_function_call` and `step_tail_recursion_terminates_under_bound` passed on the clean floor below (`1.012s`, `0.974s`). Their bodies were not edited. |
| 7 | **MET, mutant reverted.** `step_round_trip_agrees_with_eval_ast` grew. It steps and evaluates both spellings, a plain `defn`, recursion, a let-bound `fn`, a top-level `def` of a closure, a function that returns a closure then applied, a closure over a closure, and `(:wat::f64::+ 0.1 0.2)`. A quoted symbol head is data, so `eval-ast!` looks it up as a local; the step's terminal is compared to eval of the keyword `ns_to_wat_path` names. Floats agree when they are equal or the relative gap is under `1e-9`. Skipping capture substitution made `eval-step-toplevel-closure.wat` answer `no-step-rule` for `symbol-ref:k`. That return was removed. The clean floor passed this test at `7.320s`. |
| 8 | **MET.** The diff has no `is_step_canonical`. |
| 9 | **STOP-3.** The clean floor, run alone after the deadline bumps, is red on four tests. The arm is below. It stands as captured. |
| 10 | **MET.** `eval-step-closure.wat` and `eval-step-closure-kw.wat` each print `42` and then `StepNext` of `(:wat.core/+ 3 1)`. |
| R1 | **MET on the three refuted probes, mutant reverted.** Detail below. |
| R2 | **The deadlines are bumped. The floor that followed is the arm in row 9.** |

The let-bound trace, in order:

```
(:wat.core/let [f (:wat.core/fn [y <- :wat.core/i64] -> :wat.core/i64 (:wat.core/+ 42 y))] (f 1))
((:wat.core/fn [y <- :wat.core/i64] -> :wat.core/i64 (:wat.core/+ 42 y)) 1)
(:wat.core/+ 42 1)
TERMINAL 43
```

## R1 — a captured record, enum, and function

`timeout -s KILL 30 /home/watmin/.cache/wat-step-004/release/wat the-little-wat/probes/eval-step-captures-rec-enum-fn.wat`, after the field-order mutant was reverted:

```
#wat.core/Result.Ok {:value [4 7]}
#wat.core/Result.Ok {:value [8 2]}
#wat.core/Result.Ok {:value [2 3]}
```

Exit 0. `eval` of the three calls is 4, 8, and 2. The second number is the walk's step count. The same binary, the same three lines, immediately before this score.

`rendered_record_fields_follow_declaration_order` builds the values in Rust and calls `value_to_watast` directly. `run` typechecks with the stdlib `TypeEnv` only, so a deftest that declares `defrecord` cannot pass `check_program`. The probe is the closure-over-record, closure-over-enum, and closure-over-registered-function gate. The render test passed on the clean floor at `0.013s`. It asserts:

- `(:user::P :a 3 :b 4)` — keyword `:user::P`, then `:a`, `3`, `:b`, `4`;
- the enum edn text contains `:value` for `(:user::Opt.Some … 7)`;
- a function named `:user::inc` whose body mentions no capture is the keyword `:user::inc`;
- a `Value::Vec` of 10 and 20 is a `WatAST::Vector` of length 2.

Reversing the record field zip put `:b` ahead of `:a`. The test failed on the `:a` assertion at `src/runtime.rs:20575`. The zip is declaration order again. A search for `.rev().zip` in `runtime.rs` is empty. The probe above is the run after that revert.

The probe's `:user::with-fn` closes over the keyword `:user::inc`, so the walk measured the keyword path. `fn_value_to_form` writes `(fn [p <- :T] -> :Ret body)` when the function has no name, or when a named body mentions a capture, and `substitute_captures` has already written those bindings. That fn-form walk was not driven on the binary. A closure over a `Vector`, a `HashMap`, a `HashSet`, a `String`, a bool, or nil was not added to the probe. Those six already have render arms (bool, string, and nil had them before this re-strike). `String`, `bool`, and nil were not re-measured as captures.

### What still refuses

The catch-all names the value by its own snapshot. These variants have no arm:

`u8`, `Sender`, `Receiver`, `RustOpaque`, `IOReader`, `IOWriter`, `Tuple`, `HandlePool`, `ChildHandle`, `ForeignRecord`, `ForeignVariant`, the holon `Vector`, `OnlineSubspace`, `Reckoner`, `Engram`, `EngramLibrary`, `Hologram`, `Instant`, `Duration`, `Uuid`, `List`, `Stream`, `clauses`, `extend_def`.

A function refuses in two further cases, same `TypeMismatch`, `got` the function's snapshot: the body is native and the function is unnamed or its body mentions a capture; or `param_types.len()` differs from `params.len()` on that same path. A named function whose body mentions no capture is the keyword even when the body is native, because that branch returns before the native check. `rest_param` is not written into the `fn` vector.

`WatAST` is copied out as the form it already is. `HolonAST` goes through `holon_to_watast`.

## R2 — deadlines, then the floor alone

`DEFAULT_TIME_LIMIT_MS` is still `5000` (`crates/wat-macros/src/lib.rs:881`).

`(:wat::test::time-limit "15s")` sits immediately before each of the six past-end hermetic deftests: `nth-past-end-vector-raises`, `nth-past-end-persistentvector-raises`, `nth-past-end-list-raises` in `wat-tests/core/core-nth.wat`, and the three `nth-spec-past-end-*` siblings in `wat-tests/core/core-nth-differential.wat`.

`.config/nextest.toml` overrides, dated 2026-09-25, on `profile.default`, `profile.ci`, and `profile.slow`. Filter `test(c5c_nan_is_unordered_gate) or test(c5b_exact_mixed_numeric_order_gate) or test(wat_value_ui) or test(to_edn_derive_ui)`. `slow-timeout` period `90s`, `terminate-after` 2 (kill 180s). The comment records the alone measurements: `c5c` 28.6s, `wat_value_ui` 25.6s, `c5b` 27.3s under load, `to_edn_derive_ui` died on the cargo lock at 30s.

`NEXTEST_TEST_THREADS=4 scripts/floor.sh` with that target dir, nothing else building there. Doctests: six crates, each `test result: ok` (`doctest.log`). Nextest, `.floor/2026-09-25T09-26-38Z`, exit 100:

```
Summary [1494.127s] 5401 tests run: 5397 passed (2 slow), 4 failed, 22 skipped
```

The six deadline deaths from the loaded floor (1811.798s, three nth at 5s, `c5c` / `wat_value_ui` / `to_edn_derive_ui` at 30s) are absent. On this run:

| test | result |
|---|---|
| `nth-spec-past-end-persistentvector-raises` | PASS 3.518s |
| `nth-spec-past-end-list-raises` | PASS 3.571s |
| `nth-spec-past-end-vector-raises` | PASS 3.622s |
| `nth-past-end-list-raises` | PASS 3.315s |
| `nth-past-end-vector-raises` | PASS 3.192s |
| `nth-past-end-persistentvector-raises` | PASS 3.413s |
| `c5b_exact_mixed_numeric_order_gate` | PASS 17.480s |
| `c5c_nan_is_unordered_gate` | PASS 22.583s |
| `to_edn_derive_ui` | PASS 0.405s |
| `wat_value_ui` | PASS 1.545s |

The two slow tests are `retirement_table_is_fully_reachable` and `spec_equals_native_on_every_where_family`. No `TIMEOUT` line.

### The arm

F-197's two lint reds are still red. Two more are red, and one of the F-197 reds gained a site this re-strike wrote. Whole blocks from `.floor/2026-09-25T09-26-38Z/ARM.txt`:

```
        FAIL [   0.149s] (  74/5401) wat::lint no_inlined_wat_in_tests::tests_carry_no_inlined_wat
  stdout ───

    running 1 test
    test no_inlined_wat_in_tests::tests_carry_no_inlined_wat ... FAILED

    failures:

    failures:
        no_inlined_wat_in_tests::tests_carry_no_inlined_wat

    test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 131 filtered out; finished in 0.13s

  stderr ───

    thread 'no_inlined_wat_in_tests::tests_carry_no_inlined_wat' (3706286) panicked at /home/watmin/Work/holon/wat-rs/tests/lint/no_inlined_wat_in_tests.rs:427:5:


    🔥🔥🔥 INLINED-WAT IN TESTS — 1 file(s) still carry a string literal that wat's own
    reader parses as a form (surface-agnostic: rust-scheme `(:wat::core::…)` AND faithful
    Clojure `(wat.core/…)` both count).

    THE FIX — move the wat into a co-located `.wat` fixture and drive it lint-clean via ONE of
    two idioms. RUBRIC (which to reach for): docs/CONVENTIONS.md § 'Test idioms — EDN-over-stdio
    vs just-eval'. In short:
    • just-eval      — `call_beside_value(file!(), ":user::compute")`: run a fixture's named entry
    fn in-process, inspect its typed Result<Value, RuntimeError>. For a
    VALUE/TYPE claim (a fn's return; a compile-time/freeze property, which
    often needs only `startup_beside(file!())`, no call).
    • EDN-over-stdio — `run-hermetic` runs `:user::main` as a real process; it `println`s its
    result as EDN and the test `edn::read`s it back (lossless round-trip).
    For a PROGRAM claim (a crash/exit + reason, stdio effects, IPC fidelity,
    cross-loci behavior).
    One-line: 'the PROGRAM does X' -> EDN-over-stdio ; 'this VALUE/TYPE is X' -> just-eval.
    A legitimately-inline case (e.g. a parser/reader test) earns a per-site
    `// rune:lint(no-inlined-wat) — <reason>` (the reason must earn it).

    Drive it to ZERO. Literal-hit breakdown so far: 0 format!-driver, 0 faithful-surface,
    2 other parse-body. Offenders:

    tests/resolve/probe_little_wat_bits_and_code_point.rs

    note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

That offender is the one F-197 already names.

```
        FAIL [   0.233s] (  79/5401) wat::lint no_loose_string_assert::tests_carry_no_loose_string_assert
  stdout ───

    running 1 test
    test no_loose_string_assert::tests_carry_no_loose_string_assert ... FAILED

    failures:

    failures:
        no_loose_string_assert::tests_carry_no_loose_string_assert

    test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 131 filtered out; finished in 0.21s

  stderr ───

    thread 'no_loose_string_assert::tests_carry_no_loose_string_assert' (3706287) panicked at /home/watmin/Work/holon/wat-rs/tests/lint/no_loose_string_assert.rs:112:5:


    🔥🔥🔥 LOOSE STRING ASSERTIONS — 7 site(s) assert a value with contains/starts_with/
    ends_with where an exact `assert_eq!` belongs. A loose check passes on reordered fields,
    malformed maps, and appended garbage.

    THE FIX (RUBRIC: docs/CONVENTIONS.md § 'Test idioms' -> 'The .edn golden'): a deterministic
    STRUCTURED value goes in a co-located `<probe>__<label>.edn` golden, compared via
    `wat::assert_edn_eq!(actual, include_str!("...edn"))` (parses both sides, structure-exact) —
    capture the whole value, never guess. A scalar -> byte-identical `assert_eq!`. EXEMPT a
    legitimately-loose one (a value that varies per run: path/pid/hash/timestamp, or a targeted
    absence over a large output) with a per-site `// rune:lint(loose-assert) — <reason>`.

    Drive it to ZERO. Offenders:

    src/runtime.rs:20588
    tests/resolve/probe_little_wat_bits_and_code_point.rs:105
    tests/resolve/probe_little_wat_bits_and_code_point.rs:116
    tests/resolve/probe_little_wat_bits_and_code_point.rs:153
    tests/resolve/probe_little_wat_bits_and_code_point.rs:161
    tests/resolve/probe_little_wat_bits_and_code_point.rs:206
    tests/resolve/probe_little_wat_bits_and_code_point.rs:214

    note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The six `probe_little_wat_bits_and_code_point.rs` lines are F-197. `src/runtime.rs:20588` is this re-strike: the enum assertion is `assert!(text.contains(":value"), "{text}")`. The record field order is an exact keyword-position assert, and that is the assertion the reversed zip failed. The enum check is the loose one. Left as the arm captured it.

```
        FAIL [   0.174s] ( 106/5401) wat::lint one_variant_separator::only_identifier_rs_spells_the_variant_separator
  stdout ───

    running 1 test
    test one_variant_separator::only_identifier_rs_spells_the_variant_separator ... FAILED

    failures:

    failures:
        one_variant_separator::only_identifier_rs_spells_the_variant_separator

    test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 131 filtered out; finished in 0.16s

  stderr ───

    thread 'one_variant_separator::only_identifier_rs_spells_the_variant_separator' (3706414) panicked at /home/watmin/Work/holon/wat-rs/tests/lint/one_variant_separator.rs:249:5:


    🔥🔥🔥 A SECOND VARIANT SEPARATOR — 1 site(s) spell the `::` between an enum and 
    its variant OUTSIDE `crates/wat-reader/src/identifier.rs`.

    A variant's fully-qualified name is composed and decomposed in exactly ONE place, or two 
    spellings WILL disagree — nine of these hid for months inside `rsplit_once("::")`, a 
    shape `one_name_grammar.rs` bans for `'/'` and does not name for `"::"`.

    THE FIX — route through the pair:

      compose_variant(enum_path, variant)   -> `{enum}::{variant}`
      decompose_variant(name) -> Option<(&str, &str)>   the exact inverse

    If this site does NOT separate an enum from its variant, add a co-located
    `// rune:lint(one-variant-separator, <category>) — <reason>` on the line or the one
    above, with <category> one of: namespace | type-path | display | edn | not-a-name.
    ⛔ `variant` is NOT a category — a variant site routes through the door.

    Offenders:

    src/runtime.rs:13464  [DATA]  if !head_kw.contains("::") && items.len() == 2 && data_receiver(&items[1], sym) {

    note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The hit is the accessor-head check: a head with no `::` and one data-form argument is a field read. The variant name this stone writes goes through `wat_reader::identifier::compose_variant` (`enum_value_form`). The lint stayed red. No rune was added after the floor.

```
        FAIL [   0.020s] ( 935/5401) wat macros::tests::program_body_producing_non_ast_rejected
  stdout ───

    running 1 test
    test macros::tests::program_body_producing_non_ast_rejected ... FAILED

    failures:

    failures:
        macros::tests::program_body_producing_non_ast_rejected

    test result: FAILED. 0 passed; 1 failed; 0 ignored; 0 measured; 1209 filtered out; finished in 0.00s

  stderr ───

    thread 'macros::tests::program_body_producing_non_ast_rejected' (3730447) panicked at src/macros/tests.rs:594:6:
    called `Result::unwrap_err()` on an `Ok` value: [Vector([IntLit(1, Span { file: "src/macros/tests.rs:19", line: 4, col: 17, end: Some(Pos { line: 4, col: 18 }) })], Span { file: "src/macros/tests.rs:19", line: 4, col: 9, end: Some(Pos { line: 4, col: 19 }) })]
    note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
```

The test's comment says a program body that produces a `Vec` errors because `value_to_watast` rejects `Vec`. The body `(:wat::core::Vector :- [:bogus] x)` with `x` = 1 now expands to a vector of `1`. That is the render this row asked for, landing inside macro expansion. The test still expects `MalformedTemplate`. Left as the arm captured it.

## Resume — the stepper on top of 006

`the-little-wat` is `365ebc014`. The parked stepper was rebased onto it. Conflicts in `value_to_watast` were kept as landed: one `substitute_captures`, and the landed `rendered_record_fields_follow_declaration_order`. 004 adds no second renderer. The six `(:wat::test::time-limit "15s")` annotations came across. The nextest override on `default`, `ci`, and `slow` is the four-test filter (`c5c`, `c5b`, `wat_value_ui`, `to_edn_derive_ui`), period 90s, terminate-after 2. Nothing is committed on `the-little-wat`. The rebase was not pushed. `origin/the-little-wat-004-eval-step` is still `f9ae53550`.

S1. A field read is a head whose `wat_reader::identifier::path` is empty, with one data argument. The line carries `rune:lint(one-variant-separator, namespace)`. `only_identifier_rs_spells_the_variant_separator` passes.

S2. `probes/eval-step-unnamed-closure.wat`: `k` is captured by an unnamed `inner`, and `inner` is captured by an unnamed `outer`. The walk prints `#wat.core/Result.Ok {:value [4 6]}`. Eval of the same form prints `4`.

S3. `probes/eval-step-captures-rec-enum-fn.wat` prints `[4 7]`, `[8 2]`, `[2 3]`, each inside `Result.Ok`. The other `probes/eval-step-*.wat` files match their headers: builtin keyword `Ok [3 1]`, builtin symbol `[3 1]`, let-bound `[43 4]`, recursion `[6 19]`, top-level closure `[15 2]`, user function keyword `[4 3]`, user function symbol `[4 2]`, the trace ends `TERMINAL 43`, and both closure probes print `42` then a `StepNext` of `(:wat.core/+ 3 1)`.

S4. `step_round_trip_agrees_with_eval_ast` now also drives a closure over `:wat::core::Span` (answer 4), a closure over `:wat::core::Option.Some` (answer 8), and the unnamed closure that captures an unnamed closure (answer 4). Each agrees with `eval-ast!`. Reversing the record field zip (`names.iter().rev().zip(fields)`) failed `rendered_record_fields_follow_declaration_order` at the `:a` position assert. That mutant was reverted. The landed test is the one that failed it.

S5. `NEXTEST_TEST_THREADS=4 scripts/floor.sh` alone, `CARGO_TARGET_DIR=/home/watmin/.cache/wat-kw-007`. Doctests exit 0. `.floor/2026-09-26T01-43-58Z`:

```
Summary [1239.709s] 5405 tests run: 5403 passed (1 slow), 2 failed, 22 skipped
```

The two failures are F-197: `tests_carry_no_inlined_wat` and `tests_carry_no_loose_string_assert`. `step_user_function_call` passed (0.808s). `step_tail_recursion_terminates_under_bound` passed (0.790s). The arm is `.floor/2026-09-26T01-43-58Z/ARM.txt`.
