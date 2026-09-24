# SCORE — excursus 002 stone 3: the checked body is the run body (F-196, option E)

Struck 2026-09-24, 02:10–03:35 PDT (about 1 h 25 min against the 2–4 h prediction). wat-rs on
`the-little-wat` at `bbfac2ee8`; the-little-wat on `main` at `40adcda`. **Both trees are left
dirty and nothing is committed.** Every number below was measured in this session. HEAD's
binary was copied aside before the change (`wat-head`) and every before/after pair uses it.

**Verdict first.** Rows 1, 2, 3, 4, 6, 7, 8, 9 and 10 are MET. **Row 5 is NOT MET as written.**
The floor shows F-197's two lint reds plus **two new reds**. Both are in-crate unit tests in
`src/runtime.rs` whose harness depended on the old step-6 body. Neither is a latent program
error. They are listed under row 5 and were not edited to make them pass. No STOP fired.
STOP-1 did not fire: nothing consumes the body before step 7. The body consumers found all run
at step 8 or later, and they are listed under "What consumed the old body".

**The fixed check also retires a finding.** F-190 ("the checker refuses to re-bind a PARAMETER at
a new type … and blames a `vec` that is not there") was an artifact of F-196. The old check typed
the un-normalized body, where `(wat.core/let [x 1] x)` has an unbound symbol head. The error text is
consistent with the binding vector `[x 1]` having been typed as a `vec` call; that part is inferred,
not traced. With the normalized body checked, the program is
accepted and prints `4`, the same as the native compiler and the keyword spelling on HEAD. Details
are under row 8.

## What was built — the design (E, one copy)

| piece | where | what |
|---|---|---|
| the declaration marker | wat-rs `src/value/symbol_table.rs:158` (`bodies_in_residue`), `:344` `declare_function`, `:350` `body_in_residue` | Step 6 now DECLARES. The entry in `sym.functions` holds the signature and a placeholder body (`nil`, the same placeholder the defclause stub uses), and the name is marked "body lives in the residue". `register_function` clears the mark (a real body supersedes a declaration), and so does `remove_function` |
| step 6 | `src/declare/register.rs:230,265` (`register_defines`, the fn-shape arm and the user-variadic arm); `src/declare/preregister.rs:398,486` (`preregister_fn_defs_in_do/_in_let`, USER privilege only) | `sym.declare_function(path, declaration_of(func, span))` replaces `sym.register_function(path, func)`. `declaration_of` (`register.rs:351`) drops the parsed body. Stdlib registration is unchanged: stdlib's do/let defs are never re-evaluated from a residue |
| step 8 | `src/check.rs:568` `function_body`, `:594` `residue_fn_bodies`, `:689` | `check_program` finds each user fn-shape `def` in the forms it is handed (the normalized residue). It uses the SAME parsers and the SAME recognition as step 6: top-level fn-shape or user-variadic, and do/let bodies. Every body walk in `check_program` reads through `function_body`: the validators, the restricted-call walker, the def-position walker, and `check_function_body` (which now takes the body as a parameter). For a declared name that is the residue form's body; for everything else it is the body the `Function` carries |
| step 9 | `src/declare/register.rs` `register_runtime_defs` (unchanged loop) | Evaluates the same residue `def` form. Its `register_function` installs the evaluated `Function` and clears the mark. After the loop, `assert!` that no declaration is left without a body |
| live-session reinstall | `register.rs:1967` (the `has_def_value && !redef_allowed` arm), `named_def_fn` `:2130` | See row 7. A session seeds the prior turn's `runtime_def_values`, so this arm skips re-evaluating a prior turn's `def`. That used to leave a freshly re-parsed step-6 body running. It now reinstalls the function the `def` produced when it was evaluated. `named_def_fn` is the extracted, shared construction the evaluating arm already used |
| unit-test harnesses | `src/runtime.rs` (`run`, the ctx `run` variant, 3 `apply_function` tests) | They called `register_defines` and then ran functions straight out of `sym`, using step 6 as runtime registration. They now call step 9's own door (`register_runtime_defs`) on their `def` forms. This is test-harness plumbing, not a change to any test's program or assertion |

`git diff --stat` (wat-rs):

```
 src/check.rs               | 108 ++++++++++++++++++++++++++++++++++++++++-----
 src/declare/preregister.rs |  26 ++++++++++-
 src/declare/register.rs    |  86 ++++++++++++++++++++++++++++--------
 src/runtime.rs             |  36 +++++++++++++--
 src/value/symbol_table.rs  |  31 +++++++++++++
 5 files changed, 252 insertions(+), 35 deletions(-)
```

Probe files are new in `docs/excursus/2026/09/002-no-guesses/stone-3/`: `slen-namespaced.wat`,
`slen-keyword.wat`, `param-shadow-keyword.wat` and `session.txt`.

---

## Row 1 ⛔ — the namespaced wrong call is caught — **MET**

```
$ wat-head --check stone-3/slen-namespaced.wat          # HEAD
exit=0
$ wat-head stone-3/slen-namespaced.wat
[#wat.kernel/LociDiedError.RuntimeError {:message "#wat.runtime/PatternMatchFailed {:message \":wat::core::match: no arm matched scrutinee of type wat::core::i64; exhaustiveness should be caught at type-check time\" ... :value-type \"wat::core::i64\"}"}]
exit=1

$ wat --check stone-3/slen-namespaced.wat               # this build
#wat.check/CheckErrors {:message "1 type-check error" :location nil :causes [] :errors [#wat.check/TypeMismatch {:message ":user::slen: parameter #1 expects :user::S; got :wat::core::i64" :location #wat.core/Span {:file "slen-namespaced.wat" :line 10 :col 31 :end #wat.core/Option.Some {:value #wat.core/Pos {:line 10 :col 32}}} :causes [] :callee ":user::slen" :param "#1" :expected ":user::S" :got ":wat::core::i64" :remedies []}]}
exit=1
```

## Row 2 ⛔ — keyword spelling unchanged — **MET**

HEAD and this build print the same bytes:

```
$ wat --check stone-3/slen-keyword.wat
#wat.check/CheckErrors {:message "1 type-check error" :location nil :causes [] :errors [#wat.check/TypeMismatch {:message ":user::slen: parameter #1 expects :user::S; got :wat::core::i64" :location #wat.core/Span {:file "slen-keyword.wat" :line 10 :col 36 :end #wat.core/Option.Some {:value #wat.core/Pos {:line 10 :col 37}}} :causes [] :callee ":user::slen" :param "#1" :expected ":user::S" :got ":wat::core::i64" :remedies []}]}
exit=1
```

## Row 3 ⛔ — one copy — **MET**

**Between normalization (step 7, `src/freeze/env.rs:349`) and evaluation (step 9,
`src/freeze.rs:627`), a user function's body exists in exactly one place: its
`(:wat::core::def :name (:wat::core::fn …))` form in `bundle.residue`.**

- Step 6 leaves only a declaration in `sym.functions`: the signature, a `nil` placeholder body, and
  the `bodies_in_residue` mark.
- Step 8 (`check_program(&bundle.residue, …)`, `freeze.rs:1305`) reads each declared body out of
  that residue:

```rust
// src/check.rs:568
fn function_body<'a>(path: &str, func: &'a Function, sym: &SymbolTable,
                     residue_bodies: &'a HashMap<String, Arc<WatAST>>) -> Option<&'a WatAST> {
    if sym.body_in_residue(path) {
        let body = residue_bodies.get(path).map(|b| b.as_ref());
        assert!(body.is_some(), "F-196: {path} was declared at step 6 but no def form in the checked forms carries its body");
        return body;
    }
    match &func.body { FunctionBody::Wat(b) => Some(b.as_ref()), FunctionBody::Native => None }
}
```

- `residue_bodies` is a map the check builds, uses and drops. It is a view parsed from the residue,
  not a store.
- Step 9 evaluates the same residue form (`register_runtime_defs_form`'s `:wat::core::def` arm),
  and its `register_function` replaces the declaration.
- Two `assert!`s hold the invariant in release builds too, because the floor is weighed in release:
  - `register_runtime_defs` ends with "no declaration left without a body";
  - `function_body` refuses a declared name whose `def` is not in the checked forms.

  Neither fired anywhere: not on the floor, not in the corpus, not in the session probe.

**How declare-time registration changed.** Step 6 still does everything it did for the resolver
and the checker: the name exists, the scheme comes from the signature, and the metadata-map is
recorded. So a recursive or mutually recursive call is typed against the declared scheme before
any body is checked (trap door 1). The floor's recursion tests are green, and so is
`define_recursive_factorial`. The one thing step 6 stopped doing is holding the body.

## Row 4 ⛔ — correct programs run as before — **MET**

`tools/elf-run.sh` before (with `WAT=wat-head`) and after (this build):

```
BEFORE
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 4 refusals and
         4 traps, both ways. rules: 8 conflicts in 10307 argument-parameter pairs over 99 programs.
         types: 9 type conflicts in 17367 nodes both typed (17266 agree, 92 refined) over 99 programs.
real	13m35.789s

AFTER
elf-run: ok -- 87 native binaries. 38 agree with the interpreter;
         3 more use syscalls it has no implementation of (F-119); 4 refusals and
         4 traps, both ways. rules: 8 conflicts in 10307 argument-parameter pairs over 99 programs.
         types: 9 type conflicts in 17374 nodes both typed (17273 agree, 92 refined) over 99 programs.
real	9m27.023s
rc=0
```

- The interpreter builds `elf/compile.wat` itself inside this run, which is the heaviest runtime
  witness there is. It produced the same 87 binaries, and 38 agree.
- The floor's runtime tests are green apart from the two step tests under row 5, which are not
  runtime divergences.

**One program's run DID change, and it was wrongly refused before.** That is
`elf/probe/check-param-shadow.wat` (F-190):

```
$ wat-head elf/probe/check-param-shadow.wat
[#wat.kernel/LociDiedError.StartupError {:error #wat.check/CheckErrors {... ":wat::core::vec: parameter #3 expects :wat::core::String; got :wat::core::i64" ...
$ wat elf/probe/check-param-shadow.wat
4
```

The keyword spelling of the same program, `stone-3/param-shadow-keyword.wat`, gives
`--check exit=0` and prints `4` on HEAD and on this build alike. So this is the namespaced
spelling catching up with the keyword spelling. It is not a new behaviour; see row 8.

## Row 5 — the floor — **NOT MET as written**

`NEXTEST_TEST_THREADS=4 scripts/floor.sh`. The baseline is `.floor/2026-09-24T07-55-54Z`
(`5397 tests run: 5394 passed (4 slow), 2 failed, 1 timed out`).

**Run 1, `.floor/2026-09-24T09-32-15Z`:**
`Summary [1160.708s] 5397 tests run: 5392 passed (5 slow), 5 failed, 22 skipped`

- The fifth red was mine, and the arm names it.
  `probe_supervisor_select_lost::select_prime_yields_lost_when_process_child_crashes` compares a
  golden that pins a frame at `:file "src/freeze.rs" :line 1525`. My first placement of the
  step-9 `assert!` was in `freeze.rs`, and it moved that line to `1533`:

```
    assertion `left == right` failed: EDN data mismatch (Failure.error.message must match the process crash sentinel golden)
    ... #wat.kernel/Frame {:file "src/freeze.rs" :line 1533 :symbol ":user::main"} ...   (actual)
    ... :file "src/freeze.rs" :line 1525 ...                                             (expected)
```

- The fix was to move the assert out of `freeze.rs` into `register_runtime_defs`, the one door
  both boot and session call. `freeze.rs` is byte-identical to HEAD again.
- That is a change to my code, so the floor was run again as a new measurement. The red test was
  not re-run in isolation.

**Run 2 on the final tree, `.floor/2026-09-24T09-59-56Z`:**

```
     Summary [1158.362s] 5397 tests run: 5393 passed (5 slow), 4 failed, 22 skipped
        FAIL [   0.082s] (  74/5397) wat::lint no_inlined_wat_in_tests::tests_carry_no_inlined_wat
        FAIL [   0.119s] (  77/5397) wat::lint no_loose_string_assert::tests_carry_no_loose_string_assert
        FAIL [   0.849s] (1517/5397) wat runtime::tests::step_tail_recursion_terminates_under_bound
        FAIL [   0.852s] (1520/5397) wat runtime::tests::step_user_function_call
```

| red | whose | what |
|---|---|---|
| `tests_carry_no_inlined_wat`, `tests_carry_no_loose_string_assert` | F-197, pre-existing | unchanged |
| F-197's third, `every_wat_scripts_file_loads_on_the_current_runtime` | — | **did not time out.** It passed at 571.5 s (run 1) and 570.3 s (run 2), under its 600 s deadline. Recorded, not claimed as a fix: it is the same test sitting at its deadline |
| `step_user_function_call` (`left: None, right: Some(9)`), `step_tail_recursion_terminates_under_bound` (`sum-to 3 0 should equal 6 / left: None`) | **this stone — consumers of the old body** | details below |

**Why the two step tests went red.**

- `eval-step!` on a user function refuses any function with a `closed_env`
  (`step_user_call`, "closure-bearing — Phase 3").
- Every function that step 9 evaluates has one, because `eval_fn` sets `closed_env: Some(env)`.
  Only the step-6 re-parse had `closed_env: None`.
- These two tests reached the step rule only because the harness ran the step-6 body.
- **Production never did.** The same call on HEAD's binary, through the real pipeline:

```
$ wat-head step-user.wat      # (:wat::eval-step! (:wat::core::quote (:my::test::square 3)))
"(Err :wat::core::EvalError{#0: \"no-step-rule\", #1: \"eval-step! has no rule for op: :my::test::square (closure-bearing — Phase 3)\"})"
```

So the tests asserted a behaviour reachable only through the second copy. They were left red, per
STOP-2's spirit: they are the builder's to rule on. There are two ways to turn them green: teach
`step_user_call` about a top-level def's empty closure, or retire the tests. **Newly caught latent
errors in wat-rs's own tree (`wat/`, `tests/`, `wat-scripts/`): zero.** STOP-2 was not approached.

## Row 6 — `nth-record.wat` now fails `--check` — **MET**

```
$ wat-head --check elf/probe/nth-record.wat
exit=0
$ wat --check elf/probe/nth-record.wat
#wat.check/CheckErrors {:message "1 type-check error" :location nil :causes [] :errors [#wat.check/TypeMismatch {:message ":wat::core::nth: parameter #1 expects (Vector :- [T]), (List :- [T]), (PersistentVector :- [T]), or WatAST; got :user::P" :location #wat.core/Span {:file "elf/probe/nth-record.wat" :line 5 :col 37 ...}}]}
exit=1
```

## Row 7 — live sessions — **MET, by probe**

The live session calls the same pipeline by construction: `eval_form_against_defs`
(`runtime.rs`) goes through `freeze_forms`, then `startup_from_forms[_with_session]`, then
`build_env`, `check_program` and `FrozenWorld::freeze`. It then calls `register_runtime_defs`
itself, the same door. The probe was driven through `wat --repl` with `stone-3/session.txt`:

```
(:wat::core::defenum :user::S :wat::enum::Pure :None [] :Some [s <- :wat::core::String])
(wat.core/defn user/slen [o :- :user::S] :- wat.type/i64 (:wat::core::match o [...] [...]))
(wat.core/defn user/dbl [n :- wat.type/i64] :- wat.type/i64 (wat.i64/* n 2))
(user/dbl 21)
(user/slen (:user::S.Some {:s "xyz"}))
(wat.core/defn user/bad [] :- wat.type/i64 (user/slen 5))
(user/bad)
(user/dbl 5)
```

```
=== wat-head
42
3
#wat.core/EvalError {:kind "pattern-match-failed" :message "no match arm fired for wat::core::i64 scrutinee"}
10

=== this build
42
3
#wat.core/Fault {:message "1 type-check error" ... :causes [#wat.check/CheckErrors {... #wat.check/TypeMismatch {:message ":user::slen: parameter #1 expects :user::S; got :wat::core::i64" :location #wat.core/Span {:file "<read-string>" :line 1 :col 55 ...}}]}]}
#wat.core/Fault {:message "1 unresolved reference" ... :path ":user::bad" ...}
10
```

- On HEAD the wrong-typed `defn` was accepted into the session, and the call panicked at runtime as
  a pattern-match failure.
- Now the `defn` line itself is refused with the TypeMismatch, so `user/bad` never enters the
  definition set, and the next line reports it unresolved.
- Lines 4, 5 and 8 call functions defined in EARLIER turns. They exercise the session reinstall
  arm (`register.rs:1967`): `42`, `3` and `10` agree with HEAD.
- The step-9 `assert!` would have fired if a declaration had been left body-less.

## Row 8 — the-little-wat's corpus — **MET**

`wat --check` over `elf/src/*.wat elf/bench/*.wat` (68 files), before and after:

- Exit codes are identical: 65 pass and 3 fail on both builds. The 3 failures are `parse`,
  `parsebits` and `walk`, all for compiler-only `wat.os/poke`.
- **All 68 outputs are byte-identical** (`cmp` over the saved stdout+stderr of each file).
- `elf/compile.wat`: `exit=0` on both. It is now fully type-checked, since it is mostly namespaced,
  and it passes.

Outside this row's corpus, the fixed check changed the verdict on two `elf/probe/` files: this
build rejects `nth-record.wat` (row 6) and accepts `check-param-shadow.wat`, which HEAD rejected.
The second is **F-190 dissolved**. What is MEASURED is that the rejection disappears when the normalized body is checked, and that the keyword spelling never had it. The account below of why the bogus `vec` appeared is inferred from the error text; I did not trace the inference path line by line:

- The old check typed the un-normalized body, where `wat.core/let` is an unbound Symbol head.
- An unbound head gets no special-form treatment, so its binding vector `[x 1]` is inferred as a
  vector literal. `x` is the String parameter and `1` is an i64, which is the `vec: parameter #3
  expects String; got i64` the entry could not explain.
- That is why the rejection appeared only when the let rebinds the PARAMETER. A fresh name `y` in
  `[y 1]` is unbound, and an unbound symbol types as a fresh variable.
- The keyword spelling never had the error: `param-shadow-keyword.wat` passes `--check` and prints
  `4` on HEAD.

F-190 should be closed as a symptom of F-196 when the orchestrator next edits FINDINGS.

## Row 9 — the oracle still works — **MET**

`tools/rules.sh` ran inside `elf-run.sh` in report mode.

| gate | before | after |
|---|---|---|
| rules (boundary) | `8 conflicts in 10307 argument-parameter pairs over 99 programs` | same |
| types | `9 type conflicts in 17367 nodes both typed (17266 agree, 92 refined)` | `9 type conflicts in 17374 nodes both typed (17273 agree, 92 refined)` |

- The conflict LINES are the same set (the diff is ordering only).
- The type totals moved in the direction the fix predicts: `KType 28992 → 29003`,
  `joined 17367 → 17374`, `agree 17266 → 17273` and `compiler-only 290 → 283`. The startup check
  now types positions that were fresh variables before.
- The refused list changed exactly as rows 6 and 8 say. The checker now refuses `nth-record.wat`
  at startup; before, it was reported by the recording check's second pass (`1 check errors → 0`).
  `check-param-shadow.wat` is no longer refused.

The stone-2 recording pass over the frozen world (`distribution/mod.rs:371`) is unchanged and
still correct: after freeze there are no declarations, so it reads `sym.functions` as before.

## Row 10 — cost — **MET**

`wat --check elf/compile.wat`, `wat-head` against this build, 6 interleaved pairs, pinned to one
core (`taskset -c 2`), `cpu_core/instructions/u`:

| | HEAD | this build |
|---|---|---|
| instructions, min of 6 | 3,164,382,551 | 3,210,515,763 (**+1.46%**) |
| wall, best of 6 | 805 ms | 800 ms |

The +1.46% is the check now doing its job: it types the namespaced bodies it used to skip over as
fresh variables. It also parses each residue `def` once more in `residue_fn_bodies`. Wall time is
within noise. The step-9 path is unchanged in cost; it evaluates the same forms it always did.

## What consumed the old body (the STOP-1 question, answered)

| consumer | phase | disposition |
|---|---|---|
| `check_program`'s 4 body walks | step 8 | now read the residue body. This is the fix |
| rete-defn stamp, `apply_rete_defn_contracts` | step 9, after EACH form | Reads bodies of declared rete-defns and their callees. For a name not yet evaluated it now sees the `nil` placeholder, so it passes, where it used to walk the un-normalized step-6 body. It re-walks every declared name after every form, so the final verdict is taken against the real bodies. A refusal can move LATER within the same freeze (at the callee's form, not the caller's), and freeze still fails. No correct program changes. Noted as the one place a transient verdict differs |
| live-session skip arm | step 9, session re-freeze | Used to leave a freshly re-parsed step-6 body (with `closed_env: None`) as the RUNNING function for every prior-turn `def`. Now it reinstalls the function that `def` produced when it was evaluated. Row 7 witnesses it |
| `runtime.rs` unit-test harnesses (5 helpers) | tests | now call `register_runtime_defs` (step 9's door) |
| `runtime::tests::step_*` (2 tests) | tests | asserted a state only the step-6 copy could reach. Left red (row 5) |
| resolver, normalizer, `CheckEnv::from_symbols`, `register_defalias`, the FreezeValidator (rete wall) | 6–7.8 | read names and signatures only, verified by reading each; unaffected |

Nothing needs the body before step 7, so option E's premise holds.

## Not done, affirmatively

- The latent-error backlog is empty in wat-rs's tree.
- F-197's lints were not touched.
- The compiler was not touched, and nothing was pushed or committed.
- The two step tests were not edited.
- stdlib is unaffected. It is keyword-spelled (`grep -c "(wat\.[a-z.]*/" wat/` finds 0), and its
  bodies still live in `sym.functions` as before.

---

## ORCHESTRATOR — the kill, weighed against my own re-run (2026-09-24)

HEAD = a clean build of wat-rs `bbfac2ee8` from `git archive`; NEW = the stone's `target/release/wat`.

| claim | my re-run | verdict |
|---|---|---|
| row 1 | `(user/slen 5)`, namespaced: HEAD **exit 0**; NEW **exit 1**, `TypeMismatch :user::slen: parameter #1 expects :user::S; got :wat::core::i64` | **confirmed** |
| row 2 | keyword spelling: HEAD and NEW both exit 1 with the same error | **confirmed** |
| row 6 | `nth-record.wat`: HEAD exit 0; NEW exit 1 (`:wat::core::nth` TypeMismatch) | **confirmed** |
| row 8 | all 68 of `elf/src/*.wat elf/bench/*.wat`: **output and exit byte-identical, HEAD vs NEW** | **confirmed** — the fix changes nothing for correct code in the builder's corpus |
| row 5, the floor | final ARM `2026-09-24T09-59-56Z`: **5,397 run, 5,393 passed, 4 failed** — F-197's two lints, and `step_user_function_call`, `step_tail_recursion_terminates_under_bound` | **as reported** |
| the two step tests are a stale premise | my own probe, `(:wat::eval-step! (quote (:my::test::square 3)))` through the real pipeline: **HEAD refuses it** — `no-step-rule … closure-bearing — Phase 3` — and NEW gives byte-identical output | **confirmed.** They passed at HEAD only because their harness ran step 6's copy (`closed_env: None`), which no real program reaches. They asserted a behaviour that existed only through the second copy — the copy this stone removed |
| F-190 | `check-param-shadow.wat`: HEAD refuses it blaming a phantom `:wat::core::vec`; NEW passes `--check` and prints `4` | **confirmed — F-190 was F-196 in disguise**, closed by this stone |

### For the builder

1. **The two step tests** — teach `step_user_call` that a top-level def's closure is empty, or retire
   the tests. Either is honest; neither was chosen here.
2. **The live-session skip arm** (`register.rs:1967`) now reinstalls the function a `def` produced when
   it was first evaluated, where it used to reinstall a freshly re-parsed step-6 copy. The REPL probe
   (`stone-3/session.txt`) prints the same values as HEAD, but it is a runtime change in live sessions
   and it was made by this stone.

### Verdict

**Stone 3 lands** (wat-rs committed locally on `the-little-wat`, not pushed). A function body now lives
in exactly one place between normalization and evaluation, so what `--check` checks is what runs.
