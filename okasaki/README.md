# Okasaki, *Purely Functional Data Structures* — NEXT.md §10

Chosen for what it stresses rather than for being a book: the **container** story, which is where
this repository's measurements already point. F-057 (copying vs sharing containers), F-055 (`rest`
clones a Vector, so walking one is quadratic), F-023 (`conj` clones) and the missing persistent
set are all open, and this is the corpus that exercises them.

Every structure is checked for **correctness against a model first**. A timing comparison between
a wrong structure and a right one is worth nothing.

## Chapters (2026-09-16, wat-rs `a3218644d`)

| chapter | structure | result |
|---|---|---|
| 2 | `UnbalancedSet` — a persistent set as a BST | correct (C-051); **40× slower than the workaround it would replace** (F-097) |

## What chapter 2 settled, for the rest of the port

`BASELINE.md` says a user `defn` call is 795 ns, a two-arm `match` 675 ns, an `i64::<` 360 ns. A
BST node visit is one of each, and chapter 2 measured **1922 ns per node** against a prediction of
1830–2190.

So **every structure in this book pays ~2 µs per node**, and each will be measured against a
native `PersistentMap`/`HashMap` competitor it cannot beat on constant factors. The port's value
is therefore in **correctness, expressiveness, and the asymptotic curves** — not in wall-clock
wins. Knowing that at chapter 2 rather than chapter 9 is itself a result.

## Running

```
wat okasaki/ch02-persistent-set.wat
./run.sh okasaki
```
