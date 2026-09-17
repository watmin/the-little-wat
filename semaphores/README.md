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
| 3 | the barrier — hold all N until all N arrive | correct, but only as a **spin-wait** (C-054): 18 poll round-trips, because **wat cannot block a caller** (F-102) |

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

## What chapter 3 settled

A barrier holds every thread until all N arrive. wat **cannot block a caller**.
`:wat::service::Outcome` has five variants and two of them withhold the reply — `NoReply` and
`NoReplyAndArm` — so the language plainly intends a service to hold a request open. But nothing
can ever answer that caller: `Invocation`'s `conn-id` is "the name that outlives the round" and no
verb sends to one, and `Alarm` fires back into the *service*. Measured: a caller that receives
`NoReply` hangs forever. wat's own code never returns `NoReply` from a service impl.

So the barrier is a **poll** — arrive, then ask again until the count reaches N — which is exactly
what Downey introduces semaphores to eliminate. It works (8/8 released) and costs 18 round-trips,
~4 ms at F-051's 224 µs per message. That 18 is a *lower* bound: the poll count rises with real
concurrency, and F-094 measured this thread pool at 1.69×.

Chapters 4 onward (bounded buffer, readers-writers, dining philosophers) all need the same missing
primitive, so each would re-measure F-102 rather than find anything new.

## Running

```
wat semaphores/ch01-lost-update.wat
./run.sh semaphores
```
