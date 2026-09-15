# Make-a-Lisp, in wat

This is NEXT.md's second acceptance test: can wat build a language? Make-a-Lisp
(kanaka/mal) builds a Lisp interpreter in 11 steps. Each step ships its own tests, which
mal's runner (`runtest.py`) drives through the implementation's REPL. Here, mal's runner and
tests (`vendor/mal`, MPL 2.0) run unmodified against a wat implementation written from the
process guide.

## Results (2026-09-15, wat-rs `a3218644d`)

| step | passing | optional tests not passing |
|---|---|---|
| 0 repl | 24 | |
| 1 read, print | 121 | |
| 2 eval | 15 | |
| 3 env | 33 | 5 (DEBUG-EVAL tracing) |
| 4 if, fn*, do | 199 | |
| 5 tail calls | 8 | |
| 6 files, atoms | 71 | |
| 7 quote | 115 | 9 (DEBUG-EVAL tracing) |
| 8 macros | 58 | 3 (DEBUG-EVAL tracing) |
| 9 try | 173 | |
| A the rest | 92 | 21 (metadata) |

In total, 909 tests pass, and every hard test passes. Of the 38 optional tests that fail, 17
check DEBUG-EVAL tracing, which isn't implemented, and 21 check metadata, which isn't kept:
`with-meta` hands back its value unchanged. mal's self-hosting test, which runs mal written in
mal on top of this one, was not attempted.

## The shape

- **Values are data** (`lib/types.wat`):
  - a builtin is its name;
  - a closure or a macro is its parameters, its body and its environment's id;
  - an atom is its id.

  So no wat function is ever inside a value.
- **mal's state lives on a service** (`lib/env.wat`). The environments and the atoms are held
  by a store service, as wat's doctrine keeps state. A closure holds its environment by id,
  so it sees what is defined there later. A lookup walks the frames inside the service, one
  message per lookup. mal's values are declared inside the store's protocol, because a
  service's surface must own every type its messages carry.
- **mal's tail calls are wat's own.** Step 5 is step 4, unchanged.
- **A thrown value is an evaluation's Err,** as every error already is, so `try*` is a match
  on it.
- **One program per step** (`stepN_*.wat`), as mal's layout has it. The reader, printer,
  store and core builtins are shared (`lib/`).

## What it cost

- **The shim.** A wat program can't be a terminal program. Its stdout is EDN only (F-049),
  and its stdin comes by EDN frame (F-050). So `tools/mal-shim.py` stands between mal's runner
  and the program: each line crosses as one EDN string, and `:mal/done` ends each form's
  output.
- **Speed.** A message to the store costs about 224 µs (F-051), and a mal call is about a
  dozen of them, so step 5's 10000-deep recursions take about a minute. They need runtest's
  `--test-timeout` raised.
- **One arm per variant, everywhere.** Every match on a value names all 14 variants, so adding
  one (closure, atom, macro) touched about twenty places (Friction, FINDINGS).

## Running

```
tools/mal-all.sh                    # every step; one line each; exit 0 = every hard test passes
tools/mal-test.sh step4_if_fn_do    # one step (extra arguments go to runtest.py)
```
