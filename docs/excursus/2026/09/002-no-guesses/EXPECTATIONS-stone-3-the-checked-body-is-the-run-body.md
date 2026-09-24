# EXPECTATIONS — excursus 002 stone 3: the checked body is the run body

Written BEFORE the strike. wat-rs `the-little-wat` at `bbfac2ee8`.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ the namespaced wrong call is caught | `wat --check` on `(user/slen 5)`, namespaced | exit **1**, `TypeMismatch … expects :user::S; got :wat::core::i64` |
| 2 | ⛔ keyword spelling unchanged | the same, keyword spelling | exit 1, the same error as today |
| 3 | ⛔ one copy | the SCORE, with the code | between normalization and evaluation, exactly one place a function body lives; say where, cite it |
| 4 | ⛔ correct programs run as before | the floor's runtime tests; the-little-wat `tools/elf-run.sh` | no new runtime divergence; `elf-run: ok`, 38 agree |
| 5 | the floor | `NEXTEST_TEST_THREADS=4` floor | F-197's three reds and nothing else — or newly-caught latent errors, each listed (STOP-2 above 10) |
| 6 | `nth-record.wat` now fails `--check` | `wat --check elf/probe/nth-record.wat` | non-zero |
| 7 | live sessions | the SCORE | the live-session path shown to check the same body it runs — by a probe if the surface allows, by the call chain otherwise |
| 8 | the-little-wat's corpus | `wat --check` over `elf/src/*.wat elf/bench/*.wat` | the same pass/fail as today (measured 2026-09-24: 0 of 68 hide an error) |
| 9 | the oracle still works | `tools/rules.sh` in the-little-wat | both gates report as before (8 boundary, 9 type) |
| 10 | cost | the SCORE | `wat --check elf/compile.wat` time and instructions, before and after |

## RUNTIME PREDICTION

**2–4 hours.** The design question (does anything consume the declare-time body?) is the whole risk.

## TRAP DOORS

- **Signatures vs bodies.** A recursive or mutually recursive function must be callable in the checker
  before its body is checked — that is what the declare-time registration is for, and it must survive.
- **defclause, extend-type, rete-defn.** Each has its own registration path with history (step 7.6,
  7.7, "Arc 278 #88 v2"). Read those comments before touching the path they share.
- **Row 8 is the corpus the builder writes.** It must not start failing for spelling reasons.
