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
| 3 | `LeftistHeap` — the priority queue F-056 says is missing | correct, invariants checked at every node; **O(log n) confirmed** — 1.19× across three doublings (C-052) |
| 5 | `BatchedQueue` — two lists, amortized O(1) | correct; bound **exact** when enum-carried (8755 ns/op flat), **destroyed** when record-carried (158808 at n=4000) — **F-098** |
| 6 | `BankersQueue` — the bound that survives persistence | correct, and it **works**: one value / k futures falls as 1/k (508633 → 90185 ns/use, k = 10 → 100) where the eager queue is flat at ~3.0 ms — **C-055** |
| 7 | `RealTimeQueue` — **worst-case** O(1), not amortized | correct; worst single op **114 µs** against the banker's **3518 µs** spike — 30× (**C-056**) |
| 8 | `BankersDeque` — lazy rebuilding, **no cheap end** | queue *and* stack behaviour, balance invariant after every op, worst single op **84 µs** across both ends (**C-057**) |
| 9 | `BinaryRandomAccessList` — the structure *is* a binary number | every index reads back; **O(log n)** confirmed (+8600 ns/doubling) against the cons list's O(n) — 67× at n=3200. **No laziness, so no stand-in** (**C-058**) |
| 10 | `BootstrappedQueue` — a queue whose middle is a queue of lists | FIFO over 300; **wat takes polymorphic recursion**, datatype *and* mutually-recursive functions at differing instantiations (**C-059**) |
| 11 | `ImplicitQueue` — digits + polymorphic recursion + laziness | FIFO over 300; `Susp<Queue<Pair<A>>>` inside `Queue<A>` — the hardest type in the book — type-checks (**C-060**) |

## The carrier rule, found five times

`BQ`, `LCell`, `RTQ`, `DQ` and `IQ` are all **Impure enums**, and each arrived there
independently. A structure that holds a suspension cannot be a Pure enum (containment rule) and
must not be a record or struct (F-098 deep-copies user-enum fields). The Impure enum is the only
shape that satisfies both. Nothing documents this; it was derived here from two measurements and
then needed five times.

## What chapter 2 settled, for the rest of the port

`BASELINE.md` says a user `defn` call is 795 ns, a two-arm `match` 675 ns, an `i64::<` 360 ns. A
BST node visit is one of each, and chapter 2 measured **1922 ns per node** against a prediction of
1830–2190.

So **every structure in this book pays ~2 µs per node**, and each will be measured against a
native `PersistentMap`/`HashMap` competitor it cannot beat on constant factors. The port's value
is therefore in **correctness, expressiveness, and the asymptotic curves** — not in wall-clock
wins. Knowing that at chapter 2 rather than chapter 9 is itself a result.

## What chapter 5 found

The queue is a pair of lists, and the obvious way to hold a pair in wat is a `defrecord`. That
makes every operation O(n): **a record field holding a user enum value is deep-copied on
construction**, so each `snoc` copies both lists. The identical pair in an **enum variant** is
shared, and the amortized bound holds exactly.

Four other explanations were measured and eliminated first — `cons` is O(1), `rev` is O(n),
record *allocation* does not degrade with count, and removing the harness's own record traffic
made the curve worse. Native containers are unaffected: a `PersistentVector` field is O(1) either
way, which is why nothing in wat's own stdlib has tripped over this.

## The suspension stand-in

`okasaki/lib/susp.wat` is a memoizing one-shot suspension — Okasaki's `$`/`force` — built on a
`:wat::cache::Lru` at capacity 1. **It is a stand-in and the file says so**: an LRU is a bounded
*evicting* cache standing in for a never-evicting cell, a cached `force` costs 2× a function call,
capacity 0 panics, and `Lru` is thread-owned so the suspension cannot cross a thread. The real
thing is one word of state with `delay` and `force` — filed as **P-027**.

What it proved is worth the hack: chapter 6 restores the persistence bound that chapter 5 loses,
and the improvement grows with reuse exactly as theory says. So P-027 is not a speculative ask —
C-055 measures what it buys.

It does **not** change `:wat::stream::`. F-100 records that streams not memoizing is deliberate
(the Ruby `Enumerator` pattern: pull, process, discard, so a retained head cannot leak); this is
the other need, and it wants its own type.

## The queue progression, and why each chapter needs its own measurement

Okasaki's four queues each fix the previous one's weakness, and **no single metric sees all
three**:

| chapter | bound | what reveals it | result |
|---|---|---|---|
| 5 | amortized, **ephemeral only** | ns/op as n doubles | **flat**, 8755 ns/op |
| 6 | amortized, **persistent** | ns/use as k futures branch from one value | **falls as 1/k** |
| 7 | **worst-case** | the **max** single operation, not the average | **114 µs** vs 3518 µs |

| 8 | **both ends** bounded | the max op while alternating *both* ends | **84 µs** |

Chapter 7 is the one an average cannot show: the banker's queue pays its rotation all at once, a
3.5 ms spike inside an otherwise fast run, and the real-time queue spreads that work so no single
call is slow. Chapter 8 removes the last asymmetry — chapters 5–7 all have an easy direction,
because the rotation only ever moves rear into front, and a deque has none.

## Where the port stops, and why

**Chapter 6 for the amortized structures; chapter 7 needs more.** Not an abandonment — a result. Chapters 2, 3 and 5 are the ones whose bounds are
*structural*, and all three ported and held. Everything from chapter 6 on is Okasaki's Part II,
which is built on one mechanism: a suspension forced **at most once** and shared thereafter.

`probes/stream/memoization.wat` measures that mechanism directly: forcing one stream value three
times runs the suspension **three times** (F-100). With `lib/susp.wat` supplying it explicitly,
the **amortized** structures come back — chapter 6 is the proof.

Chapter 7 is now built too, on a lazy list whose *every cell* is a suspension (`lib/llist.wat`) —
one LRU per cons cell, which is where the stand-in's cost stops being a constant factor and
becomes the measurement. Its absolute numbers are mostly the hack; its **shape** — a bounded worst
case against a spike — is what a real `Susp<T>` would preserve.

The skeleton has therefore done its job: it is the spec for P-027, and PROVIDE.md now carries the
exact surface it exercises.

Chapter 7 is also where F-099 turned up: `stream::cons` is eager in its tail, so the natural
spelling of a self-referential stream recurses at construction, and wat **segfaults silently**
past ~110000 frames.

## Running

```
wat okasaki/ch02-persistent-set.wat
./run.sh okasaki
```
