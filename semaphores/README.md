# Downey, *The Little Book of Semaphores* — NEXT.md §11

Chosen for what it stresses: the **concurrency runtime**, after F-094 measured `bracket::map`'s
thread pool at 29% of what the same machine reaches with OS processes. **No networking** — the
builder's call, 2026-09-16: it is simulated via IPC anyway (processes over unnamed Unix domain
sockets, threads over crossbeam-style channels), so the puzzles run against `:wat::spawn::`,
`:wat::bracket::` and `:wat::service::` directly.

The book is a rare **self-oracling** corpus: every puzzle has a known-correct answer *and* named
failure modes — deadlock, starvation, lost update — so a wrong implementation fails in a way the
book already describes.

## Chapters (2026-09-16, wat-rs `a3218644d`)

| chapter | puzzle | result |
|---|---|---|
| 1 | the lost update — the hazard the whole book removes | **unrepresentable** in wat (C-053); the address plumbing to get there is undocumented (F-101) |

## What chapter 1 settled

Downey's book exists because read-modify-write on shared state is not atomic. wat's answer is
structural (`docs/ZERO-MUTEX.md`): state lives in a service and the actor's serialisation *is* the
mutex. Eight workers on a real thread pool, 200 increments each, into a service whose `bump` is
written as three deliberate steps — **1600/1600 on five consecutive runs**.

So the first several puzzles have no wat form, and that is a result about the design rather than a
gap in the port. What the chapter *did* cost was F-101: handing eight workers one service address
means writing

```wat
(:wat::kernel::Address :- [(:sem::Counter::Op :- []) (:sem::Counter::Reply :- []) :T])
```

where the two inner types are minted by `defsurface` and none of the three appears in any
user-facing page. The naming rule came from `wat/service.wat:1032-1051`.

## Running

```
wat semaphores/ch01-lost-update.wat
./run.sh semaphores
```
