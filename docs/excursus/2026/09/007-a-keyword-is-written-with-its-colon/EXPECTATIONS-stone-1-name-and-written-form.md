# EXPECTATIONS — excursus 007 stone 1: a keyword's string is how it is written

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 0 | ⛔ 006 parked | `git -C wat-rs branch -r` | `origin/the-little-wat-006-macro-returns`; `the-little-wat` clean before the strike |
| 1 | ⛔ written form | a probe printing `(to-string :foo)`, `(str :foo)`, `(to-string :wat::core::i64)` | `":foo"` twice; `":wat::core::i64"` |
| 2 | ⛔ name | `(name :foo)`, `(name :wat::core::i64)` | `"foo"`, `"wat::core::i64"` |
| 3 | ⛔ both round-trips, both refusals | the tests | `from-string` refuses `"foo"`; `from-name` refuses `":foo"`; each names the input |
| 4 | ⛔ nothing changed meaning silently | step 2's diff alone, then the floor | step 2 is renames only; a grep for `keyword::to-string` / `from-string` after step 2 finds only step 3's new uses and their tests |
| 5 | the corpus agrees | the-little-wat `./run.sh` on the suites that call either verb (list them) and `tools/elf-run.sh` | green |
| 6 | the floor | `NEXTEST_TEST_THREADS=4 scripts/floor.sh` | green except F-197's two lint reds |

Runtime prediction: 2–4 hours, most of it the codemod's review and the floor.
