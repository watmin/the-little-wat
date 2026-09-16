# SICP chapter 3, in wat

NEXT.md's third acceptance test. SICP's third chapter is about state, and its fifth section
about streams: the two things wat has strong opinions on. State lives on services here, and
streams are built on one special form.

Each chapter is checked against guile. `oracle/sicp/NAME.scm` is our own Scheme on that
section's topic — our code and our examples, not the book's text — and `tools/sicp-oracle.sh`
runs it and keeps every line it prints after `=> ` in `NAME.expected`. The wat chapter prints
the same values its own way, and `lib/check.wat` requires every one to match, in order.

## Results (2026-09-15, wat-rs `a3218644d`)

| chapter | results | what it is in wat |
|---|---|---|
| §3.1 local state | 20 | an account is a service holding one balance; two names for one account are two peers on one address; the accumulator and the call-counter are counters |
| §3.3 mutable data | 25 | a queue and a table are services holding the whole sequence and the whole table |
| §3.4 concurrency | 11 | four workers deposit into one account at once, through `:wat::bracket::map` on a thread locus, each dialling the account for itself |
| §3.5 streams | 9 | the stream operations written on `:wat::stream::lazy`: endless integers, a sieve of primes, fibs |

65 results, all matching guile. `./run.sh` runs every chapter.

## What the port showed

- **The book's mutable data is wat's services.** An account, a queue and a table are each a
  service holding the whole value, and the operations are its messages. wat has no `set!` and
  no mutable pairs, so the book's two-pointer queue (a `set-cdr!` on the last cell) has no
  direct counterpart; the Seasoned Schemer's Arena (C-016) is the other route.
- **A service is the serializer.** §3.4 worries about two processes reaching one balance at
  once, and wraps every access in a serializer. A wat service handles one message at a time, so
  the unserialized version the book warns about can't be written: nothing else can reach the
  balance. Four workers at once agree with what one worker sequentially would have produced.
- **An address carries its protocol in its type.** A worker that dials a service for itself
  needs the address declared `(:wat::kernel::Address :- [<Surface>::Op <Surface>::Reply])`.
  Declared as a bare `:wat::kernel::Address`, the connection speaks to nothing, and the error
  names only two unresolved type variables (F-052).
- **Streams are lazy but do not remember.** The chapter's values match guile's, but walking one
  stream value twice computes every element twice, where Scheme's `delay` computes it once
  (F-053). SICP's feedback definitions rest on that memory.
- **A definition can't name itself.** The book's `fibs` is defined in terms of itself; in wat
  the name inside its own body is a keyword literal, and the error is a type mismatch about a
  keyword (F-054). Here fibs is a function of its two seeds, and the Scheme oracle says it the
  same way, so the two agree on how, not only on what.

## Not ported

§4.1's metacircular evaluator. Make-a-Lisp (`mal/README.md`) already builds an interpreter in
wat with environments, closures, macros, tail calls and `try`, checked against mal's own tests,
so §4.1 would repeat that ground.

## Running

```
tools/sicp-oracle.sh ch35-streams        # guile writes oracle/sicp/ch35-streams.expected
wat sicp/ch35-streams.wat                # the chapter, checked against it
./run.sh                                 # every chapter in the repository
```
