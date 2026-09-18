# Advent of Code, in wat

NEXT.md's fourth acceptance test, and the first one about ordinary work: read a file, parse it,
walk a grid, count things, and get a known right answer. It is also the first to care about
speed.

The puzzles and their inputs here are **ours**. Advent of Code's own texts and inputs are not
redistributable, so none are in this repository; what is kept is their shape — an input file,
and two answers from it. Each puzzle has a reference implementation in Clojure
(`oracle/aoc/NAME.clj`), run by `tools/aoc-oracle.sh`, whose answers the wat solution must
print, in order (`lib/check.wat`).

## Puzzles (2026-09-18, wat-rs `a3218644d`)

| puzzle | input | answers | wat | Clojure |
|---|---|---|---|---|
| day01 sonar | 2000 depth readings | increases, and increases of three-reading window sums | 1.08 s | 2.58 s |
| day02 smoke | a 100×100 grid of heights | risk of the low points, and steps downhill to the left | 1.80 s | 2.40 s |
| day03 words | 5000 words | how many are distinct, and how often the commonest occurs | 0.90 s | 2.50 s |
| day04 binary | 1000 binary numbers | the product of the common-bit numbers, and of the two narrowed rows | 1.05 s | 2.50 s |
| day05 paths | a 60×60 grid of risks, then the same grown to 300×300 | the cheapest path across each | 20.6 s | 2.78 s |
| day06 adapters | 95 adapter joltages | the 1-jolt × 3-jolt product, and how many arrangements | 2.31 s | 1.02 s |
| day07 packets | one hex packet, nested | the version sum, and the value it computes | 0.58 s | 1.12 s |
| day08 brackets | 99 lines of brackets | the syntax-error score, and the median completion score | 0.63 s | 0.89 s |
| day09 basins | a 100×100 grid of heights | how many basins, and the product of the three largest | 2.08 s | 1.04 s |
| day10 growth | 300 timers | the population after 80 days, and after 500 | 0.56 s | 1.03 s |
| day11 maze | a 150×150 maze | the fewest steps across, and how many squares are reachable | 3.01 s | 1.17 s |
| day12 caves | 16 cave edges | how many paths run start to end, and with one small cave repeatable | 2.25 s | 1.24 s |
| day13 origami | 104 dots and 3 folds | dots after the first fold, then the picture — the answers are TEXT | 0.58 s | 1.03 s |
| day14 polymer | a template and 100 rules | commonest minus rarest after 10 steps, and after 40 | 0.82 s | 1.21 s |
| day15 bingo | a draw order and 20 boards | the first board to win, and the last | 1.44 s | 1.39 s |
| day16 assembly | a 12-instruction program | register a, and register a with c starting at 1 | 0.59 s | 1.08 s |
| day17 intervals | 615 blocked ranges | the lowest value not blocked, and how many are not | 0.67 s | 1.07 s |
| day18 snailfish | 20 nested-pair numbers | the magnitude of the sum, and the best pair sum | 13.0 s | 2.63 s |
| day19 passports | 300 key:value records | how many are complete, and how many are valid | 0.69 s | 1.17 s |
| day20 enhance | a 512-entry lookup and a 30×30 image | lit pixels after 2 steps, and after 12 | 10.1 s | 1.37 s |
| day21 dice | two starting positions | the deterministic game's answer, and the quantum one's | 8.89 s | 1.17 s |
| day22 cuboids | 60 on/off boxes | cubes lit in -50..50, and in the whole space | 0.75 s | 0.97 s |
| day23 scale | 20000 name-and-score rows | the top hundred scores' sum, and how many distinct names | 3.86 s | 0.99 s |
| day24 order | 29 dependencies | the alphabetically first valid order, and the longest chain | 0.54 s | 1.01 s |
| day25 cucumbers | a 24×24 grid of two herds | the first step on which nothing moves (one part, as day 25 always is) | 9.70 s | 1.06 s |

**Twenty-five days, 70 answers, all matching.** That is NEXT.md's §4 finished against its own
stated scope of "one year". The times are whole runs: wat's startup is about 0.29 s of its own,
and the JVM's about 1.49 s of Clojure's.

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
- **A stack is cheap and a queue is not — and the difference is the SIZE, not the operation.**
  day08 needs a stack: no `pop`, no `subvec`, `take`/`drop` answer a Stream (F-088), and no
  positional update (F-104), so a pop rebuilds. Its stack is at most nine deep and it costs
  nothing. day11 needs a queue, whose frontier reaches 129 — and the way out is not a workaround
  but a better shape: a level-synchronous BFS steps the whole frontier at once and never pops
  anything. F-116 is a finding about stacks that reach thousands; these two puzzles are the
  before and after.
- **The recursion the problem describes is the recursion you can write.** day09's flood fill is
  four recursive calls per cell, and the largest basin is 266 — well inside F-099's limit (fine
  to 100000 frames, SIGSEGV at 120000). The cost is not depth but PLUMBING: with no mutable set,
  `seen` must come back out of each of the four calls to go into the next, so the fill answers a
  record of (seen, count).
- **i64 traps; it does not wrap.** day10's population after 500 days is 2.6 × 10²¹, and the i64
  version dies with *"i64 overflow: … does not fit in 64 bits"*, naming the operation and both
  operands — better than C's silence and Java's wrap. The one complaint is that it locates at
  `wat/core.wat:66`, inside wat's own stdlib rather than at the line that overflowed (the
  F-006/F-008 family). The answer is therefore a bigint, and **F-060 has to be worked around a
  second time in a second suite**: a bigint has no `to-string`, so its digits come from `str`
  with a trailing `N` to strip — the identical helper `euler/p57-p71-rationals.wat` needed.
- **An answer can be a picture.** day13 folds a sheet of dots until it reads, and its second
  answer is six rows of `#` and `.` compared to Clojure's character for character. Every other
  puzzle answers with a number, and a number is much easier to get accidentally right.
- **`sort` takes no key, so the data has to be shaped to suit it.** day17 sorts 615 ranges by
  their low end, and there is no `sort-by` and no comparator argument — only `sort` over a whole
  collection. The route is to pack each pair into one integer, `lo * 1000000000 + hi`, which
  orders by `lo` then `hi`. That is also why the puzzle's space stops at 999999999 rather than
  2^32: `lo * 2^32 + hi` is 1.8 × 10¹⁹ and i64 stops at 9.2 × 10¹⁸. Choosing the universe to fit
  the packing is a decision a comparator would have made unnecessary.
- **No regex means splitting twice.** day15's boards are five rows of five columns aligned with
  spaces, so a run of spaces has to be split on one space with the empty fields dropped (F-061:
  the whole regex surface is `matches?`). The Clojure reference says `#"\s+"`.
- **The machine `lox/` spends seventeen chapters on is forty lines when it is read from text.**
  day16 is a four-register interpreter, and the differences are the interesting part: the
  dispatch is a `cond` over strings rather than an exhaustive `match`, so a typo in the input is
  a runtime error where a bad opcode in lox is unconstructible; the registers are a `defrecord`
  updated with `assoc` (F-113); and the ip is an ordinary loop argument, which is what C-098
  measured as the cheap shape.
- **Where wat is slowest is where it rebuilds.** Three puzzles take ten seconds or more, and all
  three do the same thing: day18 rebuilds a whole snailfish number on every explode and split
  (F-104, F-116 — no positional update and no `subvec`), day20 rebuilds a growing image a
  character at a time, and day21 walks 16172 memoised states. The Clojure references take one to
  three seconds. day05's 20.6 s is still the slowest, and its cause was the same: a container
  copying where one that shares was available (F-057).
- **Memoisation needs a size nobody knows.** day06's recurrence needed a memo of capacity 3, so
  P-028's ask was narrowed to "a cell whose size the caller does not have to know". day21 is the
  case where the caller genuinely cannot: 16172 states is a property of the search, not of the
  input. The capacity has to be a bound on the state space — 10 × 21 × 10 × 21 — and getting it
  wrong fails silently, by recomputing.
- **Size is fine; rebuilding is what costs.** day23 sorts 20000 numbers and puts 20000 names in a
  `PersistentMap` in 3.9 s all told, so neither `sort` nor a sharing map has a scaling problem.
  The four slowest puzzles are all rebuilds: day05 (20.6 s, a copying container — fixed to 20.6 s
  from 135 s by changing it), day18 (13.0 s, a whole number copied per rewrite), day20 (10.1 s, a
  growing image built a character at a time) and day25 (9.7 s, two grids rebuilt per step, 85
  steps). The Clojure references take about a second each. Nothing here is a wat defect; it is
  what immutability costs when the rebuild is per-element rather than per-structure, and F-104
  and F-116 are the two verbs that would change it.
- **Immutability is occasionally the point rather than the price.** day25's two herds move
  SIMULTANEOUSLY, which a mutable grid has to be careful about — move one cucumber and the next
  sees the new state. Here there is no choice to get wrong: each step reads the old grid and
  builds a new one, and a square decides its own contents from three reads of something that
  cannot change underneath. The rebuild F-104 forces IS the algorithm.
- **Startup is small.** The thing NEXT.md expected to hurt — wat's startup on a per-puzzle
  program — is 0.29 s, a fifth of the JVM's.

## Running

```
tools/aoc-oracle.sh day01-sonar     # Clojure writes oracle/aoc/day01-sonar.expected
wat aoc/day01-sonar.wat             # the solution, checked against it
./run.sh                            # every puzzle, with every chapter
```
