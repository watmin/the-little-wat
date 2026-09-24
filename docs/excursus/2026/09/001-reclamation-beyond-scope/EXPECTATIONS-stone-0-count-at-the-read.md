# EXPECTATIONS — stone 0: a pointer read out of a container is counted at the read

Written BEFORE the strike, on `main`.

⚠ **BOOTSTRAP AND `mem.sh` WERE BOTH GREEN WITH THIS BUG IN THE TREE.** Neither can be the bar.
Rows 1 and 2 are the only oracles that have ever seen it.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ door 1 closed | `callrel-borrow.wat`, native vs interpreter | both `30\|240000\|3\|1\|30` |
| 2 | ⛔ door 2 closed | `own-shadow.wat`, native vs interpreter | both `30\|3\|30` |
| 3 | ⛔ the fix is at the READ | `git diff elf/compile.wat` | the change is at the read sites; nothing at the `conj` site, nothing at the call site (STOP-1, STOP-2) |
| 4 | the String form answered | the SCORE | door-1 and door-2 String analogs, both run both ways; agree, or a named third door |
| 5 | the in-place path still pays | `tools/mem.sh` §3, §5, §6 | `grow 2000000` still ~8 bytes/element; `concat x32000` still ~3 MB; `linear.wat` agrees. A rule that disabled in-place everywhere would pass rows 1-2 and fail here |
| 6 | the corpus is correct | `tools/elf-run.sh` | `0 divergences, 0 UNCOVERED` |
| 7 | it self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | the cost, named | the SCORE | user-mode instructions, best of 9, HEAD vs after: the corpus compile, `vecsum`, `rec`, `fib32`. STOP-3 above +5% |
| 9 | the emission moved | `tools/emitted.sh` | a non-zero, NAMED set of programs moved, each explainable as a pointer read |

## RUNTIME PREDICTION

**45–75 min.** Three emission sites and one increment copied from `:c::share`; the cost is the
String probe, the site census, and one bootstrap.

## TRAP DOORS

- **Row 5 is the one that catches an over-correction.** Sharing too much makes rows 1-2 pass
  trivially by disabling in-place conj altogether. `mem.sh` §3's `grow` is what in-place buys;
  if it goes quadratic again, the rule is too wide.
- **Guards.** A string literal's count lives in a read-only segment and writing it faults
  (`elf/src/strverbs.wat` found three segfaults this way). A unit enum variant is a small integer
  and `[rax-8]` on it is a read at a negative address. `:c::share` has both guards; the new
  increment needs both.
- **The monotone flag.** A count never comes down. Sharing at a read marks that element as shared
  forever, which is conservative and correct — but it means a program that reads an element and
  then legitimately owns it loses in-place for it. Row 8 is where that shows.
