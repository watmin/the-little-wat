# Advent of Code, in wat

NEXT.md's fourth acceptance test, and the first one about ordinary work: read a file, parse it,
walk a grid, count things, and get a known right answer. It is also the first to care about
speed.

The puzzles and their inputs here are **ours**. Advent of Code's own texts and inputs are not
redistributable, so none are in this repository; what is kept is their shape — an input file,
and two answers from it. Each puzzle has a reference implementation in Clojure
(`oracle/aoc/NAME.clj`), run by `tools/aoc-oracle.sh`, whose answers the wat solution must
print, in order (`lib/check.wat`).

## Puzzles (2026-09-15, wat-rs `a3218644d`)

| puzzle | input | answers | wat | Clojure |
|---|---|---|---|---|
| day01 sonar | 2000 depth readings | increases, and increases of three-reading window sums | 1.08 s | 2.58 s |
| day02 smoke | a 100×100 grid of heights | risk of the low points, and steps downhill to the left | 1.80 s | 2.40 s |
| day03 words | 5000 words | how many are distinct, and how often the commonest occurs | 0.90 s | 2.50 s |

All six answers match. The times are whole runs: wat's startup is about 0.29 s of its own, and
the JVM's about 1.49 s of Clojure's.

## What the puzzles showed

- **Reading and parsing are fine.** `:wat::io::read-file`, `:wat::string::split` and
  `:wat::string::to-i64` do the job, and scanning a grid one character at a time is linear
  (wat has no character access, so each digit is a one-character `subs`: 10000 of them cost
  about 130 ms).
- **Indexing is constant; walking is not.** `nth` on a Vector costs about 12 µs whatever the
  index, but `rest` copies what is left, so the natural `(rest xs)` loop is quadratic — 20000
  elements take 4.9 s that way against 0.25 s by index (F-055). `conj` clones too (F-023), so
  building a Vector element by element is quadratic as well. Both puzzles here index.
- **Hash maps are comfortable.** 5000 words counted into a `HashMap`, then its keys read back,
  take 0.9 s in all, startup included — the one puzzle here faster than its Clojure reference.
- **Startup is small.** The thing NEXT.md expected to hurt — wat's startup on a per-puzzle
  program — is 0.29 s, a fifth of the JVM's.

## Running

```
tools/aoc-oracle.sh day01-sonar     # Clojure writes oracle/aoc/day01-sonar.expected
wat aoc/day01-sonar.wat             # the solution, checked against it
./run.sh                            # every puzzle, with every chapter
```
