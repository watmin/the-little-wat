# Project Euler, in wat

NEXT.md's five acceptance tests are done, and this is the first suite chosen from the findings
rather than from the list: the ledger was thinnest on **arbitrary-precision integers**. F-047 —
a bigint computes but cannot be compared — came from a single Clojure Koans row and had never
been exercised by a real workload.

Project Euler's problems suit that: they are public, they have known right answers, they need no
vendored text, and the early ones lean hard on big integers. The problem statements are not
reproduced here; each wat file states its problems in its own words. The answers are the point,
and both implementations are our own.

The oracle is Clojure (`oracle/euler/NAME.clj`, run by `tools/euler-oracle.sh`), because
Clojure's bigints are the closest thing to what wat claims to have.

## Problems (2026-09-15, wat-rs `a3218644d`)

| file | problems | answers | wat |
|---|---|---|---|
| p16-p20-p25-digits | the digit sum of 2^1000; the digit sum of 100!; the first Fibonacci term with 1000 digits | 8, all matching Clojure | 0.67 s |

The time is the whole run, wat's 0.29 s of startup included — so the bigint arithmetic itself
costs a few hundred milliseconds to build 2^1000 by doubling, 100! by multiplication, and walk
Fibonacci to a thousand digits. The arithmetic is not the problem here; getting the digits out
of it is.

Each problem is checked beside a smaller twin (2^15, 10!, the first Fibonacci term with 3
digits) so a wrong answer says where it went wrong, and the two digit counts are checked
directly so the `N`-trimming below is not taken on trust.

## What the problems showed

- **A bigint has no `to-string`.** Every other scalar has one — `:wat::i64::to-string`,
  `:wat::f64::to-string` — and `:wat::bigint::to-string` is an unresolved reference at startup.
  The entire registered surface is six verbs: `+`, `-`, `*`, `/`, `to-f64`, `to-rational`. No
  comparison, no modulo, no power (F-060).
- **`to-f64` is the trap, because it succeeds.** It is what a user finds when `to-string` isn't
  there, and it silently loses the number: 2^1000 through f64 is 17 significant digits followed
  by 285 zeroes.
- **The digits come from the EDN writer.** `:wat::edn::write` renders a bigint in full — but
  with an `N` suffix, so 2^1000 is 303 characters of which 302 are digits, and a naive `length`
  or `subs` is off by one. It works, and it is not where anyone looks for a number's digits.
- **p25 never compares two bigints.** F-047 says `<` refuses them, so the question "has this
  Fibonacci term reached 1000 digits?" is asked of the digit *count*, which is an i64. That is
  also what Clojure's own `(count (str b))` does, so the two implementations agree by shape and
  not by coincidence.
- **No power, so 2^1000 is built by doubling** — the same shape day04 needed for bit operations,
  which wat also lacks (F-035).

## Running

```
tools/euler-oracle.sh p16-p20-p25-digits   # Clojure writes the .expected
wat euler/p16-p20-p25-digits.wat           # the solution, checked against it
./run.sh                                   # every problem, with every chapter
```
