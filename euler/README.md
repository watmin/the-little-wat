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
| p22-names-scores | 2000 names sorted, each scored by its letters and its position | 9, all matching Clojure | 1.17 s |

The names in `input/p22-names.txt` are **ours** — Project Euler's own `names.txt` is not
redistributable — generated deterministically from a fixed seed, in the same shape as the real
one: quoted, comma-separated, unsorted on disk.

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

## What names scores showed

p22 was chosen because it is made of the two things wat is worst at, and both showed.

- **Parsing, without a regex that can report what it matched.** The file is
  `"NAME","NAME",…`, and `:wat::regex::matches?` answers only a bool — `:wat::regex::find` does
  not exist (F-061). So the names come out by trimming the trailing newline, splitting on `","`
  and stripping each piece's quotes with `subs`. It works; it is the workaround the finding
  predicts, written out longhand.
- **Scoring, without character access.** A String has no characters (F-062), so every letter is
  a one-character `subs`. Getting a letter's *value* then needs a second lookup, and the choice
  between the two roads is measured (`probes/euler/letter-lookup-cost.wat`, 26000 letters — the
  size p22 walks):

  | letter value by | wall |
  |---|---|
  | scanning `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` with `subs` | 2751 ms |
  | a `PersistentMap` from letter to value, built once | 395 ms |

  **7.0×** — worth measuring, because reasoning gave the wrong number: "up to 26 `subs` calls
  per letter" suggests 26×, but the average letter sits about a third of the way into the
  alphabet and the map road still pays one `subs` to read the character at all. The solution
  takes the map road, so p22 finishes in 1.17 s; the naive road would have taken about ten
  seconds for the same nine answers.
- **Sorting Strings agrees with Clojure exactly** (`probes/euler/string-sort-order.wat`):
  `"Z" < "a"`, `"MARY" < "MARYANN"`, `"B" < "AA"` false, and an eight-name sort in the identical
  order, repeats surviving. Worth checking rather than assuming — every score is multiplied by
  its position, so a collation difference would have corrupted the total silently and given no
  hint where.

## Running

```
tools/euler-oracle.sh p16-p20-p25-digits   # Clojure writes the .expected
wat euler/p16-p20-p25-digits.wat           # the solution, checked against it
./run.sh                                   # every problem, with every chapter
```
