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
| day04 binary | 1000 binary numbers | the product of the common-bit numbers, and of the two narrowed rows | 1.05 s | 2.50 s |
| day05 paths | a 60×60 grid of risks, then the same grown to 300×300 | the cheapest path across each | 20.6 s | 2.78 s |

All ten answers match. The times are whole runs: wat's startup is about 0.29 s of its own, and
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
- **A puzzle about bits has to be written without them.** wat has no and, or, xor, not or
  shift (F-035), so day04 builds each number by doubling and takes a complement as
  `(2^width - 1) - n`, where the Clojure reference says `bit-xor` and a shift. The answers
  match; the operations the puzzle is about are missing.
- **There is no ordered collection.** Dijkstra's frontier is a priority queue, and the Clojure
  reference keeps it in a sorted set. wat has no sorted set, sorted map, priority queue or heap
  (F-056), only `sort` over a whole collection, so day05 keeps a bucket per cost — which works
  only because every step costs between 1 and 9.
- **Building a map is where the time goes, and the obvious container is the wrong one.** day05
  first ran for 135 s — 45 times its reference — and nearly all of that was `hashmap::assoc` and
  `hashset::conj` over 90000 squares. `probes/aoc/map-insert-scaling.wat` shows why: 2000
  entries into a `HashMap` take 84 ms and 4000 take 341 ms — four times the time for twice the
  entries — and a `HashSet` behaves the same (45 ms, 163 ms). Reading is cheap and linear: 4000
  lookups take 41 ms. `PersistentMap` shares structure and stays linear instead (20 ms and
  40 ms, `probes/aoc/persistent-insert-scaling.wat`), and it is checked just as closely: an
  arity error and a wrong value type are both refused at startup
  (`probes/aoc/persistent-arity.wat`, `probes/aoc/persistent-valuetype.wat`). Moving the
  frontier onto it — a dozen lines — took day05 **from 135.1 s to 20.6 s**, same answers, same
  machine. wat has the right container; nothing points you to it (F-057).
- **Taking that advice runs into a wall.** The frontier is a map from a cost to the squares
  waiting at it, and `(:wat::core::PersistentMap :- [:wat::core::i64 (:wat::core::PersistentVector :- [:wat::core::i64])])`
  is refused — "bracketed type must be a type keyword" — where the `HashMap` spelling of the
  same nesting is accepted. Naming the inner type with a typealias works, and the error says
  nothing about that (F-058, `probes/aoc/persistent-nested-type*.wat`).
- **There is no persistent set.** `PersistentVector` and `PersistentMap` share structure; no set
  does, so the settled squares are a `PersistentMap` to `true` (F-057).
- **Startup is small.** The thing NEXT.md expected to hurt — wat's startup on a per-puzzle
  program — is 0.29 s, a fifth of the JVM's.

## Running

```
tools/aoc-oracle.sh day01-sonar     # Clojure writes oracle/aoc/day01-sonar.expected
wat aoc/day01-sonar.wat             # the solution, checked against it
./run.sh                            # every puzzle, with every chapter
```
