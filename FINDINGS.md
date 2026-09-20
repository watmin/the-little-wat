# Findings

Every place wat fell short of what a chapter needs, and every place it didn't.

## Status (2026-09-15, wat-rs `a3218644d`)

| Book | Chapters | State |
|---|---|---|
| The Little Schemer | 10 / 10 | all pass (`./run.sh`), including the ch 10 interpreter running the untyped Y |
| The Seasoned Schemer | 10 / 10 | all pass. letrec via Y (C-012); letcc via `Result/try`, with the abandoned work measured (C-013, C-015); `set!` on Cell services (C-014); mutable, shared and cyclic lists on an Arena (C-016); generators as lazy streams (C-017); the ch 20 interpreter with a store and escaping letcc (C-018). Refused by design: Y-bang (R-002) and re-entrant continuations (R-003) |
| The Reasoned Schemer | 10 / 10 | all pass, 201 checks (C-020). The book's surface (`run`, `fresh`, `conde`, `defrel`, `conda`, `condu`) works as wat macros (C-019). From ch 3 on, every expected value comes from `oracle/`, a Clojure transliteration of the book's engine, so answer order is checked too; ch 1–2 agree with it on all 51 queries. Speed: about 100 times slower than the JVM on ch 8's queries, and about 430 times slower on the deepest searches (F-023, C-020) |
| The Little MLer | 10 / 10 | all pass, 139 checks. Datatypes are enums (generic, recursive and mutually recursive, C-021), constructors are function values (C-022), exceptions are Results, and functors are dictionaries (C-023). Every match names every variant, and the book shows what that costs: tuple matches (F-027) and nested coverage (F-028). F-029 blocks functors over surfaces; F-030, a newtype, panics when printed |
| The Little Prover | 9 / 9 | all 49 transcript entries match guile's J-Bob (C-024). J-Bob is translated into wat by a wat program (`tools/jbob2wat.wat`) and checked against guile running the vendored original. Chapters take 2 to 58 s. F-031: `length` on a String passes the checker |
| The Little Typer | 16 / 16 | all pass. wat-Pie (`lib/pie.wat`), a dependent type checker written in wat, matches Racket's Pie on all 290 printed results and refuses all 108 forms Pie refuses (C-025, C-026). F-033: taking a WatAST apart copies it, which cost ch 14 43 s until definitions were bound as syntax (2 s). A handled thread death still prints to stderr (Friction) |
| The Little Learner | 22 / 22 | all pass: chapters 1–15 and Interludes I–VII. All 194 values match malt, the book's own library, exactly: equal f64s, no tolerance (C-027). That includes 1000-step descents, adam, and the book's own Iris run. Randomness is malt's draws replayed through a counter service, and hyperparameters are a value (C-028). Not ported: ch 0 (Scheme), the appendices; ch 15's 20000-revision training (speed: the Iris run takes 236 s against malt's 2.3 s). F-034–F-037 |
| A Little Java, A Few Patterns | 10 / 10 | all pass: all 130 results match Java's (C-029). The oracle is Java itself (JDK 27): our own Java per chapter, whose toStrings print S-expressions (`tools/java-oracle.sh`). Java's classes become wat enums, and methods become functions with an arm per variant. Java's interfaces become surfaces and its visitors structs that `extend-type` them. Its mutable fields become services. F-038: a builtin verb used as a function value passes the checker in two places of three. F-039: a partial `extend-type` passes the checker. F-040: the containment error for a defstruct in a Pure enum never names `defrecord`. Surfaces have no defaults or extension, so a Java subclass restates its parent, and a Peer surface must own every datatype its messages carry (Friction) |
| The Clojure Koans (NEXT.md §1) | 27 topics, 229 rows | our own filled-in koans, each true in Clojure. Ported with only the namespace changed, 29 run (C-030). Written the wat way, 163 more run (`koans/idiom/`, under `./run.sh`); 17 have no route today, and 20 are refused by design. F-014 measured: 38 of the 51 rows that die at runtime in the Clojure spelling are refused at startup in the keyword spelling. 74 Clojure core names are missing (the table). F-041–F-048 |
| Make-a-Lisp (NEXT.md §2) | 11 / 11 steps | all pass mal's own tests: 909 pass, every hard one (C-032); 38 optional ones don't (DEBUG-EVAL tracing, metadata). mal's own runner and tests (`vendor/mal`, MPL 2.0, unmodified) drive the wat implementation (`mal/`) through a shim, because a wat program can't be a terminal program: its stdout is EDN only (F-049), and its stdin comes by EDN frame (F-050). mal's values are pure data, and its environments and atoms live on a store service, where a message costs about 224 µs (F-051) |
| SICP (NEXT.md §3) | **COMPLETE — all 5 chapters**, 354 results | all pass (`sicp/README.md`). Our own Scheme on each section's topic is the oracle, run by guile (`tools/sicp-oracle.sh`), and every printed result must match. §3.1 local state (20): an account as a service, two access points as two peers on one address. §3.3 mutable data (25): a queue and a table as services, since wat has no mutable pairs to build the book's two-pointer queue from (the Arena, C-016, is the other route). §3.4 concurrency (11): four workers on one account at once through `:wat::bracket::map`, where the service is the serializer, so the book's unserialized bug can't be written. §3.5 streams (9): the stream operations written on `:wat::stream::lazy`. Not ported: §4.1's evaluator, which Make-a-Lisp already covers. F-052, F-053 (a forced stream doesn't remember), F-054 (a definition can't name itself) |
| Advent of Code (NEXT.md §4, **COMPLETE — 25 days**) | 25 puzzles, 70 answers | all matching (`aoc/README.md`). The puzzles and their inputs are ours, in Advent of Code's shape — its own texts and inputs are not redistributable — each with a Clojure reference implementation (`tools/aoc-oracle.sh`) whose answers the wat solution must print. day01 sonar (2000 readings), day02 smoke (a 100×100 grid, read one character at a time), day03 words (5000 words in a hash map), day04 binary (the bits of 1000 numbers, as arithmetic: F-035), day05 paths (Dijkstra over 3600 then 90000 squares, as a bucket queue: F-056). Times: wat 1.1 s, 1.8 s, 0.9 s, 1.0 s, 20.6 s against Clojure's 2.6 s, 2.4 s, 2.5 s, 2.5 s, 2.8 s. The first four are in Clojure's range with a fifth of its startup. The fifth is nearly all map and set updates, and took 135 s until its frontier moved from `HashMap`/`HashSet` to `PersistentMap`, which shares structure where those copy — a dozen lines, 6.5× (F-057), and the conversion ran into F-058. F-055, F-056, F-057, F-058. **C-114 finishes it (2026-09-18):** eighteen more puzzles, each aimed at something the first seven did not reach. The results that generalise: **size is fine and rebuilding is what costs** (20000 numbers sorted and 20000 names mapped in 3.9 s, against four puzzles over 9 s that all rebuild per element); **i64 traps rather than wrapping**, with the operation and both operands named, which sent day10's answer to bigint and F-060's missing `to-string` to a second suite; **F-116's missing `pop` is a question of SIZE** — day08's nine-deep stack costs nothing and day11's queue is avoided entirely by stepping a BFS level at a time; **F-061 is the most expensive single gap for ordinary work** — day19 is 150 lines of wat against 60 of Clojure for seven validation rules, all of them one-line regular expressions; and **`sort` takes no key**, which day17 works around by packing a pair into one i64 and day23 by sorting 20000 items to look at 100. day25 is the other direction: its two herds move simultaneously, and the rebuild F-104 forces IS the algorithm |
| PAIP (NEXT.md §5, **COMPLETE — 20 of 20 portable chapters**) | ch 2, 4-9, 11-23 — 380 results | unification ports to quoted data with no term language at all, and passed first run (C-033, `paip/README.md`). Our own Scheme is the oracle, run by guile (`tools/paip-oracle.sh`); Norvig's code is not read or copied. A pattern is an ordinary quoted form and a variable is the symbol `?x`, so `paip/lib/unify.wat` walks `:wat::WatAST` itself: `ast-kind` gates, `ast-name` reads a symbol's text (it raises on anything else, so the kind test must come first), `ast->children` decomposes, `with-children` rebuilds, `=` is structural, and `ast->source` prints exactly as guile does. The substitution maps a variable's name — not its node — to a term, and is a `PersistentMap` (F-057). Failure is `Option.None`. Chapter 12's Prolog then runs on quoted clauses too (C-034, 33 results): a clause is a quoted list, the database is a value rather than a service (nothing mutates, and F-051 charges 224 µs a message), backtracking is eager (F-053 means a stream would not memoise), and a clause's variables are renamed apart with `symbol-node` through a threaded counter, since wat has no mutable variable. Cyclic mutual recursion is accepted. **F-059 is where quoted data runs out:** PAIP's membership clauses carry a list with a variable tail, and wat's reader has no dotted pair — `(?i . ?rest)` reads as three children with a symbol named `.` in the middle, then prints back unchanged. Those clauses cannot be written, in either implementation. That is NEXT.md §5's answer: quoted data carries symbolic pattern matching as far as the improper list, and no further |
| Project Euler (after NEXT.md) | 6 problems, 30 answers | p16, p20 and p25 — the digit sum of 2^1000, the digit sum of 100!, and the first Fibonacci term with 1000 digits. Chosen to press where the ledger was thinnest: F-047 (a bigint computes but cannot be compared) had been found in a single koan row and never exercised by a workload. The oracle is our own Clojure (`tools/euler-oracle.sh`); Project Euler's problem statements are not reproduced. **F-060:** a bigint has no `to-string` where every other scalar does, and its whole surface is six verbs (`+ - * /`, `to-f64`, `to-rational`) — no comparison, no modulo. Its digits come only from `:wat::edn::write`, which appends `N`, so `length` is digits + 1; and `to-f64`, the thing a user finds instead, silently loses the number (2^1000 becomes 17 significant digits and 285 zeroes). p25 never compares two bigints: it asks whether the digit count has reached 1000, which is an i64 comparison. Then p22 names scores (C-035) adds the text half, chosen because it is made of the two things wat is worst at: **F-061**, the whole regex surface is `matches?` answering a bool — a capture group compiles and what it matched can never be read, though wat-rs depends on the entire `regex` crate — so the file is parsed by trim, split and `subs`; and **F-062**, a String has no characters, no `index-of`, `replace`, `split-lines` or `blank?`, `reverse` refuses it and `split` refuses `""`, so every letter is a one-character `subs` at about 16.7 µs. Scoring by scanning the alphabet costs 2751 ms against 395 ms through a `PersistentMap` (7.0×, measured — not the 26× the reasoning suggested). String sort order matches Clojure exactly, checked rather than assumed. F-047, F-060, F-061, F-062 |
| The rete (after NEXT.md) | 2 cases, 16 results | wat ships a production rule engine and nothing here had touched it — nor had any documentation (F-065: zero word-boundary hits in USER-GUIDE, CHEATSHEET, CLOJURE-ROSETTA or the docs README, against 134 verbs and 4154 lines of wat). `rete/r01-chaining.wat` puts the same supply-chain rules to wat and to clara-rules (`tools/rete-oracle.sh`) and all 8 results agree (C-036): a guarded join, forward chaining through a derived fact, negation over that derived fact, existence that doesn't collapse into a join, and an accumulator over derived facts. The engine is correct; only the documentation is missing. `r02-retraction.wat` then asks what r01 left out — what happens to a derived fact when its support goes — and seven of eight scenarios agree with clara, including transitive retraction and re-insertion. The eighth is **F-066**: two supports deriving the identical fact leave wat holding one and clara holding two, because wat's closure is a set of facts and clara's memory is a bag of derivations; each engine's accumulator then follows its own model. Both fire the rule twice, so it is a collapse, not a missing join. Then **F-067**, found by putting one session through wat's own two implementations rather than through clara: `fire-rules$oracle` — which wat-rs calls "the SPEC / differential oracle" — and the public `fire-fixpoint` both keep a stale `0` from the accumulator's empty first pass beside the correct answer, where `fire-rules` keeps only the answer. Bare folds (`count`, `sum`) leak; Option folds (`min`, `max`) don't, because `None` is dropped rather than asserted |
| SQLite (after NEXT.md) | 1 case, 17 results | wat ships `:wat::sqlite::` — open / open-readonly / execute-ddl / execute / select / begin / commit / pragma — and nothing here had touched it. `sqlite/s01-crud.wat` puts the same schema and queries to wat and to the sqlite3 CLI (`tools/sqlite-oracle.sh`), the same engine wat binds, and all 17 agree (C-037): bound parameters, NULL through `Cell.Nil`, aggregates over a nullable column, GROUP BY with NULL as its own group, update, delete, ordering, and a zero-row result. **Two things it does better than the language around it:** the read-only connection is capability-honest and a write through one is refused *at startup*, not by the database; and failures arrive as `Result` values (`Error.Transient/Constraint/Fatal`), so a program survives four of them without the thread-spawning catch F-063 priced at 1.3 ms. **F-068:** `begin` and `commit` exist, `rollback` does not, on a surface explicitly closed to additions — though raw `execute conn "ROLLBACK"` works and does undo the write. Rows are positional: `select` answers vectors of `Cell`s with no column names. F-034 confirmed again: a `REAL` holding 2.0 renders as `2` |
| The Store contract (after NEXT.md) | 1 case, 5 results | wat ships a backend-agnostic storage contract, `:wat::query::Store` (DynamoDB-shaped pk/sk/data with named GSIs), and **two** services satisfying it — `mem-store` and `sqlite-store`. `wat/query/mem.wat` says the in-memory one exists partly to be "differential-tested against", so the backends check each other and no external oracle is needed. `store/q01-two-backends.wat` drives ensure-schema, a put, three keyset pages and a GSI scan through one `Store`-typed function against both peers: all five results identical (C-038). wat-rs asserts the same inside its own harness; the addition here is that it holds for an **ordinary program**, with no deftest or fixture loader. A dialed peer really is the surface — not F-029, since that surface is non-parametric. **F-069:** a consumer writes more outcome arms than logic — 56 of 182 lines are match arms, and wat-rs's own fixture lands at exactly 182 too, with a 529-character `connect` line because F-052 forbids factoring the dial into a helper |
| wat's own documentation (probes only) | 626 examples executed | wat reflects every `@example` in its source into typed records and ships a runner for them, so the documentation is executable. The runner is masked: one unguarded comparison raises and hides every other example, which wat-rs records in a NOTE with three refuted fixes and an `#[ignore]`d gate saying "FIVE failures, ONE cause". Unmasked by wrapping each verdict in `:wat::test::run-thread`, the count is **134 of 485 runnable** (F-070): 44 stale constructor spellings, 23 stale variant spellings, the builder's 5 angle-bracket cases reproduced exactly, 19 eval-context limits, 6 maskers, 17 genuine mismatches, 20 other. The NOTE's open question — whether the runner can guard its own comparison — is answered yes: `run-thread` exists and `wat/test.wat` loads at #34 against `wat/doctest.wat` at #38; it looks absent only because F-063 puts wat's one general catch in the test namespace. Its picture is also incomplete: `eval-ast!` raises past its own Result too. Its unidentified "instance 2" is `:wat::core::Option/expect`. F-071: the match-arm refusal names `<enum>::<Variant>` as the remedy — the spelling it just refused |
| The holon algebra (probes only) | 12 VSA laws, 3 probes | `:wat::holon::` is wat's largest surface — 94 verbs — and the layer wat exists for. It needs no oracle: a vector-symbolic architecture has laws. Ternary vectors, d = 10000. **Eleven of twelve hold exactly** (C-039): identity, quasi-orthogonality, bind commutes, bind makes a new vector, bundle stays similar to its parts, bundle commutes, permute destroys similarity, permute inverts, permute distributes over bind. **F-072:** the twelfth — the self-inverse axiom — holds only to cosine 0.818, stable at 0.815 ± 0.003 over six pairs, and compounds multiplicatively (0.667 at two rounds, 0.543 at three), so nesting is bounded at about three levels before dropping under the 0.49 that `presence?` requires. There is no unbind verb, so binding twice is the only way back, and nothing documents any of it. A codebook lookup still wins by two orders of magnitude. **F-073:** `coincident?` is documented as "whether a's cosine clears the coincident floor" but implemented as `(1 - cosine) < floor` — the opposite test; the floor is a tolerance below identity (0.99), not a similarity threshold (0.01). Confirmed three times over by `coincident-explain`'s own `min-sigma-to-pass`. **F-074:** `presence?` refuses the raw `Vector`s that `vector-bind`/`bundle`/`permute` produce, so the looser recognition test is unreachable from the raw path — exactly where F-072 puts you |
| The formatter (probes only) | 62 stdlib files | `:wat::fmt::` is grep facts + 54 rete rules + a dumb emitter, with the rules deliberately unbaked in `wat-scripts/fmt/rules/`. **Idempotent on all 62 files of wat's own stdlib, 0 failures** (C-040) — the right property, and it holds. It is not a pure layout tool: formatting changes the parse of 14 files, and every one of those diffs is purely the **param-spec migration** (107 `[]` insertions, zero deletions) — deliberate, since enums will require a param-spec, and a useful census of what is still on the bare spelling. **F-075:** it runs at about 10 KB/s with an ~800 ms fixed floor (two files of 2 KB and 5 KB both took 812 ms), so `service.wat` takes 22.9 s and the cheapest possible format costs 0.8 s. Linear, not quadratic — the cost is honest, just high; caching the compiled rule network across formats would pay the floor once per process |
| The docs, compiled (tools only) | 203 verbs verified | **F-087:** every `:wat::` verb the four user-facing documents name, handed to the compiler one at a time. **68 MISSING, 19 RETIRED, 116 EXISTS, less 6 the docs name only to disclaim — 81 of 203 rejected (40%).** **49 of 159 fenced code blocks (30%)** carry at least one, and 26 use the retired `:wat::core::define`. The material is primary, not cautionary: §4 "Writing functions" is headed ``### `define` — named registration``; the "slightly richer first program" is refused for `-> :()`; a reference table at L3703 gives signatures for six `:wat::stream::` verbs where the namespace has four, none of them those. The refusals are excellent — almost all name their replacement and cite the arc — so the substrate holds the mapping the prose lacks, which is F-076's shape at forty times the scale |
| Semaphores (NEXT §11, **COMPLETE — ch 1-7**) | ch 1-7 | **C-053, narrowed by C-094:** wat's zero-mutex claim holds **within a service round**. 8 workers on a real thread pool, 200 increments each into one counter service whose `bump` is written as three deliberate steps: **1600/1600 on five consecutive runs**. **C-094 then broke that framing:** split the same increment across TWO rounds (`peek` then `set`) and **93/400, 94/400, 96/400, 84/400** — about 77% of the updates lost, reproducibly, where a semaphore at 1 gives 400/400 every time. A service round is atomic; a program is not, and Downey's book has a direct wat form after all. **F-101:** but handing the workers that one address required naming a three-parameter `Address` and two `defsurface`-generated types, none of which appears in any user-facing page; the naming rule came from the macro's internals. **F-102:** and wat cannot block a caller at all — `Outcome.NoReply` withholds a reply and **nothing can ever release that caller** (measured: hangs forever). Nothing sends to a held `conn-id`; `Alarm` fires back into the service. wat's own code never returns `NoReply` from an impl. **C-054:** so ch3's barrier is a **spin** — correct, 8/8 released, at a cost of **18 poll round-trips** (~4 ms at F-051's 224 µs/message), and 18 is a *lower* bound because F-094's thread pool barely parallelises |
| Crafting Interpreters Part II (NEXT §12, **COMPLETE — ch 14-29**) | ch 14-30, 17 programs | **C-098:** a byte-code VM, built to answer the question §12 was queued for. The same chunk and the same `exec`, three loop shapes, 4002 instructions, min of 5, both orderings: **`step : State -> State` costs ~2.3-2.5x** the threaded loop (F-105 measured 1.9x on EOPL's toy — a real VM is worse), and **hoisting the chunk's arrays out of the loop saves a further ~30%**, because BASELINE's 6130 ns `defrecord` accessor is paid per instruction (F-096). The two **compound to 3-4x**. Chapter 14's layout diverges once and deliberately: an opcode is an enum carrying its operand, so the book's 7-instruction 10-byte chunk is 7 instructions and 7 elements here, and an offset counts instructions rather than bytes. **C-099:** chapter 16's scanner — 38 token kinds, all 38 asserted produced, 31 checks — makes the same point in the innermost loop a compiler has: `advance` is a five-field `defrecord` rebuilt **per character**, and the same scanner with the record moved to **per token** produces identical tokens at **~2.5x less**. Three independent workloads now agree (F-105 1.9x, C-098 2.3-2.5x, this ~2.5x). Scanning on demand does work — 8 tokens cost under a tenth of the file — but **F-062 turns structural here**: `subs` is O(i) and the only character access, `split` refuses an empty separator at run time so a String cannot become a `Vector` of characters, and `:wat::core::char` is a type with no route to it. So chapter 15's 30% hoist has no equivalent: there is nothing indexable to hoist into. **F-112** raised on the way. **C-100:** chapter 17's single-pass Pratt compiler, 35 checks green on the first run, and the check worth having — the chunk chapter 14 wrote out **by hand** because there was no compiler yet is the chunk chapter 17 **compiles from source**, identical opcodes and pool, and chapter 15's VM gives chapter 15's answer. Four chapters checked against each other rather than against a description of themselves. Precedence, left associativity, unary binding, grouping emitting nothing, seven error messages with their lines, and panic mode reporting `+ + +` exactly once. Nystrom's rule table of function pointers was **built in a probe** so that not using it is a choice: a `defstruct` row carries both closures with accessors, an Impure enum row costs a `match` per field, and a `defrecord` row is refused outright — **F-114** on how that refusal is worded and where it points. **C-101:** chapter 18 gives Lox its types — a tagged union is a `defenum`, and the chapter's whole second half (the `IS_NUMBER`/`AS_NUMBER` macros that make C's union safe) has nothing to port. 49 checks green first run. Two results worth keeping: `valuesEqual` is just `(= a b)` — **F-019's headline reads wider than the finding**, and `probes/lox/value-equality.wat` is the positive control, including that an `f64` payload compares as an `f64` so `Num(NaN) = Num(NaN)` is false; and **Nystrom's acknowledged NaN bug reproduces** — `<=` compiles as `!(a > b)`, so `NaN <= NaN` answers **true** where IEEE says false. The cost is the runtime error: no early return and F-063's thread-spawning catch, so every instruction answers `Step.Next` or `Step.Fail` and the loop matches on it, one match per instruction in C-098's hot loop. **C-102:** chapter 19's strings port to one enum variant and one `string::concat`, because `Obj`, `ObjString`, `allocateObject`, `vm.objects` and `freeObjects` are C's memory management and wat owns the heap; the language half is checked in full (31 checks). Two debts: chapter 26's collector will have to build its own heap, and `==` on strings is already structural. **C-103 corrects this repository's own chapter table** — chapter 20 was recorded as *no portable content* and half of that was wrong. The hash table is not worth rewriting, but **interning** is a language decision, and its cost claim is about a C program. Measured: comparing two 100 000-character equal strings costs about **a quarter more** than comparing two integers, a few percent more at 1 000, and **nothing at all at 10**, because the call costs ~7 µs before it looks at a character. A control (strings differing at character 0) stays flat, so the walk is real and simply dwarfed. Third chapter running to find that an interpreter charges for the NUMBER of operations, not what each touches — which is what NaN boxing and cache-line layout are also aimed past. **C-104:** chapter 21 makes it a language — statements, globals, assignment as an expression, and `synchronize()`. 37 checks. The expression statement's **POP** checked by asserting the stack is empty at the end of a program; `canAssign` checked on five invalid targets (`a * b = c`, `a + b = c`, `!a = b`, `1 = 2`, `(a) = b`) — Nystrom calls it the subtlest bug in the chapter; and recovery **counted** (`print; print;` reports 2 errors, three bad statements report 3), which is the only way to tell synchronization from suppression. The cost landed in **F-115**: giving the VM a globals table and an output broke a match in the chapter-18 file that wanted neither field. **C-105:** chapter 22 puts locals on the stack — a local costs **no instruction to create**, checked through the emitted code, and the stack is asserted empty at the end of every program. Both of the chapter's compile errors checked, including `var a = 1; { var a = a; }` where an outer `a` exists and Lox still refuses. `OP_SET_LOCAL` is F-104 in an inner loop: 76 µs with one local in scope, **404 µs with forty**. The probe it prompted is worth more than the chapter — **F-116**: a pop is a rebuild, and on a `Vector` it is quadratic (**121 ms at depth 4000**) where a `PersistentVector` is linear (34 ms) and a `pop` verb would be ~8 µs. **C-106:** chapter 23 is where `lox/lib/chunk.wat`'s nine-chapter-old prediction came true — `patchJump()` assigns into `chunk->code[offset]`, and with no positional update a patch **rebuilds the code vector**. Priced: about **7 µs per instruction already emitted**, so one patch is linear in the program so far and a program's patches are **quadratic in its length** — 90 `if`s compile in 1.06 s where the same statements without jumps take 0.16 s. The cost of a jump is a property of where in the file it appears. 40 checks: `and`/`or` leaving their **operand** rather than a boolean (because `JUMP_IF_FALSE` peeks), short-circuiting checked as an **effect** and not just a value, emitted code asserted instruction by instruction, and `for`'s step count **derived** (47) rather than guessed — which is what shows the `JMP` over the increment runs every iteration. **C-107:** chapter 24, the centre of Part II — functions as values with their own chunks, a stack of compilers, call frames with their own `ip` and window into a shared stack. 44 checks; `fib(10)`, mutual recursion, functions passed and returned. It cost **less** than ch22 or ch23 because a frame is allocated per **call**, not per instruction (C-098's lesson applied), so F-104's rebuild is paid on return. A native is a **name** rather than a closure, because F-114 forbids a closure in a Pure enum — the same table of function pointers, as a `match`, and an uninstalled native is diagnosable rather than a null jump. **F-019 met twice in ordinary code.** One expectation was wrong and the fix was to the expectation: a local function cannot recurse at this chapter, because the reference is inside its own body where the name is an enclosing compiler's local — two checks now pin that boundary for ch25 to move. **C-108:** chapter 25 is the one place the book's DESIGN could not be translated. An upvalue is a `Value*` **into the stack**, and wat has no way for two values to share a mutable location — so the pointer became an **index into a VM-owned cell table** (`OnStack idx` / `Closed v`) and a closure holds cell ids. Everything the chapter promises then follows and is checked: a closure outliving its scope, two closures **sharing** one variable, two calls **not** sharing, a write through a closure seen by the local, capture through three levels. That is a positive result — `Value*` is C's spelling of an indirection, and naming it costs one table and one read. A divergence closed itself: C-107's identity-vs-structural note is gone, because a closure carries its cell ids. 33 checks, and ch24's two boundary checks moved as predicted. **C-109:** chapter 26 turned out to be a mark-sweep collector over a **real leak**, not a model — chapter 25's cell table allocated on every capture and released none. The control is the finding: same program, same VM, threshold moved — **30 cells with the collector off, 8 with it on**, 22 collections. Every root checked by keeping a closure in it through twenty collections (global, stack, suspended frame, and one reached *through another cell*, which needs clox's grey stack). 23 checks first run. **C-110, C-111, C-112** finish Part II. Chapter 27's instances forced the **second** index table in three chapters (`var a = f; a.x = 2; print f.x;` must print 2), which is **F-117**; chapter 28's methods cost **nothing**, which is worth recording after two chapters where they did — `this` is local slot 0, and a closure inside a method captures it like any other local; chapter 29's `super` is checked to be **lexical** through a three-level hierarchy (`CBA` with a C receiver). **The tally for the section: the only thing wat could not do directly is share a mutable location. That cost a cell table, an object table and a collector for both. Everything else was translation, and the expensive parts were missing VERBS — no positional update (F-104), no pop (F-116)**. **C-113 finishes it, and corrects me.** Chapter 30 was recorded as *no portable content*; right about the content (NaN boxing, a hash-table bitmask) and wrong about the METHOD, which is to benchmark before optimising. It had a claim of mine to test: F-116's quadratic pop led NEXT.md to say this VM's stack should be a `PersistentVector`. Measured at the depths a Lox stack reaches, **the `Vector` wins** — 80-89% of the cost at depths 4 to 128, crossing over only past 256, because `PersistentVector`'s `get` answers an Option and the unwrap costs more than the clone saves. The VM's profile: **59-108 µs per instruction**, and **recursion costs twice what a flat loop does** because every call and return rebuilds the frame vector |
| **Native code emission** (`elf/`) | 17 executables; 15 compiled from wat source | **C-115:** the first evidence in this repository about wat as a PRODUCER of native code rather than as an interpreted host. `elf/hello.wat` computes the bytes of an x86-64 Linux ELF, writes them, reads them back and compares them; the result runs on the kernel with no interpreter, no runtime and no libc, and the 166-byte one is **byte-for-byte identical to a reference built independently in Python**. It is a genuine two-pass assembler — the text contains the message's address and the address depends on the text's length, so pass one measures and pass two emits, with an assertion that they agree. Nothing in the layout is written down: entry, message address and `p_filesz` are all computed. A second binary exits with a status wat worked out as `6 * 7`, to show the instructions are chosen rather than pasted. The door is **F-118**: wat has no byte literal and no `i64 -> u8`, so `Bytes::from-hex` is the only thing that can invent a byte — and the only thing that can produce one above `0x7f`, since a String is UTF-8. wat cannot set the exec bit or exec the result (no `chmod`, and `spawn-process` forks a wat child), so `tools/elf-run.sh` does those two steps and nothing else. **C-116 goes further: a COMPILER.** `elf/compile.wat` is given wat source and emits a binary for it — `(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (wat.core/+ 2 2)))` becomes a **272-byte static ELF** that prints `4`. The front end is four verbs wat already has (`read-string`, `ast-kind`, `ast->children`, `ast->source`) — and `ast->source` is the one to use, because **`ast-name` RAISES** on any node that is not a symbol, keyword or string literal. Stack discipline, n-ary arithmetic, a real `rel32` relocation, two passes with an assertion that they agree, and a compile error that names the form it could not translate. The check is **differential against the interpreter**, and it caught the compiler lying on the first run: `println` renders a String as EDN, so a string literal compiles to its source text verbatim. **F-035 costs more here than anywhere else** — no shifts or masks, so two's complement is done by hand with carries, because adding 2^64 overflows `i64`. **C-117 makes it a real compiler:** `if` (a patched forward branch — **F-104 on a String**, the same problem C-106 met on a Vector), `let` with shadowing and a statically computed frame size, user functions with a calling convention, recursion, and the six comparisons. `elf/src/fib.wat` — two recursive functions and a `let` — compiles to **659 bytes** printing `6765`, `1307674368000`, `175`. And the number that says why any of this matters: **`fib(27)` is 3391 ms interpreted and 6 ms native, 565×**, which is NEXT §7's baseline arriving from the other direction. What is still missing is **all about data** — strings as values, vectors, records, `match` — so 430 lines of wat compile a language with no heap, and compiling the language those lines are written in needs one · **C-118 adds processes and threads.** A syscall turns out to be the cheapest thing in the compiler — a number in `rax` and `0f 05` — so `fork`, `wait`, `mmap`, `clone`, `peek`/`poke` and `exit` went in, with `quot`/`rem` added to decode a wait status. **fork:** `1 2 7 1 1 4` in 698 bytes, the `7` being the child's exit code read back out of `wait4`. **threads:** `clone` with `CLONE_VM` on an `mmap`'d stack, four of them writing their own slots in a shared page and summing to **1000** in 1269 bytes, five runs the same. And this is where the differential test ran out — **F-119**: wat's OS surface is Rust-implemented inside the evaluator, so a compiled program cannot reach it, and the compiled language stops being a subset of the interpreted one exactly at the first syscall · **C-119 adds strings**, the first compiled value that is not a machine word — and it still is one: a String is the address of `[len:8][bytes...]`, bump-allocated through r15 out of a megabyte the entry stub `mmap`s. It needed a two-type static pass, for the single decision of which print routine `println` should call, and a 158-byte `print_str` that is **wat's EDN escaping in machine code**. Every escape in it was found by asking the interpreter what it printed, because nothing says — **F-120** · **C-120 makes scope free memory.** A sequence's last form is its value and every form before it has its value discarded, so a bump allocator can give that back by putting the pointer where it was: `push r15` before, `pop r15` after, eight bytes a statement, nesting on the stack with no bookkeeping. `elf/src/churn.wat` allocates 2.4 MB against a 1 MiB heap — **segfault before, `50000` after**. Sound because the only two ways to store a pointer here are a `let` slot, which dies with the statement, and `poke`, which is therefore excluded; unsound for anything that escapes upward, which needs reachability rather than scope · **C-121 adds tail calls, which wat's docs promise** (*"Wat has TCO — the stack does not grow"*) and which a compiler therefore owes: a million tail calls answered `1000000` interpreted and **segfaulted compiled** until a self tail call became a `jmp` to the top of the body with the arguments overwritten in place. It broke `threads4` on the way in — a tail call reuses the frame and `clone` hands another thread an `rbp` pointing at it, so the answer fell 1000 → 400 — which is the same exclusion `poke` already forced on the heap release. **Measured against C** (`tools/vs-c.sh`): level with `-nostdlib` C on size (695 B vs 968 B) and startup, exactly at **gcc -O0** on compute with `-O2` 3.5× ahead, and 2.5× behind glibc on output because every `println` is a syscall and stdio buffers · **C-122 buffers output and takes the one benchmark that was lost**: 100000 integers went 27 ms → **6 ms** against glibc's 13, on 106 bytes of runtime (`buf_put` 70, `flush` 36, the copy a `rep movsb`). Both sides do the same ~150 syscalls now, so the gap is what `printf` does per line — walk a format string, take the `FILE` lock, check orientation, consult the locale — against a compiler that knew it was printing an integer. **The gap is the generality, not the engineering.** The price is that every exit has to flush: the stub, `exit`, `clone`, and `fork` — where the flush was demonstrated rather than asserted, since without it the forked child inherits the buffer and `fork.wat` prints `1 2 1 7 1 1 4` · **C-123 measures the distance to self-hosting**: `elf/census.wat` walks the compiler's own AST and tallies what it cannot yet translate — **56 forms, 297 occurrences** at first count. Half of it is one feature (`nth` 55, `length` 44, `Vector` 12, `conj` 6), and the cheapest 46 were `cond`/`and`/`or`/`not` and `/`, which are `if` wearing different hats and are now built, with `and`/`or` answering the first falsy/truthy **operand** as wat does rather than a bool. 51 forms, 274 left — and the count moved *up* for `nth` and `length` because the compiler being compiled grew too · **C-124 compiles vectors and records and the census falls 274 → 106 occurrences** (51 forms → 26). They are one object — `[count:8][slot:8]...`, every slot a machine word, which is what a String is too — so `length` is one instruction for all three, `nth` and a field read are the same load, and `conj` and `assoc` are the same copy: three routines, 118 bytes. Copy-on-write, because **F-104 is true in machine code too**. And wat then refused `(assoc v 1 99)` on a Vector, which the compiler could already do for free — compiling it would have made the compiled language a superset, so it is refused, and the refusal measures the gap: **positional vector update is 49 bytes wat does not expose**. What is left at the top of the census is no longer data but the AST surface (F-119) · **C-125 measures the memory model** rather than arguing about it. Nothing is freed too early: `elf/src/memory.wat` puts live data *below* the release mark and then runs four heavy discarded statements so the later ones reuse the earlier ones' addresses — it still agrees with the interpreter. The release is worth **2.9×** (31,908 KiB vs 94,592 with it compiled out). What it cannot touch is loop-carried allocation, which is O(n²) and measured as such — that needs reachability, not scope. And exhaustion is now `wat: heap exhausted`, exit 70, instead of a segfault: every allocator checks a limit at `[r14+8]` before it writes · **C-126 answers whether a compiled wat needs a collector: no, and nothing here has one** — wat-rs holds every value in an `Arc` and there is no mark, sweep or root scan in the tree. But "no collector" is bought three ways (C by hand, Rust by ownership *in the types*, wat by refcount), and the measurement says which one we have: the same accumulator loop costs the interpreter **0.2 KB per element, linear**, and costs the compiler **4n², quadratic** — because `Arc` drops each dead clone instantly and a bump pointer cannot know. We are behind wat here, and the gap is refcounting. Rust's zero-cost deal needs ownership to be expressible, which wat's types do not do · **C-127 builds what C-126 named**: `conj` now extends a vector in place when two proofs hold — a **share count** to rule out aliases and a **last-use** proof to rule out later reads. Either alone is wrong: count 1 is not enough, because `(do (conj acc 1) (nth acc 0))` has one reference and still observes the change. The accumulator loop went from **heap exhaustion at n=8000** to **8 bytes an element at n=2,000,000**, and at n=20,000 beats the interpreter **1400x on time and 78x on memory** — a change of complexity class, not a constant. `elf/src/linear.wat` fails loudly without either half · **C-128 gives `concat` the same in-place path and adds the proof that memory comes back.** `concat` is the accumulator `:c::emit` is built out of, and it died at 8000 appends — *a compiler that cannot append to a string eight thousand times cannot compile itself*; now **32000 in 4 ms and 968 KiB**, flat. And `elf/src/freed.wat` allocates **650 MB against a 64 MiB heap** and completes with a peak of 7,880 KiB — one round, not the total — which it can only do if space is reused; compile the release out and it stops after one line with `wat: heap exhausted` · **C-129 adds the string verbs a reader is made of** — `subs`, `starts-with?`, `contains?`, `i64/to-string`, four routines and 258 bytes — and the census falls **117 → 89**, with **63% of what remains now in one place**: `ast->source` (33) and `ast->children` (21). It also turned three programs into segmentation faults on the first run, all of them a String **literal** reaching a variable and then being shared: the C-127 increment was writing to the read-only segment. A literal's count is zero by construction, so the increment is now guarded — and that is the differential test catching a fault no amount of reading would have found · **C-130 writes wat's reader in wat** — the 56-of-89 item, since `read-string` and the `ast->*` verbs are Rust inside the interpreter (F-119). 187 lines, nodes in an arena to dodge a recursive record type, compiled to 8,865 bytes. `elf/conform.wat` walks its tree against wat's OWN reader node by node: **11,638 nodes agree**, including reading `compile.wat` itself (9,433 nodes, 192 top-level forms). On the way in it closed a silent divergence a lexer would have been built on — `=` on two Strings was comparing **pointers**, answering false for equal strings · **C-131 swaps the compiler onto its own reader and the census falls 297 → 21** over the session (56 forms → 12). `read-string` and the `ast->*` verbs are gone; a node is an index into an arena, read through the context that was already threaded everywhere. The closure and the last `Option`/`match` went by rewriting the compiler rather than its language. **What remains is one thing**: ten diagnostics, and eleven occurrences that are the ELF reaching the disk — `Bytes::from-hex`, the `IOWriter` verbs, `read-file`. A compiled program can write a file in three syscalls; what it cannot do is call wat's, and it cannot route around them through a String because that is UTF-8 in one world and bytes in the other. **The last mile is a verb with two implementations — the contract F-119 asked for** · **C-132: it self-hosts.** `wat elf/compile.wat` builds a 96,793-byte compiler in 64.9 s; that binary redoes the same work in **425 ms (152x)**, writes 35 binaries **all byte-identical** to the interpreter's, and **reproduces itself byte for byte**. The census that started at 56 forms and 297 occurrences is at **zero**. Compiling the compiler found two bugs nothing else could: `syscall` destroys `rcx` and `r11` (a buffer pointer parked there came back as EFAULT), and `:c::body-start` scanned for the first LIST child — so a function whose body is a bare literal compiled to nothing, and a 95-character table came back with length 0. It had been there since the first commit · **C-133 uses the bootstrap as the test.** Two peephole wins — the right operand of a binop taken straight from an immediate or the frame, and a comparison in an `if` branching on the flags instead of materialising 0/1 — put `fib(32)` at **30 ms against gcc -O0's 34**, measured side by side. The second one broke the compiler and **the bootstrap caught it on the first function it read**: `cmp-cond` recognised a comparison by spelling, and `(not= fast "")` is a `str_eq` by meaning, so it compared pointers. `elf-run` passed that build. A bootstrap is not a slower test, it is a differently-shaped one · **C-134 builds the loop the bootstrap was for: 3–5 minutes → 4.1 s.** `bootstrap.sh --fast` seeds from the compiler already built rather than the interpreter (65–85 s → 1.2 s), the differential oracle is cached by source hash so a compiler change costs zero interpreter runs, and the fib(27) benchmark stops being run as a test. `--fast` proves the fixpoint for the NEW compiler — stage 2 == stage 3 — while stage 2 differing from the seed is exactly what a codegen change means · **C-135 takes the short encodings** — one byte of displacement where four were being emitted, a seven-byte `mov` for a literal instead of a ten-byte `movabs`, and no `sub rsp` at all for an empty frame. Output **13% smaller** (99,203 → 86,250 bytes). Safe because the two-pass invariant only needs *pass-invariant* widths fixed: frame layout and program text do not change between passes, addresses do. It broke every tail call — the jump target was hardcoded `base + 11`, the old prologue length — and `tools/loop.sh` found it in four seconds · **C-136 adds register allocation and measures who should get it.** Parameters can live in `rbx`, `r12`, `r13` — callee-saved, so a call cannot clobber them. Doing it everywhere was wrong: a 200M-iteration loop went **597 → 384 ms** while `fib(32)` went **32 → 40 ms**, because the prologue cost is per-call and the benefit is per-iteration. Giving them only to functions with a **self call in tail position** gets both — mix 343 ms, fib 31 ms. The A/B took four compiler builds at half a second each; without the loop the guess *"registers are faster"* would have shipped with the regression · **C-137 keeps expression temporaries in registers** — r8-r11 survive exactly when the operand emits no call, which a whitelist decides, and how many a subtree needs is computed bottom-up so nothing is threaded. Worth **7–9%** (`poly` 398 → 372 ms, `mix` 366 → 332), smaller than it looks because the direct operand had already taken the common cases. `fib(32)` is **29 ms against gcc -O0's 32**. The first run also found that **compiling itself peaks at 1.09 GB** — C-125's limitation arriving on the only workload big enough to show it · **C-138 replaces three text searches with the structure questions they stood in for**, after the builder asked why a compiler with a type pass was guessing. `scratch-safe?` now asks `type-of` about `=` (output byte-identical — it bought nothing, it is just right); `has-clone?` is an AST walk rather than a substring; and **`releasable?` was unsound** — a statement that *calls* a poker contains no `poke`, so it was released and anything it had allocated and handed over was freed underneath. Now a fixpoint over the call graph the compiler already had · **C-139 audits for the rest.** Two more hardcoded lengths of the `base + 11` kind (`+30`, `+163`, `+220` in the runtime offset chain, and `stub-len 117`) — now derived, and the stub measures itself. `ty-of-node` recognised types by **substring** with a silent `i64` default, so an unknown type became a machine word; now exact names and a refusal. Making that refusal real found **a one-argument `concat` being rejected** and **collection being order-dependent for types**. Eight across C-138/C-139, from one question — and **every one passed every test**, because tests exercise what code does, not what it assumed · **C-140 fixes the memory and finds that the gigabyte was never where anyone looked.** The in-place `concat` had a third condition nobody had written down as a limitation -- *is this string still the top of the heap?* -- so the fast path silently required that nothing else had allocated since the last append. `elf/bench/catx.wat` is that in one line: the same 32,000 appends cost 2,180 KiB alone and **1,855,368 KiB with a second accumulator beside them**. A String now lives in a block of the next power of two at or above `16 + len`, so its spare room is derivable from its length with no header field and it can grow anywhere in the heap; vectors are adaptive, because giving every vector the same treatment measured **349 MB worse** -- records and `assoc` allocate final-size blocks that never grow. The compiler went 1,247,244 -> 1,023,672 KiB, and then a **phase bisection** said the rest of it is not in the emitter at all: **reading `elf/compile.wat` peaks at 745 MB before a byte of code is emitted**, quadratic in the input. `elf/bench/pass20000.wat` is the mechanism in six lines -- `grow20000.wat` with the accumulator handed to a user function on its way to `conj`, **964 KiB against 1,564,716** -- because `:c::push-args` increments the increment-only share count of every pointer passed to a user function, so `conj` copies the whole vector from the first call on. The fix is that storing a value that is dead afterwards is a MOVE, and it is named rather than attempted: a field read aliases without being read, and a return value can alias an argument |
| Lazy streams (probes only) | 1 probe | **F-100:** a lazy stream **does not memoize** — three forces of one value ran the suspension three times. **Deliberate**: the Ruby `Enumerator` pattern (pull, process, discard), which keeps a retained head from leaking. The consequence: Okasaki's entire **Part II** (the banker's, physicist's and real-time queues, splay and pairing heaps) is built on a suspension being forced at most once and shared, so without memoization those structures have **no mechanism**, not merely worse constants. wat's laziness itself is correct — `seq.wat` builds `remove` and `take-while` on it — what is absent is *sharing*, and the ask is a **separate** `Susp<T>`, not a change to `Stream`. Also: the 1 TB path is unreachable today anyway — `:wat::io::` is three verbs, `read-file` returns the whole file as a String and `with-open-file` is write-only. `stream::lazy` takes a **body expression**, not a thunk, which nothing documents |
| Recursion depth (probes only) | 1 probe | **F-099:** a non-tail recursion is fine to **100000** frames and **SIGSEGVs at 120000** — exit 139, **empty stderr**, no wat-level error where every other failure class emits structured EDN with a file and line. The same overflow inside `run-thread` aborts with *"has overflowed its stack"*, so the runtime sees it on a spawned thread but not the main one, and wat's only general catch (F-063) does not catch it. Reached by ordinary code: the textbook `len` over a 120000-element list, or a self-referential stream — the natural spelling, since `stream::cons` is eager in its tail. Tail recursion is unbounded (1,000,000 verified), which is the only mitigation |
| EOPL (NEXT §9, **22 of 22 — complete**) | ch 1-9 | **C-061:** Friedman & Wand's one language, two machines. Both agree on arithmetic, `let`, `proc`, `if` and `letrec`. **F-099 lands on the interpreted program**: a direct-style interpreter makes the *interpreted* depth wat's depth, so it segfaults between **40000 and 50000** while the CPS/trampolined machine reaches **300000**. Chapter 5's move is not stylistic in wat — if you write an interpreter here, write the trampolined one. Bonus, found by accident: **wat's TCO is preserved through the direct interpreter** — an interpreted tail call lands in tail position in `value-of`, so my first test could not tell the machines apart at all. **C-062:** ch4's three parameter-passing disciplines then price the suspension from the language side — by-name is **O(n²)** (~4× per doubling) where by-need is **O(n)**, so at depth 1200 an argument used twice costs 97 ms by-value, **44669 ms by-name**, 147 ms by-need. The case for P-027 is asymptotic, not a constant factor. **C-063:** ch7 then has wat **host a type system** — reconstruction by unification over the same unannotated syntax the interpreters run, so the checker and the evaluator cross-check. 5 inferred types the evaluator agrees with, and **5 rejections including the occurs check** (`proc(x) (x x)`), without which a checker loops instead of rejecting. **C-064:** and ch5's THREADS closes a loop — once a continuation is data, a thread *is* one, the scheduler is a queue, and **blocking is moving it to a blocked list**, so the interpreted language gets the mutex its host cannot express (F-102). The lost update returns on purpose **in the toy language** (not in wat — C-053 says wat cannot have it): 40/80 at slice 1–2, **80/80 at slice 1000**, the same interpreted program correct or broken by the scheduler alone. **C-065:** and ch5.4's exceptions do it a third time — a handler is a continuation frame, so **installing one costs 4 transitions** and only unwinding scales (27/47/87/167 for depth 5/10/20/40), against wat's `run-thread` at **1.44 ms flat**, because that is a thread spawn (F-063). A first draft compared wall clock and was confounded by the interpreter's own ~14 µs/transition — transitions are the machine-independent number. **C-066:** ch4's store then prices mutable state three ways — **threaded `PersistentMap` 10610 ns, `:wat::cache::Lru` 35034 ns (3.3× worse), a service ~448000 ns (42×)**. The pure option wins, which is the opposite of the systems instinct, and the store must be a map because F-104 leaves the vector without a positional update. **C-067:** and ch7's **CHECKED** closes a gap inside a chapter I had reported as done — a checker rejects `proc(x : bool) -(x,1)` where the inferencer accepts the same shape as `(int -> int)`, because inference has **no annotation to disagree with**. That is the model wat itself uses. **C-068 / C-069:** and chapter 4 is now complete — IMPLICIT-REFS makes every variable a reference so `deref` is never written, and **call-by-reference turns out to be one predicate**: *is this argument a bare variable?* One program, `let x = 0 in let f = proc(y) set y = 99 in ((f x); x)`, answers **0 by value and 99 by reference**, while a non-variable argument answers 99 under both — because there is nothing to alias, which is the half of the definition the first row alone misses. MUTABLE-PAIRS then costs almost nothing: a pair is two adjacent store cells, so aliasing needs no new machinery, and the aliased/rebuilt pair (99 vs 1) is the same sharing-vs-copying distinction wat already draws between `PersistentMap` and `HashMap` (C-023). Three EOPL languages now have the shape the CEK work wants. **C-070:** ch6 then rewrites the PROGRAM instead of the machine, and wat is the one host where that claim can be *measured* — the SAME direct interpreter segfaults at **n=25000** on the source and reaches **100000** on its CPS transform, same answers at every shared depth. Honest caveat published rather than smoothed: "every call becomes a tail call" is **false** in this encoding (LETREC's one-argument procedures force currying, so `nontail` goes 1 -> 2); the property that actually holds is a grammar — every operator and operand SimpleExp — at **2 violations on the source, 0 on the output**, after two wrong metrics of my own were deleted rather than tuned. **F-105:** and ch6.5 prices registerization, which matters because it is the shape the CEK work wants: `step : State -> State` is **~1.9x slower** than the mutually-tail-calling form it replaces (1.85x/1.84x/1.95x, and 2.05x/1.99x with the arms swapped as an order control), because `step` must allocate the State it returns where mutual tail calls allocate nothing. It is a **choice**, not a necessity: wat's TCO spans mutual tail calls to **10,000,000**, which many implementations do not. **C-071 / F-106:** ch8 then builds the chapter NEXT.md flagged as closest to wat's own design — modules with interfaces the checker enforces — and one word decides everything: under `opaque t`, `-(from ints take zero, 1)` is **REJECTED** and `(succ 0)` is **REJECTED**, while under `transparent t = int` both are accepted; the module's own `(succ zero)` and `(to-int (succ zero))` keep working either way, which is the positive control that abstraction **hides rather than forbids**. The functor row is sharper still: the same module satisfies a `zero : int` requirement transparent and **fails it sealed**, same values underneath. And the wat answer: `newtype` does the distinctness half properly (arithmetic refused, a raw i64 refused where the type is wanted) but **not the sealing half** — the bare-name constructor and the `/0` accessor resolve from any namespace, so anyone can unwrap and rewrap. Distinctness without encapsulation, and `newtype` is named twice in the guide, both times in a list, with its `/0` accessor documented **nowhere**. **C-072 / C-073:** ch9 then separates OO's two mechanisms with numbers rather than prose — on one c2 object, `send self m1` answers **23** and `super m1` answers **11**, the same method name from two starting points, so the evaluator must carry `self` AND the running method's owning class; lose either and one of the two breaks. TYPED-OO adds the first rule here that is **not an equality** — subsumption — and its sharpest row rejects `summable.m3` where the run-time value really is a `c2` that has `m3`, because a send is checked against the **static** type (C-071's opaque types again). And the gap-shaped question *"wat has no classes, so what breaks?"* answers **nothing this chapter is for**: `defsurface`+`extend-type` already give subsumption, a heterogeneous `(Vector :- [(Shape :- [i64])])` holding two different concrete types, and **dispatch through it (35 = 25 + 10)**. What wat denies is the other half — two structurally identical structs are not interchangeable and there is no `extends` — so "program to an interface, not an implementation" is enforced here rather than advised. **C-074:** chapters 1-3 then close the book. ch1's *follow the grammar* is enforced rather than remembered — an inductive definition IS a `defenum` and one-clause-per-production IS an exhaustive `match`. ch2's representation independence runs **one client against three environments** (association list, ribcage, and a **closure** with no data structure at all, the type parameter instantiated at `[String :-> i64]`) — but only via a dictionary, because the natural parametric-surface encoding is refused: **F-029, third sighting**, and new here, a second argument of type `R` does *not* rescue it. ch3 builds LET and PROC separately, where the increment turns out to be a **type** fact: `:l3::Exp` has no `Proc` variant, so a LET program containing a procedure cannot be BUILT rather than being rejected. **F-107:** and the ch2 dictionary turned up a fresh defect — a generic struct's type parameter binds from its FIRST field, a bare variant literal binds it to the **variant** rather than the enum, the enclosing function's declared return type is not consulted, and **an explicit `:- [T]` at the construction site is parsed and silently discarded** (a deliberately wrong one errors identically). The diagnostic blames the field that was written correctly |
| Okasaki (NEXT §10, **complete**) | ch 2–11 | **C-051:** chapter 2's `UnbalancedSet` is 40 lines of wat and correct — recursive parametric enums work, the in-order walk is sorted, and `ok::Set`, `PersistentMap`-to-`true` and `HashSet` agree on all 10000 membership probes over 2000 LCG values (depth 27 vs an optimum of ~11, reported not assumed). **F-097:** and it is **34x slower to build, 43x slower to query** than the workaround F-057 forces. `BASELINE.md` predicts why to within 5%: 1922 ns per node visited against a predicted 1830–2190 for one call + one match + a comparison. So F-057's gap needs a **native** persistent set; a library one cannot win, and `PersistentMap`-to-`true` is the right answer until there is one. **C-052:** ch3's leftist heap answers F-056's missing priority queue in 60 lines — leftist property and heap order checked at every node, drain sorted, and insert cost rises just **1.19x across three doublings** where O(n) predicts 8x. ch5's batched queue is FIFO-correct with its invariant held after every operation. **F-098:** and the queue exposed the biggest container finding yet — a `defrecord` field holding a **user enum value** is deep-copied on construction, so the same algorithm is flat at 8755 ns/op in an enum variant and 158808 (diverging) in a record. Four other hypotheses were measured and eliminated first. **C-055:** ch6's banker's queue then settles what a memoized suspension buys. One value, k futures: the eager queue is **flat at ~3.0 ms/use** (paying the rotation every time) while the banker's **falls as 1/k** — 508633 → 90185 ns/use for k = 10 → 100, **33.6× better at k=100 and widening**. Built on the P-027 LRU stand-in, whose 2×-a-call force tax inflates every absolute number; the shape is the result. **C-056:** ch7 then shows what an *average* cannot — the banker's queue pays its rotation all at once, a **3518 µs spike**, where the real-time queue's worst single operation is **114 µs**, 30× smaller. **C-057:** ch8's deque then generalises it — no cheap end, balance invariant held after **every** operation, and a worst single op of **84 µs** across both ends, below ch7's one-sided 114 µs. All four carriers (`BQ`, `LCell`, `RTQ`, `DQ`) are **Impure enums**: the one shape that may hold a suspension (containment rule) *and* shares its payload (F-098) — at four occurrences that is a rule the language should state. **C-058:** ch9's numerical representation then needs **no laziness at all** — every type a Pure enum, no stand-in — and both curves come out textbook: the random-access list rises a constant ~8600 ns per doubling (O(log n)) while the cons list doubles exactly (O(n)), **67× apart at n=3200**. **C-059:** ch10 then shows wat's type system takes **polymorphic recursion** — `Queue<A>` containing `Queue<List<A>>`, with mutually recursive functions over it at differing instantiations — which many type systems refuse and the rest cannot infer. **C-060:** ch11 then stacks all three techniques — numerical digits, polymorphic recursion, and a suspension in the recursive position — and `Susp<Queue<Pair<A>>>` inside `Queue<A>`, the hardest type in the book, type-checks and runs. Five structures now need the same undocumented Impure-enum carrier **C-075:** and chapter 4 — the chapter every other chapter's header cites and none had tested — was the one omission a coverage audit found inside a suite already reported complete. Its distinction is now a COUNT rather than a clock: on `s = [1 2 3 4 5]`, `head(s ++ t)` forces **1 of 6** cells and `head(reverse s)` forces **6 of 6**, with `take` at 2 and `drop 3` at 4 — five predictions, five held. A second traversal forces **nothing new**, which is the force-once-and-SHARED that `:wat::stream::` deliberately lacks (F-100) and the reason P-027 asks for a separate `Susp<T>`. `forced?` is what makes the table writable at all, so it belongs in the primitive's signature. |
| Performance baseline (bench + tools) | 2 bench programs, 7 figures | `BASELINE.md`, taken **before** the byte-code / jump-DAG work because a before/after cannot be captured afterwards. Minimum of 3 runs, each against an empty-loop control of the same shape, with every body repeating its operation 10x — the first version reported a *negative* cost for a builtin call because a 200 ns effect sits under a 3.6 µs iteration. builtin call **360 ns**, match-2 675, user `defn` 795, closure 853, `defstruct` accessor 1219, **`defrecord` accessor 6130**. **F-096:** that last one is 5.0x its `defstruct` twin for an identical one-field shape and 17x a builtin, with a control proving the cost is the accessor and not the passing |
| Load order (probes only) | 1 probe, 5 cases | **C-050:** `:wat::deporder::` verifies that wat's `.wat` files declare their load order correctly, and does exactly that. The real baked order over **62 files reports 0 violations** — and the same 62 files **reversed report 457**, so the zero is a measurement rather than a silence (R59, *nisi frangas, nihil probas*). A two-file case reports exactly 1 with both positions and the symbol; swapped, 0; and the `defmacro` order-free exemption holds. Reading 62 files: 1 ms. `verify` over ~1.3 MB: **1291 ms, ~1 MB/s** — a hundred times the formatter's ~10 KB/s (F-075), so parsing and walking are not what makes the formatter slow |
| Runtime reflection (probes only) | 1 probe | `:wat::runtime::` is 17 verbs and — unusually here — **documented** (`USER-GUIDE.md:2986`), so it can be checked docs-against-code. **C-049:** the verbs work; `signature-of-defn`, `body-of`, `extract-arg-names`, `extract-arg-types` and `return-type-of` all answer correctly. **F-095:** the section gives **every** return as `:wat::holon::HolonAST` (L2994, 2999, 3002, 3011, 3120) where they return `:wat::WatAST` — and `HolonAST` is a real, different type, the VSA AST `HolographicLru` keys on. It calls `extract-arg-names`' result "bare-symbol arg names (suitable for splicing as call positions)"; they are **keywords**. It teaches `lookup-callable`, which does not exist, and names it again in "Coverage today". And the signature it returns is in the retired `define` shape |
| Brackets (probes + tools) | 2 probes, 10 timed rows | `:wat::bracket::` is wat's parallelism layer ("Ruby's Parallel over spawn-program"). **C-048:** `map` is correct and **order-preserving** — verified with an *inverted* workload where item *i* costs `(n-i)`, so completion order would be the exact reversal; wat-rs's own fixture uses a constant-cost work-fn and would pass by luck. `:wat::spawn::Locus` accepts both `ThreadOpts` and `ProcessOpts` (second witness for C-046). **F-094:** but the **thread pool does not parallelize**. 16 equal CPU-bound items on 16 runners: sequential 16073 ms, thread **9513 ms (1.69x)**, process **5142 ms (3.38x)**, and 16 independent OS `wat` processes on the identical burn — the ceiling for this machine — **5.90x**. Thread wall time grows **10.3x** for 16x the work; process grows 3.4x. An allocation confound was found and removed (it helped, and the gap survived). The layer is named once in all four user-facing pages, as a *syntax specimen* |
| wat-fix (probes + tools) | 16 programs round-tripped | **F-092:** `wat/fix.wat` is the wat-to-wat converter whose header reads "THE PROVING POINT: wat writes wat", and whose documented STASH-DANCE applies it to a whole corpus at once. Converted 16 green self-contained probes and ran both: **7 identical, 8 no longer start, 1 failed to convert.** Four causes, and **three of them have no correct output at all**: only the fn-type bracket is a mis-dispatch (`to-symbol` vs `to-type-form` differ correctly; `fix-seq` can't see which bracket it is in), while `:wat::WatAST`, `Type/method` and a `defenum` name have **no faithful-Clojure spelling** — every candidate is unresolved, and `Result/try` canonicalizes its `/` back to `::`, a different name. The fix for those three is to refuse, not rewrite. **F-093:** and the 7 that converted cleanly each lost call-site type checking. The same program declared `i64 -> i64` and handed a String is **refused at startup** in rust-scheme and **runs, printing the String, exit 0** in faithful-Clojure. Declarations are checked (unknown annotation types and bad return literals are both caught); the argument at the call is not. F-014's consequence, and the codemod's `head-rule` exists to move every call into that spelling |
| Rationals (probes only) | 1 probe | **C-047:** exact and Clojure-faithful. `1/3+1/3+1/3 = 1` is **true** where the f64 control `0.1+0.2 = 0.3` is **false**; commutativity, associativity, distributivity and `x*(1/x)=1` all hold; arbitrary precision (no i64 overflow); `1/0` refused at lex time. The one surprise is Clojure's: `4/2` reads as `i64`, not `rational` — verified identical in **clj 1.12.6** (`(class 4/2)` is `java.lang.Long`) — so `:wat::rational::+` refuses `4/2` while the generic `:wat::core::+` takes it. The namespace is named **zero** times in any user-facing page. **F-090:** and the collapse leaks. `:wat::rational::+` declares `-> :wat::core::rational` and returns a **bigint** when the result is whole (the code comment: "this stone's pinned collapse"). `+ - * /` were all made lenient enough to absorb it; **`to-f64` was not**, so `(to-f64 (+ 1/2 1/2))` type-checks and dies at runtime. A well-typed two-call program with no user types in it. **F-091:** a lex error names no file, line or column — only a byte offset into `parser.rs` |
| The CLI (tools only) | 4 modes | **F-089:** `wat --help`, `-h`, `--version` are all read as *filenames* — `read --help: No such file or directory`, exit 66 (`EX_NOINPUT`). The usage block exists but prints only when `wat` is run with **no arguments at all** (exit 64, `EX_USAGE`). It names four modes; **only `--check` appears in any user-facing page** — `--repl`, `--mcp` and `--grep` have **zero** mentions across all four. The REPL works: `(:wat::core::+ 2 3)` → `5`. `--fmt`/`--lint`/`--test` are not modes at all (the formatter, linter and test runner are wat-level libraries, which is reasonable and also unstated). F-087 seen from the other side: the docs name 87 verbs the substrate lacks, the substrate has 3 modes the docs lack |
| Streams (probes only) | 1 probe | **F-088:** the documented stream API and the real one are **disjoint**. The docs name 9 verbs (`map`, `take`, `collect`, `fold`, `chunks`, `flat-map`, `for-each`, `spawn-producer`, `from-receiver`, `with-state`, …) and **none exists**; the substrate has 4 (`cons`, `empty`, `lazy`, `next`) and **none is documented**. Same shape for `:wat::config::` (6 taught, 0 exist; 1 exists, 0 named). A third namespace was withdrawn on re-reading — see the finding. `:wat::kernel::` is the largest absence at 15 — channels, `process-send`/`recv`, `fork-program`, `run-sandboxed`. This closes a real road: `filterv` refuses a `PersistentVector` (F-080) → `filter` answers a `Stream` → the documented `collect` does not exist → `(length <Stream>)` type-checks and dies at runtime (F-031). The probe supplies the missing collect in six lines (P-025) |
| Telemetry (probes only) | 3 probes | **C-045:** the journal's sort key holds the property its read path depends on — `time-sk` is 38 chars for every input across the whole i64 range (1677–2262), and lexicographic order matched chronological order on all 10 adjacent pairs, including both extremes and either side of the epoch. `mem.wat` really does compare `sk` as a String, so this is load-bearing. **C-046:** surface-splice works in both directions — the spliced accessors read correctly, ctor order is splice-first, and a function typed `[s <- :wat::telemetry::Scope]` **accepts a `Metric` that spliced it**, which is the contrast with F-029. wat's own source never consumes `Scope` as a surface (zero uses); this probe is its first. **F-085:** the user guide's uuid backward-compat note is wrong about 3 of the 4 spellings it names. **F-086:** the three telemetry headers describe a primed `:wat::telemetry'` namespace that exists only in their own comments |
| The cache (probes only) | 3 probes | **C-044:** `:wat::cache::Lru` is a real LRU, not a FIFO wearing the name — the decisive case (cap 2, put a, put b, **get a**, put c evicts **b**) passes with its no-get control (evicts **a**) beside it, plus 9 more assertions on displacement, update and the `len` bound over 500 puts. Its two declared panics fire with the offending value and are recoverable through `run-thread`. **F-083:** but `HolographicLru::put` **deletes an entry when the same key is put twice** — `Lru::put` displaces on BOTH over-capacity and already-present, the `Option` says which is which nowhere, and the dual-eviction step removes the key just inserted. Capacity 8, one key: len 1 → **0**. The gate that covers this file has five cases, mutation-tests the eviction path, and writes every key exactly once. **F-084:** the capacity guard names the internal `:rust::` shim and leaks a Rust backtrace note |
| wat-grep (probes only) | 534 files, 137,690 nodes, 2 probes | `:wat::grep::` is the code-search engine the formatter is built on, and it appears in **no user-facing page**. **C-043:** both laws its own header declares hold exactly over this repository — `Span == Node` at 137,690 each with **0 violations**, `Node > Named` with 0 — and the `Written` predicate ("EXACT, not a heuristic", evidenced by wat-rs on 222 nodes) scales to 137,690: of 6,156 Named-without-Written nodes, **zero are Symbols**, and the 1,313 Keyword exclusions are exactly the four reader-synthesized names. It also reports the corpus's 2 unparseable files as `Unreadable` and returns everything else — the same input that makes `lint-source` raise and discard 531 files (F-078). **F-080:** `filterv` alone among nine core sequence verbs has no `PersistentVector` clause, and every vector in `grep::Facts` is one. **F-081:** 4,843 of the 6,156 exclusions (79%) are string literals — 0 of 80,027 `Written` facts is a `StringLit`, because a string's span covers its quotes — and the header explains the guard purely in terms of the reader. **F-082:** the header's pinned `wat/fix.wat Node=4316 Span=4316` measures 4929/4929 at HEAD, 14.2% stale after 18 days of file growth, beside an invariant that held exactly |
| The linter (probes only) | 99 stdlib + 256 self findings, 5 probes | `:wat::lint::` is a pure-wat linter with two form-level rules, and `lint-stdlib` is zero-argument. **Both rules are correct and precisely scoped** (C-041), verified with positive, negative and threshold cases — `concat-abuse` fires on interleaving and not on clean code; `nested-if-=-ladder` fires at 3 literals and not at 2, on strings and keywords, and correctly ignores value-returning chains because it is a membership rule. It flags its own file 6 times. **F-076:** all 99 stdlib findings are `concat-abuse`, each recommending `:wat::core::format` — which exists (`core.wat:1681`), works, and appears in **zero** user-facing docs. Two witnesses: the stdlib is flagged 99 times, and this repository holds 339 `string::concat` calls against 0 `format` calls, written by a model that never found it. **F-077:** `lint.wat` ships its ladder fix report-only because "ast-span returns ONLY the START … not possible with the current substrate primitives" — but `ast-end-span` exists, works, and is documented in that same file's own `FixEdit` record. **C-042:** pointed at this repository's own 530 programs it returns **256 findings, every one `concat-abuse`** — `nested-if-=-ladder` fires 0 times across 592 files from two independent authors, and 59 of the 256 carry a fix (23%, against the stdlib's 15%). **F-078:** getting that number at all needed a workaround — one file that does not lex makes `lint-source` raise and discard every finding from the other 531, and the raise names only `byte 258`, never the file. **F-079:** the third rule, `load-order`, is reachable only through `lint-stdlib`, which is hardcoded to wat's own sources; outside code gets 2 of 3 |
| The others | — | Friedman's two textbooks, *Essentials of Programming Languages* (with Wand) and *Scheme and the Art of Programming* (with Springer), are not queued. NEXT.md lists the acceptance tests that come after the books |

### Relay to wat-rs, by task

Every open finding, grouped by the kind of wat-rs task it would become. The two lists below
give each one's detail.
 · F-089 `--repl`, `--grep` and `--mcp` are named in the binary's own usage and in none of the four user-facing pages — and `wat --help` is read as a filename (exit 66), so the usage block is reachable only by running `wat` with no arguments at all |
| Task | Findings · **F-088 for `:wat::stream::` and `:wat::config::` the documented API and the real one are DISJOINT — 9 documented stream verbs, none exist; 4 real ones, none documented. (A third namespace, `:wat::list::`, was in this finding and was withdrawn: its 2 names appear only inside the guide's own note that they do not exist.)** |
|---|--- · **F-083 re-putting a key into a `HolographicLru` DELETES it: `Lru::put`'s `Option` cannot distinguish an over-capacity eviction from an update, so the dual-eviction step removes the key just inserted — and the shipped `hologram-svc` inherits it** · **F-087 81 of the 203 verb names the user-facing docs teach are rejected by the compiler (68 unresolved, 19 retired, less 6 that the docs name only to disclaim), and 49 of 159 code blocks (30%) contain at least one — including §4's `define` section, the "slightly richer first program", and a reference table for six `:wat::stream::` verbs in a namespace that has four, none of them those** · F-089 a `--help` flag: the usage text already exists and is unreachable except by invoking `wat` bare |
| **Fix** (behaviour is wrong) | F-001 debug build panics · F-002 new test file never run · F-003 `wat.test/deftest` skipped · F-004 `()` in `wat.core/quote` refused · F-009 constructors fail at runtime · F-010 fn-typed param misread · F-012 `wat/load-file!` no-op · F-014 symbol-headed calls unchecked · F-016 flat `cond` crashes · F-017 `wat.core/match` arms misread · F-018 `wat.core/def u/x` defines nothing · F-021 `~@` of a vector form in a program body · F-022 `wat.core/defmacro` defines nothing · F-024 `wat.core/let` body checked without bindings · F-026 retired nested pattern passes · F-030 printing a newtype panics · F-031 `length` on a String passes the checker · F-038 a builtin verb as a function value passes the checker in two of three places · F-019 a variant keeps its narrowed type, so two values of one enum can't be compared with `=` · F-020 a unit variant isn't a value · F-029 a fn generic over a surface refuses the structs that implement it (hit in two books: ML functors, Java visitors) · F-039 an `extend-type` that leaves a feature out passes the checker; the call fails at runtime · F-041 `str` takes one argument, and more pass the checker · F-042 `#(…)` read as the symbol `#` · F-043 a map in call position passes the checker · F-044 a keyword lookup `(:k m)` isn't type-checked · F-045 `first` and `rest` die on an empty collection · F-048 a record's accessor binds a generic T to `:wat::core::Record` · F-050 end of input in the middle of a frame panics ("disconnected") · F-052 a function can't declare a connected peer as its return type · F-058 a `PersistentMap` constructor refuses a bracketed type that isn't a keyword, where its `HashMap` twin accepts the same nesting · F-059 a dotted pair reads as a three-element list with `.` as an ordinary symbol, then prints back as a dotted pair — so an improper list round-trips while meaning something else · **F-067 wat's rete disagrees with its own declared SPEC: a bare accumulator (`count`, `sum`) asserts its result over the empty first pass, so `fire-rules$oracle` and the public `fire-fixpoint` keep a stale `0` beside the right answer where `fire-rules` does not** · F-070 `wat/doctest.wat` guards neither its comparison nor its evaluations, so one bad example masks all 485 — and the guard it needs (`:wat::test::run-thread`) is already loaded at that point (test.wat #34, doctest.wat #38) · **F-078 one unlexable file makes `lint-source` raise and discard every finding from every other file in the batch — 531 good files lost to one negative probe** · **F-080 `:wat::core::filterv` has no `PersistentVector` clause, where its eight sibling sequence verbs all do — so the fact base `:wat::grep::` produces cannot be filtered with the obvious verb** · F-084 the cache's capacity guard names the internal `:rust::cache::Lru::new` rather than the `:wat::cache::Lru::new` that was called, and leaks a raw Rust panic plus `RUST_BACKTRACE` note to stderr even when recovered (C-037's family, third witness) · **F-085 `USER-GUIDE.md`'s uuid backward-compat note is wrong about 3 of the 4 spellings it names — it MANDATES `Uuid/v4`, which the checker refuses, and promises `:wat::telemetry::uuid::v4` "still works" when it does not exist** · F-086 telemetry's three headers document a primed namespace `:wat::telemetry'` that appears 14 times in comments and 0 times in code, including a `~@:wat::telemetry'::Scope` sample that would not parse · F-088 `:wat::stream::collect` — the documented way back from a `Stream` to a vector, which does not exist, leaving `filterv`'s refusal (F-080) with no exit (P-025) · **F-090 a well-typed program crashes: `:wat::rational::+` declares `-> :wat::core::rational` and returns a `bigint` when the result reduces to a whole number — the code comment calls it "this stone's pinned collapse" — and `to-f64`, alone among the five verbs, was never made lenient enough to absorb it** · **F-092 `fix-text`, wat's own wat-to-wat codemod ("THE PROVING POINT: wat writes wat"), breaks 9 of 16 independent green programs — 8 of them no longer start — in four distinct ways, including converting `:wat::WatAST` into `wat/WatAST` when no symbol spelling of `WatAST` resolves at all** · **F-093 a wrongly-typed argument at a Clojure-spelled call is not checked: a function declared `i64 -> i64` accepts a String, returns it and exits 0 — and the codemod's whole job is to move call heads into that spelling (F-014's consequence)** · **F-099 a non-tail recursion past ~110000 frames SEGFAULTS the process with an empty stderr and no wat-level error — including `(len l)` over a 120000-element list, and a self-referential stream (the natural spelling, since `stream::cons` is eager in its tail). The same overflow on a spawned thread aborts with 'has overflowed its stack', so the runtime can see it; `run-thread`, wat's only general catch, does not catch it. Tail recursion is unbounded at 1,000,000** · **F-103 a parametric enum's constructor does not check its fields against the instantiated type — `(Box.B :- [i64] {:v "a String"})` is accepted and the String reads back out of a `Box<i64>` if it never crosses a typed boundary. Function boundaries and typed accessors all refuse it; the constructor alone does not** · **F-107 an explicit type argument at a generic struct's construction site is parsed and DISCARDED — `(:p::Ops :- [:wat::core::i64] …)`, deliberately wrong, errors identically to `(:p::Ops :- [:p::E] …)` and to no annotation at all. The parameter is bound bottom-up from the first field instead, a bare enum-variant literal binds it to the VARIANT rather than its enum, and the enclosing function's declared return type is never consulted. The diagnostic then blames the field that was written correctly. An annotation accepted, ignored and never reported is the F-093 family, and the one a generator cannot catch by reading its own output** · **F-110 a second `defclause` with the same name SILENTLY REPLACES the first — *clauses attempted: (1: [:d::B])* is all the reader gets, and the earlier clauses are gone, not merged and not shadowed. `extend-type` refuses the same redefinition with *duplicate define*, so the mechanism that CAN be extended safely rejects it and the one that CANNOT accepts it. The F-107 / F-093 family: written, accepted, no effect, never reported** · **F-111 `:wat::rational::numerator` and `denominator` are annotated `@ret :wat::core::i64` and return a **bigint** when the value needs one — deliberately, and the doc comment eleven lines above the annotation says so. The checker believes the annotation, so a bigint flows through a parameter declared `i64` and OUT of a user function declared to return `i64`, with no error at check time or run time. Exactly two intrinsics do this and both are in `rational.rs`. Worse than F-107 in one way: the false annotation is in wat's own surface, so every caller inherits it** · **F-121 `/` has no Clojure spelling.** `(wat.core// 7 2)` is refused as an unresolved `:wat::core/::` — the reader splits at the first slash and rebuilds the name wrong — and bare `(/ 7 2)` is refused too, while `(:wat::core::/ 7 2)` answers 3. Clojure special-cases exactly this symbol (`clojure.core//` reads fine, checked against clj 1.12.6), and wat is migrating TO that spelling, so today a Clojure-spelled file cannot divide by name |
| **Correct** (a diagnostic misleads or points the wrong way) | F-006/F-008 errors located in wat-rs's Rust or stdlib source (again: `src/check.rs:15104`, `wat/core.wat:66`) · F-007 unknown bare call name caught only at runtime · F-011 `<WatAST>` shown for both values · F-015 docstring refusal reported at the call · F-025 the non-exhaustive error suggests `_` · F-034 an f64 prints without its decimal point · F-037 an undefined function reported as a missing struct field · F-054 a definition naming itself is reported as a keyword's type error · F-040 a defstruct in a Pure enum: the containment error offers only `:wat::enum::Impure`, never `defrecord`, and is located in `src/check.rs` · the Peer `:messages` hint names `defrecord` for an enum · the "malformed form" label on `first` and `rest` of an empty collection (F-045) · F-058's refusal carries `:remedies []`, though the remedy is a single typealias · F-068 nothing says that a sqlite transaction is abandoned by passing `"ROLLBACK"` to `execute`, since the surface lists no `rollback` · C-037 the read-only write refusal names the internal `:rust::sqlite::ReadConnection` rather than the user-facing `:wat::sqlite::ReadConnection` (the F-006/F-008 family) · **F-071 the match-arm refusal says "write `<enum>::<Variant>`" — the exact spelling it just refused; the accepted form is `<enum>.<Variant>`, and its bare-variant sibling names the dot form correctly** · **F-073 `coincident?` is documented as "cosine clears the floor" and implemented as `(1 - cosine) < floor` — the opposite test, so a floor of 0.01 reads as permissive when it admits only near-identity** · F-077 `lint.wat`'s header blocks its own auto-fix on `ast-span` having no end location, while the same file's `FixEdit` record uses `ast-end-span` — which exists and works · F-078's raise says only `lex error at byte 258` and locates itself at `wat/lint.wat:586`; `source::File` carries the `:path` and `lint-file` holds the record, but the error drops it, so the offending file must be found by grepping the corpus outside wat · **F-091 a lex error names no file, no line and no column — only a byte offset — and locates itself inside `crates/wat-reader/src/parser.rs`, where every other diagnostic class carries `{:file :line :col :end}`. This is why F-078 needed a 532-file grep outside wat** · **F-095 the reflection section gives every return as `:wat::holon::HolonAST` — the VSA type `HolographicLru` keys on — where the verbs return `:wat::WatAST`; and it calls `extract-arg-names`' result "bare-symbol" names when they are keywords, so the one stated use case (splicing into call positions) is the one that would not work** · **F-113's other half: `assoc` on a record defers to RUN time the two mistakes the constructor catches at CHECK time — a wrong field type and an unknown field — though the declared field types are in the `defrecord` and the key is a literal keyword. The runtime messages are good ones; they arrive after the program has started** · **F-114 the refusal to put a function value in a `defrecord` calls the function type an *impure (struct) type*, explains itself entirely in terms of structs, carries no `:remedies` key at all, and locates at `src/check.rs:15086` with NO span in the user's file. Two remedies exist and neither is guessable from the text: a `defstruct` holds the function **with accessors**, an Impure enum holds it at a `match` per field. `defstruct` is the answer by the rule's own logic — F-040 says a `defstruct` may not cross a boundary and a `defrecord` may, which is exactly what is being enforced — and the message never names it. The mirror of F-040, inheriting its gap: both times the aggregate the author should have reached for is the one the diagnostic omits** · **F-122 `defrecord` should refuse a symbol name the way `typealias` does.** `typealias` says *"malformed typealias declaration: name must be a keyword; got symbol"*; `defrecord` says *"macro `:wat::core::defrecord` — program body eval failed"* caused by *"`:wat::keyword::to-string`: expected keyword, got `wat::WatAST`"* — the macro's internals leaking, naming a function the author never called |
| **Clean** (docs behind the code) | the docs never map Clojure's `defprotocol`/`extend-protocol` to `defsurface`/`extend-type` (`CLOJURE-ROSETTA.md` has neither) · the user guide's retired verb names (`:wat::core::f64::to-string`, `:wat::std::math::exp`, `:wat::core::i64::to-f64`, the `log` alias) · the cheatsheet's `first` returning an Option · no top-level doc mentions `defstruct`, or says that a `defrecord` may cross a boundary and a `defstruct` may not (F-040) · the user guide's first stdin program (§2) is refused as written · a Clojure-name to wat-route table for the koans' missing names (`vals` → `:wat::hashmap::values`, `pr-str` → `:wat::edn::write`, `atom` → a service …) · F-063 nothing says that `Result/try` propagates rather than catches, or that the only general catch is `:wat::test::run-thread` · **F-065 the rete — 134 verbs, 4154 lines, `defrule`, `defquery`, negation, existence, nine accumulators — appears in no user-facing page at all** · F-066 nothing says whether a rete closure is a set of facts or a bag of derivations, and the two count differently · F-068 a `rollback` verb: `:wat::sqlite::` has `begin` and `commit` and no way to spell the third, on a surface closed to additions · **F-070 67 of wat's own `@example` lines are written in spellings two completed migrations retired — 44 use the bare `(Vector 1 2)` constructor, 23 use `Enum::Variant` arms or a bare `:None`. The examples are the documentation, and this is a codemod rather than a judgement call** · F-072 nothing says that `bind` is its own inverse, that the inverse is lossy at ~0.82 a round, that the loss compounds, or that recovery is by nearest neighbour rather than reconstruction · **F-076 `:wat::core::format` — the idiom the linter recommends 99 times against wat's own stdlib — appears in no user-facing page; this repository wrote 339 `string::concat` calls and 0 `format` calls for want of it** · F-081 the `Written` guard's stated rationale covers 21% of what it excludes: 4,843 of 6,156 exclusions are string literals, and 0 of 80,027 `Written` facts are one, which the header never says · F-082 `grep.wat`'s header pins `wat/fix.wat Node=4316 Span=4316` beside a permanent invariant; the invariant held exactly and the number is 14.2% stale after 18 days of the file growing · **`:wat::grep::` — 489 lines, 13 verbs, the engine the formatter is built on — appears in no user-facing page (the F-065 shape)** · `:wat::rational::` — five verbs and a reader literal of its own — is named zero times across all four user-facing pages (C-047) · `:wat::runtime::argv` is `[binary script …user args]` and is named zero times in any user-facing page, though the CLI usage advertises `wat <entry.wat> [args…]` · `:wat::bracket::`, the whole parallelism layer, appears in the user-facing pages exactly once — as a **syntax specimen for binders** in the cheatsheet, not as an API (F-094) · **F-101 to hand a service address to a worker you must write `(:wat::kernel::Address :- [(:S::Op :- []) (:S::Reply :- []) :T])` — a three-parameter `Address` and two types minted by `defsurface`. All three have ZERO mentions across the guide, cheatsheet, SERVICE-PROGRAMS and rosetta; I recovered the naming rule from `wat/service.wat:1032-1051`, the macro's own internals. The bare `:wat::kernel::Address` annotation is accepted and then fails at the dial with unresolved type parameters** · **F-108 the `:wat::vector::` namespace serves `PersistentVector` and rejects the type named `Vector` — all six verbs. Given a `Vector` and a need to append, the namespace whose name matches the type is the first guess a generator makes, and it is wrong for every verb it contains; the working route is `:wat::core::`. Its `concat` diagnostic is worse still, naming `:wat::core::PersistentVector/concat`, a verb the author never wrote** · **F-109 `defclause` — one of wat's two polymorphism mechanisms, and the one that does MULTIPLE DISPATCH — appears 3 times in the user guide and 0 times in the cheatsheet, the Clojure rosetta and SERVICE-PROGRAMS. It is explained in `OP-PLACEMENT.md`, an internal design doc about where to put an operator. I reached for `defsurface` instead, because that is what the user-facing pages point at for polymorphism, and published a false finding as a result (F-109 was originally 'wat cannot express multiple dispatch'). An LLM will make the same move for the same reason. One line in the cheatsheet fixes it: surfaces dispatch on `self`, `defclause` dispatches on every argument** · **F-113 `:wat::core::assoc` updates a `defrecord` field — flavor-preserving, and **flat** in the field count where restating the other fields is linear in it (1.7x at two fields, 2.9x at five, **5.8x at nine**, because each restated field pays F-096's 6130 ns accessor). The user guide's container table has three columns — HashMap, HashSet, Vec — and Record is not one of them; the verb reference calls `assoc` *polymorphic over HashMap/Vec* when the same document's table marks `Vec`/`assoc` ***illegal***, so the one line naming the verb names the container it refuses and omits both it serves. It is recorded in `docs/COLLECTION-CAPABILITIES.md:66`, an internal grid: the F-109 shape** · **F-117 `CLOJURE-ROSETTA.md` §4 shows Clojure's `atom` beside wat's `let`-rebinding and says *"Same semantic outcomes; different mechanism"*. That is right about THREADING state and wrong about ALIASING it: no sequence of rebindings makes `var a = f; a.x = 2; print f.x;` print 2, because two names for one mutable thing is what wat's value model excludes. Crafting Interpreters needed exactly that twice — upvalues (ch25) and instances (ch27) — and both became an **index into a VM-owned table**, which then leaked and needed a **hand-written mark-sweep collector** (C-109). The honest version of that sentence distinguishes the two cases and names the index-table pattern; the EXTEND half, if wanted, is an in-process reference cell a value may hold (a spawned program costs 224 µs a message, and an `:wat::cache::Lru` cannot be a field of any value — F-114)** · **F-123 `Vector`'s `conj` is a full copy and only a source comment says so.** wat-rs has measured it — *"`(into [] (map f coll))` … was QUADRATIC: 8,112 ms at n=40,000 against 113 ms"* — and fixed the one path that comment is about, `stream->vec`, by adding `Vector/extend`. The ordinary `(conj acc x)` accumulator, which is the shape `docs/ITERATION-PATTERNS.md` teaches for building up state, still gets the quadratic with no signpost: reproduced from outside at **4142 ms vs 655 ms for `PersistentVector`** over 20000 elements |
| **Improve** (works, but slowly or narrowly) | F-057 `HashMap` and `HashSet` copy on every insert where `PersistentMap` shares (10× at 4000 entries, and widening), and nothing points the user to the sharing one — a 90000-square search takes 135 s on the copying containers and 20.6 s on the sharing ones, for a dozen lines of change · F-055 `rest` on a Vector clones it, so walking one is quadratic where `nth` is constant · F-023 `conj` clones a Vector · F-027/F-028 no tuple patterns, and nested arms never cover a variant · F-033 taking a WatAST apart copies every subtree · a Peer surface must declare every datatype its messages carry, so one datatype shared by two services is restated in each (Friction, A Little Java ch 10) · `take-nth` takes its count first, `take`/`drop` the collection · `cond` refused in a macro body where `if` is allowed · F-051 a message to a service costs about 224 µs, a hundred function calls, so a mal call on a service-held environment costs 3 ms · the interpreter's speed: 100 to 430 times the JVM (miniKanren), 13 times guile (J-Bob), over 100 times Racket (malt) · F-077 with `ast-end-span` available, `lint.wat`'s ladder auto-fix is unblocked — 84 of its 99 findings currently carry no fix · **F-069 a service consumer writes more outcome arms than logic — 56 of 182 lines, and wat-rs's own fixture lands at the same 182 with a 529-character `connect` line; there is no way to say "every other outcome is a failure" once** · F-075 the formatter runs at ~10 KB/s with an ~800 ms fixed floor per invocation (23 s for a 231 KB file); the floor is the rete network rebuilt from 54 rules every time, and caching it across formats would pay it once per process · **F-094 `bracket::map` on a thread pool reaches 1.69x where the same machine, same interpreter and same work reaches 5.90x as independent OS processes; the process locus reaches 3.38x, so the shortfall is wat's threads, not the hardware. Thread wall time grows 10.3x for 16x the work on 16 runners** · **F-096 a `defrecord` field read is 6130 ns — 5.0× a `defstruct` read of an identical one-field shape, and 17× an `:wat::i64::+` — with a control showing that carrying the record costs nothing, so the cost is the accessor. Records are the substrate's own vocabulary; one accessor pass over `probes/grep`'s 137,690 nodes is 0.84 s of accessor alone** · **F-097 F-057's missing persistent set cannot be filled by a library: Okasaki's BST in wat is 34x slower to build and 43x slower to query than the `PersistentMap`-to-`true` workaround it would replace, because any interpreted pointer structure pays ~2 µs per node — one call + one match + a comparison, exactly as `BASELINE.md` predicts. The request should be for a NATIVE persistent set** · **F-098 a `defrecord`/`defstruct` field holding a USER ENUM value is deep-copied on construction (O(n)); the identical field in an enum variant is shared (O(1)). Okasaki's batched queue, same algorithm either way: enum-carried is flat at 8755 ns/op, record-carried reaches 158808 at n=4000 and diverges — the amortized bound the structure is defined by, destroyed by the carrier. Native containers AND `:wat::WatAST` are unaffected (both flat), so only USER-defined enums are cloned — which is why none of wat's own records can trip it** · **F-105 `step : State -> State` — the registerized shape a CEK evaluator would naturally take — is ~1.9× slower than the mutually-tail-calling form it replaces, because `step` must ALLOCATE the state it returns while mutual tail calls allocate nothing (1.85×/1.84×/1.95×, and 2.05×/1.99× with the arms swapped as an order control). Worth knowing before the CEK work picks a shape; whether an allocation-free `State` closes the gap is open** · **F-120 write down what `println` does to a String.** It renders EDN: quotes, then `"` `\` newline tab and carriage return escaped, and every other byte — `é` included — passed through raw. That list is behaviour, not specification: a second implementation has to discover it by experiment, which is exactly what `elf/`'s compiler did, and the 158 bytes of machine code that reproduce it are held in place by one differential test (C-119) |
| **Extend** (missing) | F-005 no symbol spelling for types outside `wat::core` · F-013 `#_` · F-032 `λ Π Σ →` in symbols · F-035 bit operations — and **C-092 narrows where that costs**: shifting and masking are `*`, `quot` and `rem`, so a bit-field DECODER needs none; XOR/AND/OR/NOT are not expressible in arithmetic and must be walked a bit at a time · F-036 random numbers · the Clojure core names the koans reach for and wat lacks (`inc`, `dec`, `even?`, `comp`, `partial`, `list`, `merge`, `for`, `group-by`, `partition`, `case`, set operations …; the Clojure Koans table) · `first`/`rest` total, like `last` (F-045) · F-046 enumerate a HashSet · F-047 an orderable bigint · F-056 a priority queue, or any ordered collection · F-049 a raw write to stdout (a prompt, plain text) · F-050 a plain `read-line` · F-053 a stream that remembers what it forced · F-054 a definition that can name itself · a String's `reverse`, `index-of` and characters · a persistent **set**: `PersistentVector` and `PersistentMap` share structure, but a sharing set is missing, so a visited set has to be a `PersistentMap` to `true` (F-057) · an improper list, or a reader that says no at the dot rather than admitting a symbol named `.` into a list (F-059) · F-060 a bigint's `to-string`, where every other scalar has one · F-061 a regex that can report what it matched (`find`, `captures`, `replace`, split-on-pattern) — the crate is already a dependency, only `matches?` is exposed · F-062 a String's characters, `index-of`, `replace`, `split-lines`, `blank?` and `reverse`; and `split` on `""` · F-063 a catch that doesn't spawn a thread — recovery costs 1.3 ms and lives in `:wat::test::` · F-064 a stream that remembers a failure, not only a value (F-053) · F-069 whatever would let a `start`+`connect` be factored into a function, since the spawn scope law (F-052) forces every dial to be written inline · F-074 let `presence?` take a raw `Vector`, as `cosine`, `dot` and `coincident?` already do — the raw algebra's own output cannot be handed to it · PROVIDE.md's P-001–P-025 · **F-079 a `lint-files` that runs all three rules over a caller's sources: `lint-stdlib` is hardcoded to `deporder::stdlib-sources`, so outside code gets 2 of 3 from `lint-source`, and rule-zero must be reassembled from `deporder::verify` + `violations->findings` by hand** · F-081 a fact carrying a string literal's INNER span, since `Written` can never hold one and a rewriting rule over string contents is therefore impossible · **F-100 a SEPARATE memoizing suspension cell (`Susp<T>`), leaving `Stream` alone. Streams not memoizing is DELIBERATE — the Ruby `Enumerator` pattern, pull-and-discard, which makes a retained head unleakable and a 1 TB file on an 8 GB host possible. Okasaki's Part II needs force-once-*ever*-and-shared, a different type from force-once-per-traversal; materialising eagerly is not a substitute, since deferring the rotation is the whole point** · **F-102 a way to answer a held `conn-id`. `:wat::service::Outcome.NoReply` and `NoReplyAndArm` let a service withhold a reply, and nothing can ever release that caller — measured: it hangs forever. `Invocation`'s `conn-id` is "the name that outlives the round" and no verb sends to one; `Alarm` fires back into the service, not to the caller. So every blocking primitive (barrier, rendezvous, bounded buffer, lock) must be a spin** · **F-104 a positional update on a vector. `core::assoc` takes a HashMap or a Record, `map::assoc` a PersistentMap, and NEITHER vector type has one — `:wat::vector::` is six verbs (`length`/`get`/`empty?`/`conj`/`contains?`/`concat`; F-108 corrects the count and shows they ALL reject the type named `Vector`), so the persistent vector is append-only. The hand-rolled `take ++ [x] ++ drop` does not close either, because take/drop answer a Stream and there is no way back (F-088)** · **F-106 a way to SEAL a type's representation. `:wat::core::newtype` gives nominal distinctness — arithmetic on it is refused and a raw `i64` is refused where it is wanted — but its auto-minted constructor (bare name) and accessor (`<Name>/0`) resolve from ANY namespace, so any caller can unwrap and rewrap. That stops a caller confusing the type with its representation; it does not stop them depending on it, which is the invariant a library needs before it can change one. EOPL's `opaque t` (C-071) has no wat spelling, and neither has ML's `:>`. The CLEAN half: `newtype` appears twice in the user guide, both times as a bare entry in a list of form names, and the `/0` accessor is named in no doc at all** · **F-112 an integer `min`, `max`, `abs`, `clamp` and `round`. `:wat::f64::` has all five; `:wat::i64::` has comparisons and conversions and no arithmetic helpers at all, and there is no `:wat::core::min` either. Seven files in this repository define their own — `(if (< a b) a b)`, seven times — and the first place anyone needs it is the min-of-N timing harness every measurement here is required to use** · **F-115 a FIELD rest pattern, so adding a field to a variant does not edit every match on it. A variant pattern must name every field today, and the refusal is delivered as a non-exhaustiveness error whose suggested remedy is `_` — the wrong one. Chapter 21 of Crafting Interpreters gave the Lox VM a globals table and an output, and the compile then failed in the chapter-18 file, at a function that counts instructions and wants neither field. Chapters 22-29 extend VM state again each time. The ask does not touch exhaustiveness over VARIANTS, which is what this repository's no-`_` rule protects: ignoring a field is not ignoring a case** · **F-116 a vector `pop` (and a `subvec`). There is no `pop`, no `subvec`, no `butlast`; `take`/`drop` answer a Stream with no way back (F-088); so taking the top off a stack is a rebuild loop — and on the type called `Vector` that rebuild is **quadratic**, because `conj` clones (F-023, now priced): **121 ms for one pop at depth 4000**. On a `PersistentVector`, whose `conj` is flat, the same rebuild is linear (34 ms, exactly 4000 interpreted iterations and nothing else); with a `pop` verb it would be ~8 µs. A stack machine pops on almost every instruction, so this is the shape of wat's own byte-code work. **Not fixed by F-104's queued Index-assoc**, which changes an element and does not shorten a vector — two asks** · **F-118 a way to author a byte: `:wat::i64::to-u8`, or a `u8` literal, or an explicit `Bytes <-> Vector<u8>` pair. An integer literal is an `i64` and there is no conversion, so the only thing in the language that can invent a byte is `:wat::core::Bytes::from-hex` — and it is the only one that can produce a byte above `0x7f`, since a String is UTF-8. Without it wat could not author an object file, an ELF, a PNG, a zip or a wire frame. With it, it can (C-115 emits a 166-byte executable), at the cost of building everything as hex and decoding once. The CLEAN half is larger: `Bytes` is accepted where a `Vector<u8>` is declared and vice versa, which is load-bearing for all of this, and **no user-facing page mentions `Bytes` at all**** · **F-119 an intrinsic set defined independently of the evaluator, with a stated ABI, so that "wat" means one language whichever implementation runs it. wat's OS surface — `:wat::io::`, `:wat::kernel::spawn-*`, `:wat::bracket::` — is Rust implemented INSIDE the interpreter, taking evaluated `Value`s; a compiled program has no evaluator and no `Value`, only registers and a syscall instruction, and there is no layer in between. C's answer to the same question is libc. Evidence that it is live: `elf/`'s compiler grew `fork`/`clone`/`mmap`, and at that moment the language it compiles stopped being a subset of the one the interpreter runs — six programs there are checked against the interpreter and three cannot be, because it will not even resolve them (C-118)** · **F-120 a byte-length verb for String.** `:wat::string::length` counts CHARACTERS — `"é"` is 1 — and nothing in the string surface measures bytes, so any code that has to lay a string out in memory either restricts itself to ASCII or reimplements UTF-8 length first. `elf/`'s compiler restricts itself, and refuses the rest (`elf/bad/nonascii.wat`) · **F-122 accept a symbol name in `defrecord` and `typealias`**, the way `defn` already accepts `user/main`. Today a Clojure-spelled program can be written right up to the point where it declares a type, and then has to switch to the keyword spelling — for the two forms that introduce every data structure it has |

**Codemod hazards** (for the Clojure/EDN syntax migration), most serious first:
- **F-014:** calls written with a symbol head are **not type-checked at startup**: neither
  arity nor argument types. Definitions still are. Converting to the Clojure/EDN spelling
  silently turns off call checking everywhere.
- **F-024:** to the checker, `wat.core/let` is not a let. Its binding vector is checked as a
  vector literal (so `[a 1 b "x"]` is refused, naming the retired `:wat::core::vec`), and its
  body is checked without the bindings. A type error in the body surfaces only at runtime.
- **F-012:** `(wat/load-file! …)` is a silent no-op: no load, no error, even for a missing
  file.
- **F-003:** a `wat.test/deftest` is silently skipped (zero tests, still green).
- **F-004:** `()` inside `wat.core/quote` is refused; the keyword quote is fine.
- **F-005:** there is no symbol spelling for types outside `wat::core` (e.g. `:wat::WatAST`).
- **F-009:** a `wat.type/HashMap` constructor passes the checker and fails at runtime.
- **F-010:** inside `wat.core/fn`, a function-typed parameter is misread as a vector literal.
- **F-017:** `wat.core/match` misreads its `[pattern body]` arms as vector literals, so every
  match breaks (loudly, with a misleading message).
- **F-018:** `(wat.core/def u/x …)` defines nothing, and reports its own name as an unresolved
  reference.
- **F-022:** `wat.core/defmacro` defines nothing. With a keyword name the definition passes
  silently and only the calls fail.

**Other defects:**
- **F-001:** every debug build panics during startup (`Option`/`Result` registered twice).
- **F-002:** a newly added `wat-tests/` file is never discovered (a false green).
- **F-006 / F-008:** some diagnostics point into wat-rs's own Rust source, with no user
  file or line. Seen again in the Little Learner: the Pure-enum containment rule is located
  at `src/check.rs:15104`, and an i64 overflow at `wat/core.wat:66` rather than at the
  user's call (F-035).
- **F-007:** an unknown *bare* call name passes the checker and fails only at runtime.
- **F-008:** a `<` in a name is a lex error (fallout from retiring turbofish).
- **F-009 (second defect):** a constructor applied to a function's own type variables fails
  at runtime. Hit twice more in the Clojure Koans. `(Vector :- [T] x x)` in a generic defn
  passes the checker and dies with "malformed :wat::core::Vector form: first argument must be
  a `(Head :- [T …])` type form" (`probes/koans/generic-vector-constructor.wat`). The idioms
  work around it with one copy per type (`iterate`), or by passing the empty collection in
  (`group-by`).
- **F-011:** a failing `assert-eq` on quoted data shows `<WatAST>` for both values.
- **F-013:** the reader does not implement `#_` (EDN's discard).
- **F-015:** `defn` with a docstring is refused. When the fn is called, the only error is
  "unresolved" at the call site.
- **F-016:** a flat Clojure `cond` crashes inside the cond macro, with no hint about the
  clause syntax.
- **F-019:** a variant constructor inside a collection or stream literal keeps its narrowed
  type, and type arguments unify invariantly, so `[(Option.Some {…})]` is not a
  `Vector<Option<i64>>`. It reaches further (A Little Java ch 5): `(= (FishD.Anchovy {})
  (FishD.Tuna {}))` is refused, inline or let-bound, and a generic pie of an anchovy and a
  tuna won't unify. Two values of one enum can't be compared.
- **F-020:** a bare user-enum unit variant (`:u::T.Nil`) is typed as a nullary function
  everywhere, contradicting the checker's own comment. Only `(:u::T.Nil {})` works.
- **F-021:** in a program-body macro, `~@` refuses a vector-form argument that a pure
  template splices fine.
- **F-023:** `conj` onto a `Vector` clones it, so Clojure's `[]` + `conj` accumulator is
  O(n²). `PersistentVector` or stream fns with one `into` are the linear routes.
- **F-025:** `match` treats a `_` arm, a bare binder `[v …]` or a hash-destructure as
  covering every variant, and its non-exhaustive error suggests adding `_`. That goes
  against the doctrine that an arm cannot be forgotten.
- **F-026:** the retired nested pattern `(Variant binders…)` passes the checker, and fails
  at runtime only when some input reaches that arm, so it can ship.
- **F-027:** a `match` arm cannot destructure a tuple (tuple patterns are legal only inside
  a variant's field), and a match on a tuple can be exhaustive only through `_` or a
  binder.
- **F-028:** nested arms never count as covering a variant, even when together they cover
  it completely, so the checker demands a binder fallback: a catch-all one level down.
- **F-029** (hit again in A Little Java ch 6–7, in the visitor pattern's own shape): a
  generic fn over `(Surface :- [T])` refuses a non-generic type that extends
  the surface at a concrete argument. Stone 118.3-B's bind-then-unify covers only
  parametric actual types, so an ML functor over a signature cannot be written once.
- **F-030:** printing a newtype value panics the Rust runtime
  (`wat-edn/src/value.rs:328`, `Keyword::new("0")`): its field is named `0`.
- **F-031:** the checker accepts `:wat::core::length` on a String, even in the keyword
  spelling; only the runtime refuses it, naming the six types it accepts. (Hit a second
  time, by accident, writing `probes/typer/value-copy-cost.wat`.)
- **F-033:** taking a WatAST apart copies it. `ast->children` deep-copies every child
  subtree (a WatAST owns `Vec<WatAST>`; only the root is behind an `Arc`), so code-as-data
  programs pay a tree's whole size per destructure. Native enums share their fields.
- **F-034:** an f64 prints without its decimal point (`100.0` as `100`, `1e21` as 22
  digits), both from `:wat::f64::to-string` and in failure records, so a printed float
  reads back as an integer. Clojure and Racket print `100.0`.
- **F-035:** integers have no bit operations: no and, or, xor, not, shift or wrapping
  arithmetic, in any namespace. Xorshift, splitmix, PCG, hashes, checksums and bit-field
  parsing can't be written. Met again in `aoc/day04-binary.wat`, a puzzle about the bits of a
  thousand binary numbers: the Clojure reference says it with `bit-xor` and a shift, and the
  wat solution builds every number by doubling and takes the complement as
  `(2^width - 1) - n`. The answers match; the operations the puzzle is about are absent.
- **F-036:** there are no random numbers, not even a seeded generator.
- **F-038:** a builtin verb (Rust-implemented, e.g. `:wat::i64::to-string`) used as a
  function value: the checker refuses it passed to `foldl`, but passes it to `mapv` and as a
  let-bound local that is then called; both of those fail only at runtime.
- **F-039:** an `extend-type` that leaves out one of the surface's features passes the
  checker; calling the missing feature fails only at runtime (`UnknownFunction`). Java
  refuses to compile such a class.
- **F-040:** a `defstruct` of two i64s inside a Pure enum is refused as an impure type that
  "cannot be reconstructed from EDN bytes". The error's only suggestion is to make the enum
  `:wat::enum::Impure`; the actual fix, declaring the point with `defrecord`, is never named. It
  is located at `src/check.rs:15104`.
- **F-041:** `:wat::core::str` takes exactly one argument, and a call with more passes the
  checker in either spelling; Clojure's `str`, and wat-rs's own parity corpus, are variadic.
- **F-042:** the reader takes `#(…)` as the symbol `#` followed by a list, and the program
  fails only when it runs ("unbound symbol: #").
- **F-043:** a map literal in call position passes the checker, and fails at runtime as a
  "malformed map form".
- **F-044:** a keyword lookup, `(:k m)`, answers an Option but isn't typed by the checker, so
  `(= 2 (:y m))` passes in the keyword spelling and dies at runtime.
- **F-045:** `first` and `rest` die on an empty collection, labelled a malformed form, while
  `last` answers an Option.
- **F-046:** a HashSet's elements can't be reached: `foldl` and `into` refuse it, and its
  namespace has only `conj`, `contains?`, `empty?` and `length`. So there are no set
  operations.
- **F-047:** a bigint is not orderable (`<` refuses it), so big integers can be computed but
  not compared.
- **F-048:** a record's accessor passed to a generic function binds T to `:wat::core::Record`,
  so a call that also passes a `HashMap` of the record is refused.
- **F-049:** a wat program can't write raw text to stdout. `println` writes EDN (a String
  comes out quoted), always ends the line, and the raw writers are restricted to the kernel.
  So no prompt and no plain text.
- **F-050:** stdin is read by EDN frame. A line that opens more than it closes swallows the
  lines after it, and end of input then panics ("disconnected") instead of answering `Eof`.
- **F-051:** a message to a service costs about 224 µs, against under 2 µs for a function
  call. So a mal call whose environment lives on a service, as the doctrine keeps state,
  costs 3 ms.
- **F-052:** a function can't declare a connected peer as its return type, so every service
  client writes its connect inline.
- **F-053:** a forced lazy stream doesn't remember: one stream value walked twice computes
  every element twice, where Scheme's `delay` and Clojure's lazy seqs compute it once.
- **F-054:** a definition that names itself reads its own name as a keyword literal, and the
  error is a type mismatch about a keyword.
- **F-055:** `rest` on a Vector clones what is left of it, so walking one is quadratic: 20000
  elements take 4.9 s by `rest` and 0.25 s by `nth`. `conj` clones too (F-023).
- **F-056:** there is no ordered collection — no sorted set, sorted map, priority queue or heap
  — only `sort` over a whole collection, so a frontier can't be kept in order as it grows.
- **F-057:** `HashMap` and `HashSet` copy on every insert (twice the entries, four times the
  time), while `PersistentMap` shares structure and stays linear — ten times faster at 4000
  entries. Nothing points a user from the first to the second.
- **F-058:** a `PersistentMap` constructor refuses a bracketed type that is not a keyword, so a
  map of vectors — the shape F-057's own advice leads to — must be spelled through a typealias,
  where the `HashMap` twin accepts the nesting directly.
- **F-062:** a String cannot be taken apart — no characters, `index-of`, `replace`,
  `split-lines` or `blank?`; `reverse` refuses a String and `split` refuses `""` — and the one
  substitute, a one-character `subs`, costs about 16.7 µs, eight times a function call. The
  char-indexing is not the cause: 80000 calls at index 0 cost 1340 ms against 1661 ms walking.
- **F-061:** the whole regex surface is `matches?`, a bool. A capture group compiles and matches
  and can never be read, though wat-rs depends on the entire `regex` crate.
- **F-059:** wat has no dotted pair. `(?i . ?rest)` reads as a `"list"` of three children, the
  middle one a symbol named `.`, and then prints back as `(?i . ?rest)` — so an improper list is
  silently a different structure that round-trips unchanged. It is why The Reasoned Schemer
  built `:rs::Term`, and why PAIP's membership clauses cannot be written.
- **F-037:** a call to an undefined keyword-named function, with a struct as its argument, is
  reported as a missing field on that struct ("field `ll::naked-gradient-descent` is not
  declared on `:ll::Hypers`"). The real cause, an unresolved function, isn't mentioned.
- **F-032:** the lexer rejects `λ`, `Π`, `Σ`, `→` in symbols but accepts `é`, and its
  error is located in `crates/wat-reader/src/parser.rs` with a byte offset, not in the
  user's file and line.

## Classes

- **GAP**: wat cannot express something it arguably should. A candidate for wat-rs work.
- **REFUSAL**: wat deliberately excludes it (a stated doctrine). Record the doctrine and the
  canonical wat route; do not file it as a bug.
- **CLEAN**: the chapter ports directly.

## Entry format

Each entry names: the book and chapter; what the chapter needs; what wat did, with the
checker's or runtime's diagnostic quoted verbatim; the class; and the repro file under
`wat-tests/`. An entry without a repro that runs is a prediction, not a finding.

## Findings

### F-001: a debug build of any wat runtime panics during setup of its type registry

- **Where:** before any book, on the outside-consumer path. A minimal sibling crate
  (`wat::test! {}`) runs one trivial deftest under `cargo test`, which uses cargo's default
  debug profile.
- **What happened** (2026-09-14, wat-rs `a3218644d`), verbatim:
  ```
  thread 'wat-test:::friedman::smoke::one-plus-one' panicked at …/wat-rs/src/types.rs:660:9:
  builtin leaf :wat::core::Option already registered as a structured TypeDef
  ```
- **Root cause** (read in wat-rs source this session):
  - `src/types.rs:1507` has registered `:wat::core::Option` structurally from `wat/core.wat`'s
    `defenum` since `1bdebac54` (2026-09-06, arc 296 H-3, "Option and Result live in wat").
  - `src/check.rs:1009–1011`: `BARE_CONTAINER_HEADS` still lists `Option` and `Result`.
  - `src/types.rs:2556` passes every `BARE_CONTAINER_HEADS` entry to `register_builtin_leaf`.
  - Its `debug_assert!` (`src/types.rs:660`) refuses a name already in `types`. `Result`
    would trip the same assert once `Option` is fixed.
  - Release builds compile `debug_assert!` out, and wat-rs's floor runs only `--release`, so
    the floor never sees it.
- **Class:** GAP. This is a wat-rs bug, not a language limit. Relay it to wat-rs; don't patch
  it from this repo.
- **Workaround here:** test in release (`cargo test --release`), as wat-rs's floor does. The
  same smoke deftest passes there: `deftest_friedman_smoke_one_plus_one ... ok`, 1 passed.
- **Repro:** `wat-tests/smoke.wat` under plain `cargo test`.

### F-002: a `.wat` file added to `wat-tests/` is never run, and the suite stays green

- **Where:** the outside-consumer path, `wat::test! {}`.
- **What happened:** two files were added to `wat-tests/` in an already-built crate.
  `cargo test --release` finished in 0.22s without recompiling. It ran only the old deftest
  and reported `1 passed`, all green. The new files were never discovered.
- **Root cause** (read in wat-rs source this session):
  - The macro lists `wat-tests/` once, when it expands (`crates/wat-macros/src/discover.rs:273`).
  - It marks each file it found with `include_bytes!` (`crates/wat-macros/src/lib.rs:969–995`).
    So cargo notices when an existing file's contents change.
  - Nothing tells cargo to watch the directory itself, so a new or removed file triggers
    nothing.
  - The comment there says "including adding/removing deftests", which holds only for
    deftests inside files that already exist.
  - Inside wat-rs this is hidden: any `src/` edit recompiles the test crates anyway.
- **Class:** GAP (a wat-rs bug). It produces a false green, the worst kind of failure.
- **Fixed here:** `build.rs` re-runs whenever `wat-tests/` changes and exports the file
  listing, which `tests/test.rs` reads with `env!`. Verified 2026-09-14 by adding
  `wat-tests/smoke-rebuild.wat` to a built crate with nothing else touched: cargo
  recompiled, and 3 tests ran where there had been 2.
- **Repro:** add any `.wat` deftest file with `build.rs` removed.

### F-003: a deftest spelled `wat.test/deftest` is silently skipped

- **Where:** deftest discovery, the syntax migration's blast radius.
- **What happened:** `wat-tests/smoke-clojure-deftest.wat` defines
  `(wat.test/deftest friedman.smoke/clojure-deftest …)`. Discovery found zero tests in it,
  with no error or warning, and the suite passed.
- **Root cause:** discovery accepts only a keyword head (`discover.rs:323`) matching one
  of the four `:wat::test::deftest*` strings (`:355–358`), with a keyword name (`:360`).
  A symbol head never matches.
- **Class:** GAP. ⚠ **Relay this to the codemod work:** a codemod that respells deftests
  to `wat.test/deftest` before discovery accepts symbol heads would silently drop every
  converted test. The suite would go quiet and stay green.
- **Here:** deftests stay in the keyword spelling until discovery accepts the new one.
- **Repro:** `wat-tests/smoke-clojure-deftest.wat` (adds zero tests; check the count).

### C-001: the Clojure/EDN `defn` spelling works

- `(wat.core/defn u/some-fn [x :- wat.type/i64 y :- wat.type/i64] :- wat.type/i64 (wat.core/+ x y))`
  type-checks and runs. `(u/some-fn 40 2)` equals 42 (`deftest_friedman_smoke_clojure_defn ... ok`).
- **Class:** CLEAN.
- **Repro:** `wat-tests/smoke-clojure-defn.wat`.

### C-002: a fully Clojure/EDN program runs under the `wat` binary and asserts loudly

- `(wat.core/defn user/main [] :- wat.type/nil …)` is found and run as the entry point.
- `wat.test/assert-eq` works in a program. On failure it exits **2**, with a structured
  `#wat.kernel/AssertionFailure` naming `:actual`, `:expected` and the file and line.
  The negative control, `probes/assert-fail.wat`, asserts 42 = 43 on purpose.
- This is why the chapters are programs run as `wat <file>` rather than deftests: no
  second build of wat, and F-001 to F-003 don't apply.
- **Class:** CLEAN.
- **Repro:** `probes/main-symbol.wat`, `probes/assert-pass.wat`, `probes/assert-fail.wat`.

### C-003: cons on quoted lists works as quasiquote plus splice

- `(wat.core/quasiquote (~x ~@l))`, with `x` = `'x` and `l` = `'(a b c)`, equals
  `'(x a b c)`.
- It also takes a list as the first element: `` `(~'(a) ~@'(b)) `` equals `'((a) b)`.
- **Class:** CLEAN.
- **Repro:** `probes/sexp-cons.wat`.

### F-005: the Clojure/EDN spelling has no name for types outside `wat::core`

- **Where:** type annotations in a `wat.core/defn`. Every S-expression function needs one,
  because the S-expression type is `:wat::WatAST`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `wat.type/WatAST` is refused: `annotation names unknown type :wat::core::WatAST`.
    `wat.type/X` always means `:wat::core::X`.
  - `wat/WatAST` is refused too. The resolver reads it as `:wat::WatAST` but
    classifies it as `namespaced symbol ref — not a builtin, not a registered function
    (arc 251)`.
  - The keyword `:wat::WatAST` works in the `:-` slot of a Clojure/EDN defn.
- **Verified spellings:** `wat.type/i64`, `wat.type/bool`, `wat.type/String` and
  `wat.type/nil` work. Only `WatAST` was tested among the non-core types; `HolonAST` and
  the `wat::kernel` types are expected to behave the same but are unverified.
- **Class:** GAP, in the syntax-migration surface. ⚠ Relay to the codemod work: there is no
  symbol spelling for a type outside `wat::core` yet.
- **Here:** type slots use the keyword `:wat::WatAST` for now.
- **Repro:** `probes/type-watast-core.wat`, `probes/type-watast-slash.wat` (both refused),
  `probes/type-watast-kw.wat` (works).

### F-006: an unknown-type error points into the checker's own Rust source

- **What happened:** the type error for `wat.type/WatAST` carries
  `:location #wat.core/Span {:file "src/check.rs" :line 15141 :col 13 :end #wat.core/Option.None {}}`.
  That is a line in wat-rs's checker, not the offending line of the user's `.wat` file.
  The user is told what is wrong but not where.
- **Class:** GAP (diagnostic quality). Other startup errors here point at the user's file
  correctly (e.g. F-004's, and F-005's `wat/WatAST` case).
- **Repro:** `probes/type-watast-core.wat`.

### C-004: Little Schemer ch 1 (Toys) ports cleanly

- `atom?`, `car`, `cdr`, `cons`, `null?` and `eq?` are defined over quoted S-expressions
  (`:wat::WatAST`), with 15 checks. Output: exit 0, `"little-schemer ch01 toys: ok"`.
- Everything is a thin wrapper over a wat primitive:
  - `atom?` is `ast-kind` ≠ `"list"`
  - `car` is `first`, `cdr` is `rest`
  - `cons` is quasiquote plus `~@`
  - `null?` is `empty?`, `eq?` is `=`
- The only friction was writing the empty list (F-004) and the type spelling (F-005).
- **Class:** CLEAN, with F-004 and F-005 as workarounds.
- **Repro:** `books/little-schemer/ch01-toys.wat`.

### F-004: an empty list inside `wat.core/quote` is refused as a retired unit literal

- **Where:** Little Schemer throughout. `'()` is the book's most common value.
- **What happened** (2026-09-14, wat-rs `a3218644d`), verbatim:
  > `bare unit value '()' is retired (arc 179); `nil` is the sole unit value. An empty list literal `()` in expression position is no longer a second spelling of unit.`
- **Scope** (verified):
  - `(wat.core/quote ())` is refused.
  - `(wat.core/quote (a () b))` is refused. So is `()` anywhere inside symbol-quoted data.
  - `(:wat::core::quote ())`, the keyword spelling, **works**: `ast-kind` is `"list"` and
    `empty?` is `true`.
  - `(:wat::core::quote (fig ()))`, with `()` **nested** in keyword-spelled quote, also
    works: 2 elements, the second a `"list"` (`probes/quote-empty-keyword-nested.wat`).
  - So only the Clojure spelling of quote is affected, top level and nested alike.
- **Root cause** (partly read):
  - `infer_quote` (`src/intrinsic/special/quote.rs:97–99`) states its argument "is DATA, not an
    expression — the type checker does not recurse into it."
  - The error is raised in one place only: `infer_list`, on an empty list
    (`src/check.rs:2613–2620`).
  - So with the symbol spelling, some checker path infers the quoted contents before (or
    instead of) reaching `infer_quote`. Which path: **unverified**.
- **Class:** GAP. Arc 179 retired `()` in *expression* position; quoted data is not an
  expression. ⚠ Relay to the codemod work: respelling `:wat::core::quote` as
  `wat.core/quote` turns every quoted empty list from working into a startup error. That
  failure is loud, unlike F-003.
- **Workarounds here:**
  - Build it as `(wat.core/rest (wat.core/quote (x)))`: ch 1's `ls/empty-list`. This one
    survives the respelling.
  - The keyword `(:wat::core::quote ())` works today, but breaks once respelled.
- **Repro:** `probes/quote-empty-symbol.wat` and `probes/quote-empty-nested.wat` (refused);
  `probes/quote-empty-keyword.wat` (works).

### C-005: the Y combinator works (Z, typed through a self-referential struct)

- **Where:** Little Schemer ch 9 derives Y; the applicative-order form is Z.
- **What happened** (2026-09-14): `probes/z-combinator.wat` exits 0 and prints `120`,
  factorial of 5 through Z. No function in it refers to itself by name.
- **How:** `(:wat::core::defstruct :u::Knot [unroll <- [:u::Knot :-> [i64 :-> i64]]])`
  is a struct whose only field is a function that takes the struct itself. This is the
  standard typed stand-in for self-application (Haskell: `newtype Mu a = In (Mu a -> a)`).
  wat accepts the self-referential type, function-typed fields, closures and higher-order
  calls.
- The textbook `(lambda (x) (x x))` cannot be written directly. A `fn` parameter must be
  annotated, and `x` would need an infinite type. That is true of every
  annotation-required typed language, so it is not a wat gap.
- This **overturns the prediction** made from ITERATION-PATTERNS.md: anonymous recursion
  works.
- **Class:** CLEAN.
- **Repro:** `probes/z-combinator.wat`.

### F-007: an unknown bare call name passes the checker and fails only at runtime (found via a self-calling let-bound fn)

- **Where:** Seasoned Schemer ch 12's `letrec` job: a local helper that recurses.
- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/letrec-let-bound-fn.wat`
  binds `fact` to a `fn` whose body calls `fact`. Startup (type check) **accepts** it. The
  run then dies, exit 1:
  ```
  #wat.runtime/UnboundSymbol {:message "unbound symbol: fact" :location … {:file "probes/letrec-let-bound-fn.wat" :line 10 :col 33 …} :name "fact"}
  ```
- **Why it matters:** local self-recursion being refused is doctrine
  (ITERATION-PATTERNS.md: "Anonymous local recursion — NOT SUPPORTED"). The problem is
  where it is refused. The checker lets through a program the runtime cannot run. An
  unresolved name should be a startup error; the checker and runtime disagree on it.
- **Scope: wider than letrec.** A call to a name that exists *nowhere* behaves the same
  way. Probed 2026-09-14:

  | where the unknown call sits | caught |
  |---|---|
  | bare `(zzz 5)` directly in `main` | only at runtime, exit 1 (`probes/unknown-bare-in-main.wat`) |
  | bare `(zzz n)` in a top-level `defn` body | only at runtime (`probes/unknown-bare-in-defn.wat`) |
  | bare `(zzz n)` in a let-bound `fn` body | only at runtime (`probes/let-fn-unknown-symbol.wat`) |
  | bare `(h n)`, `h` bound *later* in the same `let` | only at runtime (`probes/let-fn-later-binding.wat`) |
  | namespaced `(u/zzz n)` in a let-bound `fn` body | **at startup**: `namespaced symbol ref — not a builtin, not a registered function (arc 251)` (`probes/unknown-ns-in-fn.wat`) |

  So a **bare** (non-namespaced) call head is not resolved at startup anywhere, while a
  namespaced one is resolved everywhere. The `letrec` case is one instance. A typo in any
  bare call passes the check and fails only when that line runs. Mechanism (unverified):
  an unknown bare head likely gets a fresh type variable, not an error.
- **The fix is independent of `letfn`:** a bare call head must name something in scope (a
  `let` binding or a `fn` parameter), or startup fails, as namespaced references already do.
  Under the Clojure/EDN syntax bare names are *only* ever locals, so every unresolved bare
  head is a typo.
- **Class:** GAP (checker/runtime disagreement). Refusing local self-recursion is doctrine;
  refusing it (and every other unbound bare name) only at runtime is the gap.
- **Repro:** `probes/letrec-let-bound-fn.wat`, plus the four scope probes above.

### R-001: a named fn, `(fn fact [n] …)`, is refused

- **What happened:** refused at startup, located:
  `malformed :wat::core::fn form: fn signature: expected a vector [name <- :T ...] as the args-vector; got symbol`
  (`probes/letrec-named-fn.wat`, line 6).
- **Doctrine:** ITERATION-PATTERNS.md, "Anonymous local recursion — NOT SUPPORTED …
  If your function deserves to recurse, it deserves a name." There is no `letrec` or `letfn`
  either (none appears in the checker or stdlib).
- **Canonical route:** a top-level `defn`, taking as parameters whatever the local helper
  would have closed over. Or Z (C-005), now proven.
- **Class:** REFUSAL.
- **Repro:** `probes/letrec-named-fn.wat`.

### C-006: letcc's escape use (early exit) ports cleanly via `Result/try`

- **Where:** Seasoned Schemer ch 13–14. The book's main use of `letcc` is to abandon all
  pending work and answer now.
- **How:** `:wat::core::Result/try` works like Rust's `?`. An `Ok` unwraps; an `Err`
  returns from the innermost enclosing function, which must be declared to return a
  `Result` (`check.rs` `infer_try`). A recursive helper that returns a `Result` therefore
  propagates an `Err` through every frame, skipping each frame's pending work. The caller
  that matches on the `Result` is the letcc point.
- **What happened** (2026-09-14): `probes/letcc-early-exit.wat` multiplies a vector by
  non-tail recursion. Each frame prints its element only after its `Result/try` returns.
  - `[2 3 4]` prints `4 3 2` and returns 24.
  - `[2 3 0 5]` prints nothing and returns 0: the `Err` from the 0 skipped both pending
    multiplications, and the 5 was never visited.
- **Not covered:** Seasoned Schemer ch 19 saves continuations and re-enters them
  (generator-style). That is not an escape and has no Clojure analogue. The wat candidates
  are a stream or a service. Untested.
- **Class:** CLEAN (escape use).
- **Repro:** `probes/letcc-early-exit.wat`.

### C-007: numbers convert both ways between `i64` and quoted-AST nodes

- **Where:** Little Schemer ch 4. Tuples are quoted lists of numbers, and each element is
  an AST node (syntax), not an `i64`.
- **What happened** (2026-09-14):
  - `i64` → node: `` `~n `` with `n` = 5 equals `'5`, and `` `(~n ~@'(6 7)) `` equals
    `'(5 6 7)` (`probes/num-to-ast.wat`: `true true`).
  - node → `i64`: `(Result/expect (:wat::eval-ast! node) "…")` on the `5` of `'(5 6)`,
    plus 7, prints `12` (`probes/ast-to-num-eval.wat`).
- **Note:** the stdlib does node → `i64` by printing and re-parsing:
  `(:wat::string::to-i64 (:wat::core::write-forms n))` (`wat/core.wat:536`). There is no
  dedicated accessor, but `eval-ast!` makes one unnecessary.
- **Class:** CLEAN.
- **Repro:** `probes/num-to-ast.wat`, `probes/ast-to-num-eval.wat`.

### F-008: a `<` anywhere in a name is a lex error, and the error names no file or line

- **Where:** Little Schemer ch 4, which names its less-than `<`. Written in wat as `ls/o<`.
- **What happened** (2026-09-14, wat-rs `a3218644d`): the whole program was refused at
  startup:
  > `lex error at byte 1015: angle-bracket type parameters are illegal in a name (arc 109, "annihilate the angle bracket"): `<` may not open a type head.`
- **Scope** (verified):
  - `u/o>` lexes and runs (`probes/name-gt.wat`: `true`).
  - `u/o<` is refused (`probes/name-lt.wat`).
  - Clojure allows `<` in symbols (`<!!`, `<=`, `a<b`). So this is also a migration
    concern: a Clojure name containing `<` will not lex.
- **The diagnostic** gives only a byte offset. Its `:location` is the lexer's own source
  (`crates/wat-reader/src/parser.rs:201`), not the user's file. The program loaded two
  files, and nothing said which one held byte 1015; it turned out to be the entry file.
  This is the same class as F-006.
- **Why:** arc 109 retired `Name<T>` type syntax and turbofish (`name::<T>`). The lexer
  still refuses any `<` after name characters, to catch the old spellings, which also
  catches legitimate names. The builder's diagnosis, 2026-09-14: this is very likely
  fallout from making turbofish illegal.
- **Class:** GAP, in two parts: the lexer rule is broader than its purpose, and the
  diagnostic has no file or line.
- **Here:** the book's `<` is named `ls/less?`.
- **Repro:** `probes/name-lt.wat` (refused), `probes/name-gt.wat` (works).

### F-009: two collection-constructor spellings pass the checker and fail at runtime

- **Where:** generic ("data parametric") functions. The builder's example, 2026-09-14:
  ```
  (wat.core/defn u/kv-fn :- [K V] [k :- K  v :- V] :- (wat.type/HashMap :- [K V])
    (wat.type/HashMap :- [K V]))   ;; empty typed hash-map
  ```
- **What happened** (wat-rs `a3218644d`). Every case passes startup (the type check). Results:

  | constructor in the body | runtime |
  |---|---|
  | `(wat.type/HashMap :- [K V])` (the builder's example) | `unknown function: :wat::type::HashMap` (`probes/generic-kv-fn.wat`) |
  | `(wat.type/HashMap :- [wat.type/keyword wat.type/i64])`, no generics | `unknown function: :wat::type::HashMap` (`probes/ctor-wat-type-concrete.wat`) |
  | `(:wat::core::HashMap :- [K V])`, the keyword spelling, over the fn's type variables | `malformed :wat::core::HashMap form: first two arguments must be type keywords or (Head :- [args]) type forms (K, V); first argument is not one` (`probes/generic-kv-fn-kwctor.wat`) |
  | `(:wat::core::HashMap :- [:wat::core::keyword :wat::core::i64])`, keyword, concrete | **works**: `0` (`probes/ctor-kw-concrete.wat`) |
  | `{}` typed by the fn's return annotation, inside the generic fn | **works**: `0`, `true` (`probes/generic-kv-fn-literal.wat`) |

- **Two separate defects:**
  1. `wat.type/X` in **constructor** (value) position is not callable at runtime. In type
     position the same spelling resolves (F-005: `wat.type/X` means `:wat::core::X`). The
     runtime looks up `:wat::type::HashMap` literally.
  2. A constructor applied to the enclosing function's **type variables** fails at runtime.
     `K` and `V` are not concrete there, and the constructor needs them to be.
- **Class:** GAP ×2 (checker/runtime disagreement, like F-007). ⚠ Relay to the codemod
  work: respelling `:wat::core::HashMap` constructors as `wat.type/HashMap` turns working
  code into failures that only show up at runtime; the startup check stays clean.
- **Workaround:** an empty literal (`{}`, `[]`, `#{}`) typed by the surrounding
  annotation, as in ch 4's `[]` and `probes/generic-kv-fn-literal.wat`.
- **Repro:** the five probes named in the table.

### C-009: first-class functions are clean: values, closures, currying, multi-argument types

- **Where:** Little Schemer ch 8 (Lambda the Ultimate): functions passed in, returned,
  and used as collectors.
- **What happened** (2026-09-14). All in the Clojure/EDN spelling; each probe exits 0:
  - A two-argument function type, `[:wat::WatAST :wat::WatAST :-> wat.type/bool]`, as a
    parameter and called with `(col x y)` (`probes/fn-type-two-args.wat`). Live wat-rs uses
    the same shape, e.g. `[U T :-> U]`.
  - A named function passed as a value by its symbol, `(u/apply2 u/same? …)`
    (`probes/named-fn-as-value.wat`).
  - `(wat.core/fn [x :- T] :- R …)` returning a closure over the enclosing argument, the
    curried `eq?-c`, prints `true` then `false` (`probes/curried-closure.wat`).
  - Calling a call's result directly, `((u/eq?-c 'pear) 'pear)`
    (`probes/call-result-as-head.wat`).
  - `&` is legal inside a name, `u/a&b`, although a bare `&` marks rest arguments
    (`probes/name-ampersand.wat`).
- **In use:** all 20 checks of Little Schemer ch 8 pass on the first run. They include
  collectors generic over their result type `T`, closures nested two deep inside generic
  functions, named functions returned from `cond` arms, and `quasiquote` building a result
  inside a collector.
- **Class:** CLEAN.
- **Repro:** the probes above, and `books/little-schemer/ch08-lambda-the-ultimate.wat`.

### F-010: in `wat.core/fn`, a function-typed parameter is misread as a vector literal

- **Where:** Little Schemer ch 9. Y's argument is a lambda that takes a function; so is
  any Clojure-spelled lambda with a function parameter.
- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/fn-typed-param-clj.wat` is
  refused at startup, at the bracketed type (line 5, col 48):
  > `:wat::core::vec: parameter #4 expects :wat::core::keyword; got (:wat::core::Vector :- [:wat::core::keyword])`
  with a remedy about renaming the retired `:wat::core::vec`.
- **Controls:**
  - The same lambda as `(:wat::core::fn [f <- [:wat::core::i64 :-> :wat::core::i64]] …)`
    works and prints `2` (`probes/fn-typed-param-kw.wat`).
  - A function-typed parameter in `wat.core/defn` works (ch 8's `test? :- [...]`).
- **Reading** (inferred from the message): inside `wat.core/fn`'s parameter vector, the
  bracketed function type `[A :-> B]` is treated as a vector-literal expression and routed
  to the retired `:wat::core::vec`. The diagnostic names a verb the user never wrote.
- **Class:** GAP, in the syntax-migration surface. ⚠ Relay to the codemod work: converting
  `:wat::core::fn` to `wat.core/fn` breaks every lambda that takes a function. The failure
  is loud, at startup.
- **Here:** lambdas with a function-typed parameter use the keyword spelling.
- **Repro:** `probes/fn-typed-param-clj.wat` (refused), `probes/fn-typed-param-kw.wat` (works).

### C-010: a struct that is generic and self-referential works, so Y is polymorphic

- **What happened** (2026-09-14): `probes/y-generic-kwfn.wat` declares
  `(:wat::core::defstruct :u::Knot :- [A B] [unroll <- [(:u::Knot :- [A B]) :-> [A :-> B]]])`
  and a `(wat.core/defn u/Y :- [A B] …)` over it. The same `Y` computes:
  - `length` of `'(pear plum fig)` = `3` (list → `i64`)
  - `5!` = `120` (`i64` → `i64`)
- This extends C-005, which was Z at one concrete type, to a polymorphic Y.
- **Class:** CLEAN. (The first attempt, `probes/y-generic.wat`, hit F-010 in its lambdas,
  not in the struct.)
- **Repro:** `probes/y-generic-kwfn.wat`.

### C-008: mutually recursive top-level functions work, including forward references

- **Where:** Little Schemer ch 5. `eqlist?` and `equal?` call each other.
- **What happened** (2026-09-14): `ls/eqlist?` is defined first and calls `ls/equal?`,
  which is defined after it; `ls/equal?` calls back into `ls/eqlist?`. Both check and run.
  All 14 ch 5 checks pass, including equality of nested lists that contain numbers.
- **Why it matters:** this completes R-001's canonical route. With no `letrec` or `letfn`,
  top-level `defn`s carry both self-recursion and mutual recursion, in any order.
- **Class:** CLEAN.
- **Repro:** `books/little-schemer/lib/ch05-full-of-stars.wat`.

---

## Round 2: Clojure idioms and debugging ergonomics (`probes/annoy/`, 2026-09-14)

The things that were annoying while writing Little Schemer, now tested. All against wat-rs
`a3218644d`.

### F-011: a failing `assert-eq` on quoted data shows `<WatAST>` for both values

- **What happened:** `probes/annoy/assert-eq-watast-fail.wat` compares `'(pear (plum 1))`
  with `'(pear (fig 1))` and fails as it should (exit 2), but reports
  `:actual "<WatAST>" :expected "<WatAST>"`. The failure names the file and line, and
  hides both values.
- **Why it matters:** `println` renders the same value readably, as `(pear (plum 1))`
  (`probes/annoy/println-watast.wat`), so the renderer `assert-eq` uses is the gap.
  Debugging S-expression code, and macros, which are WatAST all the way down, is blind at
  exactly the moment it matters.
- **Scope:** specific to quoted data. The same failure on Vectors renders both sides
  (`"[1, 2, 3]"` vs `"[1, 2, 4]"`, `probes/annoy/assert-eq-vector-fail.wat`), and so it
  does on `i64` (`"42"` vs `"43"`, C-002).
- **Class:** GAP (diagnostics).
- **Repro:** `probes/annoy/assert-eq-watast-fail.wat`.

### F-012: the Clojure-spelled `(wat/load-file! …)` is a silent no-op

- **What happened:**
  - `probes/annoy/load-clj-missing.wat` loads a file that **does not exist** with
    `(wat/load-file! "no-such-file.wat")`. It exits 0 and prints `"ran"`: no error.
  - `probes/annoy/load-clj.wat` loads a real library that way. It then fails only at a
    later call: `unresolved reference :u::twice`.
  - The keyword spelling `(:wat::load-file! …)` loads correctly, and is idempotent
    (C-011).
- **Reading:** the symbol spelling resolves as a name, so nothing complains, but the load
  pass recognises only the keyword head. The same pattern as F-003.
- **Class:** GAP. ⚠ **Codemod hazard, silent:** converting `:wat::load-file!` to
  `wat/load-file!` drops every load without a word at the load site.
- **Repro:** `probes/annoy/load-clj-missing.wat` (exit 0), `probes/annoy/load-clj.wat`.

### F-013: the reader does not implement `#_` (EDN's discard)

- **What happened:**
  - `'(a #_b c)` prints back as `(a #_b c)`. `#_b` is kept as one token rather than
    discarding `b` (`probes/annoy/discard-inside-quote.wat`).
  - `(println #_(anything) 1)` therefore passes three arguments, and dies at runtime:
    `println: expected 1 arguments, got 3` (`probes/annoy/discard-reader.wat`).
- **Why it matters:** `#_` is how Clojure and EDN users comment out a form in place. The
  migration is to Clojure/EDN.
- **Class:** GAP (EDN conformance).
- **Repro:** the two probes above.

### F-015: `defn` with a docstring is refused, and when the fn is called the error points at the call

- **What happened:** `(wat.core/defn u/add1 "adds one" [x :- wat.type/i64] …)`:
  - **Never called** (`probes/annoy/docstring-defn-uncalled.wat`): a clear startup error at
    the `defn`, though it says `fn`, not `defn`:
    `malformed :wat::core::fn form: fn signature: expected a vector [name <- :T ...] as the args-vector; got string`.
  - **Called**, the usual case (`probes/annoy/docstring-defn.wat`): the only error is
    `unresolved reference :u::add1` **at the call site**. The resolver runs before the
    checker, so the real cause, at the definition, is never shown.
- **Class:** GAP. Docstrings are idiomatic Clojure, and the diagnostic order misleads.
- **Repro:** the two probes above.

### F-016: a flat Clojure `cond` crashes inside the cond macro's implementation

- **What happened:** `(wat.core/cond test1 "a" test2 "b" :else "c")`, Clojure's shape,
  fails at startup with the macro's internals: `macro :wat::core::cond — program body eval
  failed` → `macro_eval: runtime::eval failed` → `malformed :wat::core::rest form: cannot
  take rest of empty Vec`, located in `wat/core.wat:1488`.
- **Why it matters:** wat's `cond` takes parenthesised clauses, `((test) expr)`, unlike
  Clojure. The error tells the user nothing about that; it reports an empty-`rest` inside
  the stdlib.
- **Builder, 2026-09-14:** wat's `cond` is a known point. It will become like wat's
  `match`: a vector of `[truthy user-form]` pairs. The clause shape is an intended
  divergence ("clojure dialect != clojure impl"), so what stands here is the diagnostic.
- **Class:** GAP, for the diagnostic only.
- **Repro:** `probes/annoy/cond-flat.wat`.

### F-014: calls in the Clojure/EDN spelling are not type-checked at startup; definitions are

- **Where:** every chapter. All ten Little Schemer chapters are written in this spelling,
  so **none of their call sites was checked at startup**. They pass because the code is
  correct and the runtime assertions confirm it, not because a checker vetted the calls.
- **What happened** (each row is a probe under `probes/annoy/`):

  | same mistake | keyword spelling | Clojure/EDN spelling |
  |---|---|---|
  | wrong arity, user fn `(add1 1 2)` | startup `ArityMismatch` (`arity-user-fn-kw.wat`) | runtime only (`arity-user-fn.wat`) |
  | wrong arity, core fn `(length [1 2] [3])` | startup (`arity-core-fn-kw.wat`) | runtime only (`arity-core-fn.wat`) |
  | wrong arity, `(println 1 2)` | not probed | runtime only (`println-arity.wat`) |
  | wrong argument type, `(add1 "pear")` | startup `TypeMismatch`: `parameter #1 expects :wat::core::i64; got :wat::core::String` (`argtype-user-fn-kw.wat`) | runtime only, and not at the call: `"pear"` flows into `add1` and fails inside `+` (`argtype-user-fn-clj.wat`) |
  | wrong arity, a let-bound lambda `(f 1 2)` | startup, but only when **both** `let` and `fn` are keyword-spelled (`arity-local-lambda-kwlet-kwfn.wat`) | runtime only if **either** the `let` or the `fn` is Clojure-spelled (`arity-local-lambda-cljlet-kwfn.wat`, `-kwlet-cljfn.wat`, `arity-local-lambda-clj.wat`) |

- **What IS still checked at startup**, Clojure spelling included:
  - A `wat.core/defn` **body**: a keyword-spelled bad call inside it is caught
    (`clj-defn-body-kwcall.wat`).
  - Its **signature**: a keyword-spelled call to it with a wrong type is caught
    (`kwcall-to-clj-defn.wat`).
  - Its **return type**: `body produces :wat::core::String; signature declares
    :wat::core::i64` (`clj-defn-bad-return.wat`).
  - That namespaced names **exist** (the arc 251 resolver).
- **Mechanism** (read in wat-rs source this session):
  - `infer_list` dispatches a call by name only when its head is a **keyword**
    (`src/check.rs:2623`).
  - A symbol head falls to the value-head path (`src/check.rs:6214–6272`), which infers the
    head as a value. It checks arity and argument types (lines 6247–6269) only if the head
    infers to a `Fn` type.
  - Otherwise it returns a fresh type and skips every check. Both branches are marked
    `silent-by-intent`, assuming the failure was "already reported elsewhere" (lines 6226
    and 6242).
  - For a named function nothing reports it, and the symbol is never mapped to the
    function's declared signature. For local lambdas, a Clojure-spelled `let` or `fn`
    evidently does not carry the `Fn` type that path needs.
- **F-007 is the same path**, seen for names that do not exist at all.
- **Diagnostics:** the runtime errors for local lambdas are located at
  `src/runtime.rs:10746`, not the user's file (the F-006 class).
- **A correction, for the record:** from reading lines 6214–6272 I predicted the
  Clojure-spelled local lambda would be caught at startup. It was not. The 2×2 of `let` and
  `fn` spellings shows why.
- **Class:** GAP, and the most serious in this ledger. ⚠ **Relay first:** converting the
  corpus to the Clojure/EDN spelling would silently turn off startup checking of calls
  everywhere, while every run still reports a clean startup. A likely fix: resolve a
  symbol head to its keyword path (`u/add1` → `:u::add1`) before the keyword dispatch, and
  give `wat.core/let` and `wat.core/fn` the types their keyword twins produce.

### Friction: Clojure core forms that do not exist

- `when` and `if-let`: both are `unresolved reference` (`probes/annoy/when.wat`,
  `probes/annoy/if-let.wat`).
- `(:a {:a 1})` returns `#wat.core/Option.Some {:value 1}` where Clojure returns `1`
  (`probes/annoy/keyword-as-fn.wat`). This is a deliberate divergence (wat has no nil and
  no nil-punning), not a bug. It is still a surprise for a Clojure reader.
- A symbol-named `typealias` is refused: `name must be a keyword; got symbol`
  (`probes/annoy/typealias-clj.wat`). This is F-005's gap (no symbol names for types),
  reached from the declaration side. The keyword name works (C-011).

### C-011: `'x`, `'()`, keyword-named typealias and double loads all work

- **`'x` works, including `'()`.** `(= 'pear (wat.core/quote pear))` is `true`, and
  `'(fig ())` has 2 elements with a `"list"` second (`probes/annoy/quote-shorthand.wat`,
  `probes/annoy/quote-shorthand-empty.wat`). **This is the ergonomic workaround for
  F-004.** The shorthand takes the keyword-quote path, so `'()` is fine where
  `(wat.core/quote ())` is refused.
- **A keyword-named typealias inside the Clojure form works.**
  `(wat.core/typealias :u::Sexp :wat::WatAST)`, then `:- :u::Sexp`
  (`probes/annoy/typealias-kwname.wat`).
- **Loading the same library twice is idempotent** (`probes/annoy/double-load.wat`: `42`).
  So a lib can load its own dependencies.
- Variadic `+` works (`(wat.core/+ 1 2 3)` = `6`), and `println` renders WatAST readably.
- **Class:** CLEAN. The chapters could be much shorter with `'` and a `Sexp` alias.

---

## The Seasoned Schemer

### C-012: letrec's job ports via Y, including curried two-argument helpers

- **Where:** Seasoned Schemer ch 12 (Take Cover). The book uses letrec to hide a recursive
  helper that closes over an argument that never changes.
- **What happened** (2026-09-14): all 10 checks pass on the first run.
  - `multirember`, `member?` and `union` each hide a helper closed over `a` or `set2`.
    `ls/Y` (Little Schemer ch 9) ties the recursion, and no name refers to itself.
  - `two-in-a-row?` and `sum-of-prefixes` have two-argument helpers, so they are curried,
    and Y's result type `B` is itself a function type (`[lat :-> bool]`, `[tup :-> tup]`).
  - The top-level-helper version (R-001's canonical route) agrees with the Y version.
- **Class:** CLEAN. This extends C-010: Y works when instantiated with a function type too.
- **Repro:** `books/seasoned-schemer/ch12-take-cover.wat`.

### Friction: without letrec or letfn, a hidden helper costs its full type, written twice

- The Y version of `ss/sum-of-prefixes` writes out its helper's type
  `[:wat::core::i64 :-> [(:wat::core::Vector :- [:wat::core::i64]) :-> (:wat::core::Vector :- [:wat::core::i64])]]`
  twice, once for the Y lambda's parameter and once for its return, plus the inner
  lambdas' own types. The ch 11 top-level version of the same function needs none of that.
- A `letfn` whose local recursion is type-inferred would bring this back to the book's size.
  Whether to add one is the builder's call; this is the cost that call weighs.
- **Repro:** `books/seasoned-schemer/lib/ch12-take-cover.wat` against
  `lib/ch11-welcome-back.wat`.

### C-013: letcc's skip (abandon and restart) also ports via `Result/try`

- **Where:** Seasoned Schemer ch 13 (Hop, Skip, and Jump).
- **What happened** (2026-09-14): all 9 checks pass.
  - **The hop:** `intersectall` returns `()` as soon as any set is empty, wherever that set
    sits in the list.
  - **The skip:** `rember-upto-last` throws away every cons pending so far and restarts
    after the `a`: `'(pear plum fig plum kiwi lime)` → `'(kiwi lime)`. Finding an `a`
    returns an `Err` carrying the answer for the rest of the list. Every pending
    `(cons …)` frame is waiting in a `Result/try`, so the `Err` passes through all of
    them, and their conses never happen.
- **Class:** CLEAN. This extends C-006 from "escape with an answer" to "escape with a
  restarted computation".
- **Repro:** `books/seasoned-schemer/ch13-hop-skip-jump.wat`.

### F-017: `wat.core/match` reads its arm vectors as vector literals

- **Where:** Seasoned Schemer ch 13. Both of its matches on a `Result` failed at startup
  (4 errors).
- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/annoy/match-clj.wat`, a
  `Result` match in the Clojure/EDN spelling, is refused at startup with errors like:
  > `:wat::core::vec: parameter #3 expects [:?540 :-> (:wat::core::Result.Ok :- [:?540 :?541])]; got (:wat::core::HashMap :- [:wat::core::keyword :?543])`
- **Control:** the identical match keyword-spelled, `(:wat::core::match …)`, inside a
  Clojure-spelled `defn`, prints `5` (`probes/annoy/match-kw.wat`).
- **Reading:** the same class as F-010. Inside a Clojure-spelled special form, bracketed
  syntax (here the `[pattern body]` arms) is inferred as a vector-literal expression and
  routed to the retired `:wat::core::vec`. The diagnostic names `vec`, a `HashMap` and
  "parameter #3", none of which the user wrote, so it cannot lead anyone to the cause.
- **Class:** GAP. ⚠ **Codemod hazard:** converting `:wat::core::match` to
  `wat.core/match` breaks every match. It fails loudly, at startup, but misleadingly.
- **Here:** matches are keyword-spelled.
- **Repro:** `probes/annoy/match-clj.wat` (refused), `probes/annoy/match-kw.wat` (works).

### C-014: `set!`-style state ports to services, in all four of the book's forms

- **Where:** Seasoned Schemer ch 15 (The Difference Between Men and Boys...). wat has no
  `set!`; the builder: "mutable state is placed on services".
- **How:** a **Cell** (`books/seasoned-schemer/lib/cell.wat`) is the smallest stateful
  service. It holds one S-expression and answers `get` and `put`. Wrappers `new-cell`,
  `cell-get` and `cell-put!` hide the per-call outcome matching.
- **What happened** (2026-09-14): all 17 ch 15 checks pass. They cover:
  - a **shared** `x` that functions read and reassign, passed in as a Cell;
  - a **private** `x` per closure (`omnivore`, `gobbler`), each owning a Cell. The state
    persists between calls and stays separate: `(pizza soup)`, `(kale bread)`, then
    `(pasta pizza)` (`probes/cell-closures.wat`);
  - a **per-call** `x` (`nibbler`), a fresh Cell on each call;
  - two shared Cells **swapped** (`chez-nous`).
- **A real global works as well.** A keyword-named top-level `def` holding a started Cell,
  `(:wat::core::def :u::x (:ss::new-cell 'pizza))`, starts the service when the program
  starts. `main` then reads it, sets it and reads it again: `pizza`, `onion`
  (`probes/cell-global-def.wat`). So the book's `(define x …)` plus `(set! x …)` ports
  literally.
- **Class:** CLEAN.
- **Repro:** `books/seasoned-schemer/ch15-men-and-boys.wat` and the probes named above.

### Friction: one mutable variable costs about 60 lines, and a dropped Handle closes it

- `lib/cell.wat` is 75 lines, 60 of them code: 28 for the protocol (`defsurface`) and state
  (`defservice`), and 32 for the helpers that make each use a one-liner. Scheme's
  equivalent is `(set! x v)`. Without the helpers, every call site repeats a four-way
  outcome match (`Message` / `Lost` / `Stopped` / `Closed`) plus the response's own
  variants, as in wat-rs's `wat-tests/service-locus-parity.wat`.
- **A service's lifetime is its `Handle`'s.** Keeping only the connected peer and dropping
  the Handle closes the service: the next call gets `Closed`
  (`probes/cell-handle-drop.wat`). A closure that owns state therefore has to hold the
  Handle, not just the connection. It fails loudly, but it is easy to get wrong.
- Classed as friction, not a gap: this is the cost of the builder's deliberate design
  choice to put state on services. It is recorded so the cost is visible.

### F-018: `(wat.core/def u/x …)` does not define `u/x`; its own name is reported unresolved

- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/cell-global-def-clj.wat` is the
  working global of C-014 in the Clojure/EDN spelling. It is refused at startup with
  `4 unresolved references`, all `:u::x`, each with
  `namespaced symbol ref — not a builtin, not a registered function (arc 251)`. One of the
  four is the `def`'s own name (line 4), so the definition is treated as a use.
- **Control:** the keyword-named `(:wat::core::def :u::x …)` works (C-014).
- **Class:** GAP (migration surface). It is the same family as F-005 (no symbol names for
  types) and the symbol-named `typealias` refusal, and its diagnostic is misleading: it
  points at the definition as if it were a reference.
- **Repro:** `probes/cell-global-def-clj.wat`.

### R-002: a function cannot be a service's durable state or ride in a request, so Y-bang does not port

- **Where:** Seasoned Schemer ch 16 (Ready, Set, Bang!) derives Y-bang: recursion by
  `set!`-ing a name to a function that calls through that same name. In wat that means a
  service holding a function, and replacing it after the service starts.
- **What happened** (2026-09-14, wat-rs `a3218644d`). Every attempt is refused at startup:
  - **A `Pure` response enum holding a function**
    (`probes/service-fn-state.wat`):
    > `containment rule (arc 293.W.2b): :wat::enum::Pure enum ":u::FnCell::GetResponse" may only hold pure variant fields — variant "Ok" field "value" has impure type "[:wat::WatAST :-> :wat::core::i64]", which cannot be reconstructed from EDN bytes across an address-space boundary. Declare the enum :wat::enum::Impure if it must hold a live resource (it then stays in shared memory and never crosses).`
  - **With that enum made `Impure`, the durable state itself**
    (`probes/service-fn-state-impure.wat`):
    > `containment rule (arc 293.W): pure aggregate ":u::fncell::Record" may only hold pure fields — field "f" has impure (struct) type "[:wat::WatAST :-> :wat::core::i64]". A struct cannot be reconstructed from EDN bytes across a comms boundary; a record or holon holding a struct field could never cross — it must not exist.`
  - **A request record carrying a function**: the same rule, on
    `:u::FnBox::PutRequest` (`probes/service-fn-put.wat`).
- **Doctrine:** the containment rule (arc 293.W). Durable state and request records must
  be rebuildable from EDN bytes, because a service may run in another process. These are
  the most precise diagnostics in this ledger: each names the rule, the reason, and a way
  out. Their locations, though, are `src/check.rs:15104` and `:15086`, not the user's file
  (the F-006 class).
- **Open, untested:**
  - `defservice`'s `:ephemeral` fields "never cross" (`wat/service.wat:175`). They live in
    the `State` struct beside the pure `Record` (`:761`), and need an `:init` clause
    (`:613`). A function known at start might live there.
  - A function supplied *later* still has no request to ride in, unless a request can be
    an `Impure` enum.
- **Routes:** recursion without names is Y (C-010). Memo tables and other data state are
  Cells (C-014).
- **Class:** REFUSAL (principled).
- **Repro:** the three probes above.

### C-015: an escape measurably abandons its pending work (0 conses against 5)

- **Where:** Seasoned Schemer ch 17 (We Change, Therefore We Are!). `consC` bumps a global
  counter `N`. `N` is a keyword-named top-level `def` of a started Counter service: C-014's
  global route, used in a real chapter.
- **What happened** (2026-09-14): 12 checks pass on the first run.

  | `rember1*` on `'((food) more (food))` | conses counted |
  |---|---|
  | escaping version (ch 14's `Result/try`), atom **absent** | **0** |
  | naive version, rebuilding as it goes, atom absent | **5**, for the same answer |
  | escaping version, atom **present** | **1**, on the way back out |

  `deep-C 5` counts 5 conses, and `supercounter` over 10…0 counts 55.
- **Why it matters:** C-006 and C-013 showed `Result/try` gives the right *answers*. This
  counts the *work*, and shows the pending conses never run.
- **Class:** CLEAN.
- **Repro:** `books/seasoned-schemer/ch17-we-change.wat`.

### Friction: every shape of state needs its own service

- Counting needed an `i64` twin of the Cell: `lib/counter.wat`, 82 lines of code for three
  operations, on top of `lib/cell.wat`'s 60 for an S-expression. The protocol, the service,
  the Handle-keeping struct and the per-call outcome matching are written out again for
  each payload type.
- The stdlib's `:wat::cache::lru-svc :- [K V]` is a generic `defservice`, so a generic
  `Cell :- [T]` may remove the duplication. **Untested.**

### C-016: mutable, shared and cyclic lists work on an Arena service

- **Where:** Seasoned Schemer ch 18 (We Change, Therefore We Are the Same!). The book's
  `set-kdr` lets lists share structure and form cycles. wat's values are immutable trees,
  and a Cell cannot hold another Cell's live Handle (R-002's rule).
- **How:** `books/seasoned-schemer/lib/arena.wat`, one service holding a node table
  (`HashMap`s from id to `kar` and from id to `kdr`). Integer ids are the pointers, and
  `-1` is `()`.
- **What happened** (2026-09-14): 17 checks pass on the first run. They cover:
  - `add-at-end`, which copies, against `add-at-end-too`, which mutates;
  - `same?`, decided by mutation and then restored;
  - two lists **sharing one tail**, where growing one grows the other;
  - `finite-lenkth` (tortoise and hare, escaping through `Result/try`), which answers `4`,
    then `-1` once the list is made **cyclic** (`probes/arena-cycle.wat` checks the cycle
    directly).
- **Cost** (friction): `arena.wat` is 122 lines of code for four operations (`kons!`,
  `kar`, `kdr`, `set-kdr!`), and every list function takes the arena explicitly, because
  memory is a value you pass around.
- **Class:** CLEAN, with the cost noted.
- **Repro:** `books/seasoned-schemer/ch18-the-same.wat`.

### R-003: no first-class continuations; a captured "rest of the computation" returns to its caller

- **Where:** Seasoned Schemer ch 19 (Absconding with the Jewels). The book saves
  continuations with `letcc` and re-enters them later: `toppings` rebuilds a pizza around a
  new filling, and `get-first` / `get-next` walk leaves one at a time.
- **What wat does instead** (all 11 ch 19 checks pass on the first run):
  - **Continuation-passing style.** `ss/deep-k` reaches its bottom and *returns* its
    continuation. The result is reusable: `(toppings 'cake)` → `(((cake)))`, and
    `(toppings 'mozzarella)` → `(((mozzarella)))`.
  - **The observable divergence.** In the book, calling the continuation inside
    `(cons (toppings 'cake) '())` abandons the `cons`, and the answer is `(((cake)))`. A wat
    function returns to its caller, so the same expression answers `((((cake))))`, one
    level more. The chapter asserts wat's answer and documents the book's.
  - **Generators** become lazy streams (C-017).
- **Doctrine:** there is no call/cc. Escapes are `Result/try` (C-006, C-013, C-015). State
  lives on services, and a continuation could not be service state anyway (R-002).
- **Class:** REFUSAL.
- **Repro:** `books/seasoned-schemer/ch19-absconding.wat`.

### C-017: generators port to lazy streams, and the laziness is measured

- **How:** `ss/leaves` turns a nested list into a `(:wat::stream::Stream :- [:wat::WatAST])`
  of its leaves, using `:wat::stream::lazy` / `cons` / `empty`. `get-first` and
  `two-in-a-row*?` pull from it with `:wat::stream::next`.
- **Measured:** a Counter service counts leaf work. Asking for the first leaf of
  `'(((pear)) plum (fig (kiwi)))` produced exactly **1** leaf. A full walk of
  `'(pear (plum fig) (kiwi))` produced **4**.
- **Class:** CLEAN.
- **Repro:** `books/seasoned-schemer/ch19-absconding.wat`.

### C-018: an interpreter with a store gives its language what wat itself lacks

- **Where:** Seasoned Schemer ch 20 (What's in Store?).
- **How:**
  - The store is a global Arena: a box is a node id, and `setbox` is `set-kar!`.
  - Tables are data, `((name id) …)`, with a global table in a Cell that `define` extends.
  - The language's closures and continuations are data too.
  - Every `meaning` returns a `Result`. Calling a continuation returns `Err (id value)`,
    which the `letcc` with that id catches.
- **What happened** (2026-09-14): all 15 checks pass on the first run. They cover:
  - `define` and `set!` on a global;
  - a counter closure with **private mutable state**: `(c)` → 1, then 2, while a second
    counter `d` starts at its own 1;
  - recursion through `define`;
  - `letcc` escaping out of a `cons` (→ 2), an outer continuation called from inside an
    inner `letcc` (→ 5), and a `letcc` whose continuation is never called answering its
    body.
- **Why it matters:** `set!`, state inside closures and escaping continuations are exactly
  what wat itself moves to services or leaves out (C-014, R-002, R-003). An interpreter
  whose memory is one service gives all three to its guest language.
- **Class:** CLEAN.
- **Repro:** `books/seasoned-schemer/ch20-whats-in-store.wat`.

## The Reasoned Schemer

### F-019: a variant constructor inside a collection or stream literal keeps its narrowed type, so `[(Option.Some {…})]` is not a `Vector<Option<i64>>`

- **Update** (2026-09-15, A Little Java ch 5; `probes/java/variant-equality*.wat`): the
  narrowed type reaches equality and generics, not only collection literals.
  - `(:wat::core::= (:probe::FishD.Anchovy {}) (:probe::FishD.Tuna {}))`, inline or with
    both let-bound, is refused:
    > `:wat::core::=: parameter #2 expects :probe::FishD.Anchovy; got :probe::FishD.Tuna`
  - A generic `(PieD :- [T])` of an anchovy on a tuna doesn't unify:
    > `:lj::top: parameter #2 expects (:lj::PieD :- [:lj::FishD.Tuna]); got (:lj::PieD :- [:lj::FishD.Anchovy])`
  - Helpers whose declared return type is the enum (`(defn :lj::anchovy [] -> :lj::FishD …)`)
    widen, and then both work. That is P-006's route, which every enum a program builds
    values of needs.

- **Positive control** (2026-09-17, Crafting Interpreters ch 18; `probes/lox/value-equality.wat`):
  the boundary, stated from the other side, because this finding's headline reads wider than it
  is. Two values typed as the ENUM compare with `=` and give exactly what a tagged-union
  equality wants — same variant and equal payload is true, different variants is false, and an
  `f64` payload compares **as an `f64`**, so `Num(NaN) = Num(NaN)` is FALSE rather than
  bitwise-true. Lox's `valuesEqual` is therefore `(= a b)` and nothing more. I wrote it out by
  hand first, on this finding's headline; the probe is what the headline needed beside it.

- **Where:** Reasoned Schemer ch 10's engine, before any chapter. Its streams are
  `(:wat::stream::Stream :- [(:wat::core::Option :- [State])])`, where `None` marks a
  suspension, so a stream literal holds `Some` values.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `(:wat::core::Option.Some {:value 42})` returned from a fn declared
    `(:wat::core::Option :- [:wat::core::i64])` works (`probes/mk/some-direct.wat`).
  - The same value inside a vector literal is refused at startup
    (`probes/mk/some-in-vector.wat`):
    > `:u::v: body produces (:wat::core::Vector :- [(:wat::core::Option.Some :- [:wat::core::i64])]); signature declares (:wat::core::Vector :- [(:wat::core::Option :- [:wat::core::i64])])`
  - Likewise in `(:wat::stream::cons (Option.Some {…}) (:wat::stream::empty))`, with or
    without a typealias (`probes/mk/some-in-stream-no-alias.wat`,
    `probes/mk/alias-param-and-fn-vector.wat`).
  - The brace-form `(:wat::core::Option.None {})` hits the same wall inside a stream
    (`probes/mk/option-stream-brace-none.wat`):
    > `:wat::stream::cons: parameter #2 expects (:wat::stream::Stream :- [(:wat::core::Option.None :- [:?149])]); got (:wat::stream::Stream :- [(:wat::core::Option :- [:wat::core::i64])])`

    The bare `:wat::core::Option.None` is fine (`probes/mk/option-stream-bare-none.wat`),
    because a bare unit variant of a parametric enum is typed as the enum (`check.rs:1979`).
- **Mechanism** (read in the source): a brace-form constructor is typed as its variant
  (`Option.Some`), not its enum. The variant widens to the enum at a fn's return
  (`some-direct`), but not inside a type argument, because type arguments unify
  invariantly: "Args are INVARIANT (a channel's send/recv types are exact) → unify, not
  covariant-assignable" (`check.rs:17266`). `check.rs:13679–13690` already works around the
  same exact-head unify for `<` by widening each side to its enclosing enum first.
- **Workaround:** a generic helper whose declared return does the widening:
  `(wat.core/defn u/some :- [T] [x :- T] :- (wat.type/Option :- [T]) (:wat::core::Option.Some {:value x}))`.
  Then `[(u/some 1)]` and the stream both check (`probes/mk/some-via-helper.wat`).
- **Not every container:** a Tuple's element types do widen. `(:wat::core::Tuple
  (:ml::Meza.Shrimp {}) (:ml::Main.Steak {}))` under a declared
  `(:wat::core::Tuple :- [:ml::Meza :ml::Main])` is accepted and runs
  (`probes/ml/tuple-of-variants-claim.wat`, 2026-09-14). I had predicted a refusal; it is
  Vector's and Stream's type arguments that stay narrowed.
- **Class:** GAP. In Rust `vec![Some(1)]` is a `Vec<Option<i32>>`, and in Clojure the
  question never comes up. Widening a variant to its enum where it becomes a type argument
  would keep channel invariance while ending this.
- **Repro:** the probes named above.

### F-020: a bare user-enum unit variant is typed as a nullary function, so it cannot be used as a value

- **Where:** Reasoned Schemer ch 10's engine: `rs/nil`, the empty-list term
  `:rs::Term.Nil`.
- **What happened** (2026-09-14, wat-rs `a3218644d`), for `:u::T` with `:Nil []`:
  - Bare `:u::T.Nil` as a fn's return is refused (`probes/mk/unit-variant-bare.wat`):
    > `:u::nil: body produces [:-> :u::T.Nil]; signature declares :u::T`
  - The same as a call argument and as a let value (`probes/mk/unit-variant-bare-arg.wat`):
    > `:u::show: parameter #1 expects :u::T; got [:-> :u::T.Nil]`
  - Calling it, `(:u::T.Nil)`, the spelling that type suggests, is refused
    (`probes/mk/unit-variant-call.wat`):
    > `positional variant construction is retired; write (:u::T.Nil {:field value …}) or (:u::T.Nil {}) for a unit variant`
  - The pre-dot spelling `:u::T::Nil` is typed `:wat::core::keyword`, with the remedy
    `:u::T.Nil` (`probes/mk/unit-variant-bare-colons.wat`).
  - What works is `(:u::T.Nil {})`, which is narrowed (F-019), so inside a collection it
    also needs a widening helper.
- **Against the checker's own account:** the bare built-in `:wat::core::Option.None` is a
  value (its own arm in `infer`, `check.rs:1962`). The next arm, for user enums, says "The
  bare keyword resolves to the enum's type" (`check.rs:1968`), and its map is built from
  every declared enum in the dot spelling (`types.rs:698–719`, `compose_variant` at
  `crates/wat-reader/src/identifier.rs:362`). The behavior contradicts that. I have not
  found where the `[:-> :u::T.Nil]` type comes from. A smaller stale doc sits nearby:
  `decompose_variant`'s comment says the separator is `::`, while its code splits on `.`.
- **Explained later (C-022):** a bare tagged variant is its constructor function; a unit
  variant's constructor takes no arguments, hence `[:-> :u::T.Nil]`. So the bare keyword
  names the constructor, while the checker's comment promises the value. Which one is
  meant is the builder's call; the diagnostic should say which it saw.
- **Class:** GAP (a defect). The documented route is dead for user enums, and the
  diagnostic names a function type and offers no remedy.
- **Repro:** the probes named above.

### C-019: the book's surface syntax ports as wat macros, called with either head spelling

- **Where:** the book writes every chapter with `run`, `run*`, `fresh`, `conde` and
  `defrel`, which are macros (it defines them in ch 10).
- **How:** the last section of `books/reasoned-schemer/lib/ch10-under-the-hood.wat`. The
  macros are defined with `:wat::core::defmacro` (F-022) and called with symbol heads. The
  book's paren syntax is kept: `(rs/run* (x y) g …)`, `(rs/fresh (a d) g …)`,
  `(rs/conde (g …) (g …))`, `(rs/defrel (rs/appendo l t out) g …)`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `probes/mk/surface.wat` passes 4 of 4. That includes the order-sensitive
    `(run* (x y) (conde ((teacupo x) (== y #t)) ((== x #f) (== y #t))))`, which answers
    `((false true) (tea true) (cup true))`. The relation suspends, so conde's second line
    answers first, as in the book.
  - Symbol-headed macro calls expand, including a relation with a symbol name
    (`probes/mk/macros-symbol-head.wat`).
- **Cost:** four rules had to be found by probing (R-004, the friction entry below, F-021,
  F-004). `defrel`'s parameter list needs a second macro that recurses by expanding to
  itself.
- **Class:** CLEAN, with the cost noted.

### R-004: a macro may not call a user function while it expands

- **What happened:** `probes/mk/macro-calls-defn.wat` is refused when the macro is defined:
  > `malformed defmacro: program-body macro purity check failed at definition: keyword head :u::wrap refused at macro expand time — not on the pure-combinator allow-list (default-deny F5 gate, arc 249 stone 249.2b-i); only pure-total heads are permitted`
- **Doctrine:** expansion runs in a fenced evaluator that must be pure and total
  (`src/macros/eval.rs`). What may run there is each intrinsic's `@ExpandTime` ruling
  (`is_expand_time_legal`, `eval.rs:424`). A user fn carries no ruling.
- **Route:** a helper that walks a list becomes a second macro that expands to itself
  (`:rs::defrel-params`).
- **Class:** REFUSAL (principled). In Clojure a macro may call any fn defined before it.

### Friction: a computed unquote in a template evaluates the macro's arguments as code

- `~(:wat::core::first form)` in a template substitutes the argument
  `(:u::whatever 1 2)` into the expression and evaluates it:
  - with a keyword head, the F5 gate refuses it: `keyword head :u::whatever refused at macro expand time`
    (`probes/mk/macro-arg-data-kw.wat`);
  - with a symbol head, it fails at expansion: `unbound symbol: u/whatever`
    (`probes/mk/macro-arg-data-sym.wat`).
- This is documented: "Computed-unquote `,(expr)`: a List whose head is a Keyword is
  evaluated at expand-time via `macro_eval` … with macro params substituted"
  (`src/macros/mod.rs:89–92`). In Clojure, `~(first form)` takes apart the *unevaluated*
  form, the most common move a macro makes.
- **Route:** take arguments apart in a *program* body (a `let` or `if` outside the
  template), where parameters are bound as data (`probes/mk/macro-arg-program-body.wat`).
  But a program body's template may not introduce a literal binder (hygiene gate E,
  `mod.rs:70–72`). So `:rs::run` takes its arguments apart in a program body and hands off
  to `:rs::run-vars`, a pure template, whose binder `q0` is renamed hygienically.
- **Related:** Clojure's bare `quote` is not the quote form in this dialect (it is
  `wat.core/quote`, `:wat::core::quote` or `'`). Written bare, the only error is about its
  contents: `(quote (u/whatever 1 2))` reports `:u::whatever` unresolved
  (`probes/mk/quote-bare-symbol.wat`). This is how a template's `(quote ~form)` first
  failed (`probes/mk/macro-arg-variants.wat`); with `:wat::core::quote` it works
  (`probes/mk/macro-template-kw-quote.wat`).

### F-021: in a program-body macro, `~@` does not splice a vector-form argument

- **Where:** `defrel`'s parameter list, built one parameter at a time by a program-body
  macro that splices the list so far, `[~@typed ~a <- :rs::Term]`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - From a program body (the template inside a `let`), splicing the argument `[1 2 3]`
    fails at expansion (`probes/mk/splice-vector-form-program-body.wat`):
    > `,@: expected sequence (Vec value or list form), got wat::WatAST <WatAST>`
  - The same macro given `(1 2 3)` works and prints 6
    (`probes/mk/splice-list-form-program-body.wat`).
  - A pure template splices `[1 2 3]` fine (`probes/mk/splice-vector-form.wat`).
  - The file's second macro (the template under an `if`, no `let`) was not reached, since
    startup stops at the first failure.
- **So:** the same `~@xs` accepts a vector form or not depending on whether the macro has a
  program body. The error renders the value as `<WatAST>` (F-011's class).
- **Workaround:** carry the list between expansions as a list form with a marker head,
  `(params x <- :rs::Term …)`, and splice its `rest` (`:rs::defrel-params`).
- **Class:** GAP. Clojure's `~@` splices any seq, vectors included.
- **Repro:** the probes named above.

### F-022: `wat.core/defmacro` defines nothing, and `:wat::core::defmacro` refuses a symbol name

- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `(wat.core/defmacro u/twice …)` reports `2 unresolved references`, both `:u::twice`:
    the definition's own name and the call (`probes/mk/defmacro-clj.wat`).
  - With a keyword name, `(wat.core/defmacro :u::twice …)`, the definition passes silently
    and the call fails: `call head — not a builtin, not a registered function`
    (`probes/mk/defmacro-clj-kwname.wat`).
  - The keyword head with a symbol name, `(:wat::core::defmacro u/twice …)`, is refused:
    `malformed defmacro: macro name (item 1) must be a keyword-path (e.g. :my::macro)`
    (`probes/mk/defmacro-kw-clj-params.wat`).
- **Control:** a keyword head with a keyword name works (every macro in the ch 10 lib), and
  such a macro can be called with a symbol head.
- **Class:** GAP (migration surface), in F-018's family. A codemod that respells
  `:wat::core::defmacro` as `wat.core/defmacro` would drop every macro without a word at
  the definitions.
- **Repro:** the probes named above.

### F-023: `conj` onto a `Vector` copies the whole Vector, so an accumulating loop is quadratic

- **Where:** Reasoned Schemer ch 6, `(run 1000000 q (very-recursiveo))`, which the book
  asks for. In wat it took 18.9 s for 10 000 answers, and the 100 000 run never finished
  (R-005). The oracle does a million in 1.1 s.
- **What happened** (2026-09-14, wat-rs `a3218644d`). Measured, wall clock, about 0.55 s of
  each run being startup:

  | 10 000 answers of very-recursiveo | ms | 20 000 |
  |---|---|---|
  | as first written: `rs/take` conj's states onto a Vector, then `rs/run-goal` splices each answer onto a quoted list | 18 890 | — |
  | the search alone, answers counted (`probes/mk/vr-count-*.wat`) | 3 910 | 7 250 |
  | the search, states conj'ed onto a Vector (`vr-take-*.wat`) | 5 856 | 16 534 |
  | answers through `filter` / `map` / `take` / `into []` (`vr-stream-nolet.wat`, now `rs/run-goal`) | 4 115 | 7 551 |

  A loop that only conj's onto a Vector (`probes/mk/vector-conj-*.wat`): 1 180 ms for
  10 000, 4 516 for 20 000, 16 950 for 40 000. The same loop adding instead stays at
  623–760 ms.
- **Mechanism** (read in the source): `vector_conj_inner` clones the Vec and pushes, every
  time: `let mut out = (**xs).clone(); out.push(item.clone());`
  (`src/collection/eval.rs:280–284`). `PersistentVector`'s conj is a persistent
  `push_back` (`:899–902`).
- **So:** `[]` and `conj`, Clojure's accumulator idiom, is O(n²) in wat. The splice per
  answer (`(~@acc ~x)`) was my own quadratic, and the larger part (about 10.8 s of the
  18.9). Both are gone from the engine now.
- **Routes:** the stdlib's lazy stream fns with one native `into []`, which is linear (the
  last row). Or accumulate into `(:wat::core::PersistentVector)`.
- **What is left is the interpreter:** the search is linear at about 0.35 ms per answer,
  against about 1.1 µs on the JVM. That constant is what compilation would change; the two
  quadratics were data-structure and algorithm costs, which it would not.
- **Class:** GAP (performance). Clojure's `[]` is persistent, so `conj` costs O(log n).
  `Arc::make_mut` would avoid the copy when the Vec is not shared.
- **Repro:** the probes named above.

### F-024: to the checker, `wat.core/let` is not a let: its bindings are checked as a vector literal, and its body without them

- **Where:** Reasoned Schemer ch 10's engine. A probe binding a Stream and then a Vector in
  a Clojure-spelled `let` was refused with
  `:wat::core::vec: parameter #11 expects (:wat::stream::Stream :- [:?2972]); got (:wat::core::Vector :- [:?3004])`,
  a verb the program never calls (`probes/mk/vr-stream-10000.wat` at that commit).
- **What happened** (2026-09-14, wat-rs `a3218644d`), isolated with no miniKanren:

  | probe | form | result |
  |---|---|---|
  | `probes/kw-let-mixed.wat` | `(:wat::core::let [a 1 b "x"] …)` | runs |
  | `probes/clj-let-mixed.wat` | `(wat.core/let [a 1 b "x"] …)` | refused: `:wat::core::vec: parameter #5 expects :wat::core::i64; got :wat::core::String` |
  | `probes/clj-let-kwcalls-mixed.wat` | `(wat.core/let [a (:wat::core::+ 1 2) b (:wat::string::concat "x" "y")] …)` | refused, the same |
  | `probes/clj-let-symcalls-mixed.wat` | `(wat.core/let [a (wat.core/+ 1 2) b (wat.string/concat "x" "y")] …)` | runs |
  | `probes/kw-let-body-checked.wat` | `(:wat::core::let [a "x"] (:wat::core::+ a 1))` | refused at startup: `no clause of :wat::core::+ matches … [:wat::core::String, :wat::core::i64]` |
  | `probes/clj-let-body-unchecked.wat` | `(wat.core/let [a "x"] (:wat::core::+ a 1))` | passes the checker; fails at **runtime** with `NoMatchingClause` |

- **Mechanism** (read in the source): the checker has no case for `wat.core/let`. Its head
  is a symbol, so it takes the value-head path (`check.rs:6214–6243`): infer the head as a
  value, and when that fails or is not a Fn, "Recurse into args so nested errors still
  surface". The binding vector is one of those args, so it is inferred as a vector literal,
  whose elements must share one type. The body is inferred without the bindings in scope.
  Only elements whose types are known can clash: literals and keyword-headed calls.
  Symbol-headed calls infer as fresh variables (F-014), which is why most Clojure lets in
  this repository pass. `defn` escapes because it is a macro, and symbol-headed macro calls
  expand before checking (C-019). `let` is a special form.
- **So:**
  - This is F-014's root for lets: no binding a Clojure `let` makes is ever type-checked.
  - The error names `:wat::core::vec`, a retired verb the user never wrote. Its parameter
    number is off by one (`b`'s value, the 4th element, is "parameter #5"), and its remedy
    says to rename `:wat::core::vec` → `:wat::core::Vector`.
  - When F-014 is fixed, and symbol-headed calls get real types, every Clojure `let` that
    binds two different types will start failing with this error.
  - It already blocks tuple destructuring. `(wat.core/let [[a b] (:wat::core::Tuple 1 2)] …)`
    is refused (`:wat::core::vec: parameter #3 expects (:wat::core::Vector :- [:?6998]); got :(wat::core::i64,wat::core::i64)`,
    `probes/ml/tuple-let-clj.wat`), because the binder `[a b]` is a vector next to a tuple.
    The keyword let does it (`probes/ml/tuple-let-kw.wat`). So in the Clojure spelling a
    tuple cannot be destructured at all today.
- **Class:** GAP (a defect), and the most serious codemod hazard after F-014. The keyword
  `let` → `wat.core/let` rewrite turns off checking of every binding and body.
- **Repro:** the probes in the table.

### C-020: The Reasoned Schemer ports completely, and a Clojure oracle checks every answer's order

- **Where:** all ten chapters, `books/reasoned-schemer/`.
- **How:**
  - The ch 10 engine was built first, and the book's surface as macros (C-019).
  - For the answers, `oracle/mk.clj` transliterates the book's ch 10 algorithm to Clojure,
    and `oracle/rels.clj` holds a twin of every relation. For each chapter,
    `oracle/chNN.clj` prints the expected values, and the wat chapter asserts them.
  - Which answers a miniKanren query gives, and in what order, depends only on that
    algorithm. So the check covers interleaving, not just answer sets. On ch 1–2, written
    before the oracle, the two agree on all 51 queries.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - 201 checks pass. Every chapter from 1 to 9 passed on its first run.
  - Ch 10 needed four fixes first. Three were my own mistakes. The fourth became F-020
    (unit variants).
  - The arithmetic is right in decimal as well: 7 × 63 = 441, 68 = 7 × 9 + 5,
    3⁵ = 243, and the book's nine ways to write 68 as bᵠ + r
    (`probes/mk/logo-heavy.wat`).
  - A mutant copy of ch 9, with one wrong expectation, fails at that check
    (`probes/mk/ch09-mutant.wat`).
- **What it cost:**
  - Speed. Ch 8's chapter queries take 19.4 s in wat against about 150 ms on the JVM. The
    two deepest searches (`logo-heavy.wat`) take 610 s against 1.37 s, about 430 times
    slower. So the chapter programs stay with queries the JVM answers in about 25 ms or
    less, and the rest are probes.
  - Along the way: F-019 to F-024 and R-004/R-005.
- **Class:** CLEAN, with the cost noted.
- **Repro:** `./run.sh`; `clojure -M oracle/chNN.clj` for any chapter's expected values.

### F-025: `match` accepts `_`, a bare binder, or a hash-destructure as a catch-all, and its own error recommends `_`

- **Doctrine, per the builder (2026-09-14):** wat does not allow `_`; you cannot forget to
  define an arm.
- **What happened** (2026-09-14, wat-rs `a3218644d`), on a user enum with three unit
  variants:
  - Naming one variant and ending with `[_ …]` passes and runs
    (`probes/match-wildcard-enum.wat`).
  - Ending with a bare binder `[v …]` passes and runs (`probes/match-binder-catchall.wat`).
  - Naming two and leaving the third out is refused, but the error offers the escape
    (`probes/match-missing-arm.wat`):
    > `non-exhaustive: enum :u::Veg missing arm(s) for variant(s): Tomato (or include _ wildcard)`
- **Mechanism** (read in the source): exhaustiveness is `wildcard_seen`
  (`check.rs:6385`, `:6637`). It is set by a `MatchArm::Wildcard` arm (`:6446–6452`), a
  `MatchArm::Binding` arm (`:6453–6463`), and a hash-destructure arm (`:6468–6481`). Any of
  the three covers every variant, including ones added to the enum later.
- **So:** the exhaustiveness check is real, but a catch-all arm silences it. That keeps a
  variant added later from ever producing an error. This repository's own engine has 13
  `_` arms (`books/reasoned-schemer/lib/ch10-under-the-hood.wat`), all accepted.
- **Class:** GAP (the checker drifts from the stated doctrine). Enforcing the doctrine
  means refusing the three catch-all shapes on enums and dropping "or include `_`
  wildcard" from the diagnostic.
- **Repro:** the three probes above.

## The Little MLer

### C-021: generic recursive enums, nested patterns, and exhaustiveness that sees inside them

- **Where:** The Little MLer's datatypes, before any chapter: `'a open_faced_sandwich`
  (`Bread of 'a | Slice of 'a open_faced_sandwich`), and a function that matches
  `Onion(Onion(x))`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - A generic recursive enum, `(:wat::core::defenum :u::Sandwich :- [A] …)`, is built at
    `i64` and at `String` and taken apart by one generic fn
    (`probes/ml/generic-recursive-enum.wat`).
  - A nested variant pattern is written as a sub-pattern with no body,
    `[:u::Kebab.Onion {:k [:u::Kebab.Onion {:k inner}]} …]` (`check.rs:7894–7908`). With
    every arm explicit, it distinguishes two onions from one
    (`probes/ml/nested-pattern-vector.wat`).
  - A variant covered **only** by a nested arm is refused at startup:
    `non-exhaustive: enum :u::Kebab missing arm(s) for variant(s): Onion`
    (`probes/ml/nested-pattern-hole.wat`). A nested arm does not count as covering its
    variant, so the plain case cannot be forgotten. (The message still suggests `_`: F-025.)
  - **Mutually recursive generic enums** (`'a slist` / `'a sexp`) and two mutually recursive
    generic fns over them count the atoms of `(1 (2 3))` as 3
    (`probes/ml/mutual-recursive-enums.wat`).
  - **A datatype holding a function**, `chain = Link of int * (int -> chain)`, works when
    declared `:wat::enum::Impure`. The containment rule keeps functions out of Pure enums
    (R-002). A top-level fn passed as the `next` field unfolds 1, 2, 3
    (`probes/ml/enum-holding-fn.wat`).
- **Class:** CLEAN.

### C-022: a variant's constructor is a function value, as in ML

- **Where:** The Little MLer ch 7: `fun hot_maker(x) = Hot` returns the constructor
  `Hot : bool -> bool_or_int`.
- **What happened** (2026-09-14, wat-rs `a3218644d`): the bare keyword `:u::B.Hot`, passed
  where a `[:wat::core::bool :-> :u::B]` is expected and called positionally through the
  parameter, builds `#u/B.Hot {:v true}` (`probes/ml/constructor-as-fn.wat`). The ch 7 lib's
  `ml/hot-maker` returns `:ml::BoolOrInt.Hot` itself.
- **It explains F-020:** a bare *unit* variant is its constructor too. With no fields that
  is a nullary function, `[:-> :u::T.Nil]`, not the value, which is exactly the type F-020
  reported.
- **Class:** CLEAN.

### F-029: a generic fn over a parametric surface refuses a non-generic type that extends it, so a signature-typed functor cannot be written once

- **Where:** The Little MLer ch 10. `functor PON (structure a_N : N) = struct fun plus …`
  is one `plus` for any structure matching signature `N`.
- **Encoding:** a signature is a surface over its abstract type,
  `(:wat::core::defsurface :ml::N :- [T] … :features [(conceal …) (succ …) …])`. A structure
  is a struct that implements it with `extend-type` at its representation:
  `(:wat::core::extend-type :ml::NumberAsInt (:ml::N :- [:wat::core::i64]) …)`. That much is
  accepted, and so are feature calls through a surface-typed parameter.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - A generic `(:wat::core::defn :ml::plus :- [T] [m <- (:ml::N :- [T]) a <- T b <- T] -> T …)`,
    given either structure, is refused (`probes/ml/signature-functor.wat`):
    > `:ml::plus: parameter #1 expects (:ml::N :- [:?6254]); got :ml::NumberAsInt`
  - The same fn written at a concrete argument, `[m <- (:ml::N :- [:wat::core::i64]) …]`,
    accepts `NumberAsInt` and answers 3 (`probes/ml/surface-concrete-param.wat`).
  - The documented case works: a generic fn over `(:wat::core::Seqable :- [T])` given a
    Vector (`probes/ml/surface-seqable-control.wat`).
- **Mechanism** (read in the source): when the actual type is a plain path, the
  surface-bound check matches the extend-type edge against the expected type's **full
  parametric string**. `types.rs:2151` stores the edge verbatim (see the comment around
  `check.rs:17226–17240`). A bound holding a fresh variable, `(:ml::N :- [:?6254])`, never
  equals `(:ml::N :- [:wat::core::i64])`. Stone 118.3-B's fix, bind the surface's parameters
  and unify, sits only in the arm where both types are parametric (`check.rs:17269–17300`).
- **So:** a functor written against a signature has to be written once per structure. The
  working route is a dictionary: a generic struct of functions (C-023).
- **Class:** GAP. The fix is Stone 118.3-B's unify for the plain-path arm too.
- **Again, in A Little Java** (2026-09-15, `probes/java/visitor-surface-generic.wat`, and
  `visitor-surface-concrete.wat` as the control). The book's visitor interface is a surface,
  `(:lj::TreeVisitorI :- [R])`, and each visitor is a struct that extends it at its answer type.
  - One generic `accept :- [R]` over the surface, given `HeightV` (extended at `i64`), is refused:
    > `:probe::accept: parameter #2 expects (:probe::TreeVisitorI :- [:?5043]); got :probe::HeightV`
  - Written at a concrete answer type it works, fields read through `self` included.
  - So ch 7 (Oh My!) has three identical accepts: `accept-bool`, `accept-int`, `accept-tree`.
    That is the shape of the book's Java *before* that chapter, one visitor interface per
    result type, which the chapter exists to remove. Java escapes through `Object` and casts;
    wat, which needs neither, is stopped by this.
  - Ch 6's pies are accepted at `i64` only, for the same reason.
- **A correction to my own route:** ch 4–7 were first written with visitors as generic structs of
  closures, a dictionary. That sidesteps the surface, so it tested nothing of wat's protocols.
  The builder asked why, and they were right. The chapters now use a surface wherever Java has an
  interface, and plain namespaced functions where Java has only concrete classes.
- **Repro:** the probes above.

### C-023: ML's functors port as dictionaries: generic structs of functions, built from surface structures

- **How:**
  - Signature `N` is also a generic struct of functions, `(:ml::NOps :- [T])`.
  - Each structure yields one, `NumberAsInt` at `i64` and `NumberAsNum` at `num`.
  - Functor `PON` is a generic fn from an `N` dictionary to a `P` dictionary, whose `plus`
    is a closure over its argument.
- **What happened** (2026-09-14, wat-rs `a3218644d`): one generic `plus` answers 1 + 2 = 3
  through both representations (`probes/ml/functor-dictionary.wat`). Generic structs
  holding functions unify as C-010's `Knot` already showed.
- **Cost:** a dictionary is passed by hand, where ML's functor application is checked once
  at the module level. And the representation type stays visible to the dictionary's user;
  ML's opaque `:>` has no counterpart here. (A `newtype` is opaque to arithmetic, but see
  F-030.)
- **Class:** CLEAN, with the cost noted.
- **Repro:** `probes/ml/functor-dictionary.wat`; `books/little-mler/ch10-building-on-blocks.wat`.

### F-030: printing a newtype value panics the Rust runtime

- **Where:** The Little MLer ch 10, sealing a structure's representation (ML's `:>`) with
  `(:wat::core::newtype :u::N :wat::core::i64)`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `(:u::N 5)` builds a value, `=` compares two, and `(:u::N/0 n)` unwraps it
    (`probes/ml/newtype-construct.wat`, `newtype-equal.wat`, `newtype-unwrap-0.wat`).
    `/inner` and `/value` are unresolved. wat-rs itself has no `.wat` use of `newtype`.
  - Arithmetic on it is refused at startup, so it is opaque:
    `no clause of :wat::core::+ matches arity 2 with types [:u::N, :wat::core::i64]`
    (`probes/ml/newtype-plus.wat`).
  - `(:wat::kernel::println (:u::N 5))` passes the checker and then panics, exit 2
    (`probes/ml/newtype-value.wat`):
    > `thread 'main' panicked at crates/wat-edn/src/value.rs:328:33: invalid keyword name "0": first character must be non-numeric`
- **Mechanism, in part:** the value's one field is named `0` (hence `/0`). Rendering it as
  EDN makes a keyword of the field name, and `Keyword::new` panics on a leading digit
  (`value.rs:324–329`). I have not found the rendering code that calls it.
- **So:** a newtype can be built, compared and unwrapped, but never printed. Any path that
  renders one as EDN (printing, a failed assertion's report, maybe crossing a service
  boundary, untested) takes the process down with a Rust panic instead of a wat error.
- **Class:** GAP (a defect: a Rust panic reachable from well-typed wat). The `/0` accessor
  is an odd spelling too; a name like `/value` would read better.
- **Repro:** `probes/ml/newtype-value.wat`.

### F-026: the retired nested pattern `(Variant binders…)` passes the checker and fails at runtime

- **What happened** (2026-09-14, wat-rs `a3218644d`): `probes/ml/nested-pattern-positional.wat`
  writes the inner variant positionally, `{:k (:u::Kebab.Onion inner)}`. That is the shape
  the checker's own Option message still shows (`(Some (1 _))`, `check.rs:6643`). It passes
  startup, and the program dies when that arm is tried:
  > `retired nested (Variant binders…) pattern; a nested variant is [Variant {:k v}] (no body) or bind the field and match it`
- **And it is latent:** `probes/ml/nested-pattern-latent.wat` is the same program given only
  a Skewer, so the arm holding the retired pattern is never tried. It exits 0.
- **So:** wat knows the form is retired (the runtime says so), but only the runtime refuses
  it, and only when some input reaches that arm. A retired shape in an arm no test reaches
  ships.
- **Class:** GAP (a defect), in F-007's family: refusal at runtime instead of at startup.
- **Repro:** `probes/ml/nested-pattern-positional.wat`, `probes/ml/nested-pattern-latent.wat`.

### F-027: a match arm cannot destructure a tuple, and a match on a tuple is exhaustive only with `_`

- **Where:** The Little MLer ch 4 onward, whose functions match on tuples:
  `fun has_steak (a, Steak, d) = true | has_steak (a, ns, d) = false`, and a pair of
  variants like `(Shrimp, Sundae)`.
- **What happened** (2026-09-14, wat-rs `a3218644d`):
  - `[(a b) (+ a b)]` on a 2-tuple is refused (`probes/ml/tuple-match-binders.wat`):
    > `arm #1: a match arm is [_ body], [<binder> body], [<literal> body], [<Variant> {:k v} body], or a record hash-destructure; got 2 element(s)`

    It is also refused for being open-typed:
    > `non-exhaustive: open-typed match needs at least one hash-destructure arm or a wildcard _ arm.`
  - All four `(Meza, Dessert)` combinations as explicit arms of variant sub-patterns,
    `[([:u::Meza.Shrimp {}] [:u::Dessert.Sundae {}]) …]`, are each refused the same way
    (`probes/ml/tuple-match-variants.wat`).
  - A tuple pattern is legal only nested inside a variant's field, where `check_subpattern`
    handles it (`check.rs:7826–7846`).
- **So:** matching on the shape of a tuple, ML's everyday move, is not expressible as an
  arm. And under the no-`_` doctrine a match on a tuple cannot be made exhaustive at all.
  The route is a keyword `let` destructure, `[[a b] t]` (`probes/ml/tuple-let-kw.wat`), and
  then one match per position. For `eq_main` that means 16 leaf arms where ML writes five
  lines (`books/little-mler/lib/ch04-look-to-the-stars.wat`).
- **Class:** GAP. Enforcing F-025's doctrine would want this first: exhaustiveness over the
  product of the positions' variants.
- **Repro:** the probes above.

### F-028: nested arms never count as covering a variant, even when together they cover it completely

- **Where:** The Little MLer ch 5. `'a pizza = Bottom | Topping of ('a * 'a pizza)`, and
  ML's `rem_anchovy`, which matches `Topping(Anchovy, p)`, then the other fish.
- **What happened** (2026-09-14, wat-rs `a3218644d`), with `Topping` carrying a tuple:
  - A tuple sub-pattern of binders, `{:t (x rest)}`, works
    (`probes/ml/tuple-in-variant-binders.wat`).
  - `{:t ([:u::Fish.Anchovy {}] rest)}` followed by a binder fallback `{:t (other rest)}`
    works (`probes/ml/tuple-in-variant-nested.wat`).
  - Three nested arms, one each for Anchovy, Lox and Tuna, cover `Topping` completely, and
    are refused (`probes/ml/tuple-in-variant-strict.wat`):
    > `non-exhaustive: enum :u::Pizza missing arm(s) for variant(s): Topping (or include _ wildcard)`
- **So:** exhaustiveness counts an arm as covering its variant only when every sub-pattern
  is a binder (C-021's `nested-pattern-hole.wat` is the partial case, rightly refused).
  Complete coverage written in nested arms is refused, and the checker asks for a binder
  fallback: a catch-all one level down, the thing the no-`_` doctrine targets. It is also
  the arm that would silently absorb a fish added to the enum later.
- **Route that keeps coverage explicit:** bind the field, then match it in its own `match`
  with every variant named (`books/little-mler/lib/ch05-couples-are-magnificent-too.wat`).
  A fish added later is then flagged there.
- **Class:** GAP. P-012 (exhaustiveness over the product) would cover this too.
- **Repro:** the three probes above.

## The Little Prover

### C-024: J-Bob, the book's prover, runs in wat, translated by a wat program, and all 49 transcript entries match guile

- **How:**
  - J-Bob is written in its own tiny language: `defun`, `if` over `'t`/`'nil`, `quote`, and
    eight primitives. `vendor/j-bob` holds its Scheme source (BSD 2-Clause).
  - The primitives are hand-written in `books/little-prover/lib/j-bob-lang.wat`.
  - Everything else is generated by `tools/jbob2wat.wat`, a wat program built the way
    `wat/fix.wat`'s codemods are. It reads the source with `read-string`, rebuilds each
    form with `ast->children`, `with-children`, `symbol-node` and `keyword-node`, renders it
    with `ast->source`, and writes it with `write-file`.
  - It produces `lib/j-bob.wat` (125 functions and 3 constants), the transcript split on its
    `;; Chapter N` lines, and one program per chapter.
  - Zero-argument definitions become values computed once, so a chapter does not re-run
    every proof before it.
- **The oracle:** guile runs the same vendored J-Bob (`oracle/prover.scm`), and its answers
  are `oracle/prover.expected.tsv`. Each generated check compares
  `(ast->source :jb::ENTRY)` with guile's text, so a failure prints both strings.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - All 49 entries match, from `(car (cons 'ham '(eggs)))` → `'ham` to the proof of
    `align/align`. The generated programs hold 49 checks, and a mutant with one wrong answer
    fails at it (`probes/prover/ch01-mutant.wat`).
  - Every generated file passed the checker on its first load, and the translated J-Bob gave
    guile's answers on its first run.
  - The times for chapters 1–9 are 4.2, 1.9, 3.9, 7.0, 12.3, 14.0, 20.4, 34.2 and 57.6 s.
    J-Bob's work runs about 13 times slower than guile's, far better than the miniKanren
    search (C-020).
- **Friction on the way:**
  - The two quote spellings in read data (a nested `'x` reads as `(:wat::core::quote x)`,
    a longhand `(quote x)` keeps the symbol head) had to be normalized.
  - `nil` reads as wat's nil literal.
  - Names with a second `/`, a `.` or a `<` had to be mangled.
  - Two runtime-only type errors (F-031).
- **Class:** CLEAN.
- **Repro:** `./run.sh`; `wat tools/jbob2wat.wat` regenerates the port;
  `guile --no-auto-compile oracle/prover.scm` regenerates the answers.

### F-031: the checker accepts `:wat::core::length` on a String; only the runtime refuses it

- **Where:** The Little Prover, `tools/jbob2wat.wat`, which pads a chapter number with
  `(:wat::core::length s)` on a String. That was my mistake; `:wat::string::length` is the
  string one.
- **What happened** (2026-09-15, wat-rs `a3218644d`): `probes/length-of-string.wat` is a
  keyword-spelled defn, `[s <- :wat::core::String] -> :wat::core::i64`, whose body is
  `(:wat::core::length s)`. It passes the startup check and dies when it runs:
  > `:wat::core::length: expected (Vector :- [T]), (HashMap :- [K V]), (PersistentMap :- [K V]), (PersistentVector :- [T]), (HashSet :- [T]), or (List :- [T]), got wat::core::String "abc"`
- **So:** the runtime lists exactly which types `length` takes, but the checker does not
  enforce that list. This is the keyword spelling, so F-014 is not the reason. The same
  shape showed once in passing: `(:wat::core::Seqable/seq x)` on a `:wat::WatAST` passed
  startup and failed at runtime with "type `:wat::WatAST` does not implement surface method
  `seq`". That probe was not kept; it is noted, not claimed.
- **Class:** GAP (a defect), in F-007's family: a type error a checker should see, found
  only by running the code.
- **Repro:** `probes/length-of-string.wat`.

## The Little Typer

### F-032: wat's lexer rejects λ, Π, Σ and → in symbols but accepts é; the error points into the reader's Rust source

- **Where:** The Little Typer. Pie prints its results with `λ`, `Π`, `Σ` and `→`, and
  wat-Pie reads Pie source with wat's reader.
- **What happened** (2026-09-15, wat-rs `a3218644d`), with `read-string`:
  - `λ` alone: `lex error at byte 0: unexpected character 'λ'`
    (`probes/typer/read-pie-unicode-lambda-symbol.wat`).
  - `courgetté` reads as a symbol (`probes/typer/read-pie-unicode-accented-symbol.wat`).
  - `"→"` inside a string reads fine (`probes/typer/read-pie-unicode-arrow-string.wat`).
  - A source file whose own text holds `(:wat::core::quote λ)` fails at startup
    (`probes/typer/unicode-in-source.wat`). The error is located in wat-rs itself, not the
    user's file, and gives a byte offset, not a line:
    > `#wat.parse/Lex {:message "lex error: lex error at byte 153: unexpected character 'λ'" :location #wat.core/Span {:file "crates/wat-reader/src/parser.rs" :line 201 :col 28 …}`
- **So:** some letters beyond ASCII are symbol characters and others are not. Clojure and
  EDN allow `λ` in symbols. The location is F-006's and F-008's class: a Rust file and a
  byte count, where the user needs their own file and line.
- **Route:** Pie accepts ASCII spellings (`lambda`, `Pi`, `Sigma`, `->`), so the chapter
  files use those, and the oracle's output is mapped to them.
- **Class:** GAP (friction for mathematical code, and a diagnostic defect).
- **Repro:** the probes above.

### R-005: SIGTERM does not stop a busy wat program; stopping is cooperative

- **What happened** (2026-09-14, wat-rs `a3218644d`): `timeout 180 wat
  probes/mk/very-recursiveo-100000.wat` was still running at 10:15 elapsed, 7 minutes
  after `timeout` sent SIGTERM. An explicit `kill -TERM` changed nothing: the process was
  still running (`Rl`) 5 seconds later. Only SIGKILL stopped it.
- **Doctrine** (`src/runtime.rs:70–77`): "The wat binary installs OS signal handlers for
  SIGINT and SIGTERM; both set this flag to `true`. User programs poll via the
  `:wat::kernel::stopped?` form to decide whether to continue their main loops". So a
  computation that never polls, like a search, cannot be stopped by SIGTERM or Ctrl-C.
- **Cost:** a runaway computation needs `timeout -s KILL`. Every timed run in this
  repository since then uses it.
- **Class:** REFUSAL (a principled protocol: "stopping is a protocol", arc 170). A program
  can poll `stopped?` itself; the evaluator does not.

### C-025: wat-Pie, a dependent type checker written in wat, matches Racket's Pie

- **Where:** The Little Typer, all 16 chapters.
- **What the chapters need:** Pie, the book's dependently typed language. Types compute,
  evaluation runs under binders, and results print as normal forms, the way Pie prints them.
- **What was done** (2026-09-15, wat-rs `a3218644d`):
  - `books/little-typer/lib/pie.wat` (1,287 lines, 1,045 of them code, keyword spelling) uses normalization by
    evaluation with a bidirectional, elaborating checker. Synth gives a type and a core
    term, so a stuck eliminator carries its base's type.
  - Terms, values, closures and neutrals are all `:wat::WatAST`, built with `with-children`
    and taken apart with `ast->children`, as in the J-Bob port (C-024).
  - Each chapter is a `.pie` file that both implementations read. Racket's Pie reads it
    through `tools/pie-oracle.sh`, as a black box (AGPL, never read or copied); wat-Pie
    reads it through the chapter's runner.
- **Result:** all 290 printed results match string for string, across 16 chapters. They
  include:
  - stuck `which-Nat`, `iter-Nat` and `rec-Nat` forms;
  - eta-expanded functions and pairs;
  - Pie's renaming of a shadowed binder (`(-> U (Pi ((A₁ U)) (-> A₁ A₁)))`);
  - types that are not a U, which Pie prints by themselves;
  - proofs, from incr=add1 and twice=double to list->vec->list=, even-or-odd and nat=?.

  Each chapter runs in 0.8 to 2.8 s (after F-033's route). Ch 12, 15 and 16 needed no change
  to the checker.
- **The oracle earned its keep:** my first ch 4 draft held `(the U (Pi ((A U)) …))`, and wat-Pie
  accepted it. Racket's Pie refused it: U has no type, so a Pi over U is a type but not a
  U. That silent acceptance is why every chapter now also has refusal tests (C-026).
- **Class:** CLEAN.
- **Repro:** `wat books/little-typer/chNN-….wat` for NN = 01..16.

### C-026: a failed assertion deep in a checker comes back as a value, through `:wat::test::run-thread`

- **Where:** The Little Typer's refusal tests (`chNN-…-refusals.pie`).
- **What they need:** to test that a form is refused. In wat-Pie a refusal is an
  `assertion-failed!` up to ten frames deep. Without a way to observe a death, every
  checker function would have to return a Result.
- **What happened** (2026-09-15, wat-rs `a3218644d`): this worked the first time.
  ```clojure
  (:wat::core::match (:wat::test::run-thread (:pie::run-form st form))
    [:wat::kernel::RunResult.Passed {} (:pie::fail "accepted a form Pie refuses: …")]
    [:wat::kernel::RunResult.Failed {:failure f} (:wat::kernel::Failure/message f)])
  ```
  - The thread shares the loaded definitions and captures the let-bound checker state.
  - The Failure carries wat-Pie's message, its location in `lib/pie.wat`, and the frames.
  - 108 of 108 refused forms die, and each death comes back as data.
- **Note:** `spawn-program` is capability-restricted to `:wat::spawn::` and `:wat::test::`
  (wat-rs `wat/test.wat`, arc 170). So the door a program has for watching a computation
  die is a test verb. That's fine for tests. A non-test program supervising a risky
  computation would have to borrow it; that isn't explored here.
- **Class:** CLEAN.
- **Repro:** the refusal half of any `books/little-typer/chNN-….wat` runner.

### Friction: a thread death handled as data still prints its full failure record to stderr

- **Measured at scale (2026-09-15), and it is not incidental.** `probes/err/catch-cost.wat`
  catches 2000 deliberate failures with `:wat::test::run-thread`, handles every one as a value,
  and still writes **2000 lines and 806,000 bytes to stderr** — one full `AssertionFailure`
  record per catch, complete with thread name, location and captured frames. The program's own
  output is three lines. A program that recovers inside a loop cannot be run with readable
  stderr.
- **It is deliberate, and there is no flag.** `src/panic_hook.rs:4` records that this replaced
  an `install_silent_assertion_panic_hook` "which silently swallowed" — so the printing was
  chosen on purpose, and nothing in the hook takes a quiet or suppress setting. The right fix is
  probably not silence but *attribution*: a death that a `run-thread` is about to hand back as
  a value has a handler, and needn't be reported as though nothing caught it.
- See also F-063, which prices the catch itself.

- **Where:** the refusal tests of C-026.
- **What happened** (2026-09-15, wat-rs `a3218644d`): ch 1's run exits 0, and its stdout
  holds only the verdict lines. Its stderr holds 9 failure records, one for each refused
  case, although the parent handles every one of them as a value:
  > `#wat.kernel/AssertionFailure {:thread "wat-thread-peer::<anon>" :message "wat-Pie: 5 has type Nat but should have type Atom" :location #wat.kernel/Location {:file "books/little-typer/lib/pie.wat" :line 607 :col 13} … :frames [… ":pie::fail" … ":pie::synth-form" … ":pie::run-form" … ":wat::core::Fn"] :upstream-chain nil}`
- **Cost:** a person reading a green run sees nine failures. Nothing marks a death as
  expected (compare Erlang's `normal` exit reason, or deftest's `should-panic`, which is
  for a whole test). This may be doctrine, since a dying thread declares its death; I
  have not checked that against wat-rs's conventions.
- **Route:** live with it. The runners put their verdict on stdout, and `run.sh` judges
  by exit code.
- **Class:** GAP (minor, output noise).
- **Repro:** `wat books/little-typer/ch01-the-more-things-change.wat 2>&1 >/dev/null | grep -c AssertionFailure` prints 9.

### Friction: the cheatsheet says a Vector's `first` returns an Option; it returns the element, and an empty Vector dies at runtime labelled a malformed form

- **Where:** The Little Typer. wat-Pie takes Pie forms apart with `:wat::core::first` on
  `(:wat::core::Vector :- [:wat::WatAST])`, typed as the element itself, and a malformed
  Pie form runs off the end of its arguments.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/typer/first-of-empty-vector.wat`:
  - The checker accepts `(:wat::core::first xs)` as an `i64` for `xs` a
    `(:wat::core::Vector :- [:wat::core::i64])`, and `[7 8]` gives 7.
  - On the empty Vector the program dies, loudly and located in the user's file:
    > `#wat.runtime/MalformedForm {:message "malformed :wat::core::first form: :wat::core::first: sequence has 0 element(s); no element at index 0" :location #wat.core/Span {:file "probes/typer/first-of-empty-vector.wat" :line 6 :col 22 …}`
  - `docs/WAT-CHEATSHEET.md` says `first` on a Vec returns `(Option :- [T])` ("arc 047 — Vec
    accessors return Option to honestly signal empty/short").
- **So:** nothing is silent here. But the doc describes a different verb from the one that
  runs, and the error calls a well-formed call on an empty sequence a "malformed form".
- **Class:** GAP (a doc that has fallen behind the code, and a misleading error label).
- **Repro:** `probes/typer/first-of-empty-vector.wat`.

### F-033: taking a WatAST apart copies every subtree below it

- **Where:** The Little Typer. Ch 14 took 43 s, where the chapters before it took 1–14 s.
  Bisecting the chapter put the cost on its last few definitions.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/typer/ast-children-cost.wat`: 2000 `ast->children` calls on a two-child node
    take 14 ms. On a two-child node whose second child is a tree of about 8,200 nodes,
    they take 4,220 ms, about 2 ms per call. The cost follows the size of the subtree,
    not the number of children.
  - `probes/typer/value-copy-cost.wat`: passing that big WatAST through a function and
    asking its `ast-kind` costs the same as for a small one (16 ms against 15 for 2000).
    So does matching the root of a native Pure-enum tree whose children are shared
    (18 ms against 16). A depth-16 enum tree with shared children builds in under 1 ms, so
    it is 16 nodes, not 65,536.
  - The source agrees. A runtime value holds a WatAST as `wat__WatAST(Arc<WatAST>)`, but
    inside it every node owns its children as `List(Vec<WatAST>, Span)` with a derived
    `Clone` (`crates/wat-reader/src/ast.rs:132`). Handing out children, or building a
    node from them with `with-children`, copies whole subtrees. `Vec`, `Enum` and the
    other runtime values sit behind an `Arc` and share.
- **Cost:** a code-as-data program pays a tree's whole size for every destructure. wat-Pie
  made it exponential. Each definition's value was a closure whose environment held every
  earlier definition's value, each with its own environment, and each `bind` and each
  `arg` copied all of it.
- **Route:** bind each definition as its core syntax, `(GLOBAL core)`, and evaluate it at each
  use (`:pie::globals-only`). Measured after the change:

  | Chapter | Before | After |
  |---|---|---|
  | ch 14 | 43 s | 2.0 s |
  | ch 11 | 14 s | 2.6 s |
  | ch 9 | 10.4 s | 2.0 s |
  | ch 7 | 5.4 s | 1.4 s |

  Every chapter still matches Racket's Pie. The stronger route is values as native enums,
  which share.
- **Class:** GAP (performance; P-014).
- **Repro:** the two probes.

## The Little Learner

### F-034: an f64 prints without its decimal point, so a printed float reads back as an integer

- **Where:** The Little Learner, before its first chapter. Its results are floats, and
  checking them against Racket's means comparing how the two print.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/learner/f64-printing.wat`:

  | Value | wat `:wat::f64::to-string` | Clojure `prn` | Racket |
  |---|---|---|---|
  | `100.0` | `100` | `100.0` | `100.0` |
  | `1e21` | `1000000000000000000000` | `1.0E21` | `1e+21` |
  | `1e-7` | `0.0000001` | `1.0E-7` | `1e-7` |
  | `(* -1.0 0.0)` | `-0` | `-0.0` | `-0.0` |
  | `(+ 0.1 0.2)` | `0.30000000000000004` | the same | the same |

  wat's own renderer does the same. A failing `(:wat::test::assert-eq 100.0 1e21)` reports
  `:actual "100" :expected "1000000000000000000000"`
  (`probes/learner/f64-in-failure-record.wat`).
- **So:** the digits are the shortest round-trip ones, which is right. The format is Rust's
  `Display` for f64, though: an integral float drops its `.0`, and no magnitude ever gets an
  exponent. In EDN and Clojure `100.0` reads back as a float; wat's `100` reads back as an
  integer. A failure message can't tell a float from an integer.
- **Route:** the Little Learner's checks will compare f64 values, not their printed forms.
- **Confirmed again in a second context (2026-09-15), where it costs more than a message.** A
  SQL `REAL` column holding `2.0`, read back through `:wat::sqlite::Cell.F64`, renders as `2`
  where the sqlite3 CLI prints `2.0` (`probes/sqlite/cell-rendering.wat`). The value round-trips
  correctly; only its printed form differs. So any comparison of a float against another
  system's output fails on formatting rather than on data, and `sqlite/s01-crud.wat`
  deliberately holds no floats for that reason — they need a case where the difference is the
  subject rather than an accident.
- **Class:** GAP (EDN fidelity of printed floats).
- **Repro:** the two probes.

### F-035: integers have no bit operations

- **Where:** The Little Learner needs random numbers (F-036), and writing a generator
  needs bit operations. So will NEXT.md's packet detector, and anything else that hashes,
  checksums, or reads flags and bit fields.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - The i64 verbs registered in wat-rs's source are arithmetic, comparisons and conversions:
    `- < > mod quot rem to-bigint to-f64 to-rational to-string`. No verb in `src/` or `wat/`
    has a name containing bit, xor, shift, shl, shr, wrapping, popcount, band or bor.
  - Overflow is checked, and loud (`probes/learner/i64-overflow.wat`):
    > `#wat.runtime/IntegerOverflow {:message "i64 overflow: 9223372036854775807 :wat::i64::+ 1 does not fit in 64 bits" :location #wat.core/Span {:file "wat/core.wat" :line 66 …}`

    It is located in wat's own stdlib, not at the user's call.
- **So:** xorshift, splitmix64, PCG, FNV and xxhash, CRCs, and parsing flags or bit
  fields can't be written. The only generator left is a multiplicative one small enough
  never to overflow (Park–Miller: 48271·x mod 2³¹−1). For a language headed for
  networking, bit operations are table stakes.
- **Class:** GAP. Extend: add and, or, xor, not, shifts, and wrapping and checked arithmetic.
  Correct: locate the overflow at the user's call.
- **Repro:** the probe, and the verb grep above.

### F-036: there are no random numbers

- **Where:** The Little Learner. `init-theta` draws normal random numbers, `sampling-obj`
  draws random batch indices, and malt makes its normals with the ziggurat method from
  uniform `(random)` draws.
- **What happened** (2026-09-15, wat-rs `a3218644d`): no verb in `src/` or `wat/` has a name
  containing rand, and the docs list none. There is neither a seeded generator nor a source
  of seeds. `:wat::time::now` is the only observation of the world that could stand in
  for a seed.
- **So:** a program that needs randomness must write its own generator, and F-035 limits
  that to Park–Miller.
- **Class:** GAP. Extend: add a seeded, pure generator to the stdlib (state in, a value and the
  next state out, e.g. splitmix64), plus a seed from the world alongside `:wat::time::now`.
- **Repro:** the verb grep.

### F-037: an undefined function called on a struct is reported as a missing field of the struct

- **Where:** The Little Learner. I moved part of `lib/malt.wat` into `lib/sampling.wat`, and
  `naked-gradient-descent` went with it by mistake, so chapters that don't load
  sampling.wat were left calling a function that didn't exist.
- **What happened** (2026-09-15, wat-rs `a3218644d`): the call
  `(:ll::naked-gradient-descent h)`, where `h` is an `:ll::Hypers` struct, was reported as:
  > `malformed :ll::naked-gradient-descent form: keyword accessor: field "ll::naked-gradient-descent" is not declared on :ll::Hypers (declared fields: revs, alpha, batch-size, mu, beta)`

  The location, `books/little-learner/ch07-the-crazy-ates.wat` line 48, is right.
- **So:** a keyword-headed call whose name isn't a function falls through to Clojure-style
  keyword access, `(:field struct)`. The error then explains why the struct lacks that
  field. That is plausible for `(:alpha h)`, and misleading for a fully qualified name that
  is clearly meant as a function. The fix was a load, not a field.
- **Class:** GAP. Correct: when the keyword names a namespace that isn't the struct's, or
  looks like a function, say "unresolved function `:ll::naked-gradient-descent`" first, and
  mention the accessor reading second.
- **Repro:** call any undefined `:ns::f` with a struct argument.

### Friction: a variant pattern must name every field

- **Where:** The Little Learner's port. A dual has two fields (its real part and its
  link), and most code wants one.
- **What happened** (2026-09-15, wat-rs `a3218644d`): `[:ll::V.Dual {:r r} …]` is refused:
  > `malformed :wat::core::match form: map pattern has 1 key(s), variant `:ll::V.Dual` declares 2`

  Each refusal also counts as a missing arm, so a single short pattern reports two errors
  (non-exhaustive: missing `Dual`). Naming every field, `{:r r :k k}`, works.
- **So:** Clojure's map destructuring takes any subset of keys. Here every arm binds
  every field, used or not, and adding a field to a variant breaks every match on it.
- **Class:** friction (a divergence from Clojure; possibly deliberate).
- **PROMOTED to F-115** (2026-09-17), after Crafting Interpreters chapter 21 showed what it costs
  across a sequence of edits rather than at one site. See F-115 for the workload and the ask.
- **Repro:** change any `{:r r :k k}` in `books/little-learner/lib/malt.wat` to `{:r r}`.

### Friction: `drop` takes the collection first, the reverse of Clojure, and returns a lazy Stream

- **What happened** (2026-09-15, wat-rs `a3218644d`): I wrote `(:wat::core::drop i es)`, as
  in Clojure's `(drop n coll)`. The checker said:
  > `:wat::core::drop: parameter #1 expects (Vector :- [T]), (PersistentVector :- [T]), (List :- [T]), or (Stream :- [T]); got :wat::core::i64`

  Then `drop` returns a `Stream`, not a Vector, so a function expecting a Vector refused it
  too. `nth` and `range` take the collection or the bounds in the order Clojure does.
- **So:** a Clojure reader writes it backwards, and a codemod of Clojure-shaped code would
  too. The checker catches it, loudly and well located.
- **Class:** friction (a divergence from Clojure; a codemod hazard).

### C-027: malt, the Little Learner's library, ported to wat, matches malt exactly, number for number

- **Where:** The Little Learner, chapters 1–15 and Interludes I–VII (22 runners).
- **What was done** (2026-09-15, wat-rs `a3218644d`):
  - `books/little-learner/lib/malt.wat` (457 lines of code) ports malt's learner
    representation and the book's code by hand. malt is MIT (vendor/malt).
    - Tensors are nested Vectors, and duals carry their links as closures (an Impure enum).
    - It has prim1/prim2 with malt's derivative formulas, and ext1/ext2 with malt's descent rules.
    - Gradients are keyed by each leaf's position, since wat values have no identity.
    - The rest is ported too: the non-dual operators, naked, velocity, rms and adam descent,
      layers, blocks, correlation, and accuracy.
  - Every operation is done in malt's order: sum from the last entry, a gradient added as
    `(+ z g)`, `(- z)` as negation, correlate's own dot product.
  - Each chapter's examples run twice, in Racket with malt (`oracle/learner/`) and in wat.
    `lib/check.wat` compares the values by exact f64 equality, reading malt's printed
    numbers with `:wat::string::to-f64`. There is no tolerance. A mutant one ulp off is
    refused (`probes/learner/ch01-mutant.wat`).
- **Result:** all 194 values match, bit for bit. They include:
  - 1000-step descents;
  - velocity, rms and adam;
  - a 2-layer relu network trained on xor to a loss near 1e-30;
  - malt's own correlation examples, with their gradients;
  - the book's own Iris run: 2000 sampled revisions from the book's printed initial theta,
    ending at malt's theta and its test accuracy, 0.9333333333333333.

  `:wat::math::exp`, `ln` and `sqrt` agree with Racket's on every value tried.
- **The oracle caught me twice, both in Racket:**
  - malt shadows `*`, so `(* 1000 4)` made a dual, and `for/list` over it recorded 3 draws, not
    4000.
  - malt's unset hyperparameter is the symbol `unset-hyper-alpha`, which failed far away, in
    `vector-map`'s contract. wat's explicit Hypers can't be left unset.
- **Speed:** the book's Iris run takes 236 s in wat; malt's whole oracle, training included, takes
  2.3 s. That's over 100 times slower, in line with C-020. Ch 15's 20000-revision Morse training
  is out of reach, so its blocks are checked small and untrained. Ch 13i's grid search takes 27 s.
- **Class:** CLEAN.
- **Repro:** `wat books/little-learner/chNN-….wat`; `tools/learner-oracle.sh chNN-…`.

### C-028: malt's dynamic hyperparameters and its random draws, done wat's way

- **Where:** The Little Learner, Interlude II on, and ch 6 and 13.
- **What the book needs:**
  - malt's hyperparameters (`revs`, `alpha`, `batch-size`, `mu`, `beta`) are globals, set by
    `with-hypers` inside a `dynamic-wind`.
  - Its sampling draws with Racket's `(random n)` from a mutable global generator.

  wat has neither dynamic binding nor random numbers (F-036), and it keeps mutable state on
  services.
- **What was done:**
  - **Hyperparameters are a value.** `:ll::Hypers` is handed to each descent; a nested
    `with-hypers` is a second value, and `grid-search` hands one per combination to its body.
  - **Draws are recorded, then replayed.** The oracle copies Racket's seeded generator and
    records the draws malt is about to make (`record-draws`, `NAME.draws`). The port replays
    them, keeping its place on the Seasoned Schemer's counter service
    (`books/seasoned-schemer/lib/counter.wat`). That is malt's hidden state made explicit, on a
    service, as wat's doctrine asks.
- **Result:** 22,405 draws replayed across ch 6 and 13, and every sampled descent ends where
  malt's does.
- **Cost:** the counter's 98 lines of service ceremony are the price of one integer of state
  (compare the friction entries under C-014 and PROVIDE P-002). Hypers as a value cost
  nothing, and a missing hyper can't be written (C-027).
- **Class:** CLEAN (both). The missing random numbers are F-036.

### Friction: the user guide still names verbs that are retired

- **What happened** (2026-09-15): three verbs I took from `docs/USER-GUIDE.md` while writing
  the Learner's probes are retired. Each time the checker refused the call and named the
  replacement exactly, which is good:
  - `:wat::core::f64::to-string` ("use `:wat::f64::to-string`");
  - `:wat::std::math::exp` ("use `:wat::math::exp`");
  - `:wat::core::i64::to-f64` ("use `:wat::i64::to-f64`").

  The guide also lists `:wat::std::math::log` as an alias of `ln`. It isn't among the
  registered math verbs (`cos exp ln pi sin sqrt`), and neither is a `pow`.
- **So:** the retirement is handled well at the call. The docs just haven't followed
  (compare the `first` Friction entry in The Little Typer).
- **Class:** GAP. Clean: sweep the guide for retired names.

## A Little Java, A Few Patterns

### F-038: a builtin verb used as a function value passes the checker in two places of three, and fails at runtime

- **Where:** A Little Java, ch 2. The runner let-bound `int :wat::i64::to-string` to print
  numbers, as it had bound user functions (`bool :lj::show-bool`, and the Learner's
  `n :ll::num`) without trouble.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/java/builtin-verb-as-value.wat`:
  - A let-bound builtin, called through its local name, passes the checker. At runtime:
    > `#wat.runtime/NotCallable {:message "not callable: expected Function, got wat::core::keyword `:wat::i64::to-string` (bound from probes/java/builtin-verb-as-value.wat:17:27 at probes/java/builtin-verb-as-value.wat:18:35)" :location #wat.core/Span {:file "src/runtime.rs" :line 10734 …}`
  - `(:wat::core::mapv :wat::i64::to-string [1 2 3])` passes the checker. At runtime:
    > `#wat.runtime/TypeMismatch {:message ":wat::core::mapv: expected wat::core::fn, got wat::core::keyword `:wat::i64::to-string`" …}`
  - `(:wat::core::foldl :wat::core::+ 0 [1 2 3])` is refused by the checker, at the call:
    > `:wat::core::foldl: parameter #1 expects [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]; got :wat::core::keyword`
  - A user defn works in all three places (`:ll::num` with `mapv`, `:ll::stack2` with `foldl`).
- **So:** a builtin's name is a keyword value, not a function. The checker knows that in one
  place (foldl's parameter) and not in the other two, where the mistake ships. The
  let-bound case is F-014's family: a call through a local's symbol isn't type-checked. The
  NotCallable message names the user's lines well; its `:location` is wat-rs's Rust (F-006).
- **Route:** wrap the builtin in a `fn`.
- **Class:** GAP. Fix: refuse the other two at check time too. Extend: let a builtin's name
  be a function value, as a defn's is.
- **Repro:** the probe.

### F-039: an extend-type that leaves a feature out passes the checker, and the missing feature fails only when called

- **Where:** A Little Java. Every visitor struct implements the visitor surface with
  `extend-type`, and forgetting one feature is the slip a visitor invites.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/java/extend-type-partial.wat`:
  `HalfV` extend-types a two-feature surface with only `for-bud`. The program starts, and
  `for-bud` answers 0. Calling `for-flat` then fails:
  > `#wat.runtime/UnknownFunction {:message "unknown function: type :probe::HalfV does not implement surface method for-flat — expected a defn :probe::HalfV/for-flat but none is registered" :location #wat.core/Span {:file "probes/java/extend-type-partial.wat" :line 20 …}`
- **So:** the message is clear and located. But it comes only when some input reaches the
  missing feature, so the omission can ship. Java won't compile a class that leaves an
  interface method out, and wat's own `match` won't compile a forgotten arm (the builder's
  "you cannot forget to define an arm"). An `extend-type` is the same promise, and it isn't
  kept at check time.
- **Class:** GAP. Fix: check `extend-type` for completeness against the surface's features,
  as `defsurface` already checks `:messages` for completeness.
- **Repro:** the probe.

### Friction: a surface has no default feature bodies and can't extend another, so a Java subclass restates its parent

- **Where:** A Little Java ch 8 (Like Father, Like Son), and ch 9 (a visitor interface that
  extends another).
- **What happened** (2026-09-15): `parse_defsurface` (`src/types/surface.rs:550`) accepts
  `:nature`, `:messages` (for Peer surfaces) and `:features`, nothing else. There is no default
  body, and no surface extending another. In Java, `SetEvalV extends IntEvalV` overrides
  three one-line methods and inherits the traversal. In wat, `SetEvalV` implements all four
  features again, the traversal and the identical `for-const` included
  (`books/little-java/ch08-like-father-like-son.wat`).
- **So:** sharing among implementations goes through plain helper functions each
  `extend-type` calls, or it is repeated. That may be doctrine (composition over
  inheritance), but it is unstated. Clojure's protocols share through `extend` with a map of
  functions, which can be merged.
- **Class:** friction (possibly deliberate).

### F-040: a defstruct in a Pure enum is refused as a "live resource", and the error's only way out makes the enum Impure; `defrecord`, the fix, is never named

- **Where:** A Little Java ch 9. The shapes hold a point, `Trans [q <- CartesianPt  s <-
  ShapeD]`, and the point was a `defstruct` of two i64s.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/java/struct-in-pure-enum.wat`:
  > `#wat.type/ImpureVariantFieldInPureEnum {:message "containment rule (arc 293.W.2b): :wat::enum::Pure enum \":probe::ShapeD\" may only hold pure variant fields — variant \"Trans\" field \"q\" has impure type \":probe::Pt\", which cannot be reconstructed from EDN bytes across an address-space boundary. Declare the enum :wat::enum::Impure if it must hold a live resource (it then stays in shared memory and never crosses)." :location #wat.core/Span {:file "src/check.rs" :line 15104 …}`
- **So:** the whole fix is to declare the point with `defrecord`, and the chapter does that. A
  `defstruct` has the `Struct` nature, which the rule counts as non-portable, whatever its
  fields (`validate_aggregate_containment`, `src/check.rs:15076`). The message doesn't say so:
  it calls two i64s a type that "cannot be reconstructed from EDN bytes". Its one suggestion,
  `:wat::enum::Impure`, would take the whole enum out of the portable world to keep a point
  that could have been portable. The same message was the right guide in the Little Learner,
  where the field really was a function. Its span is `rust_caller_span!()`, so it names no
  file or line of the user's (F-006).
- The docs can't help. No top-level doc in wat-rs mentions `defstruct` (`USER-GUIDE.md`,
  `WAT-CHEATSHEET.md`, `CLOJURE-ROSETTA.md`: zero each). Nothing says what separates it from
  `defrecord`: a record may cross a boundary, and a struct may not.
- **Class:** GAP (diagnostic). Correct: when the impure field is a user `defstruct` whose own
  fields are all pure, suggest declaring it with `defrecord`; locate the error at the enum's
  declaration. Clean: document `defstruct` against `defrecord`.
- **Repro:** the probe.

### Friction: a Peer surface must own every datatype its messages carry, so a datatype two services share is restated in each

- **Where:** A Little Java ch 10. The pie man's pie lives on a service, a typed `PieCell` (the
  Seasoned Schemer's cell), whose messages carry the chapter's own pie datatype, `PieD`.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - With `PieD` declared at top level, beside the functions over pies, the surface is refused
    (`probes/java/peer-messages-outside-type.wat`):
    > `surface :probe::PieCell :messages type references :probe::PieD which is not declared in this surface's :messages — a peer surface that owns :messages must declare EVERY non-stdlib type reachable from its protocol records/enums (…), so a :satisfies service ships them ALL across a process fork (arc 278 S4c). Add a (defrecord :probe::PieD …) to :messages, or remove the reference.`

    It is located in the user's file, and gives the reason and a way out.
  - Declared inside the cell's `:messages` instead, `PieD` is usable everywhere, and the
    chapter does that. The service's surface now comes first in the file, ahead of the pie
    functions.
  - A second Peer surface over the same pies can't just refer to the `PieD` the first declares.
    It is refused with the same error (`probes/java/peer-messages-shared-type.wat`).
  - It can restate `PieD` in its own `:messages`. An identical copy is accepted
    (`peer-messages-shared-type-twice.wat`). A copy with one more variant is refused as
    `DuplicateType`, located at the second copy (`peer-messages-conflicting-type.wat`).
- **So:** the rule has a reason. The forked child registers exactly what `:messages` declares
  (`src/types/surface.rs:694`). But the unit of declaration becomes the service, not the
  datatype:
  - a program's own domain type moves inside whichever service first carries it;
  - every further service restates it word for word;
  - the copies are kept in step by hand, and are refused only once they drift.

  The hint also names `defrecord` for what is an enum, and says nothing of the top-level
  declaration that has to go.
- **Class:** friction. Improve: let `:messages` name an already-declared pure type
  (`:messages [:lj::PieD (defrecord …) …]`), or ship every reachable pure type automatically,
  since the check already walks them. Correct: the hint's `defrecord` for an enum.

### C-029: A Little Java ports completely, checked against Java itself

- **Where:** all 10 chapters, 130 results (`books/little-java/`).
- **How:** each chapter's Java is our own, written from the book's classes, with `toString`s
  that print S-expressions. `tools/java-oracle.sh` compiles and runs it (JDK 27) and keeps its
  results in `oracle/java/*.expected`. The wat runner must match every line, in order.
- **The mapping:**
  - an abstract class and its variants: a Pure enum;
  - a method on every variant: a function with an arm per variant;
  - an interface: a surface (`defsurface`);
  - a visitor: a struct of its fields that `extend-type`s the surface;
  - a mutable field: a service holding the value (ch 10).
- **Better than Java:** a visitor that isn't "good" (ch 9) is the book's runtime
  ClassCastException. In wat it is refused at check time, where the new protocol is expected
  (`probes/java/old-visitor-on-new-shape.wat`).
- **Worse than Java:**
  - a partial `extend-type` runs, which Java refuses to compile (F-039);
  - `accept` is written once per answer type, the shape ch 7 sets out to remove (F-029);
  - two fish can't be compared without widening helpers (F-019);
  - surfaces have no defaults and can't extend each other (Friction);
  - there is no identity, so Java's `pie == alias` has no counterpart, and neither has ch 9's
    ClassCastException result. Both are kept as comments.
- **A correction on the record:** the visitor chapters were first written with visitors as
  structs of closures (dictionary passing, as C-023 did for ML functors). The builder pointed
  out that wat has `defsurface` and `extend-type` for exactly this, as Clojure has protocols,
  and the chapters were rewritten on surfaces. Every finding above comes from the surface
  version.

## The Clojure Koans

### C-030: the Clojure Koans' topics, ported literally: 29 of 229 rows run, and the rest say exactly why

- **Where:** `koans/` (NEXT.md §1, `koans/README.md`). There are 229 rows of our own on the
  koans' 27 topics, each true in Clojure 1.12.6. `tools/koans.clj` ports each row with only
  its namespaces changed (`wat.core/…`, or `:wat::core::…` with `SPELLING=keyword`), and runs
  each row as its own program.
- **Results** (2026-09-15, wat-rs `a3218644d`):

  | 229 rows | literal | wrong | refused | died |
  |---|---|---|---|---|
  | Clojure spelling | 29 | 2 | 147 | 51 |
  | keyword spelling | 29 | 0 | 187 | 13 |

- **What ports literally:**
  - equality of numbers, keywords, strings and nil;
  - `count`, `conj`, `nth`, `first` of a Vector;
  - `assoc`, `dissoc`, `contains?`;
  - quoting, and `->` through plain functions.
- **What doesn't, by kind:**
  - names wat lacks (the next entry);
  - Clojure's untyped forms: `(fn [x] …)`, a `defn` without types, an `if` without an else;
  - typed nil: `get`, `last` and `(:k m)` answer an Option, so comparing one with a plain
    value is a type error;
  - quoted lists are code (`WatAST`), not data, so `(first '(4 5 6))` is not 4 (C-004);
  - reader syntax: `#(…)` (F-042).
- **F-014, measured:** of the 51 rows that die at runtime in the Clojure spelling, 38 are
  refused at startup in the keyword spelling. They are arity errors, type errors, and
  malformed special forms. The 13 rows that die in both spellings are F-041 to F-045, F-007
  and F-031.
- **F-022, again:** the 2 wrong rows define a macro with `wat.core/defmacro`, which defines
  nothing, so `macroexpand` hands back the form unchanged and the koan is silently false
  (`probes/koans/defmacro-macroexpand.wat`).
- **The idiom tier** (`koans/idiom/NN-topic.wat`, `tools/koan-tiers.sh`, `koans/tiers.tsv`).
  Every row that doesn't port literally is said the way wat says it: an assertion in the
  keyword spelling that runs under `./run.sh`. Otherwise it is marked as having no route:

  | 229 rows | literal | wat idiom | missing (gap) | refused (doctrine) |
  |---|---|---|---|---|
  | | 29 | 163 | 17 | 20 |

  - **Missing:**
    - metadata (9 rows);
    - a String's `index-of` and `last-index-of` (3) and its `reverse` (1);
    - set union, intersection and difference (3, F-046);
    - the rest of an empty collection (1, F-045).
  - **Refused:**
    - `=` between values of different types;
    - predicates that static types make empty (`char?`, `string?`, `nil?` of a number);
    - collections that mix types;
    - a cell that changes type;
    - transactions;
    - classes and host objects.
  - **What the idioms cost:** each of the following was written by hand:
    - `or-else` and `none?` over Option;
    - `merge`, `merge-with`, `into-set`, `iterate`, `partition-all`, `group-by`;
    - `partial` and `comp`;
    - two-level `update-in` and `get-in`;
    - a String cell service (60 lines);
    - widening constructors for Option (F-019).
  - **Found on the way:**
    - F-046, F-047 and F-048;
    - F-009, twice more;
    - the computed-unquote friction, once more;
    - `take-nth` and `take` disagree on argument order;
    - a macro body may use `if` but not `cond`.
- **Class:** acceptance result. Every refusal is evidence.

### Clojure core names wat lacks, by the rows they block

Across both runs, wat's resolver refused 74 names that the rows use. Five exist under another
name. Rows blocked are counted once per row.

| Kind | Names (rows blocked) | wat's route |
|---|---|---|
| numbers | `inc` (13), `dec` (11), `even?` (7), `==` (2), `odd?` (1), `zero?` (1) | none; write `(+ n 1)` |
| functions | `comp` (7), `partial` (2), `complement`, `juxt`, `identity` (1 each) | none; write the `fn` |
| predicates | `nil?` (3), `string?` (2), `char?` (2), `false?`, `keyword?` (1 each) | none (types are static; `nil?` becomes a match on Option) |
| collections | `list` (10), `cons` (5), `merge` (3), `vec`, `hash-map`, `set`, `pop` (2 each), `vector`, `merge-with`, `peek`, `subvec`, `get-in`, `update-in` (1 each) | none; `vals` is `:wat::hashmap::values` |
| sequences | `for` (5), `partition` (5), `group-by` (5), `iterate`, `repeat`, `sequence`, `transduce` (2 each), `partition-all` (1) | streams (C-017) for some; `:wat::seq::window` may serve for `partition` |
| strings | `blank?` (3), `index-of` (2), `last-index-of`, `split-lines`, `symbol` (1 each) | `subs` is `:wat::string::subs`, `reverse` is `:wat::core::reverse`, `keyword` is `:wat::keyword::from-string` |
| sets | `union`, `intersection`, `difference` (1 each) | none |
| control | `case` (2), `try`/`catch` (2), `if-not`, `loop`/`recur` (1 each) | `match`; `Result/try` (C-006); recursion |
| state | `atom` (7), `ref` (7), `reset!`, `ref-set`, `dosync` (5 each), `swap!`, `alter` (3 each), `compare-and-set!` (2), `deref` (1) | services, by doctrine (C-014) |
| types and dispatch | `defmulti`/`defmethod` (8), `deftype` (3), `defprotocol` (1) | `defsurface` + `extend-type` (C-029); `match` on the dispatch value |
| metadata | `meta`, `with-meta` (6 each), `vary-meta` (3) | none |
| printing | `pr-str` (1) | `:wat::edn::write` |
| host | `class`, `Math/pow` (1 each) | none (no JVM, and no power function) |

- **So:** most of what a Clojure programmer reaches for first is missing under its Clojure
  name, even where the spelling claims to be Clojure's: the number helpers, `comp` and
  `partial`, `list`, `merge`, `for`, `group-by`, `partition`, `case`. The state, dispatch and
  exception names are refused by doctrine, and each has a route that earlier books took. The
  rest are ordinary gaps.
- **Class:** Extend (the small functions: PROVIDE.md P-017), and Clean (a Clojure-name to
  wat-route table, where one exists; `CLOJURE-ROSETTA.md` has none of these).

### F-041: `str` takes exactly one argument, and a call with more passes the checker in either spelling

- **Where:** the Clojure Koans, 02-strings row 3 and 25-threading-macros row 2.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/koans/str-arity.wat`:
  `(:wat::core::str "pear" " and " "plum")` passes the checker in the keyword spelling, and
  dies at runtime:
  > `#wat.runtime/ArityMismatch {:message ":wat::core::str: expected 1 arguments, got 3" …}`
- **So:** Clojure's `str` is variadic, and so is the one wat-rs's own Clojure-parity corpus
  expects (`tests/clj_expr_oracle/corpus.txt`: `(wat.core/str "a" "b" 1)` → `"ab1"`; that
  test is `#[ignore]`d). The arity of this builtin isn't checked at all, and in the keyword
  spelling F-014 doesn't explain that.
- **Class:** GAP. Fix: check `str`'s arity. Extend: make `str` variadic, as the parity corpus
  expects.
- **Repro:** the probe.

### F-042: the reader takes `#(…)` as the symbol `#` followed by a list, and the program fails only when it runs

- **Where:** the Clojure Koans, 07-functions rows 4–6 and 23-meta row 6.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/koans/anon-fn-literal.wat`:
  `(#(:wat::core::+ % 1) 2)` parses and passes the checker, and then:
  > `#wat.runtime/UnboundSymbol {:message "unbound symbol: #" …}`
- **So:** Clojure's anonymous-function literal is neither supported nor refused. The reader
  takes `#` for a symbol, and the program ships until the line runs. F-013 (`#_`) is the
  same reader family. There, the reader refuses loudly.
- **Class:** GAP. Fix: refuse `#(` at read time, naming it. Extend: read it as `fn`.
- **Repro:** the probe.

### F-043: a map in call position passes the checker, and fails at runtime as a "malformed map form"

- **Where:** the Clojure Koans, 06-maps rows 5 and 7. In Clojure a map is a function of its
  keys: `({:x 1 :y 2} :x)` is 1.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/koans/map-as-function.wat`: the
  program starts, and then:
  > `#wat.runtime/MalformedForm {:message "malformed map form: call head must be a keyword, symbol, or list" …}`
- **So:** a call head the runtime can never accept is seen only at runtime, in either
  spelling.
- **Class:** GAP. Fix: refuse it at check time (the message is already right). Extend: a
  map as a function of its keys, as a keyword already is (F-044).
- **Repro:** the probe.

### F-044: a keyword lookup, `(:k m)`, answers an Option, and the checker doesn't type it

- **Where:** the Clojure Koans, 06-maps row 6: `(= 2 (:y {:x 1 :y 2}))`.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/koans/keyword-as-function.wat`: `(:y {:x 1 :y 2})` is
    `#wat.core/Option.Some {:value 2}`, and `(:z …)` is `Option.None`. As with `get`, this
    is typed nil, and consistent.
  - `probes/koans/keyword-lookup-equals.wat`: in the keyword spelling,
    `(:wat::core::= 2 (:y {:x 1 :y 2}))` passes the checker, and dies at runtime:
    > `#wat.runtime/TypeMismatch {:message ":wat::core::=: expected matching comparable pair, got wat::core::i64 `2`" …}`
- **So:** comparing an i64 with an Option is a type error the checker catches everywhere
  else. A keyword-headed lookup reaches the runtime untyped, so a mistake with one ships.
- **Class:** GAP. Fix: give `(:k m)` its type, `Option<V>`, at check time.
- **Repro:** the two probes.

### F-045: `first` and `rest` die on an empty collection, and are labelled a malformed form; `first` answers T but `last` an Option

- **Where:** the Clojure Koans, 03-lists row 12 (`(rest '())`) and 04-vectors row 7
  (`(last v)`). Clojure's `first`, `last` and `rest` are total: nil, nil and `()`.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/koans/rest-of-empty.wat`: `(rest <empty Vector>)` dies:
    > `#wat.runtime/MalformedForm {:message "malformed :wat::core::rest form: cannot take rest of empty Vec" …}`

    `(rest '())` dies the same way ("cannot take rest of empty form").
  - `first` of an empty Vector dies labelled a malformed form too (Friction, Little Typer).
  - `probes/koans/first-last.wat`: on `[4 5 6]`, `first` answers `4`, and `last` answers
    `#wat.core/Option.Some {:value 6}`.
- **So:**
  - Two of the three are partial, and nothing at check time says so.
  - Their failure is labelled a malformed *form*, when the form is fine and the collection is
    empty.
  - The pair that Clojure makes symmetric answers different types. `last` is the one that
    is total, which is Clojure's contract written in types, so `first` looks like the outlier.
- **Class:** GAP. Correct: say "empty collection", not "malformed form". Improve: give
  `first` and `rest` the totality `last` has (an Option, and an empty collection).
- **Repro:** the probes.

### F-046: a HashSet's elements can't be reached: nothing enumerates a set

- **Where:** the Clojure Koans, 05-sets rows 4–6 (union, intersection, difference).
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `(:wat::core::foldl f init #{3 4 5})` is refused:
    > `:wat::core::foldl: parameter #3 expects (Vector :- [T]), (PersistentVector :- [T]), (List :- [T]), or (Stream :- [T]); got (:wat::core::HashSet :- [:wat::core::i64])`
  - `probes/koans/hashset-elements.wat`: `(:wat::core::into (Vector :- [i64]) #{3 4 5})` is
    refused: "no clause of `:wat::core::into` matches arity 2 with types
    [(:wat::core::Vector :- [:wat::core::i64]), (:wat::core::HashSet :- [:wat::core::i64])]".
  - A set's intrinsics are its constructor and `:wat::hashset::conj`, `contains?`, `empty?`
    and `length`: nothing else. In the runtime, a HashSet is named only in an arm that the
    `ordered()` gate makes unreachable (`src/collection/eval.rs:494`).
- **So:** a set can be built, asked about one element, counted and compared. Its elements can
  never be read back out. So no union, intersection or difference can be written, nor
  anything else that visits a set's members. Clojure's sets are seqs.
- **Class:** GAP. Extend: make a HashSet Seqable (for foldl, into, and a Stream of its
  elements in some order), then add the set operations (P-017).
- **Repro:** the probe.

### F-047: a bigint is not orderable: `<` refuses it

- **Where:** the Clojure Koans, 14-recursion row 11: `(< 1000000000000000000000000N (fact 25N))`.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/koans/bigint-literal.wat`: wat reads the literal, and prints it back as
    `1000000000000000000000000N`.
  - It has `:wat::i64::to-bigint`, and bigint `+`, `-`, `*` and `/`.
  - But `probes/koans/bigint-compare.wat` is refused:
    > `:wat::core::<: parameter #1 expects an orderable type (i64, u8, f64, String, bool, keyword, Instant, Duration, (Vector :- [T]), Tuple, (Option :- [T]), (Result :- [T E])); got :wat::core::bigint`
- **So:** big integers can be computed but not compared, except by converting them to f64,
  which loses digits above 2^53. The idiom does that.
- **Class:** GAP. Extend: make `:wat::core::bigint` orderable.
- **Repro:** the two probes.

### F-048: a record's accessor, passed to a generic function, types its parameter as `:wat::core::Record`; beside a HashMap of the record, the call is refused

- **Where:** the Clojure Koans, 22-group-by rows 3–4. A generic `group-into` over `[T :-> K]`
  and a `(HashMap :- [K (Vector :- [T])])` is given `:koan::Person/id`.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/koans/record-accessor-generic.wat`: with a `(Vector :- [:probe::Person])` for
    `(Vector :- [T])`, the accessor works, and prints `[7 8]`.
  - `probes/koans/record-accessor-generic-map.wat`: with a
    `(HashMap :- [i64 (Vector :- [:probe::Person])])` for the map parameter, it is refused:
    > `:probe::group-count: parameter #2 expects (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::Record])]); got (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:probe::Person])])`
- **So:** the accessor binds T to the record nature, `:wat::core::Record`, instead of to the
  record it is given. When T also sits inside another argument's type, that argument must
  then hold plain `Record`s. The same accessor works in one generic call and not in the
  next. Wrapping it in a typed `fn` works, and the idiom does that.
- **Class:** GAP. Fix: type a record's accessor over its own record,
  `[:probe::Person :-> :wat::core::i64]`.
- **Repro:** the two probes.

### Friction: `take-nth` takes its count first, and `take` and `drop` take the collection first

- **Where:** the Clojure Koans, 21-partition (`koans/idiom/21-partition.wat`).
- **What happened** (2026-09-15): `(:wat::core::take-nth (window xs n) step)`, written in
  `take`'s order, is refused: "`:wat::core::take-nth`: parameter #1 expects
  :wat::core::i64". `take-nth` follows Clojure, `(take-nth n coll)`. Its neighbours don't:
  `take` and `drop` take the collection first (the Little Learner's friction).
- **So:** three neighbouring functions disagree on argument order within wat itself, so the
  order has to be looked up for each one.
- **Class:** friction. Clean: one argument order for the sequence functions.

### Friction: a macro body may use `if` and `let`, but not `cond`

- **Where:** the Clojure Koans, 24-macros (`recursive-infix`).
- **What happened** (2026-09-15), a program-body macro using `:wat::core::cond`:
  > `malformed defmacro: program-body macro purity check failed at definition: keyword head `:wat::core::cond` refused at macro expand time — not on the pure-combinator allow-list (default-deny F5 gate, arc 249 stone 249.2b-i); only pure-total heads are permitted`

  The same logic as nested `if`s passes, and the idiom uses them.
- **So:** `cond` is as pure as the `if`s it stands for, but the allow-list names one and not
  the other. The same macro also hit the computed-unquote friction (the Reasoned Schemer):
  `~(second form)` evaluated the macro's argument as code ("malformed int form"), so the
  form is taken apart by `let` first.
- **Class:** friction. Improve: allow `cond` in a macro body.

## Make-a-Lisp

### F-049: a wat program can't write raw text to stdout: `println` writes EDN, a line at a time, and the raw writers are the kernel's

- **Where:** Make-a-Lisp (NEXT.md §2). mal's test runner (`vendor/mal/runtest.py`) drives an
  implementation as a REPL. It waits for a prompt (`user> `, with no newline), sends a line,
  and matches what comes back.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `:wat::kernel::println` "serializes `v` to compact EDN and writes the line to stdout" (its
    doc). So a String comes out quoted and escaped: `probes/mal/read-frame-raw.wat` prints
    `"frame 1: abc"`, quotes and all. Every chapter's "ok" line in this repository prints that
    way.
  - `:wat::io::IOWriter/from-fd` is restricted to `:wat::kernel::`
    (`probes/mal/stdin-repl.wat`), and so is `IOReader/from-fd`:
    > `` `:wat::io::IOWriter/from-fd` has a restricted caller whitelist [:wat::kernel::]; the enclosing fn `:user::main` does not match any entry ``
  - A three-argument `:user::main` taking stdin, stdout and stderr is refused at freeze
    (wat-rs `tests/program/wat_arc170_slice_1e_user_main_nil.rs`).
- **So:** no wat program can print a prompt, a line without its newline, or a String without
  quotes. That rules out mal's REPL, a CSV file, a report, or any line of plain text. Every
  other language on mal's scoreboard can do it. Here a 40-line Python shim
  (`tools/mal-shim.py`) stands in: it prints the prompt, and turns each EDN string the
  program prints back into text.
- **Class:** GAP. Extend: a raw write to stdout (a String, no newline, no EDN).
- **Repro:** the probes.

### F-050: stdin is read by EDN frame, so a line that opens more than it closes swallows the lines after it, and end of input then panics

- **Where:** Make-a-Lisp step 1. Its tests send `(1 2`, `"abc` and the like, each on its own
  line, and expect an "unbalanced" error for that line alone.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/mal/read-frame-raw.wat`: balanced lines come back one frame each, raw, even when
    they aren't EDN (`[]{}"'* ;:()`).
  - `probes/mal/read-frame-unbalanced.wat`, given `(+ 1 2`, then `abc`, then `(x`: no frame
    comes back at all. The reader keeps reading while its buffer is incomplete EDN, and at end
    of input it dies:
    > `#wat.kernel/LociDiedError.Panic {:message "disconnected" … :frames [#wat.kernel/Frame {… :symbol ":wat::kernel::stdio-read-frame"} …]}`

    `wat/repl.wat` says EOF comes back "as a VALUE (`ReadFrameOutcome::Eof`)".
- **So:** a program can't read a line as a line. wat's own REPL names part of this limit ("a
  multi-line form … reaches read-string truncated", `wat/repl.wat:121`). An unbalanced line
  is worse, because it takes the following input with it. The shim sends each line as one EDN
  string, which the program decodes with `:wat::edn::read`.
- **Class:** GAP. Fix: at end of input, answer `Eof` (or the partial frame), not a panic.
  Extend: a plain `read-line` for user programs.
- **Repro:** the probes.

### Friction: the user guide's first stdin program is refused

- **Where:** USER-GUIDE.md §2, "Your first real program — stdin echo".
- **What happened** (2026-09-15): copied verbatim (`probes/mal/user-guide-stdin-echo.wat`), the
  program is refused at startup, twice over:
  > `bare unit type '()' is retired (arc 109 slice 1d); canonical FQDN form is ':wat::core::nil'`

  It is also written with the retired `:wat::core::define`, with `(Some line)` patterns, and
  with the three-argument main that freeze now refuses. The route that works,
  `:wat::kernel::read-frame` and `println`, has to be found in `wat/repl.wat`.
- **Class:** Clean.

### F-051: a message to a service costs about 0.22 ms, a hundred times a function call, so state kept on a service is slow to use

- **Where:** Make-a-Lisp step 5. mal's environments live on a store service
  (`mal/lib/env.wat`), as wat's doctrine keeps state. A mal call costs about 3.3 ms, linearly:
  `(sum2 N 0)` takes 1.8 s at N=500, 3.4 s at 1000, 6.6 s at 2000 and 13.1 s at 4000. The
  10000-deep tests overrun runtest's 20 s per-test default; they pass with
  `--test-timeout 300`, 65 s for the whole step.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/mal/service-roundtrip-cost.wat` sends 5000 `add` messages to the Seasoned
    Schemer's counter (one i64, on a thread), in 1422 ms.
  - `probes/mal/function-call-cost.wat` runs the same loop with a plain function call where
    the message was, in 301 ms.
  - Any program's startup takes about 290 ms. So a message costs about 224 µs, and a function
    call under 2 µs.
- **So:** a mal call is about a dozen messages: a new environment, one bind per parameter,
  one lookup per symbol. Hence 3 ms a call. The doctrine puts mutable state on services, and
  each access to it costs about a hundred function calls. A store value threaded through eval
  would avoid the messages, but that is not the doctrine's route. Where the time goes isn't
  measured here: encoding each message as EDN, the thread handoff, or both.
- **Class:** GAP (performance). Improve: a cheaper path to a service on a thread locus.
- **Repro:** the two probes.

### Friction: one more variant of an interpreter's value type is twenty edits in ten files

- **Where:** Make-a-Lisp steps 4, 6 and 8. mal's value type (`:mal::Val`, `mal/lib/types.wat`)
  grew a closure, then an atom, then a macro, to 14 variants.
- **What happened** (2026-09-15): no match may have a catch-all arm, by this repository's
  rule and the builder's doctrine that an arm can't be forgotten (F-025). So every function
  that takes a value apart names all 14 variants. Adding `Macro` meant an arm in each of these:
  - nine helpers (`int-of`, `str-of`, `sym-of`, `seq-of`, `list-of`, `builtin-of`, `atom-of`,
    `kind-of`, `falsy?`);
  - the printer, and `show-atoms`;
  - six steps' `eval`, and four steps' `apply`.

  That is about twenty edits across ten files, for arms that all say "not this". The checker
  caught every one I missed, which is the doctrine working. What it costs is the typing.
- **So:** a `kind-of` helper that names the variant once turns each later test of a value's
  kind into a keyword comparison (`mal/lib/types.wat`). A catch-all that the checker knows to
  mean "every other variant, each listed in the error when one is added" would keep the
  doctrine and drop the repetition.
- **Class:** friction. Improve: an explicit "every other variant" arm that still reports which
  variants it covers.

### C-031: Make-a-Lisp step 0 passes mal's own tests

- `mal/step0_repl.wat`, driven by mal's unmodified runner through the shim
  (`tools/mal-test.sh step0_repl`), passes 24 of 24.

### C-032: Make-a-Lisp passes mal's own tests at every step: 909 of them, and every hard one

- **Where:** `mal/`, all 11 steps (`mal/README.md`), driven by mal's unmodified runner through
  the shim (`tools/mal-all.sh`).
- **Results** (2026-09-15, wat-rs `a3218644d`):

  | step | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | A |
  |---|---|---|---|---|---|---|---|---|---|---|---|
  | passing | 24 | 121 | 15 | 33 | 199 | 8 | 71 | 115 | 58 | 173 | 92 |
  | optional, not passing | | | | 5 | | | | 9 | 3 | | 21 |

  The 38 optional failures are 17 DEBUG-EVAL traces, not implemented, and 21 metadata tests.
  Values keep no metadata; `with-meta` hands its value back. mal's self-hosting test (mal in
  mal, run on this mal) was not attempted.
- **How:**
  - mal's values are pure data. A builtin is its name; a closure or a macro is its
    parameters, body and environment's id; an atom is its id.
  - mal's environments and atoms live on a store service, as wat's doctrine keeps state
    (C-014). So the mutable state of a language written in wat is wat state on a service.
  - mal's tail calls are wat's own: step 5 is step 4 unchanged, recurring 10000 deep, and
    mutually so.
  - Every error, a thrown value included, is an evaluation's `Err`, so `try*` is a match.
  - Steps 1–4 and 6–A passed their hard tests on the first full run. Step 0 first failed on
    the shim's missing echo, and step 5 on runtest's timeout (F-051), not on the
    interpreter.
- **What it cost:**
  - the shim (F-049, F-050);
  - 3 ms a call on a service-held environment (F-051);
  - twenty edits for each new variant of the value type (Friction).
- **Class:** acceptance result.

## SICP

### F-052: a function can't answer a connected peer, and an address that has been through a parameter connects to nothing usable

- **Where:** SICP §3.1 and §3.4 in wat. An account is a service; a second access point to one
  account is a second connect to its address, and a worker on another thread dials the account
  for itself.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - **A function that answers a peer is refused** (`probes/sicp/connect-return-type.wat`):
    > `:probe::connect-to: body produces (:wat::kernel::Peer :- [:?1461 :?1462]); signature declares :probe::Cell`
  - **A peer passed as an argument is fine** (`probes/sicp/peer-as-parameter.wat`, which runs
    and prints 7): connecting to the address read straight off a typed handle gives a peer that
    is the surface's type, and it passes to a function declared to take one.
  - **An address declared as a bare `:wat::kernel::Address` does not**
    (`probes/sicp/connect-bare-address.wat`, a worker dialling a service it was handed):
    > `:probe::read-once: parameter #1 expects :probe::Cell; got (:wat::kernel::Peer :- [:?2830 :?2831])`

    The peer's two type parameters stay unresolved, so the connection speaks to nothing: a
    parameter refuses it, and so does a struct field.
- **So:** an address carries its service's protocol in its type, and the spelling that keeps it
  is `(:wat::kernel::Address :- [<Surface>::Op <Surface>::Reply])`, as the stdlib's own
  services declare it (`wat/kernel/services/stdio.wat`). Declared bare, the type is lost and
  the error names only two unresolved variables — not what to write instead. With the full
  spelling, a worker on another thread can dial the service and speak to it
  (`sicp/ch34-concurrency.wat`).
- **Class:** GAP. Fix: let a function declare a peer's type as its surface's name. Correct: when
  a connect answers a peer whose parameters are unresolved, say that the address needs its
  protocol (`Address :- [X::Op X::Reply]`). Clean: the guide never shows the address spelling.
- **Repro:** `probes/sicp/connect-return-type.wat` (a function answering a peer),
  `probes/sicp/peer-as-parameter.wat` (a peer as an argument, which works),
  `probes/sicp/connect-bare-address.wat` (an address without its protocol).

### F-053: a forced lazy stream doesn't remember, so walking one twice computes it twice

- **Where:** SICP §3.5 in wat (`sicp/ch35-streams.wat`). Its nine values match guile's, but the
  chapter's point is that `delay` memoizes: an element is computed once, however often the
  stream is walked.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/sicp/stream-memo.wat`. One stream
  value, `(smap counted (integers-from 1))`, walked three times, each computation counted on a
  counter service:

  | walked | wat computed | guile computed |
  |---|---|---|
  | the first five | 5 | 6 |
  | the same five again | 10 | 6 |
  | the first seven | 17 | 8 |

- **So:** `:wat::stream::lazy` re-evaluates its body at every force. A stream is lazy but not
  shared: an algorithm that walks one twice pays twice, and SICP's feedback definitions (§3.5.3's
  integral, the implicit fibs) would cost exponentially instead of linearly. Scheme's `delay`
  memoizes, and so do Clojure's lazy seqs.
- **Class:** GAP. Extend: remember a forced thunk, or offer a memoizing stream beside the
  re-evaluating one, and say which is which.
- **Repro:** the probe.

### F-054: a definition that names itself reads its own name as a keyword, and the error says only "got `:wat::core::keyword`"

- **Where:** SICP §3.5 defines the Fibonacci stream by naming it inside its own definition:
  `(define fibs (cons-stream 0 (cons-stream 1 (add-streams (stream-cdr fibs) fibs))))`. Only the
  delay makes that honest.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/sicp/self-referential-stream.wat`:
  four type-check errors, the first being
  > `:probe::rest-of: parameter #1 expects :probe::IntStream; got :wat::core::keyword`

  Inside its own body the name `:probe::fibs` is a keyword literal (F-020's family: a bare
  keyword is a value), so the complaint is about a type, and nothing says that a definition
  can't name itself.
- **So:** a stream defined in terms of itself can't be written; `sicp/ch35-streams.wat` writes
  fibs as a function of its two seeds instead, and the Scheme oracle says it the same way so
  that the two agree on how, not only on what. Mutually recursive `defn`s are fine (C-008), so
  this is about values, not functions.
- **Class:** GAP. Correct: say that a definition cannot refer to itself, where the type error
  is now. Extend: let a `def` whose body is lazy name itself, as Scheme's `define` does.
- **Repro:** the probe.

## Advent of Code

### F-055: walking a Vector by `rest` copies it, so the idiomatic walk is quadratic

- **Where:** the Advent of Code puzzles in wat (`aoc/`). Every puzzle walks its input, and the
  two ways a functional program does that are `(rest xs)` down to empty and `(conj acc x)` up
  from empty.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/aoc/nth-scaling.wat`, one Vector of 20000 numbers, summed twice:

    | walked | time |
    |---|---|
    | by index, with `nth` | 250 ms |
    | by `rest`, to the end | 4869 ms |

  - `probes/aoc/conj-subs-scaling.wat`: `conj` 5000 times takes 292 ms and 10000 times 1057 ms
    — four times the work for twice the elements. One-character `subs` is linear: 2000
    characters in 25 ms, 4000 in 54 ms.
- **So:** `rest` clones what is left of the Vector, as `conj` clones the whole of it (F-023).
  Indexing with `nth` is constant, at about 12 µs. A 2000-line puzzle input is comfortable
  either way; a 20000-line one is five seconds of copying, for a sum. Strings are not the
  problem: scanning a grid character by character is linear.
- **Class:** GAP (performance). Improve: let `rest` on a Vector be a view rather than a copy.
  Clean: say which sequence type is meant for walking — a `PersistentVector` exists, and
  nothing points a user to it.
- **Repro:** the two probes.

### F-057: `HashMap` and `HashSet` copy on every insert, while `PersistentMap` shares — and nothing tells the user which to reach for

- **Where:** the shortest-path puzzle (`aoc/day05-paths.wat`), which took 135 s where its
  Clojure reference takes 2.8 s. Nearly all of its work is putting squares into a hash map of
  buckets and a hash set of settled squares: 90000 of them.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/aoc/map-insert-scaling.wat`,
  filling each structure at n and at 2n:

  | filled | n = 2000 | n = 4000 | ratio |
  |---|---|---|---|
  | a hash map, by `hashmap::assoc` | 84 ms | 341 ms | 4.1× |
  | a hash set, by `hashset::conj` | 45 ms | 163 ms | 3.6× |

  Twice the entries cost four times the time: each insert copies what is already there. Reading
  is not affected — 4000 lookups in the 4000-entry map take 41 ms, about 10 µs each.
- **And `PersistentMap` does share** (`probes/aoc/persistent-insert-scaling.wat`, both filled in
  the same run):

  | filled | n = 2000 | n = 4000 | ratio |
  |---|---|---|---|
  | `HashMap`, by `hashmap::assoc` | 106 ms | 381 ms | 3.6× |
  | `PersistentMap`, by `map::assoc` | 20 ms | 40 ms | 2.0× |

  Linear, and already ten times faster at 4000 entries, with the gap widening.
- **And nothing is given up for it.** `probes/aoc/persistent-arity.wat` and
  `probes/aoc/persistent-valuetype.wat`, each beside a HashMap control that is refused the same
  way: `:wat::map::get` handed seven arguments is refused at startup (`:wat::map::get: expected
  2 argument(s); got 7`), and a `PersistentMap` declared `[:wat::core::i64 :wat::core::i64]`
  propagates its value type, so using that value as a String is refused (`:probe::want-string:
  parameter #1 expects :wat::core::String; got :wat::core::i64`). The fast container is checked
  as closely as the slow one. Worth saying because wat-rs's own note of 2026-08-20,
  `docs/arc/2026/04/109-kill-std/NOTE-the-persistent-family-is-outside-the-type-checker.md`,
  measured the opposite — thirteen persistent verbs blanket-accepted, their annotations
  "INERT" — but that was the retired `PersistentMap/get` spelling; at `a3218644d` the
  `:wat::map::`/`:wat::vector::` intrinsics carry real schemes. **The note is stale**, and it is
  the kind of note a reader would act on.
- **So:** wat has the container that shares structure and the container that copies, and the
  one everybody reaches for is the copying one. `HashMap` is what the examples use, what the
  stdlib's own services keep their state in, and what the name suggests; `PersistentMap` is
  named for its persistence, not for being the one to accumulate into. A program that builds a
  frequency count, a visited set, a memo table or a graph frontier out of `HashMap` is
  quadratic in what it accumulates, and nothing says so. **Measured on the real workload:** the
  same program, the same two answers, back to back on an idle machine —

  | `aoc/day05-paths.wat`, 90000 squares | wall |
  |---|---|
  | frontier and settled set as `HashMap`/`HashSet` | 135.1 s |
  | the same, as `PersistentMap` | 20.6 s |

  6.5× for a change of a dozen lines: `:wat::hashmap::` became `:wat::map::`, `:wat::core::conj`
  became `:wat::vector::conj`, and `:wat::hashset::conj` became an assoc of `true`, there being
  no persistent set. The puzzle looked like evidence that wat is 45 times slower than Clojure
  here; it was evidence about the container. The same split is open for `Vector` against
  `PersistentVector` (F-023, F-055).
- **Class:** GAP. Clean: say, where `HashMap` is documented, that an accumulating map should be
  a `PersistentMap`. Improve: make `hashmap::assoc` share, or have the checker say which
  container a growing map wants.
- **Repro:** the two probes.

### F-056: there is no ordered collection: no sorted set, no sorted map, no priority queue, no heap

- **Where:** the shortest-path puzzle (`aoc/day05-paths.wat`). Dijkstra's algorithm takes the
  cheapest square waiting, which is what a priority queue is for; the Clojure reference keeps
  its frontier in a sorted set (`oracle/aoc/day05-paths.clj`).
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/aoc/sorted-structures.wat`, which
  asks for each ordered structure by name:
  > `4 unresolved references`: `:wat::core::sorted-set`, `:wat::core::sorted-map`,
  > `:wat::core::priority-queue`, `:wat::core::heap`

  What exists is `:wat::core::sort` and `:wat::core::sort-by`, which sort a whole collection at
  once, and the four containers: Vector, PersistentVector, HashMap, PersistentMap, HashSet,
  List.
- **So:** a frontier can't be kept in order as it grows. Sorting it again at each step is
  quadratic on top of the copying (F-055), so the wat solution keeps a bucket per cost — Dial's
  algorithm — which works only because each step's cost is between 1 and 9. A puzzle with
  arbitrary weights would have nothing to fall back on.
- **Class:** GAP. Extend: a priority queue (a binary heap is enough), or an ordered map or set.
- **Repro:** the probe, and `aoc/day05-paths.wat` for what the absence costs to work around.

### F-058: a `PersistentMap`'s bracketed type must be a keyword, so a map of vectors cannot be written the way a `HashMap`'s can

- **Where:** taking F-057's own advice, in `aoc/day05-paths.wat`. The frontier is a map from a
  cost to the squares waiting at that cost — a map whose values are vectors.
- **What happened** (2026-09-15, wat-rs `a3218644d`), from
  `(:wat::core::PersistentMap :- [:wat::core::i64 (:wat::core::PersistentVector :- [:wat::core::i64])])`
  (`probes/aoc/persistent-nested-type.wat`), verbatim:
  ```
  malformed :wat::core::PersistentMap form: bracketed type must be a type keyword
  ```
- **The control passes.** The same nesting on the copying twin,
  `(:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::i64])])`, is
  accepted and runs (`probes/aoc/persistent-nested-type-control.wat`) — and it is what day05
  was built on before the conversion. So this is not a rule about nested types.
- **And the container is not the limit.** Naming the inner type first and putting that name in
  the brackets is accepted, and the map holds and returns the vector
  (`probes/aoc/persistent-nested-type-alias.wat`, which prints 1 then 7):
  ```
  (:wat::core::typealias :probe::Cells (:wat::core::PersistentVector :- [:wat::core::i64]))
  (:wat::core::PersistentMap :- [:wat::core::i64 :probe::Cells])
  ```
- **So:** the refusal is about the spelling, not about what a `PersistentMap` can hold, and it
  lands on precisely the users F-057 sends to the persistent family — the first thing you want
  to accumulate is often a map of collections. The diagnostic carries `:remedies []`, though the
  remedy is a single typealias.
- **Class:** GAP. Fix: accept a parametric type form inside a persistent constructor's brackets,
  as the std constructors do. Failing that, Correct: have the message say to name the inner type
  with a typealias.
- **Repro:** the three probes.

## PAIP

### F-059: a dotted pair reads as a three-element list with `.` as an ordinary symbol, and prints back as a dotted pair

- **Where:** PAIP chapter 12's membership clause, the classic recursive one, whose head carries a
  list with a variable tail:
  ```
  ((member ?i (?i . ?rest)))
  ((member ?i (?head . ?rest)) (member ?i ?rest))
  ```
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/paip/dotted-pattern.wat`:
  ```
  source of (?i . ?rest): (?i . ?rest)
  kind of (?i . ?rest): list
  children of (?i . ?rest): 3
  each child: ?i | . | ?rest
  ```
  The form reads. It is a `"list"`. Its children are **three** nodes — `?i`, the symbol `.`, and
  `?rest` — so the dot is an ordinary symbol and there is no tail. `ast->source` then prints it
  back as `(?i . ?rest)`, so it round-trips and looks preserved.
- **So:** quoted data cannot express a pattern with a variable tail, and does not say so. A
  dotted pair is not refused, not flagged, and not lost on the round trip; it is silently a
  different structure — a three-element proper list containing a symbol named `.`. Any port that
  reads Lisp source with dotted pairs in it (a Prolog's clause heads, an association list, an
  improper argument list) gets a form that prints correctly and means something else. This is
  the same wall The Reasoned Schemer hit and built its way around:
  `books/reasoned-schemer/lib/ch10-under-the-hood.wat` says "Quoted lists can't hold a pair with
  a variable tail, `(a . d)`, so terms are their own enum" — that is `:rs::Term`'s whole reason
  for existing, arrived at independently.
- **The consequence for NEXT.md §5.** Chapter 11's unification ports to quoted data completely
  (C-033) because every pattern in it is a proper list. Chapter 12 is where quoted data runs
  out: the family-tree half needs no dotted heads and ports, and the membership half cannot be
  written at all. That is the answer to "quoted data versus typed data" — quoted data carries
  symbolic pattern matching right up to the improper list, and no further.
- **Class:** GAP. Fix: read a dotted pair as a pair, or refuse it — either is honest; printing
  it back unchanged while meaning a three-element list is not. Extend: if wat is not to have
  improper lists, `ast-kind` or the reader should say so at the dot, rather than admitting a
  symbol named `.` into a list.
- **Repro:** `probes/paip/dotted-pattern.wat`.

### C-033: PAIP's unifier ports to quoted data, with no term language at all

- **Where:** `paip/ch11-unification.wat` on `paip/lib/unify.wat`, checked against guile
  (`oracle/paip/ch11-unification.scm`, 25 results).
- **What NEXT.md §5 asked:** chapters 11–12 are "where quoted data versus typed data gets
  decided". The Reasoned Schemer had already answered for typed data — `:rs::Term` is a
  four-variant enum and `rs/q` converts a quoted form into it immediately, because a quoted list
  cannot hold a pair with a variable tail. PAIP asks the opposite: a pattern **is** an
  S-expression, and a variable is the symbol `?x`.
- **What happened** (2026-09-15, wat-rs `a3218644d`): it ports directly, and passed on the first
  run — 25 of 25 results matching guile. Nothing is converted; `:wat::WatAST` is walked as it
  stands. What carries it (measured first in `probes/paip/ast-as-data.wat`):
  - `ast-kind` is total — `"symbol"`, `"list"`, `"int"` — and gates everything;
  - `ast-name` gives a symbol's verbatim text, so `?x` is recognised by
    `(:wat::string::starts-with? (:wat::core::ast-name x) "?")`. It **raises** on a node that is
    not a Symbol/Keyword/StringLit, so the kind test must come first; that ordering is the only
    trap in the chapter;
  - `ast->children` decomposes a list and yields nothing for a leaf, so PAIP's car/cdr recursion
    becomes an index walk with a length test where the two lists would run out together;
  - `with-children` rebuilds a node of the same kind, which is the whole of `subst-bindings`;
  - `=` is structural on nested forms, which is PAIP's `equal?`;
  - `ast->source` prints a node back as source, and prints `(2 + 1)` and `(?x (f ?y))` exactly
    as guile prints them — so the chapter needs no printer of its own.
- **Two choices worth recording:**
  - the substitution maps a variable's **name** to a term, not a node to a term: two `?x` nodes
    read from two different quoted forms are different AST nodes but one variable;
  - it is a `PersistentMap`, which shares structure where a `HashMap` copies on every insert
    (F-057) — a unifier extends its substitution once per variable it meets. F-057's lesson,
    applied in a new suite rather than rediscovered.
- **Failure is `Option.None`.** PAIP uses the symbol `fail`; wat has no failure marker, and an
  enum of two cases would be the typed representation this chapter exists to avoid.
- **Mutual recursion across definition order is accepted:** `occurs-in?`/`occurs-in-all?`,
  `unify`/`unify-variable`/`unify-all` and `subst`/`subst-all` each call a function defined
  below them, and the checker resolves it.
- **Class:** CLEAN.

### C-034: PAIP's Prolog runs on quoted clauses, with backtracking and renaming, and no term language

- **Where:** `paip/ch12-prolog.wat` on `paip/lib/prolog.wat`, checked against guile
  (`oracle/paip/ch12-prolog.scm`, 33 results). It reuses `paip/lib/unify.wat` whole — which is
  what building chapter 11 first was for.
- **What happened** (2026-09-15, wat-rs `a3218644d`): 33 of 33 results match, on the first run.
  A clause is a quoted list, head first and goals after; the database is a `Vector` of them.
  `ast->children` splits a clause, `first`/`rest` take it apart, and nothing is converted into a
  term type anywhere.
- **Renaming works, and the last query is what proves it.** A clause's variables are renamed
  apart before each attempt (`?x` → `?x-1`), or a rule that calls itself collides with itself.
  `ancestor` is that rule, and `(ancestor ?a ?d)` must yield nine pairs: the five direct
  `parent` facts from the base clause, then four transitive ones from the recursive clause. Get
  renaming wrong and the transitive four vanish or duplicate. All nine match guile.
  `:wat::core::symbol-node` builds the renamed variable, and `probes/paip/renamed-symbol.wat`
  shows it round-trips through `ast-name` and still satisfies `variable?`. The separator is `-`
  and not PAIP's `.`, because a dot carries reader meaning inside a list (F-059).
- **The counter is threaded, not kept.** Renaming needs a fresh number per attempt, which is
  mutable state; wat has no mutable variable. The two honest routes are threading a number
  through the recursion or keeping one on a counter service (C-014's doctrine). Threading won:
  the recursion already carries a substitution, so carrying a number beside it costs nothing,
  and the library stays a value. A `defstruct` (`:paip::Proof`) carries the solutions and the
  counter back together, and holds a `Vector` of `PersistentMap` without complaint.
- **The database is a value, not a service.** C-014 puts mutable state on services, but nothing
  here mutates, and a message costs about 224 µs against a function call's two (F-051) — a
  Prolog asks its database thousands of times. A read-only database is a value.
- **Backtracking is eager.** `prove` answers a `Vector` of every solution rather than a lazy
  stream: the databases are small, and a wat stream does not remember what it forced (F-053), so
  laziness would buy nothing back.
- **Cyclic mutual recursion is accepted.** `prove-clauses` → `prove-all` → `prove-rest` →
  `prove-all` genuinely cycles, unlike chapter 11's downward-only calls, and the checker
  resolves it.
- **What could not be written:** PAIP's membership clauses, whose heads carry a list with a
  variable tail (F-059). They are absent from the database and from the oracle, and that absence
  is the finding, not a gap in the port.
- **Class:** CLEAN.

## Project Euler

### F-060: a bigint has no `to-string`, and its digits come only from the EDN writer, which appends `N`

- **Where:** Project Euler's digit problems (`euler/p16-p20-p25-digits.wat`) — the sum of the
  digits of 2^1000, the sum of the digits of 100!, and the first Fibonacci term with 1000
  digits. All three need a big integer taken apart digit by digit.
- **What happened** (2026-09-15, wat-rs `a3218644d`):
  - `probes/euler/bigint-to-string.wat` is refused at startup, verbatim:
    ```
    1 unresolved reference … :wat::bigint::to-string
    "call head — not a builtin, not a registered function"
    ```
    **Corrected 2026-09-16** (`probes/scalar/to-string-coverage.wat`, wat-rs `a3218644d`): the
    original wording here said "every other scalar has one". It does not. Registered
    `to-string` verbs are exactly **four** — `:wat::i64::`, `:wat::f64::`, `:wat::keyword::`,
    `:wat::uuid::` (`grep -r '::to-string' wat-rs/src wat-rs/wat`). The two **arbitrary-precision
    numeric** types are precisely the two that lack one: `:wat::bigint::` (5 verbs) and
    `:wat::rational::` (**7** verbs — `+ - * /`, `numerator`, `denominator`, `to-f64`; the "4
    verbs" first written here was wrong, see C-093). That is a sharper statement than the
    original and a worse one — the types whose whole reason to exist is holding a number no
    other type can hold are the two with no way to show it.
  - The whole registered bigint surface is six verbs (`src/intrinsic/bigint.rs`):
    `+`, `-`, `*`, `/`, `to-f64`, `to-rational`. There is no comparison (F-047) and no modulo.
  - `:wat::bigint::to-f64` reaches a String only by losing the number:
    `probes/euler/bigint-surface.wat` renders 2^1000 through f64 as 17 significant digits
    followed by 285 zeroes.
  - `:wat::edn::write` does answer the digits — 2^1000 comes back in full — but as **303**
    characters whose last is `N`, so `length` is digits + 1 and a caller must strip the suffix.
    **Corrected 2026-09-16:** the original said the digits come *only* from the EDN writer. They
    do not. `:wat::core::str` and `:wat::core::show` both answer the same string — measured,
    `(:wat::core::str (bigint 2^64))` is `"18446744073709551616N"`, full digits, no scientific
    notation — and a rational likewise renders `"3/1"` through all three. The `N` suffix and the
    strip-it workaround are unchanged, so the finding's substance stands; the route is simply
    three doors wide rather than one, and `str` is the door a user would actually try first.
- **The working route, measured** (`probes/euler/bigint-digits-route.wat`, every line matching
  Clojure): trim the `N`, and the digit count of 2^1000 is 302 and of 100! is 158; the digits sum
  with `:wat::string::to-i64` over one-character substrings to 1366 and 648; and the digit
  *count* stands in for the comparison F-047 says is refused, giving Fibonacci indices 12 and
  4782.
- **So:** big integers are usable, but the way in is undiscoverable. A user looks for
  `:wat::bigint::to-string` by analogy with every other scalar, doesn't find it, finds `to-f64`,
  and silently loses their number — `to-f64` is the trap, because it succeeds. The route that
  works goes through the EDN writer, which is not where anyone looks for a number's digits, and
  which appends a suffix that makes a naive `length` or `subs` off by one.
- **Class:** GAP. Extend: `:wat::bigint::to-string`, and a comparison (F-047). Clean: until
  then, say where a bigint's digits come from and that the writer appends `N`.
- **Repro:** the three probes.

### C-035: names scores ports, and pays for every missing text operation on the way

- **Where:** `euler/p22-names-scores.wat` — 2000 names sorted, each scored by its letters and its
  position — checked against our own Clojure (`oracle/euler/p22-names-scores.clj`, 9 answers).
  The names are ours, generated deterministically; Project Euler's `names.txt` is not
  redistributable.
- **What happened** (2026-09-15, wat-rs `a3218644d`): all 9 answers match, in 1.17 s. The
  problem was chosen because it is made of the two things wat is worst at, and both showed
  without blocking it.
- **Parsing, without a regex that reports what it matched (F-061).** The file is
  `"NAME","NAME",…`. `:wat::regex::matches?` answers a bool and `:wat::regex::find` does not
  exist, so the names come out by `trim`, `split` on `","`, and a `subs` per piece to strip its
  quotes. Longhand, and correct.
- **Scoring, without character access (F-062).** Every letter is a one-character `subs`, and its
  value needs a second lookup. Both roads measured over 26000 letters, the size p22 walks
  (`probes/euler/letter-lookup-cost.wat`): scanning `"ABCDEFGHIJKLMNOPQRSTUVWXYZ"` with `subs`
  costs **2751 ms**, a `PersistentMap` from letter to value **395 ms** — **7.0×**. The solution
  takes the map road, which is why it finishes in 1.17 s rather than about ten seconds.
- **Worth recording about the 7×:** reasoning predicted 26×, from "up to 26 `subs` calls per
  letter". It is 7×, because the average letter sits about a third of the way into the alphabet
  and the map road still pays one `subs` to read the character at all. The second time this
  session that a measurement has corrected a confident ratio — the first was F-062's own
  index-0 control.
- **Sorting agrees with Clojure exactly** (`probes/euler/string-sort-order.wat`): `"Z" < "a"`,
  `"MARY" < "MARYANN"`, `"B" < "AA"` false, and an eight-name sort in the identical order with
  repeats surviving. Checked rather than assumed, because every score is multiplied by its
  position: a collation difference would have changed the total silently and given no hint
  where.
- **Class:** CLEAN.

### F-061: regex is a single predicate, so a pattern can be written and what it matched can never be read

- **Where:** looking for the text-handling surface, after Project Euler's digit problems. Nothing
  in this ledger had mentioned regex before, in sixty findings.
- **What there is** (2026-09-15, wat-rs `a3218644d`): one verb.
  `(:wat::regex::matches? pattern haystack)` → `bool`, unanchored, pattern first. It works, and
  it takes real patterns — `probes/euler/regex-surface.wat` matches `^hello`, `[0-9]+`,
  `^[A-Z][a-z]+$`, `\d{3}-\d{4}` and `(foo|bar)baz`, and correctly declines `^wor` against
  `hello world`.
- **What there isn't:** `probes/euler/regex-find.wat` and `probes/euler/regex-replace.wat` are
  both refused at startup, verbatim:
  ```
  1 unresolved reference … :wat::regex::find
  "call head — not a builtin, not a registered function"
  ```
  and the same for `:wat::regex::replace`. The whole `:wat::regex::` namespace is `matches?`.
- **So:** an alternation group compiles, matches, and its capture is unreachable. There is no
  way to get the matched text, its position, a capture group, a replacement, or a split on a
  pattern — the operations a text program is actually built from. wat-rs depends on the entire
  `regex` crate (`Cargo.toml:111`, `regex = "1"`), so this is a surface that was never exposed
  rather than an engine that isn't there. The user guide is honest about it: `USER-GUIDE.md:3684`
  lists the one entry and claims nothing more.
- **Class:** GAP. Extend: `find`, `captures`, `replace` and `split` on a pattern — the crate is
  already a dependency and already compiled in.
- **Repro:** the three probes.

### F-062: a String cannot be taken apart, and the one substitute costs 16.7 µs a character

- **Where:** every suite that has touched text — mal's reader, Advent of Code day02, Project
  Euler's digit problems — and the Clojure Koans, which recorded the pieces one row at a time
  without ever measuring them.
- **What is missing.** The registered `:wat::string::` surface is twenty verbs, and none of them
  is `index-of`, `last-index-of`, `replace`, `split-lines`, `blank?` or `chars`. There is no
  `:wat::char::` namespace at all. Two further refusals close the obvious workarounds:
  - `:wat::core::reverse` takes a Vector, PersistentVector or List and refuses a String;
  - `:wat::string::split` with `""` fails — at **runtime**, not startup
    (`probes/euler/string-split-empty.wat`), verbatim:
    ```
    malformed :wat::string::split form: separator must not be empty
    ```
  So a String cannot be turned into its characters, and cannot be reversed. The two gaps compound
  into one impossible one-liner, which is what `koans/idiom/02-strings.wat` row 11 records.
- **The one road left** is a one-character `subs`, and it is expensive
  (`probes/euler/char-at-scaling.wat`, `probes/euler/char-at-exponent.wat`):

  | scan | wall |
  |---|---|
  | 10000 characters | 112 ms |
  | 20000 characters | 244 ms |
  | 40000 characters | 588 ms |
  | 80000 characters | 1661 ms |

  About **16.7 µs per character**, against roughly 2 µs for a plain function call (F-051's
  baseline) — eight times the cost of a call, to look at one character.
- **It is NOT the char-indexing that costs.** `subs` is documented as char-indexed
  (`src/intrinsic/string.rs:542`, "the CHAR-indexed substring `[start, end)`"), which would make
  a full scan quadratic if the seek dominated. The control says otherwise: **80000 `subs` calls
  all at index 0 cost 1340 ms**, against 1661 ms for the same calls walking the string. The seek
  is under 20% of it; the flat per-call overhead is the rest. Scanning is mildly superlinear,
  not quadratic — and the expensive part is calling `subs` at all.
- **So:** text work in wat is not asymptotically broken, it is uniformly expensive and
  uniformly verbose. Four independent users already pay it: `mal/lib/reader.wat` builds a whole
  Lisp reader on nine `char-at` call sites, `aoc/day02` reads a 100×100 grid one character at a
  time, `euler/p16-p20-p25-digits.wat` walks a 302-digit number, and wat-rs's **own `format`
  macro** walks its template with `length` + `subs i (i+1)` at expand time
  (`src/intrinsic/string.rs:550`).
- **Class:** GAP. Extend: `chars` (or an iterator), `index-of`, `replace`, `split-lines`,
  `blank?`, and `reverse` on a String; let `split` take `""`. Improve: a cheaper single-character
  read, since that is the primitive everything else is built from. Clean: `CLOJURE-ROSETTA.md`
  mentions none of `index-of`, `replace`, `split-lines` or `blank?` in its 388 lines, so a
  Clojure user looking for them finds neither the operation nor a route to it.
- **Repro:** the five probes.

## Errors and recovery

### F-063: catching a failure spawns a thread, so recovery costs 1.3 ms — and the only general catch is a test verb

- **Where:** looking for wat's error-recovery story after Project Euler. Sixty-two findings in,
  no suite had measured what surviving a failure costs, though `books/little-typer/lib/pie.wat`
  leans on it for all 108 of Pie's refusals and two probes use it the same way.
- **The whole vocabulary** is small: `:wat::core::Result` (a two-variant Pure enum,
  `Ok [value <- T]` / `Err [error <- E]`), `Result/try`, `Result/expect`,
  `:wat::kernel::assertion-failed!`, and `:wat::test::run-thread` →
  `:wat::kernel::RunResult.Passed` / `.Failed [failure <- :wat::kernel::Failure]`. The lowercase
  `:wat::core::try` is retired in favour of `Result/try` (`src/remedy/retirement.rs:120`).
- **`Result/try` is not a catch.** Its own contract (`src/intrinsic/result.rs`) says:
  `@ret :T the wrapped value, if res is Ok; otherwise short-circuits the enclosing function with
  (Err e)`. It is the `?` operator — it propagates an `Err` outward. It cannot even be written in
  a function that doesn't return a `Result`; `probes/err/try-catches-assertion.wat` is refused at
  startup, verbatim:
  ```
  malformed :wat::core::Result/try form: enclosing function returns :();
  `:wat::core::Result/try` requires the enclosing function to return (:wat::core::Result :- [T E])
  ```
  That refusal is a good diagnostic — it names the rule and the actual return type — but it
  settles that `Result/try` never recovers from a fault.
- **So the only way to survive a fault is `:wat::test::run-thread`,** a macro from the **test**
  namespace (`wat/test.wat:364`), which expands to `:wat::test::spawn-thread-program`: it spawns
  a thread, runs the body in it, and faces the death as a value through the parent's `recv`.
  Catching means spawning.
- **What that costs** (`probes/err/catch-cost.wat`, 2000 iterations each, stdout and stderr
  separated so the timings stand alone):

  | | per call |
  |---|---|
  | a plain function call | 8 µs |
  | `run-thread` around a call that succeeds | 1257 µs |
  | `run-thread` around a call that dies | 1405 µs |

  About **157× a plain call**, and roughly six times the 224 µs a service message costs (F-051).
  Catching nothing at all still costs 1.26 ms, because the thread is spawned either way.
- **What a caught failure carries:** `:wat::kernel::Failure` is a record of
  `[error, frames, actual, expected]` (`wat/kernel/diagnostics.wat:107`), with
  `Failure/message` and `Failure/location` derived from `error`, and `frames` a real captured
  stack (file, line, symbol). There is an `upstream-chain` field on `AssertionFailure`, but
  `src/assertion.rs:235` says it is `Some` only when called from `result::expect` on an `Err`
  arm carrying a `Vec<*DiedError>` — the spawn-cascade path. An ordinary `assertion-failed!`
  carries `nil`, as observed. So a caught failure keeps a stack and no cause chain.
- **So:** a program that wants to recover from anything — a bad parse, a missing key, an
  out-of-range index — pays a millisecond and a thread per attempt, through a verb named for
  testing. A retry loop, a parser that backtracks over failures, or a server that survives a bad
  request are all priced out.
- **Class:** GAP. Extend: a catch that doesn't spawn — recovery belongs outside `:wat::test::`.
  Improve: if spawning is the design, make the thread cheap. Clean: nothing says that
  `Result/try` propagates rather than catches, or that `run-thread` is the catch.
- **Repro:** `probes/err/catch-cost.wat`, `probes/err/try-catches-what.wat`,
  `probes/err/try-catches-assertion.wat`.

### F-064: a failure inside a lazy stream waits for the force, then happens again on every walk

- **Where:** the natural place errors and laziness meet — a stream that computes something that
  can fail.
- **What happened** (2026-09-15, wat-rs `a3218644d`), `probes/err/error-in-stream.wat`: a stream
  whose second element raises prints `built the stream without dying` first, so **building the
  stream doesn't raise**; the failure waits for the force. Then the same stream, walked twice,
  fails **both** times.
- **So:** two distinct problems. The failure surfaces where the stream is forced rather than
  where it was built, which moves an error away from its cause — the hardest kind to locate, and
  the reason F-006/F-008's "located in wat-rs's own source" complaints matter here too. And
  because a forced stream doesn't remember what it forced (F-053), a failure isn't remembered
  either: a program that catches the error, recovers, and walks the stream again gets the same
  failure a second time, having already handled it. Memoisation would fix both halves.
- **Class:** GAP. This is F-053's consequence for errors. Extend: a stream that remembers what it
  forced, failures included.
- **Repro:** `probes/err/error-in-stream.wat`.

## The rete

### C-036: wat's rete is correct — chaining, negation over derived facts, existence and accumulation all agree with clara

- **Where:** `rete/r01-chaining.wat`, a small supply chain, against the same rules written on
  clara-rules (`oracle/rete/r01-chaining.clj`, run by `tools/rete-oracle.sh`). The rules are
  ours, written twice; nobody's code is ported. 8 results, all matching, on the first run.
- **What it exercises,** each building on the last:
  - **a join** — an `Order` and a `Stock` line for the same part, with a guard
    `(:wat::rete::where (:wat::rete::i64::> ?qty 0))`. Two of three orders ship;
    the out-of-stock one doesn't.
  - **forward chaining** — the derived `Shippable` feeds the rule deriving `Invoice`. This fires
    only if the engine puts what it derived back into the network, so it is a direct test that
    `fire-rules` computes a closure rather than one pass. It does: `fire-rules$oracle`
    "delegates to fire-stratified … within each stratum fire-stratified still uses
    fire-fixpoint" (`wat/rete/oracle/fire.wat:356`).
  - **negation over a derived fact** — `(:wat::rete::not (:sc::Hold (?id <- :id)))` on a
    `Shippable`. The held order is shippable and not invoiced; stratification is what makes that
    come out right.
  - **existence** — `(:wat::rete::exists (:sc::Supplier (?part <- :part)))`. Two suppliers for
    one part derive **one** `Sourced`, not two: `exists` is not a join.
  - **accumulation over a derived fact** — `(?n <- (:wat::rete::acc::count) :from (:sc::Shippable))`
    counts 2.
- **The surface used:** `defrecord` facts, `(:wat::rete::defrule :ns::name :when […] :then […])`,
  `(:wat::rete::defquery :ns::name :params [] :when […])`,
  `(:wat::rete::collect-rules :ns)` — which reflects the symbol table for a namespace's rules
  (`src/rete/collect.rs`) — `compile-all`, `insert-all`, `fire-rules`, `query`. A query answers a
  `(PersistentVector :- [PersistentMap])` whose keys are the binding names **with** the question
  mark, so the whole fact bound as `(?f <- :sc::Shippable)` is read back at `"?f"`.
- **Guards are type-namespaced:** `:wat::rete::i64::{< <= = > >= not= mod quot rem}`, and the
  same for `f64`, `string`, `keyword`, `bool`, plus `:wat::rete::core::{and or not if let match
  cond}` and `enum::=`. rete has its own `cond`, its own `if`, its own everything — a parallel
  namespace, deliberately (`BRIEF-rete-cond-is-its-own-macro.md`).
- **Nine accumulators exist:** `count`, `sum`, `min`, `max`, `mean`, `distinct`, `all`,
  `group-by`, `gather-vals`.
- **Class:** CLEAN. The engine works. What is missing is any way to find out that it exists —
  F-065.

### F-065: the rete has 134 verbs, 4154 lines of wat, and no user-facing documentation at all

- **Where:** looking for the next untouched part of wat, after bigints, text and errors.
- **What happened** (2026-09-15, wat-rs `a3218644d`). A word-boundary search for `\brete\b`,
  `:wat::rete::` or `defrule` across the user-facing documentation:

  | page | hits |
  |---|---|
  | `USER-GUIDE.md` | 0 |
  | `WAT-CHEATSHEET.md` | 0 |
  | `CLOJURE-ROSETTA.md` | 0 |
  | `docs/README.md` | 0 |
  | `SERVICE-PROGRAMS.md` | 0 |
  | `CONVENTIONS.md` | 1 — and it is a Rust module-path listing (`rete/` beside `kernel/`, `value/`), not about the engine |

  Against a subsystem of **134 `:wat::rete::` verbs** and **4154 lines** of wat source
  (`wat/rete.wat`, `wat/rete/*.wat`, `wat/rete/oracle/*.wat`), with a native Rust implementation
  beside a pure-wat reference for every fire and insert verb.
- **A caution about the measurement.** Counting `rete` case-insensitively gives 3 hits in
  USER-GUIDE and 4 in the cheatsheet — every one of them the word **conc-rete**. The same trap
  swallowed an earlier count of this ledger's own references (18 hits, all "concrete" or
  "interp-rete-r"). Word boundaries are the only honest way to count this name.
- **So:** a user cannot discover that wat has a production rule engine, cannot learn that
  `defrule` exists, and has nowhere to read what `:when`/`:then` accept, what
  `(?v <- :field)` means, which of the five `fire-*` verbs to call, or that guards live in
  type-namespaced operators like `:wat::rete::i64::>`. Everything in C-036 above was recovered by
  reading `wat/rete/syntax.wat`, `src/rete/collect.rs`, and fixtures under `wat-rs/tests/rete/`.
  This is the largest documented-nowhere surface the project has found: `CLOJURE-ROSETTA.md`
  never mentions it, though clara-rules is exactly the Clojure-world counterpart a reader would
  arrive with.
- **Class:** GAP. Clean: a `RETE.md` — or a cheatsheet section — covering `defrule`, `defquery`,
  the condition forms (`where`, `not`, `exists`, `acc::*`, `:from`), the fire verbs and how they
  differ, `collect-rules`, and the shape a query answers. PROVIDE's P-010 already notes wat
  "already ships a Rete, which reacts forward to facts"; that is currently truer than any
  documentation admits.
- **Repro:** the grep table above, and `rete/r01-chaining.wat`, which had to be written from
  source and fixtures.

### F-066: wat's closure is a set of facts where clara's memory is a bag of derivations

- **Where:** `rete/r02-retraction.wat`, asking what happens to a derived fact when its support
  goes away — the question `rete/r01-chaining.wat` deliberately left out.
- **Seven of eight scenarios agree exactly** (`probes/rete/retraction-scenarios.wat`, which
  prints both engines side by side): a derived fact goes when its support is retracted; it goes
  **transitively**, taking the fact derived from it; re-inserting restores the whole closure;
  retracting one of two supports leaves the fact standing; retracting both clears it; and
  retracting an unrelated fact changes nothing. wat reaches those answers by recomputing —
  "retract-then-fire recomputes the full closure from the reduced input, so consequences vanish
  transitively" (`wat/rete/oracle/fire.wat:360`) — while clara tracks dependencies. Same
  answers, different roads.
- **One scenario diverges.** Two `Stock` lines match one `Order`, so the rule fires twice and
  both firings derive the *identical* `Shippable`:

  | | wat | clara |
  |---|---|---|
  | identical derived facts kept | **1** | **2** |
  | `acc::count` over them | **1** | **2** |
  | derived facts when the two firings carry *different* payloads | 2 | 2 |

- **So it is a collapse, not a missing join.** Both engines fire the rule once per matching
  support — the distinct-payload row proves it (`probes/rete/derived-multiplicity.wat`). They
  differ in what they keep afterwards: wat's closure is a **set of facts**, so two equal
  derivations become one, and clara's working memory is a **bag of derivations** that happen to
  be equal. The difference then propagates consistently rather than as a second quirk: each
  engine's own accumulator reports what that engine holds, 1 and 2 respectively
  (`probes/rete/derived-multiplicity-tally.wat`).
- **Which matters to a user** writing a rule that counts, sums or averages over derived facts.
  In wat, "how many ways did this conclusion get derived?" cannot be asked — the answer is
  always one. In clara it is the default, and asking for distinct values takes an explicit
  `distinct`. Neither is wrong; they are different questions, and nothing tells a reader which
  one they are asking, because nothing documents the rete at all (F-065).
- **Class:** GAP (semantics, undocumented). Clean: say which it is — a sentence in the rete
  documentation F-065 asks for. Extend, if support counting is wanted: a way to see
  multiplicity, or an accumulator that counts derivations rather than facts.
- **Repro:** the three probes; `rete/r02-retraction.wat` holds wat's answers, with clara's
  recorded beside them rather than smoothed away.

### F-067: a bare accumulator asserts its result over the empty set, so `fire-fixpoint` keeps a stale answer beside the right one

- **Where:** running one session through both of wat's own rete implementations. Every fire and
  insert verb ships two mouths — `fire-rules` reaches `fire-rules$native` (the Rust kernel a
  program actually runs), and `fire-rules$oracle` is pure wat, which `wat/rete/oracle/fire.wat:356`
  calls **"the SPEC / differential oracle"**. They are meant to agree, so wat can check itself
  with no other language involved.
- **They do not agree** (`probes/rete/native-vs-oracle.wat`). Same session, same rules — a
  guarded join, a derived fact feeding another rule, a negation, an existence and an
  accumulator:
  ```
  native  shippable/invoice/sourced/tally: 2/1/1/1
  oracle  shippable/invoice/sourced/tally: 2/1/1/2
  native  derived facts: 5      oracle derived facts: 5
  ```
  The total derived-fact count agrees; only what the accumulator contributes differs.
- **The values say why** (`probes/rete/accumulator-count-leak.wat`), on a rule that counts a
  derived fact:

  | fired with | tally values |
  |---|---|
  | `fire-rules` (native) | `2` |
  | `fire-rules$oracle` (the SPEC) | `0\|2` |
  | `fire-once` (native) | `0` |
  | `fire-once$oracle` | *no rows at all* |
  | `fire-fixpoint` | `0\|2` |
  | `fire-stratified` | `0\|2` |

  The accumulator runs on the **first** pass, before anything has been derived, and asserts
  `n = 0`; the next pass asserts `n = 2`; and because a closure is a set of facts (F-066) the two
  distinct values both survive. `fire-once`'s lone `0` shows the first pass genuinely sees an
  empty set. Native suppresses the stale row; the SPEC keeps it — and so do **`fire-fixpoint`
  and `fire-stratified`, both public, user-callable verbs**
  (`probes/rete/fire-verbs-compared.wat`). That `fire-stratified` leaks locates the mechanism:
  `fire-rules$oracle` delegates to it, and "within each stratum fire-stratified still uses
  fire-fixpoint" (`fire.wat:357`), so the stale row comes from the fixpoint inside a stratum.
- **A second divergence in the same family, found by chasing an empty output line**
  (`probes/rete/fire-once-oracle-empty.wat`). Counting rows rather than joining values:
  ```
  fire-once        (native)  shippable rows: 2  tally rows: 1  derived facts: 3
  fire-once$oracle           shippable rows: 0  tally rows: 0  derived facts: 3
  fire-rules       (native)  shippable rows: 2  tally rows: 1  derived facts: 3
  fire-rules$oracle          shippable rows: 2  tally rows: 2  derived facts: 3
  ```
  All four derive the same **3** facts into production memory. But `fire-once$oracle` answers
  **no query rows at all**, where `fire-once` native answers 2 and 1 from the same 3 derived
  facts. So that mouth populates production memory without populating query memory: the
  conclusions are there and nothing can read them.
- **Insertion is clean, which bounds this.** `insert-all` and `insert-all$oracle` both leave 7
  facts, and all four insert×fire crossings give the same conclusions
  (`probes/rete/insert-native-vs-oracle.wat`). The divergence is confined to the fire path; facts
  do not enter the network differently depending on which mouth inserted them.
- **Only the bare folds leak** (`probes/rete/accumulator-empty-pass.wat`):

  | fold | native | SPEC |
  |---|---|---|
  | `acc::count` | `2` | `0\|2` |
  | `acc::sum` | `15` | `0\|15` |
  | `acc::max` | `10` | `10` |
  | `acc::min` | `5` | `5` |

  which is exactly what the dispatch predicts: "bare folds (count/sum/distinct/all/group-by)
  assoc their result into the token's bindings; Option folds (min/max/mean) match inline
  (None → drop)" (`wat/rete/oracle/accum-pass.wat:16`). An empty set gives `count` 0 and `sum` 0
  — real values, asserted as facts — while `min`/`max`/`mean` give `None` and are dropped.
- **So:** a rule that counts or sums derived facts gets a **wrong extra answer** from the engine
  wat-rs calls its specification, and from `fire-fixpoint` — which is public, user-callable, and
  undocumented like the rest of the rete (F-065). A user who reaches for `fire-fixpoint` by name,
  reasonably enough for a forward-chaining engine, silently gets a superset of the truth. Nothing
  in wat-rs's source acknowledges any native/oracle divergence.
- **Class:** GAP (a defect in the reference implementation, or in `fire-fixpoint` and
  `fire-stratified`, depending which is meant to be right). Fix: don't assert a bare fold's
  result over an empty element set during the fixpoint, or re-derive the accumulator's fact
  after the closure settles as native does; and populate query memory in `fire-once$oracle`, or
  say that one pass through that mouth is not meant to be queried. Correct: if either
  divergence is intended in the SPEC, say so — a differential oracle that disagrees with
  production is worse than no oracle.
- **A note on how this was nearly mis-filed.** My first version of the fold probe wrote
  `(:wat::rete::acc::sum :qty)` and died with `acc: var unbound` at `wat/rete/acc.wat:83` — deep
  in wat's own source, which reads exactly like a defect. It was mine: an accumulator's operand
  is a `?`-variable bound in the `:from` condition, `(acc::sum ?q) :from (:R (?q <- :qty))`, and
  nothing documents that either (F-065).
- **Repro:** the seven probes under `probes/rete/`.

## SQLite

### C-037: wat's sqlite surface matches the reference client, and its capability split is real

- **Where:** `sqlite/s01-crud.wat` against the sqlite3 CLI on the same schema and queries
  (`oracle/sqlite/s01-crud.sql`, run by `tools/sqlite-oracle.sh`). 17 results, all matching, on
  the first run. The oracle is sqlite3 **itself** — the engine wat binds — so this compares
  wat's surface against the reference client rather than one database against another.
- **What it covers:** parameter binding (`Param.Str`, bound rather than interpolated), NULL
  round-tripping through `Cell.Nil`, `count(*)` and `count(col)` over a nullable column, a
  GROUP BY where NULL is its own group, an update, a delete, ordering by a non-key column, and a
  query matching nothing — zero rows being an answer, not an error.
- **The read-only half is capability-honest, and the checker enforces it at startup.**
  `sqlite.wat`'s header claims "no execute/execute-ddl/pragma/begin/commit is registered under
  ReadConnection's type path, so the checker rejects any attempt to write through one". It does
  (`probes/sqlite/readonly-refuses-write.wat`), verbatim:
  ```
  :wat::sqlite::execute: parameter #1 expects :wat::sqlite::Connection;
  got :rust::sqlite::ReadConnection
  ```
  with the control passing — a read through the same connection returns its row
  (`probes/sqlite/readonly-reads.wat`). This is the first documented claim this session that
  survived checking intact, and it is a real guarantee: not "the database will refuse", but "the
  program will not compile".
- **Errors are values, and that is the thing the rest of the language lacks.**
  `probes/sqlite/errors-are-values.wat` faces four failures in a row — a good insert (`Ok 1`), a
  duplicate primary key (`Err Constraint`), a syntax error (`Err Fatal`), an unopenable path
  (`Err Fatal`) — and runs straight through all of them to print its verdict. No
  `:wat::test::run-thread`, no spawned thread, no death. F-063 measured the alternative: wat's
  only general catch costs about 1.3 ms and lives in the **test** namespace. A subsystem that
  hands failures back as ordinary `Result` values needs none of it, and a match arm costs
  nothing. This is the pattern F-063 asks for, already built, one layer down.
- **Rows are positional.** `select` answers
  `(Result :- [(Vector :- [(Vector :- [Cell])]) Error])` — rows of cells, with no column names
  anywhere, so every read is by index. SQL's results are named; wat's are not.
- **Class:** CLEAN.

### F-068: the sqlite surface has `begin` and `commit` but no `rollback`, on a surface closed to additions

- **Where:** `probes/sqlite/transaction-abort.wat`, asking how a wat program abandons a
  transaction.
- **What happened** (2026-09-15, wat-rs `a3218644d`): a word-boundary search for `rollback`
  across `:wat::sqlite::` and `:rust::sqlite::` finds **nothing**, while `begin` and `commit`
  are both present with identical shapes. And `sqlite.wat`'s header closes the surface against
  repair: "the named surface (intueri-cast — **do NOT rename or add verbs**) … open /
  open-readonly / pragma / begin / commit / execute / execute-ddl / select".
- **The workaround works, which is what keeps this small.** `execute` takes arbitrary SQL, so
  `(execute conn "ROLLBACK" [])` runs, answers `Ok 1`, and genuinely undoes the write — the row
  count goes 1 → 2 → 1 across begin, insert, rollback. So a transaction *can* be abandoned; the
  verb for it is just missing from the set of verbs.
- **So:** the asymmetry is the defect, not an inability. A reader of the surface sees `begin` and
  `commit`, reasonably concludes those are the transaction verbs, and has no way to learn that
  the third one is spelled as a raw string through `execute`. Nothing documents it.
- **Worth recording about the method:** the empty grep alone would have supported a much more
  serious finding — "a transaction cannot be abandoned" — and I had that half-drafted. The probe
  is what turned it into a missing convenience verb. The absence of a name is not the absence of
  a capability.
- **Class:** GAP. Extend: a `rollback` verb, which the ratification note would have to permit.
  Clean: failing that, say in the surface's own documentation that rollback goes through
  `execute`.
- **Repro:** `probes/sqlite/transaction-abort.wat`.

## The Store contract

### C-038: one function drives two backends, and they agree — from outside wat-rs's own harness

- **Where:** `store/q01-two-backends.wat`. wat ships a backend-agnostic storage contract,
  `:wat::query::Store` — a DynamoDB-shaped `(pk, sk, data)` narrow waist with named GSIs — and
  **two** services that satisfy it: `:wat::query::mem-store` and `:wat::query::sqlite-store`.
- **No external oracle is needed, because wat ships its own.** `wat/query/mem.wat` says the
  in-memory store is "dual-purpose … a genuine in-memory backend AND the oracle sqlite will be
  differential-tested against — correct-by-construction, not a canned stub". So the two backends
  check each other.
- **What happened** (2026-09-15, wat-rs `a3218644d`): ensure-schema, a five-row put, three
  keyset-paginated scan pages and a GSI scan, driven through one `:wat::query::Store`-typed
  function and run against both peers. **All five results identical**, first run.
- **The narrow claim, stated carefully.** wat-rs already has
  `tests/rete/probe_arc278_sqlite_store_differential.{wat,rs}`, which asserts the same agreement
  inside their harness. This does not re-prove that. What it adds is that the agreement holds for
  an **ordinary program** — no `deftest`, no fixture loader, no co-located `.rs` — which is the
  consumer's position and the one this repository exists to occupy.
- **A dialed peer really is the surface.** `(:st::run-ops [store <- :wat::query::Store])` accepts
  a connected `mem-store` peer and a connected `sqlite-store` peer, and one body serves both.
  This is *not* F-029: that finding is about a **generic** fn over a **parametric** surface
  refusing a concrete implementor. Here the surface is non-parametric and the values are peers,
  so it works — worth recording as the case that does.
- **Where the two are meant to differ, they are not compared:** `mem-store`'s `ensure-schema` is
  a deliberate no-op ("no physical schema to establish") while `sqlite-store`'s is where
  `CREATE TABLE` happens.
- **Class:** CLEAN.

### F-069: a Store consumer writes more outcome arms than logic — 56 of 182 lines, in two independent attempts

- **Where:** driving `:wat::query::Store` from an ordinary program (`store/q01-two-backends.wat`)
  against wat-rs's own consumer fixture
  (`wat-rs/tests/rete/probe_arc278_smem_roundtrip.wat`).
- **What happened** (2026-09-15, wat-rs `a3218644d`). Both files do the same five operations.
  Both are **exactly 182 lines**:

  | | wat-rs's fixture | this repository's case |
  |---|---|---|
  | lines | 182 | 182 |
  | longest line | 529 chars | 167 chars |
  | `ConnectOutcome` arms | 32 | 8 |
  | `RecvOutcome` arms | 24 | 20 |
  | response-variant arms | — | 26 |
  | lines that are a match arm | — | **56 of 182** |

  Two authors, independently, one shaping for a test harness and one for plainness, land on the
  same length — and about a third of it is outcome ceremony rather than the put, the scan and
  the page.
- **Why it is forced, not stylistic.** Three things compound:
  - **every call answers a `RecvOutcome`**, so `Message`/`Lost`/`Stopped`/`Closed` must be said
    at each of the four ops, whatever the op meant;
  - **every op then answers its own response enum**, `Success` plus `Constraint`/`Transient`/
    `Fatal`/`RequestTooLarge`/`RequestMalformed` — correct, exhaustive, and five arms of which
    four are usually "this cannot happen here";
  - **the dial cannot be factored out.** wat-rs's fixture states the rule in its own words:
    "start+connect stay inlined in each deftest (**spawn scope law**: a helper that returns the
    peer leaves the service thread dead)". That is F-052 — a function cannot answer a connected
    peer — confirmed independently in wat-rs's source, and it is why their `connect` is a
    529-character line rather than a named helper.
- **So:** the contract is well designed and the exhaustiveness is right; what is missing is any
  way to *say* "and every other outcome is a failure, here is the message" once. Every consumer
  of every service pays this, and it is why a 529-character line exists in wat-rs's own tests.
- **Class:** GAP. Improve: a way to collapse the uninteresting arms — an `expect`-style helper
  over `RecvOutcome`, or letting a response enum's error variants be handled as a group.
  Extend: whatever would let a dial be factored into a function (F-052's underlying rule).
- **Repro:** the two files, and the counts above.

## wat's own documentation, executed

### F-070: 134 of wat's 485 runnable documented examples do not pass, and the runner's own mask hid it

- **Where:** `probes/doctest/*.wat`. wat reflects every `@example` in wat-rs's source through
  `:wat::intrinsic::examples` into typed records, and `:wat::doctest::verify-examples` runs them.
  That makes the documentation executable — 626 examples, 485 of them runnable
  (`@example`), 141 marked `@example-norun`.
- **What the builder already knows, and this does not re-report.** `wat/doctest.wat`'s
  comparison is unguarded, so one non-comparable pair raises, escapes the `foldl`, and masks
  every other example. It is recorded in
  `docs/arc/2026/06/296-diagnostics-fully-edn/NOTE-the-doctest-runner-masks-every-failure-behind-one-raise.md`,
  with three attempted fixes refuted, and the gate that would catch it
  (`probe_arc255_ivb2b_verify_examples`) is `#[ignore]`d. Its `#[ignore]` text records "FIVE
  failures, ONE cause".
- **Unmasked, the count is 134** (`probes/doctest/unmask-failures.wat`). Running the same
  examples through the same `:wat::eval-ast!`, but with every per-example verdict wrapped in
  `:wat::test::run-thread` so a raise becomes a value and the walk continues:

  | cause | count | distinct fqdns |
  |---|---|---|
  | stale **constructor** spelling — bare `(:wat::core::Vector 1 2)`, needs `:- [T]` | 44 | 42 |
  | stale **variant** spelling — `Enum::Variant` arms, bare `:None` (the dot flip) | 23 | 18 |
  | angle-bracket `keyword-node` — **the builder's known five**, reproduced exactly | 5 | 2 |
  | eval-context limits — `defrecord`/`defstruct` inside `eval-ast!` | 19 | 19 |
  | raised past the guards — the masking instances | 6 | 6 |
  | genuine mismatch — ran, answered something else | 17 | 17 |
  | other | 20 | 20 |
  | **total** | **134** | |

  That the five angle-bracket failures come out exactly as the builder diagnosed them is the
  control: where they had an answer, this agrees with it.
- **Both stale spellings confirmed directly**, not inferred from an error string
  (`probes/doctest/*`):
  ```
  (:wat::core::Vector 1 2)          => Err malformed-form: first argument must be a (Head :- [T …]) type form
  (:wat::core::Vector :i64 1 2)     => Ok [1 2]
  (:wat::core::Vector :- [:i64] 1 2) => Ok [1 2]
  match arm :wat::core::Option::Some => Err malformed-form
  match arm :wat::core::Option.Some  => Ok 7
  ```
  So the documentation is one migration behind the runtime in two places at once.
- **The NOTE's open question has an answer.** It asks whether the runner should guard its own
  comparison, calls that "the only one that fixes the masking rather than the instances", and
  says it "needs a raise-catching mechanism the runner does not currently have". That mechanism
  exists: `:wat::test::run-thread` returns a death as `RunResult.Failed {:failure f}` with a
  readable message. **Load order permits it** — `wat/test.wat` is stdlib file **#34**,
  `wat/doctest.wat` is **#38**. The reason it looks absent is F-063: wat's only general catch
  lives in the `:wat::test::` namespace, which is not where a substrate author writing
  `wat/doctest.wat` would look.
- **And the NOTE's picture of the defect is incomplete.** It marks the two evaluations as safe:
  ```
  (eval-ast! expr)     -> Ok | Err   "becomes a Failure"
  (eval-ast! expected) -> Ok | Err   "becomes a Failure"
  (= got want)         -> UNGUARDED
  ```
  `eval-ast!` **also raises past its own Result** — a first version of this probe guarded only
  the comparison, exactly as option (2) proposes, and still died on `"unreachable"` from
  `<intrinsic-example>`. So a real fix must guard the evaluations too, not only the comparison.
- **Instance 2 is named.** The NOTE says of its second masking instance: "source not identified —
  the mask hides which example produces it. That is the defect describing itself." It is
  `:wat::core::Option/expect`, raising `"unreachable"`. The other maskers are `PersistentMap`
  comparisons (`:wat.core/PersistentMap`, `:wat.rete.core/PersistentMap`) — so `=` refuses
  persistent maps as well as the Option/WatAST/HolonAST cases already found.
- **Class:** GAP. Clean: the examples are the documentation, and 67 of them are written in
  spellings two completed migrations have retired — a codemod, not a judgement call. Fix: guard
  both the evaluations and the comparison in `wat/doctest.wat`, then lift the `#[ignore]`; the
  mechanism is available at that point in the load. The 17 genuine mismatches and 20 others can
  only be triaged once the mask is down.
- **Repro:** `probes/doctest/unmask-failures.wat` (the full run),
  `probes/doctest/guarded-compare.wat` (the guard, demonstrated),
  `probes/doctest/examples-count.wat` (the census).

### F-071: the match-arm refusal tells you to write the spelling it just refused

- **Where:** found while confirming F-070's dot-flip bucket.
- **What happened** (2026-09-15, wat-rs `a3218644d`), verbatim:
  ```
  (:wat::core::match … [:wat::core::Option::Some {:value v} v] …)
    => Err malformed-form:
       ":wat::core::match: variant arm head `:wat::core::Option::Some` is not namespaced;
        write `<enum>::<Variant>`"
  ```
  The remedy says write `<enum>::<Variant>` — which is exactly the `::` form that was just
  refused. The spelling that works is `<enum>.<Variant>`: `[:wat::core::Option.Some {:value v} v]`
  answers `Ok 7`.
- **Its sibling gets it right**, which is how the defect stands out:
  ```
  :None => Err "the bare variant spelling is retired; write `:wat::core::Option.None`"
  ```
  That message names the dot form and is correct.
- **So:** a reader who follows the first message changes nothing and is refused again. This sits
  with F-025 (the non-exhaustive error suggesting `_`) and F-040 (the containment error offering
  only `:wat::enum::Impure`) — diagnostics whose remedy is wrong rather than missing, which is
  worse than silence because it costs a cycle to disprove.
- **Class:** GAP. Correct: the message should say `<enum>.<Variant>`, and ideally name the
  corrected form of the arm it refused, as the bare-variant message does.
- **Repro:** the dot-flip comparison in F-070's evidence.

## The holon algebra (VSA)

### C-039: wat's vector-symbolic algebra obeys its laws — eleven of twelve exactly

- **Where:** `probes/holon/vsa-algebra.wat`. `:wat::holon::` is the largest surface in wat — 94
  verbs — and the layer wat exists for. It needs no external oracle: a vector-symbolic
  architecture has algebraic laws, and the mathematics is the oracle.
- **The vectors are ternary**, 10000-dimensional (measured: `vector-bytes` answers 2504 bytes =
  10000 elements at 2 bits + a 4-byte header), produced by `(encode (leaf "name"))`.
- **What holds, exactly** (cosine 1 or ~0 as the law requires):

  | law | expected | measured |
  |---|---|---|
  | `cos(a,a)` — identity | 1 | **1** |
  | `cos(a,b)` — distinct atoms quasi-orthogonal | ~0 | −0.0007, −0.012 |
  | `cos(bind(a,b), bind(b,a))` — bind commutes | 1 | **1** |
  | `cos(bind(a,b), a)` — binding makes a new vector | ~0 | 0.0009 |
  | `cos(bundle(a,b,c), a)` — bundle stays similar to its parts | >0 | 0.514, 0.535 |
  | `cos(bundle(abc), bundle(cba))` — bundle commutes | 1 | **1** |
  | `cos(permute(a,1), a)` — permute destroys similarity | ~0 | 0.0098 |
  | `cos(permute(permute(a,1),-1), a)` — permute inverts | 1 | **1** |
  | `permute(bind(a,b),1) = bind(permute(a,1), permute(b,1))` — distributes | 1 | **1** |

- **Class:** CLEAN. The one law that does not hold exactly is F-072.

### F-072: bind is lossy, by a stable 18% a round, and nothing says so

- **Where:** `probes/holon/vsa-algebra.wat`, `probes/holon/bind-lossiness.wat`.
- **The self-inverse axiom is approximate.** `bind(bind(a,b),b)` should recover `a`. It recovers
  it at **cosine 0.818**, not 1 — and this is the axiom the architecture rests on, because
  **there is no unbind verb**: the whole raw surface is `vector-bind`, `vector-blend`,
  `vector-bundle`, `vector-bytes`, `vector-permute`. Binding twice by the same vector is the only
  way back.
- **The loss is systematic, not noise.** Six different pairs: 0.8180, 0.8147, 0.8180, 0.8161,
  0.8186, 0.8123 — 0.815 ± 0.003.
- **The mechanism is sparsity.** These are ternary vectors, so `a·b·b` is `a` wherever `b ≠ 0`
  and **zero wherever `b = 0`**. Every zero coordinate in the binder destroys that coordinate of
  `a` permanently. Sparse-ternary binding is known to be lossy this way; dense bipolar binding is
  not. The measured 0.818 implies roughly 18% zeros in an encoded vector.
- **And it compounds multiplicatively.** Two rounds measured 0.667 ≈ 0.818²; three measured
  0.543 ≈ 0.818³. So nesting depth is bounded:

  | binding depth | recovered cosine |
  |---|---|
  | 1 | 0.818 |
  | 2 | 0.667 |
  | 3 | 0.543 |
  | 4 | ~0.448 — **below the 0.49 that `presence?` requires at this dimension** |

  So a role-filler structure survives about **three** levels of nesting before the recovered
  vector falls under the architecture's own threshold for "is this the same thing".
- **What still works, and is the point.** A codebook lookup is unharmed: the recovered vector
  scores 0.818 against the right atom and −0.0009, −0.0057, −0.0037, 0.0006 against four others.
  The right answer wins by two orders of magnitude. Lossy unbinding is fine for
  nearest-neighbour recovery against a known codebook, which is how VSA is normally used.
- **So:** this is very likely a designed tolerance rather than a defect — but nothing states it.
  A reader of the surface sees `vector-bind` with no `vector-unbind` and no note that binding
  twice is the inverse, no statement that the inverse is lossy, and no figure for how lossy or
  how it compounds. That is the difference between "use a codebook" and "unbind returns what you
  put in".
- **Class:** GAP. Clean: say that bind is its own inverse, that the inverse is lossy at roughly
  0.82 a round, that the loss is multiplicative, and that recovery is by nearest neighbour
  against a codebook rather than by exact reconstruction.
- **Repro:** the two probes.

### F-073: `coincident?` tests the opposite of what its documentation says

- **Where:** `probes/holon/coincident-semantics.wat`, found while checking whether F-072's lossy
  unbinding still clears wat's own recognition thresholds.
- **The documented contract** (`src/intrinsic/holon/atom.rs`):
  > `(:wat::holon::coincident? a b)` → `:bool`, whether `a`'s cosine to `b` **clears the
  > coincident floor** — the tighter of the two similarity thresholds (`presence?` is the looser
  > one).
- **The implementation** (`src/holon/coincident.rs`):
  ```rust
  // presence?     cosine > enc.presence_floor(sym)            -> cosine > 0.49
  // coincident?   (1.0 - cosine) < enc.coincident_floor(sym)  -> cosine > 0.99
  ```
  Both floors are the same formula, `sigma / sqrt(dims)` (`src/vm_registry.rs`), giving 0.49 for
  presence (sigma 49) and 0.01 for coincident (sigma 1) at d = 10000. But they are **used in
  opposite directions**: `presence?` asks whether the cosine *exceeds* the floor; `coincident?`
  asks whether the *distance from 1* falls *below* it.
- **So the phrase "clears the coincident floor" describes the wrong test.** A reader who sees a
  floor of 0.01 and the words "cosine clears the floor" will expect nearly everything to be
  coincident. The measured ladder — every rung far above 0.01, every one rejected:

  | cosine | `coincident?` |
  |---|---|
  | 1.0 | yes |
  | 0.818 | **NO** |
  | 0.667 | **NO** |
  | 0.543 | **NO** |

- **`coincident-explain` confirms the real rule arithmetically.** It reports `min-sigma-to-pass`
  19, 34 and 46 for those three rungs; solving `1 − sigma×floor ≤ cosine` predicts 18.2, 33.3 and
  45.7. Three independent confirmations that the test is `cosine ≥ 1 − sigma·floor` = 0.99.
- **The doc is right that coincident? is the tighter test** (0.99 against 0.49) — only the
  mechanism is described backwards. That it ships a `coincident-explain` diagnostic "for when a
  coincidence judgement disagrees with expectation" suggests the confusion is already known.
- **Class:** GAP. Correct: say that `coincident?` holds when `1 − cosine` is below the floor —
  that the floor is a *tolerance below identity*, not a similarity threshold. The two floors
  share a name and a formula but not a meaning.
- **Repro:** `probes/holon/coincident-semantics.wat`.

### F-074: the raw vector algebra produces `Vector`s that `presence?` will not accept

- **Where:** `probes/holon/coincident-semantics.wat`, `probes/holon/bind-lossiness.wat`.
- **What happened** (2026-09-15, wat-rs `a3218644d`): `presence?` on two raw vectors is refused
  at startup, verbatim:
  ```
  :wat::holon::presence?: parameter #1 expects :wat::holon::HolonAST; got :wat::holon::Vector
  ```
  The implementation calls `require_holon` on both arguments and then encodes them itself.
  `coincident?` takes `:wat::core::Value` and accepts a raw `Vector` happily.
- **So:** `vector-bind`, `vector-bundle` and `vector-permute` all answer a `Vector`, and the only
  recognition predicate that will take one is `coincident?` — which is the near-identity test
  (F-073). The looser "is this the same thing" test, `presence?` at 0.49, is **unreachable from
  the raw vector path**; a caller has to take the cosine and compare against `presence-floor`
  themselves. There is no `Vector → HolonAST` lift in the surface (`to-holon`, `from-holon`,
  `to-wat`, `from-wat`, `leaf`, `literal` all work at the AST level).
- **Which matters because F-072 makes it the common case.** Anything unbound is a raw `Vector`
  at cosine ~0.82 — below `coincident?`'s 0.99 and above `presence?`'s 0.49 — so the one
  predicate that would answer "yes, that's it" is exactly the one that cannot be called.
- **Class:** GAP. Extend: let `presence?` take a `Vector`, as `cosine`, `dot` and `coincident?`
  already do (the cheatsheet documents cosine/dot as "polymorphic over HolonAST or Vector
  inputs"; `presence?` is listed without that note and does not have it).
- **Repro:** the two probes.

## The formatter

### C-040: `:wat::fmt::` is idempotent across all 62 files of wat's own stdlib

- **Where:** `probes/fmt/corpus.wat`, `probes/fmt/smoke.wat`. `:wat::fmt::` was at zero probes,
  and it carries the cleanest property in the language: **`format(format(x)) == format(x)`**. A
  formatter that fails that is wrong whatever its style, so no oracle is needed.
- **The corpus is wat's own stdlib** — the 62 `.wat` files the formatter exists to format. Each
  is formatted twice and compared, and each runs inside its own `:wat::test::run-thread`, so one
  file that raises cannot mask the rest (the failure mode F-070 found in wat's own doctest
  runner).
- **What happened** (2026-09-16, wat-rs `a3218644d`): **62 files, 0 not-idempotent, 0 raised.**
- **The design is worth recording.** The formatter is grep facts → rete rules → `Break`
  assertions → a dumb emitter: `fmt.wat`'s header says "Rules assert Breaks; this file holds no
  style opinion." The 54 rules come from 14 files in `wat-scripts/fmt/rules/` and are
  deliberately **not baked into the binary** ("a new rule is a new file"), so an ordinary program
  drives it as
  `(:wat::fmt::format-source path src (:wat::rete::collect-rules :fmt))` after loading them.
  It is the largest thing in this repository built out of a subsystem already measured here
  (C-036), and it works.
- **It is not a pure layout tool, and its surface does not say so.** Formatting changes the parse
  of **14 of the 62** files. Every one of those diffs is the same thing and nothing else —
  measured by diffing `write-forms(read-string(src))` against the same of the formatted text:
  **107 insertions of `[]`, and zero deletions**, across 13 files (the 14th, `rete/compile.wat`,
  also changes; its diff was not itemised). That is the **param-spec migration** — a bare unit
  variant `:Exhausted` gains its `[]` because enums will require a param-spec — and it is
  deliberate, confirmed by the builder. So `fmt` migrates as well as formats.
  - That is worth documenting rather than filing: a user running the formatter gets program
    edits in the diff, not only whitespace, and nothing in the surface warns them.
  - It also makes the census useful. Sites still on the bare spelling: `runtime-meta` 40,
    `kernel/outcomes` 21, `runtime-typeinfo` 12, `telemetry` 11, `service` 10, `holon` 3,
    `io`/`program`/`kernel/diagnostics` 2 each, `edn`/`eval`/`spawn`/`stream` 1 each.
  - **A note on method:** my probe asserted `read(format(x)) ≡ read(x)` and reported these as
    "meaning changed". That is the wrong property for a formatter that migrates by design, and
    the builder corrected it. Idempotence is the right property, and it holds.
- **Class:** CLEAN.

### F-075: formatting runs at about 10 KB/s, with an 800 ms floor on any file

- **Where:** `probes/fmt/throughput.wat`. A formatter is an interactive tool — format-on-save
  wants to be imperceptible — so its speed is part of whether it can be used.
- **What happened** (2026-09-16, wat-rs `a3218644d`), one format each, timed with wat's own
  clock:

  | file | bytes | format | bytes/ms |
  |---|---|---|---|
  | `stream.wat` | 2,014 | 812 ms | 2 |
  | `io.wat` | 5,127 | 812 ms | 6 |
  | `rete/compile.wat` | 77,246 | 7,292 ms | 10 |
  | `core.wat` | 140,784 | 14,299 ms | 9 |
  | `service.wat` | 230,875 | **22,895 ms** | 10 |

- **Two separate costs.** There is a **fixed floor of about 800 ms** — the two smallest files,
  2 KB and 5 KB, took *the same* 812 ms, so that is the rete network being built from the 54
  rules, not the file. Above it, throughput is a steady **~10 KB/s**, and pleasingly **linear**:
  77 KB, 141 KB and 231 KB all land within 9–10 bytes/ms, so there is no quadratic blowup of the
  kind F-057 and F-062 found elsewhere. The cost is honest, just high.
- **So:** formatting one 231 KB file takes 23 seconds, and the cheapest possible format costs
  0.8 s. Ordinary formatters run at megabytes a second; this is roughly two orders of magnitude
  off what format-on-save needs. The whole 62-file stdlib takes about six minutes to format
  twice.
- **Where it likely goes.** Each format compiles 54 rete rules into a fresh network and asserts a
  `:wat::grep::Node` fact per AST node. Nothing here is wrong — F-051 already priced rete-adjacent
  work, and C-036 showed the engine is correct — but the fixed 800 ms in particular is paid again
  on every single invocation.
- **Class:** GAP. Improve: hold the compiled rule network across formats, so the 800 ms is paid
  once per process rather than per file. That alone would make small files interactive. With a
  bytecode VM coming, this is also a natural benchmark to keep.
- **Repro:** `probes/fmt/throughput.wat`, and `probes/fmt/corpus.wat` for the whole-stdlib run.

## The linter

### C-041: the linter is correct and precisely scoped on both its rules

- **Where:** `probes/lint/stdlib.wat`, `probes/lint/catches-what.wat`,
  `probes/lint/ladder-trigger.wat`. `:wat::lint::` is a pure-wat linter — "a rule is
  `(form → (Vector :- [Finding]))`" — and `lint-stdlib` is zero-argument, so the most direct
  question available is to ask it about wat's own standard library.
- **It has two form-level rules, and both are sound** (a third, `load-order`, exists but no
  public entry point reaches it for your code — F-079). Verified with positive, negative and
  threshold cases rather than positives alone:

  | case | fires? |
  |---|---|
  | `concat` interleaving a literal with a value | ✓ yes |
  | a boolean `if`/`=` ladder over one var, 3 literals, ending `false` | ✓ yes |
  | the same with 4 literals | ✓ yes |
  | the same with **2** literals — below the stated threshold of 3 | ✓ **no** |
  | keyword literals rather than strings | ✓ yes |
  | a *value*-returning `if`/`=` chain ending in `0` | ✓ **no** — it is a membership rule |
  | clean code | ✓ **no** — no false positives |

  `nested-if-=-ladder` recommends `(:wat::core::contains? (:wat::core::HashSet :- [:T] lit…) var)`;
  `concat-abuse` recommends `:wat::core::format`.
- **A note on method.** My first attempt handed it a three-literal ladder returning `1`/`2`/`3`
  and got nothing, and I was ready to report "the rule never fires". The rule's own comments say
  the chain must bottom out in `false` — it targets membership, not dispatch — so the trigger was
  narrower than my test, not absent. The threshold and negative cases above exist because of
  that.
- **It applies itself honestly:** of 99 findings over the stdlib, 6 are in `lint.wat`.
- **And it holds on code it has never seen:** 256 findings over this repository's 530 programs,
  same single rule, no false positive found (C-042).
- **Class:** CLEAN.

### F-076: the linter's recommended idiom, `:wat::core::format`, is in none of the user-facing docs

- **Where:** `probes/lint/stdlib.wat`.
- **What happened** (2026-09-16, wat-rs `a3218644d`): `lint-stdlib` reports **99 findings over
  wat's own standard library**, every one of them `concat-abuse`, each saying:
  > `string::concat interleaves N literal(s) with M value(s) — use (:wat::core::format "…{name}…" :name v …) instead`

  Concentrated in `service.wat` (27), `core.wat` (18), `query.wat` (13), `bracket.wat` (12),
  `fmt.wat` (7), `lint.wat` (6).
- **`format` exists and works.** It is a `defmacro` at `wat/core.wat:1681`:
  `(:wat::core::format "hello {name}, you are {n}" :name "world" :n 42)` → `"hello world, you are 42"`.
- **And it appears nowhere a user would find it:** zero hits for `:wat::core::format` in
  `USER-GUIDE.md`, `WAT-CHEATSHEET.md` and `CLOJURE-ROSETTA.md`.
- **Two independent witnesses that this costs something.** wat's own stdlib is flagged 99 times
  for not using it. And this repository — 450 wat programs written by a model with the
  documentation available — contains **339 `:wat::string::concat` calls and 0 `format` calls**. I
  never found it, because nothing I read mentioned it. The linter was the only thing in the
  system that knew. Run over those programs, it says so **256 times**, every finding the same
  rule (C-042) — so the gap is not one author's blind spot.
- **So:** the linter is currently better documentation of wat's string idiom than the
  documentation is. (The sibling recommendation, `contains?`, *is* documented — 2 hits in the
  user guide, 1 in the rosetta — so this is specifically about `format`.)
- **Class:** GAP. Clean: document `format` where `string::concat` is documented, and ideally say
  that concat-with-interleaving is the shape to avoid. It is the single highest-frequency idiom
  gap the ledger has found: 99 sites in the stdlib, 339 in this repository.
- **Repro:** `probes/lint/stdlib.wat`, and the counts above.

### F-077: `lint.wat` blocks its own auto-fix on a primitive that exists, and that the same file uses

- **Where:** `probes/lint/end-span.wat`.
- **What the file says** (`wat/lint.wat`, header):
  > STOP-1 in effect: the auto-fix … **cannot land cleanly because `:wat::core::ast-span` returns
  > ONLY the START location (line/col), not the end** — so computing old-len for a structural node
  > (the whole ladder form) **is not possible with the current substrate primitives**. The rule is
  > shipped REPORT-ONLY (fix = None).
- **What the runtime says:**
  ```
  ast-span      {:line 6 :col 45}
  ast-end-span  {:line 6 :col 64}
  ```
  for `(:wat::core::+ 1 2)` — 19 characters, exactly the form's width. `:wat::core::ast-end-span`
  exists and answers one past the end.
- **And the same file already knows.** Forty lines below the STOP-1 note, `lint.wat`'s own
  `FixEdit` record documents its fields as: "end-line / end-col: 1-indexed position one char PAST
  the last char (**from ast-end-span**)". The header and the record contradict each other.
- **So:** a rule ships report-only, and a seam is "deferred", for a blocker that no longer holds.
  84 of the 99 findings carry no fix. The cost of a stale blocker is not the stale sentence; it
  is that the next person to look has to re-derive it, and may simply believe it — the same shape
  as F-070's `#[ignore]` reason, which was also stale and also cost a re-measurement.
- **Class:** GAP. Correct: the header should be retired or re-pointed. Improve: with
  `ast-end-span` available, the ladder rule's auto-fix is unblocked.
- **Repro:** `probes/lint/end-span.wat`.

### C-042: two independent authors, one rule — the linter agrees with itself across 592 files

- **Where:** `probes/lint/self.wat`.
- **The experiment** (2026-09-16, wat-rs `a3218644d`). `probes/lint/stdlib.wat` asked the linter
  about wat's own standard library. This asks the same question of the other side: the **532 wat
  programs in this repository**, written by a model with the documentation in front of it and no
  knowledge of the linter until this week.

  | | files | findings | `concat-abuse` | `nested-if-=-ladder` | `load-order` |
  |---|---|---|---|---|---|
  | wat's stdlib | 62 | 99 | 99 | 0 | 0 |
  | this repository | 530 | **256** | **256** | 0 | 0 |

  (530, not 532: two files are negative probes that deliberately do not lex — see F-078.)
- **Every finding, in both populations, is the same rule.** `nested-if-=-ladder` fires zero times
  across 592 real files from two independent authors, and `load-order` zero times per program.
  The linter's practical output is one rule.
- **This is the linter agreeing with itself, and it is why C-041 holds.** The rule verified
  against constructed positives, negatives and a threshold now has 256 unconstructed witnesses
  and produced no false positive I could find. A rule that fires 256 times on code it has never
  seen, all of one kind, is measuring something real about the code rather than about the rule.
- **59 of the 256 carry an auto-fix** (23%), against 15 of 99 in the stdlib (15%). So roughly four
  in five `concat-abuse` findings are report-only in both populations — which is F-077's cost
  measured a second way.
- **Class:** CLEAN.
- **Repro:** `wat probes/lint/self.wat` from the repository root.

### F-078: one unlexable file destroys the whole batch, and the error does not say which file

- **Where:** `probes/lint/self.wat`, and a two-file minimal case.
- **What happened.** `lint-source` over this repository's 532 files raised and returned nothing.
  The corpus deliberately contains programs that do not parse — they are negative probes, that is
  their entire purpose (`probes/name-lt.wat` exists to record that a name ending in `<` is
  refused). Reduced to two files:

  | batch | result |
  |---|---|
  | one clean file alone | `1` finding |
  | the same file **plus** one unlexable file | raises, exit 2, **0 findings** |

  One bad file in five hundred and thirty-one good ones costs every finding in all of them.
- **And the raise does not name the file.** The message is `lex error at byte 258`, and its only
  `:location` is `wat/lint.wat:586` — the linter's own line. `:wat::source::File` carries a
  `:path`, and `lint-file` has that record in hand when it calls the reader, but the error
  discards it. **I found the culprit by grepping all 532 files outside wat** for a `<` near byte
  258. Inside wat there was no way to ask.
- **The workaround is real but expensive:** screen every file through `:wat::test::run-thread`
  first and set aside the ones that fail — which is F-063's 1.3 ms thread spawn, per file, to
  learn something the reader already knew.
- **So:** a linter is a tool you point at a tree you have not read. The first file it cannot
  parse is the normal case, not the exceptional one, and it should become a `Finding` (the
  `Finding` record has `rule`, `file`, `line`, `col` and `severity` — a `parse-error` rule would
  fit it exactly) rather than an exception that discards the other five hundred results.
- **Class:** DEFECT. Fix: `lint-file` should catch the read failure and report it as a finding, or
  at minimum name the file in the raise.
- **Repro:** `wat probes/lint/self.wat`; the two-file case is in the probe's header.

### F-079: wat's complete rule set is reachable only for wat's own source

- **Where:** `probes/lint/self.wat`, `wat/lint.wat:640`.
- **The linter has three rules**, not two as C-041 recorded: `concat-abuse` and
  `nested-if-=-ladder` are form-level, and `load-order` — "rule-zero" — comes from
  `:wat::deporder::verify` through `:wat::lint::violations->findings`.
- **Only one entry point runs all three, and it is hardcoded to the stdlib.** `lint-stdlib` is
  five lines: `deporder::stdlib-sources`, `lint-source`, `deporder::verify`,
  `violations->findings`, `concat`. It takes no arguments, so it lints wat's own standard library
  and nothing else. The entry point an outside project gets is `lint-source`, which runs the
  form-level rules only — **2 of 3**.
- **Nothing else in the stdlib calls `violations->findings`.** Its only caller is `lint-stdlib`.
  To lint your own tree completely you must discover `:wat::deporder::`, work out that
  `verify` and `violations->findings` compose, and rewrite `lint-stdlib`'s body with your own
  sources — which is what `:sl::rule-zero` in the probe does, in two lines.
- **And doing it by hand has a trap that cost me a wrong number.** `deporder::verify` reads its
  argument as **one ordered load sequence** — which is exactly what the stdlib is. Handed this
  repository's 530 *independent programs* it returns **1778 load-order violations**. Run per
  program, the same corpus returns **0**. The 1778 was my category error, and `verify` had no way
  to know; but a `lint-files` export would have made the category explicit and the error
  unreachable.
- **Class:** GAP. Extend: export `lint-stdlib`'s body over a caller-supplied
  `(Vector :- [:wat::source::File])` — the five lines already exist and are already correct.
- **Repro:** `wat probes/lint/self.wat` prints both the batch and the per-file rule-zero counts.


## wat-grep

### C-043: the fact base holds both its declared laws, and its exactness claim, at corpus scale

- **Where:** `probes/grep/facts-invariants.wat`, `probes/grep/written-is-exact.wat`.
- **What `:wat::grep::` is.** The code-search engine the formatter is built on — `fmt.wat` calls
  `(:wat::grep::facts-of path src)` to turn a file into a fact base the rete then queries. 489
  lines, 13 functions, 12 records. It appears in **no user-facing page** — the F-065 shape again.
- **It declares its own laws in prose, and names its own control:**
  > ★ NON-VACUITY: `Node` must exceed `Named` on any real file. `Span` is emitted
  > UNCONDITIONALLY beside `Node` (unlike `Named`) because `ast-span`/`ast-end-span` are TOTAL —
  > Span == Node is the non-vacuity control for that half.

  Run over this repository's 534 files (2026-09-16, wat-rs `a3218644d`):

  | | |
  |---|---|
  | Node facts | 137,690 |
  | Span facts | **137,690** |
  | Named facts | 86,183 |
  | Written facts | 80,027 |
  | Unreadable | 2 |
  | **Span == Node violations** | **0** |
  | **Node > Named violations** | **0** |

- **And it survives what breaks the linter.** Two files in the corpus deliberately do not parse.
  `facts-of` matches `ReadOutcome.Malformed`, reports them as `Unreadable` facts, and returns
  every other file's facts — exit 0. `lint-source` on the same two files raises and discards all
  531 others (F-078). Same stdlib, same input class, opposite behaviour.
- **The `Written` predicate is exact where exactness matters.** `Named` says what a node is
  called; `Written` says *and it is spelled here* — the fact a rewriting rule must join, because
  a reader-synthesized node like `~x` is named `unquote` but its span covers the token `~x`.
  wat-rs measured 50 real source-corruption sites from that confusion before the guard existed.
  The guard is `nameable? AND single-line AND end-col − col == length(ast-name)`, and its note
  calls it "EXACT, not a heuristic", evidenced on 172 genuine and 50 phantom nodes.

  At 137,690 nodes — a 620× scale-up of that sample — the 6,156 Named-without-Written nodes
  break down as:

  | kind | count | |
  |---|---|---|
  | `StringLit` | 4,843 | see F-081 |
  | `Keyword` | 1,313 | `wat.core/quote` 1061, `unquote` 120, `quasiquote` 67, `unquote-splicing` 65 |
  | `Symbol` | **0** | |

  **Zero symbols are excluded**, and the keyword exclusions are *exactly* the four
  reader-synthesized names — no ordinary keyword is caught. So a rewriting rule over symbols
  never silently skips a site, which is the property the guard exists to provide. The sample
  scales.
- **Class:** CLEAN.
- **Repro:** `wat probes/grep/facts-invariants.wat` and `wat probes/grep/written-is-exact.wat`.

### F-080: `filterv` is the one core sequence verb that refuses a `PersistentVector`

- **Where:** `probes/aoc/persistent-filterv.wat` (the nine-verb control),
  `probes/grep/written-is-exact.wat` (the `foldl` workaround, in the code).
- **What happened.** `(:wat::core::filterv pred pvec)` is refused at startup — clauses attempted:
  `(Vector :- [T])` and `(Stream :- [T])`, and nothing else. Every other core sequence verb I
  tried takes one:

  | verb | `Vector` | `PersistentVector` |
  |---|---|---|
  | `mapv` `foldl` `length` `nth` `first` `rest` `reverse` `concat` | ✓ | ✓ |
  | **`filterv`** | ✓ | ✗ **refused** |

- **There is no parallel API to fall back to.** `:wat::vector::` — the namespace that does hold
  persistent operations — has exactly three verbs: `concat`, `conj`, `contains?`.
- **`filter` takes one, but is not a drop-in:** it returns a `:wat::stream::Stream`, so the
  result needs different handling downstream. (Aside: `(length <Stream>)` *type-checks* and fails
  at runtime with a message listing the six types it does accept — F-031's family, a third
  witness.)
- **This bites wat's own code immediately.** All five vectors in `:wat::grep::Facts` — `nodes`,
  `named`, `spans`, `written`, `unreadable` — are `PersistentVector`. So the fact base wat's own
  search engine produces cannot be filtered with the verb a user would reach for first; the probe
  that needed it had to rewrite the filter as a `foldl`.
- **So:** F-057 says the persistent containers are the ones that scale and nothing points users
  at them. This is the other half — when you do take the advice, one core verb stops working, and
  the gap is a single missing clause rather than a design decision.
- **Class:** DEFECT. Fix: add the `(PersistentVector :- [T])` clause to `filterv`, as its eight
  siblings already have.
- **Repro:** the nine-verb table above; `probes/grep/written-is-exact.wat` carries the `foldl`
  workaround with a comment.

### F-081: the `Written` guard excludes every string literal, and says so nowhere

- **Where:** `probes/grep/written-is-exact.wat`.
- **The header explains the guard entirely in terms of the reader:**
  > A reader-synthesized node (`~` → unquote, `` ` `` → quasiquote, `\c` → char/of, …) gets a
  > `Named` fact (its name is real) but NOT a `Written` fact.

  That accounts for 1,313 of the 6,156 exclusions — **21%**. The other **4,843 (79%) are string
  literals**, which the header never mentions.
- **And the exclusion is total, not incidental.** Of **80,027** `Written` facts across 534 files,
  the number that are `StringLit` is **0**. The mechanism makes it unavoidable: `ast-name` on a
  `StringLit` returns the string's *contents*, while its span covers the quotes, so
  `end-col − col == length(name) + 2` always. No string literal can ever carry a `Written` fact.
- **The consequence is silent.** A rewriting rule over string literals — renaming a path, fixing
  a message — joins `Written`, finds nothing, and reports no matches. That is indistinguishable
  from "there were none", which is the exact failure mode the builder's own audit note calls
  "unfalsifiable absence" and spent a stone removing from `facts-of`'s malformed path.
- **This is not a bug in the predicate.** Refusing to rewrite `"bolt"` into `bolt` is the
  conservative and correct choice. The gap is that the guard's stated rationale covers a fifth of
  its behaviour, so a rule author predicting what `Written` matches would get strings wrong.
- **Class:** GAP. Clean: say that `Written` holds no string literals and why. Extend: if a
  rewriting rule should be able to target string *contents*, that needs a fact carrying the inner
  span, which the current record cannot express.
- **Repro:** `wat probes/grep/written-is-exact.wat` — the `WRITTEN-STRINGLITS` line is 0 for every
  file.

### F-082: a header pins a measurement next to an invariant, and only the invariant survived

- **Where:** `probes/grep/facts-invariants.wat`.
- `grep.wat`'s header records, in the same comment block as the non-vacuity law:
  > shipped numbers: `5d650b807`, wat/fix.wat Node=4316 Span=4316
- **Measured at HEAD:** `wat/fix.wat` is **Node=4929 Span=4929** — 14.2% above the pinned figure.
- **It is not a defect, and that is the point.** `5d650b807` is 2026-08-24; HEAD is 2026-09-11.
  In those 18 days `fix.wat` grew from 1200 to 1374 lines (+14.5%), and its node count grew
  +14.2% — the density is unchanged, so the number moved because the file did.
- **The invariant beside it held exactly** (4929 == 4929, and 0 violations over 534 files). One
  line of that comment block is permanent and one perishes, and nothing marks which is which or
  re-checks either.
- **Class:** GAP. Clean: date the measurement or drop it; the law is the durable claim and it now
  has a test (`tests/cli/wat_grep.rs` G1/G2, added in the same stone that noticed these controls
  "had NEVER run"). Same family as F-077's stale blocker and F-070's stale `#[ignore]` reason.
- **Repro:** `wat probes/grep/facts-invariants.wat`, first three lines.


## The cache

### C-044: `:wat::cache::Lru` is a real LRU, and its guards behave exactly as documented

- **Where:** `probes/cache/lru-laws.wat`, `probes/cache/lru-guards.wat`.
- **The contract is precise, which is what makes it checkable.** `wat/cache.wat` says `put`
  "returns the DISPLACED entry — the least-recently-used one when the insert pushed past
  capacity, or `k`'s previous binding when `k` was already present"; `get` returns "`Some v` on a
  hit (**which bumps `k` to MRU**)"; `len` is "never above capacity … does not touch LRU order".
- **The load-bearing clause is `get`'s parenthetical**, because that is the whole difference
  between an LRU and a FIFO: a read must count as use. So the decisive case is run with its
  control:

  | case | expected | got |
  |---|---|---|
  | cap 2 · put a · put b · **get a** · put c | evicts **b** (LRU) | ✓ `b=2` |
  | cap 2 · put a · put b · put c *(no get)* | evicts **a** (control) | ✓ `a=1` |

  Without the second row a build that always evicted the oldest would pass the first by accident.
  Eleven assertions in all — displacement is `None` under capacity, a re-put returns the previous
  binding and leaves `len` alone, and `len` never exceeded 3 across 500 puts. All pass first run.
- **The guards panic as declared, and usefully.** The header promises that two conditions panic
  rather than erroring as values — "deliberate behaviour-parity with the oracle". Capacity 0 and
  −1 both do, the message carries the offending value
  (`capacity must be positive; got -1`), and they are recoverable through
  `:wat::test::run-thread` — so a caller can guard a constructor, at F-063's 1.3 ms.
- **Class:** CLEAN.
- **Repro:** `wat probes/cache/lru-laws.wat`, `wat probes/cache/lru-guards.wat`.

### F-083: re-putting a key into a `HolographicLru` deletes it

- **Where:** `probes/cache/hologram-dual-evict.wat`.
- **What happened** (2026-09-16, wat-rs `a3218644d`). Capacity 8, one key, nothing to evict:

  ```
  H1 len after one put                  1      <- control: a first put survives
  H1 get finds it                       hit
  H2 len after first put                1
  H2 len after RE-PUT of the same key   0      <- the entry is gone
  H2 get after re-put                   MISS
  H3 len after 3 distinct puts, cap 2   2      <- control: dual eviction works
  ```

  Updating a cached value **removes it from the cache**. Both controls pass, so this is not a
  broken build: the mechanism works for the case it was written for and destroys the one it was
  not.
- **The cause is an `Option` that conflates two events.** `HolographicLru::put` is documented as:
  > 3. If step 2 displaced an entry (**over capacity**), remove ITS key from the Hologram too —
  > the dual-eviction invariant.

  But `Lru::put` displaces in **two** cases, as its own docstring says and C-044's L4 confirms:
  over capacity, *and* when the key was already present. The returned
  `(Option :- [Entry])` carries no discriminant, so step 3 cannot tell an eviction from an
  update — and on an update the key it removes is the one just inserted.
- **The same misreading is written down one function away.** `HolographicLru::get`'s comment says
  "`Lru::put` on an already-present key updates its recency **without displacing anything**".
  That is false by the same contract. `get` happens to bind the result to `_` and ignore it, so
  the false belief is harmless there and load-bearing in `put`.
- **And the file argues for the fix it didn't apply.** Its own header defends replacing an
  `Option` with a named enum elsewhere, quoting the doctrine directly: a `GetResult` of
  `:Hit`/`:Miss` ships instead of `Option` because "a proper enum name is doubly useful;
  `Option` tells a reader nothing about the DOMAIN". A displaced entry has exactly the same
  problem and exactly the same cure.
- **It reaches the shipped service.** `hologram-svc`'s `put` folds `HolographicLru::put` over a
  batch, so a *single batch* containing the same key twice loses it too.
- **The gate that should have caught it is careful, and still misses it.**
  `wat-tests/cache/HolographicLru.wat` has five cases, documents mutation-testing the eviction
  path ("sabotaging `HolographicLru::put` to skip the `Hologram/remove` call sends
  `test-dual-eviction` AND `test-get-bumps-recency` red"), and **every one of its cases writes
  each key exactly once**. For a cache, the second write to a key is the ordinary case.
- **Class:** DEFECT. Fix (one line): skip the `Hologram/remove` when the displaced key equals the
  key just inserted. Better (the file's own doctrine): give `Lru::put` a named result that says
  *which* of the two displacements happened, so no consumer has to guess again.
- **Repro:** `wat probes/cache/hologram-dual-evict.wat`.

### F-084: the cache's panic names its internal Rust shim, and prints a Rust note to stderr

- **Where:** `probes/cache/lru-guards.wat`.
- The capacity guard reports:
  `:rust::cache::Lru::new: capacity must be positive; got 0`
  — the **internal** `:rust::` name, not the `:wat::cache::Lru::new` the user actually called.
  This is the F-006/F-008 family, and the third witness after C-037's
  `:rust::sqlite::ReadConnection`.
- **And it is a raw Rust panic.** Even when caught by `run-thread`, stderr still carries
  `thread 'wat-thread-peer::<anon>' (330171) panicked at src/rust_deps/cache.rs:72:13` and
  `note: run with RUST_BACKTRACE=1 environment variable to display a backtrace` — an
  implementation detail of the host, surfacing to someone writing wat.
- **Class:** GAP. Correct: report the wat-facing name, and suppress the host backtrace note on a
  guard the language declares as part of its contract.
- **Repro:** `wat probes/cache/lru-guards.wat`, stderr.


## Telemetry

### C-045: the journal's sort key sorts chronologically across the whole i64 range

- **Where:** `probes/telemetry/time-sk-orders.wat`.
- **The claim, from `wat/telemetry/journal.wat`:**
  > sk = `#inst "<iso8601 with 9 fixed fractional digits, Z>"` — **CONSTANT WIDTH**, so it sorts
  > lexicographically = chronologically (the store's `sort-by Row/sk` is the range order).
- **It is load-bearing, not decorative.** `wat/query/mem.wat:58-59` filters a scan range with
  `(:wat::core::>= (StoredRow/sk row) lo)` and `(<= … hi)` — plain **string** comparison. If the
  key were not constant width, a keyset scan would return the wrong window and paginate past
  records, with no error raised anywhere.
- **Measured** (2026-09-16, wat-rs `a3218644d`) on cases chosen to break it — both i64 extremes,
  the epoch, either side of the epoch, and a sub-second boundary:

  | | |
  |---|---|
  | distinct key widths | **1** (38 chars, every case) |
  | adjacent-pair order violations | **0** of 10 |

  `-9223372036854775808` → `#inst "1677-09-21T00:12:43.145224192Z"`, `9223372036854775807` →
  `#inst "2262-04-11T23:47:16.854775807Z"`, and `-1` → `…1969-12-31T23:59:59.999999999Z` sorts
  below `0` → `…1970-01-01T00:00:00.000000000Z`.
- **And the reachable range is narrower than it looks**, which is why the other classic width
  break cannot occur: i64 nanos spans 1677 to 2262, so a five-digit year is unreachable.
- **Class:** CLEAN.

### C-046: a record that splices a surface does satisfy that surface

- **Where:** `probes/telemetry/scope-splice.wat`.
- `wat/telemetry.wat` calls itself "the first real consumer of surface-splice": `Metric` and `Log`
  open their field lists with `~@:wat::telemetry::Scope`, inlining the surface's four features
  ahead of their own, so `Metric/namespace` and friends are minted for free.
- **Both halves work.** The spliced accessors read correctly, the constructor's field order is
  splice-first as documented (`namespace uuid tags time-ns` then the record's own), and — the
  question worth asking — **a function typed by the surface accepts the record**:

  ```wat
  (:wat::core::defn :sp::ns-of [s <- :wat::telemetry::Scope] -> :wat::core::String
    (:wat::telemetry::Scope/namespace s))
  ```
  called with a `Metric`, returns `"probe"`.
- **That is the contrast with F-029**, where a function generic over a *parametric* surface
  refuses the structs that implement it — hit in two books. A splice is a different relationship:
  the fields are physically inlined, and satisfaction follows. So `Scope` is a type you can
  program against, not merely a macro that saves typing.
- **Nothing in wat's own source knows that.** `:wat::telemetry::Scope/<anything>` has **zero**
  uses anywhere in the stdlib — the spliced accessors `Metric/namespace` are used, the surface
  itself never is. This probe is its first consumer.
- **Class:** CLEAN.

### F-085: the user guide's uuid backward-compat note is wrong about three of the four spellings it names

- **Where:** `probes/uuid/spellings.wat`, `docs/USER-GUIDE.md:2642-2650`.
- **The note, verbatim:**
  > The retired namespace verbs `:wat::core::uuid::v4` and `:wat::core::uuid::v5` no longer exist
  > in the substrate; **new code MUST use `Uuid/v4` and `Uuid/v5`.** `:wat::telemetry::uuid::v4`
  > still works — it delegates to `:wat::uuid::v4` at the wat layer and returns a typed `:Uuid`.
  > **Existing callers of the telemetry alias see no behavior change**; new code should reach for
  > `:wat::uuid::v4` directly.
- **Measured against the substrate:**

  | spelling | the note says | what happens |
  |---|---|---|
  | `:wat::core::uuid::v4` / `v5` | "no longer exist" | ✓ unresolved reference |
  | **`Uuid/v4` / `Uuid/v5`** | "new code **MUST** use" | ✗ **retired** — *"':wat::core::Uuid/v4' is retired; use ':wat::uuid::v4' instead"* |
  | **`:wat::telemetry::uuid::v4` / `v5`** | "still works … no behavior change" | ✗ **does not exist** — *"not a builtin, not a registered function"* |
  | `:wat::uuid::v4` | mentioned in passing | ✓ the only one that works |

- **So the paragraph contradicts itself inside five lines** — mandating `Uuid/v4` and then
  recommending `:wat::uuid::v4` — and the spelling it makes mandatory is the one the checker
  refuses. It also promises an alias still resolves when it resolves to nothing.
- **A backward-compat note is the one piece of prose whose whole job is to be right about
  spelling.** This one describes a first migration (`core::uuid::` → `Uuid/v4`) that a second
  migration (`Uuid/v4` → `uuid::v4`) has since superseded; the section's own code examples use
  the correct spelling throughout, so only the note went stale.
- **The refusal itself is excellent** — it names the replacement and carries a populated
  `:remedies` entry, which is what F-058's refusal lacked. The gap is entirely in the prose.
- **Class:** GAP. Clean: retire the note, or rewrite it to the one surviving spelling.
- **Repro:** `wat probes/uuid/spellings.wat`, and the two commented lines in it.

### F-086: telemetry's three headers document a namespace that no longer exists, in code that would not compile

- **Where:** `wat/telemetry.wat`, `wat/telemetry/journal.wat`, `wat/telemetry/span.wat`.
- All three headers describe the namespace as **primed** — `:wat::telemetry'`, with a trailing
  apostrophe — and explain why: "The namespace is PRIMED (`:wat::telemetry'`) — staged to replace
  the loaded `wat-telemetry` battery bridge, so no collision."
- **The apostrophe appears 14 times across the three files and zero times in code.** Every
  declaration is plain `:wat::telemetry::`. The migration finished; the headers did not.
- **One of those 14 is a code sample that would be refused:**
  "`Metric`/`Log` are `defrecord`s that SPLICE the `Scope` surface via `~@:wat::telemetry'::Scope`"
  — the actual line is `~@:wat::telemetry::Scope`. A reader copying the header's spelling gets a
  parse failure.
- **Class:** GAP. Clean: a three-file find-and-replace. Same family as F-077's stale blocker,
  F-082's stale measurement and F-070's retired `@example` spellings — the fourth instance of a
  comment outliving the thing it describes, which is now the most common shape in this ledger.


## The user-facing documentation, compiled

### F-087: 81 of the 203 verb names the user-facing docs teach are rejected by the compiler

- **Where:** `tools/doc-names-audit.sh`, `tools/doc-names-verdicts.tsv`.
- **Method.** Not "grep the stdlib and diff" — a name can be a Rust intrinsic, a wat `defn`, a
  `defmacro` or generated, so set membership proves nothing. Every candidate is handed to the
  compiler **on its own** and classified by what the compiler says. (One name per run: a bulk
  file stops after two type errors and masks the rest — I tried.)
- **Corpus.** Every `:wat::…` token with a lowercase final segment in `USER-GUIDE.md`,
  `WAT-CHEATSHEET.md`, `CLOJURE-ROSETTA.md` and `docs/README.md`. Prose placeholders
  (`set-*!`, `<source>::to-<target>`), bare namespace prefixes, and the lowercase **primitive
  type names** (`:wat::core::i64`, `bool`, `f64`, `nil`, `keyword`, `true`) are dropped: a type is
  not callable, so testing it as a call head would be a false positive. That leaves **203 names,
  each verified individually**.

  | verdict | count | |
  |---|---|---|
  | EXISTS | 116 | |
  | **MISSING** — *"not a builtin, not a registered function"* | **68** | |
  | **RETIRED** — *"… is retired; use … instead"* | **19** | |
  | *less: named only to say they do not exist* | **−6** | see below |

  **81 of 203 — 40% — of the distinct verbs these documents name do not work.**
- **A second correction, and this one favours the docs.** Six of the 87 are named *only* in
  sentences that say they do not exist — `:wat::list::reduce`/`:wat::list::fold` appear once each,
  inside the guide's own note that it "previously named … neither of which exists on disk";
  `:wat::core::uuid::v4`/`v5` only in F-085's backward-compat note listing them as retired;
  likewise `:wat::config::set-dim-count!` and `:wat::std::member?`. My extractor counted the
  documentation being *correct* as the documentation being wrong. Filtering every rejected name
  whose only mentions carry a disclaimer (`retired`, `no longer`, `does not exist`, `neither of
  which`, `removed`, `deprecated`, `previously named`) removes exactly 6, and **81 is the honest
  figure**. None of the 6 appears in a code block, so the block counts below are unchanged.
- **One correction, and it is the method's.** Probing each name with zero arguments reported
  `:wat::kernel::assertion-failed!` as retired; it is not — only its zero-arg form is, and
  `(:wat::kernel::assertion-failed! :message "x")` works and is what this repository's own probes
  use. It is excluded above. The other three retirements that name no replacement — `define`,
  `enum`, `struct` — were re-run **with** plausible arguments and are genuinely refused, so the
  artifact is confined to that one name. An earlier pass of mine reported "87 of 98 (89%)"; that
  denominator was a set I had already filtered to suspicious names, which is selection bias on my
  side. 43% is the figure against every verb the docs name.
- **Every one of the 87 is genuinely in the corpus** — checked by attributing each back to a
  file, with zero misattributions — and they concentrate in the main teaching document:
  **79 of 87 appear in `USER-GUIDE.md`**, 13 in `docs/README.md`, 10 in the cheatsheet, 3 in the
  rosetta. **None sits under a "planned", "future" or "not yet" heading**; there are no such
  headings in these documents.
- **The 68 MISSING verdicts were re-probed a second way** — each name called with three value
  arguments instead of none, so an arity-specific retirement could not masquerade as an absence.
  **All 68 still report "not a builtin, not a registered function."** The zero-arg artifact is
  confined to the one `RETIRED` case named above. A useful control fell out of it:
  `:wat::kernel::spawn-program` answers *"no clause matches arity 1"* — a resolved name failing on
  arity, which is exactly what a false MISSING would have looked like, and it was classified
  EXISTS by both probes.
- **Widening the corpus barely moves it.** Repeating the audit over all **24** files in `docs/`
  adds only 18 new names (221 total): 11 more MISSING, 1 more RETIRED — **99 of 221, 45%**. The
  rejected names are already concentrated in the pages a user is told to read. (Two of those 11,
  `:wat::cache::lru-svc` and `:wat::pause::*`, are service names rather than verbs and would need
  their own probe shape; the four-document figure above does not depend on them.)
- **And it is not confined to a stale corner.** Across the three teaching documents, **49 of 159
  fenced code blocks (30%) contain at least one name the compiler rejects**, and **26 of them use
  `:wat::core::define`**, which is retired (Stone 241.11).

  | doc | blocks | with a rejected name | using retired `define` |
  |---|---|---|---|
  | `USER-GUIDE.md` | 127 | 40 (31%) | 24 |
  | `WAT-CHEATSHEET.md` | 20 | 6 (30%) | 2 |
  | `CLOJURE-ROSETTA.md` | 12 | 3 (25%) | 0 |

- **The affected material is the primary teaching material, not counter-examples.** Three
  specimens, run verbatim:

  1. **§4 "Writing functions" opens with the retired form.** The section that teaches a newcomer
     how to declare a function is headed ``### `define` — named registration`` and its first
     block is
     `(:wat::core::define (:my::app::double (n :i64) -> :i64) (:wat::core::i64::* n 2))`.
     Refused: *"bare primitive type ':i64' is retired (arc 109 slice 1c)"*, and `define` itself
     is retired.
  2. **"A slightly richer first program"** (§2) is refused: *"bare unit type '()' is retired
     (arc 109 slice 1d); canonical FQDN form is ':wat::core::nil'"*. (The ledger already noted
     this one program; the point here is that it is representative rather than isolated.)
  3. **A reference table lists an API that does not exist.** `USER-GUIDE.md:3703-3709` tabulates
     `:wat::stream::map` / `filter` / `inspect` / `take` / `collect` / `fold` with their argument
     and return types. The real `:wat::stream::` namespace has **four** verbs — `cons`, `empty`,
     `lazy`, `next` — and none of those six is among them. A worked streaming-pipeline example at
     line 2200 uses `spawn-producer`, `map`, `chunks` and `collect`; all four are unresolved.

- **The refusals themselves are excellent**, which is the sharpest part. Nearly every retirement
  names its replacement and cites the arc that made it: *"':wat::core::f64::to-string' is
  retired; use ':wat::f64::to-string' instead"*, *"':wat::core::foldr' is retired (arc 118.B6b);
  use '(:wat::core::reduce f init (:wat::core::reverse coll))' instead"*. The substrate knows
  exactly what every one of these names became. **Nothing propagated that knowledge into the
  prose** — so the compiler is a better and more current reference than the reference is, which
  is F-076's shape (the linter knew about `format` and the docs did not) at forty times the
  scale.
- **Class:** GAP. Clean — and mechanical, because the substrate already holds the mapping. The
  19 RETIRED names come with their replacements in the error text; a codemod over the docs could
  fix those without a judgement call. The 68 MISSING ones need a decision per name: delete the
  claim, or build the verb.
- **Repro:** `tools/doc-names-audit.sh` re-derives the table from scratch against any wat-rs
  checkout; `tools/doc-names-verdicts.tsv` is the run recorded here (2026-09-16, `a3218644d`).


### F-088: for three namespaces, the documented API and the real one are disjoint sets

- **Where:** `probes/stream/drain.wat`, `tools/doc-names-verdicts.tsv`.
- F-087's 68 unresolved names are not scattered evenly. Grouped by namespace, three of them
  turn out to have **no overlap at all** between what the documents teach and what exists:

  | namespace | verbs the docs teach | of those, that exist | verbs that exist | of those, documented |
  |---|---|---|---|---|
  | `:wat::stream::` | 9 | **0** | 4 | **0** |
  | `:wat::config::` | 6 | **0** | 1 | **0** |

  The documented stream API and the actual stream API do not share a single verb. The docs
  name `map`, `filter`, `inspect`, `take`, `collect`, `fold`, `chunks`, `flat-map`, `for-each`,
  `spawn-producer`, `from-receiver`, `with-state`; the substrate has `cons`, `empty`, `lazy`,
  `next`.

  **A third namespace was in this table and has been removed.** `:wat::list::` looked entirely
  fictional — 2 names, 0 verbs — until I read the lines they came from: both are inside the
  guide's own correction note saying it "previously named `wat/list.wat` and
  `:wat::list::reduce`/`:wat::list::fold`, neither of which exists on disk". The documentation was
  right and my extractor was wrong. See F-087's second correction; the `stream` row survives it
  untouched (0 of its 9 are disclaimed) and `config` loses one.
- **`:wat::kernel::` is the largest absence**: 15 names, a whole concurrency and sandboxing
  surface — `make-bounded-channel`, `make-unbounded-channel`, `process-send`, `process-recv`,
  `try-recv`, `spawn`, `fork-program`, `fork-program-ast`, `join-result`, `run-sandboxed`
  (+ `-ast`, `-hermetic-ast`), `spawn-program-ast`, `drop`, `extract-panics`.
- **And it closes a road a user actually walks.** Three findings compose:
  1. `filterv` refuses your `PersistentVector` (F-080), so you reach for `filter`;
  2. `filter` takes it and answers a `Stream`, so you reach for the documented
     `:wat::stream::collect` (`USER-GUIDE.md:3709` gives its signature) — which does not exist;
  3. and `(length <that Stream>)` type-checks before dying at runtime (F-031).

  Every exit from that position is either absent or silent.
- **The real API is good, and unfindable.** `next` is a single-force pull returning
  `(NextOutcome :- [T])` — `:Item [value rest]` or `:Exhausted []` — and `wat/stream.wat`
  explains the design well ("replaces the three-force `empty?`/`first`/`rest` walk protocol",
  measured at "15 user-code calls for 5 elements"). That file is not a document a user reads,
  and the four verbs it describes are mentioned **zero** times across all four user-facing pages.
- **The missing `collect` is six lines**, and `probes/stream/drain.wat` carries it:
  ```wat
  (:wat::core::defn :sd::drain [s <- :sd::S acc <- :sd::P] -> :sd::P
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:sd::drain r (:wat::vector::conj acc v))]
      [:wat::stream::NextOutcome.Exhausted {} acc]))
  ```
- **Class:** GAP. Extend (`stream::collect` at minimum — P-025) and Clean (document the four
  verbs that exist; delete the twelve that do not).
- **Repro:** `wat probes/stream/drain.wat`.


### F-089: three of the binary's four modes are documented nowhere, and there is no `--help` to find them with

- **Where:** `tools/cli-surface.sh`.
- **There is no help flag.** `--help`, `-h`, `help`, `--version` and `-V` are all read as
  *filenames*: `wat: read --help: No such file or directory (os error 2)`, exit **66**
  (`EX_NOINPUT`). A usage block does exist — but only when `wat` is invoked with **no arguments
  at all**, which exits 64 (`EX_USAGE`). The two exit codes are correct sysexits; the problem is
  that the one invocation that prints the usage is the one a user who has read "run it on a file"
  will never try.
- **The usage names four modes. One of them is documented:**

  | mode | mentions across the four user-facing pages | |
  |---|---|---|
  | `--check` | 6 (all in `USER-GUIDE.md`) | |
  | `--repl` | **0** | |
  | `--mcp` | **0** | |
  | `--grep` | **0** | |

- **The REPL works.** Fed `(:wat::core::+ 2 3)` and `(:wat::string::concat "a" "b")` on stdin it
  answers `5` and `"ab"` and exits 0. For a Lisp, a REPL is among the first things a newcomer
  looks for, and nothing a user reads says it is there.
- **`--fmt`, `--lint` and `--test` are *not* modes** (also read as filenames) — the formatter,
  linter and test runner are wat-level libraries you call from a program, which is a reasonable
  design and also not stated anywhere.
- **This is the same shape as F-087 seen from the other side.** There, the docs name 87 verbs the
  substrate does not have. Here, the substrate has three modes the docs do not name. The two
  drifted apart in both directions at once.
- **Class:** GAP. Extend: a `--help` that prints the usage block already written. Clean: name
  `--repl`, `--grep` and `--mcp` in the user guide.
- **Repro:** `tools/cli-surface.sh`.


## Rationals

### C-047: wat's rationals are exact, and faithful to Clojure

- **Where:** `probes/rational/laws.wat`.
- `:wat::rational::` is five verbs — `+ - * / to-f64` — over a `num_rational::BigRational`, with
  its own reader literal (`1/2`, `-3/2`). Every law it should hold, holds:

  | | |
  |---|---|
  | reader reduces to lowest terms | `2/4` reads as `1/2` |
  | **exactness** | `1/3 + 1/3 + 1/3 = 1` → **true** |
  | f64 control | `0.1 + 0.2 = 0.3` → **false** |
  | commutative, associative, distributive | all hold |
  | `x * (1/x) = 1` | holds |
  | arbitrary precision | `1/9223372036854775807 + itself` → `2/9223372036854775807`, no overflow |
  | `1/0` | refused at **lex** time |

- **And the one surprise is Clojure's surprise.** A literal that reduces to a whole number is not
  a rational at all: `4/2` reads as `i64`, so a function taking `:wat::core::rational` accepts
  `1/2` and refuses `4/2`. That is deliberate — `crates/wat-reader/src/ast.rs` says such a literal
  "parses to `IntLit` instead, never this variant" — and it is exactly Clojure's behaviour,
  checked against **clj 1.12.6** in the same session:

  | | clojure | wat |
  |---|---|---|
  | `2/4` | `clojure.lang.Ratio` `1/2` | `rational` `1/2` |
  | `4/2` | **`java.lang.Long` `2`** | **`i64` `2`** |
  | `(+ 1/2 4/2)` | `Ratio` `5/2` | `5/2` via `:wat::core::+` |

  Per the standing rule, a deliberate Clojure-faithful divergence is friction, not a bug — though
  the friction is real: `(:wat::rational::+ 1/2 4/2)` **is refused** while the generic
  `(:wat::core::+ 1/2 4/2)` works. The verb named after the type is the one that cannot take the
  literal.
- **It is documented nowhere.** `:wat::rational::` is named **zero** times across
  `USER-GUIDE.md`, `WAT-CHEATSHEET.md`, `CLOJURE-ROSETTA.md` and `docs/README.md` — an entire
  branch of the numeric tower, with reader syntax of its own. (Grepping those files for
  "rational" finds only "rationale" and "aspirational".) The F-088 shape again.
- **Class:** CLEAN, with a Clean-the-docs note.

### F-090: a well-typed program crashes — `rational` arithmetic returns a `bigint` it did not declare

- **Where:** `probes/rational/laws.wat` (L5/L6).
- **What happens.** This type-checks and dies at runtime:

  ```wat
  (:wat::rational::to-f64 (:wat::rational::+ 1/2 1/2))
  ```
  ```
  RuntimeError  :wat::rational::to-f64: expected rational, got wat::core::bigint `1N`
  ```

  The control rules out the verb: `(:wat::rational::to-f64 (:wat::rational::+ 1/4 1/4))` → `0.5`.
  The only difference is that the first result reduces to a whole number.
- **The declared type is a lie the implementation knows about.** `wat/core.wat:119-120` declares
  `([x <- :wat::core::rational y <- :wat::core::rational] -> :wat::core::rational …)`, and the
  comment eight lines above says the opposite:
  > `:wat::rational::+` itself accepts a bigint accumulator (self-promoted) so the fold can carry
  > a COLLAPSED intermediate (**this stone's pinned collapse: a BigRational result reducing to a
  > whole number becomes bigint**) across steps…

  The collapse is known, named and pinned. The remedy applied was to make the *arithmetic* verbs
  lenient enough to swallow their own output.
- **Four of the five verbs were made lenient. The fifth was not:**

  | verb, applied to a collapsed rational | result |
  |---|---|
  | `+` `-` `*` `/` | all four absorb it |
  | **`to-f64`** | **runtime `TypeMismatch`** |

  So the collapse is contained inside the arithmetic family and leaks at the one verb that leaves
  it — the verb you call at the end of a computation.
- **Why this is the sharpest class in the ledger.** Every other type finding here is the checker
  refusing something that would have worked (F-029, F-058, F-080), or accepting something that
  fails for an *untyped* reason (F-031, F-044). This is the checker proving a claim the runtime
  then contradicts, in a two-call program containing no user types at all.
- **Class:** DEFECT. Fix (one line, precedented four times over): give `to-f64` the same bigint
  leniency `+ - * /` already carry. Better: declare what these verbs actually return — the honest
  type is rational-or-integer, and a named enum for exactly this job is the file's own doctrine
  (F-083).
- **Repro:** `probes/rational/laws.wat`; uncomment the final line.

### F-091: a lex error names no file, no line and no column — only a byte offset into wat-rs's own parser

- **Where:** `probes/rational/laws.wat`, `probes/name-lt.wat`.
- **Two witnesses, found a week apart and both by accident.** `1/0`:
  > `lex error at byte 95: invalid numeric literal "divide by zero"`,
  > `:location … {:file "crates/wat-reader/src/parser.rs" :line 201 :col 28}`

  and a name ending in `<` (`probes/name-lt.wat`):
  > `lex error at byte 258: angle-bracket type parameters are illegal in a name`, the same
  > `parser.rs` location.
- **Neither names the offending file**, and neither gives a line or column within it — only a byte
  offset. Type errors in the same substrate do far better:
  `:location {:file "/tmp/t.wat" :line 2 :col 68 :end {:line 2 :col 95}}`. The gap is specific to
  the lexer.
- **It has a measured cost.** This is exactly why F-078 was hard: `lint-source` over 532 files
  raised `lex error at byte 258`, and finding which file meant grepping all 532 outside wat for a
  `<` near byte 258. A file name would have made it a one-second answer.
- **And the message reads as though the reason were the literal:** `invalid numeric literal
  "divide by zero"` quotes the *cause* in the slot where the offending text belongs, so the
  sentence claims a literal spelled `divide by zero` was invalid.
- **Class:** GAP. Correct: carry the source path, and resolve the byte offset to a line and column
  as every other diagnostic class already does.
- **Repro:** `wat` on any file containing `1/0`, or `probes/name-lt.wat`.


## wat-fix, the wat-to-wat converter

### F-092: wat's own codemod breaks 9 of 16 independent programs, in four distinct ways

- **Where:** `tools/fix-roundtrip.sh`, `probes/fix/convert.wat`, `probes/fix/subject.wat`.
- **What it is.** `wat/fix.wat` is "`fix-source`: the wat-to-wat faithful-Clojure converter", and
  its header opens: **"THE PROVING POINT: wat writes wat."** `fix-text` is the text entry point
  (`String -> String`, span edits so whitespace survives). The documented workflow — the
  "STASH-DANCE", marked *"this is the supported path — do NOT hand-edit instead"* — runs it over
  an entire corpus in one shot, with the warning *"list EVERY path; a missed file breaks the
  build"*.
- **The only test that means anything for a codemod is semantic preservation.** Converted, ran
  both, compared stdout and exit code, over 16 self-contained probes from this repository that
  were green to begin with:

  | outcome | count |
  |---|---|
  | identical behaviour | **7** |
  | **converted program no longer starts** (rc 0 → 3) | **8** |
  | conversion itself failed | **1** |

- **Four distinct causes, each reduced to a minimal case:**

  1. **A function-type bracket gets the wrong namespace.** `[:wat::i64 :-> :wat::i64]` converts to
     `[wat.core/i64 :-> wat.core/i64]`, which is unresolved. The rule appears to treat every `[…]`
     as a parameterization bracket, and only `(Head :- […])` accepts `wat.core/`:

     | position | `wat.core/i64` | `wat.type/i64` |
     |---|---|---|
     | plain annotation `[n :- T]` | **unresolved** | ✓ |
     | inside `(wat.core/Vector :- [T])` | ✓ | ✓ |
     | inside fn-type `[T :-> T]` | **unresolved** | ✓ |

  2. **`:wat::WatAST` is converted into a spelling that does not exist.** It becomes
     `wat/WatAST` — and `wat/WatAST`, `wat.type/WatAST` **and** `wat.core/WatAST` are *all*
     unresolved. `:wat::WatAST` is the only form that works, so there is no correct output for
     this input. That is F-005 ("no symbol spelling for types outside `wat::core`") turning into a
     data-loss bug: the converter destroys the one spelling that resolves.
  3. **`Type::method` spellings break** — `:wat::core::Result::try` and `:wat::core::Result::expect`
     both become unresolvable.
  4. **A `defenum`'s name is converted from a keyword to a symbol**, and the declaration is then
     refused: *"malformed :wat::core::defenum declaration: name must be a keyword"*.

- **Localized: three of the four are not dispatch bugs — the target dialect cannot express the
  input.** Asking the two conversion verbs directly (`probes/fix/keyword-conversions.wat`):

  | input | `keyword::to-symbol` | `keyword::to-type-form` | a spelling that resolves? |
  |---|---|---|---|
  | `:wat::core::i64` | `wat.core/i64` | `wat.type/i64` | both, in the right slot |
  | `:wat::WatAST` | `wat/WatAST` | `wat/WatAST` | **none** — `wat/`, `wat.type/`, `wat.core/` all unresolved |
  | `:wat::core::Result/try` | `wat.core.Result/try` | `wat.type/Result::try` | **none** |
  | `:u::Veg` (a `defenum` name) | `u/Veg` | `u/Veg` | **none** — the declaration needs a keyword |

  Only case 1 is a mis-dispatch: the two verbs differ correctly, and `fix-seq` simply picks
  `to-symbol` for the first element of a `[…]` because it is handed items, not the bracket they
  came from — in a `(…)` that element is a call head, in a `[…]` it is a type.

  The other three have **no correct output at all**. `:wat::core::Result/try` is the sharpest:
  every symbol spelling canonicalizes the associated-function `/` back to `::`, so
  `wat.core.Result/try` is read as `:wat::core::Result::try` — a different name. The conversion is
  not injective, and the original keyword is the only form that runs.
- **The header is honest about scope** — the rules were "grown one at a time", "each probe-gated"
  — so this is a coverage boundary rather than a betrayal. The gap is that **nothing tells a user
  where the boundary is**, while the documented procedure applies the tool to every file at once
  and warns that a miss breaks the build. A codemod that silently produces non-compiling output on
  half its input needs a refusal, not a rewrite.
- **Class:** DEFECT. Fix, in two parts, because the causes are two kinds. (a) The dispatch: give
  `fix-seq` the bracket kind, so a `[…]`'s first element takes `to-type-form`. (b) The rest:
  **refuse rather than rewrite.** `:wat::WatAST`, `Type/method` and a `defenum` name have no
  faithful-Clojure spelling, so the only non-destructive action is to leave them alone — and the
  general safety net is for `fix-text` to `read-string` its own output and refuse to emit a form
  that no longer parses, machinery already present in the file.
- **Repro:** `tools/fix-roundtrip.sh ../wat-rs probes/*.wat`,
  `wat probes/fix/keyword-conversions.wat`.

### F-093: converting a program removes call-site type checking — and that is what the converter is for

- **Where:** `tools/fix-roundtrip.sh`, and a two-line pair.
- **The same program, in the two spellings.** Declared `[n <- :wat::core::i64] -> :wat::core::i64`,
  body `n`, called with a String:

  | spelling | result |
  |---|---|
  | rust-scheme `(:bad::ident "I am a String")` | **rc 3** — *":bad::ident: parameter #1 expects :wat::core::i64; got :wat::core::String"* |
  | faithful-Clojure `(bad/ident "I am a String")` | **rc 0** — prints `"I am a String"` |

  A function declared to take and return an `i64` accepted a String, returned it, and exited 0.
- **The hole is exactly the call site, and no wider.** Three controls place it:

  | | |
  |---|---|
  | an unknown type in an annotation (`wat.type/zzzz`) | ✓ refused |
  | returning a String literal from `:- wat.type/i64` | ✓ refused |
  | an undefined Clojure-spelled function | ✓ refused, "1 unresolved reference" |
  | **a wrongly-typed argument at a Clojure-spelled call** | ✗ **not checked** |

  So annotations are real and declarations are checked; what is not checked is the argument at
  the call. This is F-014 with its consequence measured.
- **And this is what the codemod does to every file it touches.** `fix-source`'s whole purpose is
  to move call heads from the checked spelling to the unchecked one — its `head-rule` is exactly
  *"a list-head `::`-keyword (a rust-scheme call head) → a faithful-Clojure symbol"*. So the **7
  of 16 programs that converted cleanly in F-092 are "clean" only because they were already
  correct**: each of them lost call-site type checking silently, and nothing in the output says so.
- **Class:** DEFECT (F-014's). The ledger has had "symbol-headed calls unchecked" since early on;
  what is new is that wat ships, documents and recommends a tool whose job is to perform that
  conversion across an entire corpus.
- **Repro:** the two files above; `tools/fix-roundtrip.sh`.


## Brackets, wat's parallelism layer

### C-048: `bracket::map` is correct and order-preserving, on both loci

- **Where:** `probes/bracket/parallel-map.wat`, `probes/bracket/scaling.wat`.
- `:wat::bracket::` is "the brackets layer (Ruby's Parallel) built over spawn-program" — a thread
  or process pool whose `map` and `each` are `defmacro`s, called as
  `(:wat::bracket::map (:wat::spawn::thread) <items> <work-fn>)`.
- **Ordering is the claim worth testing, and it holds under a workload designed to break it.**
  wat-rs's own fixture is named `brackets_map_doubles_in_order`, but its work-fn is `(* x 2)` —
  every item costs the same, so a pool returning *completion* order would pass it by luck. This
  probe inverts the cost instead: item *i* burns `(n − i)` units, so the last item finishes first
  and completion order would be the exact reversal of input order. The result came back in input
  order, identical to `mapv`, every time.
- **10 rows across both loci and 1–16 items: `same=yes` on all of them.**
- **And `:wat::spawn::Locus` accepts both implementors.** One `[locus <- :wat::spawn::Locus …]`
  function takes `(:wat::spawn::thread)` (a `ThreadOpts`) and `(:wat::spawn::process)` (a
  `ProcessOpts`). A second witness for C-046, and again the contrast with F-029.
- **Class:** CLEAN.

### F-094: the thread pool does not parallelize — the process pool does, and the machine proves it

- **Where:** `probes/bracket/scaling.wat`, `tools/bracket-os-oracle.sh`.
- **A speedup ratio alone proves nothing**, so this is measured by *scaling*: hold the work per
  item fixed and vary the item count. Genuine parallelism keeps wall time roughly flat up to the
  runner count; serialized work grows linearly. `runner-count` is 16.

  | items | seq | **thread** par | **process** par |
  |---|---|---|---|
  | 1 | 1025 | 922 | 1522 |
  | 2 | 2005 | 1480 | 2101 |
  | 4 | 3784 | 2429 | 2288 |
  | 8 | 7576 | 6038 | 3137 |
  | 16 | 16073 | **9513** (1.69x) | **5142** (3.38x) |

  From 1 item to 16, the **thread** pool's wall time grows **10.3x** — nearly linear, for 16x
  the work on 16 runners. The **process** pool's grows **3.4x**.
- **The external control rules out the hardware.** This is a 4 P-core + 8 E-core laptop that drops
  its turbo clock under full load, so 16x was never available. `tools/bracket-os-oracle.sh` runs
  the identical burn, the same interpreter, as 16 independent OS processes and lets the OS
  schedule: **5.90x**. The process locus reaches 3.4–3.8x, within range of that ceiling. The
  thread locus reaches **1.7x — about 29% of what the same machine does with the same code**.
- **One confound was real and is corrected here.** My first workload built its busywork with
  `(:wat::core::foldl … (:wat::core::range 0 k))`, which allocates a *k*-element Vector per call —
  a contended allocator would produce the same linear curve as serialized evaluation. Rewriting
  the burn as an allocation-free tail-recursive countdown *improved* the thread numbers (1.45x ->
  1.7x at 16 items), so allocation was part of it — and the gap survives its removal.
- **There is a crossover, which is the practical advice.** Below about four items the process
  pool is *slower* (0.61x at one item) — a spawn floor of roughly 1.5 s. Above it, processes win
  and keep winning.
- **And none of this is findable.** `:wat::bracket::` appears in the four user-facing pages
  exactly once, in `WAT-CHEATSHEET.md`, where `:wat::bracket::runner-loop :- [I O]` is used as a
  **syntax specimen for binders** — not as an API. So a user cannot discover the parallelism
  layer, and if they do, the locus that looks like the obvious default is the one that does not
  parallelize.
- **Class:** IMPROVE (and Clean). The measurement to hand a builder: thread 1.69x, process 3.38x,
  OS ceiling 5.90x, all on one machine in one session.
- **Repro:** `wat probes/bracket/scaling.wat`, then `tools/bracket-os-oracle.sh`.


## Runtime reflection

### C-049: the reflection API works, and is one of the few documented subsystems

- **Where:** `probes/runtime/reflection.wat`.
- `:wat::runtime::` is wat's reflection surface — 17 registered verbs, and unusually for this
  ledger it **is** documented: `USER-GUIDE.md:2986`, "Runtime reflection — `:wat::runtime::*`
  (arc 143)", 16 mentions. So it can be checked in the direction nothing else here could: docs
  against code.
- **The verbs do what they say.** For `(:rr::my-add [a <- i64 b <- i64] -> i64 (+ a b))`:

  | call | answer |
  |---|---|
  | `signature-of-defn` | `(:rr::my-add (a wat.type/i64) (b wat.type/i64) -> wat.type/i64)` |
  | `body-of` | `(:wat::core::+ a b)` |
  | `extract-arg-names` | `[:a :b]` |
  | `extract-arg-types` | `[wat.type/i64 wat.type/i64]` |
  | `return-type-of` (of a fn value) | `"wat::core::String"` |

- **Class:** CLEAN.

### F-095: the reflection section documents the wrong return type, five times

- **Where:** `probes/runtime/reflection.wat`, `docs/USER-GUIDE.md:2986-3120`.
- **Every return in the section is given as `:wat::holon::HolonAST`:**
  `lookup-callable`, `signature-of-defn` and `body-of` as `(:Option :- [:wat::holon::HolonAST])`
  (L2994, L2999, L3002), `extract-arg-names` and `extract-arg-types` as
  `(:Vec :- [:wat::holon::HolonAST])` (L3011, L3120).
- **They return `:wat::WatAST`.** Measured, not inferred: a function declared
  `[n <- :wat::WatAST]` accepts `signature-of-defn`'s payload and `ast->source` renders it. And
  `:wat::holon::HolonAST` is not a near-miss name — it is a **real, different type**, the VSA
  holon AST that `:wat::cache::HolographicLru` keys on (`wat/cache.wat:274-320`). Declaring a
  parameter `[n <- :wat::holon::HolonAST]` and passing it to `ast->source` is refused:
  *"parameter #1 expects :wat::WatAST; got :wat::holon::HolonAST"*.
- **`extract-arg-names` is wrong twice over.** The guide calls its result "**bare-symbol** arg
  names (suitable for splicing as call positions)". It returns
  `(:wat::core::Vector :- [:wat::core::keyword])` — `[:a :b]`, keywords. The checker says so
  itself: *"`mapv`: parameter #1 expects `[:wat::core::keyword :-> …]`"*. Splicing `:a` into a call
  position is not splicing `a`, so the one stated use case is the one that would not work.
- **The section also teaches a verb that does not exist.** `:wat::runtime::lookup-callable` is one
  of F-087's 68, and L3047's "**Coverage today.** `:wat::runtime::signature-of-defn` +
  `lookup-callable` + …" names it again as shipped.
- **And the shape it hands back is the retired one.** `signature-of-defn` returns
  `(:rr::my-add (a wat.type/i64) (b wat.type/i64) -> wat.type/i64)` — the
  `(name (arg :Type) -> :Ret)` form of the retired `:wat::core::define`, which is exactly what
  F-087 found §4 still teaching. A macro that splices this is splicing a form the current reader
  will not accept.
- **Two verbs take a value where the section implies a signature.** `return-type-of` and
  `signature-of-fn` want a **fn value**, not the AST the neighbouring verbs return; handing one a
  `sig` dies at runtime with *"expected wat::core::fn value …, got wat::WatAST"*. Nothing in the
  section marks the change of argument kind.
- **Class:** GAP. Correct: `:wat::WatAST` in five places, `keyword` for the arg-name element, and
  a note that `return-type-of`/`signature-of-fn` take values. Clean: retire `lookup-callable` from
  the prose and from the coverage sentence.
- **Repro:** `wat probes/runtime/reflection.wat`.


## The load-order analyzer

### C-050: deporder does exactly what it claims, and can be made to fail

- **Where:** `probes/deporder/order-laws.wat`.
- **What it is.** `:wat::deporder::` is "the stdlib load-order analyzer" — given an ordered list of
  `SourceFile{path,source}` it builds a symbol → (file, kind) map and returns the `Violation`s
  where a file eval-depends on a **later-loaded** file. Its header states the classification rule
  it works by: `defmacro` is **order-free**;
  `defn`/`defenum`/`defalias`/`def`/`defprotocol`/`defclause`/`typealias`/`defstruct`/`newtype`/
  `extend-type`/`derive` are **eval-dependent**.
- **A checker that reports zero has proved nothing until you know it can report something.**
  wat-rs's own rune for this is R59, *NISI FRANGAS, NIHIL PROBAS*. So:

  | | result |
  |---|---|
  | **D1** the real baked stdlib order, 62 files | **0 violations** |
  | **D2** the *same 62 files*, order reversed | **457 violations** |
  | **D3** two files, referencer before definer | **1**, `a.wat (pos 0) -> b.wat (pos 1) symbol :u::callee` |
  | **D4** the same two, definer first | **0** |
  | **D5** a reference ahead of the `defmacro` that defines it | **0** — the order-free rule holds |

  D2 is the one that makes D1 mean anything: the same input, reordered, produces 457 findings, so
  the zero is a measurement and not a silence.
- **The Violation is fully addressed.** It names the referencing file *and its position*, the
  defining file *and its position*, and the symbol — everything needed to act, which is more than
  F-078's lex error manages for the linter.
- **And it is fast.** Reading the 62 files takes 1 ms; `verify` parses and analyzes ~1.3 MB of
  stdlib in **1291 ms**, about **1 MB/s**.

  That is a useful control for F-075. The formatter does comparable pure-wat work over source at
  roughly **10 KB/s** — a hundred times slower — so wat's parsing and walking are not the
  formatter's problem, which is what F-075 suspected when it pointed at the rete network being
  rebuilt from 54 rules on every invocation.
- **Class:** CLEAN.
- **Repro:** `wat probes/deporder/order-laws.wat`.


## Performance

### F-096: a `defrecord` field read costs 5× a `defstruct` field read, and 17× a builtin call

- **Where:** `bench/records.wat`, `bench/dispatch.wat`, `tools/bench.sh`, `BASELINE.md`.
- **Measured** (2026-09-16, wat-rs `a3218644d`, minimum of 3 runs, each against an empty-loop
  control of the same shape):

  | operation | ns/op |
  |---|---|
  | builtin call (`:wat::i64::+`) | **360** |
  | `match`, two arms | 675 |
  | user `defn` call | 795 |
  | closure call | 853 |
  | **`defstruct` accessor** | **1219** |
  | **`defrecord` accessor** | **6130** |

- **The control rules out the obvious explanation.** The loop passes its aggregate through every
  recursive call, so passing could have been the cost. Measured on its own, carrying the record
  without touching it lands **at or below the empty loop** — no measurable cost. The 6130 ns is
  the accessor.
- **And the two aggregates differ 5×** for an identical one-field shape, read through an
  identically-spelled accessor (`(:r::Box/v b)` either way). A user choosing between `defrecord`
  and `defstruct` is choosing on the documented criterion — whether the value may cross a
  boundary (F-040) — and getting a 5× read cost with it, which no page mentions.
- **It is stable**: 6072 / 6171 / 6484 ns across three runs, against 1230 / 1250 / 1304 for
  `defstruct`. A 4.9–5.0× ratio every time.
- **The scale is not hypothetical.** Records are the substrate's own working vocabulary —
  `:wat::grep::Facts`, `:wat::query::StoredRow`, `:wat::lint::Finding`, `:wat::telemetry::Metric`.
  `probes/grep/facts-invariants.wat` walks 137,690 nodes; at 6.1 µs a field read, a single pass of
  one accessor over that corpus is **0.84 s** of accessor alone.
- **The builder expects them to share a backing** (2026-09-16: "afaik they are both backed by
  structs anyways"), which makes the 5x a surprise on the implementation side rather than a
  design consequence — and narrows where to look.
- **Class:** IMPROVE. This is also the most actionable item for the byte-code work: of everything
  in `BASELINE.md`, the record accessor is the largest multiple over the cheapest operation in the
  same interpreter, which makes it the clearest single target.
- **Repro:** `tools/bench.sh ../wat-rs 3`, or `wat bench/records.wat`.


## Okasaki — purely functional data structures

### C-051: Okasaki's persistent set ports cleanly, and wat has the types for it

- **Where:** `okasaki/lib/set.wat`, `okasaki/ch02-persistent-set.wat`.
- Chapter 2's `UnbalancedSet` is 40 lines of wat. The foundation it needs — a **recursive
  parametric enum** — works:
  `(:wat::core::defenum :ok::Tree :- [A] :Leaf [] :Node [l <- (:ok::Tree :- [A]) v <- :A r <- …])`
  type-checks and pattern-matches, which is what every structure in the book rests on.
- **Correctness, 2000 LCG-generated values:** 2000 distinct, in-order walk **sorted**, walk length
  equals size, and `ok::Set`, a `PersistentMap`-to-`true` and a `HashSet` **agree on all 10000
  membership probes**. Depth 27 against an optimum of ~11, which is the expected shape for a
  random BST and is reported rather than assumed — the values are an LCG and not `0..n-1`
  precisely because a sorted sequence degenerates this structure into a linked list.
- **Class:** CLEAN.

### F-097: a persistent set written *in wat* is 40× slower than the workaround it would replace

- **Where:** `okasaki/ch02-persistent-set.wat`.
- **F-057 records that wat has no persistent set** — `PersistentVector` and `PersistentMap` share
  structure, and a visited set has to be a `PersistentMap` to `true`, which is what
  `aoc/day05-paths.wat` had to do. The open question was whether shipping one is worth it. This
  measures it, same workload, same machine, all three verified to agree first:

  | | build 2000 | 10000 membership tests |
  |---|---|---|
  | `ok::Set` — Okasaki's BST, in wat | **170 ms** | **519 ms** |
  | `PersistentMap` to `true` — F-057's workaround | 5 ms | 12 ms |
  | `HashSet` — the copying one | 29 ms | 10 ms |

  The hand-written persistent set is **34× slower to build and 43× slower to query** than the
  workaround it exists to replace.
- **And `BASELINE.md` predicts that, to within 5%.** A lookup costs 51.9 µs over a depth of 27 —
  **1922 ns per node visited**. The baseline's dispatch figures, measured on synthetic loops with
  no data structure in sight, say a node visit is one user `defn` call (795 ns) + one two-arm
  `match` (675 ns) + one or two `i64::<` (360–720 ns) = **1830–2190 ns**. Measured 1922.
- **So the conclusion inverts, and it is the useful one.** F-057's gap is real, but it cannot be
  filled by a library: **any** user-level pointer structure in wat pays ~2 µs per node regardless
  of its asymptotics, so a native `PersistentMap` beats a hand-written O(log n) tree by more than
  the algorithm can win back. The request F-057 should carry is a **native persistent set**, not
  a wat one — and until there is one, `PersistentMap`-to-`true` is not a workaround to apologise
  for, it is the right answer.
- **This also bounds the rest of the Okasaki port** (NEXT §10). Every structure in the book will
  be measured against a native competitor it cannot beat on constant factors, so the suite's value
  is in **correctness, expressiveness and the asymptotic curves**, not in wall-clock wins. Worth
  knowing at chapter 2 rather than chapter 9.
- **Class:** IMPROVE, redirecting F-057. The measurement to hand a builder: 2 µs per node visit is
  the price of any interpreted data structure, and it is three dispatch operations deep.
- **Repro:** `wat okasaki/ch02-persistent-set.wat`.


### C-052: the leftist heap and the batched queue are correct, and their bounds hold in wat

- **Where:** `okasaki/ch03-leftist-heap.wat`, `okasaki/ch05-batched-queue.wat`.
- **Chapter 3 — the priority queue F-056 says is missing.** All five checks pass over 2000 LCG
  values: the **leftist property** (rank of the left child ≥ the right, and the stored rank is
  right-spine + 1) and **heap order** hold at every node, draining by `delete-min` returns exactly
  2000 values, and the drain is non-decreasing. The invariants are *checked*, not trusted.
- **And the O(log n) bound survives the interpreter.** Insert cost against heap size:

  | n | 500 | 1000 | 2000 | 4000 |
  |---|---|---|---|---|
  | ns/insert | 157713 | 160757 | 193729 | 187283 |

  A **1.19× rise across three doublings**, where O(n) would predict 8×. Per F-097 the constant is
  dispatch and can't be helped; the *curve* is the structure's, and it is the shape claimed.
- **Chapter 5 — the batched queue.** FIFO order preserved over 2000 push/pop pairs, empty after
  draining, and the invariant *"front is empty only if the queue is"* held after **every single
  operation**. Its amortized O(1) is exact — `8755, 8737, 8702, 8755` ns/op across four doublings,
  flat to within 0.6%.
- **Class:** CLEAN. `okasaki/lib/heap.wat` is 60 lines and answers F-056.

### F-098: a record field holding a user enum value is deep-copied; the same field in an enum variant is shared

- **Where:** `okasaki/ch05-batched-queue.wat`, `okasaki/lib/queue.wat`.
- **The same algorithm, the same cons list, the same operations — differing only in what holds
  the pair:**

  | n | **enum-carried** | **record-carried** |
  |---|---|---|
  | 500 | 8755 | 38321 |
  | 1000 | 8737 | 54418 |
  | 2000 | 8702 | 79738 |
  | 4000 | **8755** | **158808** |

  The enum version is flat — Okasaki's amortized O(1), exactly. The record version is **18.1×
  slower at n=4000 and diverging**: its per-operation cost doubles as the queue doubles, so the
  bound the structure is *defined by* is destroyed by the choice of carrier.
- **Isolated to construction, and to user enum values.** Holding a list of length *n* and
  constructing 200 aggregates around it:

  | list length | `defrecord` | `defstruct` | `defenum` variant |
  |---|---|---|---|
  | 250 | 14873 | 14798 | **1092** |
  | 2000 | **123199** | **119966** | **1174** |

  Records and structs are **O(n) in the size of the field's value**; an enum variant is O(1).
- **Nothing the substrate provides is affected — only user types.** Two controls:

  | field holds | `defrecord` construction |
  |---|---|
  | a `PersistentVector` of 250 → 2000 | **flat**, ~4000 ns |
  | a `:wat::WatAST` parsed from 1442 → 4956 bytes of source | **flat**, ~1900 ns |
  | **a user `defenum` chain of 250 → 2000** | **14873 → 123199 ns** |

  So a native container is a handle, and even `WatAST` — itself a large recursive enum — is
  shared. Only a **user-defined** enum value is cloned.
- **Which is exactly why nobody has hit it.** `:wat::grep::Facts` holds five `PersistentVector`s,
  `:wat::telemetry::Metric` holds a two-variant scalar enum, `fmt` and `lint` hold `WatAST`s —
  none of wat's own records can trip this. It is reachable only by a user who defines a recursive
  enum and puts it in a record, which is the first thing anyone porting a functional data
  structure does.
- **Four hypotheses were eliminated before this one**, each with its own measurement: `cons` is
  O(1) (flat, ~2400 ns, so enum construction shares), `rev` is O(n) (flat per element),
  `defrecord` *allocation* does not degrade with count (flat), and the harness's own record
  traffic was not the cause (removing it made the curve *worse*). The carrier was what was left.
- **It joins a family.** F-023 (`conj` clones a Vector), F-033 (taking a WatAST apart copies every
  subtree), F-055 (`rest` clones, so walking is quadratic) and F-057 (the copying containers) are
  all "wat copies where it could share". This is the same shape at the aggregate boundary, and the
  most invisible of them: the two spellings look equivalent and differ asymptotically.
- **Class:** IMPROVE. The workaround is one word — carry the payload in an enum variant — and it
  is not discoverable. Anyone porting a functional data structure to wat will reach for
  `defrecord` first, because that is what a pair of things is.
- **Repro:** `wat okasaki/ch05-batched-queue.wat` — both carriers, one run.


### F-099: a non-tail recursion past ~110000 frames segfaults the process, silently

- **Where:** `probes/recursion/depth-limit.wat`.
- **Measured** (2026-09-16, wat-rs `a3218644d`):

  | depth | result |
  |---|---|
  | 1000 … **100000** | exit 0, correct answer |
  | **120000** and beyond | **SIGSEGV, exit 139, and stderr is empty** |

- **There is no diagnostic.** Every other failure class in wat produces structured EDN — a
  `CheckErrors`, a `RuntimeError`, an `UnresolvedReferences` — with a file, a line and a column.
  This produces **nothing at all**: no message, no exit code a program could interpret, just a
  dead process.
- **The runtime can see it — on another thread.** The identical overflow inside
  `:wat::test::run-thread` **aborts** (exit 134) with a real message:
  *"thread 'wat-thread-peer::<anon>' has overflowed its stack / fatal runtime error"*. So the
  guard page is doing its job on a spawned thread and not on the main one. It is still not
  recoverable: F-063 established `run-thread` as wat's **only general catch**, and it does not
  return a `Failed` here — it takes the whole process down with it.
- **The trigger is ordinary code, not a stress test.** Three natural spellings, all silent
  SIGSEGV:
  1. `(:ok::len l)` — the textbook non-tail-recursive list length —
     **over a 120000-element cons list**;
  2. a self-referential stream, `(defn s [] (:wat::stream::cons 0 (s)))`, which is the *natural*
     spelling because `stream::cons` is **eager in its tail** (this is how I hit it: writing
     SICP's `fibs = 0 : 1 : zipWith (+) fibs (tail fibs)`);
  3. any non-tail recursion over a large collection.
- **Recursion is wat's primary iteration idiom** — it is how every Friedman book in this
  repository is written — so the ceiling sits directly under the language's main control
  structure.
- **Tail recursion is unbounded**, and is the only mitigation: 1,000,000 frames returns correctly,
  so wat's TCO (arc 003) works exactly as documented. The gap is that nothing tells a user which
  of their functions is tail-recursive, and the penalty for guessing wrong is a silent crash.
- **Class:** DEFECT. Fix: install a guard on the main thread too, so the overflow reports as
  wat's own error rather than as a signal — the machinery already exists, since the spawned-thread
  path detects and names it. Better still, make it catchable, since `run-thread` is advertised as
  the catch.
- **Repro:** `probes/recursion/depth-limit.wat` runs at 100000 and carries the over-the-edge cases
  commented out, because a probe that segfaults would take the suite with it.


### F-100: lazy streams do not memoize — deliberately — so Okasaki's Part II needs a different type

- **Where:** `probes/stream/memoization.wat`.
- **Measured.** A suspension that prints when it runs, forced three times through the *same*
  stream value: the suspension ran **three times**. All three answers are correct; all three were
  recomputed. F-053 recorded this as a missing feature; this is it measured, with the consequence
  attached.
- **The consequence is a whole half of a textbook.** Okasaki's Part II — chapters 6 through 11,
  the banker's and physicist's queues, the real-time queue, the splay and pairing heaps,
  bootstrapped and implicit structures — is built on one mechanism: a suspension is forced **at
  most once** and shared thereafter, so the expensive step is paid once and amortized across every
  later access. Without memoization those structures do not lose their bounds by a constant, they
  **have no mechanism at all**: the rotation that the real-time queue schedules incrementally is
  simply re-run on every access.
- **This is a design decision, not an oversight, and the rationale is sound.** The builder,
  2026-09-16: the model is Ruby's `Enumerator` — pull an item, process it, discard it; *"I never
  need to use an item in the stream more than once, or if I do, I choose to hold those items in
  another struct for their re-use."* Used in production for paginated DynamoDB queries,
  Elasticsearch scrolls and multi-terabyte S3 objects and listings.

  **Ruby's `Enumerator` is not memoized either** — `each` re-runs the block, `.lazy` chains do not
  cache, and you only get caching by explicitly materialising with `to_a`/`force`. wat matches that
  exactly. Memoizing by default would turn every retained stream head into unbounded retention,
  which is the classic space leak and is precisely what makes a 1 TB file on an 8 GB host
  impossible. **The current semantics make that leak unrepresentable**, which is a property worth
  keeping.
- **So the ask is not "memoize streams" — it is a separate one-shot suspension.** Okasaki needs a
  `Susp<T>` cell (`$` / `force` in his notation): a deferred computation, forced at most once,
  *shared between accessors*. That is a different type from a sequence, and adding it would not
  change `Stream`'s semantics at all. The two needs genuinely differ:

  | | wants |
  |---|---|
  | `Enumerator`-style pull | force once **per traversal**, retain nothing, no sharing |
  | Okasaki's amortization | force once **ever**, shared across every later accessor |

  Materialising eagerly is not a substitute for the second: the whole point of the banker's queue
  is that the O(n) rotation is *deferred*, so forcing it early defeats the structure.
- **The 1 TB path is not reachable today in any case**, which is worth knowing before either is
  built. `:wat::io::` has exactly three verbs: `read-file` returns the **whole file as a String**,
  `with-open-file` is **write-only** (it opens an `IOWriter`), and `write-file`. Nothing in the
  substrate produces a `Stream` from a file or a reader. The only line-wise input in the language
  is `:wat::kernel::readln` on stdin — a loop, not a lazy sequence, so memoization never enters.
  The property the design protects is real; the code that would exercise it does not exist yet.
- **wat's own laziness is real and correct** — `wat/seq.wat` builds `remove` and `take-while` on
  `stream::lazy`, and wat-rs pins the property that `take-while` never realizes the cell past the
  first false. What is absent is *sharing* of what was realized.
- **A calling-convention note, since nothing documents it:** `:wat::stream::lazy` takes a **body
  expression**, not a thunk. `(:wat::stream::lazy (:wat::core::fn [] -> … ))` is refused with
  *"expects (wat::stream::Stream :- [T]); got [:-> …]"*. That is the whole of `:wat::stream::`'s
  documentation problem in one line (F-088: none of the four real verbs is mentioned in any
  user-facing page).
- **And materialising DOES recover most of it — measured.** The obvious workaround is to do the
  deferred work eagerly and share the result ("stream → vec → reuse the vec"), which is exactly
  what `okasaki/ch05-batched-queue.wat` already is: the rotation runs eagerly instead of being
  suspended. It is correct and flat at 8755 ns/op. What it recovers is the **ephemeral** bound —
  each version of the structure used once — which is the common case and is precisely the
  Enumerator pattern.

  What it cannot recover is the bound under **persistence**: branching several futures off one
  value. Taking a queue in its pre-rotation state and calling `tail` on that *same value* k times:

  | k (reuses of one value) | 10 | 25 | 50 | 100 |
  |---|---|---|---|---|
  | persistent ÷ ephemeral | **7×** | **23×** | **46×** | **86×** |

  **The penalty is k.** The rotation is paid once per reuse instead of once ever, which is exactly
  what a memoized suspension buys and what no amount of eager materialisation can. (A first
  version of this measurement was wrong — it drained the queue to empty, so no rotation ever
  fired, and the two arms did different work. The numbers above are the corrected run.)
- **So the practical summary is narrower than the finding first sounded.** Eager materialisation
  covers everything except two cases: multiple futures branched from one version, and **worst-case**
  rather than amortized latency (ch 7's real-time queue spreads the rotation across operations so
  no single call is slow). Neither is what an `Enumerator` does, and neither is reachable through
  `stream → vec`.
- **So NEXT §10 stops at chapter 5**, and that is a result rather than an abandonment: chapters 2,
  3 and 5 are the ones whose bounds are structural, and they ported and held (C-051, C-052).
  Everything past chapter 5 would be measuring F-100 over and over.
- **Class:** FRICTION, not a defect — a deliberate divergence with a named precedent, recorded so
  it is not re-litigated. Extend, if the amortized structures are ever wanted: a **separate**
  memoizing suspension cell, leaving `Stream` exactly as it is. F-053 and F-064 should be read the
  same way.
- **Repro:** `wat probes/stream/memoization.wat` — count the `FORCED` lines.


## Semaphores — concurrency

### C-053: wat's zero-mutex claim holds **within a service round** — and **C-094 shows it does not hold across two**

- **Where:** `semaphores/ch01-lost-update.wat`.
- **The Little Book of Semaphores exists because shared mutable state races.** N threads each
  incrementing a shared counter K times finish *below* N·K without synchronisation, because
  read-modify-write is not atomic; every puzzle in the book is a way of stopping that.
- **wat's answer is structural**, from `docs/ZERO-MUTEX.md`: state lives in a service, and the
  actor's serialisation **is** the mutex. This file tries to break it: **8 workers on a real
  thread pool, 200 increments each, one counter service.** The service's `bump` is written as
  three deliberate steps — read, add, write — so an interleaving would show.

  | run | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | final / expected | 1600/1600 | 1600/1600 | 1600/1600 | 1600/1600 | 1600/1600 |

  **Five for five, exact.** Races are nondeterministic, so one green run would have meant little.
- **So Downey's chapter 1 is answered by construction rather than by a semaphore** — *for a
  read-modify-write written as ONE service round*. The service processes rounds one at a time, so
  no interleaving is possible inside one.
- **CORRECTED 2026-09-17 (C-094). The sentence that stood here — "the first several puzzles have no
  wat form because the hazard they remove cannot occur" — was wrong, and wrong in the direction
  that flatters wat.** What this entry measured is a property of the **round**, not of the
  language. A read-modify-write spanning **two** rounds (`peek`, then `set`) is interleavable
  exactly as it is anywhere else, and loses updates catastrophically:

  | 8 workers × 50 increments, expected 400 | run 1 | run 2 | run 3 | run 4 |
  |---|---|---|---|---|
  | unguarded, read and write in separate rounds | **93** | **94** | **96** | **84** |
  | the same, guarded by a semaphore at 1 | 400 | 400 | 400 | 400 |

  About **77% of the updates are lost**, reproducibly, and a mutex fixes it deterministically. So
  Downey's book has a very direct wat form after all, and the honest claim is narrower and more
  useful than the one first written here: **a service round is atomic; a program is not.** The
  design removes the hazard exactly when the whole read-modify-write fits in one message, and a
  user who splits it across two has the classic race back, with nothing in the type system to say
  so.
- **Class:** CLEAN, with its headline claim narrowed by C-094.

### F-101: sharing a service address with a worker requires naming two generated types that appear in no documentation

- **Where:** `semaphores/ch01-lost-update.wat`.
- **The obvious spelling compiles and then cannot be used.** A worker that takes
  `[addr <- :wat::kernel::Address]` type-checks — the bare name is a legal annotation — but the
  peer that `kernel::connect` returns from it has **unresolved type parameters**, so no surface
  method can be called on it:
  > `:sem::Counter/bump: parameter #1 (receiver) expects :sem::Counter; got (:wat::kernel::Peer :- [:?5282 :?5283])`

  The annotation is accepted at the point where it is wrong and refused at the point where it is
  used, which is the hardest shape to diagnose.
- **The spelling that works has to name generated types:**
  ```wat
  (:wat::core::defn :sem::work :- [T]
    [addr <- (:wat::kernel::Address :- [(:sem::Counter::Op :- []) (:sem::Counter::Reply :- []) :T])]
    -> :wat::core::i64 …)
  ```
  `Address` is **three**-parameterized — op, reply, transport — and `:sem::Counter::Op` and
  `:sem::Counter::Reply` are minted by `defsurface`; the user never writes them.
- **Neither is documented.** Across `USER-GUIDE.md`, `WAT-CHEATSHEET.md`, `SERVICE-PROGRAMS.md`
  and `CLOJURE-ROSETTA.md`: **zero** mentions of a generated `::Op`/`::Reply` surface type, and
  **zero** of `(Address :- [...])` in its parameterized form. I recovered the naming rule by
  reading `wat/service.wat:1032-1051` — the `defservice` macro's own internals, where
  `proto-op-base-kw` is constructed. A user cannot be expected to do that.
- **And this is the ordinary case, not an exotic one.** Handing a pool of workers one service is
  what a service is *for*. It compounds F-052 (the spawn scope law forces `connect` inside each
  worker, so the address must cross a function boundary and therefore needs an annotation) and
  F-069 (the outcome arms at every call).
- **Class:** GAP. Clean: document the generated `::Op`/`::Reply` types and the three-parameter
  `Address`, since a service is unusable across a boundary without them. Correct: refuse the bare
  `:wat::kernel::Address` annotation at the annotation, or carry enough type information through
  `connect` that it does not need one.
- **Repro:** `semaphores/ch01-lost-update.wat`; the naive annotation is in the finding above.


### F-102: a service can withhold a reply, and nothing can ever release the caller

- **Where:** `semaphores/ch03-barrier.wat`, and a ten-line reduction.
- **`:wat::service::Outcome` has five variants**, and two of them withhold the reply:
  `Reply`, `Stop`, **`NoReply [state]`**, `ReplyAndArm`, **`NoReplyAndArm [state arms]`**. So the
  language clearly intends a service to be able to hold a request open — which is exactly what a
  barrier, a rendezvous, a bounded buffer and a lock all need.
- **But the held caller can never be answered.** Measured: a service whose only impl returns
  `Outcome.NoReply`, called once — **the caller hangs forever** (killed at 20 s, having printed
  "calling wait…" and nothing after).
- **There is no mechanism to answer it.** `Invocation` — the mandatory `ctx` — carries a
  `conn-id`, documented as *"the stable monotonic i64 minted in the serve loop (never reused) …
  the name that outlives the round"*. Nothing takes a `conn-id` and sends to it. `Alarm` /
  `NoReplyAndArm` fires back into the **service**, not to the waiting caller.
- **wat's own code never uses it.** `Outcome.NoReply` appears in `wat/service.wat` only inside the
  macro's own dispatch, and in two test fixtures — one of which is named `.bad`. No service impl
  anywhere in the substrate returns it, which is consistent with it being unusable.
- **So every blocking primitive in Downey's book has to be a spin.** `ch03-barrier.wat` is a
  correct 8-way barrier built by polling — arrive, then ask again until the count reaches N — and
  polling is precisely what chapter 3 introduces semaphores to eliminate.
- **Class:** GAP. Extend: a way to answer a held `conn-id` later, which would make `NoReply` mean
  something and make barriers, rendezvous and bounded buffers expressible. Correct, at minimum:
  say in the surface docs that a `NoReply` caller is stranded, since the variant's existence reads
  as a promise.
- **Repro:** the ten-line service in this finding; `semaphores/ch03-barrier.wat` is the workaround.

### C-054: the barrier is correct, and costs a round-trip per poll

- **Where:** `semaphores/ch03-barrier.wat`.
- Downey's chapter 3 barrier, 8 workers on a real thread pool: **8 of 8 released**, none
  proceeding until all 8 had arrived. The property holds by construction of the spin, and the spin
  is forced by F-102.
- **The price is visible:** **18 poll round-trips** across the 8 workers, 22 ms wall. At F-051's
  measured 224 µs per service message that is ~4 ms of pure waiting, on a barrier of 8.
- **And 18 is a lower bound, for an awkward reason.** The poll count depends on how much real
  concurrency there is, and F-094 measured `bracket::map`'s thread pool at 1.69× — so the workers
  arrive nearly in order and the later ones find the count already full. On a runtime that
  actually parallelised, the barrier would spin more, not less.
- **Class:** CLEAN, with the cost recorded. The puzzle is expressible; the primitive is not.
- **Repro:** `wat semaphores/ch03-barrier.wat`.


### C-055: a memoized suspension does buy back persistence — measured, on a stand-in

- **Where:** `okasaki/lib/susp.wat`, `okasaki/lib/bankers.wat`, `okasaki/ch06-bankers-queue.wat`.
- **The question F-100 left open** was whether a memoizing suspension would actually restore the
  bound that eager materialisation loses, or whether the interpreter's constants would swallow it.
  Chapter 6's `BankersQueue` exists for exactly this, so it is the experiment.
- **One value, k futures, each needing the rotation's result** (n = 800, `tail` then `head` on the
  same queue value k times):

  | k | eager (ch 5) ns/use | banker's (ch 6) ns/use |
  |---|---|---|
  | 10 | 3 014 241 | 508 633 |
  | 25 | 2 992 661 | 228 553 |
  | 50 | 3 063 693 | 144 198 |
  | 100 | 3 030 811 | **90 185** |

  **The eager queue is flat** — cost per use independent of k, the signature of paying the
  rotation *every time*. **The banker's queue falls as 1/k** — paid once and amortized across
  every future. **33.6× better at k = 100**, and the gap widens with k.
- **FIFO order holds** over 800 elements, checked against the insertion sequence.
- **The carrier had to thread a needle, and both constraints are findings here.** F-098: a
  `defrecord`/`defstruct` field holding a user enum is deep-copied, so holding the rear list in a
  record would make every `snoc` O(n). The containment rule: a **Pure** enum cannot hold a live
  handle, and a suspension is one. The only shape that both shares its payload *and* may hold a
  suspension is an **Impure enum**. Neither constraint is documented; both were measured here.
- **The absolute numbers carry a tax that a real primitive would not.** The suspension is the
  P-027 stand-in built on an LRU, and a cached `force` costs 7251 ns — 2× a function call — so
  every one of the banker's queue's forces pays it. The *shape* is the result; the constants are
  the hack's.
- **Class:** CLEAN, and it settles P-027's value: the suspension is worth building, and this
  measures what it buys.
- **Repro:** `wat okasaki/ch06-bankers-queue.wat`.


### C-056: the whole queue progression ports, and each chapter's bound is visible in a different measurement

- **Where:** `okasaki/ch05-batched-queue.wat`, `ch06-bankers-queue.wat`, `ch07-realtime-queue.wat`.
- **Okasaki's four queues each fix the previous one's weakness**, and each weakness needs its own
  experiment to see. All three are ported and all three show their claimed shape:

  | chapter | bound | the measurement that shows it | result |
  |---|---|---|---|
  | 5 BatchedQueue | amortized O(1), **ephemeral only** | ns/op as n doubles | **flat**, 8755 ns/op |
  | 6 BankersQueue | amortized O(1), **persistent** | ns/use as k futures branch from one value | **falls as 1/k**; eager stays flat at ~3.0 ms |
  | 7 RealTimeQueue | **worst-case** O(1) | **max** single operation, not the average | **114 µs** vs the banker's **3518 µs** — 30× |

- **Chapter 7's point is that an average cannot see it.** The banker's queue pays the rotation
  once, but pays it *all at once* on whichever operation forces it — a 3.5 ms spike inside an
  otherwise fast run. The real-time queue forces one schedule cell per call, spreading that work
  across the operations that caused it, and its worst single operation is 30× smaller. Both are
  FIFO-correct over 300 elements.
- **Three carriers, three times the same needle.** `BQ`, `LCell` and `RTQ` are all **Impure
  enums**, because each must hold a suspension (so not a Pure enum — the containment rule) and
  must share its payload (so not a record — F-098). That shape is not documented anywhere; it was
  derived here from two measurements.
- **All of it rests on the P-027 stand-in**, and chapter 7 is where the stand-in's cost stops
  being a constant factor: a lazy list is **one `:wat::cache::Lru` per cons cell**, so a 300-element
  front allocates 300 bounded evicting caches whose eviction can never fire. The absolute numbers
  are therefore mostly the hack. The *shapes* — flat, 1/k, bounded-max — are the results, and they
  are what a real `Susp<T>` would preserve.
- **Class:** CLEAN. Together with C-051 and C-052 this is chapters 2, 3, 5, 6 and 7 of Okasaki
  running under `./run.sh okasaki`.
- **Repro:** `wat okasaki/ch07-realtime-queue.wat`.


### C-057: lazy rebuilding ports too — a deque with no cheap end, bounded at both

- **Where:** `okasaki/lib/deque.wat`, `okasaki/ch08-bankers-deque.wat`.
- **Chapter 8 generalises the technique.** Chapters 5–7 all have an easy direction — the rotation
  only ever moves rear into front, so a spike can only land on one side. A deque has no such
  asymmetry: keep the halves within a factor c of each other (c = 3 here), and when one outgrows
  the other, split it and reverse the remainder onto the other side. Laziness makes that split
  incremental rather than a stop-the-world rebuild, which is what Okasaki means by *lazy
  rebuilding*.
- **All three checks pass over 300 elements:**

  | | |
  |---|---|
  | behaves as a **queue** (snoc, drain the front) | PASS |
  | behaves as a **stack** (cons, drain the front) | PASS |
  | balance invariant `lenf ≤ c·lenr+1` and `lenr ≤ c·lenf+1`, after **every** operation | PASS |

- **And the worst case is bounded at both ends**, which is the chapter's whole claim. Driving it
  by alternating `cons`/`snoc` to build and `tail`/`init` to drain, timing every operation:

  | | worst single operation |
  |---|---|
  | ch 6 banker's queue (amortized) | 3518 µs |
  | ch 7 real-time queue (worst-case, one-sided) | 114 µs |
  | **ch 8 banker's deque (both ends)** | **84 µs** |

  A structure with a cheap and an expensive end would show a spike on whichever side the rebuild
  lands. None appears.
- **Four carriers, four times the same needle.** `BQ`, `LCell`, `RTQ` and now `DQ` are all
  **Impure enums** — the only shape that may hold a suspension (containment rule) *and* shares its
  payload (F-098). At this point that is less an observation than a rule the language should
  state.
- **Still the P-027 stand-in**, and by chapter 8 both halves of the deque are per-cell LRUs, so
  the absolute numbers belong to the hack. The shape — bounded at both ends, invariant never
  violated — is what survives substitution.
- **Class:** CLEAN. §10 now runs chapters 2, 3, 5, 6, 7 and 8.
- **Repro:** `wat okasaki/ch08-bankers-deque.wat`.


### C-058: numerical representations port, and this is what a measurement looks like with no stand-in

- **Where:** `okasaki/lib/ralist.wat`, `okasaki/ch09-random-access-list.wat`.
- **Chapter 9 is a different technique**: the structure mirrors a number system. The list is a
  sequence of binary digits, each `Zero` or `One` carrying a complete tree of size 2^i, and `cons`
  is binary increment with carry. Indexing then finds the right tree in O(log n) and descends it
  in O(log n), where a cons list is O(n).
- **It needs no laziness at all**, so nothing in this chapter touches `lib/susp.wat` and none of
  these numbers carry the P-027 stand-in's tax. Every type is a **Pure** enum — no suspensions, no
  live handles, none of the Impure-carrier awkwardness chapters 6–8 required.
- **Correct**: over 400 elements, every index reads back exactly what was consed there, and the
  size is 400.
- **Both curves are textbook:**

  | n | random-access list | cons list |
  |---|---|---|
  | 400 | 94 302 | 1 032 344 |
  | 800 | 101 924 | 2 037 857 |
  | 1600 | 111 849 | 4 092 533 |
  | 3200 | **119 975** | **8 084 623** |

  The random-access list rises by a **constant additive step of ~8 600 ns per doubling** — that is
  O(log n). The cons list **doubles exactly** each time — 1.03M → 2.04M → 4.09M → 8.08M — which is
  O(n). At n = 3200 they are **67× apart**.
- **Worth saying plainly after chapters 6–8:** this is what these measurements look like when the
  tooling is not in the way. The curve separation is visible at 400 elements and unambiguous by
  3200, with no caveat about what belongs to the hack.
- **Class:** CLEAN. §10 now runs chapters 2, 3, 5, 6, 7, 8 and 9.
- **Repro:** `wat okasaki/ch09-random-access-list.wat`.


### C-059: wat's type system takes polymorphic recursion, datatype and functions both

- **Where:** `okasaki/lib/bootstrap.wat`, `okasaki/ch10-bootstrapped-queue.wat`.
- **Chapter 10's queue keeps its middle as a queue of lists:**
  ```
  Queue<A> = E | Q of int * List<A> * Queue<List<A>> * int * List<A>
  ```
  The recursive occurrence sits at a **different type instance**. That is polymorphic recursion —
  a shape many type systems refuse outright, and which the rest require explicit annotation for
  because it is not inferable.
- **wat takes the datatype**, declared exactly as above with `(:ok::BSQ :- [(:ok::GList :- [A])])`
  as a field of `(:ok::BSQ :- [A])`.
- **And it takes the functions, which are the harder half.** They are *mutually* recursive **and**
  polymorphic: `bsq-checkf` calls `bsq-head`/`bsq-tail` at `GList<A>` while `bsq-tail` calls
  `bsq-checkq` at `A`, so every level of the recursion is a different instantiation. The whole
  cycle type-checks with ordinary `:- [A]` annotations and no special pleading.
- **Verified, not just compiled:** FIFO order over 300 elements, and the queue is empty after
  draining all of them.
- **And re-verified by mutation, because "it worked first try" is not evidence.** Declaring the
  middle a queue of `A` rather than of `GList<A>` produces **5 type-check errors**, including
  exactly the nesting: *"`:ok::gcons`: parameter #2 expects `(:ok::GList :- [:A])`; got
  `(:ok::GList :- [(:ok::GList :- [:?1207])])`"*. The checking is real and it happens at the
  **function signatures**. (A weaker first demonstration only *constructed* nested values and
  would have passed even with no checking at all — that is F-103.)
- **No laziness in this chapter**, so no P-027 stand-in and no Impure carriers — every type is a
  Pure enum.
- **And the reason is not mysterious, which is worth saying.** Inferring polymorphic recursion is
  undecidable; *checking* it is easy. wat annotates every parameter and every return, so it never
  infers and never meets the hard problem. Haskell behaves the same way once you write the
  signature. The capability is real, and it is a consequence of the annotation discipline rather
  than a surprise.
- **Class:** CLEAN.
- **Repro:** `wat okasaki/ch10-bootstrapped-queue.wat`.


### C-060: the hardest type in the book — polymorphic recursion through a suspension — type-checks and runs

- **Where:** `okasaki/lib/implicit.wat`, `okasaki/ch11-implicit-queue.wat`.
- **Chapter 11 stacks three of the book's techniques in one datatype:**
  ```
  Digit<A> = Zero | One of A | Two of A * A
  Queue<A> = Shallow of Digit<A> | Deep of Digit<A> * Susp<Queue<Pair<A>>> * Digit<A>
  ```
  a **numerical representation** (the digits are a redundant binary counter, `snoc` is increment,
  the middle carries the carry — ch 9), **polymorphic recursion** (the middle is a queue of
  *pairs* — ch 10), and **laziness** (it sits behind a suspension, so a carry propagates
  incrementally rather than cascading through every level — ch 4).
- **All of it type-checks**, including the part that is genuinely hard: the recursive occurrence
  is at a different instantiation *and* behind a suspension, so the type is
  `(:ok::Susp :- [(:ok::IQ :- [(:ok::Pair :- [A])])])` inside `(:ok::IQ :- [A])`. That is the most
  demanding type in the book and wat takes it with ordinary annotations.
- **Verified rather than merely compiled:** FIFO over 300 elements, and empty after draining all
  of them — and the sibling structure's nesting was mutation-tested (C-059), so the acceptance is
  the checker agreeing rather than the checker abstaining. The one place it *does* abstain is a
  variant's constructor, which is F-103.
- **The carrier is an Impure enum for the fifth time.** `BQ`, `LCell`, `RTQ`, `DQ` and now `IQ`
  all need the one shape that may hold a suspension (containment rule) *and* shares its payload
  (F-098). Five independent structures arriving at the same undocumented requirement is a rule the
  language should be stating.
- **Class:** CLEAN. §10 is complete for the queue and list line of the book: chapters 2, 3, 5, 6,
  7, 8, 9, 10 and 11, nine programs, all green under `./run.sh okasaki`.
- **Repro:** `wat okasaki/ch11-implicit-queue.wat`.


### F-103: a parametric enum's constructor does not check its fields against the instantiated type

- **Where:** `probes/typer/parametric-ctor.wat`.
- **What happens.** `(:u::Box.B :- [:wat::core::i64] {:v "I am a String"})` — a `Box<i64>` built
  with a String — is **accepted**, and if the value never crosses a typed boundary the String
  reads straight back out:
  ```
  read out of a Box<i64>: "I am a String"      exit 0
  ```
- **The hole is construction only**, which is why it survives ordinary use — every *downstream*
  path is checked:

  | | |
  |---|---|
  | a builtin parametric type at a function boundary (`Vector<i64>` given `Vector<String>`) | ✓ refused |
  | a user parametric enum at a function boundary (`Box<i64>` given `Box<String>`) | ✓ refused |
  | reading the field through a typed accessor function | ✓ refused |
  | **the constructor itself** | ✗ **accepted** |

- **It also swallows nesting errors.** A `Nest<A>` whose field is declared
  `(Nest :- [(Vector :- [A])])` accepts a `Nest<i64>` there, and accepts a
  `Nest<Vector<String>>` where `Nest<Vector<i64>>` is required — all at construction, all silently.
- **How it was found, which is the useful part.** C-059 claims wat takes polymorphic recursion.
  The minimal demonstration I first wrote only *constructed* nested values and never passed them
  through a typed function — so it would have passed even if nothing were checked at all. Asked
  whether that was suspicious, I mutated it instead of re-asserting it, and three deliberately
  wrong programs all passed.
- **C-059 and C-060 survive the re-check, and are stronger for it.** Deliberately breaking the
  nesting inside the real structure (`okasaki/lib/bootstrap.wat`, declaring the middle a queue of
  `A` rather than of `GList<A>`) produces **5 type-check errors**, including exactly the
  mismatch: *"`:ok::gcons`: parameter #2 expects `(:ok::GList :- [:A])`; got
  `(:ok::GList :- [(:ok::GList :- [:?1207])])`"*. The polymorphic recursion is genuinely checked —
  through the **function signatures**, which is where wat does its work. It is the constructor,
  alone, that does not.
- **Which also explains why wat takes polymorphic recursion at all**, and it is not mysterious:
  inferring it is undecidable, but *checking* it is easy, and wat annotates every parameter and
  return. It never infers, so it never faces the hard problem.
- **Class:** DEFECT. Fix: check a variant's field values against the instantiated parameters at
  construction, as the function boundary already does.
- **Repro:** `wat probes/typer/parametric-ctor.wat`.


## EOPL

### C-061: EOPL's two machines port, and chapter 5 lifts F-099's ceiling by 6× and counting

- **Where:** `eopl/lib/letrec.wat`, `eopl/lib/direct.wat`, `eopl/lib/cps.wat`,
  `eopl/ch05-cps-interpreter.wat`.
- **Friedman & Wand build one language and then change only how it is executed** — chapter 3
  recurses directly on the host stack, chapter 5 defunctionalizes the continuation into a data
  structure and drives it from a loop. In a host with a growable stack that is a presentation
  choice. In wat it is not.
- **Both machines agree** on arithmetic, `let`, `proc`, `if` and `letrec`, including a 500-deep
  recursion.
- **F-099 lands on the interpreted program.** A direct-style interpreter turns the *interpreted*
  program's depth into wat's depth, so wat's silent segfault becomes a ceiling on the user's
  program:

  | non-tail interpreted recursion | direct (ch 3) | CPS (ch 5) |
  |---|---|---|
  | depth 40000 | ok | ok |
  | depth 50000 | **SEGFAULT, exit 139** | ok |
  | depth 300000 | — | **ok** |

  So chapter 5's move is not stylistic in wat: it is the difference between a ~45000 ceiling that
  fails silently and one bounded by the heap. **If you write an interpreter in wat, write the
  trampolined one.**
- **And one result that arrived by accident and is worth more than the planned one: wat's TCO is
  preserved *through* the direct interpreter.** My first test program was tail-recursive in the
  interpreted language, and the direct machine handled it at every depth I tried — because the
  interpreted tail call lands in tail position inside `value-of`, so the host collapses that frame
  too. The ceiling only exists for interpreted recursion that must *return*. I had to rewrite the
  test (putting the recursive call inside a `Diff`) before the two machines could be told apart at
  all.
- **The whole thing is Pure enums** — `Exp`, `Val`, `Env`, `Cont`, `State` — with `Val` and `Env`
  mutually recursive, since a closure captures an environment that holds closures. No suspensions,
  so none of Okasaki's Impure-carrier requirement.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch05-cps-interpreter.wat`.


### C-062: by-value, by-name and by-need, and the asymptotic price of not memoizing

- **Where:** `eopl/lib/lazy.wat`, `eopl/ch04-parameter-passing.wat`.
- **EOPL chapter 4's three parameter-passing disciplines differ in exactly one thing** — when and
  how often an argument is evaluated — so on a pure terminating program all three give the same
  answer and the difference is visible only in cost. All three agree here, on both test programs.
- **The whole difference is one function**, `:eopl::mk-thunk`: by-value evaluates now, by-name
  keeps the expression, by-need wraps it in a memoizing suspension. That makes this F-100's
  distinction seen from the language-design side: `:wat::stream::` is **by-name** (a forced
  suspension is not remembered) and P-027's `Susp<T>` is exactly what turns it into **by-need**.
- **Two programs separate all three** (depth 1200):

  | | by-value | by-name | by-need |
  |---|---|---|---|
  | argument used **twice** | 97 ms | **44 669 ms** | 147 ms |
  | argument **never used** | 93 ms | **0 ms** | **0 ms** |

  The never-used row is the textbook result. The used-twice row is **460×**, not the 2× a naive
  reading predicts.
- **Because it is asymptotic, not constant.** Measuring the cost against depth:

  | depth | by-name | by-need |
  |---|---|---|
  | 100 | 144 966 µs | 10 444 µs |
  | 200 | 726 061 | 27 289 |
  | 400 | 2 323 470 | 54 878 |
  | 800 | **10 597 030** | **172 102** |

  by-name rises **~4× per doubling — O(n²)**; by-need rises ~2× — **O(n)**. The mechanism is that
  each use of `n` re-walks the whole thunk chain back to the top, and `n` is used twice per level
  (in `zero?(n)` and in `-(n,1)`), so the work sums to O(n²). It is quadratic rather than
  exponential precisely because those two uses are at the same level rather than nested.
- **So the case for a memoizing suspension is asymptotic, not a constant factor.** P-027 has been
  measured twice now from opposite directions: C-055 showed it restores a data structure's
  persistence bound, and this shows it turns a language's parameter-passing from quadratic to
  linear.
- **The carrier rule appears again**, for the sixth time: `LVal`, `LEnv` and `LThunk` are all
  **Impure enums**, because a by-need thunk holds a suspension (containment rule) and the
  environment chain must share rather than copy (F-098).
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch04-parameter-passing.wat`.


### C-063: wat hosts a type system — unification, occurs check, and agreement with the evaluator

- **Where:** `eopl/lib/types.wat`, `eopl/ch07-type-inference.wat`.
- **The most relevant chapter in EOPL for this repository**, because wat is itself a typed
  language heading for "typed Clojure": this is wat *hosting* a type system rather than being one.
- **Type reconstruction over the unannotated syntax.** The inferencer reads the same `:eopl::Exp`
  the chapter-5 interpreters run, so the two can be cross-checked rather than trusted separately:

  | program | inferred | evaluator agrees |
  |---|---|---|
  | `-(3,2)` | `int` | ✓ |
  | `zero?(0)` | `bool` | ✓ |
  | `proc(x) -(x,1)` | `(int -> int)` | ✓ |
  | `(proc(x) -(x,1))(3)` | `int` | ✓ |
  | `letrec f(n) = … in f(5)` | `int` | ✓ |

  Every well-typed program is evaluated and its value's *shape* must match the inferred type. A
  checker and an evaluator that disagree mean one of them is wrong, and only running both says so.
- **And five rejections, because a checker that accepts everything passes every positive test:**

  | program | rejected with |
  |---|---|
  | `-(zero?(0), 1)` | *diff lhs: bool vs int* |
  | `if 1 then 2 else 3` | *if test: int vs bool* |
  | `if … then 1 else zero?(1)` | *if branches: int vs bool* |
  | `(3)(4)` | *call: int vs function* |
  | **`proc(x) (x x)`** | ***call: occurs check: infinite type*** |

  The last is the one that matters: without an occurs check that program builds an infinite type
  and the checker **loops** instead of rejecting. It is the classic omission, so it is written
  explicitly and tested.
- **One wat-specific shape worth noting.** EOPL threads fresh type-variable ids through a mutable
  counter. wat has no mutable counter outside a service, and F-051 charges 224 µs per message, so
  the counter is **threaded through the return value** — `Res` carries `(type, substitution,
  next-id)`. That is more verbose than the book and it makes `infer` a pure function, which is a
  fair trade.
- Every type is a Pure enum; substitutions are an association list, which is EOPL's own
  representation.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch07-type-inference.wat`.


### C-064: once a continuation is data, wat hosts the blocking primitive wat itself lacks

- **Where:** `eopl/lib/threads.wat`, `eopl/ch05-threads.wat`.
- **Nothing here is a defect in wat, and the lost update below is not wat's.** The racy program is
  the **toy interpreted one**, and it races by construction: I gave that toy language non-atomic
  read-modify-write (`get` and `put` as separate expressions) and a preemptive scheduler with a
  tunable time slice. A language with those two properties *must* lose updates — reproducing it on
  demand is the port working. **wat itself cannot have this bug** (C-053), which is the whole
  contrast being drawn.
- **This closes a loop across three results:**
  - **C-053** — wat's own services *cannot* lose an update. The actor serialises, so Downey's
    chapter-1 hazard is structurally unrepresentable (1600/1600 on five runs).
  - **F-102** — and wat *cannot block a caller*. `Outcome.NoReply` withholds a reply and nothing
    can ever release that caller, so every blocking primitive in wat must be a spin — C-054's
    barrier costs 18 poll round-trips for want of one.
  - **Here** — once a continuation is a **data structure**, both are trivial. A thread *is* a
    continuation, the scheduler is a queue of them, **blocking is "move this one to the blocked
    list and run someone else"**, waking is "move it back". That is fourteen lines of
    `:thr::step`, and it gives the interpreted language a real mutex while its host cannot express
    one.
- **And the hazard comes back, deliberately.** `get` and `put` are separate expressions, so a
  thread can be preempted between reading the counter and writing it — the lost update. Two
  threads, 40 increments each:

  | | time slice | counter |
  |---|---|---|
  | no lock | 1 | **40 / 80** |
  | no lock | 2 | **40 / 80** |
  | no lock | **1000** | **80 / 80** |
  | with lock | 1 | 80 / 80 |
  | with lock | 2 | 80 / 80 |

- **The `slice=1000` row is the one worth keeping.** The same *interpreted* program, carrying the
  same race, is *correct* when each thread runs to completion and *loses half its updates* when
  they interleave. Nothing about that program changed — only the scheduler I chose for it. That is Downey's whole thesis, and the
  reason a passing test proves nothing about a concurrency bug; here it is reproducible on demand
  because the interleaving is a parameter rather than a race.
- **A note on what this says about wat's design.** C-053 is a genuine strength — the actor model
  makes the hazard unrepresentable, which is better than making it detectable. F-102 is the cost
  of that same choice: no blocking primitive, so a barrier must spin. This chapter shows the third
  option, and it is the one a CEK evaluator would open up (NEXT.md's CEK notes): with the
  continuation reified, *both* properties are available at once.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch05-threads.wat`.


### C-065: a handler is a continuation frame, and installing one is nearly free

- **Where:** `eopl/lib/exceptions.wat`, `eopl/ch05-exceptions.wat`.
- **The same move as C-064, aimed at F-063.** wat's only general catch is
  `:wat::test::run-thread`, which expands to `spawn-thread-program` — **recovery in wat means
  starting a thread**. In the guest language a handler is one frame in the continuation and
  `raise` walks the chain to the nearest one.
- **Correct on all four cases:** the handler fires on a division by zero, is skipped when nothing
  raises, an uncaught raise reaches the top, and with nested handlers the **inner** one wins.
- **The cost scales the way the mechanism says it should:**

  | raise under | transitions to catch | an empty `try` |
  |---|---|---|
  | 5 frames | 27 | **4** |
  | 10 | 47 | 4 |
  | 20 | 87 | 4 |
  | 40 | **167** | **4** |

  Four transitions per frame (two to build it, two to unwind it) plus a constant — O(depth), as a
  chain walk should be. **Installing a handler costs 4 transitions whatever the program does
  afterwards**; only unwinding costs anything. wat's `run-thread`, by contrast, measured
  **1 438 671 ns per catch and is flat in depth**, because a thread spawn does not care how deep
  you were.
- **A methodological correction, recorded because I nearly published the wrong number.** My first
  version of this chapter compared *wall clock*: guest 1.13 ms per catch against wat's 2.13 ms,
  and I was about to report the guest as nearly twice as cheap. That comparison is confounded —
  the guest's wall time is **wat interpreting the guest** at ~14 µs per transition (the CEK
  measurement), so it measures the interpreter, not the exception mechanism. Transitions are the
  machine-independent number, and they are what the table above reports.
- **What it actually says:** the difference between the two is not speed, it is *shape*. A handler
  frame is something you can install for almost nothing and pay for only if it fires. A thread
  spawn is a fixed cost paid on every recovery, whether or not anything went wrong deep. That is
  the third time reifying the continuation has turned a wat limitation into a data-structure
  operation — after C-064's blocking and C-061's unbounded depth — and the same argument the CEK
  notes make for wat's own evaluator.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch05-exceptions.wat`.


### F-104: neither vector type has a positional update, and the hand-rolled route is closed off

- **Where:** `probes/vector/positional-update.wat`.
- **Replacing element *i* of a vector cannot be spelled.** Measured:

  | | |
  |---|---|
  | `(:wat::core::assoc pv 1 99)` | refused — *"expects (HashMap :- [K V]) or :wat::core::Record"* |
  | `(:wat::core::assoc vec 1 99)` | refused, same |
  | `:wat::vector::assoc` | does not exist |
  | `:wat::core::update` | does not exist |
  | `:wat::core::assoc-n` | does not exist |

  So `core::assoc` covers **HashMap** and **Record**, `map::assoc` covers **PersistentMap**, and
  **neither vector type has a positional update at all**. `:wat::vector::` is three verbs —
  `concat`, `conj`, `contains?` — so the persistent vector is effectively append-only.
- **And the hand-rolled route does not close.** The obvious construction is
  `take i ++ [x] ++ drop (i+1)`; `take` and `drop` do accept a `PersistentVector`, but they
  **answer a `:wat::stream::Stream`**, and `vector::concat` wants a `PersistentVector`. Getting
  back from a Stream needs `:wat::stream::collect` — which F-088 measured as documented and
  absent. Three findings meet: F-080 (`filterv` refuses a PersistentVector), F-088 (no way back
  from a Stream), and this.
- **It is not an exotic want.** EOPL chapter 4's store is exactly `setref(ref, value)` — an
  array-like structure updated at an index. Any interpreter, any simulation, any grid.
- **The working route is a `PersistentMap` keyed by index**, which is the *same* workaround F-057
  records for the missing persistent set ("a visited set has to be a `PersistentMap` to `true`").
  Two independent needs, one shape: **wat's structure-sharing story is map-shaped, and the vector
  is append-only.**
- **Class:** GAP. Extend: a positional update on `PersistentVector` (and `Vector`) — the single
  operation that would make it a general-purpose sequence rather than an accumulator.

- **UPDATE (found 2026-09-17, while chasing F-113): wat has already ruled on this.**
  `docs/COLLECTION-CAPABILITIES.md` — an internal capability grid, not a user-facing page —
  carries a **BUILD queue** whose item 3 is *"Index-assoc — `assoc`-by-index on Vector/PV/
  WatAstList (homogeneous, bounds-checked)"*, and its rulings table resolves
  *Vector/assoc, PV/assoc, WatAstList/assoc* as **✓ BUILD (assoc-by-index)**, grounded
  *"homogeneous → type-preserving, bounds-checked; the immutable element-update verb"*, dated
  2026-06-20. So this finding is not a request for a decision — the decision is made and the
  work is queued. What this repository adds is the **priority evidence**: nine independent
  workloads have now routed around its absence (C-086 lists them, plus the lox chunk patch and
  the VM stack). Meanwhile the USER-GUIDE container table still reads ***illegal** (arc 146)*
  for `Vec`/`assoc`, with no note that it is coming — which is the same gap between the
  internal doc and the user-facing one that F-113 and F-109 record.
- **Repro:** `wat probes/vector/positional-update.wat`; the refused forms are in its comments.


### C-066: EOPL's store ports, and in wat the pure way to hold state is also the fastest

- **Where:** `eopl/lib/refs.wat`, `eopl/ch04-explicit-refs.wat`.
- **Chapter 4's EXPLICIT-REFS ports** — `newref`, `deref`, `setref` over a store, with the store
  **threaded** rather than mutated so the interpreter stays a pure function. All three checks
  pass: a ref round-trips, two refs stay independent, and 200 increments driven through the store
  land on 200.
- **The store has to be a `PersistentMap` keyed by index**, because wat has no positional update
  on either vector type (F-104) — the same shape F-057 forces on a visited set.
- **And the chapter answers a question every wat program eventually asks.** There are three ways
  to hold mutable state in wat, and they are two orders of magnitude apart:

  | | ns per read-modify-write |
  |---|---|
  | **threaded `PersistentMap`** (pure — no handles, no messages) | **10 610** |
  | `:wat::cache::Lru` (the one mutable cell wat exposes) | 35 034 — **3.3× slower** |
  | a service | ~448 000 — **42×** (two messages at F-051's measured 224 µs; derived, not re-run) |

- **The pure option wins, which is worth stating plainly** because it is the opposite of the
  instinct a systems programmer brings. Threading a `PersistentMap` beats the mutable cell by
  3.3×: `Lru::get` answers an `Option` (allocate, then match), `Lru::put` crosses into a Rust
  shim, and the LRU's recency machinery runs on every access whether or not it can ever evict —
  the same overhead P-027 records.
- **So in wat the functional choice is also the fast choice**, and the ordering is
  threaded → cell → service, each step about 3× and then 13× worse. C-063 noticed this in passing
  while threading a type-variable counter; this measures it.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch04-explicit-refs.wat`.


### C-067: EOPL's CHECKED, and why a checker catches what an inferencer cannot

- **Where:** `eopl/lib/checked.wat`, `eopl/ch07-checked.wat`.
- **This entry exists because of a correction.** I reported chapter 7 as done having built only
  INFERRED (C-063) — half of it. EOPL pairs a **checker** with an **inferencer** deliberately, and
  the pairing is the lesson. The builder's ruling on 2026-09-16 — *"the cost of duplication is
  worth coverage of the books; I'd rather not have omissions"* — is what surfaced it, and a full
  audit of §9 found **14 outstanding items**, several inside chapters I had called done.
- **CHECKED has no unification and no type variables.** Types are declared and compared for
  equality, which makes it the simpler algorithm and the stricter tool.
- **Correct on the annotated programs**, and it rejects the class of error that matters:

  | | |
  |---|---|
  | `proc(x : bool) -(x,1)` | REJECTED — *diff lhs: expected int, got bool* |
  | `letrec bool f(n : int) = -(n,1)` | REJECTED — *letrec body: expected bool, got int* |
  | `(proc(x : int) x)(zero?(0))` | REJECTED — *call argument: expected int, got bool* |

- **And the reason the book ships both, in one line:**

  | | `proc(x : bool) -(x,1)` |
  |---|---|
  | CHECKED | **REJECTED** — *diff lhs: expected int, got bool* |
  | INFERRED, same shape unannotated | **accepted as `(int -> int)`** |

  The inferencer is not wrong — `(int -> int)` *is* the type of that function. It simply has **no
  annotation to disagree with**, so it cannot catch a programmer who wrote down the wrong type.
  Inference checks a program against itself; checking tests it against what its author *believed*.
- **Which is the model wat itself uses**, and worth having demonstrated before the typed-Clojure
  work: wat annotates every parameter and every return and never infers (C-059's note on why
  polymorphic recursion comes free). This chapter is the small version of what that discipline
  buys — not internal consistency, which inference also gives, but disagreement with the author.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch07-checked.wat`.


### C-068: EOPL's IMPLICIT-REFS and CALL-BY-REFERENCE, and how small the calling convention actually is

- **Where:** EOPL chapter 4, `eopl/lib/implicit.wat` + `eopl/ch04-implicit-refs.wat`.
- **What the chapter is:** EXPLICIT-REFS (already built, `eopl/lib/refs.wat`) makes references a
  *value* the programmer allocates with `newref` and reads with `deref`. IMPLICIT-REFS moves the
  reference behind the curtain: **every variable is bound to a reference**, a bare `Var` is a
  dereference, and `set x = e` assigns through the cell. The programmer never writes `deref`.
  That is the calling convention of nearly every language anyone actually uses.
- **The result that makes the chapter worth building** — one program, two conventions:

  ```
  let x = 0 in
    let f = proc(y) set y = 99 in
      ((f x); x)
  ```

  | | result |
  |---|---|
  | by value | **0** |
  | by reference | **99** |

  and, when the argument is an *expression* rather than a variable:

  | | result |
  |---|---|
  | by value | 99 |
  | by reference | 99 |

  The second row is the interesting one. Call-by-reference can only differ when there is
  something to alias; a non-variable argument has no cell of its own to share, so both
  conventions must agree. The two rows together are the definition — not the first row alone.
- **How much code the switch is:** the whole of the call-by-reference decision is one predicate —
  *is this argument expression a bare variable?* If yes, pass its existing cell index; if no,
  allocate a fresh cell. Everything else in the interpreter is shared between the two modes.

  ```wat
  (:wat::core::defenum :imp::Strategy :wat::enum::Pure
    :ByValue [] :ByReference [])
  ```

  A calling convention reads, in the literature and in most people's heads, like a deep property
  of a language. Written out it is a two-variant enum and one question asked at one call site.
- **Nothing here is a defect in wat.** The interpreter implements assignment, aliasing and a
  mutable store in a language that has no mutation — the same shape as the mutex in C-064. The
  store is threaded as a value (`st`, `next`) through every evaluation arm and returned in the
  answer; that is what a language without mutation forces, and it is also exactly the fourth
  component a CEK machine carries. This is the third EOPL language whose implementation *already
  has the shape* the long-term CEK work wants (with `eopl/lib/cps.wat` and `eopl/lib/threads.wat`).
- **One wat friction re-hit, strengthening an existing row:** the store is a
  `PersistentMap<i64,i64>` and not a vector, because **F-104** — neither vector type has a
  positional update. A store indexed by a dense integer counter is the textbook vector use, and
  it is the fourth workload in this repository to route around F-104 the same way.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch04-implicit-refs.wat`.

### C-069: EOPL's MUTABLE-PAIRS — aliasing is free once a store exists

- **Where:** EOPL chapter 4, `eopl/lib/mutpairs.wat` + `eopl/ch04-mutable-pairs.wat`.
- **What the chapter is, and why it is short:** a mutable pair is **two adjacent cells** in the
  store the previous language already had. `newpair` allocates `n` and `n+1` and the pair's
  *value* is the index `n`. `left`/`right` fetch; `setleft`/`setright` assign. No new store
  machinery, no new value kind. EOPL's point is deflationary and it survives the port intact.
- **What the port demonstrates** (all five rows PASS):

  | program | result |
  |---|---|
  | `left(newpair(3,4))` | 3 |
  | `right(newpair(3,4))` | 4 |
  | `let p = newpair(1,2) in let q = p in (setleft q 99; left p)` | **99** — aliased |
  | same, but `q` is a *second* `newpair(1,2)` | **1** — not aliased |
  | `let p = newpair(7,8) in (setright p 99; left p + right p)` | 106 — two real cells |

  Rows 3 and 4 are the pair: identical-looking pairs alias when one *name* was copied and do not
  when the *pair* was rebuilt. Row 5 rules out a one-cell implementation with a tag.
- **The connection to wat's own containers:** this is precisely the distinction wat already draws
  between `PersistentVector`/`PersistentMap`, which **share**, and `HashMap`/`HashSet`, which
  **copy** (C-023, F-057). The interpreter has to reproduce sharing *on top of* a persistent
  store, and it does it the way EOPL does — by passing around an **index**, not a value. A
  language without mutation can express aliasing exactly when it is willing to make the
  indirection explicit, which is the same trade the reader is being taught.
- **Nothing here is a defect in wat.** Chapter 4 is now complete: EXPLICIT-REFS (`refs.wat`),
  IMPLICIT-REFS and CALL-BY-REFERENCE (C-068), MUTABLE-PAIRS.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch04-mutable-pairs.wat`.


### C-070: EOPL's CPS transformation — the only place a source-to-source rewrite can be *measured* against a hard ceiling

- **Where:** EOPL chapter 6, `eopl/lib/cps6.wat` + `eopl/ch06-cps-transform.wat`, ladder in
  `probes/eopl/cps6-depth.wat`.
- **What the chapter is:** chapter 5 changed the *machine* and left the program alone. Chapter 6
  does the opposite — it rewrites the **program**, source to source, so that any interpreter at
  all, including the naive direct one, runs it in constant stack.
- **The experiment wat makes possible.** In Scheme this claim is a theorem you take on faith,
  because the host stack grows. wat has a hard ceiling to hit (**F-099**: a non-tail recursion
  segfaults, empty stderr). So: **one** interpreted program, `sum(n) = n + sum(n-1)` with the
  recursive call in an operand position, under **one** interpreter (`eopl/lib/direct.wat`), before
  and after `cps-of-program`:

  | n | as written | after the transform |
  |---|---|---|
  | 1000 / 5000 / 10000 / 20000 | ok, 500500 … 200010000 | ok, **same answers** |
  | 25000 | **SEGFAULT** (rc 139) | ok |
  | 30000, 35000 | SEGFAULT | — |
  | 40000 | SEGFAULT | ok, 800020000 |
  | 60000, 100000 | — | ok, 5000050000 |

  Same interpreter, same program, same answers at every shared depth. The transform moves the
  ceiling by at least 4× and the CPS arm was still green where the ladder stopped.
- **Two corrections I had to make to my own instrumentation before the claim was honest:**
  1. "Every call becomes a tail call" is **false in this encoding, and I published the number that
     shows it**: `nontail` is 1 on the source and **2** on the output. LETREC's procedures take
     one argument, so the continuation must be **curried** — `((f a) k)` — and the inner `(f a)`
     is a genuine non-tail call, one per call site. EOPL's target language has multi-argument
     procedures and does not pay this.
  2. A first attempt to rescue the claim counted "non-tail calls with a non-simple operator or
     operand" and answered **6**, not 0 — it ignored tail position and flagged the curried spine
     itself. It measured the wrong thing and was deleted rather than tuned.

  The property that actually holds is a **grammar**: every operator and every operand is a
  *SimpleExp*, so evaluating one can never re-enter the program, and the only nested call is the
  curried spine whose inner application returns a closure immediately. `violations` counts
  departures — **2 on the source, 0 on the output**. The source is its own negative control.
  - And a third correction inside that: my first `simple?` excluded primitive applications, and
    reported the transform's **own output** as ungrammatical (4 violations, coincidentally equal
    to the source's 4). EOPL's SimpleExp is "cannot diverge, cannot call a procedure", which
    **includes** `-(x,y)` and `zero?(x)` over simple operands. Dumping the term found it:
    `(proc(%halt) %halt) -(v%0,v%1)` — an operand that is a `Diff`.
- **What the transform costs:** the `if` case duplicates the continuation into both arms, so a
  17-node source becomes a **61-node** output (3.6×). That is the code blow-up EOPL warns about
  and the reason a real compiler binds `k` to a name first.
- **Nothing here is a defect in wat.** This is the fourth EOPL chapter whose port is a controlled
  experiment *because* of an existing wat limitation rather than in spite of it.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch06-cps-transform.wat`; ladder `wat probes/eopl/cps6-depth.wat direct 25000`.

### F-105: registerizing a machine costs ~1.9× in wat, because `step : State -> State` must allocate the state it returns

- **Where:** EOPL chapter 6.5, `eopl/lib/regz.wat` vs `eopl/lib/cps.wat`; measured by
  `probes/eopl/regz-cost.wat`.
- **Why this matters beyond the book:** the long-term wat goal is a **CEK evaluator**, and the
  obvious shape for one is exactly the registerized shape — an explicit machine state and a
  `step` function driven by a trampoline. That is the shape this repository already wrote
  (`eopl/lib/cps.wat`) and the shape EOPL argues toward. **It is the slower of the two.**
- **The two shapes, same continuations, same interpreted program:**
  - *registerized* — `step : State -> State` plus a trampoline (`:eopl::run`);
  - *before registerization* — `value-of-k` and `apply-cont` **mutually tail-calling** (`:rz::run`).
- **Measured** (min of 5 per arm, answers AGREE at every size):

  | n | registerized (`step`/`drive`) | mutual tail calls | ratio |
  |---|---|---|---|
  | 200 | 61721 µs | 33306 µs | **1.85×** |
  | 1000 | 329577 µs | 178828 µs | **1.84×** |
  | 4000 | 1472878 µs | 756546 µs | **1.95×** |

  **Order control** — the registerized arm runs first in every row above, so the rows were re-run
  with the arms swapped. The gap survives and widens slightly: n=200 **35446 µs mutual first vs
  72817 µs registerized second (2.05×)**; n=1000 **179146 vs 356000 (1.99×)**. It is the
  allocation, not the ordering.
- **The mechanism:** `step` has to *return* the next state, so every transition allocates a
  `State` enum value that is immediately destructured and discarded by `drive`. The mutually
  recursive form allocates nothing — it passes the same three components as arguments and tail
  calls. One enum allocation per transition is the whole difference.
- **And registerization is not forced here**, which is what makes it a cost rather than a
  necessity: `probes/eopl/mutual-tco.wat` shows wat's TCO spans **mutual** tail calls, not only
  self-calls — `ping`/`pong` survive **n=10,000,000**, the same ceiling as a self-call. Many
  implementations optimize only self-calls; wat does not, and that is worth knowing on its own.
- **So:** if the CEK work adopts `step : State -> State` it should do so for the reasons that
  actually favour it — the state is inspectable, serialisable, and steppable from outside, which
  is what made C-064's scheduler and C-065's handler frames possible — and not for speed, where
  it is about 1.9× behind the shape it replaces. Whether that gap survives an allocation-free
  representation of `State` is the open question; nothing here shows it is inherent.
- **Class:** IMPROVE.
- **Repro:** `wat probes/eopl/regz-cost.wat`, `wat probes/eopl/mutual-tco.wat 10000000`.


### C-071: EOPL's SIMPLE-MODULES and OPAQUE-TYPES — abstraction that a checker enforces

- **Where:** EOPL chapter 8, `eopl/lib/modules.wat` + `eopl/ch08-modules.wat`.
- **What the chapter is:** a module has an **interface** (what the outside may see) and a **body**
  (what is actually there), and the type checker enforces the gap. The sharpest version is an
  **opaque** type: inside the body `t` *is* `int`; outside, `t` is a name and nothing more.
- **The result, one module, two interfaces differing in a single word:**

  | expression | `opaque t` | `transparent t = int` |
  |---|---|---|
  | `from ints take zero` | ACCEPTED : `ints.t` | ACCEPTED : `ints.t` |
  | `-(from ints take zero, 1)` | **REJECTED** — *diff lhs: expected int, got ints.t* | **ACCEPTED** : `int` |
  | `(succ 0)` — smuggling a raw int in | **REJECTED** — *argument: expected ints.t, got int* | **ACCEPTED** : `int` |
  | `(succ zero)` | ACCEPTED : `ints.t` | ACCEPTED |
  | `(to-int (succ zero))` | ACCEPTED : `int` | ACCEPTED |

  The last two rows are the positive control that matters: abstraction **hides, it does not
  forbid**. The module's own operations keep working on its own values, and `to-int` is the
  deliberate hole the interface chose to leave. A checker that rejected those too would be
  rejecting everything, and the table would prove nothing.
- **And the interface is a promise checked at the seal, not at the use:** a module whose interface
  names `missing : int` is rejected as *"interface promises missing the body never defines"* even
  though nothing ever refers to it. `from ints take nope` is likewise *"interface does not export
  nope"* however plainly the body defines a name.
- **How sealing is done:** the body is checked under a view where the module's own `type t = int`
  is **transparent** — the implementation is allowed to know — and the outside then gets the
  declared interface, where `opaque t` hides it again. `expand` unfolds a transparent name and
  refuses to unfold an opaque one, and that single asymmetry is the whole of type abstraction.
- **8.4, parameterized modules (ML's functors), and the sharpest row in the chapter.** A
  module-proc taking any module that exports `zero : int` and `succ : (int -> int)` is checked
  **once, against the parameter's interface** — not once per application. Then:

  | | result |
  |---|---|
  | the functor's own body | **well typed** |
  | the `transparent` module satisfies the requirement | **well typed** |
  | the `opaque` module | **REJECTED** — *interface promises zero : int but the body has ints.t* |

  Same body, same definitions, the same integer underneath. The seal alone decides. That is the
  cost of abstraction stated as a type error rather than as prose, and it is also why `to-int`
  exists in the interface: a sealed module has to hand out a way back or it can satisfy nothing.
- **A bug of mine that the table caught.** The first run rejected the *transparent* module too,
  with the same message. `satisfies?` compared types without the argument module in scope, so
  `ints.t` could not be expanded and every requirement failed for the wrong reason — a checker
  that rejects both arms proves nothing. Binding the module's **sealed interface** (never its
  body) before comparing is the fix, and the opaque/transparent split then appears.
- **Nothing here is a defect in wat.** But it is the chapter NEXT.md flagged as closest to wat's
  own design, and the port says exactly what wat has and lacks — see **F-106**.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch08-modules.wat`.

### F-106: `newtype` gives nominal distinctness but not sealing — the constructor and the `/0` accessor are public to every namespace

- **Where:** EOPL chapter 8's opaque types (C-071) asked what the wat spelling would be. Also the
  cost already noted under The Little MLer ch 10's functor ("ML's opaque `:>` has no counterpart
  here"), now measured rather than asserted.
- **What wat has.** `:wat::core::newtype` is real and it does the *distinctness* half properly —
  both directions, checked at startup (2026-09-16, wat-rs `a3218644d`):
  - `(:wat::core::- (:ints::zero) 1)` where `zero : ints::T` →
    *"no clause of `:wat::core::-` matches arity 2 with types [:ints::T, :wat::core::i64]"*;
  - `(:ints::succ 41)` where `succ` takes `ints::T` →
    *":ints::succ: parameter #1 expects :ints::T; got :wat::core::i64"*.

  That is exactly EOPL's `opaque t` behaviour for arithmetic, and better than a `typealias`, which
  is transparent in both directions (measured: arithmetic through the alias answers `-1`, and a
  raw `41` is accepted where the alias is wanted).
- **What wat lacks.** The representation is **public**. `newtype` auto-mints a constructor at the
  bare type name and an accessor at `<Name>/0` (`src/declare/register.rs:1554-1580`, mirroring
  Rust's tuple-struct `.0`), and **both resolve from any other namespace**:

  ```
  (:wat::core::newtype :ints::T :wat::core::i64)
  (:wat::core::defn :ints::zero [] -> :ints::T (:ints::T 0))
  ;; from :user::, a DIFFERENT namespace:
  (:ints::T/0 (:ints::zero))            => 0        ; unwrapped
  (:ints::T/0 (:ints::T (+ 41 1)))      => 42       ; and rewrapped
  ```

  So any caller can open the box and build a fresh one. EOPL's `opaque t` means the outside gets
  **no constructor and no accessor** — the type is a name it can pass around and nothing else.
  wat has no way to spell that: there is no visibility marker for a user type's representation,
  and a namespace in wat is a keyword prefix, not a boundary.
- **The gap, precisely:** distinctness without encapsulation. `newtype` stops a caller
  *confusing* `ints::T` with `i64`; it does not stop them *depending on* `ints::T` being an
  `i64`, which is the invariant a library actually needs when it later wants to change the
  representation.
- **And it is effectively undocumented**, which is the F-065 / F-076 shape: `newtype` appears
  **twice** in `USER-GUIDE.md` and both are bare entries in lists of form names; **zero** times in
  the cheatsheet, the rosetta and SERVICE-PROGRAMS; `:wat::core::newtype` appears in a docs code
  example **zero** times; and the `/0` accessor — the only way to get the value back out — is
  named **zero** times in any doc. I recovered it from `register.rs`.
- **Related and still open:** **F-030**, re-verified today — printing a newtype still panics the
  Rust runtime (`value.rs:328`, exit 2), because the field is named `0` and EDN rendering makes a
  keyword of it. A type you cannot print is a hard thing to seal *or* to use.
- **Class:** EXTEND (a way to seal a representation), with a CLEAN half (document `newtype` and
  its `/0` accessor at all).
- **Repro:** `wat eopl/ch08-modules.wat` for the language-level contrast;
  `probes/scalar/newtype-seal.wat` for the wat-level probe.


### C-072: EOPL's CLASSES — the two mechanisms that make OO more than records-with-functions, separated by numbers

- **Where:** EOPL chapter 9, `eopl/lib/classes.wat` + `eopl/ch09-classes.wat`.
- **The book's own c1/c2 example, chosen because it distinguishes the two mechanisms with results
  rather than prose:**

  ```
  class c1                        class c2 extends c1
    field x                         field y
    initialize() set x = 11         initialize() begin super initialize(); set y = 12 end
    m1() x                          m1() -(x, -(0,y))     ; override: x + y
    m2() send self m1()             m3() super m1()       ; the PARENT's m1
  ```

  | call | result |
  |---|---|
  | `c1.m1` / `c1.m2` | 11 / 11 |
  | `c2.m1` — the override | **23** |
  | `c2.m2` — **c1's code**, which must find **c2's** m1 | **23** |
  | `c2.m3` — **c2's code**, which must find **c1's** m1 | **11** |

  The last two rows are the whole chapter. Both are `m1`, both on the same object; they differ
  only in **where the walk up the class chain starts**. An interpreter carrying only `self` gets
  m2 right and m3 wrong; one dispatching statically gets m3 right and m2 wrong. So the evaluator
  carries `self` **and** `curclass`, and a method runs with `curclass` set to the class that
  *owns* it rather than the object's.
- **Objects are MUTABLE-PAIRS generalised** (C-069): an object is a class name plus a **base
  index**, and field *k* lives at `base + k`. Inherited fields are listed **first**, so c1's `x`
  is still index 0 in a c2 instance and an inherited method's field access stays valid in the
  subclass. That layout rule is why chapter 4's store had to exist before this chapter could.
- **Nothing here is a defect in wat.** This is the fourth interpreted language in this repository
  to implement mutation on a host that has none, by threading the store as a value.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch09-classes.wat`.

### C-073: EOPL's TYPED-OO — the first type rule here that is not an equality, and how much of it wat already has

- **Where:** EOPL chapter 9.4–9.5, `eopl/lib/typedoo.wat` + `eopl/ch09-typed-oo.wat`; the wat
  half in `probes/oo/surface-subtyping.wat`.
- **What is new over chapter 7's CHECKED (C-067):** **subsumption**. Every rule in this repository
  up to here compared types for *equality*; this one accepts a **subtype**. Everything
  interesting follows from that relation being one-way.

  | | result |
  |---|---|
  | `c2` where `c1` is wanted | **ACCEPTED** |
  | `c1` where `c2` is wanted | **REJECTED** — *parameter expects c2, got c1* |
  | `c2` where the interface `summable` is wanted | **ACCEPTED** |
  | `c1` where `summable` is wanted | **REJECTED** |
  | `c2.m3` (declared on c2) / `c2.m2` (inherited) | ACCEPTED / ACCEPTED |
  | `c1.m3` — only c2 has `m3` | **REJECTED** — *no method m3 on c1* |
  | **`summable.m3`, where the value is a `c2` that really does have `m3`** | **REJECTED** — *no method m3 on summable* |

  The last row is the one worth keeping. The receiver's run-time value *is* a `c2`, and the call
  *would* work; the checker refuses because a `send` is checked against the **static** type. That
  is the same shape as C-071's opaque types — the **declared** view rather than the actual one —
  and it is what soundness over subtyping costs.
- **And wat already has half of this, which I expected to be a gap and is not.** `defsurface` +
  `extend-type` give interface subtyping, measured rather than assumed:
  - a parameter typed at the surface takes either concrete implementation (**25**, **10**);
  - a **single collection** typed `(Vector :- [(Shape :- [i64])])` holds two *different* concrete
    types (length **2**);
  - and dispatch through it works — summing `area 5` over the heterogeneous vector gives
    **35 = 25 + 10**. That is exactly the dynamic dispatch chapter 9 builds by hand.
- **What wat does not have, also measured:** concrete-to-concrete subtyping. Two *structurally
  identical* structs are not interchangeable —
  *":s::take-a: parameter #1 expects :s::A; got :s::B"* — and there is no `extends` on a
  `defstruct` or `defrecord`. So there is no implementation inheritance, no method override and
  no `super`.
- **So, as a design observation rather than a gap:** wat has the **interface** half of chapter 9
  and denies the **inheritance** half. "Program to an interface, not an implementation" is the
  standard advice about this chapter's machinery; in wat it is not advice, it is the only thing
  the type system will let you write. Worth stating plainly because the gap-shaped question —
  *"wat has no classes, so what breaks?"* — has the answer *nothing that this chapter is for*.
- **Class:** CLEAN.
- **Repro:** `wat eopl/ch09-typed-oo.wat`; `wat probes/oo/surface-subtyping.wat`.


### C-074: EOPL's chapters 1-3 — follow the grammar, one client against three representations, and an increment that is a type fact

- **Where:** `eopl/ch01-inductive-sets.wat`, `eopl/ch02-data-abstraction.wat`, `eopl/ch03-let-and-proc.wat`. **These close the book: 22 of 22.**
- **Chapter 1** is the *follow the grammar* discipline: one clause per production, recur exactly
  where the grammar recurs. `occurs-free?` over `Lc-exp`, and `list-length` / `nth-element` /
  `remove-first` / `subst` over `List-of-Int`, all agreeing with the book.
  - **Why it is short in wat, and worth saying:** an inductive definition **is** a `defenum`, and
    "one clause per production" **is** an exhaustive `match`. The checker rejects a missing clause
    (and this repository bans `_`), so the chapter's central advice is enforced rather than
    remembered. `nth-element` out of range answers an `Option` rather than guessing, which is
    EOPL 1.2.2's insistence on *reporting* with a type behind it.
- **Chapter 2** is representation independence: one client, three environments — an association
  list, a **ribcage** (parallel name/value vectors per frame), and a **procedure**. All nine rows
  pass: `x` shadowed to 99, `y` at 20, an unbound name reporting -1, through each representation.
  - The third is the one worth the trip: the environment has **no data structure at all**. It is a
    closure `[String :-> i64]`, and `extend` returns a new closure that shadows the old. The
    dictionary's type parameter is instantiated at a **function type**, so the chapter's punchline
    survives the port intact.
- **But the chapter's natural wat encoding does not work, and that is the finding.** A parametric
  surface with three `extend-type` implementations and one generic client is refused at every call
  site — **F-029, third independent sighting** (The Little MLer ch 10, A Little Java's visitor,
  now EOPL ch 2). Kept verbatim as `probes/eopl/ch02-surface-blocked.wat`, because a chapter whose
  entire subject is representation independence is the sharpest demonstration of what F-029 costs.
  - **New over the two earlier sightings:** adding a second argument of type `R` does **not**
    rescue it. `[d <- (:c2::Env :- [R]) seed <- R]` is refused the same way, so the variable is
    not resolved from elsewhere in the signature — the surface argument itself has to pin it, and
    it cannot.
  - The working route is the one F-029 already names: a **dictionary**, a generic struct of
    functions (C-023). The client is still written exactly once.
- **Chapter 3** builds LET and PROC as the *separate* languages the book presents, rather than
  jumping to LETREC (C-061). PROC adds **two productions** to the syntax and **one variant** to the
  value domain — and that one variant is the whole cost, because it is what makes `Val` and `Env`
  mutually recursive: a closure captures an environment that holds closures. Lexical capture is
  checked rather than assumed (rebinding `x` after the `proc` is built leaves the result at 100).
  - **The wat observation worth keeping:** in Scheme, "LET has no procedures" means the
    interpreter has no clause for one and a program containing one is *rejected*. In wat
    `:l3::Exp` has no `Proc` variant, so such a program **cannot be built**. The ill-formed
    program is unrepresentable rather than refused — the increment between two languages is a
    **type** fact, and the enum is the grammar.
- **Class:** CLEAN (the ports), with F-029 and F-107 recorded against the route not taken.
- **Repro:** `wat eopl/ch01-inductive-sets.wat`, `wat eopl/ch02-data-abstraction.wat`,
  `wat eopl/ch03-let-and-proc.wat`.

### F-107: a generic struct's type parameter is bound from its FIRST field, a bare variant literal binds it to the variant, and an explicit type argument at the construction site is silently discarded

- **Where:** found building C-074's chapter 2 dictionary — a generic struct holding a value of `T`
  and a function over `T`, which is the commonest shape a dictionary takes.
- **The repro** (`probes/scalar/generic-param-inference.wat`, wat-rs `a3218644d`, 2026-09-16):

  ```wat
  (:wat::core::defenum :p::E :wat::enum::Pure :A [] :B [n <- :wat::core::i64])
  (:wat::core::defstruct :p::Ops :- [T] [seed <- T  step <- [T :-> T]])
  (:wat::core::defn :p::mk [] -> (:p::Ops :- [:p::E])
    (:p::Ops :seed (:p::E.A {})
             :step (:wat::core::fn [x <- :p::E] -> :p::E x)))
  ```
  > `:p::Ops: parameter #2 expects [:p::E.A :-> :p::E.A]; got [:p::E :-> :p::E]`

- **Three separate problems, in order of how much they matter:**
  1. **The explicit type argument is parsed and discarded.** `(:p::Ops :- [:p::E] :seed …)` fails
     with the identical message — and so does `(:p::Ops :- [:wat::core::i64] :seed …)`, a
     **deliberately wrong** one. Nothing the author writes at the construction site changes the
     inferred parameter, and nothing warns them. An annotation with no effect and no diagnostic is
     worse than one that is rejected, because the author reasonably believes they have pinned it.
  2. **A bare enum-variant literal binds the parameter to the VARIANT type**, `:p::E.A`, not to
     its enum. Everywhere else a variant flows into an enum-typed position without comment; here
     it narrows the parameter and poisons every other field.
  3. **The enclosing function's declared return type does not pin it.** `-> (:p::Ops :- [:p::E])`
     is right there and is not consulted; binding is bottom-up from the fields, in declaration
     order, and the first field wins.
- **And the diagnostic blames the wrong field.** It reports `parameter #2` — the `step` closure,
  which is the field the author wrote *correctly* — rather than `seed`, where the parameter was
  bound too narrowly. Someone reading only the error will go and change the correct field.
- **Two things that work**, both accidents of ordering rather than anything a user reasons their
  way to: route the value through a function with a **declared return type**
  (`(:p::empty)` where `:p::empty [] -> :p::E`), or **declare the function field first** so `T` is
  pinned from its annotation before the variant literal is seen. Same struct, same values,
  different field order.
- **Why this one is worth prioritising.** wat is LLM-first, and its case for that is that
  annotations are written everywhere and mean something. This is an annotation that is accepted,
  ignored, and never reported — the same family as **F-093**, and the sort of thing a generator
  cannot discover by reading its own output.
- **Class:** FIX (the discarded type argument and the misdirected diagnostic), with an IMPROVE half
  (consult the declared return type, and widen a variant literal to its enum).
- **Repro:** `wat probes/scalar/generic-param-inference.wat`; the refused shapes are recorded in
  its header, each having been a separate single-file run.


### C-075: Okasaki chapter 4 — the incremental/monolithic distinction, measured as a count rather than a clock

- **Where:** `okasaki/ch04-lazy-evaluation.wat`. **Found by a coverage audit**, 2026-09-16: this
  was the one omission inside a suite the status table already called *complete*. The library was
  there — `okasaki/lib/llist.wat` has `take`, `drop`, `append` and `reverse` — but the chapter
  that states and **checks** their defining property had never been written. Every later chapter's
  header cites "ch 4 LAZINESS"; nothing had ever tested it. Same shape as EOPL ch7's CHECKED.
- **What chapter 4 is, and why the rest of Part II rests on it:**
  - **incremental** — every forcing does O(1) work and hands back another suspension (`++`, `take`);
  - **monolithic** — the *first* forcing does all the work at once (`drop`, `reverse`).

  Amortization by lazy evaluation only works when the expensive operation is **incremental**,
  because the debt has to be payable a little at a time. That is why the banker's queue (ch 6) may
  defer a rotation, and why a monolithic `reverse` must be paid for in advance.
- **Measured by observation, not by clock.** `:ok::forced?` reports whether a suspension has been
  paid for, so "how much of the list did this touch?" is a **count** — the same number on any
  machine, which is the discipline C-065 had to be rewritten to follow. `s = [1 2 3 4 5]`, six
  cells counting the nil, each its own suspension:

  | after | cells forced |
  |---|---|
  | built, untouched | **0** of 6 |
  | `head(s ++ t)` | **1** — incremental |
  | consuming both elements of `take s 2` | **2** — incremental |
  | `head(drop s 3)` | **4** — monolithic |
  | `head(reverse s)` | **6** — monolithic, the whole list |

  Every row is a prediction the chapter makes, and every one held. The 1-vs-6 contrast between
  `++` and `reverse` on the same list is the chapter in a single line.
- **And sharing, which is the property the whole scheme needs:** traversing the list a second time
  forces **nothing new** — 6 after the first traversal, 6 after the second. That is exactly what
  `:wat::stream::` deliberately does *not* do (**F-100**: three forces of one value ran the
  suspension three times, the Ruby `Enumerator` pattern), and it is the whole reason **P-027** asks
  for a separate `Susp<T>` rather than for streams to change.
- **This file is also the third argument for P-027's shape.** `forced?` is not a convenience: it is
  the only reason the table above can be written at all. A real suspension primitive has to expose
  *delay*, *force* and **observably-forced**, or incrementality cannot be tested — only timed, and
  timing it is what C-065 got wrong once already.
- **Nothing here is a defect in wat.** The stand-in (`:wat::cache::Lru` at capacity 1, P-027) is
  the wrong vehicle and its header says so; the chapter's behaviour is right regardless.
- **Class:** CLEAN.
- **Repro:** `wat okasaki/ch04-lazy-evaluation.wat`.


### C-076: SICP chapter 1 — and the two places wat makes the book's own claims *observable* rather than diagrammatic

- **Where:** `sicp/ch11-elements.wat`, `sicp/ch12-processes.wat`, `sicp/ch13-higher-order.wat`,
  against new guile oracles (`oracle/sicp/ch1*.scm`). **13 + 27 + 20 = 60 results, every one
  matching guile in order.** Written after the builder ruled for full coverage over probe-driven
  sampling: *"prove we handled all of the books' various nuance, not just arguing 'meh, they're
  the same'"*.
- **§1.2.1's central claim stops being a diagram.** SICP says two procedures computing the same
  function can generate different *processes* — one accumulating deferred operations, one not —
  and in Scheme that difference never shows in the answers. wat has a ceiling, so it shows
  (`probes/sicp/process-shape-depth.wat`, both arms computing `sum(1..n)`, each rung its own
  process):

  | n | linear recursion | linear iteration |
  |---|---|---|
  | 100000 | ok, 5000050000 | ok, 5000050000 |
  | 200000 | **SEGFAULT** (rc 139, F-099) | ok |
  | 1000000 / 10000000 | — | ok, ok |

  The two are not two styles here; they are two different programs at depth. That is §1.2.1
  stated as a fact about the machine.
- **§1.1.8's block structure has an exact boundary in wat, and it falls at recursion.** SICP nests
  `good-enough?`, `improve` and `iter` inside `sqrt` so they share `x` without passing it. In wat
  the two **non-recursive** helpers genuinely can be internal — let-bound closures capturing `x`,
  neither taking it as a parameter, which is the whole of what block structure buys. The
  **recursive** one cannot: a let-bound closure has no name to call itself by (**F-007**, and
  **F-054** asks for the fix), so `iter` is lifted to the top level and `x` is threaded by hand.
  Both versions are in `ch11-elements.wat` so the difference is one thing and visible. The same
  boundary reappears in §1.3's `fixed-point`, whose internal `try` has to be lifted too.
- **F-038, fourth sighting, and it lands on the one chapter whose subject is procedures as values.**
  §1.3 hands procedures to procedures; `(:sicp::fixed-point :wat::math::cos 1.0)` passes the
  checker and dies at run time —
  > `not callable: expected Function, got wat::core::keyword ":wat::math::sin"`

  so every builtin SICP would pass to a higher-order procedure has to be wrapped in a
  user-defined `defn` first. A user function *is* a value; a builtin is a keyword only the call
  position understands. Everything else in §1.3 ports without friction: `sum` taking a term and a
  successor, `average-damp` and `deriv` and `newton-transform` **returning** closures, a
  transform passed as an argument to `fixed-point-of-transform`, and `repeated` building a
  closure by recursion.
- **Nothing new is broken.** All three frictions are existing ledger rows; what is new is that
  they are the *only* three across a whole chapter, and that two of them are where the book's own
  pedagogy points.
- **Class:** CLEAN, with F-007/F-054 and F-038 corroborated in a fourth context.
- **Repro:** `./run.sh sicp`; `wat probes/sicp/process-shape-depth.wat rec 200000`.


### C-077: SICP §2.1 and §2.2 — the closure property is a recursive enum, and a pair can still be a procedure

- **Where:** `sicp/ch21-data-abstraction.wat`, `sicp/ch22-hierarchical-data.wat`, against new
  guile oracles. **18 + 20 = 38 results, every one matching in order.**
- **§2.1 closes by asking what a pair IS, and answering that it need not be data.** `cons` returns
  a procedure; `car` and `cdr` apply it to a chooser (Exercise 2.4). wat **types** that:

  ```wat
  (:wat::core::typealias :sicp::Chooser [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64])
  (:wat::core::typealias :sicp::PPair   [:sicp::Chooser :-> :wat::core::i64])
  ```

  The rationals are then rebuilt on it and **every result is unchanged**, which turns the
  section's argument about abstraction barriers from a claim into a mechanical check.
- **§2.2's closure property is the one place SICP's Scheme and wat genuinely differ,** and it is
  worth stating plainly rather than working around quietly. In Scheme `((1 2) (3 4) 5)` works
  because a list is untyped — `car` may answer a number or another list and nothing checks. wat's
  collections are monomorphic and `:Any` is banned (C-004), so the structure has to be named:
  `Tree ::= Leaf i64 | Node Trees`. That is not a workaround; it is the closure property **written
  down**, and the gain is that `count-leaves` is checked exhaustive where Scheme's leans on
  `pair?` at run time and would answer nonsense for a string. The cost is that the shape must be
  declared first, and a genuinely heterogeneous list still needs C-004's quoted-form route.
- **A note wat earns against itself:** wat *has* rationals natively, and SICP's hand-built version
  is more capable in one specific way. **Corrected 2026-09-17 (C-093): the claim first made here,
  that `:wat::rational::` is "four verbs with no division, no comparison and no to-string", was
  wrong on three counts.** It is **seven** verbs — `+ - * /`, `numerator`, `denominator`,
  `to-f64` — division exists, equality works (`(= 1/2 2/4)` is true, so rationals normalise), and
  there is a rational **literal** (`3/4` reads). The original count came from grepping only `docs/`
  and `wat/` and missing `src/`. What is genuinely absent is **ordering** — `(< 1/4 3/4)` is
  refused — and a dedicated `to-string`.
- **Class:** CLEAN.
- **Repro:** `wat sicp/ch21-data-abstraction.wat`, `wat sicp/ch22-hierarchical-data.wat`.

### F-108: the `:wat::vector::` namespace serves `PersistentVector`, not the type named `Vector` — and one of its errors names a verb the author never wrote

- **Where:** hit while porting SICP §2.2 (C-077) by reaching for `:wat::vector::concat` to append
  two `Vector`s — the obvious thing to reach for, and the wrong one.
- **Measured** (`probes/scalar/vector-namespace.wat`, wat-rs `a3218644d`, 2026-09-16): **all six**
  verbs in `:wat::vector::` take a `PersistentVector` and **reject** a `Vector`:

  | called on a `Vector` | says |
  |---|---|
  | `:wat::vector::length` / `get` / `empty?` / `conj` / `contains?` | *parameter #1 expects (:wat::core::PersistentVector …)* |
  | `:wat::vector::concat` | ***:wat::core::PersistentVector/concat**: parameter #1 expects (PersistentVector …)* |

  The last row is the worst of the six: the diagnostic names **a verb the author never wrote**, so
  the reader has to work out that `:wat::vector::concat` is an alias before the message means
  anything.
- **The working route for a `Vector` is `:wat::core::`** — `concat`, `conj`, `length`, `nth`,
  `first`, `rest`, `mapv`, `filterv`. So the namespace called `vector` and the type called
  `Vector` are *different things*, and nothing says so.
- **Why it matters more than a naming quibble.** wat is LLM-first. Given a value of type `Vector`
  and a need to append, the namespace whose name matches the type is the first and most confident
  guess a generator will make — I made it — and it is wrong for every verb it contains. This is
  the F-093 / F-107 family: not a defect in what the code *does*, but in what a reader is led to
  believe before running it.
- **Correction to my own ledger, from the same probe.** **F-104** described `:wat::vector::` as
  `concat`/`conj`/`contains?`. The surface is **six** — `length`, `get`, `empty?`, `conj`,
  `contains?`, `concat`. F-104's conclusion is unaffected and in fact firmer: six verbs, and still
  no positional update, so the persistent vector remains append-only.
- **Class:** CLEAN (name the namespace for the type it serves, or say in one line that it does
  not), with a FIX half for the `concat` diagnostic naming an unwritten verb.
- **Repro:** `wat probes/scalar/vector-namespace.wat`.


### C-078: SICP §2.3-§2.5 — an open dispatch table and a closed enum, arriving at the same place from opposite directions

- **Where:** `sicp/ch23-symbolic-data.wat`, `sicp/ch24-multiple-representations.wat`,
  `sicp/ch25-generic-operations.wat`. **27 + 20 + 20 = 67 results, every one matching guile in
  order. SICP chapter 2 is complete** (§2.1–§2.5, 125 results).
- **§2.3, symbolic differentiation:** SICP represents an expression as a tagged list and asks
  `pair?`, `symbol?`, `number?` at run time; wat's counterpart is an enum, so `deriv`'s dispatch
  is **checked exhaustive**. SICP's version ends in `(else (error "unknown expression"))` — a case
  the reader is told to worry about and the compiler never sees. The section's real lesson, that
  the *simplifying constructors* are what keep answers readable, ports unchanged.
  Sets three ways (unordered list, ordered list, binary tree) are Okasaki ch2 (C-051) arrived at
  from the other direction, and are where **F-057** bites: no persistent set, so an unordered set
  is a `Vector` and membership is a scan — exactly as SICP writes it by hand.
- **§2.4 builds all three dispatch styles, because the section exists to compare them.** Two
  results worth keeping:
  - **A `HashMap` can hold closures**, so data-directed dispatch works — the first thing in this
    repository to put functions in a *map* rather than in a struct.
  - **Message passing types cleanly only because every selector here answers `f64`.** An object
    whose messages return *different* types has no wat spelling short of an enum return. That is
    the typed language's real objection to the style, and it is worth naming: SICP's version
    silently relies on the answers being unioned by the untyped host.
- **§2.5 is where the two philosophies meet, and the port states the trade rather than resolving
  it.** SICP's table is **open**: any package may `put` a new (operation, type) entry and nothing
  records that it did — which is the freedom being sold, and the reason `apply-generic` must end
  in an error for an entry never put. wat's `Num` is a **closed enum**, so `add-same` and
  `raise-1` are checked exhaustive and adding a fourth level is a compile error at exactly the
  sites SICP asks you to remember by hand. The freedom is gone; so is the bug class §2.5.2 spends
  its last pages on.
  **The tower itself survives intact either way** — `level` and `raise-to` are unchanged from the
  Scheme, and only the dispatch beneath them differs. That is the part worth carrying into any
  wat design discussion: the idea is portable, the openness is not.
- **Nothing here is a defect in wat.**
- **Class:** CLEAN.
- **Repro:** `./run.sh sicp`.


### C-079: SICP §3.2 — the environment model, with the frames as data

- **Where:** `sicp/ch32-environment-model.wat`. **18 results, all matching guile. SICP chapter 3
  is now complete** (§3.1–§3.5), and this was the gap inside it.
- **Why it was worth building rather than waving at.** §3.2 is the one section of chapter 3 that
  is not about mutation, and it is the rule §3.1's local state (C-014) silently depends on: a
  procedure is code **plus the frame it was created in**, so applying one makes a new frame whose
  enclosing frame is the *procedure's*, not the caller's. It is normally taught with diagrams;
  here the frames are data, so the claims are things the model computes:

  | claim | result |
  |---|---|
  | a name resolves at the first enclosing frame that binds it | `x` in the inner frame is **99**, at depth **0** |
  | and the outer binding is still reachable | `y` is **20**, at depth **1** |
  | a closure made in the global frame, applied "inside" another | sees `x` = **10**, not 99, at depth **1** |
  | two procedures from one maker | **100** and **200**, and `=` on them is **#f** |
  | both still see the frame behind their own | `y` = **20** at depth 1 |

  The third row is lexical scoping, and the fourth is the whole reason a maker works at all.
- **Nothing here needs mutation, so nothing here needs a service** — unlike §3.1 and §3.3, which
  route through C-014. This is the smallest environment implementation in the repository, beside
  EOPL's (C-061) and §2.2's three representations (C-077).
- **Class:** CLEAN.
- **Repro:** `wat sicp/ch32-environment-model.wat`.


### C-080: SICP chapter 4 — a genuinely metacircular evaluator, and the one place the checker cannot help

- **Where:** `sicp/ch41-metacircular.wat`, `ch42-lazy-evaluation.wat`, `ch43-nondeterministic.wat`,
  `ch44-logic-programming.wat`. **17 + 12 + 13 + 17 = 59 results, all matching guile in order.**
- **§4.1 keeps the word METACIRCULAR honest, and that is the point of the port.** Almost every
  port of this chapter quietly declares an `Exp` enum, which yields an interpreter for a
  *different* language that happens to look similar. (EOPL's ports here do exactly that, correctly,
  because EOPL is not claiming otherwise.) wat does not have to: `:wat::WatAST` is wat's own quoted
  form (C-004), so the programs are written `(:wat::core::quote (+ 1 2))` — real wat syntax, read
  by wat's own reader — and the evaluator takes them apart with `ast-kind`, `ast-name`, `first`,
  `rest`. Nothing re-declares the evaluated language's syntax. `let` is derived, not primitive.
- **And the cost showed up while building it, which is the finding.** Dispatch on `ast-kind` is a
  chain of **string comparisons, not a `match`**, so this is the only evaluator in the repository
  whose dispatch the checker cannot prove exhaustive. A fallthrough for the non-int, non-symbol
  case sent a node into `first`/`empty?` and failed at **run time**:
  > `:wat::core::empty?: expected (Vector :- [T]), … got wat::WatAST "<WatAST>"`

  `ast-kind` has more kinds than the evaluator handled (string, float, keyword) and nothing warned.
  That is exactly the trade C-004 records, and it is why the enum versions elsewhere are the right
  default: **metacircularity in a typed host buys fidelity and gives up exhaustiveness.**
- **§4.2's lazy evaluator is the third independent route to P-027.** One change — an operand
  becomes a thunk — buys the divergent-argument demonstration and `unless` as an ordinary
  procedure, and costs repeated evaluation. Counted, with the counter **threaded** rather than
  mutated (C-066's shape): an argument used three times forces **3**, used once forces **1**,
  ignored forces **0**. SICP's fix is a memoizing thunk; wat has no force-once-and-shared cell,
  which is why `okasaki/lib/susp.wat` exists. EOPL C-062 priced the same gap asymptotically and
  C-075 counted it on streams; this is SICP's side of the same missing primitive.
- **§4.3's `amb` is the first thing here to need TWO continuations at once**, and the types are
  the interesting part:
  ```wat
  (:wat::core::typealias :sicp::Fail    [:-> :sicp::Out])
  (:wat::core::typealias :sicp::Succeed [:sicp::NVal :sicp::Fail :-> :sicp::Out])
  (:wat::core::typealias :sicp::Comp    [:sicp::Succeed :sicp::Fail :-> :sicp::Out])
  ```
  Three mutually referring function types, including the **zero-argument** `[:-> Out]`, taken
  without ceremony. Pythagorean triples to 20 come back in the right order, and `require` prunes by
  calling the failure continuation. **The cost is that the answer type must be fixed:** in Scheme
  one computation answers a value to `first-of` and a list to `all-of`; here both must answer the
  same `Out`, so `Out` is a three-variant enum. A polymorphic answer type would need the
  computation generic in it — **F-029** territory.
- **§4.4 is unification for the third time in this repository, on a third kind of data** — PAIP
  ch11 builds it for Prolog terms, EOPL ch7 (C-063) for type trees with the occurs check, and here
  for trees of plain symbols. The algorithm is the same all three times, which is the section's
  real claim, and the ports make that checkable rather than asserted. One fact shape answers "who
  is a computer programmer" and "what does Ben do" depending only on where the variable sits.
- **Class:** CLEAN.
- **Repro:** `./run.sh sicp`.


### C-081: SICP chapter 5 — a register machine, a collector, and the compiler's payoff as a count. **SICP is complete.**

- **Where:** `sicp/ch52-register-machine.wat`, `ch53-garbage-collection.wat`,
  `ch54-explicit-control.wat`. **14 + 13 + 20 = 47 results, all matching guile. SICP is now
  complete: all five chapters, 354 results**, from 4 files inside chapter 3 at the start of the
  day.
- **§5.1-5.2 turn the chapter's central claim into a number.** SICP says a recursive procedure
  needs a stack and an iterative one does not, and asks you to see it in a diagram. Simulating the
  machine reports it:

  | machine | result | stack high-water | steps |
  |---|---|---|---|
  | gcd 206 40 | 2 | **0** | 32 |
  | iterative factorial 10 | 3628800 | **0** | — |
  | recursive factorial 10 | 3628800 | **9** (and 4 at n=5) | — |

- **§5.3's stop-and-copy checks the claim that actually needs checking.** Not that collection frees
  memory — that is obvious — but that copying **preserves sharing**: two lists sharing a tail must
  still share it afterwards, or the collector has silently turned one structure into two. Verified
  as the equality of two cdr pointers *after* the copy. With one list live, 4 cells become 3; with
  nothing live, 0. The broken heart is written **before** the recursive call exactly as in the
  book, because that ordering is what makes sharing work — a property of the algorithm, not of
  mutation, and nothing here mutates.
- **§5.4-5.5 are the chapter's payoff, and it is a count:**

  | the same expression | machine steps |
  |---|---|
  | interpreted, explicit control | **11** |
  | compiled (3 top-level instructions) | **8** |

  and both answer 42. That is the whole argument for compilation, stated as a number rather than
  an argument. The continuation is a **list of tasks** rather than a chain of frames — the same
  defunctionalisation EOPL ch5 does (C-061), reached from SICP's side.
- **This is the closest thing in the repository to NEXT.md §12's byte-code VM, and it arrives with
  a price tag.** Both machines are a step function over an explicit state, which **F-105** measured
  at **~1.9×** the cost of mutually tail-calling procedures, because the step must allocate the
  state it returns. The step counts above are machine-*independent*; the 1.9× is what those steps
  cost in wat specifically. The byte-code work should pick the shape knowing both numbers.
- **Three existing ledger rows landed for structural rather than incidental reasons:**
  - **F-088** — popping the machine's stack cannot use `:wat::core::take`, which answers a
    **Stream** with no way back to a Vector. A register machine pops on almost every instruction.
  - **F-104** — GC memory is a `PersistentMap` keyed by cell index because neither vector type has
    a positional update. A collector indexing dense integers is about the purest case for that
    missing operation there is; fifth workload to route around it.
  - **the containment rule** — `Mem` had to be a `defrecord`, not a `defstruct`, because a
    defstruct is impure (F-040) and a Pure enum may not hold one. Sixth time the aggregate *kind*,
    rather than the field types, decided a program's shape.
- **Class:** CLEAN.
- **Repro:** `./run.sh sicp`.


### C-082: PAIP chapters 2 and 4 — and the missing random number generator forcing a better shape

- **Where:** `paip/ch02-sentence-generator.wat`, `paip/ch04-gps.wat`, against new guile oracles.
  **16 + 13 = 29 results, all matching in order.** First fruits of the builder's full-coverage
  ruling on PAIP (2026-09-16): the suite was two chapters chosen to press quoted data, and NEXT.md
  §5 now carries a 25-row table, including the five chapters marked **no portable content**
  because they teach Common Lisp itself rather than an algorithm.
- **Chapter 2 walks straight into F-036** — there are no random numbers in wat, not even a seeded
  generator. Re-verified: `random::int`, `rand::int`, `core::random`, `math::random` all
  unresolved, and `grep -r rand wat-rs/src wat-rs/wat` finds nothing but an unrelated rete name.
  So the generator drives a **hand-written LCG**, and so does the oracle — the only way the two can
  be compared at all.
- **And the workaround turns out to be better than the thing it replaces, which is worth saying
  plainly.** Threading the seed makes `generate` a **function**: the same seed gives the same
  sentence, checked in the chapter. Norvig's version is an effect on a hidden generator and cannot
  be tested that way at all. wat's missing primitive forced the more testable shape.
  **The ask still stands**, and this sharpens it: what a user cannot get is a *seed*. `:wat::uuid::v4`
  exists, but turning one into an integer is a route nothing documents. A seeded, explicitly
  threaded generator would be the right primitive — not a hidden global one.
- `generate-all` needs no randomness and is the stronger test: 2 articles × 4 nouns × 4 verbs × 2
  articles × 4 nouns = **256** sentences, every one five words long.
- **Chapter 4's GPS is a chapter about a program's BUGS**, so the failures are tested as carefully
  as the successes: a goal no operator adds, a chain broken at its deepest link (no phone book, no
  money), and **prerequisite-clobbers-sibling-goal**. The port carries PAIP's fix — every goal is
  re-checked against the *final* state — and that is why the two goal orderings agree here where
  GPS 1.0's would not.
- **What chapter 4 does NOT stress is worth recording too.** **F-057**'s missing persistent set is
  the natural representation for a state, and its absence costs a linear `mem?` per condition —
  invisible at these sizes. The finding is real; this is not the workload that proves it, and
  saying so keeps the ledger honest about which evidence carries which claim.
- **Class:** CLEAN, with F-036 corroborated and sharpened.
- **Repro:** `./run.sh paip`.


### C-083: PAIP chapters 5, 6 and 8 — the matcher, the search tool, and what a rule table cannot ask

- **Where:** `paip/ch05-eliza.wat`, `ch06-search-tools.wat`, `ch08-symbolic-math.wat`.
  **17 + 15 + 18 = 50 results, all matching guile in order.** PAIP is now **7 of 20 portable
  chapters**.
- **Chapter 5's segment matcher is the chapter**, not the psychiatry. `?*x` matches zero or more
  words, so matching means trying every split and backtracking. Driven directly as well as through
  the rules, including the two cases a naive implementation gets wrong: a segment matching
  **nothing**, and the same variable appearing **twice**.
  **F-062 decides the representation and is at its mildest here**: a wat String has no characters,
  so `?x` and `?*x` are recognised by `:wat::string::starts-with?` rather than by `string-ref`.
  Recorded because a finding's weight should track the workloads it actually blocks, and this one
  it did not.
- **Chapter 6 produced two results that contradict what one expects to write, and they are kept
  rather than tuned:**
  - **Depth-first expands 29 states where breadth-first expands 19.** The dive is 50% *dearer* on
    this graph, because the goal is shallow and the dive goes past it. The chapter asserts the
    comparison and prints **#f**.
  - A **beam of width 1** still finds 19. The "a narrow beam can miss the goal" warning is true in
    general and simply does not bite here — the sort of thing only running it tells you.
  Best-first expands **7**, which *is* fewer than breadth-first, so the tool does earn its keep;
  just not where the intuition said.
- **F-057 lands exactly where the chapter puts it.** Graph search needs a **visited set**, and wat
  has no persistent set, so it is a `Vector` with a linear `member?`. On a three-node cycle that is
  free. What this workload contributes is not a cost but the **shape**: a visited set is precisely
  the *insert-and-test, never iterate* use F-057 describes, which is the use a `PersistentMap` to
  `true` serves worst.
- **Chapter 8 is the sharpest thing in the three, and it is a limit on rule tables.** The
  simplifier is driven by rewrite rules as data, and it reproduces SICP §2.3's differentiation
  (C-078) with a different factor order — same expression, `(+ (* x y) (* (+ x 3) y))` against
  SICP's `(+ (* x y) (* y (+ x 3)))`, because the rule's right-hand side fixes an order the
  hand-written constructor fixed differently. Neither is wrong; the table does not know it should
  prefer one.
  **But two of the rules cannot be written as patterns at all.** `d(c)/dx = 0` needs "?c is a
  **number**", and `d(y)/dx = 0` needs "?y is a symbol **other than** ?x". Both are side
  conditions on a term's *kind*, not shapes, so both live outside the table as ordinary functions —
  and PAIP hits this too, and does the same thing. **A rule table is open to new rows and closed to
  new kinds of question.** That is the same trade C-078 recorded for SICP §2.5's dispatch table,
  reached from the opposite direction, and it is the thing to say to anyone proposing a rule table
  as an extension mechanism.
- **Class:** CLEAN.
- **Repro:** `./run.sh paip`.


### C-084: PAIP chapter 9 — a guess about memoization that was wrong, and the contract difference underneath it

- **Where:** `paip/ch09-efficiency.wat`, `probes/paip/transparent-memoize.wat`. **19 results, all
  matching guile.** PAIP is **8 of 20 portable chapters**.
- **The measurement the chapter is about:** naive `fib(20)` costs **21891** calls; the memoized
  version costs **21**. The chapter uses a **threaded** table rather than a wrapper for a reason
  that has nothing to do with what is possible — threading makes the call count *observable*, and
  a transparent wrapper hides exactly the number being measured.
- **And a guess that was wrong, recorded because it nearly went in as a finding.** Norvig's
  `memoize` is a higher-order function returning a memoized version *with the same signature*, on a
  hidden mutable table. The obvious conclusion is that wat cannot write it, because wat has no
  mutation (C-053). **It can.** A closure captures a `:wat::cache::Lru`, and the wrapper behaves
  exactly as Norvig's — second call, same argument, no recomputation. The probe exists because this
  file's header first claimed the opposite; checking the obvious alternative before publishing is
  the only reason the ledger does not now contain a false row.
- **What survives is sharper than what I nearly wrote, and it is a contract difference rather than
  a performance one:** an **LRU is allowed to forget**. At capacity 2 the probe shows the wrapper
  recomputing a value it had already produced. For `fib` that is a tuning parameter. For anything
  memoized for **identity** — hash-consing, interning, a canonical-form table — it is *wrong*,
  because the invariant being bought is "the same input yields the very same result, always", and
  an evicting cache cannot promise it.
- **So the ask is P-028**, a memo cell that never evicts — the **keyed relative of P-027's one-shot
  suspension**. They are one requirement at two arities: *a cell that remembers and is not allowed
  to forget*. `:wat::cache::Lru` is the wrong vehicle for both, for the same reason. Three further
  costs carry over from P-027: a cached read is ~7251 ns against ~3583 ns for a plain call (**2× a
  function call**, which the saving must clear before memoizing pays at all); `Lru` is
  `thread_owned`, so a memoized function cannot cross a thread boundary; and capacity 0 panics
  (**F-084**), so every wrapper must reject or clamp it.
- **Class:** CLEAN, with **P-028** raised and a nearly-published error caught.
- **Repro:** `wat paip/ch09-efficiency.wat`; `wat probes/paip/transparent-memoize.wat`.


### C-085: PAIP chapters 7 and 13 — a precondition no code checks, and the second dispatch axis

- **Where:** `paip/ch07-student.wat`, `paip/ch13-object-oriented.wat`. **18 + 15 = 33 results, all
  matching guile.** PAIP is **10 of 20 portable chapters**.
- **Chapter 7's `isolate` is correct only under a precondition its own code never checks**, and the
  port prints the number that shows it. `isolate` moves operands across by asking *which side of
  the operator the unknown is on* — so with the unknown on **both** sides it does something
  well-defined and useless: `(+ x x) = 10` isolates to `x = 10 - x`, and "did isolate fail?"
  answers **#f**. The guard lives in the **caller**: `solve-system` only selects an equation whose
  unknown occurs exactly once. That split — an algorithm whose correctness rests on a condition
  nothing in it tests — is worth naming precisely because wat's checker is so good at this class of
  thing elsewhere (C-078, C-080): exhaustiveness catches missing *cases*, not missing *conditions*.
  The one place the port is tighter than the original: `evaluate` answers an `Option` where the
  Scheme answers the symbol `'unbound`, so a caller cannot forget to check.
- **Chapter 13: see F-109, which this entry originally got wrong.** C-085 first reported that wat
  could not express multiple dispatch and recommended a hand-built table keyed by the tuple of type
  tags. **Both halves were wrong**: `:wat::core::defclause` does multiple dispatch, on the runtime
  types, and a missing combination at a concretely-typed call site is a **compile error** — so the
  recommended table was strictly worse than the feature that already existed. The retraction and
  what actually survives are in F-109. `paip/ch13-object-oriented.wat` now demonstrates
  `defclause` alongside the table, with the two required to agree.

### F-109 — **RETRACTED AND REPLACED.** wat *does* have multiple dispatch: `defclause`. What is true is that almost nobody will find it

- **The original claim was wrong, and is kept here rather than deleted** because how it went wrong
  is the more useful record. F-109 said: *"wat has single dispatch and cannot express multiple
  dispatch — the method name has no room for the argument types."* I tested `defsurface` +
  `extend-type`, found a concrete type may extend a surface only once, and concluded the language
  could not do it. **I never checked whether another mechanism existed.** The builder asked
  *"is this what wat's defclause is meant for?"* — and it is.
- **What `defclause` actually does** (`probes/paip/multiple-dispatch.wat`, wat-rs `a3218644d`,
  2026-09-16). The exact case the original finding called impossible:

  ```wat
  (:wat::core::defclause :d::collide
    ([a <- :d::Asteroid  b <- :d::Ship]     -> :wat::core::String "ship destroyed")
    ([a <- :d::Asteroid  b <- :d::Asteroid] -> :wat::core::String "both shatter")
    ([a <- :d::Ship      b <- :d::Ship]     -> :wat::core::String "both damaged"))
  ```
  Four calls, four clauses, selected per-position. `OP-PLACEMENT.md` describes it exactly:
  *"dispatch is first-match-wins by per-position type match … checked against each clause's
  parameter types independently, one position at a time."*
- **And it is better than I credited on the point I made most of.** C-085 argued that the
  hand-built table "loses exactly the exhaustiveness the enum route buys". It does — but
  `defclause` does **not**:

  | call site | missing combination is |
  |---|---|
  | argument types known concretely | a **compile error** — `CheckErrors`, *1 type-check error*, `NoMatchingClause` |
  | dispatching through a wider static type (a surface-typed parameter) | a **runtime** `NoMatchingClause` |

  So the recommended workaround in C-085 was strictly *worse* than the feature that already
  existed. That correction matters more than the original finding did.
- **It also dispatches on the RUNTIME type, not merely the declared one.** One statically-typed
  function whose two parameters are both `(:d::Thing :- [i64])` selects three different clauses
  from three different argument pairs. That is CLOS's behaviour, which is what PAIP chapter 13 is
  about.
- **What survives, and it is a real finding of the F-065 / F-076 / F-108 family: discoverability.**
  `defclause` is one of wat's two polymorphism mechanisms and carries its own arithmetic
  (`+`, `-`, `*`, `<`, …). It appears **3** times in `USER-GUIDE.md`, and **0** times in the
  cheatsheet, the Clojure rosetta and SERVICE-PROGRAMS. The place it is actually *explained* is
  `OP-PLACEMENT.md` — an internal design document about where to put an operator, not a page a
  user reads to learn the language.
  I reached for `defsurface` because that is what the user-facing material points at for
  polymorphism, and wrote a false finding as a result. An LLM generating wat will make the same
  move for the same reason. **The fix is one line in the cheatsheet and one paragraph in the
  guide:** surfaces dispatch on `self`; `defclause` dispatches on every argument.
- **Class:** CLEAN (document `defclause` where users look). The original EXTEND claim is withdrawn.
- **Repro:** `wat probes/paip/multiple-dispatch.wat`; `wat paip/ch13-object-oriented.wat`.

### C-086: PAIP chapters 14 and 18 — and F-104 landing on the most ordinary case there is

- **Where:** `paip/ch14-knowledge.wat`, `paip/ch18-othello.wat`. **15 + 16 = 31 results, all
  matching guile.** PAIP is **12 of 20 portable chapters**.
- **Chapter 14's semantic network turns on two things**, both checked: a subclass **overriding** a
  default (birds fly, penguins do not, so two birds give two answers), and the search stopping at
  the **nearest** answer — Opus has **2** legs, from `bird`, not 4 from `animal`. Plus a `seen`
  list, because `isa` is user-supplied and can contain a cycle.
  **A distinction worth drawing about F-057:** in PAIP ch6 (C-083) the missing persistent set cost
  *performance*. Here the visited set is load-bearing for *termination* — without it the query does
  not return at all. Same missing primitive, two different consequences, and the second is the one
  that would bite a user who reached for `HashSet` and paid a copy per recursive step.
- **Chapter 18 is a real 8×8 Othello** — move generation flipping in eight directions, minimax and
  alpha-beta — and the chapter's claim comes out as a count: **depth 3, minimax visits 73 nodes,
  alpha-beta visits 37**, same answer.
- **F-104 lands here on the most natural case there is: a game board.** Placing a piece changes one
  square of a 64-square vector, and neither vector type has a positional update — `core::assoc`
  takes a HashMap or a Record, `map::assoc` a PersistentMap, and `:wat::vector::` is six verbs on
  PersistentVector with no update among them (F-108). So `set-at` rebuilds the whole board, and a
  move flipping *k* pieces rebuilds it *k+1* times.
- **That is the sixth workload here to route around F-104, and the pattern across all six is now
  clear enough to state as one sentence:** a game board, a store (C-066), a garbage collector's
  memory (C-081), a register machine's stack (C-081), EOPL's IMPLICIT-REFS store (C-068), and
  MUTABLE-PAIRS (C-069) all want **dense integer indices with one cell changing** — which is what a
  vector is *for*. Every one ends up either rebuilding the whole structure or reaching for a
  `PersistentMap` keyed by an integer, which is a tree standing in for an array. The finding is not
  that some program was awkward; it is that the six most array-shaped workloads in the repository
  all had to stop being arrays.
- **Class:** CLEAN, with F-104 and F-057 corroborated and their consequences separated.
- **Repro:** `./run.sh paip`.


### C-087: PAIP chapter 22 — wat gives the interpreted language `call/cc`, and pays for it with the carrier

- **Where:** `paip/ch22-scheme-interpreter.wat`. **13 results, all matching guile.** PAIP is **13 of
  20 portable chapters**.
- **The third time this repository has watched the same thing happen:** wat lacks a feature, and an
  interpreter written in wat hands that feature to the language it interprets.

  | | |
  |---|---|
  | **R-003** | wat has no first-class continuations; the Seasoned Schemer's `letcc` went through `Result/try` (C-013) |
  | **C-064** | EOPL ch5's THREADS gave the interpreted language a **mutex** its host cannot express |
  | **here** | the interpreted Scheme gets **`call/cc`**, complete, because the interpreter is in CPS and a continuation is therefore just a value it holds |

- **The result that shows it is real rather than decorative:**
  `(+ 1 (call/cc (lambda (k) (* 100 (k 10)))))` answers **11** — the `(* 100 …)` never runs. That
  is precisely what a `Result/try` escape cannot do from an arbitrary position, and what makes
  `call/cc` more than an early return. The classic short-circuit product answers **0** where the
  same recursion without the escape answers **24**.
  guile has `call/cc` of its own and the oracle deliberately does not use it — both sides build it
  from their own explicit continuations, so the comparison is of equal work.
- **And the price is the carrier, in a new way.** `SVal` cannot be a Pure enum:
  > *containment rule: Pure enum `:paip::SVal` may only hold pure variant fields — variant `Cont`
  > field `k` has impure type `[:paip::SVal :-> :paip::SVal]`*

  This is the **seventh** time the aggregate *kind* rather than the field types decided a program's
  shape, and the **first where the impure thing is a closure rather than a live handle**. The
  consequence deserves stating on its own: **a value domain that includes continuations can never
  cross a service boundary.** An interpreter offering `call/cc` is, by that fact alone, confined to
  one address space — and nothing in the docs would tell an author that before they wrote it.
- **Class:** CLEAN, with the containment rule's reach extended from handles to closures.
- **Repro:** `wat paip/ch22-scheme-interpreter.wat`.


### C-088: PAIP chapter 23 — the peephole optimizer, and why exhaustiveness suits a compiler pass

- **Where:** `paip/ch23-compiling-lisp.wat`. **19 results, all matching guile.** PAIP is **14 of 20
  portable chapters**.
- **SICP §5.5 already compiled here (C-081)** and measured the payoff — 11 machine steps
  interpreted, 8 compiled. What PAIP adds is the **peephole optimizer**, so the measurement is
  instruction count before and after:

  ```
  (+ (* 2 3) (* x 1))   compiles to  7 instructions
                        optimises to 3
                        both answer  11
  ```

  Three rewrites do it: fold two constants under an arithmetic primitive, drop `+ 0`, drop `* 1`.
- **And a compliment rather than a complaint, which the ledger should carry as readily as the
  gaps.** A peephole window is *instruction, instruction, instruction*, and each rewrite asks about
  the **shape** of those three — which is exactly what `match` over an enum is for. The optimizer
  cannot silently miss an instruction kind: adding one to `Instr` breaks every `match` that must
  learn about it. PAIP's version dispatches on `(car i)` and would simply not fire, quietly
  emitting unoptimised code forever. That is the property C-078 praised in SICP §2.3 and C-085
  found the limit of in PAIP ch13 — **exhaustiveness catches missing cases, and a compiler pass is
  almost entirely cases.** If there is one workload shape this type system is built for, it is
  this one.
- **Class:** CLEAN.
- **Repro:** `wat paip/ch23-compiling-lisp.wat`.


### C-089: PAIP chapters 15, 16 and 17 — canonical forms against rewrite rules, and a range the type system cannot say

- **Where:** `paip/ch15-canonical.wat`, `ch16-expert-system.wat`, `ch17-constraints.wat`.
  **16 + 20 + 16 = 52 results, all matching guile.** PAIP is **17 of 20 portable chapters**.
- **Chapter 15 against chapter 8 is the best pairing in the book, and having both ports here makes
  it concrete rather than rhetorical:**

  | | |
  |---|---|
  | ch8, **rewrite rules** (C-083) | `x + x` and `2x` are different trees. A rule set may or may not reconcile them; the simplifier runs to a fixed point hoping; two rules could not be written as patterns at all |
  | ch15, **canonical form** | `x + x` and `2x` are the **same vector** the moment they are built. `(0 2)` equals `(0 2)`. There is no simplification step |

  The consequence the chapter is selling: an identity becomes **checkable** rather than provable.
  `(x+1)² = x² + 2x + 1` is decided by comparing `(1 2 1)` with `(1 2 1)`, and a **false** identity
  is refuted just as cheaply — which a rewrite system cannot promise, because failing to find a
  proof is not finding a disproof.
  **And the first array-shaped workload here that F-104 does *not* touch**, because it rebuilds
  rather than updates. Worth recording as carefully as the seven that did: the missing positional
  update hurts exactly the programs that change one cell.
- **Chapter 16's certainty factors expose a gap in the type system rather than in the language.** A
  certainty factor is an integer constrained to **[-100, 100]**, and nothing in wat can say so.
  `:wat::core::i64` admits 5000; every combining rule would produce nonsense from it; the only
  defence is that no caller writes one. Verified there is no route: `:wat::core::range` is a
  *sequence generator* (`(range 1 5)` → `[1 2 3 4]`), not a type, and a type annotation carrying a
  bound is a malformed type expression.
  **The focused version of this ask is not refinement types** — that is a large feature a language
  may reasonably decline. It is that **`newtype` already exists** (F-106) and is the natural place
  to hang a checked constructor: a `newtype CF = i64` whose constructor rejects out-of-range input
  would cost one predicate and close the hole. As it stands `newtype` gives distinctness without
  sealing (F-106) and without invariants.
- **Chapter 17's Waltz filtering tests all three outcomes**, including the one that is easy to omit:
  **decided** (12 possibilities collapse to 3 — a=+, b=R, c=-), **impossible** (every domain
  empties, total 0), and **ambiguous** (2×2 survives and would need search). A single junction on
  its own removes **nothing** here; propagation earns its keep from the *interaction* of
  constraints, not from any one of them.
  **F-104, seventh workload, and the purest yet:** constraint propagation is a loop whose entire
  job is *change one cell, repeat*.
- **Class:** CLEAN, with F-104 corroborated and F-106's ask sharpened.
- **Repro:** `./run.sh paip`.


### C-090: PAIP chapters 19, 20 and 21 — **PAIP is complete**, and the same design pressure answered four times

- **Where:** `paip/ch19-natural-language.wat`, `ch20-unification-grammar.wat`,
  `ch21-english-grammar.wat`. **13 + 15 + 15 = 43 results, all matching guile. PAIP is now
  complete: 20 of 20 portable chapters, 377 results**, from 2 chapters at the start of the day.
  The five chapters that teach Common Lisp itself rather than an algorithm are listed in NEXT.md §5
  as **no portable content** — a decision on the record, not a silent gap.
- **Chapter 19: ambiguity.** "I saw the man with the telescope" has **2** parses and the grammar
  cannot choose. The chapter checks that the two trees are **not equal** rather than merely
  counting them — a parser returning the same tree twice would pass a count and fail that.
- **Chapter 20: agreement by unification.** A category carries a number feature; `S(?n) → NP(?n)
  VP(?n)` makes "the-sg man see" ungrammatical with no second rule, and `*` gives the object an
  independent scope so "the-sg man sees the-pl men" is fine while "the-sg man see the-pl men" is
  not. A plain CFG needs every rule **twice**, and the count multiplies with each feature.
- **Chapter 21: subcategorization and recursion.** A verb takes what it takes — "the dog slept the
  bone" and "the man saw" are both rejected — and a relative clause embeds a sentence inside a noun
  phrase, two levels deep, with the embedded clause obeying subcategorization too.
  **One honest correction carried in the file:** this grammar attaches a PP only inside a noun
  phrase, so "the man saw the dog in the park" has exactly **one** parse here where chapter 19's
  grammar gave it two. Ambiguity is a property of the grammar, not of English, and the chapter
  records the count rather than implying the reverse.
- **The pattern worth taking away from the whole book.** Four chapters independently needed a
  return type with **three** states rather than two, and wat's enums answered it every time without
  a sentinel:

  | chapter | the three states |
  |---|---|
  | ELIZA (C-083) | `Fail` ≠ "matched with no bindings" ≠ a binding |
  | STUDENT (C-085) | `fail` ≠ `unbound` ≠ a value |
  | ch19 (here) | ungrammatical (empty) ≠ unambiguous (one) ≠ ambiguous (many) |
  | ch20 (here) | `BFail` ≠ `Undecided` ≠ `Is(sg)` |

  Each is a case where `Option` carries two of the three and forces the third into a sentinel that
  a caller can forget to check. This is the quiet thing wat did well across an entire book, and it
  belongs in the ledger as firmly as the gaps do.
- **Class:** CLEAN.
- **Repro:** `./run.sh paip`.


### F-110: a second `defclause` with the same name silently REPLACES the first — where `extend-type` refuses a redefinition

- **Where:** `probes/clause/redefinition-and-order.wat`, wat-rs `a3218644d`, 2026-09-17. Found
  while working out whether `defclause` could be made open (F-109's follow-up).
- **What happened:**

  ```wat
  (:wat::core::defclause :d::f ([x <- :d::A] -> :wat::core::String "a"))
  (:wat::core::defclause :d::f ([x <- :d::B] -> :wat::core::String "b"))
  (:d::f (:d::A))
  ```
  > `no clause of :d::f matches arity 1 with types [:d::A]; clauses attempted: (1: [:d::B])`

  **"clauses attempted: (1: `[:d::B]`)"** is the whole finding: the `A` clause is *gone* — not
  merged, not shadowed, not reported. The second form replaced the first silently.
- **And the comparison that makes it a defect rather than a choice:** `extend-type` in exactly this
  situation **refuses** — *"duplicate define: `:d::Asteroid/hit` already registered"* (F-109's
  original probe). So the mechanism that **can** be extended safely rejects a redefinition, and the
  mechanism that **cannot** accepts one and drops the earlier clauses. That is backwards.
- **Why it matters more than an ordinary duplicate-definition bug.** A clause set is the dispatch
  table. Losing clauses silently does not produce a wrong answer at the redefinition site; it
  produces a *missing method* somewhere else entirely, and the error names the clause set as it
  now stands, so the reader is looking at a table that never mentions the clause that was deleted.
  In a large file, or across `load-file!`, the two `defclause` forms need never be visible together.
- **This is the same family as F-107** (an explicit type argument parsed and discarded) and **F-093**
  (call sites unchecked in the Clojure spelling): something the author wrote is accepted, has no
  effect, and is never reported. For an LLM-first language that is the worst class of defect,
  because a generator cannot find it by reading its own output.
- **Class:** FIX. Whatever is decided about openness (see the design note below), a second
  `defclause` of the same name should be a `DuplicateDefine`, exactly as `extend-type` is.
- **Repro:** `wat probes/clause/redefinition-and-order.wat` (the failing case is recorded in its
  header, since it is a startup error).

#### Design note: what an `extend-clause` would have to settle

The builder's question — could there be an `extend-clause`, so a later module adds to an existing
clause set the way `extend-type` adds to a surface? — runs into one fact, measured in the same
probe: **clause order is semantically significant.** The same argument against the same two
overlapping clauses answers `"concrete clause"` or `"surface clause"` depending only on which was
written first.

That is what makes `extend-clause` a harder problem than `extend-type`, and the difference is the
**shape of the key**:

| | keyed by | can two modules collide? |
|---|---|---|
| `extend-type` | **one** type — the method lives at `<Type>/<feature>` | only by extending the *same* type for the *same* surface, which is already caught |
| `defclause` | a **tuple** of types, matched first-match-wins **with overlap allowed** | yes — `[A, Thing]` and `[Thing, B]` both match `(A, B)`, and which wins is whichever was written first |

So `extend-type` already has a coherence story for free (each type owns its slot — Rust's orphan
rule in miniature). `extend-clause` would turn a **textual** order, visible in one form, into a
**load** order determined by the dependency graph, which can change when an unrelated module is
added.

Three ways out, and they are not equally good:

1. **Require non-overlap.** Reject any two clauses whose type tuples can both match. Order then
   cannot matter and extension is safe in any order. The cost is that first-match-wins is used
   deliberately today — `wat/bracket.wat:224` dispatches `thread-enter` on `keyword` versus a type
   variable `W`, which is exactly an overlap with a fallback.
2. **Orphan rule.** Allow `extend-clause` only when some argument type in the new clause belongs to
   the extending module. Prevents two unrelated modules claiming the same tuple; keeps
   whole-program exhaustiveness checkable at link.
3. **Specificity, not textual order — what CLOS actually does.** CLOS never consults the order
   methods were written in; it computes the *most specific applicable method* from the class
   precedence list, and rejects genuinely ambiguous pairs. **That is precisely why CLOS methods can
   be open.** It would cost wat a specificity partial order over its types (concrete before
   surface, and a rule for two unrelated surfaces) and an ambiguity error where none exists today.

The third is the answer the prior art gives, and it has a pleasant property: adopting it would make
the existing closed `defclause` order-independent too, which would turn the overlap above from a
silent behaviour change into a thing the checker can talk about.

Worth weighing against all three: **F-109 found that the closed form buys a compile-time
`NoMatchingClause` at concretely-typed call sites.** That check works because the clause set is
complete at check time. Any openness either moves it to link time or gives it up.


### C-091: AoC day06 — the workload P-028 was missing, and the measurement that narrowed it

- **Where:** `aoc/day06-adapters.wat`, against a new Clojure oracle. **7 answers, all matching.**
  Chosen the way Euler's puzzles were — from the findings rather than from a list — because
  **P-028** had been raised the day before on an argument and had no real workload behind it.
- **The workload:** AoC's adapter-chain shape. Part two counts the distinct arrangements of a
  97-link chain, and the answer is **171802567918485504** — over 1.7×10¹⁷. Nothing can enumerate
  that. It is the first thing in this repository where memoisation is the difference between an
  answer and **no answer**, rather than between fast and slow.
- **And it refuted the argument P-028 was raised on.** P-028 said an LRU is the wrong primitive
  *because it is allowed to forget*. Measured, on a 26-link prefix:

  | Lru capacity | time |
  |---|---|
  | 256 | 1505 µs |
  | 4 | 1665 µs |
  | **3** — the order of the recurrence | **1823 µs** |
  | 2 | ~10000 µs |
  | 1 | ~700000 µs, varying between runs |

  `ways(v)` needs `v-1`, `v-2`, `v-3` — **exactly the three most recently used keys**. So capacity
  **3 is already enough** and 256 buys nothing. A recurrence's access pattern *is* a recency
  pattern, and an LRU is built for precisely that. The guess this file was written to test was
  wrong, and the file says so in its header rather than being quietly re-aimed.
- **What survives is narrower and better founded.** The risk is not eviction; it is **falling below
  the working set**, and the edge is a **cliff rather than a slope** — capacity 2 costs several
  times more and capacity 1 hundreds of times more, because below the threshold each miss respawns
  three calls and the recursion returns to exponential. Being one under is not a 10% regression, it
  is a different complexity class.
  So **P-028 is now an ask for a cell whose size the caller does not have to know**: for a linear
  recurrence the working set is the recurrence's order and a user can compute it; for an arbitrary
  memo it is not knowable in advance. That is a much more defensible request than "eviction is
  wrong", and it came from running the thing rather than from reasoning about it.
- **Three counts of the same number must agree** in the file: a forward fold threading a
  `PersistentMap` (no memo primitive needed), the natural recursion with an Lru memo, and the
  oracle's. They do.
- **Class:** CLEAN, with **P-028 narrowed** and its original argument withdrawn.
- **Repro:** `wat aoc/day06-adapters.wat`.


### C-092: AoC day07 — a bit-field decoder, and which half of the work F-035 actually falls on

- **Where:** `aoc/day07-packets.wat`, against a new Clojure oracle. **13 answers, all matching.**
  Chosen to press **F-035** (wat has no bit operations) with the most bit-twiddling workload there
  is: a hexadecimal transmission decoded into nested packets, 3-bit versions, 3-bit types, 4-bit
  literal groups with continue bits, and 15- or 11-bit sub-packet headers.
- **It half refuted the expectation, and that is the finding.**

  | | |
  |---|---|
  | **shifting and masking need no bit operations** | reading a 15-bit field is a fold that doubles and adds; `acc * 16 + nibble` is a shift by four; `quot`/`rem` by a power of two is a mask. The whole decoder — the part that *looks* most like bit-twiddling — is ordinary arithmetic, and no harder to write than the Clojure, which reaches for `bit-shift-right` and `bit-and` only because they are there |
  | **XOR and AND do** | neither is expressible as `+ - * quot` on whole numbers, so `:aoc::xor` and `:aoc::band` walk the two numbers **a bit at a time** — a loop per operation, where Clojure calls `bit-xor` |

- **So F-035's weight is narrower than "no bit operations" suggests, and now has a shape:** a
  program that **extracts fields** does not need them; a program that **combines values bitwise**
  does. The finding is unchanged — the verbs are still absent — but the cost lands on
  XOR/AND/OR/NOT, not on the shifting that the phrase "bit operations" makes people picture. That
  matters for prioritising it: field extraction is the common case in parsing, and it is free.
- **This is the second AoC puzzle in two days to refute the guess it was written to test** (C-091
  was the first, on P-028). Both kept the refutation in the file header rather than being re-aimed
  at something that would agree.
- **F-062 shows up mildly**: a hex digit is read with a one-character `:wat::string::subs`, because
  a String has no characters. At 40 digits that is invisible; C-083 already recorded that the
  finding's weight should track the workloads it blocks, and this is another it did not.
- **Class:** CLEAN, with **F-035 sharpened**.
- **Repro:** `wat aoc/day07-packets.wat`.


### F-111: `:wat::rational::numerator` is declared `-> i64` and returns a bigint when the value needs one — and a bigint then flows out of a function declared to return `i64`

- **Where:** found while choosing a Euler problem to press the rational surface (C-093).
  `probes/scalar/rational-accessor-type.wat`, wat-rs `a3218644d`, 2026-09-17.
- **The behaviour is deliberate and right.** `src/intrinsic/rational.rs:218-220`:
  > *"Renders as `:wat::core::i64` when it fits; `:wat::core::bigint` otherwise (never silently
  > truncated)."*

  Refusing to truncate is the correct call. **The annotation eleven lines below it does not say
  so** (`rational.rs:229`):
  > `@ret     :wat::core::i64 the numerator of n`

- **So the checker believes `i64`, and nothing catches the difference.** A user function declared
  `[n <- :wat::core::i64] -> :wat::core::i64` accepts the bigint, computes with it, and **returns a
  bigint**:

  ```
  (:r::takes-i64 (:wat::rational::numerator (bigint 2^64 as a rational)))
  => 18446744073709551616N
  ```
  The trailing `N` is the whole finding: that is a bigint leaving a function whose signature
  promises an `i64`. No error at check time; none at run time.
- **Contained, and therefore cheap to fix:** exactly **two** intrinsics have this shape —
  `numerator` and `denominator` — and both are in `rational.rs` (219/229 and 242/252).
  `grep -rn "when it fits" src/intrinsic/` finds no others.
- **Why it is worth more than a doc-comment nit.** This is wat's own stdlib handing user code a
  value of the wrong declared type, so the annotation a user reads and the annotation the checker
  enforces are both wrong together. It is the **F-107 / F-093 family** — something written,
  accepted, and never reported — but one level worse, because here the false annotation is in the
  language's own surface and every caller inherits it.
- **Three ways out, in increasing honesty:** declare `-> :wat::core::bigint` and make callers
  narrow; declare a two-variant return (`i64 | bigint`) and make the choice explicit at the call
  site; or keep the behaviour and say so in the `@ret`, so that at least the *documented* type
  matches what arrives. The first is probably right — `to-rational` already exists in the other
  direction, and a bigint that happens to be small is not a problem.
- **Class:** FIX (the annotation does not describe the function), with a CORRECT half (decide
  whether the return type should be widened or the behaviour narrowed).
- **Repro:** `wat probes/scalar/rational-accessor-type.wat`.


### F-112: `:wat::f64::` has `min`, `max`, `abs`, `clamp` and `round`; `:wat::i64::` has none of them

- **Where:** found while writing `lox/ch16-scanning.wat`'s timing harness, which needed the
  smaller of two nanosecond counts.
- **What is there.** `:wat::f64::` exposes `min`, `min-of`, `max`, `max-of`, `abs`, `clamp` and
  `round`. `:wat::i64::` exposes `<`, `<=`, `=`, `>`, `>=`, `not=`, `to-bigint`, `to-f64`,
  `to-rational`, `to-string` — comparisons and conversions, and no arithmetic helpers at all.
  There is no `:wat::core::min` or `:wat::core::max` either, and `:wat::math::` is six verbs
  (`sin cos exp ln sqrt pi`), none of them these.
- **So the smaller of two integers is hand-written, over and over.** Seven files in this
  repository define one: `paip/ch15-canonical.wat` (`imax`), `paip/ch16-expert-system.wat`
  (`imin`, `imax2` *and* `iabs2`), `sicp/ch25-generic-operations.wat` and
  `sicp/ch52-register-machine.wat` (`imax`), `probes/lox/char-access-cost.wat` and
  `lox/ch16-scanning.wat` (`imin`), `semaphores/ch02-basic-patterns.wat` (`max-of`). Every one is
  the same three tokens: `(if (< a b) a b)`.
- **Why it matters more than its size.** Every measurement in this repository takes the minimum
  of N runs — the discipline R-003 asks for — so a timing harness is the first thing anyone
  writes and an integer `min` is the first thing it needs. An LLM writing wat will reach for
  `:wat::core::min` (Clojure's spelling), get *not a builtin, not a registered function*, then
  reach for `:wat::i64::min` by analogy with `:wat::f64::min`, and get the same. The third guess
  is to write it, which is what happened seven times here.
- **Class:** EXTEND, and a small one: five verbs mirroring the `f64` module. The `f64` module is
  the specification; only the `i64` implementations are missing.
- **Repro:** `grep -c ':wat::i64::min' wat-rs/src` answers 0; `:wat::f64::min` is in
  `src/intrinsic/`. Any program calling `(:wat::core::min 1 2)` fails to resolve.

### F-113: `:wat::core::assoc` updates a `defrecord` field — worth up to 5.8× over restating — and the user-facing reference says it is "polymorphic over HashMap/Vec"

- **Where:** `probes/lox/record-update.wat`, found while writing `lox/lib/scanner.wat` (C-099).
- **What is true.** `(:wat::core::assoc r :field v)` takes a `defrecord`, changes one field and
  answers **the same nominal type** — it type-checks as `-> :t::R` and the other fields carry
  over. So the immutable-update idiom every state-carrying program needs already exists.
- **What it is worth.** Restating the other fields reads each one at F-096's **6130 ns**;
  `assoc` reads none of them. `probes/lox/record-update.wat`, 20 000 updates, arms interleaved,
  each warmed, each taking first position once:

  | record | restate one field | `assoc` one field | restate costs |
  |---|---|---|---|
  | 2 fields | 31 µs | 18 µs | **169%** |
  | 5 fields | 58 µs | 20 µs | **294%** |
  | 9 fields | 102 µs | 18 µs | **578%** |

  `assoc` is **flat** in the field count and restating is linear in it, which is the shape the
  6130 ns accessor predicts. On C-099's five-field `Scanner` this alone moved the
  record-per-character scanner from ~190 ns/char to ~140, and its ratio against the flat shape
  from 2.5× to 1.9×.
- **The CLEAN half, and it is why none of this was used until now.** The user guide's container
  section is titled *"Containers — polymorphic `get` / `assoc` / `conj` / `contains?` / `length`"*
  and its table has three columns: `HashMap`, `HashSet`, `Vec`. **Record is not a column.** The
  verb reference then says:

  > `:wat::core::assoc` | `coll k v` | new collection — polymorphic over HashMap/Vec (arc 025)

  `Vec` is the one container in that table whose `assoc` cell reads ***illegal** (arc 146)* — the
  same document, 2 300 lines earlier. So the one-line reference for `assoc` names a container it
  refuses and omits both it serves (`PersistentMap` and `Record`). It is recorded correctly in
  `docs/COLLECTION-CAPABILITIES.md:66` — *"Record/assoc = field update (flavor-preserving) —
  done"* — an internal capability grid. That is the F-109 shape exactly: the mechanism exists, it
  is written down where the builder looks and not where a user does, and the user-facing line
  that does mention the verb is wrong about it.
- **The CORRECT half.** `assoc`'s two mistakes are deferred to run time, where the constructor
  catches both at check time, with the same information available (the field's declared type is in
  the `defrecord`, the key is a literal keyword):

  | mistake | `(:t::R :a "s" …)` | `(assoc r :a "s")` |
  |---|---|---|
  | wrong field type | **CheckErrors** at startup | `TypeMismatch` at run time |
  | unknown field | **CheckErrors** at startup | `UnknownField` at run time |

  Both runtime messages are good ones — *"unknown field 'zzz' on record t::R; available: [a, b]"*
  — they just arrive after the program has started.
- **Cost paid before finding it:** this repository restated fields by hand in every
  record-updating program — `lox/lib/chunk.wat`'s `write` and `add-constant`, `lox/lib/vm.wat`,
  `okasaki/lib/queue.wat`, `mal/lib/env.wat` among them.
- **Class:** CLEAN (one column in the container table, one corrected reference line), plus
  CORRECT (two static errors reported late).
- **Repro:** `wat probes/lox/record-update.wat`.

### F-114: the refusal to put a function in a `defrecord` calls the function type a "struct", reasons about structs, offers no remedy, and gives no location in the user's file

- **Where:** `probes/lox/rule-table.wat`, building Crafting Interpreters' rule table (C-100).
- **The refusal, in full:**

  > `containment rule (arc 293.W): pure aggregate ":t::R" may only hold pure fields — field "f"
  > has impure (struct) type "[:wat::core::i64 :-> :wat::core::i64]". A struct cannot be
  > reconstructed from EDN bytes across a comms boundary; a record or holon holding a struct
  > field could never cross — it must not exist.`
  > `:location {:file "src/check.rs" :line 15086}`

- **The rule is right.** A `defrecord` may cross a service boundary and a closure cannot be sent,
  so a record may not hold one. Nothing here disputes that.
- **Four things are wrong with how it is said.**
  1. **The field is not a struct.** It is a function type, `[i64 :-> i64]`, written in wat's own
     arrow syntax. The message calls it an "impure (struct) type" and then explains itself
     entirely in terms of structs — *"A struct cannot be reconstructed from EDN bytes"*, *"a
     record or holon holding a **struct** field"*. A reader who did not write a struct is being
     told about structs.
  2. **No remedy, and there are two.** The error carries no `:remedies` key at all (a sibling
     `TypeMismatch` carries `:remedies []`). Both remedies work and neither is guessable from the
     text: a **`defstruct`** holds the function fine, **with accessors**, and reads like the C it
     is porting; an `:wat::enum::Impure` variant holds it too, at the cost of a `match` per field
     read. `defstruct` is the honest answer *by the rule's own logic* — F-040 records that a
     `defstruct` may not cross a boundary and a `defrecord` may, which is precisely the
     distinction being enforced. The refusal never names it.
  3. **The location is `src/check.rs:15086`** — the F-006/F-008 family, sixth witness — and,
     unlike those, there is **no span in the user's file at all**. The aggregate and field names
     are in the payload (`:aggregate`, `:field`), so the offending declaration is findable by
     grep, but the error points at wat-rs.
  4. **It is the mirror of F-040 and inherits its gap.** F-040: a `defstruct` inside a Pure enum
     is refused with a message that offers only `:wat::enum::Impure`, never `defrecord`. Here a
     function inside a `defrecord` is refused with a message that offers nothing. Both times the
     aggregate the author should have reached for is the one the diagnostic does not name.
- **What it costs.** "A table of functions" — a vtable, a strategy table, a dispatch table, a
  parser's rule table — is a shape any port of C or Java arrives at, and the first spelling
  anyone tries is a record. The refusal reads as *wat cannot carry functions in aggregates*,
  which is false, and this repository's own note to itself
  (`feedback-use-wat-surfaces.md`: "an interface is `defsurface` + `extend-type`, not a struct of
  closures") would have sent the reader further from the one-word answer.
- **Class:** CORRECT (the wording, the missing remedy, the location), with the CLEAN half being
  that nothing user-facing says which aggregate may hold a function value.
- **Repro:** `wat probes/lox/rule-table.wat` — attempt 1 is commented out with the verbatim
  refusal; attempts 2 and 3 both run.

### F-115: a variant pattern must name every field, so adding a field to an enum edits every match on it — including the ones that do not want it

- **Promoted from** the friction entry *"a variant pattern must name every field"* (Little
  Learner, 2026-09-15), which recorded the refusal and classed it *possibly deliberate*. Chapter
  21 of Crafting Interpreters (C-104) is the workload that shows what it costs over time, so it
  is written up as a task here rather than left as a note.
- **The rule.** `[:ll::V.Dual {:r r} …]` is refused — *"map pattern has 1 key(s), variant
  `:ll::V.Dual` declares 2"* — and each such refusal also counts as a missing arm, so one short
  pattern reports two errors. Clojure's map destructuring takes any subset of keys; here every
  arm binds every field, used or not.
- **What it costs, as a sequence rather than an instance.** Chapter 21 gives the Lox VM state
  beyond its stack — a globals table and an output — so `:loxv::Out` gained two fields. The
  compile then failed in **`lox/ch18-types-of-values.wat`**, at a function that counts
  instructions and wants neither new field:

  > `map pattern has 2 key(s), variant ':loxv::Out.Ok' declares 4`
  > `non-exhaustive: enum :loxv::Out missing arm(s) for variant(s): Ok, Err`

  A chapter about **tagged unions**, edited by a chapter about **global variables**, to name two
  fields it discards. Chapters 22 through 29 each extend the VM's state again — locals, call
  frames, upvalues, a heap — so the same edit is due at each of them, in every file that ever
  matched the carrier.
- **The ask is narrow, and it does not touch the house rule.** A **field** rest pattern
  (`{:steps k ..}`, or simply permitting a subset as Clojure does) says nothing about which
  VARIANTS are covered, so exhaustiveness over the enum — the property this repository relies on,
  and the reason it bans `_` arms — is untouched. What is being asked for is the ability to
  ignore a field, not the ability to ignore a case. The two are conflated by the current rule:
  the refusal for a short field list is delivered *as* a non-exhaustiveness error, which is why
  one mistake reports twice and why the remedy the message suggests (`_` wildcard) is the wrong
  one.
- **Why it matters more for generated code.** An LLM editing a wat program adds a field to a
  record or variant and has no way to know which files must change until the whole program is
  re-checked; the diagnostics then blame files that are correct about everything they meant.
  F-107 and F-110's family is "written, accepted, no effect"; this is the opposite and just as
  expensive — "unchanged, refused, must be edited".
- **Class:** EXTEND (a field rest pattern), with a CORRECT half (a short field list should not be
  reported as a missing arm, and should not be told to write `_`).
- **Repro:** `./run.sh lox` at the commit that added `:globals` and `:out` to `:loxv::Out`; or
  change any `{:r r :k k}` in `books/little-learner/lib/malt.wat` to `{:r r}`.

### F-116: a vector has no `pop`, so a stack machine's pop is a rebuild — and on the type called `Vector` that rebuild is QUADRATIC (121 ms for one pop at depth 4000)

- **Where:** `probes/lox/stack-ops.wat`, `lox/lib/v-vm.wat`, `lox/ch22-local-variables.wat`
  (C-105). Adjacent to F-104 and **not fixed by it**: `assoc`-by-index changes an element, it
  does not shorten a vector.
- **What is missing.** To take the top element off a vector there is no `pop`, no `subvec`, no
  `butlast`; `:wat::core::take` and `drop` answer a **Stream** with no way back (F-088); and
  `:wat::vector::` is six verbs with none of them either (F-108). So a pop is a rebuild loop.
- **Measured** — one push and one pop at depth, min of 2, arms interleaved, against a control
  (`nth` of the last element, which is O(1), so its column is the loop's own cost):

  | depth | control (`nth`) | `Vector` push | `Vector` rebuild-pop | `PersistentVector` push | `PV` rebuild-pop |
  |---|---|---|---|---|---|
  | 10 | 8.5 µs | 6.6 µs | 60 µs | 6.8 µs | 75 µs |
  | 100 | 8.4 µs | 7.8 µs | 610 µs | 7.0 µs | 755 µs |
  | 1 000 | 8.4 µs | 19.4 µs | **12.0 ms** | 8.0 µs | 8.3 ms |
  | 4 000 | 8.5 µs | 55.9 µs | **121 ms** | 8.0 µs | 34 ms |

- **Three results, and they are separable.**
  1. **`conj` on a `Vector` is O(n)** — F-023 said it clones; this prices it. 6.6 µs at depth 10,
     55.9 µs at 4 000, against a flat 8.5 µs control.
  2. **`conj` on a `PersistentVector` is flat** — 6.8 µs to 8.0 µs across a 400× range. The
     structural sharing its name promises is real.
  3. **So the rebuild-pop is quadratic on one type and linear on the other.** At depth 4 000 the
     `PersistentVector` rebuild costs 34 ms, which is 4 000 × the 8.5 µs control **and nothing
     else** — the conjs themselves are free and it is all interpreted loop. The `Vector` rebuild
     costs 121 ms, and the extra 87 ms is the clones.
- **What this means for a VM, which is the point.** A stack machine pops on almost every
  instruction. Today:
  - on `Vector` — the type whose name matches, the one `:wat::core::` serves, and the one every
    port in this repository reaches for — **a pop is quadratic in the stack depth**;
  - on `PersistentVector` — which `:wat::vector::` serves and which **rejects** the type called
    `Vector` (F-108) — a pop is linear;
  - with a `pop` verb it would be the control column: about **8 µs**, four orders of magnitude
    below the 121 ms above.
- **So there are two asks and they should not be merged.** F-104's queued *Index-assoc* fixes
  `OP_SET_LOCAL` (`stack[slot] = v`) and does nothing for `OP_POP`. A **`pop` / `subvec`** is the
  second one. A VM needs both.
- **And a piece of advice that costs nothing:** the naming actively misleads here. The type
  called `Vector` is the wrong one to build a stack out of, and the namespace called
  `:wat::vector::` is the one that refuses it.
- **Class:** EXTEND (a `pop`, and separately `subvec`), with the IMPROVE half being that
  `Vector`'s `conj` is a clone where its sibling's is not, and nothing user-facing says so.
- **Repro:** `wat probes/lox/stack-ops.wat`.

### F-117: nothing in wat can share a mutable location, and `CLOJURE-ROSETTA.md` says the alternatives have "same semantic outcomes" — which is true for threading state and false for ALIASING it

- **Where:** Crafting Interpreters chapters 25 and 27 (C-108, C-110), which needed the same thing
  twice and built the same workaround twice.
- **The design is deliberate and this finding does not dispute it.** `CLOJURE-ROSETTA.md` §4,
  *"Mutation-free by construction"*: no `set!`, no mutable bindings; state changes by returning
  new values, by messaging a spawned program, or through "substrate-level atomic primitives
  (rarely user-facing)". It then shows Clojure's `atom` beside wat's `let`-rebinding and says:

  > Same semantic outcomes; different mechanism.

- **That sentence is right about THREADING state and wrong about ALIASING it.** Rebinding works
  when one holder owns the value. It cannot express two independent names for one mutable thing:

  ```
  var a = f; a.x = 2; print f.x;      // Lox prints 2
  ```

  There is no sequence of `let` rebindings that makes `f` see a write through `a`, because `f` and
  `a` are different bindings of the same immutable value. This is not a missing convenience; it is
  the defining requirement of an object with identity, and of a closed-over variable shared by two
  closures.
- **Two chapters needed it, and both had to build the same thing.** Nystrom's upvalue is a
  `Value*` into the stack; his instance is a pointer with a field table. Both became **an index
  into a table the VM owns** — `Cell.OnStack idx | Closed v` for upvalues, `Obj.Instance` for
  instances — with the value holding an integer id. Sharing then works because two values hold the
  same id.
- **And the workaround has a second cost that is easy to miss: the table leaks.** A hand-built
  heap has to be swept by hand. C-109's mark-sweep collector exists because nothing else was going
  to reclaim those cells — thirty closures in a loop grew the table to thirty entries with the
  collector switched off. **Wanting one shared mutable location cost a table, an id scheme, a
  collector and a root set.**
- **What is actually available today**, and why neither answers:
  - **a spawned program** — F-051 prices a message at ~224 µs, about a hundred function calls.
    That is a service, not an object graph; a VM cannot pay it per field write.
  - **`:wat::cache::Lru`** — a live handle, so it really is shared mutable state, but F-114's
    containment rule means **no value can hold one**: not a `defrecord`, not a Pure enum. So it
    cannot be the thing a Lox instance *is*.
- **Class:** CLEAN (one sentence in the rosetta overclaims; the honest version distinguishes
  threading from aliasing and points at the index-table pattern), plus EXTEND if the builder wants
  it: an in-process reference cell a value may hold. The evidence for the EXTEND half is that
  every interpreter-shaped program will build the same table, and then have to collect it.
- **Repro:** `./run.sh lox`; `lox/ch25-closures.wat` and `lox/ch27-classes-and-instances.wat`
  state the problem in their headers, and `lox/ch26-garbage-collection.wat` measures what the
  workaround leaks.

### F-118: wat cannot author a byte. There is no `u8` literal and no `i64 -> u8`, so `Bytes::from-hex` is the only door to binary — and it is not documented as one

- **Where:** `elf/hello.wat` (C-115), which emits a native executable and had to go through that
  door to do it.
- **What is refused.** An integer literal is an `i64`. `(:wat::core::Vector :- [:wat::core::u8]
  127)` is a **check-time** error —

  > `:wat::core::vec: parameter #1 expects :wat::core::u8; got :wat::core::i64`

  — and there is no conversion: no `:wat::i64::to-u8`, no `u8::from`, no cast, and no arithmetic
  on `u8` at all (`:wat::u8::` is empty). An untyped literal vector handed straight to
  `IOWriter/write-all` fails the same way, so the expectation cannot be dodged by inference.
- **What produces a `Vector<u8>`, exhaustively.** Three things:
  1. `:wat::io::IOReader/read` and `read-all` — bytes that already exist in a file;
  2. `:wat::io::IOWriter/to-bytes` — bytes already written, and the only way to put bytes *in*
     is `write-string` (a String's UTF-8) or `write`/`write-all` (u8s you already have);
  3. **`:wat::core::Bytes::from-hex`**, which decodes a String of hex digits.
- **Only the third can invent a byte**, and only it can produce one above `0x7f` — a String is
  UTF-8, so `0xb8` inside one is two bytes, not one. Every x86-64 `mov` opcode is above `0x7f`,
  which is exactly where this stops being academic.
- **`from-hex` answers a `Bytes`, and `write-all` wants a `Vector<u8>` — and it works anyway.**
  The two are the same representation, so the checker accepts a `Bytes` where the vector is
  declared, and `Bytes::to-hex` accepts a `Vector<u8>` read back off the disk. That round trip is
  load-bearing for anything binary, and **nothing says it is supposed to work**: `Bytes` appears
  in four intrinsic signatures (`to-hex`, `from-hex`, and two holon verbs) and in no user-facing
  page. A reader would conclude the two types do not meet.
- **What it costs.** A wat program can copy bytes and can write text, but without `from-hex` it
  could not author an object file, an ELF, a PNG, a zip, a wasm module or a wire frame — anything
  whose format is not UTF-8. With `from-hex` it can, at the cost of building everything as a hex
  string and decoding once at the end. That is a real technique (C-115 uses it, and it is clean)
  but it is a discovery, not a documented route, and it doubles the working size of every buffer.
- **Class:** EXTEND (`:wat::i64::to-u8`, or a `u8` literal, or an explicit `Bytes <-> Vector<u8>`
  pair), with a CLEAN half that is larger than the extend half: **`Bytes` is the binary-authoring
  surface and no user-facing page says so.**
- **Repro:** `wat elf/hello.wat` for the working route; for the refusal,
  `(:wat::core::Vector :- [:wat::core::u8] 127)` in any program.

### F-119: wat's OS surface lives inside the interpreter, so a compiled wat program cannot reach it — there is no intrinsic set defined independently of the evaluator

- **Where:** `elf/compile.wat`, `elf/native/*.wat` (C-118). Found by walking into it: the compiler
  grew `fork`, `clone`, `mmap` and `wait`, and at that moment the language it compiles stopped
  being a subset of the language the interpreter runs.
- **The shape of it.** Everything in `elf/src/` is wat, and every one of those programs is checked
  by running it **both ways** — compiled binary and wat interpreter — and requiring identical
  output. That differential test is the strongest oracle in this repository, and it carried the
  compiler through `if`, `let`, recursion and a calling convention. It stops dead at the first
  syscall: the interpreter has no `wat.os/fork`, so `elf/native/fork.wat` will not even resolve
  (*"unresolved reference :wat::os::exit"*), and those programs have no oracle but a fixed
  expected output.
- **Why the interpreter cannot help.** wat's OS surface is `:wat::io::`, `:wat::kernel::spawn-*`,
  `:wat::bracket::` and `:wat::service::` — all implemented in Rust, inside the evaluator, as
  intrinsics that take evaluated `Value`s. A compiled program has no evaluator and no `Value`; it
  has registers and a syscall instruction. **There is no layer in between**: no FFI, no calling
  convention for a wat program to reach a native function, and no specification of what a wat
  primitive *is* other than "what this Rust function does".
- **This is not a defect.** It is the question every language faces once compilation is on the
  table, and C's answer is libc: a C compiler does not implement `write` either. wat has not had
  to answer it yet because there has only ever been one implementation. The finding is that
  **there is now evidence the question is live**, and a shape for the answer: a compiled wat needs
  an intrinsic set defined independently of the evaluator — a list of primitives with a stated
  ABI, which the interpreter implements one way and a compiler another.
- **What it costs if nobody answers it.** The two languages drift apart exactly at the interesting
  boundary. Nine compiled programs in `elf/` are evidence: six are wat and are checked against
  wat; three are a *dialect* that only the compiler accepts, and the only thing standing behind
  their correctness is a hand-written expectation in a shell script. Multiply that by every
  primitive a real program uses — files, sockets, time, spawn — and the compiler's language and
  the interpreter's language are different languages that share a reader.
- **Class:** EXTEND, and a design question rather than a bug: **name the intrinsics and their ABI**,
  so that "wat" means one language whichever implementation runs it.
- **Repro:** `wat elf/native/fork.wat` — the interpreter refuses it with five unresolved
  references; `tools/elf-run.sh` — the same program, compiled, prints `1 2 7 1 1 4`.

### F-120: a wat String is specified only by its Rust implementation — `println`'s EDN escaping is undocumented behaviour, and `length` counts characters with no byte-length verb to compile against

- **Where:** `elf/compile.wat` (`:c::rt-print-str`, `:c::str-lit`), `elf/src/strings.wat`,
  `elf/bad/nonascii.wat`, `elf/refuse-nonascii.wat` (C-119). Found by teaching the compiler
  strings, which is the first time anything outside the interpreter had to *be* a wat String.
- **The rendering half.** `:wat::kernel::println` renders a String as EDN, so a compiled
  `println` has to reproduce that exactly or the differential test goes red. What it reproduces
  is: quotes around the whole thing; `"` → `\"`; `\` → `\\`; newline → `\n`; tab → `\t`;
  carriage return → `\r`; **and every other byte passed through raw**, so `é` goes out as its
  two UTF-8 bytes and not as an escape.
- **Every line of that list was obtained by asking the interpreter what it printed.** There is no
  document that says which characters escape, no document that says non-ASCII does not, and no
  test outside wat-rs that would notice if the answer changed. The compiler's 158-byte
  `print_str` is, quite literally, a guess pinned down by experiment and held in place by one
  differential test.
- **The measuring half.** A string in memory has a length in **bytes**. `:wat::string::length`
  answers a length in **characters** — `(:wat::string::length "é")` is `1` — and the string
  surface has no byte-length verb at all (`concat contains? ends-with? join length split
  starts-with? subs to-lowercase to-uppercase trim` and friends; not one of them measures bytes).
  So a compiler either restricts itself to ASCII, where the two agree, or reimplements UTF-8
  length before it can lay a single string out. This one restricts itself, and refuses the rest:
  `elf/bad/nonascii.wat` is valid wat that prints `"café"` under the interpreter and is rejected
  at compile time rather than silently mis-measured.
- **Why this is worth writing down.** It is the same root as **F-119** one level lower. F-119 is
  that wat's *primitives* are defined only as Rust functions; this is that wat's *values* are
  defined only as Rust data. Both are invisible while there is one implementation and both bite
  immediately when there are two. The difference is that this one is cheap to close: the escape
  set is six rules and a sentence about non-ASCII.
- **Class:** IMPROVE — write the rendering down as part of the language rather than as behaviour
  of one printer — with a small EXTEND inside it: a byte-length verb, so that code which has to
  think in bytes can.
- **Repro:** `elf/src/strings.wat` run both ways (`tools/elf-run.sh`) is the positive case;
  `wat elf/refuse-nonascii.wat` is the refusal; `wat elf/bad/nonascii.wat` is the same program
  under the interpreter, printing `"café"`.

### F-121: `/` has no Clojure spelling — `wat.core//` misreads as `:wat::core/::`, and bare `/` does not resolve either

- **Where:** found while adding `/` to `elf/`'s compiler (C-123). `elf/src/logic.wat` has to write
  `(:wat::core::/ 7 2)` in the *keyword* spelling in a file that is otherwise entirely
  Clojure-spelled, which is the only way to say it.
- **What happens.** `(wat.core// 7 2)` is refused with *"unresolved reference `:wat::core/::`"* —
  the reader has split it at the first slash and rebuilt the name wrong. `(/ 7 2)` is refused
  too. `(wat.core/quot 7 2)` answers `3`, and `(:wat::core::/ 7 2)` answers `3`, so the function
  is there; it is only the Clojure spelling of its name that cannot be written.
- **Clojure handles this, deliberately.** `/` is the one symbol allowed to contain a slash, and
  the reader special-cases it. Checked against clj 1.12.6:
  `(println (clojure.core// 7 2) (quote clojure.core//) (= clojure.core// /))` prints
  `7/2 clojure.core// true`.
- **Why it matters here rather than being a curiosity.** wat is migrating *to* the Clojure/EDN
  spelling, and this repository writes new ports in it. Today a file in that spelling cannot
  divide by name: it has to drop into `:wat::core::/` for one form, in the middle of a file that
  uses `wat.core/` everywhere else. That is a visible seam in the target syntax, in the most
  ordinary arithmetic there is.
- **Class:** FIX — the reader's one special case, the same one Clojure makes.
- **Repro:**
  `echo '(wat.core/defn user/main [] :- wat.type/nil (wat.kernel/println (wat.core// 7 2)))' > /tmp/d.wat && wat /tmp/d.wat`
  — and the same file with `(:wat::core::/ 7 2)`, which prints `3`.

### F-122: `defrecord` and `typealias` cannot be written in the Clojure spelling, and `defrecord` says so with an internal macro error

- **Where:** found while compiling records (C-124). `elf/src/vectors.wat` declares its record and
  its type alias in the **keyword** spelling in a file that is otherwise entirely Clojure-spelled,
  because that is the only way to write them.
- **What happens.**
  - `(wat.core/typealias user/R (wat.core/Vector :- [wat.type/i64]))` →
    *"malformed typealias declaration: name must be a keyword; got symbol"*. Clear, correct,
    and it names the rule.
  - `(wat.core/defrecord user/P [x <- wat.type/i64])` →
    *"macro `:wat::core::defrecord` — program body eval failed"*, caused by
    *"`:wat::keyword::to-string`: expected keyword, got `wat::WatAST`"*. The rule is the same one,
    but the message is the macro's internals leaking: it names a function the author never
    called, and does not say that the record's name has to be a keyword.
  - Both work verbatim in the keyword spelling: `(:wat::core::defrecord :user::P [x <- :wat::core::i64])`.
- **Why it matters.** wat is migrating *to* the Clojure/EDN spelling. A program can be written in
  it right up to the point where it declares a type — and then has to switch, for the two forms
  that introduce every data structure a program has. `elf/src/vectors.wat` carries the seam in
  its header, next to the one F-121 causes for `/`.
- **Two separate asks.** EXTEND: accept a symbol name in both forms, the way `defn` already
  accepts `user/main`. CORRECT: until then, `defrecord` should refuse the way `typealias` does —
  *"name must be a keyword; got symbol"* — rather than failing inside `wat/Record.wat` with a
  type mismatch on a helper.
- **Repro:** `echo '(wat.core/defrecord user/P [x <- wat.type/i64])' > /tmp/r.wat && wat /tmp/r.wat`,
  and the same with `typealias`, which gives the good message.

### F-123: `Vector/conj` is a full copy, wat-rs has measured it and says so **in a source comment** — and the docs a user reads do not

- **Where:** `wat-rs/src/collection/eval.rs:280` (`vector_conj_inner`) and `:922`. Found while
  asking whether a compiled wat needs a collector (C-126), and it turned out to be a finding
  about **where the knowledge lives**, not about the code.
- **The code copies unconditionally**, and cannot do otherwise: `Arc::make_mut` is the standard
  "clone only if shared" primitive and wat-rs uses it in 27 places, but it needs `&mut Arc` and
  `vector_conj_inner` has `&Value`. A uniqueness check is not expressible from that signature.
  In an accumulator loop it would not fire anyway — the environment slot and the argument each
  hold an `Arc`, so the count is 2 — and getting it to 1 needs the evaluator to *move* at a
  variable's last use, which is liveness analysis. **That is the same wall `elf/`'s compiler hits
  from the other side (C-126): a pure `conj` cannot mutate its argument unless something proves
  the argument is dead, and neither implementation has that proof.**
- **wat-rs already knows all of this.** The comment on `vector_extend_inner` says so, with its
  own numbers: *"`stream->vec` drained a Stream with one `conj` per element, and
  `vector_conj_inner` copies the whole accumulator each time — so `(into [] (map f coll))`, the
  language's standard materializer, was QUADRATIC: 8,112 ms at n=40,000 against 113 ms for the
  identical drain into an rpds accumulator (structural sharing)"*. And it was fixed — for that
  one path, by adding `Vector/extend`.
- **Reproduced from the outside, on the path that was not fixed.** Building a collection with an
  explicit `conj` loop, 20000 elements: **`Vector` 4142 ms, `PersistentVector` 655 ms** — 6.3x.
  F-116 measured the same shape at depth 4000 (121 ms vs 34 ms). The memory is fine either way:
  peak RSS grows *linearly* (70.4 MB at n=5000 to 79.5 MB at n=40000) because each dead clone is
  dropped immediately. It is purely time.
- **So the gap is not the implementation, it is the route from the measurement to the user.** The
  numbers exist, in a comment, on a different function, explaining a fix to a different path.
  A user writing the ordinary `(conj acc x)` accumulator — the shape `wat-rs/docs/
  ITERATION-PATTERNS.md` teaches for building up state — gets the quadratic and no signpost.
- **Class:** CLEAN (docs behind the code): say in the iteration docs that building a collection
  element by element wants `PersistentVector`, because `Vector`'s `conj` copies, and that it is a
  6x difference at twenty thousand elements.
- **Repro:** the two loops in C-126's entry.

### C-093: Euler p57 and p71 — the rational surface, and three corrections to this repository's own record

- **Where:** `euler/p57-p71-rationals.wat`, against a new Clojure oracle. **13 answers, all
  matching.** Chosen the way the first Euler file was — from the findings — to press
  `:wat::rational::` the way p16/p20/p25 pressed the bigint surface.
- **Three corrections came out of choosing the problems, and they matter more than the answers.**
  1. **C-077 and C-089 said `:wat::rational::` is "four verbs (`+ - *`, `to-f64`) with no division,
     no comparison and no `to-string`". Wrong on three counts.** It is **seven** verbs —
     `+ - * /`, `numerator`, `denominator`, `to-f64`; division **exists**; equality **works**
     (`(= 1/2 2/4)` is true, so rationals normalise); and there is a rational **literal** — `3/4`
     reads and `(+ 3/4 1/4)` is `1N`. The wrong count came from grepping only `docs/` and `wat/`
     and missing `src/`. Both entries are corrected in place.
  2. **What is actually missing is ORDERING**, and p71 is the problem that needs it:
     > `:wat::core::<: parameter #1 expects an orderable type (i64, u8, f64, S…)`

     So p71 cannot compare two fractions and cross-multiplies instead — `a/b < c/d` becomes
     `a*d < c*b`, correct for positive denominators and silently wrong for a negative one. That is
     a precondition the type system cannot state, the same shape PAIP ch7's `isolate` had (C-085).
  3. **This is F-047 generalised, and the generalisation is tidy.** Both arbitrary-precision
     numeric types support equality and neither supports order — and they are the **same two** that
     lack a `to-string` (F-060's correction). One sentence covers all of it: **bigint and rational
     can be built, combined and compared for equality, and cannot be ordered or printed.**
- **p57 needs the bigint half**, and pays F-060's tax twice: the thousandth numerator is **383**
  digits, so the convergents must be bigints, and `:wat::core::str` answers `…N`, so the file
  carries a `bigstr` that strips the suffix — once for the digit count and once for the digits.
  Clojure's `(str 3N)` is `"3"`; wat's is `"3N"`, and the first run of this file failed on exactly
  that.
- **And it turned up F-111** on the way: `numerator` is annotated `@ret :wat::core::i64` and
  deliberately returns a **bigint** when the value needs one, so a bigint flows out of a user
  function declared to return `i64` with nothing reported.
- **Class:** CLEAN, with two of this repository's own claims corrected and **F-111** raised.
- **Repro:** `wat euler/p57-p71-rationals.wat`.


### C-094: Downey chapter 2 — and the lost update that C-053 said could not happen

- **Where:** `semaphores/lib/sem.wat` (a counting semaphore, which is the whole of Downey's book)
  and `semaphores/ch02-basic-patterns.wat`.
- **The correction first, because it is the point.** **C-053** reported that wat's zero-mutex claim
  holds and concluded *"the first several puzzles have no wat form because the hazard they remove
  cannot occur."* That conclusion was wrong, and wrong in the direction that flatters wat.
  C-053 measured a read-modify-write written as **one service round**, and a round is atomic — the
  service handles them one at a time. Split the same increment across **two** rounds (`peek`, then
  `set`) and the classic race is back:

  | 8 workers × 50 increments, expected 400 | run 1 | run 2 | run 3 | run 4 |
  |---|---|---|---|---|
  | unguarded, read and write in separate rounds | **93** | **94** | **96** | **84** |
  | the same, guarded by a semaphore at 1 | 400 | 400 | 400 | 400 |

  **About 77% of the updates are lost**, reproducibly, and the mutex fixes it deterministically on
  every run. The honest claim is narrower and more useful than the one first written: **a service
  round is atomic; a program is not.** The design removes the hazard exactly when the whole
  read-modify-write fits in one message — and nothing in the type system says when it does not.
- **So Downey's book has a direct wat form after all**, which is why `sem.wat` exists: one service
  hosting many named semaphores, `signal` incrementing, and `try` decrementing-if-positive **in a
  single round**, so the test-and-decrement cannot itself race.
- **The other three patterns of chapter 2 all hold:** multiplex at 3 never let a fourth in (busiest
  crowd observed: **3**); signalling put A's work strictly before B's release; the mutex is a
  semaphore at 1 and needs no separate machinery.
- **And every one of them pays F-102.** `wait` cannot block, so it is try-and-retry, and the
  guarded counter spent **~7700 poll round-trips** on the mutex alone — at F-051's ~224 µs that is
  most of the run. Downey's semaphore costs one context switch; this one costs a service round per
  attempt. That number is the price of the missing primitive, reported by every puzzle rather than
  asserted once.
- **Class:** CLEAN, with **C-053's headline claim narrowed**.
- **Repro:** `wat semaphores/ch02-basic-patterns.wat`.


### C-095: Downey chapter 4 — the classical problems, and the deadlock that would not happen

- **Where:** `semaphores/ch04-classical.wat`, on the semaphore of C-094. Producer-consumer with a
  bounded buffer, readers-writers, and the dining philosophers both ways.
- **The three that work:**

  | | |
  |---|---|
  | producer-consumer | 8/8 items drained, buffer left empty, **high-water 3 of a 3-slot buffer** — the bound held |
  | readers-writers | no writer ever shared the room; **4 readers inside together** |
  | philosophers with a footman | 5/5 ate |

- **And the one that should not have worked. Downey's worked deadlock does not occur.** Five
  philosophers each taking their left fork first is *the* textbook deadlock, and here they ate
  **5/5 on five consecutive runs**. That is evidence about the **thread pool**, not about the
  algorithm: **F-094** measured `bracket::map` at 29% of what the same machine does with OS
  processes, and philosophers who run nearly serially never hold a fork anyone else is waiting for.
  **This is the worse of the two possible outcomes.** A design the book calls broken *passes*
  here — so it would pass in testing and deadlock later on a scheduler that actually interleaves.
  The Little Book of Semaphores is a self-oracling corpus (a wrong implementation fails in a way
  the book names) **only when the scheduler cooperates**, and on this runtime it does not. That is
  worth knowing before anyone uses wat's thread pool to validate a concurrent design.
- **A deadlock I wrote myself, kept because it is the same lesson twice.** The first version ran
  the producers through `bracket::map` and consumed *afterwards*. With a 3-slot buffer the
  producers filled it and spun on `spaces` forever — and because a wait is a spin (**F-102**), that
  was not a blocked program but a **hot loop that never returned**. In a language with blocking it
  would have deadlocked visibly, with threads parked and a stack to inspect; here it burned CPU and
  looked like slowness. The consumer now runs as one of the pool's workers and every wait is
  bounded, so a stall is reported rather than hung.
- **And a measurement artefact worth recording, because it failed first.** Readers-writers reported
  a violation until the check was fixed: `readers` is incremented *before* the first reader waits
  on `room-empty`, so a writer legitimately holding the room sees `readers = 1` for a reader that
  has not entered. The algorithm was never wrong; the instrument was. The file now counts `inside`
  separately and says why.
- **Class:** CLEAN, with **F-094's consequence sharpened** — the pool is not merely slow, it is too
  weakly interleaved to exhibit a textbook race.
- **Repro:** `wat semaphores/ch04-classical.wat`.


### C-096: Downey chapters 5 and 6 — and C-094's hazard reappearing, by accident, in the instrument

- **Where:** `semaphores/ch05-less-classical.wat`, `semaphores/ch06-not-so-classical.wat`. Dining
  savages, the barbershop, building H2O and river crossing; then search-insert-delete, the unisex
  bathroom, the baboon rope and Modus Hall. All invariants hold.

  | | |
  |---|---|
  | savages | 6/6 ate, nobody from an empty pot, cook woken once |
  | barbershop | served + turned away = 8 of 8 arrivals; **never more than 3 in a 3-chair shop** |
  | H2O | 4 molecules from 12 atoms, **every one exactly 2H + 1O** |
  | river | 3 boats, **none carried three-and-one** |
  | search-insert-delete | all three rules held, five runs for five |
  | bathroom / rope / hall | limits 3, 5, 4 never exceeded; the two kinds never mixed |

- **The result worth the whole chapter is a bug I wrote.** Search-insert-delete failed
  *consistently* — the deleter saw 1 or 2 searchers while holding `no-searcher`, which looks
  exactly like a mutual-exclusion failure. It was not. My `searchers` counter was a `peek` then an
  `init`: a read-modify-write across **two service rounds**, unprotected. A lost *decrement* leaves
  the counter permanently above zero, so every later deleter sees a searcher who has gone home.
  **That is C-094 in the wild, in the instrument rather than in the code under test**, and it
  presented as a false violation of the very property being tested. Putting the counter under the
  mutex fixed it: five runs, five passes. It is the best argument in this repository for why C-094
  matters — the hazard is invisible until something counts, and **what it corrupts first is the
  counting**.
- **Three wrong versions preceded the right one**, and the file keeps all three in its header
  because they failed differently: (1) every searcher took and released the semaphore instead of
  using a **lightswitch**; (2) searchers and inserters shared one semaphore, so they excluded each
  other — which the puzzle does not ask — and the loser spun until `wait-upto` gave up and, because
  the return was ignored, **walked into the critical section anyway**; (3) the racy counter above.
- **And (2) generalises into something F-102 should carry:** **a bounded wait that is not checked
  is worse than no wait at all.** `wait-upto` answers -1 when it gives up, and ignoring that turns
  a timeout into a silent mutual-exclusion violation. A blocking `wait` cannot be misused this way
  because it has no failure to ignore — so the workaround F-102 forces carries a hazard the
  primitive it replaces does not have.
- **A small structural observation the port can make and the book cannot:** the bathroom, the rope
  and Modus Hall differ only in a limit and some names, so all three run through one
  `enter-group`. Downey presents them as three puzzles because the *reader* has to discover that;
  a port can say it, having checked all three against the same code.
- **Class:** CLEAN, with **C-094 corroborated from the worst possible direction** and F-102's
  workaround shown to carry its own hazard.
- **Repro:** `wat semaphores/ch05-less-classical.wat`, `wat semaphores/ch06-not-so-classical.wat`.


### C-097: Downey chapter 7 — **the book is complete**, and the zero-mutex story stated correctly

- **Where:** `semaphores/ch07-not-remotely-classical.wat`. The sushi bar, child care, the Senate
  bus, Faneuil Hall and the dining hall. Six invariants, four runs, six passes each.

  | | |
  |---|---|
  | sushi bar | **5 of 5 seats**, never a sixth; a customer finding it full waits for the bar to **empty**, not for a seat |
  | child care | children never outnumbered adults 3:1 — 3 adults, 9 children, none refused |
  | Senate bus | 2 buses, 8 boarded, 2 still waiting; **nobody lost**, every bus within its seats |
  | Faneuil Hall | nobody entered while the judge sat; 8 entered, 7 confirmed, 1 pending |
  | dining hall | nobody left eating alone |

  **The Little Book of Semaphores is now complete: chapters 1–7**, every puzzle with an invariant
  the port checks rather than asserts.
- **And the chapter earns its place by fixing what chapters 2 and 6 found.** Every counter here is
  `:sem::do-add` — a read-modify-write in **one service round**, added to the semaphore service for
  this chapter. C-094 measured a `peek`-then-`init` pair losing ~77% of its updates; C-096 then had
  the same hazard corrupt the *instrument* and present as a false mutual-exclusion failure. `add`
  removes the class entirely, **and needs no mutex to do it**.
- **So the zero-mutex claim can finally be stated in a form that survives contact with the book:**
  not *"races are impossible in wat"* — C-094 disproved that — but **"keep the whole
  read-modify-write inside one message and they are."** The design is sound; what it requires of a
  user is a discipline the type system does not enforce and the documentation does not name. That
  is a better sentence than the one this repository started with, and it took the whole book to
  earn it.
- **What the port measured that a blocking language would not have to:** every `wait` in all seven
  chapters is a spin (**F-102**), and each puzzle reports its poll count — 618 round-trips for the
  sushi bar alone, ~224 µs apiece (F-051). That is the standing price of the missing primitive,
  now paid across thirty-odd puzzles rather than argued once.
- **Class:** CLEAN. **§11 closed.**
- **Repro:** `./run.sh semaphores` — 7/7.


### C-098: Crafting Interpreters ch 14-15 — a byte-code VM, and the two decisions that cost it 3-4×

- **Where:** `lox/lib/chunk.wat`, `lox/lib/vm.wat`, `lox/ch14-chunks.wat`,
  `lox/ch15-virtual-machine.wat`. NEXT.md §12 begun — the section queued specifically because it
  *"rehearses the exact machinery §7's baseline is being taken for"*.
- **Chapter 14** builds the book's chunk and disassembles it, matching Nystrom's format. Its one
  divergence is worth stating because every later number depends on it: **the book's chunk is 7
  instructions and 10 bytes** (three two-byte `OP_CONSTANT`s), **this one is 7 instructions and 7
  elements**, because an opcode is an *enum carrying its operand* rather than a `uint8_t` followed
  by operand bytes. A bad opcode is unconstructible here and undefined behaviour there; the price
  is that an "offset" counts instructions, not bytes, so chapter 23's jump operands will too.
- **Chapter 15 answers the question §12 was queued for, and the answer is worse than F-105's.**
  The same chunk, the same `exec`, only the plumbing different, 4002 instructions, min of 5 runs,
  **both orderings measured** because F-105's first draft was confounded by running one arm first:

  | loop shape | cost |
  |---|---|
  | **registerized** — `step : VmState -> VmState` plus a driver | **~2.3-2.5×** the threaded loop |
  | **threaded** — one tail-recursive loop carrying `ip` and the stack as arguments | baseline |
  | **hoisted** — the threaded loop with the chunk's arrays read **once**, not per instruction | a further **~30%** off |

  F-105 measured **1.9×** for the registerized shape on EOPL's toy machine; a real byte-code loop
  measures **more**. And the two costs **compound**: registerized-with-accessors against
  threaded-and-hoisted is between **three and four times**, on the same instructions computing the
  same answer.
- **The second cost is F-096 arriving where it hurts most.** BASELINE.md prices a `defrecord`
  accessor at **6130 ns** — eight times a user function call — and a dispatch loop reads
  `Chunk/code` *every instruction*. Hoisting the arrays out of the loop is a one-line change worth
  about a third of the run. That is not a subtle optimisation; it is the difference between a
  record being a convenience and being the hot path.
- **So the guidance for wat's own byte-code work, which is what this section is for:** the shape a
  VM is usually *drawn* as — an explicit machine state stepped by a function — is the expensive
  one, twice over. The state is inspectable, which is exactly what made C-081's instruction counts
  and high-water marks readable, so there is a real trade; but it should be made knowing it costs
  3-4×, not assumed to be free.
- **F-104 and F-088 again**, structurally: the stack pops by rebuilding, because neither vector
  type has a positional update and `:wat::core::take` answers a Stream. A stack machine pops on
  almost every instruction. Eighth and ninth workloads (C-086 lists the rest).
- **Class:** CLEAN, with **F-105 confirmed and strengthened** and **F-096 shown to dominate a
  dispatch loop**.
- **Repro:** `./run.sh lox`.

### C-099: Crafting Interpreters ch 16 — a scanner, and the registerized shape in the innermost loop there is

- **Where:** `lox/lib/scanner.wat`, `lox/ch16-scanning.wat`, `probes/lox/char-access-cost.wat`.
  38 token kinds, 31 checks, all green; the two scanner shapes are checked to produce **identical
  tokens** — kind, lexeme and line — before either is timed.
- **Coverage first.** The corpus is one Lox program that produces every token kind the language
  has, and the chapter asserts that **none of the 38** went unproduced, rather than sampling a
  few. Maximal munch (`!=` is one token, `!` alone is not), keywords against their own prefixes
  (`or` / `orchid`, `class` / `classy`), `12.` as NUMBER DOT and `.5` as DOT NUMBER, a string
  holding `//`, an unterminated string, an unexpected character, a comment at EOF, and a string
  spanning two lines reporting the line it **ended** on (Nystrom's `makeToken` reads
  `scanner.line` after the lexeme, and this port had to match that deliberately).
- **The chapter's architectural claim holds in wat.** `scan-n 8` — pull eight tokens from a 3 KB
  source and stop — costs under a **tenth** of scanning the file. Scanning on demand is
  representable, and it saves the work. That was not guaranteed: a language whose only string
  operations were bulk (`split`, `join`) would have to consume the whole source to produce the
  first token.
- **And then the cost, which is the finding.** Nystrom's scanner is three pointers he
  increments. The wat translation of `advance` is a **five-field `defrecord` rebuilt for every
  character**. That is C-098's registerized shape, arriving in the innermost loop a compiler
  has. So this chapter did what chapter 15 did — wrote the same scanner with the record taken
  out of the inner loops, per-character walks taking `src`/`n`/`i` as plain arguments and
  answering a plain index, one record built **per token** instead of per character:

  | shape | cost |
  |---|---|
  | record per **character** (Nystrom's, translated straight) | **~2.5×** |
  | record per **token** (the same scanner, same tokens) | baseline |

  Measured with the arms interleaved, each run twice and each taking first position once.
  **Three independent workloads now agree**: F-105's toy machine at 1.9×, C-098's byte-code loop
  at 2.3–2.5×, and a scanner at ~2.5×. The rule is not about VMs; it is that a record returned
  from a per-step function is the most expensive thing in any inner loop.
- **F-062, with a heavier workload and a sharper edge.** F-062 recorded that a String has no
  characters; Euler p22 priced one `subs` at 16.7 µs. A scanner is the workload where that is
  structural rather than inconvenient:
  - `:wat::string::subs` is the only way to reach character i, and it is **O(i)** — the
    implementation counts the string's chars, then skips. `probes/lox/char-access-cost.wat`
    prices a bare per-character walk at ~10 µs/char, within about a third of a `Vector` walk of
    the same length up to 16 KB, with the superlinear term visible but not yet dominant.
  - The other functional shape — carry the unscanned remainder and re-cut it — is **twice as
    fast at 1 KB and 1.5× slower at 16 KB**, because it copies the whole remaining source at
    every character. The idiomatic choice is the one that loses.
  - `:wat::string::split` **refuses an empty separator**, so a String cannot be exploded into a
    `Vector` of characters at all. It is a *runtime* `MalformedForm` — `(split s "")` with a
    literal empty separator type-checks. The intrinsic's own doc comment says callers who want
    per-char iteration "can encode through `Vec<u8>` via the IO layer", which is to say: through
    an impure handle.
  - `:wat::core::char` exists **as a type**, and the one intrinsic producing it takes a length-1
    String. It is a destination, not a route.
  - **So there is no hoist here.** Chapter 15 bought 30% by reading the chunk's arrays once
    instead of per instruction; the equivalent move for a scanner is to hoist the source into an
    indexable form, and there is no indexable form of a String to hoist into.
- **F-112 and F-113 found on the way.** F-112: `:wat::f64::min` exists, `:wat::i64::min` does
  not, and seven files here hand-write it. F-113 is the larger one — `:wat::core::assoc` updates
  a `defrecord` field without restating the others, which is **flat** in the field count where
  restating is linear, and is worth 1.7× at two fields and **5.8× at nine**. The `Scanner` uses
  it; that is what moved the ratio above from 2.5× to 1.9×, and the 2.5× is what the shape costs
  when the update is written the way the documentation shows.
- **Class:** CLEAN, with **F-105/C-098 confirmed a third time**, **F-062 strengthened** (the ask
  is not a convenience — it is the difference between a scanner and no scanner), and **F-112**
  raised.
- **Repro:** `./run.sh lox`; `wat probes/lox/char-access-cost.wat`.

### C-100: Crafting Interpreters ch 17 — the compiler, and the chunk chapter 14 wrote out by hand

- **Where:** `lox/lib/compiler.wat`, `lox/ch17-compiling-expressions.wat`,
  `probes/lox/rule-table.wat`. 35 checks, all green on the first run.
- **The check worth having.** Chapter 14 built the chunk for `-((1.2+3.4)/5.6)` **by hand**,
  instruction by instruction, because there was no compiler yet. Chapter 17 compiles the same
  source text and asserts the two chunks are **identical** — same opcodes, same constant pool,
  same order — and then runs it on chapter 15's VM and gets chapter 15's answer,
  `-0.8214285714285714`. Four chapters, written on four different days, checked against each
  other rather than against a description of themselves. This is the closest thing the lox suite
  has to an oracle (NEXT §12: "there is no second implementation to compare against — the VM IS
  the thing being tested").
- **And the rest of the Pratt parser, checked rather than assumed:** precedence (`1+2*3` compiles
  the multiply first and answers 7; `(1+2)*3` does not and answers 9), left associativity
  (`1-2-3` is −4 and its code is `C C SUB C SUB`, which is the `+1` in
  `parse-prec (infix-prec k) + 1` doing its job), unary binding tighter than any binary operator
  and being right-associative (`-1*2` emits `C NEG C MUL`, `-(1*2)` emits `C C MUL NEG`, both
  answer −2), grouping emitting no instructions of its own (`((((1))))` is one constant), seven
  error cases with their messages and line numbers, and **panic mode** — `+ + +` reports exactly
  one error, which is the whole reason Nystrom carries the flag.
- **The rule table, settled by building it.** Nystrom's parser is driven by an array of function
  pointers indexed by TokenType. This port dispatches with `match` instead, and
  `probes/lox/rule-table.wat` exists so that is a choice rather than an excuse. The table is
  expressible: a **`defstruct`** row carries both closures and the precedence, with accessors,
  and `getRule(op)->infix(a,b)` reads as one line. An `:wat::enum::Impure` row also works, at a
  `match` per field read. A **`defrecord`** row is refused outright — **F-114**, on how that
  refusal is worded, where it is located and what it does not offer.
- **One place wat is stricter than the C, to its credit.** Nystrom's number literal is
  `strtod(parser.previous.start, NULL)`, which answers 0 for input it cannot read and says
  nothing. `:wat::string::to-f64` answers an `Option`, so the failure has to be written down —
  and the scanner guarantees it cannot happen, which is exactly the kind of arm a compiler wants
  present and unreachable.
- **F-113 applied before it cost anything.** The parser is a nine-field record updated **per
  token**; every update goes through `:wat::core::assoc`. C-099 learned that the hard way one
  chapter earlier.
- **Class:** CLEAN, with **F-114** raised.
- **Repro:** `./run.sh lox`; `wat probes/lox/rule-table.wat`.

### C-101: Crafting Interpreters ch 18 — a tagged union, runtime errors, and Nystrom's NaN bug reproduced

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/lib/prec.wat`, `lox/ch18-types-of-values.wat`, `probes/lox/value-equality.wat`.
  **49 checks, all green on the first run.**
- **The data half ports in nine lines**, and that is the honest report: a tagged union is a
  `defenum`. Nystrom's entire second half — the `IS_NUMBER` / `AS_NUMBER` / `NUMBER_VAL` macros
  that make C's union safe to use — has nothing to port, because a `match` arm that binds `n` has
  already done it and a missing arm is a compile error rather than a reinterpreted bit pattern.
  Chapter 30's NaN boxing has nothing to say either, which is why NEXT.md records it as "no
  portable content" rather than dropping it.
- **`valuesEqual` is `(= a b)`.** I wrote it by hand first — comparing type names, then
  unwrapping each variant — on F-019's headline, *"two values of one enum can't be compared with
  `=`"*. That headline is wider than the finding: F-019 is about values still carrying their
  **variant** type. `probes/lox/value-equality.wat` is now the positive control, and it settles
  the case Lox actually needs: the `f64` payload compares **as an `f64`**, so
  `Num(NaN) = Num(NaN)` is false rather than bitwise-true.
- **Nystrom's acknowledged bug, reproduced rather than repeated.** `!=`, `<=` and `>=` have no
  opcodes: they compile as `==`/`>`/`<` followed by `!`. He says this is wrong under IEEE 754,
  because NaN is not less than, equal to or greater than anything. wat's `f64` is IEEE
  (`0.0/0.0` is `NaN`; `NaN > NaN`, `NaN < NaN` and `NaN = NaN` are all false), so the bug ports
  intact and the chapter checks it: **`NaN <= NaN` answers `true`** where IEEE says false, and
  `NaN >= NaN` likewise. The code shapes are checked too — `1 <= 2` compiles to `CONST CONST GT
  NOT RET` and `1 < 2` to `CONST CONST LT RET`.
- **The half that cost something is the runtime error.** Chapter 15's VM could not fail; this one
  must, because `-true` and `1 < nil` are programs the compiler accepts. Nystrom returns
  `INTERPRET_RUNTIME_ERROR` up through `run()`. wat has no early return and its only general
  catch spawns a thread (**F-063**), so the failure is a value: every instruction answers
  `Step.Next` or `Step.Fail` and the loop matches on it — **one extra `match` per instruction**,
  in the hot loop C-098 measured. It is the shape EOPL chapter 5's exceptions took.
- **Also checked:** Lox truthiness is Ruby's, not C's (`!0` is `false`, not `true` — six cases),
  equality across types (`nil == false`, `1 == true` and `0 == nil` are all false), the literals
  getting opcodes rather than constant-pool slots, error lines surviving a newline, the full
  precedence ladder now that there is enough of one to get wrong, and the VM stopping **at** the
  failing instruction rather than past it.
- **A second namespace, and why.** Chapter 18 in C edits `value.h` in place. Here `:lox::`
  (chapters 14–17) is left exactly as it was and the value era is `:loxv::`, because C-098 and
  C-099 published measurements taken on that code — three VM loop shapes, two scanner shapes —
  and `lox/ch15-virtual-machine.wat` must keep running the loop its numbers came from. The
  scanner is shared unchanged (tokens do not care what a value is), and the precedence ladder was
  factored into `lib/prec.wat` so the two eras cannot drift apart.
- **Class:** CLEAN. No new defect; **F-019 clarified with a positive control**, and F-063,
  F-104, F-088 and F-113 all met again in the ordinary course of writing a VM.
- **Repro:** `./run.sh lox`; `wat probes/lox/value-equality.wat`.

### C-102: Crafting Interpreters ch 19 — strings, and the part of the chapter that is about C

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch19-strings.wat`. **31 checks, all green on the first run.**
- **The chapter in C is where Lox grows a heap.** A value becomes a pointer to an `Obj` with its
  own type tag; `ObjString` adds a length and a character array; the VM keeps a linked list of
  every object it has allocated so `freeObjects()` can walk it at shutdown; concatenation
  allocates, copies both halves and takes ownership.
- **In wat the port is one enum variant and one `:wat::string::concat`**, and saying precisely
  which part vanished is the value of doing it. `Obj`, `ObjString`, `allocateObject`,
  `vm.objects` and `freeObjects` have no wat-level meaning, because wat owns the heap. What
  survives is the LANGUAGE half, and that half is checked in full: `+` overloaded for two strings
  and refusing mixed operands with its own longer message, every other arithmetic operator
  keeping the short one, `<` refusing strings entirely (Lox does not order them), a string being
  truthy including the empty one, and equality across types staying false.
- **Two things are genuinely lost, and both are debts to later chapters.**
  1. The object list is what chapter 26's mark-sweep collector walks. A GC chapter in wat will
     have to build its own heap to collect, the way SICP §5.3 did (C-081) — which is the right
     answer anyway, since collecting wat's heap is not something a wat program can do.
  2. `==` on two strings is already structural, so the CORRECTNESS chapter 20's interning buys
     arrives one chapter before the chapter that adds it. `"ab" == "a" + "b"` is true here.
     What is left of interning is its cost, which is C-103.
- **One check worth naming:** two identical string literals are two constant-pool entries. That
  is exactly right for chapter 19 and exactly what chapter 20 stops.
- **Class:** CLEAN.
- **Repro:** `./run.sh lox`.

### C-103: Crafting Interpreters ch 20 — NEXT.md said "no portable content", and half of that was wrong

- **Where:** `lox/lib/v-intern.wat`, `lox/ch20-hash-tables.wat`. **9 checks and a measurement.**
- **The reclassification.** NEXT.md recorded chapter 20 as *no portable content* because the
  chapter builds a hash table — open addressing, linear probing, tombstones, a 75% load factor —
  and wat has `HashMap` and `PersistentMap` with C-078 already measuring them. That half stands.
  But the chapter's other job is **string interning**, and interning is not about hash tables: it
  is a language design decision, and it has two separable consequences that this repository was
  in a position to separate.
- **The correctness half wat gets for free**, and C-102 already showed it: `=` on a String is
  structural, so `"ab" == "a"+"b"` was true in chapter 19.
- **The cost half is a claim about a C program, so it was measured.** Same loop, same count, min
  of 2, arms interleaved: comparing two interned ids (an `i64` compare), comparing two
  separately-built equal strings, and — as the control — comparing two strings that differ at
  character 0.

  | string length | interned id | equal strings | differ at char 0 |
  |---|---|---|---|
  | 10 | ~6950 ns | ~6900 ns | ~7100 ns |
  | 1 000 | ~7000 ns | ~8600 ns | ~7100 ns |
  | 100 000 | ~8600 ns | ~11400 ns | ~8000 ns |

- **So interning buys nothing measurable in wat until a string is enormous.** At ten characters
  the three columns are the same number. At a thousand, comparing equal strings costs a few
  percent more than comparing integers. At a hundred thousand it costs roughly a quarter more —
  and a Lox program compares identifiers and short literals. In C this optimisation turns an
  O(length) `memcmp` into a pointer compare and is worth the chapter; here the call costs about
  **7 µs before it looks at a character**, and the walk disappears underneath it.
- **The control says the walk is real.** Two strings differing at character 0 stay **flat** as
  the length grows where two equal strings do not, so the comparison does walk and does exit
  early. It is simply dwarfed by the call around it.
- **The general form, and it is the third chapter in a row to find it.** In an interpreter a
  program is charged for the NUMBER of operations, not for what each one touches. C-098 found the
  record per instruction; C-099 found the record per character; this finds that an optimisation
  aimed at the per-touch cost — interning, and by the same argument chapter 30's NaN boxing and
  cache-line layout — is aimed past where the time goes. That is a useful thing for wat's own
  byte-code work to know before it starts optimising.
- **Class:** CLEAN, and a **correction to this repository's own chapter table** — "no portable
  content" was half right, and the half that was wrong was the half with a measurement in it.
- **Repro:** `wat lox/ch20-hash-tables.wat`.

### C-104: Crafting Interpreters ch 21 — statements, globals, and the subtlest bug in the chapter

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch21-global-variables.wat`. **37 checks green**; two code-shape expectations were wrong on
  the first run (I had forgotten the trailing `RET`) and are fixed, not re-aimed.
- **The chapter that turns an expression evaluator into a language:** statements, `print`, `var`,
  a global table, assignment as an expression, and `synchronize()` so one bad statement does not
  poison the file. Nystrom's own example runs —
  `var beverage = "cafe au lait"; var breakfast = "beignets with " + beverage; print breakfast;`
- **The three emphases, checked rather than assumed.**
  1. **An expression statement POPs.** `print 1;` is `CONST PRINT RET` and `1;` is
     `CONST POP RET`, and that one instruction is why a long program's stack does not grow —
     checked by running programs and asserting the stack is **empty** at the end, after
     expressions, after prints, and after declarations.
  2. **Assignment is an expression.** `print a = 2;` prints 2 *and* leaves `a` at 2; `a = b = 3`
     chains. And assignment does not define: `x = 1;` on an undeclared `x` is a runtime error,
     where `var x = 1;` is not.
  3. **`canAssign`** — Nystrom calls it the subtlest bug in the chapter. A prefix rule may take a
     following `=` only if it was reached at or below assignment precedence, which is what makes
     `a * b = c` a compile error instead of a silent parse of `a * (b = c)`. Five targets
     checked: `a * b = c`, `a + b = c`, `!a = b`, `1 = 2`, and `(a) = b` — the last because a
     grouping is not an lvalue in Lox either — against `a = b`, which is fine.
- **`synchronize()` measured by counting**, which is the only way to tell recovery from
  suppression: `print; print;` reports **2** errors, `print; print; print;` reports **3**, and
  `var = 1; var b = 2; print;` reports 2. Without synchronization the parser would still be in
  panic mode at the second statement and would swallow its error.
- **What it cost in wat.** The VM now has state beyond its stack, and both the globals table and
  the output are values, so `Step.Next` carries three things forward where it carried one. The
  exchange is not obviously bad: `print` becoming a `conj` onto a vector is exactly why this file
  can check what a program **printed** rather than what it left on the stack, which is what a
  language test actually wants.
- **The cost landed somewhere else, and it is now F-115.** Adding `:globals` and `:out` to
  `:loxv::Out` broke a match in `ch18-types-of-values.wat` that wanted neither field, because a
  variant pattern must name every field. A chapter about tagged unions, edited by a chapter about
  global variables. Chapters 22–29 each extend VM state again.
- **One more piece of bookkeeping worth recording:** chapter 21 replaces the top level — a source
  becomes a sequence of declarations rather than one expression. `:loxv::compile` (the expression
  grammar) is kept beside `:loxv::compile-program` rather than replaced, so chapters 17–20 keep
  testing the thing they were written for. That is the same problem C-101 solved with a second
  namespace, at a much smaller scale: a book that edits one codebase across chapters, against a
  suite that runs every chapter against the current code.
- **Class:** CLEAN, with **F-115** raised.
- **Repro:** `./run.sh lox`.

### C-105: Crafting Interpreters ch 22 — locals on the stack, and the pop that costs 121 ms

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch22-local-variables.wat`, `probes/lox/stack-ops.wat`. **26 checks green on the first
  run.**
- **The chapter's own claim, checked.** A local costs **no instruction to create**: its
  initializer already left the value in the right stack slot. So `{ var a = 1; print a; }`
  compiles to `CONST GET_LOCAL PRINT POP RET` where the global form compiles to
  `CONST DEFINE_GLOBAL GET_GLOBAL PRINT RET` — one fewer instruction and no name in the constant
  pool. Leaving a scope emits one `POP` per local, and the chapter asserts the stack is **empty**
  at the end of every program, including nested blocks.
- **Scoping, checked rather than described:** a local shadows a global and an outer local, three
  deep (`3|2|1`); sibling blocks do not collide; an inner block reads *and assigns to* an outer
  local; slot numbering is checked through the emitted code (`GETL/1` for the second local).
- **The two compile errors this chapter adds**, both of them the kind that distinguishes a real
  scope analysis from a name lookup: *"Already a variable with this name in this scope."* (while
  redeclaring a **global** stays legal), and *"Can't read local variable in its own
  initializer."* — including the case that makes it subtle, `var a = 1; { var a = a; }`, where an
  outer `a` exists and Lox still refuses.
- **And this is where F-104 lands in an inner loop.** `OP_SET_LOCAL` is `vm.stack[slot] =
  peek(0)`. Measured across the same instruction count at increasing scope depth: one
  `OP_SET_LOCAL` costs **76 µs with one local in scope, 133 µs with ten, 404 µs with forty**, and
  the `GET+POP` baseline rises with it because a pop is a rebuild too.
- **Then `probes/lox/stack-ops.wat` took that apart, and found something worth more than the
  chapter: F-116.** `conj` on a `Vector` clones (F-023), so a rebuild-pop is **quadratic** — one
  pop at depth 4 000 is **121 ms**. `conj` on a `PersistentVector` is flat, so the same rebuild
  there is linear — 34 ms, which is exactly 4 000 × the interpreted-loop control and nothing
  else. A `pop` verb would make it about **8 µs**. F-104's queued *Index-assoc* fixes
  `OP_SET_LOCAL` and does nothing for `OP_POP`; they are two asks.
- **Recorded, not acted on:** this VM's stack is a `Vector`, as every port in this repository
  uses, and the measurement says a VM stack should be a `PersistentVector`. Switching it is one
  clear piece of work (the `Stack` typealias and about twenty call sites) and would change
  C-098's and this chapter's numbers, so it is listed in NEXT.md rather than done inside the
  chapter that discovered it.
- **Class:** CLEAN, with **F-116** raised and **F-023 priced**.
- **Repro:** `./run.sh lox`; `wat probes/lox/stack-ops.wat`.

### C-106: Crafting Interpreters ch 23 — control flow, and the backpatch chapter 14 predicted

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch23-jumping.wat`. **40 checks green**; one expectation (a step count) was a guess and was
  replaced with a derivation, not re-aimed.
- **`lox/lib/chunk.wat`'s header, written nine chapters earlier, said this chapter would land on
  F-104**, because `patchJump()` assigns into `chunk->code[offset]` and wat has no positional
  update. It did, and now it is priced:

  | `if`s in the program | instructions | compile, no patches | compile, with | per patch |
  |---|---|---|---|---|
  | 15 | 106 | 27 ms | 48 ms | 0.73 ms |
  | 45 | 316 | 80 ms | 266 ms | 2.06 ms |
  | 90 | 631 | 163 ms | **1 055 ms** | 4.96 ms |

  A patch costs about **7 µs for every instruction already emitted**. So one patch is *linear in
  the program compiled so far*, and a program's patches together are **quadratic in its length**:
  90 `if`s take a second to compile where the same statements without jumps take a sixth of one.
  F-116's per-element clone rides on top and is still small at this size, so the curve gets worse
  rather than better. **The cost of a jump is currently a property of where in the file it
  appears** — which is the clearest argument this section has for wat's queued *Index-assoc*.
- **The semantics, checked where a jump is visible in the answer.** `and` and `or` leave their
  **operand**, not a boolean, because `JUMP_IF_FALSE` peeks rather than pops: `nil and 2` is
  `nil`, `1 or 2` is `1`, `1 and 2 and 3` is `3`. Short-circuiting is checked as an **effect**
  too — `var a = 0; false and (a = 1); print a;` answers 0, and the `true and` form answers 1 —
  because a value test alone cannot tell short-circuiting from evaluation.
- **The emitted code is asserted, instruction by instruction**, for `if`, `if/else`, `while`,
  `and` and `or`, including that `while`'s `LOOP` goes back to 0 and that both `if` paths leave
  the stack empty. A jump offset here counts **instructions, not bytes** — chapter 14's decision,
  arriving where it was predicted to matter — so Nystrom's two-byte big-endian operand and his
  65 535 limit have no analogue.
- **`for` is the set piece**, desugared entirely in the compiler with the increment compiled
  *before* the body and jumped over. Every clause present and each one absent is checked, nesting
  is checked, the loop variable being local and shadowing an outer one is checked, and the
  **step count is derived** rather than asserted: 17 instructions, 1 + 3×13 + 4 + 3 = **47** for
  three iterations. That derivation is what shows the `JMP` over the increment runs on *every*
  iteration, not just the first — the price of compiling the increment first.
- **One wat-side change worth naming:** a jump had to become a value. The threaded loop advances
  `ip` itself, so `exec` gained a third `Step` variant, `Step.Jump`, carrying the target. That is
  cheaper than it sounds — the match is in one place — and it is the same move C-101 made for
  runtime errors.
- **Class:** CLEAN, with **F-104 priced in the compiler** (it was already priced in the VM by
  C-105).
- **Repro:** `./run.sh lox`.

### C-107: Crafting Interpreters ch 24 — functions, call frames, and the capability boundary I got wrong

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch24-calls-and-functions.wat`. **44 checks green.**
- **The centre of Part II**, and the largest single chapter in the section: a function becomes a
  value with its own chunk, the compiler becomes a stack of compilers, the VM grows call frames
  with their own `ip` and their own window into a shared value stack, and arity, callability and
  stack depth become runtime errors. Recursion (`fib(10)` is 55), mutual recursion, functions
  passed as arguments and returned from functions, and `mk()()` all run.
- **Three wat-shaped decisions, each a question before it was an answer.**
  1. **A `Val` holds a `Chunk` and a `Chunk`'s constant pool holds `Val`s** — a `defenum`
     recursive through a `defrecord`. Checked in a scratch probe before it was relied on; wat
     accepts it.
  2. **A native is a NAME, not a closure.** Nystrom stores a C function pointer *in* the value; a
     closure cannot live in a `:wat::enum::Pure` (**F-114**), so `Val.Native` carries a name and
     the VM dispatches on it — the same table of function pointers, spelled as a `match`. It is
     not purely a workaround: a native that is not installed is a diagnosable error here rather
     than a jump through a null pointer.
  3. **The current frame rides in the loop's arguments; only enclosing frames are a vector.**
     C-098 priced a record per instruction, so `ip` is an argument and a frame is allocated per
     **call**. F-104's rebuild is then paid per *return* rather than per *step* — which is why
     this chapter cost less than 22 or 23 did, despite being much larger.
- **F-019 met twice, exactly where the finding says it will be**, and this time in ordinary code
  rather than in a probe: `(:loxv::Val.Native {…})` inline has the **variant's** type, so
  `assoc` into a `HashMap<String, Val>` is refused with *"parameter #3 expects `:loxv::Val`; got
  `:loxv::Val.Native`"*. A helper whose declared return type is the enum widens it — P-006's
  route, which C-101's positive control had already mapped.
- **One expectation was wrong on the first run, and the fix was to the expectation.** I asserted
  that a local function can recurse. It cannot, at this chapter: the recursive reference lives
  inside the function's **own** body, where the name is a local of the *enclosing* compiler, and
  `resolveLocal` does not look there — `resolveUpvalue` is chapter 25. That is exactly what clox
  does at this point in the book. There are now **two checks pinning that boundary** (a local
  function cannot refer to itself, and cannot read an enclosing local), so chapter 25 will have
  to move them rather than quietly widen past them.
- **One real divergence, recorded because it is unreachable rather than absent.** clox compares
  functions by **object identity**; `=` on a wat enum is structural, so two functions with the
  same name and the same body would compare equal here. Lox cannot construct that case — a name
  is declared once per scope — so no program can tell. Chapter 25 changes that, because a closure
  carries captured state.
- **Class:** CLEAN, with **F-019 and F-114 met in ordinary code**.
- **Repro:** `./run.sh lox`.

### C-108: Crafting Interpreters ch 25 — closures, and the one place the book's design could not be translated

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch25-closures.wat`. **33 checks green**; ch24's two boundary checks moved, as that chapter
  said they would have to.
- **This is the chapter where wat said no to the design rather than to a spelling.** Nystrom's
  upvalue is a `Value*` **into the stack**: while the variable is live the pointer aliases its
  slot, so a write through the closure and a write through the local are the same write; when the
  frame dies the upvalue is *closed* by copying the value into the object and redirecting the
  pointer at it. Two closures share a variable because they hold the same `ObjUpvalue*`.
- **wat has no way for two values to share a mutable location.** No pointer, no reference cell,
  and no positional update (F-104) that both could see. So the pointer became an **index into a
  table the VM owns**:

  | | |
  |---|---|
  | `Cell.OnStack idx` | the variable is live; the cell is an alias for stack slot `idx` |
  | `Cell.Closed v` | the frame is gone; the cell owns the value |

  A closure holds cell **ids**. Two closures over one variable hold the same id, so they see each
  other's writes.
- **And that is a positive result, not a workaround.** `Value*` is not a language feature wat is
  missing; it is C's spelling of an indirection, and naming the indirection costs one table and
  one extra read. The parts of the C that *did* vanish — the open-upvalue list kept sorted by
  stack slot, and freeing the objects — were both about the pointer rather than about Lox.
- **Everything the chapter promises is checked, not asserted:** a closure outliving its scope; a
  counter (`1|2|3`); **two closures sharing one variable** (`up(); up(); get()` is 2); two
  separate calls **not** sharing (`1|2|1`); a write through a closure seen by the **local**
  (`99`); capture through **three** levels; a parameter captured. On the compiler's side, what it
  decided to capture is read out of the emitted function: `local/0`, de-duplicated when the same
  variable is used twice, `local/0 local/1` for two, and **nothing** for a global.
- **Two emitted-code facts worth keeping**, both of which I got wrong first and fixed by looking:
  a function's own locals are **never popped** — the frame is discarded whole and anything
  captured out of it is closed at `RETURN`, exactly as `endCompiler` does not `endScope`; and
  `OP_CLOSE_UPVALUE` appears only where a **block** inside a function ends, one per captured
  local, innermost first (`POP CLOSEU` for an uncaptured `i` above a captured `x`).
- **A divergence closed itself.** C-107 recorded that clox compares functions by object identity
  where `=` on a wat enum is structural, and that no Lox program could tell. A closure carries its
  captured cell ids, so two closures from two calls now differ — `mk() == mk()` is false and
  `a == a` is true.
- **F-115 again, twice**, both in files that wanted nothing from the change: adding the `Closure`
  variant and the `updescs` field to `Val` broke a helper in `ch24-calls-and-functions.wat` that
  only wanted a chunk. That is the fourth chapter to pay it.
- **Class:** CLEAN.
- **Repro:** `./run.sh lox`.

### C-109: Crafting Interpreters ch 26 — a mark-sweep collector over a real leak, not a model

- **Where:** `lox/lib/v-vm.wat`, `lox/ch26-garbage-collection.wat`. **23 checks green on the
  first run.**
- **NEXT.md said "partly covered".** SICP §5.3 (C-081) already built stop-and-copy with broken
  hearts, and Nystrom's mark-sweep is a different algorithm. What that note could not know is that
  by the time this chapter arrived there would be a **real leak to collect** rather than a heap to
  simulate: chapter 25's cell table allocates a cell on every capture and, until this chapter,
  released none.
- **The control is the finding.** The same program, the same VM, the collector's threshold moved
  out of reach:

  | | collector off | collector on |
  |---|---|---|
  | 30 closures in a loop | **30 cells**, all of them unreachable | **8 cells**, 1 live, 22 collections |
  | 40 closures in a loop | **40 cells** | **8 cells** |

  A GC chapter without that control is a chapter about an opinion.
- **Every root is checked by keeping a closure in it and running twenty collections underneath.**
  A global, a stack local, a **suspended frame's** local, and — the one that needs clox's grey
  stack — a cell reached **through another cell**: `o` captured `inner`, `inner` captured `n`, and
  marking `o` is not enough, so marking runs to a fixpoint. It answers 5.
- **State survives collection, which is the other half of correctness:** a counter keeps counting
  (`1|2`) across twenty collections, sharing between two closures survives, and three closures
  kept alive together still fit in the same eight slots with four cells live.
- **Two things the C does that this does not need**, and both are about the pointer rather than
  about Lox: Nystrom keeps open upvalues in a list **sorted by stack slot** so closing a frame can
  stop early (a table is scanned instead), and his sweep unlinks and `free()`s (a table cannot
  forget an index, so a swept slot becomes `Cell.Free` and is reused — which is why the table
  *stops* at eight rather than growing and shrinking).
- **One design note worth keeping for wat's own work.** Adding statistics did not cost the
  F-115 tax this time, and deliberately: `run-loop` now answers a `Run` record (out, cells, peak,
  collections) and `run` unwraps it to the `Out` every earlier chapter matches on. Widening the
  *inner* function and keeping the *outer* signature is the move that stops a change rippling
  through six chapter files — which is worth knowing precisely because F-115 makes the ripple
  expensive.
- **Class:** CLEAN, and a **correction to this repository's own chapter table** in the other
  direction from C-103: "partly covered" understated it.
- **Repro:** `./run.sh lox`.

### C-110: Crafting Interpreters ch 27 — classes and instances, and the second table wat made me build

- **Where:** `lox/lib/v-value.wat`, `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`,
  `lox/ch27-classes-and-instances.wat`. **35 checks green on the first run.**
- **One line of Lox is the whole chapter's difficulty:** `var a = f; a.x = 2; print f.x;` must
  print 2. A wat value cannot be two names for one mutable object, so an instance became an **id
  into a VM-owned table** — the same move chapter 25 made for upvalues, and the second time in
  three chapters. **F-117** is that pattern written up.
- **A class needed none of it.** A class is immutable once declared, so it is an ordinary value:
  `OP_METHOD` rebuilds it in its stack slot and the finished value is stored back into its binding
  at the end of the declaration. Nothing can observe a class before then, so this is
  indistinguishable from Nystrom's mutation in place — and it is checked, including that a local
  class inside a function works.
- **Reference semantics checked five ways**, because one way would not have been convincing: two
  names, the other direction, through a function parameter, through a returned instance, and
  through a field of another instance.
- **The collector already knew what to do.** Extending C-109's mark-sweep to instances was part of
  the same change, so the chapter closes with that chapter's own before-and-after: **30 instances
  with the collector out of reach, 1 with it running**, and a kept instance still answering 5.
- **`canAssign` in its third setting:** `f.x + 1 = 2` is *"Invalid assignment target."* — the same
  rule that refused `a * b = c` in C-104 and `(a) = b` before it.
- **Class:** CLEAN, with **F-117** raised.
- **Repro:** `./run.sh lox`.

### C-111: Crafting Interpreters ch 28 — methods and initializers, which cost nothing

- **Where:** `lox/lib/v-compiler.wat`, `lox/ch28-methods-and-initializers.wat`. **34 checks green
  on the first run.**
- **Worth recording precisely because it was free**, after two chapters where it was not. The
  chapter's design is that a method needs almost no new machinery: it is a closure in the class's
  method table, and calling one puts the **receiver in local slot 0**, so `this` is an ordinary
  local. Every consequence then ports without a decision — including the one that would have
  caught a shortcut: **a closure declared inside a method captures `this` like any other local**,
  and still answers correctly after the method has returned.
- **The compiled difference between `init` and any other method is exactly two details**, and both
  are asserted from the emitted code: a method ends `NIL RET` and an initializer ends
  `GETL/0 RET`, and `return <expr>` inside an initializer is a compile error. `init` is a method
  *name*, not a keyword — so a class without one has no `init` property at all, which the chapter
  checks rather than assumes.
- **A field shadows a method**, Lox's rule and the reason both use `.`: `f.m = 1` replaces the
  method for that instance, and calling it afterwards is *"Can only call functions and classes."*
- **Class:** CLEAN. No finding; the chapter is a positive control for the two before it.
- **Repro:** `./run.sh lox`.

### C-112: Crafting Interpreters ch 29 — superclasses, and **Part II is complete**

- **Where:** `lox/lib/v-vm.wat`, `lox/lib/v-compiler.wat`, `lox/ch29-superclasses.wat`.
  **30 checks green**; two expectations were wrong on the first run and both were fixed by
  reading the output rather than by re-aiming anything.
- **`super` is LEXICAL, and that is the chapter.** It means the superclass of the class the method
  was *written in*, not of whatever the receiver turns out to be, and Nystrom makes it true by
  giving each class declaration a hidden local called `super` that methods capture as an upvalue.
  The three-level check is what tests it: `B.m` calls `super.m()` and must reach **A** with a
  **C** receiver — `CBA`, with `this` still the C. If `super` meant the receiver's superclass this
  would not terminate.
- **Copy-down inheritance** checked: a subclass takes its parent's method table at *declaration*
  time, a subclass method wins whatever the declaration order, and a three-level chain resolves
  without walking anything.
- **In wat this needed no new idea.** `OP_INHERIT` merges one immutable class value into another
  and rebuilds it in its stack slot — the move `OP_METHOD` already made — and `super` is chapter
  25's upvalue machinery used unchanged. One of the two wrong expectations was my guess at the
  emitted code; the real shape (`INHERIT SETG SETG POP POP`) is the class stored back twice, once
  after inheriting and once after the method list, and the hidden `super` local going out of
  scope.
- **One Lox fact the end-to-end program had to respect:** there is no number-to-string conversion,
  so `"" + 9` is a runtime error rather than a cast. The final check is a program using nearly
  everything Part II built — a class hierarchy three deep, an initializer calling `super.init`, a
  `for` loop inside a method, a bound method passed to a function — and it answers
  `square|9|18|cube of a square|4`.
- **The tally for the whole section.** Sixteen chapters, and what wat could not do directly is
  short and consistent: **nothing can share a mutable location** (F-117). That cost a cell table
  (ch25), an object table (ch27) and a collector for both (ch26). Everything else was translation,
  and the expensive parts were not missing *features* but missing **verbs** — no positional update
  (F-104), no pop (F-116).
- **Class:** CLEAN. **NEXT §12 complete.**
- **Repro:** `./run.sh lox` — 16 passed, 0 failed.

### C-113: Crafting Interpreters ch 30 — "no portable content" was right about the content and wrong about the method, and it caught a mistake of mine

- **Where:** `lox/ch30-optimization.wat`, `probes/lox/stack-mix.wat`. **17 programs in the suite;
  Part II is complete, chapter 14 to chapter 30.**
- **NEXT.md recorded this chapter as "no portable content"** because its two optimizations are NaN
  boxing and a hash-table bitmask, and both are about C's memory model. That half stands. What
  re-reading it found — C-103 being the standing reason to re-read such a ruling — is that the
  chapter's **method** ports completely: write the benchmarks first, profile, and distrust the
  obvious optimization.
- **And it had a specific claim of mine to test.** F-116 measured one push and one pop against
  depth and found a `Vector`'s rebuild-pop **quadratic** where a `PersistentVector`'s is linear —
  121 ms against 34 ms for one pop at depth 4000 — and **NEXT.md concluded that this VM's stack
  should be a `PersistentVector`**, recording it as work left undone.
- **That conclusion is wrong, and this is the correction.** `probes/lox/stack-mix.wat` runs the
  operation mix a byte-code VM actually performs — two reads, a pop of two, a push, a positional
  store — at the depths it actually reaches:

  | stack depth | `Vector`, against `PersistentVector` |
  |---|---|
  | 4 | **89%** |
  | 8 | **86%** |
  | 16 | **82%** |
  | 32 | **80%** |
  | 128 | **82%** |
  | 512 | 113% — the crossover |

  A Lox stack holds one frame's locals plus a couple of temporaries; it reaches **tens**. Below
  about 256 elements the `Vector` **wins**, because `PersistentVector`'s `get` answers an `Option`
  and the unwrap on every read costs more than the clone it saves. F-116's measurements stand;
  the advice drawn from them did not survive being tested at the right size.
- **The VM's own profile**, which is the number to keep for wat's byte-code work:

  | benchmark | instructions | ns/instruction |
  |---|---|---|
  | `fib(12)`, recursion | 5 582 | **108 000** |
  | arithmetic loop | 6 610 | 59 000 |
  | property access | 2 626 | 64 000 |
  | closure calls | 1 692 | 89 000 |

  **Recursion costs about twice per instruction what a flat loop does**, and that is the frame
  vector: every call `conj`s a `Saved` onto it and every return rebuilds it without the last
  element — F-116's missing `pop`, met in the one place a VM cannot route around it.
- **Third time this section has landed on the same shape.** C-103 found interning worth nothing at
  Lox's string lengths; C-098 and C-099 found that an interpreter charges for the *number* of
  operations rather than for what each one touches; and now a container choice **reverses** below
  256 elements. The common lesson is the chapter's: measure the thing you are optimizing, at the
  size it runs at, before believing a micro-benchmark about it.
- **Class:** CLEAN, and a **correction to this repository's own recommendation**.
- **Repro:** `wat lox/ch30-optimization.wat`; `wat probes/lox/stack-mix.wat`.

### C-114: Advent of Code, finished — 25 days, 70 answers, and what a year of ordinary work found

- **Where:** `aoc/day01-sonar.wat` … `aoc/day25-cucumbers.wat`, `oracle/aoc/*.clj`,
  `aoc/README.md`. **25 puzzles, 70 answers, every one matching its Clojure reference.** NEXT.md
  §4 asked for "one year"; this is that, and it was the only item on that page still labelled in
  progress.
- **Eighteen puzzles were added in one pass (days 8–25)**, each chosen for something the first
  seven did not reach rather than for being a puzzle. What they found, in the order it matters:
- **Size is fine. Rebuilding is what costs.** day23 sorts 20 000 numbers and puts 20 000 names in
  a `PersistentMap` in **3.9 s all told**, so neither `sort` nor a sharing map has a scaling
  problem. The four slowest puzzles are all rebuilds — day05 (20.6 s, a copying container, and it
  was 135 s before F-057's advice was taken), day18 (13.0 s, a whole number copied per rewrite),
  day20 (10.1 s, a growing image built a character at a time) and day25 (9.7 s, two grids per
  step). Their Clojure references take about a second each. **F-104 and F-116 are the two verbs
  that would change all four.**
- **F-116's missing `pop` is a question of SIZE, and this suite has both halves.** day08's
  bracket stack is nine deep and the rebuild costs nothing; day11's BFS frontier reaches 129 and
  the answer is not a workaround but a better shape — a **level-synchronous** BFS steps the whole
  frontier at once and never pops anything. Set against C-113's 121 ms for one pop at depth 4000,
  the finding is now bracketed from both ends.
- **i64 traps rather than wrapping**, which nothing here had probed. day10's population reaches
  2.6 × 10²¹ and the i64 version dies with *"i64 overflow: … does not fit in 64 bits"*, naming the
  operation and both operands — better than C's silence and Java's wrap. The one complaint is
  F-006/F-008's: it locates at `wat/core.wat:66` rather than at the line that overflowed. The
  answer therefore has to be a bigint, and **F-060's missing `to-string` was worked around a
  second time in a second suite** with the identical helper `euler/` needed.
- **F-061 is the most expensive single gap for ordinary work.** day19 validates seven fields —
  four digits, six hex digits, nine digits, a number with a unit, a word from a set — and every
  one of them is a one-line regular expression in any language that has them. wat's whole regex
  surface is `matches?`, which answers a bool and cannot report what it matched, so each rule is
  a length check and a loop over `subs`. **150 lines of wat against 60 of Clojure**, for rules
  nobody would call hard. day15 and day22 pay smaller versions of the same tax (a run of spaces,
  and four splits where the reference writes one pattern).
- **`sort` takes no key**, and three puzzles reach three different verdicts. day17 packs a pair
  into one i64 (`lo * 1e9 + hi`) so that sorting the packed value sorts by `lo` — which is also
  why that puzzle's universe stops at 10⁹ rather than 2³², since `lo * 2³² + hi` overflows. day23
  sorts 20 000 items to look at 100, because there is no `take` that answers a Vector (F-088).
  day24 is the case where `sort` is exactly right.
- **P-028 asked its real question.** day06's memo needed capacity 3 — the recurrence's own order
  — so the Lru's fixed size never mattered and the ask was narrowed to "a cell whose size the
  caller does not have to know". day21's caller genuinely **cannot** know: 16 172 states is a
  property of the search, not of the input. The capacity has to be a bound on the state space
  instead, and getting it wrong fails **silently**, by recomputing.
- **And one place immutability is the point rather than the price.** day25's two herds move
  *simultaneously*, which a mutable grid has to be careful about — move one cucumber and the next
  sees the new state. Here there is no choice to get wrong: each step reads the old grid and
  builds a new one, and a square decides its own contents from three reads of something that
  cannot change underneath. The rebuild F-104 forces **is** the algorithm.
- **Two answers are not numbers.** day13 folds a sheet of dots until it reads and its second
  answer is six rows of `#` and `.`; day24's first answer is a comma-separated order. Both are
  compared to Clojure's character for character, which is a much harder thing to get accidentally
  right than an integer.
- **Class:** CLEAN. No new defect — every finding above is an existing one met at a new size or
  from a new direction, which is what an acceptance suite is for.
- **Repro:** `./run.sh aoc` — 25 passed, 0 failed.

### C-115: a wat program that emits a native executable — 166 bytes, no interpreter, no libc

- **Where:** `elf/hello.wat`, `tools/elf-run.sh`, `elf/README.md`. **`./run.sh elf` green**, and
  `tools/elf-run.sh` runs what it emitted.
- **The question was whether wat can produce a binary rather than be interpreted into one.** It
  can. `elf/hello.wat` computes the bytes of an x86-64 Linux ELF, writes them, reads them back
  and compares them, and the result runs on the kernel with no interpreter, no runtime and no
  libc. The 166-byte one is **byte-for-byte identical to a reference built independently in
  Python**, which is how it was checked before it was trusted.
- **It is a two-pass assembler, for the reason every assembler is.** The code contains the
  address of the message and the address depends on the length of the code, so pass one emits
  the text with the address at zero only to measure it, every address then follows from the
  lengths, and pass two emits it again for real. The program **asserts the two passes agree on
  size**, which is the invariant that makes the technique sound. Nothing in the layout — entry
  point, message address, `p_filesz` — is written down; it is all computed, and changing the
  message re-lays the file.
- **A second binary exists to show the code is chosen rather than pasted:** same headers, same
  layout arithmetic, different instructions, exiting with a status wat worked out as `6 * 7`.
  132 bytes, exits 42.
- **The door is F-118.** wat has no byte literal and no `i64 -> u8`; the only thing that can
  invent a byte is `:wat::core::Bytes::from-hex`. So the program assembles to a **hex string** —
  ordinary string work, which wat is good at — and decodes once at the end. That `Bytes` is
  accepted where a `Vector<u8>` is declared, in both directions, is undocumented and load-bearing.
- **ASCII without a character type.** There is no character-to-integer verb, so a character's code
  is found by its **index** in the 95-character printable range, which starts at 32. That is the
  whole encoder, and it is F-062 wearing a different hat.
- **Two things wat cannot do, and they are both about the OS rather than about bytes.** It cannot
  set the executable bit (`:wat::io::` has no `chmod`) and it cannot run the result
  (`:wat::kernel::spawn-process` forks a wat child that evaluates a source string, not an
  arbitrary program). So `tools/elf-run.sh` does those two steps and nothing else. Worth noting:
  `open-file` truncates rather than replaces, so the exec bit only has to be set **once** — after
  that a wat program alone keeps producing runnable binaries at that path.
- **Why this matters more than another port.** Every finding in this repository up to here is
  about wat as an interpreted host. This is the first evidence about wat as a **producer of
  native code**, which is the question its next phase actually turns on — and the answer is that
  the byte-level surface is sufficient, undocumented, and one verb short of comfortable.
- **Class:** CLEAN, with **F-118** raised.
- **Repro:** `./run.sh elf`; then `tools/elf-run.sh`.

### C-116: a compiler from wat source to x86-64, in wat — and the differential test that caught it lying

- **Where:** `elf/compile.wat`, `elf/lib/asm.wat`, `elf/src/*.wat`, `elf/refuse.wat`,
  `tools/elf-run.sh`, `elf/README.md`. **`./run.sh elf` green, `tools/elf-run.sh` green.**
- **C-115 emitted a binary its author chose. This one is given a wat PROGRAM and emits a binary
  for it.** The builder's own example —

  ```clojure
  (wat.core/defn user/main [] :- wat.type/nil
    (wat.kernel/println (wat.core/+ 2 2)))
  ```

  — compiles to a **272-byte static ELF** that prints `4` and exits 0, with no interpreter, no
  runtime and no libc.
- **The front end is four verbs wat already has**, and that is the finding that makes the rest
  possible: `read-string` turns source into a `:wat::WatAST`, and `ast-kind` / `ast->children` /
  `ast->source` walk it. `ast->source` makes `ast-name` unnecessary, which matters —
  **`ast-name` RAISES on any node that is not a symbol, keyword or string literal**, and a tree
  walk meets those constantly, so the obvious accessor is a trap and the less obvious one is
  total.
- **It is a real compiler, not a code generator.** Stack discipline (`push`/`pop` around every
  binary operator), n-ary `+ - *` folded left, nesting to any depth, negative literals, both
  name spellings, and a **real relocation**: `call print_i64` is a `rel32` computed in pass two.
  Two passes, for the reason every assembler has two, with an assertion that the passes agree on
  length. Anything outside the subset is a compile error **that names the form** —
  *"compile: cannot compile call: (wat.core/quot 10 2)"* — and `elf/bad/unsupported.wat` is a
  perfectly valid wat program the interpreter runs, so the refusal is about the compiler's
  subset rather than about the program. `elf/refuse.wat` is that negative test, checked by
  `tools/elf-run.sh` because a program meant to fail cannot pass `./run.sh`.
- **The check worth having is differential, and it earned its keep on the first run.** For every
  program in `elf/src/`, the compiled binary and the **wat interpreter** must print the same
  thing and exit the same way. They did not: the compiler was stripping the quotes from string
  literals and expanding their escapes, and `:wat::kernel::println` renders a String as **EDN** —
  `(println "a\nb")` writes `"a\nb"` and a newline, quotes kept, escape unexpanded. So the
  faithful compilation of a string literal is its **source text, verbatim**, and the compiler is
  now simpler than the wrong version was. Three programs, all agreeing.
- **F-035 costs more here than anywhere else in this repository.** An assembler is bit work by
  nature and wat has no shifts and no masks, so `& 0xff` is `rem 256`, `>> 8` is `/ 256`, and
  `~b` is `255 - b`. Two's complement for negative immediates is done the way the hardware does
  it — complement every byte and add one, **carrying by hand** — because the obvious route,
  adding 2⁶⁴, overflows `i64`, which traps rather than wrapping (the AoC day10 result, arriving
  somewhere it mattered). Every encoder was checked against Python's `struct.pack` before use.
- **F-118 is still the door**, and now it is load-bearing for a toolchain rather than for one
  file: the whole thing assembles to a hex string and decodes once, because `Bytes::from-hex` is
  the only verb in the language that can invent a byte.
- **What is not compiled, stated plainly.** The 105-byte `print_i64` runtime is hand-assembled
  and embedded — sign handling, a divide-by-ten loop building digits **on the stack** so the
  segment never needs to be writable, and one `write` syscall. It is the part a C toolchain calls
  libc for, and it was checked against a negative, a small value, zero and `i64::MAX` before it
  was embedded. Everything else in every output is computed from the source being compiled.
- **Why this matters.** Every other finding in this repository is about wat as an interpreted
  host. C-115 showed the byte surface is sufficient to author a binary; this shows the **language
  surface is sufficient to author a compiler** — wat can read wat, decide what it means, and emit
  machine code for it. Self-hosting is a long way off (this compiler uses strings, records,
  vectors, `match` and recursion, none of which it can compile) but the road exists, and the
  first three steps — `let`, `if`, and a calling convention — are days rather than months.
- **Class:** CLEAN. No new defect; F-035 and F-118 met where they cost the most, and one
  behaviour of `ast-name` worth knowing before reaching for it.
- **Repro:** `./run.sh elf`; then `tools/elf-run.sh`.

### C-117: `if`, `let` and user functions — the compiler is real, and compiled code is 565× the interpreter

- **Where:** `elf/compile.wat` (430 lines), `elf/lib/asm.wat`, `elf/src/*.wat`, `elf/refuse.wat`,
  `tools/elf-run.sh`. **`./run.sh elf` green; `tools/elf-run.sh` green — eight native binaries,
  six compiled from wat source, every one agreeing with the interpreter.**
- **What the compiler now accepts:** `defn` with typed parameters, `if`, `let` with shadowing,
  calls to user functions including recursion, `+ - *` n-ary, the six comparisons, `println` of
  an expression or a literal, both name spellings. `elf/src/fib.wat` is the program that settles
  whether it is real — two recursive functions, a `let`, and arithmetic wide enough to need 64
  bits — and it compiles to **659 bytes** that print `6765`, `1307674368000` and `175`.
- **The number.** `fib(27)`, the same source both ways:

  | | |
  |---|---|
  | wat interpreter | **3391 ms** |
  | compiled, native | **6 ms** (mostly `execve`) |
  | | **565×** |

  This is what NEXT.md §7's baseline was taken to make sense of, arriving from the other
  direction: the interpreter's per-operation cost — the 360 ns builtin, the 795 ns user call, the
  6130 ns record accessor — is exactly what a compiler removes, and it removes essentially all of
  it.
- **Three pieces of real compiler machinery**, none of which the first version had:
  1. **Forward branches are patched, not predicted.** `if` emits its `jz` with a zero operand,
     compiles the branch, and overwrites the operand once it knows the distance. That is **F-104
     on a String** — no positional update, so the patch is a `subs` either side of the hole —
     and it is the same problem C-106 met on a Vector in Crafting Interpreters chapter 23.
  2. **Two passes over the whole program, not one function.** A call needs the callee's address
     and that depends on the length of everything before it, so pass one compiles every function
     with every address zero purely to measure. The compiler asserts the passes agree **function
     by function**.
  3. **A calling convention.** Arguments pushed left to right, popped by the caller; argument *i*
     of *n* at `[rbp + 16 + 8*(n-1-i)]`, `let` slots at `[rbp - 8*(slot+1)]`. The frame size is
     computed before the body is compiled, by walking it for the deepest simultaneous `let`
     demand — a static analysis, which is the first thing here that is a *compiler* pass rather
     than a code generator.
- **The differential test carried all of it.** Six programs, each run both ways and required to
  match on output and exit status. Nothing in this chapter needed an oracle written for it: the
  interpreter is the oracle, which is the strongest position an acceptance test can be in.
- **What is still missing is all about DATA, and that is the finding.** Control flow and calls
  are solved. A compiler that could compile *itself* needs strings as values (length, `subs`,
  concatenation — so a heap), vectors and records (allocation and field offsets), `match` (which
  is `if` plus a tag test, so again a data-representation problem), and the substrate's own verbs
  (`read-string`, `ast->children`, `Bytes::from-hex`). **430 lines of wat compile a language with
  no heap; compiling the language those 430 lines are written in needs one.** That is the honest
  distance to self-hosting, and it is a shorter list than it was before this chapter.
- **Class:** CLEAN. No new defect; F-104 met on a String, and F-035's absence of shifts and masks
  paid again in every encoder.
- **Repro:** `./run.sh elf`; then `tools/elf-run.sh`.

### C-118: processes and threads, compiled — fork, clone, mmap and shared memory in 1269 bytes

- **Where:** `elf/compile.wat`, `elf/native/fork.wat`, `elf/native/thread.wat`,
  `elf/native/threads4.wat`, `tools/elf-run.sh`. **`./run.sh elf` green; `tools/elf-run.sh`
  green** — eleven native binaries, nine compiled from wat source.
- **The compiler now emits syscalls**, which turns out to be the cheapest thing in it: a bare
  syscall is a number in `rax` and `0f 05`, and everything else is argument marshalling. Added:
  `getpid`, `getppid`, `fork`, `exit`, `wait`, `mmap`, `clone`, `peek`, `poke` — plus
  `wat.core/do`, and `quot`/`rem` (`cqo; idiv rcx`), which were needed to decode a wait status.
- **fork works, and the proof is the exit code.** `elf/native/fork.wat` prints `1 2 7 1 1 4` in
  698 bytes: the parent prints 1, the child prints 2 and calls `exit(7)`, and the parent decodes
  **7** out of `wait4`'s raw status word with `(rem (quot st 256) 256)`. Two processes, and the
  parent observed the other one's death.
- **Threads work, and the proof is shared memory.** `clone` is called with
  `CLONE_VM | CLONE_FS | CLONE_FILES | SIGCHLD` on an `mmap`'d stack. `CLONE_VM` is what makes it
  a thread — the address space is shared, so a `poke` on one side is visible on the other.
  `SIGCHLD` rather than `CLONE_THREAD` keeps it waitable with the same `wait4`, because a thread
  proper is not a child in `wait`'s sense and this compiler has no futex.
  `elf/native/threads4.wat` starts **four** of them, each writing its own slot in a shared page,
  and sums: **1000**, in 1269 bytes, the same on five consecutive runs.
- **One honest limitation, stated in the source.** `clone` gives the child a fresh `rsp` but it
  inherits `rbp`, so the child reads its locals out of the **parent's** frame — which works only
  because the address space is shared, and only while that frame is live. `threads4.wat` is
  written so the parent reaps every child at the bottom of its recursion, before any frame
  unwinds. A compiler that wanted real threads would give the child its own frame at the clone
  site; this one documents why it does not.
- **And this is where the differential test ran out**, which is **F-119**. Everything in
  `elf/src/` is wat and is checked by running it both ways. Nothing in `elf/native/` is: the
  interpreter has no `wat.os/fork` and will not resolve the program at all. The split is
  structural — two directories — because the finding is structural: wat's OS surface is
  Rust-implemented inside the evaluator, so a compiled program cannot reach it, and there is no
  intrinsic set defined independently of the interpreter for it to target instead.
- **Class:** CLEAN, with **F-119** raised.
- **Repro:** `tools/elf-run.sh`.

### C-119: strings, compiled — a value model, a heap, a type pass, and wat's EDN escaping in 158 bytes of machine code

- **Where:** `elf/compile.wat`, `elf/src/strings.wat`, `elf/bad/nonascii.wat`,
  `tools/gen-refuse.sh`, `tools/elf-run.sh`. **`./run.sh elf` green (11/11); `tools/elf-run.sh`
  green** — twelve native binaries, ten compiled from wat source, **seven** of them checked
  against the interpreter.
- **This is the first compiled value that is not a machine word**, and the interesting part is
  that it still is one: a String is the address of `[len:8][bytes...]`, so it rides in `rax` like
  an integer and nothing else in the compiler had to change shape. Literals go in the read-only
  data tail; anything `concat` builds goes in a megabyte the entry stub `mmap`s, bump-allocated
  through **r15** — reserved for the program's whole life, callee-saved, and the entire memory
  model. No free, no collector, no bounds check.
- **It needed a type pass, for exactly one decision.** `println` has to know whether to call
  `print_i64` or `print_str`, and the argument can be a name, a branch, a call or a `let` — so
  there is now a two-type static pass (`i64`, `str`) that propagates what the *declarations*
  already say, through parameters, `defn` returns, `let` bindings, `if` arms and `do` tails. It
  is not inference; it reads `wat.type/String` and `:wat::core::String` by spelling, which is why
  it needs no table.
- **`print_str` is wat's EDN escaping in machine code**: a quote, a byte loop emitting one byte
  or two, a quote, a newline, one `write`. 158 bytes. Every escape in it was found by asking the
  interpreter what it printed, which is **F-120**.
- **`str_cat` is 97 bytes** and was hand-encoded, then checked against `as`/`objdump` byte for
  byte before it was embedded — as was `print_str`. The compiler's runtime is now three routines
  and 360 bytes.
- **The differential test is back, and it earned its keep on the first run.** `elf/src/strings.wat`
  exercises a String parameter, a String return, `let`-bound strings, `length`, both arms of an
  `if` typed as strings, forty allocations in a recursion, and all five escapes — and the binary
  matched the interpreter byte for byte, including `"q\" b\\ n\n t\t r\r ."`.
- **A second negative test, of a different kind.** `elf/bad/unsupported.wat` is refused for a
  *form* the compiler has no translation for; `elf/bad/nonascii.wat` is refused for a
  *representation* it cannot honour — byte length and character length part company outside
  ASCII (F-120). Both refusal drivers are now generated by `tools/gen-refuse.sh` from
  `compile.wat` itself, because a negative test that has drifted from the thing it tests proves
  nothing; the committed one had already drifted.
- **Class:** CLEAN, with **F-120** raised.
- **Repro:** `./run.sh elf` and `tools/elf-run.sh`.

### C-120: scope can free, and exactly where it stops — a region release at statement boundaries, in eight bytes per statement

- **Where:** `elf/compile.wat` (`:c::seq`, `:c::releasable?`), `elf/src/churn.wat`,
  `elf/src/shadow.wat`. **`./run.sh elf` green (13/13); `tools/elf-run.sh` green** — fourteen
  native binaries, twelve compiled from wat source, **nine** checked against the interpreter.
- **The question that started it, from the builder:** *"why don't we need to free stuff?.. like...
  wat doesn't need to express it.. but strings can have scopes?"* The answer was: we do, we were
  getting away with it because every compiled program was short, and here is the program that
  does not get away with it.
- **The red, captured first.** `elf/src/churn.wat` allocates a 32-byte string per level, asks its
  length, and throws the string away — 50000 levels, 2.4 MB against a 1 MiB heap. The interpreter
  printed `50000` and exited 0; the compiled binary died with **`Segmentation fault (core
  dumped)`, exit 139**.
- **The fix is eight bytes per statement.** A sequence's last form is its value; every form
  before it has its value discarded, so whatever it allocated is garbage the instant it finishes
  — and with a bump allocator, freeing all of it is putting the pointer back. `push r15 / push
  r15` before, `pop r15 / pop r15` after (twice, to keep the frame 16-byte aligned). The marks
  live on the stack, so it nests with no bookkeeping. churn now prints `50000`.
- **Why it is sound, which is the interesting half.** The release is safe only if nothing
  outliving the statement can hold a pointer into what it allocated, and in this language there
  are exactly two ways to store a pointer: a `let` slot, which is written inside the statement
  and out of scope when it ends because `:c::let-form` does not carry its environment back out;
  and **`poke`**, which can hand an address to anyone. So a statement containing a `poke`
  anywhere inside it is not released. The test is a substring of the statement's own source,
  crude in the direction that costs nothing — a false positive only declines to free memory.
- **And where it stops.** Anything whose allocation *escapes upward* still accumulates:
  `(user/stars 40 "")` in `elf/src/strings.wat` is a deliberate example, since each level's
  result is the next level's argument and every intermediate string is live until the outermost
  one is. Scope cannot free those; reachability can. The next step in the same direction is a
  caller-side release after every call whose return type is not a pointer — sound for the same
  reason, one level up — and after that it is a collector, which is a different program.
- **The builder's own example, compiled.** `elf/src/shadow.wat` is the program from the question:
  a `let` binds `x` to a string the body never uses, and the *function's* `x` is the value. The
  compiler gets it right by not carrying the `let`'s environment past its body, which is one line
  and is the whole of lexical scope. It also happens to be the case where scope-based freeing
  has nothing to do: the shadowed binding is a **literal**, which lives in the read-only data
  tail and was never on the heap at all. Scope of a NAME and lifetime of a VALUE are not the
  same question.
- **A latent silent divergence, found by writing that program and now closed.** It needed `nil`,
  which the compiler had no value for. Adding `nil` and `bool` exposed that
  `(wat.kernel/println (wat.core/> 3 2))` prints **`true`** in wat and would have printed **`1`**
  compiled — a disagreement no existing program happened to trigger. `println` now dispatches on
  all four printable types (`i64`, `str`, `bool`, `nil`), each with a program in `elf/src` that
  exercises it, and the runtime gained a fourth routine (`print_bool`, 75 bytes, building `true`
  and `false` on the stack so it needs no relocation).
- **No finding is filed against wat for any of this.** Lifetime is the compiler's problem, not
  the language's: wat is evaluated by a runtime that frees for you, and nothing about that is a
  gap. What the exercise produced is evidence for **F-119** and **F-120** rather than a new
  entry — a second implementation has to invent a memory model, and nothing in the language says
  what the first one does.
- **Class:** CLEAN.
- **Repro:** `./run.sh elf`, `tools/elf-run.sh`. For the red: remove the `41574157`/`415f415f`
  emission from `:c::seq` and run `elf/out/churn.elf`.

### C-121: tail calls, because wat has them — and the compiler measured against C on four axes

- **Where:** `elf/compile.wat` (`:c::TC`, `:c::tail-call?`, `:c::tail-store`), `elf/src/deep.wat`,
  `elf/bench/`, `tools/vs-c.sh`. **`./run.sh elf` green (14/14); `tools/elf-run.sh` green;
  `tools/vs-c.sh` green** — seventeen native binaries, fifteen compiled from wat source, **ten**
  checked against the interpreter.
- **This one is correctness, not speed.** wat's own documentation says so: *"Wat has TCO — the
  stack does not grow"*, and *"the tail call must be the LAST expression in the body"*
  (`wat-rs/docs/ITERATION-PATTERNS.md`, where a `defn` plus a tail call is the documented way to
  iterate with state). Verified both directions: a million levels of tail self-recursion answer
  `1000000` under the interpreter, and the same depth **not** in tail position dumps core. So a
  compiler that lays every call down as a `call` turns idiomatic, working wat into segmentation
  faults.
- **The red, captured first.** `elf/src/deep.wat`, a million tail calls: interpreter `1000000`
  exit 0, compiled binary **`Segmentation fault`, exit 139**.
- **The fix.** A self call in tail position becomes a `jmp` to the top of the body with the
  incoming arguments overwritten: arguments are all evaluated and pushed first, then popped back
  over the parameter slots last-first, then `jmp`. Evaluating before storing is what makes
  `(f (g b) (h a))` safe when the new `a` is computed from the old `b`. Tail position is
  threaded as a `:c::TC` record — name, arity, jump target — through `expr`, `form`, `seq`,
  `if-form`, `let-form` and `call-user`, matching wat's own definition of the value-producing
  position: the last form of a body or `do`, both arms of an `if`, the body of a `let`.
- **And it broke `threads4`, which is the instructive part.** A tail call reuses the frame, which
  is sound only while the frame is private to this thread — and `clone` hands a second thread an
  `rbp` pointing straight at it. With `user/spawn`'s tail call eliminated, the parent overwrote
  `i` while four children were still reading it and the answer fell from **1000 to 400**. So a
  function containing `clone` is not tail-call optimised, exactly as a statement containing
  `poke` is not heap-released (C-120). **Two optimisations, two soundness arguments, and the
  same intrinsic set breaks both** — which is more evidence for **F-119**: an intrinsic set needs
  a stated contract about what it does to the machine, not just an opcode.
- **Measured against C** (`tools/vs-c.sh`, gcc 16.2.1, glibc; best-of-5, one machine, one run —
  the numbers move with load and are here to set terms, not to win an argument):

  | | ours | C, libc removed | C, glibc static | C, glibc dynamic |
  | --- | --- | --- | --- | --- |
  | size, prints `4` | **695 B** | 968 B | 856,720 B | 15,968 B |
  | startup, 500 runs | 430 ms | **405 ms** | 596 ms | 761 ms |

  | | ours | gcc -O0 | gcc -O2 |
  | --- | --- | --- | --- |
  | fib(32) | 44 ms | 42 ms | **12 ms** |
  | 100000 integers out | 27 ms | — | **11 ms** |

- **What that actually says.** On size and startup we are level with C that has had libc removed
  — 695 bytes against 968, and startup inside noise of each other. Against C *with* glibc we are
  1200× smaller and about 30% quicker to start, and **all of that difference is libc**, not the
  compiler: the fair opponent is `-nostdlib`, and against it we are even. On compute we are a
  naive stack machine with no register allocator and we land exactly on **gcc -O0**, with `-O2`
  3.5× ahead of us. On output we lose 2.5×, and for a reason with a name: every `println` is a
  `write` syscall, where glibc's stdio buffers 4 KiB. That is the clearest thing left on the
  table and it is a dozen instructions.
- **Class:** CLEAN.
- **Repro:** `./run.sh elf`, `tools/elf-run.sh`, `tools/vs-c.sh`.

### C-122: buffered output — 106 bytes of runtime that beat glibc's stdio by 2.2×, and the fork trap that comes with it

- **Where:** `elf/compile.wat` (`:c::rt-buf-put`, `:c::rt-flush`, `:c::stub`), `tools/vs-c.sh`.
  **`./run.sh elf` green (14/14); `tools/elf-run.sh` green; `tools/vs-c.sh` green.**
- **The one benchmark we were losing, and why.** C-121 measured `println` at 27 ms against
  glibc's 13 ms for 100000 integers, because every `println` was a `write` syscall where stdio
  buffers 4 KiB. Now bytes go into a 4 KiB buffer at **r14**, laid out `[used:8][4096]`, and the
  syscall happens once per buffer. `buf_put` is 70 bytes, `flush` is 36, the copy is `rep movsb`,
  and `used` needs no initialising because MAP_ANONYMOUS memory arrives zero-filled.
- **The number turned over: 27 ms → 6 ms, against glibc's 13.** Both sides now do the same ~150
  syscalls, so the remaining gap is per-line work on the way to the buffer. `printf` walks a
  format string at runtime, takes the `FILE` lock, checks stream orientation and consults the
  locale; `print_i64` knows at compile time that it is printing an integer. **The gap is the
  generality, not the engineering** — which is the honest form of "libc carries things a program
  may not need".
- **Buffering is a promise you keep on every exit.** The stub flushes after `main` returns, or
  every program loses its last line. `exit` flushes before the syscall, parking the status on the
  stack while it does, because a flush clobbers rax, rcx, rdx, rsi and rdi. `clone` flushes,
  because `CLONE_VM` shares the buffer rather than copying it.
- **And `fork` flushes, which was worth demonstrating rather than asserting.** `fork` duplicates
  the address space, buffer included, so anything pending is written **twice**. Compiled with the
  flush removed, `elf/native/fork.wat` prints `1 2 1 7 1 1 4`; with it, `1 2 7 1 1 4`. The parent
  had buffered `1\n`, the child inherited a copy, and `exit(7)` flushed it again. That is the
  oldest bug in buffered I/O, reproduced here in a compiler written in wat.
- **Cost:** 773 bytes for the four-printing program, up from 695 — still smaller than the 968 of
  C with `-nostdlib`.
- **Also fixed on the way in, and worth recording because it was invisible.** The runtime is now
  assembled as ONE block so the routines can call each other, and the first build of it produced
  a binary that printed nothing at all. `as` had left `call flush` as `e8 00000000` — an
  unresolved *relocation*, because the symbols were declared `.globl` and `objcopy` does not
  apply relocations. The call jumped to the next instruction and quietly unbalanced the stack.
  Dropping `.globl` made them local and the assembler resolved them in place; the check is
  `objdump -r` showing no relocations left.
- **Class:** CLEAN.
- **Repro:** `tools/vs-c.sh`, `tools/elf-run.sh`.

### C-123: the self-hosting census, and the 46 occurrences it said to build first

- **Where:** `elf/census.wat` (new), `elf/compile.wat`, `elf/src/logic.wat`. **`./run.sh elf`
  green (16/16); `tools/elf-run.sh` green.**
- **Self-hosting is the objective, so it needed a number rather than a feeling.**
  `elf/census.wat` reads the AST of `elf/compile.wat` and `elf/lib/asm.wat` — the compiler's own
  source — asks of every form *"could `:c::form` translate this?"*, and tallies what is left,
  most frequent first. It is written in wat, using the same `read-string` walk the compiler uses.
  **The first honest answer was 56 distinct forms, 297 occurrences.**
- **What the table said to do first.** The top of it is not what intuition suggests. It is not
  `match` (3) or closures (1); it is `nth` (55), `length` (44), `cond` (18), `/` (14),
  `Vector` (12). Half the total is **one feature** — growable indexed sequences on the heap — and
  the next cheapest chunk was 46 occurrences of `cond`, `and`, `or`, `not` and `/`, which needed
  **no new codegen idea at all**: they are `if` wearing different hats, plus one `sete` and an
  alias from `/` to the `idiv` we already had for `quot`.
- **Built, with the semantics pinned down rather than approximated.** `and` and `or` answer the
  **first falsy / first truthy operand**, not a bool — which is wat's rule and also the cheapest
  possible code, since the deciding value is already in `rax` and the short circuit is one
  conditional jump to the end with nothing to load. `elf/src/logic.wat` tests exactly that, along
  with a `cond` in tail position that still eliminates its tail call, and `/` truncating toward
  zero on a negative. It agrees with the interpreter.
- **The census also moves as you build, which is worth knowing.** After the five forms went in,
  the total fell 297 → 274 and the distinct count 56 → 51 — but `nth` rose 55 → 65 and `length`
  44 → 54, because the compiler that has to be compiled had itself grown by five forms. A
  self-hosting target is not stationary; the honest measure is the ratio, not the count.
- **Two flaws in the first census, both found by reading its output and both instructive.**
  `cond` clauses are lists whose head is the *test*, so they were being tallied as forms — the
  fix is that only a symbol or keyword head is a call, since the two spellings read differently.
  And `let` bindings, `defn` parameters and `match` patterns live in **vectors**, which the walk
  was not descending into at all, so every initialiser was invisible. It also masked record
  accessors: `:c::Out/code` looks like a call into the program's own namespace, and is really a
  `defrecord` form the compiler would have to generate.
- **Where it stands.** 51 forms, 274 occurrences. `nth` + `length` + `Vector` + `conj` is **137
  of them, exactly half**, and is one feature. After that: the AST surface (`ast->source` 21,
  `ast->children` 13) and the I/O surface, which are **F-119** — Rust inside the interpreter, with
  no ABI for a compiled program to reach.
- **Class:** CLEAN, with **F-121** raised.
- **Repro:** `wat elf/census.wat`; `./run.sh elf`; `tools/elf-run.sh`.

### C-124: vectors and records, compiled — one layout, and the census falls 274 → 106

- **Where:** `elf/compile.wat`, `elf/runtime.s`, `elf/src/vectors.wat`, `elf/census.wat`.
  **`./run.sh elf` green (17/17); `tools/elf-run.sh` green; `tools/vs-c.sh` green.** Eighteen
  native binaries, sixteen compiled from wat source, **twelve** checked against the interpreter.
- **The census said this was half the distance, and it was more than that.** 51 distinct forms
  and 274 occurrences before; **26 forms and 106 occurrences** after. Vectors, records and their
  verbs were 168 of those occurrences — 61% — and what is left at the top is no longer a data
  structure but the **AST surface** (`ast->source` 28, `ast->children` 17) and string slicing
  (`subs` 16), which is a different kind of problem.
- **One layout answers all of it.** A Vector and a record are the same object —
  `[count:8][slot:8]...`, every slot a machine word — which is also what a String is if the
  payload is read as bytes. So `length` is one instruction for all three; `nth` and a field read
  are the same indexed load, and `conj` and `assoc` are the same copy. The only difference is
  that a record's field names are known at compile time, so its accesses are at constant offsets
  and its constructor can fill slots in **declaration** order regardless of the order the caller
  wrote them.
- **Three runtime routines, 118 bytes.** `vec_new` (21) bumps r15 past a header and n slots;
  `vec_conj` (48) copies with `rep movsq` and appends; `slot_set` (49) copies with one slot
  replaced. Everything is copy-on-write, because **F-104 is true in machine code as well**: there
  is no positional update, so `assoc` makes a new one, and `conj` is O(n) per call exactly as the
  interpreter's Vector is (F-023).
- **And then wat refused something the compiler could already do.** `(assoc v 1 99)` on a Vector
  is rejected by the interpreter — *"expected (HashMap :- [K V]), (PersistentMap :- [K V]), or
  `:wat::core::Record`"* — which is **F-104 in the language itself**. The machine code for it was
  already there and cost nothing extra, since `slot_set` takes an index and does not care where
  it came from. Compiling it anyway would have made the compiled language a **superset** of the
  interpreted one, which is the same drift **F-119** warns about, so it is refused instead. The
  refusal is also a measurement: **positional vector update is 49 bytes of runtime that wat does
  not expose.**
- **The heap went from 1 MiB to 64 MiB, and that is free.** `MAP_ANONYMOUS` is lazy, so pages are
  committed only when first touched. A megabyte was enough while only string concatenation
  allocated; building a 1000-element vector one `conj` at a time touches about 4 MB, and a
  megabyte segfaulted. `elf/src/vectors.wat` does exactly that and sums to `500500`.
- **A refactor made room for it.** Records and type aliases have to reach every part of the
  compiler, so the `fns` parameter became a `:c::Prog` carrying functions, records and aliases —
  one value instead of three more parameters on functions that already take nine. wat's type
  checker found every call site that needed changing, which is the argument for a checked
  language doing this kind of surgery.
- **Class:** CLEAN, with **F-122** raised.
- **Repro:** `wat elf/census.wat`; `./run.sh elf`; `tools/elf-run.sh`.

### C-125: what the memory model actually does — measured, including a test built to catch a premature free

- **Where:** `elf/src/memory.wat`, `elf/bench/grow*.wat`, `elf/bench/maxrss.c`, `tools/mem.sh`
  (new), `elf/runtime.s`, `elf/compile.wat`. **`./run.sh elf` green (18/18); `tools/elf-run.sh`
  green; `tools/mem.sh` green.**
- **The question, from the builder:** *"did we have freeing up stuff? memory management is
  handled correctly or no?"* — which deserved a test rather than the reasoning in C-120.
- **Is anything freed too early? No, and the test is built to catch it.**
  `elf/src/memory.wat` allocates `keep` (a Vector of strings) and `p` (a record) **first**, so
  they sit below the release mark; then runs **four** heavy discarded statements — 2×2000 string
  concatenations and 2×2000 `conj`s, about 4 MB — so the later ones **reuse the addresses the
  earlier ones used**; then reads `keep` and `p` back. A release that rewound too far would have
  had them overwritten by the second churn. Compiled output is byte-identical to the interpreter.
- **Why it is still sound now that there are vectors and records**, which C-120 could not have
  known: there is a third way to store a pointer — inside a heap object — but **everything is
  copy-on-write**, so a store always creates a *fresh* object rather than writing into an older
  one. A pointer can therefore only ever land in an object created at or after it, and both are
  inside the statement being released. The tail-call rewrite writes parameter slots, but only in
  tail position, which is never a released statement.
- **How much it reclaims: 2.9×.** Peak resident memory for `memory.wat`, measured with
  `ru_maxrss` out of `wait4` (there is no `/usr/bin/time` here, and a compiled binary cannot
  measure itself — F-119 again, so `elf/bench/maxrss.c` does it):

  | | peak RSS |
  | --- | --- |
  | compiled, release on | **31,908 KiB** |
  | compiled, release compiled out | 94,592 KiB |
  | the wat interpreter, same program | 70,688 KiB |

- **What it does NOT reclaim, which is the honest half.** Loop-carried allocation: in
  `(user/grow (- n 1) (conj acc n))` every intermediate vector is the *next call's argument*, so
  all n of them are live at once and scope cannot help. Memory is O(n²) — measured 17,580 KiB at
  n=2000 and 63,548 KiB at n=4000 against a 4n² prediction of 15,625 and 62,500. **Freeing those
  needs reachability, not scope** — a collector, or linear types that let `conj` mutate when the
  old vector is provably dead.
- **And running out is now a sentence rather than a signal.** `grow 8000` needs about 250 MB
  against a 64 MiB heap. It used to **segfault**; every allocator now checks `r15 + need` against
  a limit kept at `[r14+8]` *before it writes anything*, and jumps to an 89-byte `oom` routine
  that flushes stdout, puts `wat: heap exhausted` on stderr and exits 70. The limit lives beside
  the output buffer because there is no third callee-saved register to spare and no writable data
  section to put it in.
- **The honest summary:** correct, incomplete, and bounded. Nothing is freed too early; plenty is
  freed too late; and the ceiling is now reported instead of hit.
- **Class:** CLEAN.
- **Repro:** `tools/mem.sh`.

### C-126: does a compiled wat need a garbage collector? No — and the measurement says what it needs instead

- **Where:** `tools/mem.sh`, `elf/bench/`, and read-only greps of wat-rs. **No code changed for
  this entry**; it is the evidence behind a design question the builder asked: *"do we need a
  collector at all? rust gets away without having one... c doesn't need a gc, rust doesn't...
  zero gc pause... is that possible?"*
- **The premise checks out. Nothing here has a tracing collector, wat included.** wat-rs holds
  every value in an `Arc<...>` — `Arc<Vec…>`, `Arc<String>`, `Arc<HashMap…>`, `Arc<WatAST>` — and
  there is no mark phase, no sweep, no roots scan anywhere in the tree. So *"zero GC pause"* is
  not an aspiration for wat; it is already true.
- **But "no collector" is bought three different ways, and the difference is the whole answer.**

  | | who frees | cost | fails on |
  | --- | --- | --- | --- |
  | C | the programmer, by hand | none | use-after-free, double-free, leaks |
  | Rust | the compiler, statically, from **ownership in the types** | none | cycles (`Rc`), needs `&`/`&mut`/move to be expressible |
  | wat | `Arc`, at runtime, when the count hits zero | an atomic inc/dec per share | cycles |
  | `elf/`'s compiler | scope, at statement boundaries (C-120) | none | anything that outlives a statement |

- **The measurement that settles which one we have.** The same loop —
  `(user/grow (- n 1) (conj acc n))`, an accumulator that copies the whole vector every
  iteration — run both ways:

  | n | interpreter, peak RSS | compiled, peak RSS |
  | --- | --- | --- |
  | 5,000 | 70,420 KiB | — |
  | 10,000 | 72,488 KiB | — |
  | 20,000 | 75,740 KiB | — |
  | 40,000 | 79,516 KiB | — |
  | 2,000 | — | 17,580 KiB |
  | 4,000 | — | 63,548 KiB |
  | 8,000 | — | **`wat: heap exhausted`** |

  The interpreter's baseline is 70,736 KiB, so it is spending about **0.2 KB per element** —
  **linear**. Ours is **4n² bytes** — quadratic, and over at n=8000. Both run the identical
  algorithm doing the identical number of copies. The difference is entirely that `Arc` drops
  each dead clone the instant `conj` returns, and a bump pointer cannot know it happened.
- **So the honest standing is that we are *behind* wat here, not ahead**, and the gap is exactly
  refcounting. Scope-based release (C-120) is free and sound and covers everything that dies
  inside a statement — which is most of what a compiler-shaped program allocates — but it cannot
  see a value whose only reference is the next iteration's argument.
- **Can we have Rust's deal instead — zero runtime cost?** Not without wat expressing ownership.
  Rust's freedom from both GC and refcount overhead is bought by `&`, `&mut` and move semantics
  being *in the type system*: `fn f(v: Vec<T>)` and `fn f(v: &Vec<T>)` are different functions,
  and the compiler knows which one may free. wat's `acc <- (Vector :- [T])` says nothing about
  whether the caller kept a reference, so no compiler can decide it statically. **That is a
  language question, not a compiler question**, and it is the interesting one on the road to
  rivalling C: *if wat is to be compiled to C-class code, ownership has to become expressible.*
- **What to build, and why the obvious order is wrong.** The first instinct is a refcount plus a
  free list. But a refcount of 1 is **not** sufficient to mutate in place, and that is the trap:
  in `(wat.core/do (conj acc 1) (nth acc 0))` the slot holding `acc` is the only reference — count
  1 — and mutating would still be observable, because `conj` is pure and `acc` is read afterwards.
  Rust escapes this because `v.push(x)` takes `&mut v`, which makes the old value unreachable by
  construction; a pure `conj` has no such guarantee.
  So the mechanism has to be **a refcount AND a liveness analysis**: the count rules out aliases,
  and last-use rules out later reads. With both, `(conj acc n)` in a tail-recursive accumulator
  can extend in place — O(n) time and memory — while the `do` above still copies. **F-123 is the
  same wall seen from inside the interpreter**, where the fix is blocked by `conj`'s signature
  rather than by analysis.
- **Class:** CLEAN, with **F-123** raised.
- **Repro:** `tools/mem.sh`; the two loops in F-123.

### C-127: in-place `conj` — a share count and a last-use proof, and the accumulator goes from heap exhaustion to 8 bytes an element

- **Where:** `elf/runtime.s` (`vec_conj_own`), `elf/compile.wat` (`:c::occ`, `:c::linear-of`,
  `:c::share`), `elf/src/linear.wat`, `tools/mem.sh`. **`./run.sh elf` green (19/19);
  `tools/elf-run.sh` green (fourteen programs checked against the interpreter);
  `tools/mem.sh` green.**
- **The move C-126 named, built.** The accumulator loop — the shape `wat-rs/docs/
  ITERATION-PATTERNS.md` teaches for building up state — was the one thing scope-based release
  could not touch, because every intermediate is the next call's argument and all n are live at
  once. It now extends the vector in place instead of copying it.
- **A reference count of 1 is not enough, and that is the trap.** In
  `(wat.core/do (conj acc 1) (nth acc 0))` the slot holding `acc` is the *only* reference —
  count 1 — and mutating would still be wrong, because `conj` is pure and `acc` is read
  afterwards. Rust escapes this because `v.push(x)` takes `&mut v`, which makes the old value
  unreachable by construction. A pure `conj` has no such guarantee. **So in-place needs two
  proofs: a count to rule out aliases, and last-use to rule out later reads.**
- **Last use, by counting occurrences on the worst path.** `:c::occ` walks the body: the two arms
  of an `if` are alternatives so they are *maxed*, a `cond`'s tests are sequential so they are
  *summed*, everything else sums. A parameter read at most once on every path is read at most
  once, so any read of it is the last one. Over-counting only declines the optimisation, so the
  conservative direction is the safe one.
- **The count is increment-only, and that is deliberate.** Every heap object carries a count in
  the word *below* the pointer — `[rc:8]` at `[p-8]`, so every payload offset stayed where it
  was — set to 1 at allocation and incremented whenever a pointer *read out of a variable* is
  stored somewhere durable. It is never decremented. This is not reclamation; it answers one
  question — *"has this ever been shared?"* — and never decrementing means the answer can only
  become more conservative, never wrong. String literals in the read-only tail get a count of
  **0**, which no allocation can produce, so one can never be mistaken for a unique heap object.
- **Both halves are load-bearing, and `elf/src/linear.wat` proves it by failing without either.**
  `user/bump` reads its parameter once, so the *compiler* offers the fast path — but the caller
  still holds the vector, the count is 2, and the *runtime* copies. Remove the share increment
  and the program prints `99 4 5 4` instead of `99 3 102 3`: `base` comes back with four elements
  and a length that was never written. `user/twice` reads its parameter twice on one path, so the
  compiler never offers the fast path at all.
- **What it bought**, compiled, measured with `ru_maxrss`:

  | n | before | after | interpreter |
  | --- | --- | --- | --- |
  | 4,000 | 63,548 KiB | — | — |
  | 8,000 | **heap exhausted** | — | — |
  | 20,000 | — | 956 KiB · **3 ms** | 74,236 KiB · **4424 ms** |
  | 200,000 | — | 3,296 KiB · 3 ms | — |
  | 2,000,000 | — | 15,744 KiB · 19 ms | — |

  Eight bytes an element at two million, which is the vector and nothing else. The interpreter is
  quadratic in *time* here (F-123) and we are linear, so at n=20,000 this is **1400x faster and
  78x smaller** — and unlike the earlier benchmark wins, this one is a change of complexity class
  rather than a constant factor.
- **What it does not do.** Nothing is reclaimed when a value simply stops being used: the count
  never falls, so there is still no `free`. This buys the loop, not the general case. The general
  case needs decrements and a free list, and would buy back memory this does not — but the shape
  that was actually breaking programs is fixed.
- **Class:** CLEAN.
- **Repro:** `tools/mem.sh`; `tools/elf-run.sh`.

### C-128: in-place `concat`, and a test that proves memory is actually given back

- **Where:** `elf/runtime.s` (`str_cat_own`), `elf/compile.wat` (`:c::cat-fold`),
  `elf/src/freed.wat`, `elf/bench/cat32000.wat`, `tools/mem.sh`. **`./run.sh elf` green (20/20);
  `tools/elf-run.sh` green (fifteen programs checked against the interpreter); `tools/mem.sh`
  and `tools/vs-c.sh` green.**
- **The builder asked whether there was a next move and whether anything proved we free. Both
  answers turned out to be yes, and the first one was blocking self-hosting.** C-127 gave `conj`
  an in-place path. `concat` did not get one — and `concat` is the accumulator
  **`:c::emit` is built out of**, the hottest thing in the compiler. Measured before touching it:

  | | time | peak RSS | result |
  | --- | --- | --- | --- |
  | 2000 concats | 38 ms | 31,764 KiB | 32000 |
  | 8000 concats | — | — | **`wat: heap exhausted`** |
  | 32000 concats | — | — | **`wat: heap exhausted`** |

  A compiler that cannot append to a string eight thousand times cannot compile itself.
- **`str_cat_own`, 86 bytes, the same two proofs.** A String is `[rc:8][len:8][bytes padded to
  8]`, so appending in place costs **nothing at all** while the padding has room, and one bump
  when it does not. After the fix: **32000 concats in 4 ms and 968 KiB**, flat in both.
- **One thing fell out that `conj` did not need.** `concat` is n-ary and folds left, so only the
  *first* operand came from somewhere else — every step after it works on a temporary this
  expression just made, which nothing else can be holding. So the last-use proof is required
  once and free thereafter.
- **And the proof of freeing, which nothing in the repository had.** Everything else shows memory
  is not freed too *early*. `elf/src/freed.wat` shows it is freed *at all*: it allocates about
  **650 MB — ten times the whole heap —** and completes, which it can only do if the space is
  being reused. Peak RSS is **7,880 KiB**, about one round of 6.5 MB rather than the 650 MB
  total. The shape defeats both optimisations on purpose: `user/copies` reads its string twice on
  its path so it is not linear and every concat is a real 64 KB copy, and `user/burn` calls it as
  a **discarded statement** so each round's 6.5 MB is released at the boundary and the next round
  reuses the same addresses.
- **The counterfactual, run rather than asserted.** Compile the statement release out and the same
  program stops after its first line with `wat: heap exhausted`, exit 70.
- **Where this leaves the memory model.** Three mechanisms, none of them a collector: scope
  release at statement boundaries (C-120), in-place update behind a share count and a last-use
  proof (C-127, C-128), and a bounds check that reports exhaustion instead of faulting (C-125).
  What is still missing is reclamation of a value that stops being used *mid-statement* — the
  share count never falls, so there is no per-object `free`. The next honest step is decrements
  and a free list, and the workload that would justify it is the compiler compiling itself.
- **Class:** CLEAN.
- **Repro:** `tools/mem.sh`, sections 4 and 5.

### C-129: the string verbs a reader is made of — and a read-only-segment fault the differential test caught on its first run

- **Where:** `elf/runtime.s` (`str_subs`, `str_starts`, `str_contains`, `i64_to_str`),
  `elf/compile.wat`, `elf/src/strverbs.wat`, `elf/census.wat`. **`./run.sh elf` green (21/21);
  `tools/elf-run.sh` green (sixteen programs checked against the interpreter); `tools/mem.sh`
  and `tools/vs-c.sh` green.**
- **Aimed by the census, which is the point of having one.** `subs` alone was sixteen occurrences
  of the 117 standing between the compiler and compiling itself, and a lexer is `subs`,
  `starts-with?` and a comparison in a loop. Four routines, 258 bytes: `str_subs` (66),
  `str_starts` (40, `repe cmpsb`), `str_contains` (68, the naive search, which is what the
  interpreter's is at this size) and `i64_to_str` (84, `print_i64`'s divide-by-ten loop landing
  in the heap instead of the output buffer).
- **Census: 117 → 89 occurrences, 26 → 22 forms.** And the shape of what is left changed
  completely. It is now **56 of 89 — 63% — in one place**: `ast->source` (33),
  `ast->children` (21), `ast-kind`, `read-string`. Everything else is a tail: seven
  `assertion-failed!`, five `assert-eq`, four calls to a closure, three `match`, and singletons.
- **The bug, which is the part worth recording.** Adding the verbs turned three programs into
  segmentation faults at once, and they had one thing in common: a **String parameter passed on
  through a recursive call**. The share increment from C-127 emits `incq [rax-8]` when a pointer
  read out of a variable is stored somewhere durable — and a string **literal** lives in the
  read-only segment, so incrementing its count faults. Nothing had caught it because no earlier
  program let a literal reach a *variable* and then be shared; passing a literal directly is a
  different code path.
- **The fix is also the honest one**: a literal's count is **zero** by construction, which
  already means *never eligible for in-place*, so the increment is guarded —
  `cmp [rax-8],0 ; je +4 ; incq [rax-8]`, eleven bytes. Skipping it costs nothing and writing it
  was a fault.
- **This is the differential test earning its keep for the fourth time** (after the string-literal
  rendering in C-115, the `threads4` frame reuse in C-121, the `fork` double-flush in C-122, and
  the missing share increment in C-127). The pattern is consistent: every one of these was a
  silent divergence or a fault that no amount of reading the code would have found, and every one
  was caught by running the same source both ways.
- **Class:** CLEAN.
- **Repro:** `tools/elf-run.sh`; `wat elf/census.wat`.

### C-130: wat's reader, written in wat — 11,638 nodes agreeing with wat's own, including the compiler itself

- **Where:** `elf/lib/reader.wat` (new), `elf/src/reader.wat`, `elf/conform.wat` (new),
  `elf/compile.wat`. **`./run.sh elf` green (23/23); `tools/elf-run.sh` green (seventeen
  programs checked against the interpreter); `tools/mem.sh` and `tools/vs-c.sh` green.**
- **This is the 56-of-89 item.** `ast->source`, `ast->children`, `ast-kind` and `read-string` are
  Rust inside the interpreter with no ABI a compiled program can reach (**F-119**), so a
  self-hosting compiler either gets an intrinsic contract or owns its reader. It owns it now:
  187 lines of wat that lex and parse wat, compiled to an 8,865-byte binary.
- **Nodes live in an arena.** A record whose field is a Vector of that same record is a recursive
  type; an arena — a Vector of records referred to by index — sidesteps it entirely and makes a
  node cheap to pass. `rd/kind`, `rd/text` and `rd/kids` are then exactly `ast-kind`,
  `ast->source` and `ast->children`.
- **`elf/conform.wat` is the test that matters.** Self-consistency — saying the same thing
  compiled and interpreted — is not the same as being *right*. So this reads real wat source
  **both ways** and walks the two trees in step, asserting the kinds agree, compound forms have
  the same number of children, and atoms have the same text:

  | corpus | nodes | top-level forms |
  | --- | --- | --- |
  | `elf/lib/asm.wat` | 658 | 18 |
  | `elf/src/vectors.wat` | 272 | 6 |
  | `elf/src/logic.wat` | 187 | 3 |
  | `elf/src/strings.wat` | 110 | 3 |
  | `elf/lib/reader.wat` (itself) | 978 | 25 |
  | **`elf/compile.wat`** | **9,433** | **192** |

- **One deliberate difference, and not a finding.** Compound forms are compared structurally
  rather than by text, because **`ast->source` is a re-printer, not a slice of the file**: give
  it `"(a\n  b)"` and it answers `"(a b)"`. wat-rs says so where it is implemented — *"DISPLAY,
  not transport … a rendering is allowed to be pretty"* — and offers `ast-span`, `ast-end-span`
  and `read-string-with-comments` for the other job. Our reader keeps the bytes it was given.
  Both are right; they are answering different questions.
- **`load-file!` became a compile-time include**, which is what lets the reader be a library two
  programs share: `elf/src/reader.wat` compiles it, `elf/conform.wat` checks it. The compiler
  reads the named file relative to the file that named it and collects its top level, exactly as
  the interpreter resolves it.
- **And a silent divergence closed on the way in, which the reader would have been built on.**
  `(wat.core/= a b)` on two Strings compiled to a machine-word compare — that is a **pointer**
  comparison. `(= (concat "ab" "c") (concat "a" "bc"))` answered `false` where the interpreter
  answers `true`. Nothing had noticed because no program in `elf/src` compared two strings, and a
  lexer is the first thing that must. The type pass knows both operand types, so `=` and `not=`
  on two `str` operands now call a 40-byte `str_eq`. **This is the fifth time the differential
  test has caught something reading the code would not have.**
- **What it does not do yet.** The census did not fall — it went 89 → 91, because `:c::compile`
  itself grew while gaining `load-file!`. The reader does not reduce the number until the
  compiler is rewritten to call it. What changed is the **kind** of work left: the largest item
  stopped being *"needs a capability nothing has"* and became *"needs 58 call sites renamed"*.
- **Class:** CLEAN.
- **Repro:** `wat elf/conform.wat`; `tools/elf-run.sh`.

### C-131: the compiler now runs on its own reader — census 297 → 21, and what is left is F-119 and nothing else

- **Where:** `elf/compile.wat`, `elf/lib/reader.wat`, `elf/census.wat`. **`./run.sh elf` green
  (23/23); `tools/elf-run.sh` green (seventeen programs checked against the interpreter);
  `tools/mem.sh` and `tools/vs-c.sh` green.**
- **`read-string` and the `ast->*` verbs are gone from the compiler.** A node is now an index into
  an arena rather than a `:wat::WatAST`, and `:c::kind` / `:c::text` / `:c::kidsof` read it
  through `:c::Prog`, which was already threaded everywhere. 28 type annotations, 35
  `ast->source` and 23 `ast->children` call sites, done mechanically with wat's type checker as
  the net — and then the *runtime* found thirteen helpers that used the context without taking
  it, which the checker had let through.
- **`load-file!` reads into the same arena**, because two arenas would give two node 7s.
- **Two more removed by rewriting the compiler rather than the compiler's language.** The `int`
  closure became `:wat::i64::to-string` at each of its four call sites. And `:c::to-int` stopped
  going through `:wat::string::to-i64`, whose `Option` needs `match`: it folds over the
  characters instead, which needs nothing but arithmetic. That is the bootstrap subset doing its
  job — a compiler is allowed to be written in the language it compiles.
- **The census, over this session:**

  | | forms | occurrences |
  | --- | --- | --- |
  | first count (C-123) | 56 | 297 |
  | after `cond`/`and`/`or`/`not`/`/` | 51 | 274 |
  | after vectors and records (C-124) | 26 | 106 |
  | after the string verbs (C-129) | 22 | 89 |
  | after the reader (C-130, + `load-file!`) | 21 | 91 |
  | **now** | **12** | **21** |

- **And the 21 that remain are one thing.** Five `assertion-failed!` and five `assert-eq` are
  diagnostics — a compiled program can print and exit, and they differ only on the failure path.
  The other eleven are **`:asm::write-bytes` and `:asm::read-hex`**: `Bytes::from-hex`,
  `Bytes::to-hex`, `IOReader/open-file`, `read-all`, `IOWriter/open-file`, `write-all`, `close`,
  `flush`, two `read-file`, and the last `match`. Every one of them is the ELF actually reaching
  the disk.
- **That is F-119 with nothing else left standing in front of it.** A compiled program can open
  and write a file — it is three syscalls. What it cannot do is call *wat's* `:wat::io::` verbs,
  because those are Rust inside the evaluator. And it cannot route around them through a String,
  because a String is UTF-8 in the interpreter and a byte array in the compiled world (F-118,
  F-120), so the two would disagree on the first byte above `0x7f` — which an ELF header has in
  its second byte. **The last mile of self-hosting is a verb with two implementations, which is
  exactly the contract F-119 asked for.**
- **Class:** CLEAN.
- **Repro:** `wat elf/census.wat`; `./run.sh elf`; `tools/elf-run.sh`.

### C-132: **the compiler compiles itself, and the result reproduces itself byte for byte**

- **Where:** `elf/compile.wat`, `elf/lib/prim.wat` (new), `elf/runtime.s`, `tools/bootstrap.sh`
  (new), `elf/src/diag.wat`, `elf/src/fileio.wat`, `elf/src/asmbits.wat`. **`./run.sh elf` green
  (26/26); `tools/elf-run.sh` green (twenty programs checked against the interpreter);
  `tools/mem.sh`, `tools/vs-c.sh` and `tools/bootstrap.sh` green.**
- **The result:**

  ```
  == stage 0: the interpreter runs the compiler ==
     36 binaries in 64877 ms, the compiler among them (96793 bytes)
  == stage 1: the compiler, compiled, runs itself ==
     the same work in 425 ms -- 152x faster than the interpreter
  == every binary, from both ==
     35 binaries, all byte-identical
  == the fixpoint ==
     stage1 == stage2, byte for byte (96793 bytes)
     The compiler reproduces itself.
  ```

  A wat program, compiled to a 96,793-byte static ELF by a compiler written in wat, compiles that
  same compiler to the same 96,793 bytes. **235 functions, 73,736 bytes of code, 20,878 of data,
  no libc and no interpreter.**
- **What the last three steps were.** *Diagnostics* — `assertion-failed!` and a failed
  `assert-eq` compile to an 81-byte `die` that flushes stdout, puts the message on stderr and
  exits 70; the message is the assertion's own source text, which the compiler has. *The two
  verbs that reach the disk* — `prim/write-hex` and `prim/read-hex` have a wat definition in
  `elf/lib/prim.wat` for the interpreter and a native implementation in the compiler, and a
  **`defn` whose name is a primitive is skipped when compiling**. That is F-119's contract stated
  in one sentence, and `elf/src/fileio.wat` runs both ways to prove the two agree. *And
  `wat.io/read-file`*, which is wat's own verb, compiled to open/read/close.
- **Two bugs found by compiling the compiler, both invisible until then.**
  1. **`syscall` destroys `rcx` and `r11`** — the instruction uses them to save `rip` and
     `rflags`. The file primitives parked their buffer pointer in `r11` across `open`, so `write`
     got a garbage address and answered `-14`, EFAULT. Moved to `r12`.
  2. **`:c::body-start` scanned forward for the first child that was a LIST.** That is right for
     every body that is a call and wrong for every body that is not. `:asm::printable` returns a
     bare string literal, so the scan ran off the end, the body compiled to nothing, and a
     95-character table came back with **length 0**. The compiler had carried that since its
     first commit; no program in `elf/src` had a literal for a body, and nothing noticed until it
     compiled itself. A `defn`'s body starts at index five, always.
- **That second one is the argument for bootstrapping in one line.** The differential test caught
  five silent divergences over this session; this one it could not, because no test program had
  the shape. **Compiling the compiler is a test with 1,900 lines of adversarial input written by
  someone who was not trying to break it.**
- **Where the census ended.** It began at 56 forms and 297 occurrences (C-123) and ended at
  **zero**. Every form `elf/compile.wat` and its libraries use is one the compiler can translate.
- **Class:** CLEAN.
- **Repro:** `tools/bootstrap.sh`.

### C-133: using the bootstrap as the test — two peephole wins, and the one that caught itself

- **Where:** `elf/compile.wat` (`:c::direct`, `:c::if-cmp`). **`./run.sh elf` green;
  `tools/elf-run.sh` green (twenty programs); `tools/bootstrap.sh` green, fixpoint holds.**
- **Measured in the same breath, best of nine, `fib(32)`:**

  | | before | after |
  | --- | --- | --- |
  | ours | ~53 ms | **30 ms** |
  | gcc -O0 | 34 ms | 34 ms |
  | gcc -O2 | 9 ms | 9 ms |

  Now **ahead of `gcc -O0`**, and 3.3x off `-O2`. (Numbers taken across a busy machine swung
  47/34/37 on the same binary; only a side-by-side run in one breath is worth quoting.)
- **The direct operand.** `(wat.core/- n 1)` was six instructions — push rax, load 1, mov rcx,
  pop rax, sub — because a compiler with no register allocator keeps everything in rax and the
  stack. But x86 takes the right operand straight from an immediate or from memory, and the two
  shapes that matter are the two a program writes most: a constant and a name. Both collapse to
  **one instruction**. `quot`/`rem` are excluded because `idiv` wants rcx anyway.
- **Branching on the flags.** `(if (< n 2) …)` computed the comparison into rax — `cmp`, `setcc`,
  `movzx` — then threw it away with `test rax,rax` and a `jz`. A comparison in an `if` condition
  now emits the compare and the **opposite** jump straight to the else.
- **And that one caught itself, immediately, which is the point.** The first bootstrap after it
  failed with *"only defn, defrecord, typealias and load-file! at the top level"* on an ordinary
  `defn` — because `:c::cmp-cond` recognised a comparison **by spelling** and `(wat.core/not=
  fast "")` is a comparison by spelling and a `str_eq` call by meaning. Branching on
  `cmp rax, <address>` compares pointers, so the compiler stopped recognising its own `defn`s.
  It is F-120's cousin for the third time, and the fix is a type test: only machine words branch
  on flags.
- **What this says about the loop.** The differential suite passed that build. `elf-run` passed
  that build. The thing that failed was the compiler reading 1,900 lines of its own source — and
  it failed on the *first* function it looked at. **A bootstrap is not a slower test, it is a
  differently-shaped one**, and it is the only one in this repository whose input was not written
  by someone thinking about the compiler.
- **Cost of an iteration, measured:** stage 0 through the interpreter is 65–85 s, `elf-run` about
  60 s, and `bootstrap.sh` another 150 s because it redoes stage 0. So a change costs three to
  five minutes of wall clock, **and 99% of that is the interpreter**: the compiled compiler does
  the same work in 0.5 s.
- **Class:** CLEAN.
- **Repro:** `tools/bootstrap.sh`; `tools/vs-c.sh`.

### C-134: the iteration loop the bootstrap was for — 3–5 minutes to 4.1 seconds

- **Where:** `tools/loop.sh` (new), `tools/bootstrap.sh --fast`, `tools/elf-run.sh`.
  **Full `tools/bootstrap.sh` green (fixpoint at 99,203 bytes); `tools/elf-run.sh` green;
  `./run.sh elf` green (26/26).**
- **The loop was paying for the thing the bootstrap had just made unnecessary.** Measured in
  C-133: a change to `elf/compile.wat` cost three to five minutes of wall clock, and **99% of it
  was the interpreter** — stage 0 at 65–85 s, then `bootstrap.sh` doing stage 0 again, then
  `elf-run.sh` re-running the interpreter once per program for the differential oracle.
- **Three changes, in order of what each was worth:**

  | | before | after |
  | --- | --- | --- |
  | `bootstrap.sh --fast` — seed from the compiler already built | 65–85 s | **1.2 s** |
  | cache the interpreter's oracle by source hash | ~30 s | ~1 s |
  | skip the fib(27) benchmark when not rebuilding | 4 s | 0 |
  | **`tools/loop.sh` total** | **3–5 min** | **4.1 s** |

- **What `--fast` actually proves, which is the subtle part.** It seeds from the *old* compiler
  binary: that builds the new source to stage 2, stage 2 builds it again to stage 3, and
  **stage 2 == stage 3 is the fixpoint for the new compiler**. Stage 2 differing from the seed is
  *expected* — that is what a change to the code generator means. Stage 2 differing from stage 3
  is the bug. The full run stays the pre-commit gate, because only it proves the chain still
  starts from source a human can read rather than from a binary nobody can.
- **The oracle cache is sound for the same reason the oracle is.** The interpreter's answer for a
  program depends on exactly two things — that source and which `wat` binary is asking — so the
  cache key is the source's hash and the binary's size and mtime. A change to the *compiler*,
  which is most changes, then costs no interpreter runs at all.
- **And the benchmark stopped being run as a test.** `fib(27)` interpreted is four seconds, which
  was over half the remaining loop, and it measures rather than checks. It runs on the full path.
- **Class:** CLEAN.
- **Repro:** `tools/loop.sh`; `tools/bootstrap.sh`.

### C-135: short encodings — 13% smaller output, and a hardcoded 11 that the tail calls were built on

- **Where:** `elf/compile.wat`. **`tools/loop.sh` green in 4.2 s; fixpoint holds.**
- **x86 encodes a small displacement in one byte and a large one in four**, and the same for an
  immediate. Every frame access this compiler emitted used four bytes of displacement where one
  would do, every literal was a ten-byte `movabs`, and a function with no `let` slots still got
  `sub rsp, 0` spelled out in seven bytes. Disassembling `fib` made all of it obvious at once.
- **Why it needed thinking about rather than just doing.** The two-pass technique compiles once
  with every address zero purely to measure, and the second pass must come out the same length.
  So anything whose value *changes* between the passes has to stay fixed-width. Frame
  displacements and source literals do not change — the frame layout and the program text are
  the same both times — while addresses do. `mov-rax` keeps its `movabs` for addresses, a source
  literal gets a seven-byte `mov`, and every call and jump keeps its rel32.
- **Result:** the compiler's own code went **74,938 → 61,577 bytes** and the binary **99,203 →
  86,250**, about 13%. `fib(32)` was unchanged within noise (33 ms against gcc -O0's 32,
  side by side) — the same instructions, fewer bytes.
- **And it broke every tail call, for a reason worth recording.** `:c::compile-fn` set the
  tail-call jump target to `base + 11` — *"push rbp (1) + mov rbp,rsp (3) + sub rsp,imm32 (7)"*.
  The moment the prologue stopped being seven bytes of `sub rsp`, every self tail call jumped
  into the middle of its own body. `four`, `arith` and `fib` still passed, because none of them
  has a tail call; `logic`, `vectors`, `strings` and `reader` all dumped core. The target is now
  `base + (:c::codelen o1)` — wherever the prologue actually ended — which is what it should
  have said in the first place.
- **The loop paid for itself here.** Change, `tools/loop.sh`, four seconds, four core dumps,
  fixed, four seconds, green. That cycle used to be three to five minutes.
- **Class:** CLEAN.
- **Repro:** `tools/loop.sh`.

### C-136: register allocation, and the measurement that said to give it to loops only

- **Where:** `elf/compile.wat` (`:c::Bind/reg`, `:c::tail-self?`, `:c::reg-*`), `elf/runtime.s`.
  **Full `tools/bootstrap.sh` green — 37 binaries byte-identical, fixpoint at 91,339 bytes;
  `tools/elf-run.sh` green; `./run.sh elf` green (26/26); `tools/vs-c.sh` green.**
- **The mechanism.** A parameter can live in `rbx`, `r12` or `r13` instead of the frame. Those
  three are callee-saved in the System V ABI, which is the entire reason they work: a call cannot
  clobber them, so a parameter read *after* a call is still there. The four runtime routines that
  used them as scratch — `slot_set` and the three file primitives — now save them.
- **And doing it everywhere was wrong**, which only a measurement could say:

  | | registers | frame |
  | --- | --- | --- |
  | `mix` — 200M iterations, three parameters read four times each | **384 ms** | 597 ms |
  | `fib(32)` — one parameter, an enormous number of ordinary calls | 40 ms | **32 ms** |

  A push, a load and a pop in the prologue, against one memory reference saved per read in the
  body. Whether that pays depends entirely on **how many times the body runs per prologue**. In a
  tail-recursive loop the prologue runs once and the body runs n times. In `fib` the prologue
  runs on *every* call and the body is three instructions, so the saving never arrives and the
  save/restore is pure cost — the loads it replaced were L1 hits either way.
- **So the registers go to functions that loop.** `:c::tail-self?` walks the body in tail
  position — through `if` arms, `cond` bodies, `do` and `let` tails — looking for a self call at
  the end. That is exactly the shape that pays, and it gets **both** numbers rather than trading
  one for the other:

  ```
  mix     343 ms   (registers everywhere 384, frame everywhere 597)   1.74x
  fib32    31 ms   (registers everywhere  40, frame everywhere  32)
  ```

- **`fib(32)` against C, from `tools/vs-c.sh`:** ours 36 ms, gcc -O0 37 ms, gcc -O2 10 ms.
- **What the loop was for.** That A/B needed four separate compiler builds to do honestly — with
  registers, without, and the two programs from each — and every one of them took half a second
  (C-134). Without it the guess *"registers are faster"* would have shipped, and with it the
  `fib` regression. **The cheap loop did not make the work faster so much as make it correct.**
- **Class:** CLEAN.
- **Repro:** `tools/loop.sh`; `tools/bootstrap.sh`; `tools/vs-c.sh`.

### C-137: expression temporaries in registers — worth 7–9%, and a gigabyte of the compiler's own memory found on the way

- **Where:** `elf/compile.wat` (`:c::scratch-safe?`, `:c::scratch-need`, `:c::scr-*`).
  **Full `tools/bootstrap.sh` green — 38 binaries byte-identical, fixpoint at 95,879 bytes;
  `tools/elf-run.sh` green; `./run.sh elf` green (26/26); `tools/vs-c.sh` green.**
- **What was left on the stack.** C-133's direct operand collapses a right operand that is a
  constant, a frame slot or a register parameter. What it cannot help is a **compound** one —
  `(+ a (* b c))`, `(nth v (+ i 1))` — which still went push accumulator, evaluate into rax,
  `mov rcx,rax`, pop, combine. Three instructions and two memory references to hold one value.
- **r8 through r11 survive exactly when the operand emits no call**, and nothing else this
  compiler generates touches them. So the question is decidable by looking at the subtree, and
  the answer is a whitelist: arithmetic, comparisons, the logical forms, `if`, `cond`, `let`,
  `do`, `nth`, `length`, `peek`, and leaves. **`=` and `not=` are deliberately off it**, because
  on two Strings they call `str_eq` (C-130) and that is a question about types this analysis does
  not have.
- **Nothing is threaded.** How many of the four a subtree needs is computed bottom-up: an operand
  needing k registers is evaluated with 0..k-1, which leaves k free for the value waiting on it.
- **Measured, both benchmarks, A/B against the same compiler with the pool disabled:**

  | | registers | stack |
  | --- | --- | --- |
  | `poly` — 100M iterations, compound right operands | **372 ms** | 398 ms |
  | `mix` — 200M iterations | **332 ms** | 366 ms |

  **7–9%**, consistent and smaller than it looks like it should be. The reason is that the direct
  operand had already taken the common cases, and a `push`/`pop` pair forwards through L1 nearly
  for free on this hardware. `fib(32)` is now **29 ms against gcc -O0's 32 and -O2's 9**.
- **And the first run found something bigger than the optimisation.** `tools/loop.sh` failed with
  `wat: heap exhausted` — not a bug in the new code, since all twenty differential programs
  agreed, but the compiler's own memory. **Compiling itself peaks at 1.09 GB**, and the heap was
  a gibibyte. That is C-125's stated limitation arriving on the only workload large enough to
  show it: nothing is reclaimed except at statement boundaries, and a 2,200-line compile builds a
  gigabyte of intermediate hex strings that stay live until their enclosing statement ends.
  Raised to ~1.9 GB, which costs nothing while untouched — and it is now the clearest argument
  for the decrements and free list C-128 said were still missing.
- **Class:** CLEAN.
- **Repro:** `tools/bootstrap.sh`; `tools/vs-c.sh`; `elf/bench/poly.wat`.

### C-138: three text searches standing in for structure questions — one of them unsound

- **Where:** `elf/compile.wat` (`:c::scratch-safe?`, `:c::releasable?`, `:c::has-clone?`).
  **Full `tools/bootstrap.sh` green — 38 binaries byte-identical, fixpoint at 98,255 bytes;
  `tools/elf-run.sh` green; `./run.sh elf` green (26/26).**
- **Prompted by the builder reading C-137's write-up:** *"how are we forgetting type? we call them
  in every meaningful location... don't we have a registry to query?"* The answer was that we do,
  in all three places, and the compiler was grepping its own source text instead.
- **`:c::scratch-safe?` (C-137) excluded `=` and `not=`** on the grounds that on two Strings they
  call `str_eq` and "the analysis does not have types". It did not have them because I had not
  threaded `env` into it — while `:c::cmp-cond`, twenty lines away, already did exactly this
  check for `if` conditions. Now threaded and asked. **Honest result: every emitted program is
  byte-identical.** No program in `elf/src` has an integer comparison inside a fold's right
  operand, so it bought nothing. It is right rather than conservative-by-omission.
- **`:c::has-clone?` was `(contains? (text pg node) "clone")`.** A variable named `clone-count`
  or a string literal containing the word would have silently switched off tail calls and
  register allocation for that function. Now an AST head walk. Fail-safe either way; still wrong.
- **`:c::releasable?` was `(not (contains? (text pg a) "poke"))`, and that one was unsound.**
  A statement that *calls* a function which pokes contains no `poke` itself, so it was released
  — and anything it allocated and handed over was freed underneath the pointer.
  `(user/stash (wat.string/concat "a" "b"))` where `stash` pokes: the concat is allocated inside
  the statement, the pointer is stored somewhere durable, and the release rewinds `r15`. **No
  program in this repository does it. The rule permitted it.**
- **The fix uses the call graph the compiler already has.** `:c::Prog/fns` holds every function
  and its body, so the set of functions that transitively reach a `poke` is computed once as a
  fixpoint over that graph, before any code is emitted; a statement is releasable when it neither
  pokes nor calls anything that does. The release still fires where it should — `freed.wat`
  allocates 650 MB with a **6.7 MB** peak.
- **The pattern is the finding.** Three times I reached for `contains?` because it was one line,
  in a compiler that had already parsed the structure and computed the types. Twice it was merely
  imprecise; once it was wrong. **A text search standing in for a structure question is a smell
  even when it passes the tests** — and the tests did pass, all of them, in every one of these
  cases.
- **Class:** CLEAN.
- **Repro:** `tools/bootstrap.sh`; `tools/mem.sh`.

### C-139: auditing for the rest of them — five more approximations, two of them the `base + 11` shape

- **Where:** `elf/compile.wat`. Prompted by the builder after C-138: *"let's audit for more of
  those."*
- **Two were hardcoded lengths, the same shape as the `base + 11` that broke every tail call in
  C-135.** `at-wrhex = at-die + die_len + 30`, `at-rdhex = at-wrhex + 163`,
  `at-rdfile = at-rdhex + 220` — the lengths of `hexval`, `hexchar`, `prim_write_hex` and
  `prim_read_hex`, read out of `nm` and typed in by hand, because all five routines shared one
  hex blob. Split into five defns, so every offset comes from `hexlen` of what precedes it as
  every other routine's already did. And `:c::stub-len` was `117`; it is now
  `(:c::hexlen (:c::stub 0 0))` — the stub measures itself, which it can, because every form in
  it is fixed-width.
- **One was a substring standing in for a type.** `:c::ty-of-node` asked whether the annotation
  *contained* `"String"`, which makes a user type called `StringBuilder` a string and one called
  `nilable` a nil — and the fallthrough was `"i64"`, so an unrecognised type quietly became a
  machine word. That is the F-120 silent-divergence shape: `println` would render a pointer as an
  integer. Now exact names, and **an unknown type is a refusal**.
- **Making that refusal real found two more things, which is the argument for making it real.**
  - **A one-argument `concat` was rejected.** `(wat.string/concat "solo")` is the identity and
    wat accepts it; the compiler demanded two operands. It surfaced because a runtime routine
    short enough to fit one line of hex generates exactly that.
  - **Collection was order-dependent for types.** `:c::kidsof` returns `:c::Kids` twenty lines
    *above* the typealias that defines it — legal in wat, which has no such rule, but collection
    is a single forward pass. Rather than move the line, record field types and function return
    types are now left blank during collection and filled once every record and alias has been
    seen. That removes a trap for anyone adding a function above its type alias.
- **Eight in total across C-138 and C-139, from one question**, and the through-line matters more
  than any of them: **every one passed every test.** The differential suite, the fixpoint,
  `tools/mem.sh`, `tools/vs-c.sh` — green before and after. These are not bugs testing finds,
  because the tests exercise what the code *does*, not what it *assumed*. The two dangerous ones
  would have surfaced as memory corruption and as a wrong jump target, in programs nobody has
  written yet.
- **Two left, named rather than quietly fixed.** The `999999` sentinel standing in for "name not
  found" is a magic number where an `Option` belongs — safe today only because frame
  displacements are small. And the `"vec:"`/`"rec:"` string-tagged type encoding wants a record;
  it is internal and consistent, so changing it would be churn without a reason.
- **Class:** CLEAN.
- **Repro:** `tools/bootstrap.sh`; `tools/loop.sh`.


### C-140: the in-place path was gated on the top of the heap -- and the gigabyte was never where I looked

- **Where:** `elf/runtime.s` (`str_cat_own`, `str_cat`, `str_subs`, `i64_to_str`, `prim_read_hex`,
  `io_read_file`, `vec_conj_own`, `vec_conj`), `tools/rt-embed.sh`, `tools/bootstrap.sh`,
  `elf/bench/catx.wat`, `elf/bench/pass20000.wat`. Prompted by the builder: *"let's fix the
  memory -- a gig for 2200 lines is embarrassing."*
  **`tools/bootstrap.sh` green, fixpoint at 100,934 bytes; `tools/loop.sh` green;
  `tools/mem.sh` green; `tools/vs-c.sh` green.**
- **The gate.** C-128's in-place `concat` needs two proofs -- a share count of 1 and a last use --
  and then a third condition nobody wrote down as a limitation: `cmpq %r15, %r9`, *is this string
  still the top of the heap?* A bump allocator can only extend the last object it handed out, so
  the fast path silently required that **nothing else had allocated since the last append**.
  `elf/bench/cat32000.wat` satisfies that by accident. `:c::emit` does not: every append to
  `:c::Out/code` has a whole form's hex strings, records and vectors allocated after it.
- **`elf/bench/catx.wat` is the difference in one line of source** -- the same 32,000 appends with
  a second accumulator growing beside them:

  | | peak | time |
  | --- | --- | --- |
  | `cat32000` — one accumulator | 2,180 KiB | 10 ms |
  | `catx` — two | **1,855,368 KiB, heap exhausted** | 1424 ms |

  Same work, 850x the memory. That is why the capacity experiment before this one bought
  nothing: the capacity was still behind the gate.
- **The fix costs no header field.** A String's block is now always the next power of two at or
  above `16 + len`, so its spare room is *derivable from its length* -- `2 << bsr(n-1)` -- and an
  append in place is legal whenever the new length still fits, **wherever the string sits**. The
  derivation stays consistent under growth because `16 + len` is always more than half the block,
  so the block it names never changes while the string is growing into it. Every String allocator
  had to agree, or a later append would run off the end of a block someone else sized.
- **Doing the same to vectors measured WORSE, by 349 MB.** `vec_new` and `slot_set` allocate
  blocks of a known final size -- every record, and every `assoc` on one -- and rounding those up
  wastes as much as half of each of the millions the compiler builds, for slack a record never
  uses. So vectors are **adaptive**: still at the top of the heap, extend by one bump and waste
  nothing; *displaced*, get promoted into a power-of-two block and marked `0x100000001` in the
  count word, which the increment-only share rule cannot collide with. That beats both fixed
  rules -- `grow2000000` is 15,724 KiB against 32,156 before and 33,672 for power-of-two
  everywhere.
- **Where that leaves the compiler: 1,247,244 KiB -> 1,023,672 KiB.** An 18% cut, and the
  quadratic cliff is gone from both accumulator shapes -- but still a gigabyte, so the
  measurement continued instead of the guessing.
- **The phase bisection, which says the gigabyte is not in the emitter at all.** Five builds of
  the compiler, each stopping after one phase, each compiling its own source:

  | stops after | peak |
  | --- | --- |
  | `rd/read` — **reading the source** | **732,320 KiB** |
  | collection | 930,304 KiB |
  | pass one | 966,000 KiB |
  | placement | 973,060 KiB |
  | pass two | 1,010,776 KiB |

  **Reading `elf/compile.wat` costs 745 MB before a byte of code is emitted.** Everything this
  session assumed -- `:c::emit`, the capacity work, the growth rules -- was about the emitter,
  which turns out to be under a third of it. And it is quadratic in the input: the same read is
  6,380 KiB for `elf/lib/reader.wat` at 192 lines and 744,952 KiB for `elf/compile.wat` at 2,637.
- **`elf/bench/pass20000.wat` is the mechanism in six lines** -- `grow20000.wat` with the
  accumulator handed to a user function on its way to `conj`, which is exactly what `rd/add`
  does with the reader's arena:

  | | peak |
  | --- | --- |
  | `grow20000` — `conj` at the call site | 964 KiB |
  | `pass20000` — through a user function | **1,564,716 KiB** |

  1,622x, for the same answer. `:c::push-args` increments the share count of **every
  pointer-typed symbol passed to a user function**, because the callee's frame is a second
  reference and the caller may read it again after the call returns. The count is increment-only
  by design (C-126) -- it never comes back down -- so from the first call onward `conj` sees a
  count above 1, gives up, and copies the whole vector. n copies of an n-element vector.
- **What the fix needs, named rather than attempted.** Storing or passing a value that is *dead
  afterwards* is a MOVE, not a share, and needs no increment -- which is Rust's rule, and the
  compiler already computes a last-use proof for `conj`. Two traps make it more than a one-line
  change, both of them found by reading the reader rather than by argument:
  - **A name can alias without being read.** `a (:rd::St/arena st)` binds a field, so `st` still
    points at the same vector; `a` being read once is not enough, `st` must also be dead.
  - **A return value can alias an argument.** `(let [b (f a)] ...)` where `f` answers its own
    argument leaves two names on one object, and neither store increments anything.
  Getting this wrong is silent memory corruption in a compiler that compiles itself, so it wants
  its own session and a written rule, not a patch at the end of this one.
- **Two things the session cost that the tools now prevent.** `tools/rt-embed.sh` assembles
  `elf/runtime.s` and writes the bytes into `compile.wat`'s `:c::rt-*` constants; that was a
  by-hand step, and its first run rewrote nothing, which is the check that the embedded hex had
  been right all along. And `tools/bootstrap.sh` now requires the seed and stage 1 to have
  actually printed `"compile: ok"` -- **a seed left behind by an experiment ran, exited 0, wrote
  no binaries, and every comparison below it passed because nothing had moved.** That is the
  same shape as the stale binary measured earlier in the session: a pipeline that carries on.
- **Class:** FIX.
- **Repro:** `tools/bootstrap.sh --fast`; `tools/mem.sh`; `./elf/out/catx.elf`;
  `./elf/out/pass20000.elf`; `elf/bench/out_maxrss ./elf/out/stage1.elf`.


### C-141: a program carries only the runtime it can reach -- 2,377 bytes to 452, and C's 968 beaten twice over

- **Where:** `elf/runtime.s` (reordered), `elf/compile.wat` (`:c::runtime`, the `:c::at-*` chain,
  `:c::rt-level`), `tools/rt-embed.sh`. Prompted by the builder: *"we can chase getting better
  than c on the benchmarks we rigged up?"*
  **`tools/bootstrap.sh` green, fixpoint at 109,456 bytes; `tools/loop.sh` green;
  `tools/mem.sh` green; `tools/vs-c.sh` green.**
- **We had quietly lost the size benchmark.** `tools/vs-c.sh` read 2,377 bytes against C's 968,
  where earlier in the project it had been 695. Nothing regressed in the code generator: the
  runtime had grown to **23 routines and 2,118 bytes**, and every binary embedded all of it.
  `elf/src/four.wat` prints one integer and can reach 193 bytes of it.
- **The fix needed no relocation machinery, only an order.** `elf/runtime.s` is now sorted so
  that **every internal call points backward** -- `buf_put` calls `flush`, `str_cat` calls `oom`,
  `vec_conj_own` calls `vec_conj`, and nothing calls anything defined after it. A dependency
  order exists because the graph is shallow: 23 cross-routine references, all of them into six
  routines. That makes **any prefix of the blob a complete runtime**, so the compiler emits a
  prefix and every routine's address is still the sum of the lengths before it -- the `:c::at-*`
  chain did not change shape at all. Three branches that `as` had relaxed to one byte are forced
  back to `{disp32}`, so no cross-routine reference depends on a distance.
- **The level is read off the arena, and a bare name is enough.** Every node of every file --
  `load-file!` reads into the same arena -- and if `wat.string/concat` appears *anywhere*,
  `str_cat` is carried, call or not. That over-approximates on purpose: being wrong high costs
  bytes, being wrong low is a call into the data tail. **A built-in the table does not name
  takes the whole runtime**, so adding a verb to the compiler cannot silently truncate it.

  | | before | after |
  | --- | --- | --- |
  | `four.elf` — prints `4` | 2,377 B | **452 B** (C, `-nostdlib`: 968) |
  | `fib32.elf` | 2,519 B | 595 B |
  | startup, 500 runs | 502 ms | 517 ms (C, libc removed: 524) |

- **Two holes, both found by the suite crashing rather than by reading.**
  - **`rd/classify` calls a keyword-spelled name kind `"keyword"`, not `"symbol"`.** The scan
    read symbols only, so it skipped every `:wat::core::assoc`, `:wat::io::read-file` and
    `:prim::read-hex` — which is *how this compiler writes about itself*. It gave itself level
    16, and called past the end of its own runtime. The clj-spelled `wat.core/conj` in the
    libraries is why the level was 16 and not 0: **the two spellings of one language read as two
    node kinds**, and a scan that knows about one of them looks like it works.
  - **`assert-eq` compares**, so on two Strings it is `str_eq` (C-130) and not just the
    diagnostic. `elf/src/diag.wat` asserts on a `concat` and died on the first run.
- **`tools/rt-embed.sh`** now also checks that `:c::runtime` concatenates the routines in the
  order `nm -n` reports, which is the invariant the whole scheme rests on.
- **Class:** FIX.
- **Repro:** `tools/vs-c.sh`; `tools/bootstrap.sh`; `stat -c%s elf/out/four.elf`.


### C-142: inlining -- fib(32) twice as fast as gcc -O0, and three bugs that only a new shape could reach

- **Where:** `elf/compile.wat` (`:c::inl-*`, `:c::scratch-safe?`, `:c::scratch-need`).
  **`tools/bootstrap.sh --fast` green, fixpoint at 120,327 bytes; `tools/loop.sh` green;
  `tools/mem.sh` green; twenty differential programs agree.**
- **The disassembly said what the gap was.** gcc -O2 beat this compiler four to one on fib(32),
  and it is not instruction quality -- our call sequence is twenty-two instructions and tight.
  **-O2 does not make most of the calls.** It inlines the recursion about six levels deep and
  leaves one `call` in an inner loop, spending 1,040 bytes of code on a three-line function.
- **So this inlines too, two levels, as a rewrite of the AST before either pass sees a node.** A
  call becomes a `let` that binds the parameters to the argument expressions and runs a copy of
  the body. Nothing downstream changes: `:c::compile-fn` compiles the rewritten `defn`, and the
  frame size falls out of `:c::slots-body` walking the same tree, **so the emitter and the frame
  cannot disagree about what is in there** -- which is the failure this change could most easily
  have had. A subtree that does not change is shared rather than copied, because appending to
  the arena is the thing C-140 measured at 745 MB.

  | | | |
  | --- | --- | --- |
  | ours | **19–23 ms** | was 29–34 |
  | gcc -O0 | 32–38 ms | |
  | gcc -O2 | 9–14 ms | |

  `fib32.elf` grows 595 → 1,152 bytes. Depth three buys a millisecond for 732 more bytes and
  depth four buys nothing at all, so the limit stays at two.
- **Three restrictions, each a soundness boundary rather than a simplification.**
  - **Never in tail position.** A self call there is a jump that reuses the frame (C-121) and a
    `let` is not; `elf/src/deep.wat` is a million of them.
  - **Only bodies that allocate nothing** — `:c::lvl-node` at 3 or below, the same level C-141
    uses to decide how much runtime to carry. That is not a coincidence: *"allocates nothing"*
    is the same question both times. A body that `conj`s is judged by `:c::linear?`, which is
    keyed by NAME and rebuilt per function, and inlining moves those names into a frame whose
    linear set belongs to somebody else.
  - **A size and a depth limit**, because every expansion is a copy.
- **Three bugs, none of them found by reading, and the first one was already there.**
  - **`:c::scratch-safe?` and `:c::scratch-need` keyed on `kind == "list"`**, so neither ever
    looked inside a `let`'s binding VECTOR. An initialiser holding a call was judged quiet, and
    the call then clobbered whichever of r8–r11 the enclosing expression was holding a value in.
    **That hole has been open since C-137** — nothing in this repository reached the shape until
    inlining put a `let` in operand position, and then the compiled compiler started disagreeing
    with itself about how many children a form had. It is the C-138/C-139 lesson again: the
    tests exercise what the code does, not what it assumed.
  - **`(user/gcd b (wat.core/rem a b))`** — binding the parameters in order gives `a` its new
    value before the second argument is compiled, and `let` is `let*`. The oldest bug in
    inlining, and it took a real program to produce it. Arguments now bind to temporaries first,
    named with a **space**, which the reader can never put in a symbol; one parameter cannot be
    captured by anything, so `fib` pays nothing for the fix.
  - **A `cond` clause body is in tail position**, and a clause's head is a *test expression*
    rather than a form name — so the general rule called it non-tail and inlined the tail call
    out of `elf/src/logic.wat`'s `gcd`. It printed 462 instead of 21.
- **Where that leaves the five benchmarks against C:** size **452 B against 968**, startup level,
  output **5 ms against 11**, tail calls level, and compute now **ahead of `gcc -O0` and about
  twice behind `-O2`**. What is left in the gap is memory traffic: every inlined binding still
  goes to a frame slot and comes back, where gcc keeps it in a register. `:c::Bind` already has
  a `reg` field and C-136 already saves rbx/r12/r13 — **giving `let` bindings registers is the
  named next step.**
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh`; `tools/bootstrap.sh`; `elf/bench/fib32.wat`.


### C-143: moves work, and the increment-only count cannot carry them -- 660x on the shape, refused by the compiler

- **Where:** `elf/src/moved.wat` (kept), `elf/compile.wat` (`:c::share`, written and reverted).
  Prompted by the builder choosing the memory over the register work: *"do we work on memory or
  let next?"*
- **The claim under test, from C-140:** storing a value that is dead afterwards is a MOVE, not a
  share, so `:c::push-args` need not increment. That is the 745 MB the reader spends, and it is
  Rust's rule.
- **`elf/src/moved.wat` was written before a line of analysis existed**, which is the C-127
  pattern: a program that fails loudly. `user/thread` is the reader's shape -- a vector carried
  in a record, read out, handed to a helper that conj's it, never looked at again.
  `user/leak` reads the container after the call; `user/alias` binds to a function that answers
  its own argument. Both must keep printing 304, never 404.
- **It worked, on the shape.** With the analysis in place:

  | | peak |
  | --- | --- |
  | `moved.wat` before | 1,563,948 KiB |
  | `moved.wat` after | **2,364 KiB** |

  **660x**, with `leak` and `alias` still answering 304 and 3, and all twenty differential
  programs in agreement. Two pieces were needed that are worth keeping in mind: the "is this the
  last use" test has to be an **evaluation-order walk**, not a comparison of arena indices,
  because C-142's inliner appends synthesised nodes at the end and a rewritten body has no usable
  index order left; and the container's uniqueness is a question only the runtime can answer, so
  it compiles to a `cmp qword [rcx-8], 1` -- **on a register**, because C-136 puts the parameters
  of exactly the looping functions this rule is for into rbx, r12 and r13, and the first version
  bailed out on that path and measured no change at all.
- **The compiler refused it.** Every test passed except the one that matters: compiled by a
  compiler that applies the rule, the compiler stopped reproducing itself. Four distinct holes
  came out of four bisections, each a real defect in the rule and none of them the last one:
  - **`conj` and `concat` are not fresh.** On the in-place path (C-127, C-128) they answer the
    *same pointer* they were given, so a name bound to one aliases its first operand. This
    compiler threads `(:c::Out/code o)` through `concat` on every instruction it emits.
  - **An expression argument aliases too.** `(f (:R/v b))` hands the callee a second reference
    to something `b` still points at, and nothing ever counted it. Symbols were never the whole
    story; they were the only case anyone had written down.
  - **Provenance chains have to bottom out.** `(:rd::St/arena (:c::Prog/src pg))` is two links,
    and a count of 1 on the middle one says nothing -- it was never incremented when it was read
    out of the outer one either.
  - **An already-pushed sibling argument holds a reference no source walk can see.** In
    `(f x (g x))` the pointer for `x` is on the machine stack before `g` runs, so "no occurrence
    after this point" is measured in the wrong place.
- **And the conservative direction is not free either.** Adding the increments that correctness
  requires -- the expression case -- and then turning the moves *off* made the compiler exhaust a
  1.9 GB heap where it used to finish in 1.02 GB.
- **The conclusion, and it is not "try harder at the analysis".** Every one of those four is the
  same fact: **a reference created without an increment is a hole in a whole-program invariant.**
  Reading a field creates a reference and does not increment. That is sound today only because
  every *onward* store does increment -- and a move is precisely the decision not to. The fix is
  therefore not a smarter `:c::share`; it is **decrementing**, so that a reference which dies
  gives its count back, which is what `Arc` does and what C-126 deliberately did not build:
  *"it is never decremented, so it answers exactly one question."* The reader's 745 MB is the
  bill for that choice, and this is the first measurement of how large it is.
- **Class:** IMPROVE.
- **Repro:** `./elf/out/moved.elf`; `elf/bench/out_maxrss ./elf/out/moved.elf`.


### C-144: the gigabyte was a data structure, not an ownership model -- 1,023,672 KiB to 142,008

- **Where:** `elf/lib/reader.wat` (`:rd::Block`, `rd/push`, `rd/at`, `rd/count`, `rd/spine`),
  `elf/compile.wat` (`:c::mknode`, `:c::rt-level`). Follows C-143 directly.
  **`tools/bootstrap.sh` green from the interpreter -- 42 binaries byte-identical, fixpoint at
  121,103 bytes; `tools/loop.sh`, `tools/mem.sh`, `tools/vs-c.sh` green; `elf/conform.wat`
  agrees with wat's own reader on 16,349 nodes of `elf/compile.wat`.**
- **C-143 closed off the compiler's side of it.** The arena's share count climbs because
  `:c::push-args` counts every pass as a share and the count is increment-only; turning that
  into a move needs an invariant that four separate kinds of uncounted reference break, and the
  repair for *those* is decrements -- which need to know when a heap object dies, which a bump
  allocator that frees by rewinding `r15` does not. That is a memory model, not a patch.
- **So this stops asking the compiler.** Appending to a flat Vector copies all of it when the
  compiler cannot prove the vector is unique: n copies of an n-element arena. (**Not F-104** --
  an earlier draft of this entry blamed the missing positional update, and that is wrong. The
  arena grows by `conj`, which needs no positional update; C-143 made the same program 660x
  cheaper without touching `assoc` at all. The cause is the ownership model, measured below.) A
  **block list**
  makes an append copy one block plus the spine -- `b + n/b` words instead of `n` -- and b is
  128, which is about the square root of the 16,349 nodes `elf/compile.wat` reads to. Nodes are
  still addressed by a single index; `rd/at` divides it.

  | | before | after |
  | --- | --- | --- |
  | reading `elf/compile.wat` | 744,952 KiB | **45,076 KiB** |
  | the compiler compiling itself | 1,023,672 KiB | **142,008 KiB** |
  | the same, wall clock | 310–480 ms | 288–293 ms |

  **7.2x less memory and no slower** -- a gigabyte for 2,600 lines becomes 138 MB, which is
  finally the same order as a C compiler rather than twenty times worse.
- **And the cliff is ours, not wat's.** The same three programs, interpreted and compiled:

  | | interpreted | compiled |
  | --- | --- | --- |
  | `grow20000` — `conj` at the call site | 75,032 KiB | **988 KiB** |
  | `pass20000` — the same, through a function | 73,444 KiB | **1,563,944 KiB** |
  | `moved.wat` — the same, in a record | 75,760 KiB | **1,564,432 KiB** |

  **The interpreter does not notice the shape change at all** -- it is flat at ~75 MB across all
  three. **An earlier version of this entry said that was because its vector shares structure.
  That was invented, not read, and it is false.** `vector_conj_inner` in wat-rs is
  `let mut out = (**xs).clone(); out.push(item)` -- it clones the whole `Vec` on every `conj`,
  unconditionally. wat's `Vector` is copy-on-append exactly as ours is.

  The interpreter is flat in memory because **`Arc` frees each dead copy**, and it pays the copy
  in TIME instead -- measured, `pass20000` at four times the size is **18.2x** slower (6,027 ms
  -> 109,402 ms), which is the quadratic showing itself. Our bump allocator frees nothing except
  by rewinding `r15` at a statement boundary, so we pay the same quadratic in memory.

  So the difference is **reclamation, not representation** -- which is what C-143 concluded
  before this entry talked itself out of it. And it means the chunked arena is right for a
  different reason than the one first given here: it does not dodge an ownership proof, it
  attacks the O(n^2) **work**, which is why it fixed the memory *and* left the time alone.
  `(:wat::core::PersistentVector)` is a separate wat type and is presumably the structure-sharing
  one; this compiler does not implement it.
- **What it is, said plainly: a workaround, and the right one for now.** `elf/src/moved.wat` still costs
  1.5 GB, because C-143's limitation is still exactly true for any user program that threads a
  collection through a call. We routed around it in the one place we own; we did not fix it. The
  two findings belong together -- C-143 is why this is a data structure change and not a
  compiler change.
- **Two things fell out of it.** The comment over `rd/add` had claimed since C-130 that passing
  `n` separately let the compiler extend the arena in place; it never did, and nobody had
  measured it. And `tools/bootstrap.sh`'s seed check (C-141) earned itself: a read-only probe
  binary left in `elf/out/compiler.elf` was caught with *"the seed ran but did not compile"*
  rather than silently reporting a green fixpoint over stale binaries.
- **Class:** FIX.
- **Repro:** `tools/bootstrap.sh`; `elf/bench/out_maxrss ./elf/out/compiler.elf`; `elf/conform.wat`.


### F-124: `wat.core/Vector` clones on every `conj`, and is quadratic in time -- `PersistentVector` is the one that does not

- **Where:** `wat-rs/src/collection/eval.rs:280` (`vector_conj_inner`), against
  `wat-rs/src/value/pvec.rs`. Measured with `elf/bench/pass20000.wat`.
- **The source.** `vector_conj_inner` is, in full:

  ```rust
  Value::Vec(xs) => {
      let mut out = (**xs).clone();
      out.push(item.clone());
      Ok(Value::Vec(Arc::new(out)))
  }
  ```

  A full clone of the backing `Vec` on every append -- no `Arc::make_mut`, no sharing, no
  uniqueness check. So `conj` on a `(Vector :- [T])` is O(n), and building one by repeated
  `conj` is **O(n^2)**.
- **Measured, and it is the curve.** `elf/bench/pass20000.wat` grows a vector to 20,000 by
  `conj` through a function call. At **4x** the elements:

  | | |
  | --- | --- |
  | 20,000 | 6,027 ms |
  | 80,000 | **109,402 ms** |

  **18.2x for 4x the input** -- quadratic, with the constant showing. Peak memory stays flat
  (~75 MB) the whole time, because `Arc` frees each dead copy as the next one is made; the cost
  is paid entirely in time, which is why nothing had noticed.
- **`PersistentVector` is the type that does not do this**, and its design says why:
  `PVec` is `Array(Arc<Vec<Value>>) | Tree(rpds::VectorSync<Value>)`, promoting one-way past
  eight elements on persistent append, with the rule that **representation must be
  unobservable**. Its own doc comment states the principle: *"One representation chosen globally
  is a claim about how vectors are built; promoting per instance makes no claim."* That is the
  right answer -- it is just not the answer `wat.core/Vector` gets.
- **Why it matters here.** Nothing in the books or the suites builds a vector large enough for
  the curve to bite, which is why 97 chapters passed over it. `elf/` found it because a compiler
  builds one big vector -- an arena of 16,349 nodes -- and it is the difference between the
  compiled and interpreted cost models that made it visible (C-144).
- **Class:** FIX (in wat-rs). The builder's stated direction is that wat's aggregates move to
  persistent stores -- rpds already supplies the map, vector, set and list -- so this is a case
  of `Vector` not yet having made that move rather than a design anyone chose.
- **Repro:** `time wat elf/bench/pass20000.wat`, then the same file with 20000 -> 80000.


### C-145: the promoting vector -- `conj` from O(n) to O(log n), and the cliff measured at 1,580x is gone

- **Where:** `elf/runtime.s` (`varr_new`, `node_new`, `node_copy`, `tree_get`, `tree_push`,
  `tree_from_arr`, `vec_conj`), `elf/compile.wat` (`nth`, `:c::at-varr`, `:c::at-tget`, the
  level table), `elf/src/pvec.wat`, `elf/bench/pass80000.wat`, `elf/bench/deepvec.wat`.
  Fixes F-124 on our side. **`tools/bootstrap.sh` green from the interpreter -- 46 binaries
  byte-identical, fixpoint at 129,077 bytes; `tools/loop.sh`, `tools/mem.sh`, `tools/vs-c.sh`
  green.**
- **The shape, taken from wat's own `PVec` rather than invented.** Reading `wat-rs/src/value/
  pvec.rs` produced a better design than three turns of reasoning had: an array while the vector
  is small or bulk-built, a 32-way tree once persistent `conj` pushes it past eight, promoting
  one way and never back, under one rule -- *representation must be unobservable*. Its own
  comment carries the argument: **"One representation chosen globally is a claim about how
  vectors are built; promoting per instance makes no claim."** A blocked vector, which this
  entry was going to be, fails that test: it is a third representation, chosen globally, by me.

  ```
  array:  [arm=0][rc][count][slot]...        p -> count
  tree:   [arm=1][rc][count][shift][root]    p -> count
  ```

  **`count` is at offset 0 in both**, so `length` stays one instruction for either arm, for a
  record and for a String. Only `nth` asks, and only for a Vector -- a record never conj's, so
  it is an array for ever and the compiler emits its bare indexed load with no test. The arm
  could not live in the `rc` word: that is a share count `incq` walks upward, and it already
  carries C-140's `0x100000001`, while an arm must survive sharing.
- **`vec_conj_own` did not change, because it already WAS `push_back_mut`.** C-127 and C-140's
  work is kept entire. Exactly one routine was wrong -- `vec_conj`, the shared path -- and it
  promotes now instead of cloning.

  | | before | after |
  | --- | --- | --- |
  | `pass20000` — a shared accumulator | 1,563,944 KiB | **18,168 KiB**, 17 ms |
  | `pass80000` — four times the size | heap exhausted | **80,976 KiB**, 76 ms |
  | **the curve at 4x n** | — | **4.5x** |
  | `deepvec` — 40,000 through a call | heap exhausted | **ok**, 36,672 KiB |
  | `moved.wat` — the F-124 cliff | 1,564,512 KiB | **18,652 KiB** |
  | the compiler on itself | 142,008 KiB / 288 ms | **136,032 KiB / 242 ms** |

  **4.5x for four times the input is the whole finding.** O(n) would be 16x; wat's interpreter
  measures 18.2x on the same program. It does `pass80000` in 109,402 ms; this does it in 76.
- **The tests were written first, and one of them was wrong.** `elf/src/pvec.wat` builds the
  same sequence in bulk and by `conj` and compares it observation by observation -- length,
  `nth` at every index, sum, `conj` onto each, a trip through a function, `i64` and `String`
  elements -- at 0, 1, 7/8/9, 31/32/33, 64, 1000, 1025. `elf/bench/deepvec.wat` first **passed**
  at 960 KiB, which was the test being wrong rather than the claim right: built by `conj` at the
  call site, the accumulator takes C-127's in-place path and never promotes anything. It goes
  through a function now.
- **Three bugs, and the third is the one to keep.**
  - `r10` held the slot index across `node_new`, which uses `r10` for the object it is building.
    The compiler segfaulted compiling itself -- its own arena is deep enough to run the walk.
  - `[rax+8]` written where `[rax-16]` was meant, and the array load on the wrong side of the
    branch. Caught by decoding the bytes by hand before building, not by a test.
  - **C-137's scratch pool collided with this change.** It parks expression temporaries in
    r8-r11 whenever a subtree *"emits no call"*, and `nth` is on that whitelist -- true until a
    Vector's `nth` could reach `tree_get`, which used r8 and r9. The pool's real requirement is
    not "no call" but **"disturbs no scratch register"**, so `tree_get` now disturbs only `rax`
    and `rcx`, stated as a contract in the routine's own comment. It surfaced only in a function
    with TWO vector parameters and a self tail call, because C-136 puts those in registers --
    which is exactly why the wall test compares two vectors rather than checking one. **Two
    optimisations, each sound alone, whose invariants met for the first time here.**
- **C-144's hand-chunked arena comes out** -- 46 lines of blocks and spine, deleted, because the
  runtime does it properly now and a flat arena promotes on its own. A workaround's obituary is
  the feature landing.
- **What is still refused:** `(assoc v i x)` on a Vector. The machine code for it is a path copy
  we now have, and wat has already resolved to BUILD index-assoc (F-104's update), but exposing
  it here while the interpreter refuses it would make the compiled language a superset -- the
  F-119 drift this repository exists to catch. `elf/src/assocn.wat` is the portable O(n) route
  in the meantime, working both ways today.
- **Class:** FIX.
- **Repro:** `tools/bootstrap.sh`; `./elf/out/pvec.elf`; `./elf/out/pass80000.elf`;
  `./elf/out/deepvec.elf`.


### C-146: `let` bindings take the registers a parameter did not -- 10% on fib, and 33 bytes smaller

- **Where:** `elf/compile.wat` (`:c::bind-each`, `:c::compile-fn`, `:c::reg-mov-from`,
  `:c::Prog/nlr`, `:c::Prog/regbase`). **`tools/bootstrap.sh` green from the interpreter,
  fixpoint at 129,319 bytes; `tools/loop.sh`, `tools/mem.sh`, `tools/vs-c.sh` green.**
- **The opportunity came from C-142, not from `let`.** `fib` has no `let` in it at all -- but
  inlining turns every inlined call into one, and each of those bindings was round-tripping
  through a frame slot, a store and then a load per read, where gcc keeps the value in a
  register. C-136 already saves rbx, r12 and r13 for the parameters of looping functions; this
  gives the ones a parameter did not take to `let`.
- **Measured A/B, one session, the same build either way** -- which is C-136's own lesson, where
  *"registers are faster"* would have shipped a regression:

  | | ON | OFF | |
  | --- | --- | --- | --- |
  | `fib(32)` | **20,171 µs** | 22,374 µs | **−9.8%** |
  | `poly` | 303,819 µs | 307,028 µs | −1.0% |
  | `mix` | 355,845 µs | 357,104 µs | −0.4% |
  | the compiler on itself | **275 ms** | 294 ms | **−6.5%** |
  | `fib32.elf` | **1,119 B** | 1,152 B | 33 bytes **smaller** |

  Smaller, because a register store is three bytes where a frame store is four, and a register
  read is three where a load is four. The loop benchmarks barely move because C-133's direct
  operand and C-137's scratch pool had already taken their bindings; the win is concentrated
  exactly where the inlining put the bindings.
- **The disconfirming probe was mechanical, and it mattered**: the trie (C-145) had just added
  three runtime routines that use rbx, r12 and r13. Disassembling the whole runtime and checking
  that every routine writing a callee-saved register pushes it first came back clean -- the
  assumption C-136 already rests on, re-verified after the thing that could have broken it.
- **Excluded for a function that clones**, for C-136's reason exactly: the child inherits the
  frame, so a value moved out of it is a value the child cannot see. `threads4` still sums to
  1000 and `fork` still prints `1 2 7 1 1 4`.
- **The counts ride in `:c::Prog`**, set per function beside `linear`, so not one expression form
  needed a new argument. All three readers of a binding already consulted `lookup-reg` before
  `lookup` -- verified by audit, and there are exactly three.
- **What the disassembly says is left**, and neither is this strike:
  - **A store-then-reload pair at every binding**: `mov %rax,%rbx` followed immediately by
    `mov %rbx,%rax`, because `bind-each` writes the register and the body's first act is to read
    it. A peephole would take it, but only with knowledge of branch targets the emitter does not
    have at emit time -- a jump can land on the read.
  - **C-136's ruling has been undermined by this change.** It gives parameters registers only in
    looping functions, because the prologue cost is per call and the benefit per iteration. But
    a function with `let` registers is already paying that prologue -- so the marginal cost of
    also giving its parameters registers is now nearly zero, and `fib` still loads `n` from the
    frame three times.
- **Against `-O2`, honestly:** this closes about a tenth of a two-fold gap. The rest is what the
  disassembly showed in C-142 -- `-O2` inlines about six levels deep and partially turns the
  recursion into iteration, spending 1,040 bytes on a three-line function. That is a different
  and larger piece of work, not more of this one.
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh`; `elf/bench/fib32.wat`; `tools/bootstrap.sh`.


### C-147: inlining depth belongs to the callee, and the reload that never had to happen -- fib 26% faster

- **Where:** `elf/compile.wat` (`:c::inl-depth-for`, `:c::Out/rax`, `:c::emit`, `:c::bind-each`,
  the symbol read). **`tools/bootstrap.sh` green from the interpreter, fixpoint at 129,797
  bytes; `tools/loop.sh`, `tools/mem.sh`, `tools/vs-c.sh` green; `threads4` 1000, `deep`
  1,000,000.** Prompted by the builder: *"if we need to do more inlining, then we do more
  inlining."*
- **The first thing measured was that C-142's own answer had gone stale.** When inlining went
  in, depth 3 bought a millisecond for 732 bytes and depth 4 bought nothing, so the limit was
  set at 2 and the entry said so. Re-run after C-146 put `let` bindings in registers:

  | depth | fib(32) | `fib32.elf` |
  | --- | --- | --- |
  | 2 | 19,978 µs | 1,119 B |
  | 3 | 17,569 µs | 1,799 B |
  | **4** | **14,880 µs** | 3,263 B |
  | 5 | 17,169 µs | 6,191 B |

  **The registers unlocked the depth.** Before them the extra bindings spilled to frame slots
  and paid back exactly what the inlining saved; with three of them held, depth 4 is a 25% win,
  and depth 5 loses it again to instruction cache at 6 KB. Two changes each close to worthless
  alone -- which is the argument for re-measuring a closed decision when its neighbours move.
- **But one depth for everything cost the compiler 21%** (275 → 333 ms), because the only things
  it can inline are `:c::at-*` accessor chains, and expanding those four deep is bloat with no
  call removed that matters. **So depth is a property of the callee.** A self-recursive callee
  earns 4: its inlined copy contains another call to itself, so each level removes a
  *multiplicative* number of calls. A leaf earns 1: inlining it removes exactly one call per
  site, and more depth only expands *its* callees. Per-callee, `fib` keeps the whole 25% and the
  compiler pays **nothing** (276 ms against depth 2's 275).
- **The redundant reload.** Every binding emitted `mov %rax,%rbx` and then immediately
  `mov %rbx,%rax` -- `:c::bind-each` writes the register and the body's first act is to read it
  back. `:c::Out` now carries the name `rax` already holds; **`:c::emit` clears it
  unconditionally and only `bind-each` sets it**, so the window is one instruction wide and any
  emission whatever closes it. That is also what makes it sound against a jump landing on the
  read: a branch target is a position some emission recorded, and any emission has already
  cleared the field. Worth another 5% on fib and **11% on the compiler**, with both binaries
  smaller.

  | | before this entry | after |
  | --- | --- | --- |
  | `fib(32)` | 20,171 µs | **14,828 µs** |
  | the compiler on itself | 275 ms | **245 ms** |
  | against `gcc -O0` | 1.5x ahead | **2.0x ahead** (29,475 µs) |
  | against `gcc -O2` | ~2.1x behind | **~1.7x behind** (8,514 µs) |

- **C-136 re-tested, and left standing -- a negative result.** It withholds registers from the
  parameters of non-looping functions because the prologue cost is per call and the benefit per
  iteration. C-146 appeared to have changed that premise: a function with `let` registers is
  already paying the pushes, and `fib` was reloading `n` from the frame three times a level with
  all three registers pushed above it. Implemented, then A/B'd interleaved: **wash** -- 235, 242
  and 272 ms against 241, 244 and 266, with fib neutral. The first reading, 275 against 245, was
  noise measured across rounds rather than within one. Reverted: no churn for a number that
  cannot be shown. **The ruling was right, and for a reason its own entry did not give** -- the
  compiler's functions carry many pointer parameters, so registering three of them costs three
  prologue loads per call and takes registers the `let` bindings were using better.
- **On the honest size of the remaining gap:** `-O2`'s own time swings between 8,514 and 11,054
  µs across rounds on this machine, so the 26% is the solid number and the ratio is approximate.
  What is left is what C-142's disassembly showed: `-O2` inlines about six levels and turns part
  of the recursion into iteration.
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh`; `elf/bench/fib32.wat`; `tools/bootstrap.sh`.


### F-125 / C-148: the compiled language did not trap on i64 overflow -- a wrong answer, not a refusal

- **Where:** `elf/runtime.s` (`ovf`), `elf/compile.wat` (`:c::ovf-check`, `:c::fold`,
  `:c::lvl-pure`), `elf/bad/overflow.wat`, `tools/elf-run.sh`. **`tools/bootstrap.sh` green from
  the interpreter, fixpoint at 133,594 bytes; `loop`, `mem`, `vs-c`, `elf-run` green.**
- **Found by chasing an optimisation, not by looking for a bug.** `gcc -O2` beats this compiler
  on `fib` partly by *tail recursion modulo `+`* -- `acc += fib(n-1); n -= 2` -- which
  **reassociates** the additions. That is free in C, where signed overflow is undefined. wat
  traps. So the question *"may we reassociate?"* became *"what do we do on overflow at all?"*:

  | `(+ 9223372036854775807 1)` | |
  | --- | --- |
  | interpreted | dies — `IntegerOverflow: 9223372036854775807 :wat::i64::+ 1 does not fit in 64 bits` |
  | compiled | printed **-9223372036854775808**, exit **0** |

  A bare `add rax, rcx`, wrapping silently. **A wrong ANSWER, not a refusal** -- the shape F-120
  names as the worst kind -- and forty differential programs stayed green because not one of
  them overflowed. The suite had never asked.
- **The fix is six bytes a site.** `add`, `sub` and `imul` set the overflow flag, so every `+`,
  `-` and `*` now carries `jo` to a handler modelled on `oom`: flush what stdout had buffered --
  the interpreter would have printed it -- name the fault on stderr, exit 70. The branch is
  never taken and predicts as such.

  | | before | after |
  | --- | --- | --- |
  | `fib(32)` | 14,828 µs | 15,586 µs |
  | `four.elf` | 452 B | 611 B (C `-nostdlib`: 968) |
  | the compiler on itself | 245 ms / 129,016 B | 261 ms / 133,594 B |

  Five percent and a hundred and sixty bytes, for not lying.
- **`quot` and `rem` are NOT covered, and that is stated rather than deferred:** `idiv` faults on
  `MIN / -1` rather than setting a flag, so it is a different mechanism -- a signal, not a
  branch -- and it needs its own answer.
- **The fix nearly hid a second bug, and the symptom was a binary getting smaller.** Inserting
  `ovf` at runtime index 1 shifted every later index, and `:c::inl-ok?` carried a hardcoded
  *"pure means level ≤ 3"* -- a 3 that had silently meant `print_bool`. `(< n 2)` now scored 4,
  **`fib` stopped being inlinable**, and `fib32.elf` fell from 3,104 to 702 bytes while its time
  doubled to 43,313 µs. Nothing failed. C-139's lesson word for word: a number standing in for a
  question. It is `(:c::lvl-pure)` now, defined as *"everything at or below the last routine that
  does not touch the heap."*
- **And the optimisation that started this is inadmissible, which is the finding underneath the
  finding.** Reassociating `+` changes *whether a program traps*: for terms that can be negative,
  a prefix sum can overflow where the total does not. `gcc` may do it because C says overflow is
  undefined; wat says it stops. **So the specific trick `-O2` uses to beat us here is one this
  compiler cannot take** without the compiled language diverging from the interpreted one. That
  is a real, measured consequence of wat choosing trapping arithmetic -- a cost on one side of a
  ledger whose other side is that `(+ a b)` never silently answers nonsense.
- **Class:** FIX.
- **Repro:** `tools/elf-run.sh`; `./elf/out/overflow.elf`; `wat elf/bad/overflow.wat`.


### C-149: a compare and a branch write no register, so both arms already hold the value

- **Where:** `elf/compile.wat` (`:c::if-cmp`, `:c::patch`). Extends C-147's tracking.
  **`tools/bootstrap.sh --fast` green, `loop`, `mem`, `vs-c`, `elf-run` green; `threads4` 1000,
  `deep` 1,000,000, overflow still traps.**
- **Every inlined `if` reloaded a value that was sitting in the register.** C-147 gave `:c::Out`
  a field naming what `rax` already holds, with a window one instruction wide -- any emission
  closed it. The compare and the conditional jump between a binding and its use closed it,
  though neither writes a register:

  ```
  175: mov %rax,-0x20(%rbp)     the binding
  179: cmp $0x2,%rax            uses rax directly -- C-147 caught this one
  17d: jge 0x192
  183: mov -0x20(%rbp),%rax     then arm: reloads what rax holds
  192: mov -0x20(%rbp),%rax     else arm: reloads what rax holds
  ```

- **What makes it sound is the reasoning, not the observation.** A compare and a branch write
  nothing, so the fall-through and the jump arrive at their arms with the *same* contents -- and
  the else arm has exactly one predecessor, that branch. Both arms may therefore inherit. Only
  when the right operand compiled to a bare compare: the general path pushes and evaluates into
  `rax`, which destroys it, and the restore is conditional on exactly that.
- **`:c::patch` now clears the tracking**, because most of its uses are real joins -- two paths
  meeting with different contents -- and one conservative clear in one place covers every `if`
  and every `cond`. `:c::if-cmp` is the single caller that knows better, and says so where it
  re-establishes the arm's state. That is the shape worth copying: clear centrally, restore
  where the reasoning is written down.
- **`fib32.elf` 4,053 → 3,719 bytes**, one load fewer on the hot path of every node.
- **On the measurement, honestly.** The machine was under load -- average 1.5, a browser
  running -- and `fib` read 19–25 ms against the 15 ms of an hour before, so the timing is
  directional only: two of three interleaved rounds favour it, one ties. **The argument that
  carries this change is structural**: strictly fewer instructions, visible in the disassembly,
  executed once per node. A change whose only evidence was timing would not have been kept under
  those conditions.
- **And it struck an item off its own queue.** NEXT.md item 5, rematerialising instead of
  spilling, was named as *"one `add` instead of a store and three loads"*. Two of those three
  loads were these redundant reloads. A spill now costs one store and one load; rematerialising
  costs one load and one subtract **per read** -- a tie at best, a loss when read twice. Struck,
  with the arithmetic recorded rather than the line deleted.
- **Class:** IMPROVE.
- **Repro:** `objdump -b binary -m i386:x86-64 -D elf/out/fib32.elf`; `tools/bootstrap.sh`.


### F-126 / C-150: `idiv` faults rather than flagging, and two places needed a magnitude i64 has not got

- **Where:** `elf/runtime.s` (`divzero`, `i64_quot`, `i64_rem`), `elf/compile.wat`
  (`:c::arith-emit`, `:c::to-int`, `:c::neg-digits-val`), `elf/lib/asm.wat` (`:asm::le-neg`),
  `elf/src/extremes.wat`, `elf/bad/divzero.wat`, `tools/elf-run.sh`. Closes the part of F-125
  that C-148 left open. **`tools/bootstrap.sh` green from the interpreter, fixpoint at 136,134
  bytes; `loop`, `mem`, `vs-c`, `elf-run` green.**
- **A division did not diverge quietly — it crashed.** `(quot 1 0)` compiled to a bare `idiv`
  took **SIGFPE: core dumped, exit 136**, with nothing printed, where the interpreter answers
  `DivisionByZero: division by zero` and stops. C-148 could use `jo` because `add` *flags*
  overflow; `idiv` **faults**, so the divisor has to be tested before the instruction runs
  rather than after.
- **The two faults, and the two answers.** Zero divisor → `divzero`, which flushes what stdout
  had buffered and names the fault. `MIN / -1` → **`neg rax; jo ovf`**: `a / -1` *is* `-a`, and
  it overflows in exactly the same place, so the one case `idiv` cannot do is an instruction
  that already reports it. `rem` by `-1` is `xor rax, rax` — zero for every dividend, including
  the one `quot` must refuse. They are **routines, not inline guards**: a division is rare and
  seven instructions at every site is not.
- **Then trapping arithmetic found two more, both wrong since C-116 and both hidden by wrapping.**
  - **`:c::to-int` refused `-9223372036854775808`** — a literal wat accepts and prints. It parsed
    as `0 - digits-val("9223372036854775808")`, and that magnitude is 2^63. Before C-148 it
    wrapped **twice** and arrived at the right answer by luck; when arithmetic stopped wrapping,
    the luck became **a valid program the compiler refused**. Negative literals accumulate
    negatively now, reaching the bound without ever exceeding it.
  - **`:asm::le` encoded that same value wrongly**, for the same reason — it negated to get a
    magnitude to complement. **The compiler's own read-back check is what caught it**: it wrote
    the binary, read the file back, and the bytes disagreed. It steps with floor division now
    (wat's `rem` takes the sign of its dividend, so a negative byte borrows from the next step),
    and never holds a value the range cannot represent. Verified byte for byte against Python's
    two's complement for `-1`, `-7`, `-256`, MIN and a positive.
- **One fact underneath both: i64's range is ASYMMETRIC.** There is a `-9223372036854775808` and
  no `+9223372036854775808`, so **any code that reaches a negative by negating its magnitude is
  wrong at exactly one input** — and both places that did it were invisible for as long as
  arithmetic wrapped. That is the same shape as F-125 itself: the defect was always there, and
  what was missing was anything that would ask.
- **The tests, which is where this belongs.** `elf/src/extremes.wat` pins thirteen values both
  ways — both literals, arithmetic reaching the edge without crossing it, truncation toward zero
  on mixed signs, `quot MIN 2`, `rem MIN -1`, `quot MIN 1`. The two that genuinely stop cannot
  live in a differential that compares output, so `elf/bad/divzero.wat` joins
  `elf/bad/overflow.wat` and the harness checks that both sides stop and agree on why.
- **Class:** FIX.
- **Repro:** `tools/elf-run.sh`; `./elf/out/extremes.elf`; `./elf/out/divzero.elf`.


### F-127 / C-151: a borrowed pointer is not a temporary, and the count cannot tell the difference

- **Where:** `elf/compile.wat` (`:c::fresh-str?`, the `concat` first-operand rule),
  `elf/src/strown.wat` (new), `tools/elf-run.sh`. The item C-140 flagged twice and left open,
  now with a wrong answer behind it instead of a note. **`tools/bootstrap.sh` green from the
  interpreter — 52 binaries byte-identical, fixpoint at 136,662 bytes; `elf-run`, `mem`, `vs-c`,
  `loop` green.** **C-152 buys back 94% of the price this entry measures, without touching the
  ownership model at all.**
- **`elf/src/strown.wat` prints a string that grew after it was read.** A record whose String
  field is filled from an expression, read back, and concatenated:

  ```
              interpreter   compiled
  (grow x)    "abcdXY"      "abcdXY"
  (S/s x)     "abcd"        "abcdXY"      <-- the record's field changed
  length      4             6
  ```

  Three shapes do it -- a field read, a field read through two records, and a user function
  that answers a field. **The fourth in the file is right, and is in there because of WHY it is
  right**: `(let [a (S/s z)] (concat a "!!"))` borrows exactly as hard, and survives only because
  `:c::linear?` is keyed on PARAMETER names and a `let` name is never in that list. It is correct
  by an accident of scope, not by a proof -- so the day `linear?` learns about `let` bindings,
  that line starts printing `"mnop!!"` for `z` too. It is in the file to fail then.
- **The rule that did it.** `str_cat_own` extends the left operand in place; the compiler decides
  whether to call it. For a SYMBOL that needs C-127's two proofs. For anything else the rule was
  a sentence: *"a non-variable operand is a temporary and always qualifies"*. A field read is not
  a temporary. It is a **borrowed pointer into a container that is still alive**.
- **And the share count says 1, truthfully.** `:c::share` increments only symbols, so a fresh
  value stored into a container is stored by MOVE and keeps the count of 1 the allocator gave
  it -- which is exactly what makes the reader's `(conj rows n)` chain cheap (C-140). So the
  runtime guard asks *"has this ever been shared?"*, gets the right answer, and draws the wrong
  conclusion. **C-127's two proofs are sound for a value you HOLD and vacuous for a value you
  reached THROUGH something**: the count lives on the container's object, not on the one handed
  back.
- **The fix asks what is true instead of what it is spelled like.** An operand is fresh when
  whatever produced it ALLOCATED it, and exactly three verbs always do -- `concat`, `subs` and
  `i64/to-string` each write a new block and answer it on every path. A field read, an `nth`, a
  user call and an `if` can all hand back something older than themselves.
- **The price, measured, because it is not free.** Peak resident memory compiling the whole of
  `elf/`, interleaved on two retained binaries and taking the minimum of each,
  **145,092 -> 444,200 KiB (3.06x)**; wall clock the same way, **303 -> 346 ms (14%)**.
- **And then measured AGAIN, because the first account of where it went was wrong.** It read
  *"all of it is one call site"* -- `:c::emit`, whose left operand is `(:c::Out/code o)`. That
  was reasoning, not measurement, and four throwaway builds that hand `own?` back to one class of
  operand at a time say otherwise:

  | granted back | peak KiB | recovers |
  | --- | --- | --- |
  | nothing (the correct rule) | 444,200 | -- |
  | `(:c::Out/code o)` alone | 301,344 | 142,856 |
  | `(:c::Out/tail o)` alone | 363,720 | 80,480 |
  | every field read | 149,868 | 294,332 |
  | every NON-field-read (user calls) | 440,388 | 3,812 |

  So it is **three accumulators, not one** -- `:c::Out/code` (the instruction stream),
  `:c::Out/tail` (the data segment, which is nearly as hot because this compiler is mostly hex
  literals) and `:c::PassR/code` -- and the operands that LOOK like the majority in a source
  count, the fifty-odd `(concat (:c::mov-rax n) "...")` calls, are worth 0.9% between them.
  **Every kilobyte of it is the same shape: a String grown by `concat` inside a record field.**
- **And one alarm that the measurement put out.** `:c::patch` rebuilds the accumulated code with
  a `subs` either side of the hole -- F-104 again, on the hottest string in the compiler, for
  every forward branch, which is every `if` and every `cond` clause. It looks like the worst
  thing in the file. Compiled with `:c::patch` made a no-op it peaks at **431,820 KiB against
  444,200 -- 2.8%**, because a patch rewrites one FUNCTION's code and functions are small. The
  first attempt at that probe measured the wrong binary (the broken output of the patch-less
  compiler, not the patch-less compiler itself) and reported 1.86 GB; the number above is the
  corrected one. **An O(n) copy in an obvious place is worth measuring before it is worth
  fixing**, which is the same lesson C-140 learned from the other side.
- **Three ways to buy it back, and the same wall behind all three.**
  1. **Check the container's count too** -- extend in place only when the record itself is
     unshared. `:c::push-args` increments every pointer-typed symbol argument, so `o`'s count
     inside `:c::emit` is never 1. Making that a move is what C-143 tried and what got reverted.
  2. **Read destructively** -- null the slot as the pointer leaves, so "sole owner" becomes true
     by construction. It converts silent corruption into a null dereference, which is more
     honest and still not the right answer.
  3. **Count the store** -- increment for fresh values too. Then every field read sees 2 and the
     copy comes straight back.
- **The root, and this is the first time it is a correctness constraint.** C-126 chose an
  increment-only count and wrote down what it buys: *"it answers exactly one question"*. C-128
  and C-143 both said the next step is decrements, both for MEMORY. It is not a memory question
  any more: **without a count that can come down, a compiled wat cannot both answer correctly
  and append in place through a container field.** wat has no way to say a reference is unique
  -- Rust has it in the types, which is the deal C-126 measured us against.
- **What did NOT regress**, and it matters which: an accumulator that is a linear PARAMETER is
  untouched -- `cat32000`, `catx` and `grow20000` compile to **byte-identical binaries** under
  both rules (md5 checked both ways), and `mem.sh` still reads 2,468 KiB for 32,000 appends.
  What regressed is specifically accumulating into a record FIELD, which is the one shape the
  compiler itself is built out of.
- **The other in-place decision was audited and is clean.** There are exactly two -- `concat`
  and `conj` -- and `conj`'s has always demanded a symbol *and* `linear?`, so a borrowed pointer
  never reached `vec_conj_own`. It is conservative in the other direction: `(conj (conj v 1) 2)`
  copies although the inner `conj` allocated, which is a missed optimisation and the symmetric
  half of this fix. Left undone deliberately, because the point of this entry is that the cheap
  half of that symmetry is what was wrong.
- **And the interpreted suite had been red since C-148, in the other direction.** `elf/bad/`
  holds programs that MUST DIE -- one per arithmetic trap -- and `run.sh`'s exclusion list knew
  about `elf/refuse*.wat`, `elf/native/` and `elf/bench/` but not the directory C-148 added, so
  `./run.sh elf` reported two failures whose failure WAS the pass. Excluded now, with the reason
  written next to the other three.
- **And the harness was only looking at 20 of the 25 programs in `elf/src/`.** `moved`, `pvec`,
  `assocn` and `extremes` were being built and never compared against the interpreter; each was
  run by hand when it was written and never again. All of them are in the differential loop now,
  which is where `strown` went too.
- **Class:** FIX.
- **Repro:** `./elf/out/strown.elf` against `wat elf/src/strown.wat`; `tools/elf-run.sh`.


### C-152: the accumulator stops needing an ownership proof — 444,556 KiB to 162,908, and correctness keeps its 94%

- **Where:** `elf/compile.wat` (`:c::Buf`, `:c::buf-add`, `:c::buf-str`, `:c::Out`, `:c::PassR`,
  `:c::emit`, `:c::patch`, `:c::static-str`, `:c::print-string`, `:c::pass`, the driver).
  Answers F-127's price directly, sixteen edits, no change to what any binary contains.
- **F-127 left the compiler correct and 3.06x hungrier**, and named three roads out. Two of them
  — check the container's count, decrement when a reference dies — are the ownership model, and
  C-143 already crashed into that wall. This is the third, which is **C-144's move**: when the
  ownership model cannot win, *stop asking the compiler* and change the data structure.
- **A `Buf` is the string as a VECTOR OF CHUNKS.** `concat` can only extend in place when
  nothing else holds the string, which a record field can never promise. `conj` on the promoting
  vector's tree arm (C-145) needs no such promise: `tree_push` copies the root and one node per
  level and **shares everything else**, so an append costs about 850 bytes regardless of how
  much has been accumulated, and nothing is mutated, so there is nothing to prove.
- **The string only has to exist whole twice** — when a patch reaches into it, and at the end.
  `:c::buf-str` is that fold, and **its** accumulator is a linear parameter read once on every
  path, so C-127's in-place rule applies to it honestly and the flatten is linear.
- **Measured, interleaved on three retained binaries, minimum of each:**

  | | peak KiB | wall (min of 15, load 0.85) |
  | --- | --- | --- |
  | the old UNSOUND rule (pre-F-127) | 145,920 | 280 ms |
  | F-127's correct rule, String accumulators | 444,556 | 379 ms |
  | **correct rule, chunk accumulators** | **162,908** | **293 ms** |

  **94% of the memory and 87% of the time, bought with no ownership analysis whatever.** The
  compiler costs 416 bytes more (137,078 vs 136,662) and produces byte-identical output for all
  52 binaries.
- **And it moves the whole question.** The compiler no longer depends on appending in place
  through a container field anywhere. F-127's defect made that path CORRECT; this makes it
  UNNECESSARY, which is a better place for a language to be: the fast path is now the one that
  needs no proof, and the one that needs a proof is a user-program optimisation rather than the
  thing the compiler is built out of.
- **What is left is `:c::patch`, and now it is the largest single item.** Compiled with the patch
  leaving the buffer alone, the same compiler peaks at **146,612 KiB against 164,444 — 10.9%**;
  and 146,612 is where the old unsound rule sat. **A free patch would make the correct compiler
  exactly as cheap as the incorrect one.** It costs that because a patch is the one operation
  that needs the string whole, and it needs it whole because **F-104**: there is no positional
  update, so a four-byte displacement cannot be written where it goes. C-124 measured that gap
  at 49 bytes of machine code wat does not expose; this measures it again, at 10.9% of the
  compiler's memory, on the compiler itself.
- **Class:** IMPROVE.
- **Repro:** `tools/loop.sh`; `elf/bench/out_maxrss ./elf/out/compiler.elf`.


### C-153: where the gap to `gcc -O2` actually is — hardware counters, and two experiments that said no

- **Where:** `elf/bench/loopsum.wat` and `loopsum.c` (new), `tools/vs-c.sh` (a fifth section).
  The builder installed `perf` for this; before it, every claim in this section of the ledger was
  a stopwatch and a guess.
- **fib(32), pinned to one P-core** (`taskset -c 2`, the machine is hybrid and unpinned counts
  split across P and E cores into nonsense):

  | | instructions | cycles | branches | IPC |
  | --- | --- | --- | --- | --- |
  | ours | 80,687,452 | 22,175,786 | 23,743,694 | 3.64 |
  | gcc `-O2` | 51,422,383 | 10,044,616 | 7,402,486 | 5.12 |
  | gcc `-O0` | 113,017,452 | 56,230,166 | 24,731,580 | 2.01 |

  1.57x the instructions, **3.2x the branches**, 2.2x the cycles.
- **First experiment: are the overflow checks the gap?** fib does three arithmetic operations per
  call and C-148/C-150 give each a `jo`, so the arithmetic that F-125 made *correct* ought to be
  most of that branch count. Compiled with every check removed — unsound, and purely to measure
  the ceiling — fib32 is 828 bytes smaller, which is exactly the 138 `jo`s it contains:

  | | instructions | cycles | branches |
  | --- | --- | --- | --- |
  | checks on | 80,687,458 | 22,086,941 | 23,743,700 |
  | checks **off** | 70,113,721 | 21,133,187 | 13,169,963 |

  **45% of our branches, 13% of our instructions — and 4.3% of our cycles.** A never-taken,
  perfectly-predicted `jo` costs a decode slot and nothing else on an out-of-order core. An
  interval analysis to prove the checks away was about to be built; it would have bought 4%.
  **Trapping arithmetic is very nearly free, and that is the answer to whether wat can afford to
  be correct here.**
- **Second experiment: is it inlining depth?** `:c::inl-depth` is a global 4 and
  `:c::inl-depth-for` a per-callee cap; raising only the cap changes nothing, because the global
  start binds — which is itself worth knowing, since the first run of this experiment measured
  four identical binaries and looked like a null result.

  | depth | size | instructions | cycles |
  | --- | --- | --- | --- |
  | 4 (shipping) | 3,719 B | 80,687,452 | 22,175,786 |
  | 5 | 6,935 B | 81,272,706 | 25,366,053 |
  | 6 | 13,367 B | 74,386,240 | 21,346,370 |
  | 8 | 51,959 B | 64,207,641 | 18,563,239 |

  **14x the code for 16% of the cycles**, and depth 5 is *worse* than depth 4. C-147 said the
  remaining call overhead was ~11% and that deeper inlining could not close 1.7x; this is that
  claim measured rather than asserted, and it holds.
- **So a benchmark with no calls in it at all.** `elf/bench/loopsum.wat` is a self tail call,
  which C-121 turns into a `jmp` on the same frame, so the loop is arithmetic, a compare and a
  branch. **The first version of it was summed away by gcc in CLOSED FORM** — 231,032
  instructions for the whole program against our 1.8 billion — so the conditional subtraction
  that defeats that is load-bearing, and the lesson is that a benchmark C can solve measures
  nothing.

  | 100M iterations | instructions | cycles | branches | per iteration |
  | --- | --- | --- | --- | --- |
  | ours | 2,600,000,501 | 406,300,747 | 800,000,336 | **26 insn, 4.06 cyc, 8 br** |
  | gcc `-O2` | 600,231,241 | 303,823,410 | 100,059,687 | **6 insn, 3.04 cyc, 1 br** |

- **And the surprise is which way that cuts.** We issue **4.3x the instructions for 1.34x the
  cycles**, at an IPC of 6.40 against gcc's 1.98 — we are saturating a 6-wide machine while gcc
  sits latency-bound on its own accumulator chain. **Our straight-line code is fat and the
  out-of-order engine is hiding most of it.** It will stop hiding it the moment a loop is
  throughput-bound rather than latency-bound, so the fat is a real debt, not a free pass.
- **The fat, named, from the loop body.** Eighteen instructions where five would do, and every
  one of them is a compiler task rather than a language limit:
  - `mov %rbx,%rax` then `cmp $0x0,%rax` — a comparison against a register operand still routes
    the LEFT side through rax. `test %rbx,%rbx` is one instruction and one byte shorter. C-133
    took the right operand; the left one was never taken.
  - `push %rax` / `pop %r12` **adjacent** — that is a `mov`, written as a store and a load.
  - `mov %r12,%rax` then `mov %rax,%r9` — the scratch pool routes through rax to reach a
    register it could have been given directly.
  - `mov %rbx,%rax` emitted twice for the same value either side of a branch, because C-149's
    tracking clears at a join and never learns what both paths agree on.
  - every branch a `rel32` (NEXT.md 3c).
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh` section 5; `taskset -c 2 perf stat -e cpu_core/instructions/ ./elf/out/loopsum.elf`.


### C-154: the four redundancies C-153 named, taken — 26 instructions an iteration to 22

- **Where:** `elf/compile.wat` (`:c::reg-cmp-imm`, `:c::reg-of`, `:c::imm-cmp?`, `:c::reg-to-scr`,
  `:c::reg-of-name`, `:c::push-but-last`, `:c::tail-store`, `:c::call-user`, `:c::if-cmp`,
  `:c::fold` and its call site, `:c::expr`).
- **C-153 named four wasted instructions in one loop body.** Three of them were worth taking and
  one was not, and the one that was not is the interesting entry.
- **The comparison with a register on the left.** C-133 taught the RIGHT operand of a binop to
  come straight from an immediate or the frame; the left one always went through rax, so every
  `(if (= i 0) ...)` on a parameter cost a `mov` before a `cmp` that could have named the
  register. `cmp $0x0,%rbx` where there were two instructions. It costs nothing, because
  `:c::if-cmp` already restores what rax held across a compare-and-branch — and now rax holds it
  because nothing overwrote it.
- **The last argument of a self tail call never goes to the stack.** `:c::push-args` pushed every
  argument and `:c::tail-store` popped them straight back; the last push and the first pop are
  adjacent, which is a `mov` written as a store and a load, once per iteration of every
  tail-recursive loop. `:c::push-but-last` leaves it in rax.
- **The scratch copy comes from the source register.** `mov %r12,%rax ; mov %rax,%r9` is one
  instruction. Taking it naively made the first of the two **dead** rather than absent, because
  the caller had already emitted it — so the fix is that **the caller stops emitting it**:
  `:c::fold` now takes `ar`, the register the accumulator is still in, and the two paths that
  genuinely need rax load it themselves. That is the difference between 26 instructions an
  iteration and 22.
- **And the one that was not worth taking, which is why it is written down.** C-149 tracks what
  rax holds but only ever SET the field where a `let` binding stored one; extending it to every
  symbol load looked free. **It fired nowhere.** Every binary came out byte-identical and the
  compiler executed *more* instructions, purely because its own source had grown. The reason is
  structural: `:c::emit` clears the field, and any two reads of the same name have an emission
  between them. It is kept only because `:c::fold`'s `ar` needs `:c::reg-of-name` to ask the
  question — **as an optimisation it is worth zero, and C-149's tracking was already at its
  useful limit.**
- **Measured, minimum of five, pinned to a P-core:**

  | | instructions | cycles |
  | --- | --- | --- |
  | `loopsum` (100M iterations, no calls) | 2,600,000,531 -> **2,200,000,488** (-15.4%) | 404,131,657 -> **354,547,663** (-12.3%) |
  | `fib32` | 80,687,448 -> 79,389,357 (-1.6%) | 22,042,933 -> 21,940,583 (-0.5%) |
  | the compiler compiling everything | 790,244,709 -> 781,849,361 (-1.1%) | 491,803,160 -> 492,511,199 (+0.1%) |

- **Why the loop gets everything and fib almost nothing:** C-136 gives `rbx`/`r12`/`r13` to the
  parameters of functions with a self call in TAIL position, and all four of these peepholes fire
  on an operand that is already in a register. `fib` is not tail-recursive, so its parameters
  live in the frame and there is no register on the left of anything. **The register allocator
  decides how much the peepholes are worth**, which is an argument for widening C-136 rather than
  for more peepholes.
- **And what fib says next.** The peepholes DO fire in it -- `cmp $0x2,%rbx`, `%r12`, `%r13` --
  and at the fourth level of inlining it runs out and spills: `mov %rax,-0x18(%rbp)`. That is the
  spill C-147 predicted and the case NEXT.md item 4 is for, now with a disassembly behind it.
  **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  140,594 bytes, and the compiled compiler is 568x the interpreter; `elf-run` 25/25, `mem`,
  `vs-c`, `loop` green.**
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh` section 5.


### F-128: three holes the compiler has in itself, found by changing it

- **Where:** found while building C-155 (frame-pointer elimination); `elf/compile.wat`.
  None of these is about the language being compiled. All three are about the COMPILER, which
  is a wat program, and all three were found because a large edit made mistakes that a smaller
  one would not have.
- **1. A user call is not checked for arity.** **FIXED in C-156.** An edit left `(:c::emit X "58" 8)` -- two
  parameters, three arguments -- and the compiler compiled it. `:c::push-args` pushes three, the
  callee reads two at `[rbp + 16 + 8*(n-1-i)]` with ITS OWN `n`, and the caller pops three, so
  the stack stays balanced and the callee reads its parameters **from the wrong slots**. The
  symptom was two binaries silently differing by two bytes. `:c::inl-ok?` checks arity before
  inlining, so the check exists -- `:c::call-user` simply never asks it. **Class: FIX.**
- **2. `(+ i64 String)` compiles.** **FIXED in C-156.** A new parameter `k` was shadowed by `:c::direct`'s own
  `(let [k (:c::kind a pg)] ...)`, so `(:wat::core::+ d k)` added a displacement to a POINTER TO
  A STRING. The type pass knows both types -- it is the same pass that decides `=` on two
  Strings is `str_eq` (C-130) -- and it did not object. It compiled to
  `add 0x41a8fc(%rsp),%rax`, an address where a frame offset belongs, and only `elf/src/diag.wat`
  of twenty-five differential programs noticed. **Arithmetic on a pointer should be a refusal,
  and the compiler has everything it needs to refuse it.** **Class: FIX.**
- **3. A duplicate definition survived in the compiler for months.** `:c::reg-mov-from` was
  defined twice, ~30 lines apart, with byte-identical bodies. wat's `DefRedefForbidden` did not
  fire, because the two agreed; the moment one of them was updated and the other was not, the
  interpreter refused the file. So the check is real but **only fires once the copies have
  diverged -- which is exactly when the damage is already done** -- and the compiled compiler
  never checks at all, which is why `tools/loop.sh --fast` was green while `tools/bootstrap.sh`
  was red. The half-updated program ran, self-hosted and passed all twenty-five differential
  tests; it was wrong only in the function nobody had reached yet. **Class: FIX** (a redefinition
  should be refused whether or not the bodies agree), and **a lesson about the harness**: the
  fast loop cannot see anything only the interpreter checks.
- **Class:** FIX.
- **Repro:** each is a one-line edit to `elf/compile.wat`; the entry names the exact shape.



### C-155: frame-pointer elimination, and what it was actually worth

- **Where:** `elf/compile.wat` — `:c::Out` gains `sp`/`fk`/`fpr`, `:c::push`/`:c::popn`/
  `:c::at-depth0`/`:c::fp`/`:c::fp-at`/`:c::at-frame`, every frame-addressing helper, the
  prologue and epilogue, and `:c::nregs` 3 → 4. NEXT.md item 4, built.
- **Done in three steps, because the first one is the one that can be TESTED.** A local is
  `[rbp-8]` however deep the stack happens to be; without a frame pointer it is
  `[rsp + d + fk + sp]`, and the emitter is the only thing that knows the depth. So step one
  tracked the depth and changed **no bytes** — every binary byte-identical, peak unchanged at
  168,188 KiB, and `:c::at-depth0` asserting that every body ends where it started. Step two
  moved the addressing to rsp with rbp still maintained, so a wrong `fk` would fail loudly. Step
  three dropped rbp and gave it to the register allocator.
- **`clone` keeps its frame pointer, and that is not a workaround.** `clone` gives the child a
  fresh rsp and lets it INHERIT rbp, which is the only reason a spawned thread can read the frame
  it came from. Under rsp-relative addressing the child reads its own empty stack: `thread`
  printed `11 11` instead of `11 22`, and `threads4` answered `0` instead of `1000`. C-136
  already refuses such a function its register parameters and C-121 its tail calls; this is the
  third thing the intrinsic costs, and `:c::has-clone?` was already there to ask.
- **The layout mistake worth writing down.** `push rbp` put the saved rbp eight bytes below the
  return address, with the frame below that. Take the push away and the frame stays exactly where
  `sub rsp, frame` puts it, while the return address and the arguments come eight bytes NEARER.
  Subtracting eight from everything moved the locals down onto the saved registers —
  `mov %rax,0x10(%rsp)` was overwriting saved `r13`, and `fib(20)` answered 2374 instead of 6765.
  **Locals are the negative displacements and arguments the positive ones, so the correction is a
  test on the sign.**
- **Measured, interleaved, minimum of six, pinned to a P-core:**

  | | instructions | cycles | size |
  | --- | --- | --- | --- |
  | the compiler compiling everything | 798,552,820 → **776,615,139** (-2.7%) | 502,947,611 → **493,832,485** (-1.8%) | 141,504 → 147,174 B (+4.0%) |
  | `fib32` | 79,389,353 → 79,389,355 (0.0%) | 21,987,137 → 21,946,607 (-0.2%) | 3,716 → 3,719 B |
  | `loopsum` | 2,200,000,440 → 2,200,000,472 (0.0%) | 353,316,178 → 353,420,997 (0.0%) | 752 → 748 B |

- **And the honest reading: the two halves cancel on anything call-heavy.** Dropping rbp removes
  `push rbp` and `mov rbp,rsp` from every call — two instructions — and then giving rbp to the
  allocator adds its own `push`/`pop` back, one per call. Measured separately: **with three
  registers** `fib32` was -3.3% instructions but **+3.0% cycles**, because every frame access
  grew a SIB byte (rsp cannot be a ModRM base without one) and the code got less dense; the
  fourth register bought that back to flat. The compiler gains because it is full of functions
  with many live values and comparatively few calls.
- **What it actually bought** is therefore not the 1.8%: it is **a callee-saved register that
  did not exist before**, on a machine where the ABI has five and this compiler already spends
  two on the output buffer and the heap. Everything that wants one from here — a register
  calling convention above all — is now working with four instead of three.
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  147,011 bytes, and the compiled compiler is **705x** the interpreter; `elf-run` 25/25, `mem`,
  `vs-c`, `loop` green.**
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh`; `taskset -c 2 perf stat -e cpu_core/instructions/ ./elf/out/compiler.elf`.


### C-156: the compiled language stops being a SUPERSET of wat, and `imul` stops needing a `mov`

- **Where:** `elf/compile.wat` (`:c::arity-at`, `:c::ptr-among`, `:c::imul3`, the call clause and
  the arithmetic clause), `elf/bad/arity.wat` and `elf/bad/ptradd.wat` (new),
  `tools/gen-refuse.sh` and `tools/elf-run.sh`. Takes two of F-128's three.
- **Both holes were the same shape, and it is the shape C-124 went out of its way to avoid.**
  C-124 could have compiled `(assoc v 1 99)` for free and refused to, because *"compiling it
  would have made the compiled language a superset"* of wat. These two made it one by accident:
  **wat rejects both programs and the compiler accepted them.**
  - `(user/two 1 2 3)` — wat says `:user::two: expected 2 arguments, got 3`. The compiler pushed
    three, the callee read two at its own offsets, the caller popped three; the stack stayed
    balanced and the callee read **the wrong slots**. `:c::inl-ok?` had always compared arity
    before inlining, so the check existed — `:c::call-user` never asked it.
  - `(+ 1 s)` where `s` is a String — wat's `defclause` dispatch fails on it. The compiler
    emitted `add <pointer>(%rsp), %rax`, and only `elf/src/diag.wat` of twenty-five differential
    programs noticed. The type pass knew: it is the same pass that decides `=` on two Strings is
    `str_eq` (C-130).
- **The refusals are generated from the compiler, not written beside it** (`tools/gen-refuse.sh`,
  C-116's rule), so they are the same compiler; both new programs are also refused by the
  interpreter, which is the point.
- **And the call clause got cheaper while gaining a check.** The guard asked `:c::fn-addr`
  whether a name was a function and `:c::call-user` then asked again for its address — two
  linear scans of a 365-entry table per call site. Asking `:c::fn-of` once answers both and pays
  for the arity check: the naive version cost **+6.2% instructions**, this one **+2.4%**.
- **`imul` is the one arithmetic instruction with a three-operand form.** `imul $3,%rbx,%rax`
  multiplies a register by a literal into a different register, so the `mov` every other binop
  needs to get its left operand into rax is not needed. `add` and `sub` have no such form: `lea`
  does the arithmetic and sets no flags, and every one of these carries a `jo`.
- **Measured, interleaved, minimum of six:**

  | | instructions | cycles |
  | --- | --- | --- |
  | `loopsum` (the generated code) | 2,200,000,427 → **2,100,000,449** (-4.5%) | 351,658,342 → 351,097,553 (-0.2%) |
  | `fib32` | flat | flat |
  | the compiler (paying for the checks) | 783,652,137 → 802,246,401 (+2.4%) | 497,638,461 → 517,997,755 (+4.1%) |

  **`loopsum` is 22 instructions an iteration to 21** and shows almost nothing in cycles, because
  C-153 established that loop is latency-bound at IPC 6.4 — the machine had the slot to spare.
  It will show the moment a loop is throughput-bound. The compiler is slower because it is now
  doing two things it did not do; **that cost is compile time, and it buys the compiled language
  back inside wat.**
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  148,842 bytes; `elf-run` 25/25 and four refusals, `mem`, `vs-c`, `loop` green.**
- **Class:** FIX (the two refusals) and IMPROVE (the `imul` form).
- **Repro:** `tools/elf-run.sh`, which now refuses four programs instead of two.


### C-157: a self tail call stops going through memory — and the first compute benchmark we do not lose

- **Where:** `elf/compile.wat` (`:c::none-mention?`, `:c::tail-direct?`, `:c::tail-direct`,
  `:c::call-user`'s tail path).
- **The arguments of a self tail call were computed into the machine stack and taken straight
  back out.** They have to be computed before any parameter is overwritten, which is why they
  went there — but that is only NECESSARY when a later argument reads a parameter an earlier one
  clobbers. `(user/go (- i 1) (if (> a 1000000) (- a 1000000) a))` does not: nothing after the
  first argument mentions `i`. So `i` is written where it lands, and the `push`/`pop` pair C-153
  found on `loopsum`'s critical path — **a store and a load with forwarding latency, once per
  iteration** — is a `mov`.
- **The condition is exactly one question, asked with machinery that already existed.**
  Parameter `j`'s name is `pv[3j]` and its argument `ks[j+1]`; the assignment is safe in order
  when no argument after `ks[j+1]` mentions that name, which is `:c::occ` — the same counter
  C-127 uses for last-use. All of the parameters must qualify or none do, because a single
  clobber invalidates the order.
- **Measured, interleaved, minimum of six:**

  | | instructions | cycles |
  | --- | --- | --- |
  | `loopsum` | 2,100,000,432 → **2,000,000,443** (-4.8%) | 352,238,127 → **303,778,493** (-13.8%) |
  | the compiler | 809,439,024 → 804,136,058 (-0.7%) | 523,527,446 → 513,597,346 (-1.9%) |
  | `fib32` | flat | flat — `fib` is not tail-recursive |

  **The cycles moved four times as much as the instructions**, which is the whole point: one
  instruction of the four per cent, and a store-to-load round trip off the dependency chain for
  the rest.
- **And it is the first compute benchmark where we are not behind `gcc -O2`.** Head to head,
  pinned to a P-core, minimum of eight:

  | | instructions | cycles | IPC |
  | --- | --- | --- | --- |
  | ours | 2,000,000,400 | **303,273,696** | 6.59 |
  | gcc `-O2` | 600,231,244 | **303,792,305** | 1.98 |

- **The honest reading, because the number flatters us.** We issue **3.3x the instructions** and
  finish in the same cycles. That is not our code being as good as gcc's; it is that this loop is
  latency-bound on its own accumulator chain — both compilers wait on the same `add` — and a
  six-wide machine has the slots to hide our extra work. **It will stop hiding it the moment a
  loop is throughput-bound**, which is precisely what C-153 said when it measured IPC 6.40 and
  called the fat a debt rather than a free pass. The debt is now 20 instructions an iteration
  against six, down from 26.
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  150,311 bytes, and the compiled compiler is **714x** the interpreter; `elf-run` 25/25 and four
  refusals, `mem`, `vs-c`, `loop` green.**
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh` section 5; `taskset -c 2 perf stat ./elf/out/loopsum.elf` against
  `elf/bench/out_loopsum`.


### C-158: the register allocator, measured before it was built — and the four levers that do not close fib

- **Where:** no code. The builder asked for a register allocator; this is the probe that was run
  first, and the reason it was not built.
- **`fib(32)` against `gcc -O2`, pinned, minimum of ten:**

  | | wall | instructions | cycles | IPC |
  | --- | --- | --- | --- | --- |
  | ours | 14 ms | 79,389,356 | 21,927,866 | 3.62 |
  | gcc `-O2` | 7 ms | 51,422,402 | 9,972,984 | 5.16 |
  | gcc `-O0` | 37 ms | 113,017,444 | 56,025,125 | 2.02 |

  **2.2x the cycles at 1.54x the instructions** — so the gap is not only how much we do, it is
  how fast the machine can be made to do it.
- **The top-down breakdown says which end of the machine.** Measured two counters at a time,
  because five at once multiplexes and one run in five disagreed by a factor of two:

  | | slots | front-end bound | |
  | --- | --- | --- | --- |
  | ours | 132,763,248 | 57,270,420 | **43%** |
  | gcc `-O2` | 61,042,344 | 11,011,560 | 17% |

  **Back-end bound is ZERO** across every run — no dependency stall, no memory stall, no spill
  pressure. **A register allocator exists to relieve exactly that, and we do not have it.** It
  would have been the largest change in `elf/` to date and it would have bought nothing
  measurable on this benchmark.
- **Four levers, all measured, none of them enough:**
  - **Register allocation: 0%.** Back-end bound is zero.
  - **Overflow-check elimination: -3%.** Compiled with every `jo` removed — unsound, purely to
    find the ceiling — cycles go 21.95M to 21.29M. It **raises** front-end boundedness to 47%,
    because the checks were cheap uops filling slots the front-end was not using anyway.
  - **Inlining depth: -16% cycles for 14x the code** (C-153), and depth 5 is worse than depth 4.
  - **Branch density: ~8% of the bytes.** `fib32`'s hot function is 3,094 bytes; all 46 `jge` and
    24 of 46 `jmp` would fit an `rel8`, which is 256 bytes. The `jo`s are **26.4% of the bytes on
    their own** (136 x 6) and cannot shorten without a handler within 127 bytes.
- **What the machine is actually short of.** The uop cache is delivering (MITE is ~0.01% for
  both, so this is not legacy decode and not a length-changing-prefix stall) but it is idle a
  quarter of the time, against gcc's one seventh, and delivers 4.55 uops a cycle against 5.34.
  Our basic blocks are about three instructions long and our instructions average 4.5 bytes to
  gcc's 3.5. **We ask the front end for 1.63x the uops in shorter runs and longer encodings, and
  it is the front end that runs out.**
- **So the honest statement of where `elf/` stands on compute** is not "we need a register
  allocator". It is: **we execute half again as many instructions as `gcc -O2` in basic blocks
  half the length, and no single mechanism on the list above recovers more than a few per cent.**
  What would is emitting fewer instructions across the board — which is a grind, not a feature.
- **Class:** IMPROVE (a negative result that redirects the work).
- **Repro:** `taskset -c 2 perf stat -e cpu_core/slots/,cpu_core/topdown-fe-bound/ ./elf/out/fib32.elf`
  against `elf/bench/out_fib_O2`; two events at a time.


### C-159: shrink-wrapping — a base case stops paying for a frame it never uses, and fib drops under 2x

- **Where:** `elf/compile.wat` (`:c::param-of?`, `:c::wrap-val?`, `:c::wrappable?`,
  `:c::wrap-head`, `:c::compile-fn`), `tools/elf-run.sh` (a timeout that should always have
  been there). Built on C-158's instruction-level profile, which is the reason it was built
  instead of a register allocator.
- **The profile named it.** The two hottest instructions in `fib32` were `cmp $0x2,%rbx` (9.4%)
  and `sub $0x20,%rsp` (5.0%) — the test and the frame, both targets of a call. `fib` makes
  **1,298,098 calls** and roughly 63% of them return a parameter immediately, after executing
  `sub rsp,32`, four pushes, a parameter load, the test, four pops, `add rsp,32` and `ret`:
  **fourteen instructions to hand back the argument it was given.**
- **So the test goes first and the prologue happens only on the path that needs it.** The base
  case is now four instructions — `mov 0x8(%rsp),%rax ; cmp $0x2,%rax ; jge ; ret` — reading the
  argument where the caller left it, eight bytes up, because rsp has not moved yet.
- **Two conditions, both narrow on purpose.** The arm that returns early must be a parameter or
  a literal, so computing it needs no frame, no register and no call. And the function must have
  **no self tail call**: C-121 makes such a call a `jmp` to the end of the prologue, and the test
  now lives before the prologue, so the jump would skip it and the loop would never terminate —
  `elf/src/vectors.wat` hung on exactly that. It costs nothing to exclude them, because a loop
  pays its prologue once per call rather than once per iteration.
- **`fk` is zero before the prologue and `fkv` after it.** The first version read the argument at
  the offset it would have LATER (`0x48(%rsp)` instead of `0x8(%rsp)`) — a load from the caller's
  frame. Same class as C-155's layout mistake and caught the same way, by looking at four
  instructions of output.
- **Measured, interleaved, minimum of eight, pinned:**

  | | instructions | cycles | IPC |
  | --- | --- | --- | --- |
  | before (C-157) | 79,389,357 | 21,938,469 | 3.62 |
  | **shrink-wrapped** | **72,094,487** (-9.2%) | **19,483,749** (-11.2%) | 3.70 |
  | gcc `-O2` | 51,422,402 | 9,884,989 | 5.20 |

  **The gap on `fib(32)` goes from 2.22x to 1.97x** — under two for the first time. `loopsum` and
  the compiler are flat, which is right: neither has a wrappable function.
- **And a harness hole that cost an hour.** `tools/elf-run.sh`'s differential loop ran each
  binary with **no timeout**. The first, broken version of this change made `churn.wat` loop
  forever; that binary ran for seven minutes at 99% of a core after the harness had been killed,
  holding **ETXTBSY on its own file** so every later `write-hex` failed with
  `assert-eq written filesz` — a failure that looked like a compiler bug, reproduced on the
  *committed* source, and had nothing to do with either. R-005 is about `wat` runs; it applies to
  the binaries the harness runs too, and now it does.
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  153,625 bytes, and the compiled compiler is **780x** the interpreter; `elf-run` 25/25 and four
  refusals, `mem`, `vs-c`, `loop` green.**
- **Class:** IMPROVE.
- **Repro:** `tools/vs-c.sh` section 3; `taskset -c 2 perf stat ./elf/out/fib32.elf`.


### C-160: the short branch, taken — and the overflow trampoline, measured and thrown away

- **Where:** `elf/compile.wat` (`:c::tiny-arm?`, `:c::jcc-not8`, `:c::if-cmp`, `:c::wrap-head`).
  NEXT.md item 3c, half taken and half refused, both with counters.
- **A forward branch needs its distance before it can choose an encoding, and a single-pass
  emitter does not have it.** The usual answer is a measuring pass, which costs 50% of compile
  time. It is not needed for the case that matters: **when the arm being jumped over is a NAME or
  a CONSTANT, its length is bounded without measuring** — a symbol is at most an eight-byte load,
  a literal at most a ten-byte `mov`, and the `jmp` after it is five. Fifteen bytes, inside the
  127 a `rel8` reaches, known when the branch is emitted. `(if (< n 2) n ...)` is that shape and
  so is every base case in the corpus.
- **C-159's own branch is the extreme case**: it jumps over a value and one byte of `ret`, so the
  shrink-wrapped head is now `mov 0x8(%rsp),%rax ; cmp $0x2,%rax ; 7d 01 ; c3` — **eleven bytes
  for a base case that was fourteen instructions two findings ago.**
- **And then the same idea for `jo`, which did not work.** `jo` is six bytes because the handler
  is at the far end of the program, and it was **26.4% of the bytes** of `fib32`'s hot function.
  A two-byte `jo` reaches 128 bytes back, so the handler can be brought within reach by planting
  a five-byte `jmp ovf` in the instruction stream — and there is a free place to put one, because
  `:c::if-cmp` emits an unconditional `jmp` over its else arm and **nothing falls through a
  `jmp`**. It is a backward reference, so no extra pass is needed. It worked exactly as designed:
  `jo` went from 816 bytes to 388, and `fib32` from 3,719 bytes to 3,367.

  | fib32 | size | cycles (min of 14) | uop cache active |
  | --- | --- | --- | --- |
  | 6-byte `jcc`, 6-byte `jo` | 3,717 B | **19,493,294** | 15,799,558 |
  | **`rel8 jcc`** | **3,533 B** | 19,522,609 (+0.15%) | 14,823,807 |
  | `rel8 jo`, trampolines | 3,367 B | 19,898,965 (**+2.1%**) | 15,211,667 |

  **Nine and a half per cent smaller and two per cent slower.** The five dead bytes sit at the
  HEAD of the else arm's fetch region — the one place a never-executed blob costs the most — and
  that is worth more than the four bytes each `jo` gives back. Reverted.
- **The two together say something worth keeping.** Shortening the branch itself is free and
  helps the compiler (**-1.0% cycles** on the largest program we have) while leaving `fib`
  unmoved; planting bytes to shorten a branch is not. **Density is not a quantity to maximise —
  it is live bytes that matter, and dead ones in a hot fetch path cost several times what they
  save.** The first measurement of the `rel8` change said +1.5% on `fib` and the second, with
  fourteen repetitions instead of eight, said +0.15%: at this scale the honest reading needs more
  samples than a conclusion feels like it deserves.
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  154,307 bytes; `elf-run` 25/25 and four refusals, `mem`, `vs-c`, `loop` green.**
- **Class:** IMPROVE (the short branch) and a recorded refusal (the trampoline).
- **Repro:** `taskset -c 2 perf stat -e cpu_core/cycles/ ./elf/out/fib32.elf`, min of fourteen.


### C-161: `+` and `*` do not care which side they came from

- **Where:** `elf/compile.wat` (`:c::fold`'s general path). Found by reading C-159's profile
  rather than by reasoning about the compiler.
- **The profile of `fib(32)` after shrink-wrapping put one sequence at 15% of its cycles** — the
  `add %rcx,%rax` sites, which are where the two halves of `(+ (fib (- n 1)) (fib (- n 2)))`
  are brought together. Around each one:

  ```
  push %rax        ; the left result, saved across the second call
  <the second call>
  mov  %rax,%rcx   ; the right result out of the way
  pop  %rax        ; the left result back
  add  %rcx,%rax
  ```

  Four instructions and three memory operations to add two numbers. The `mov` and the `pop`
  exist only to put the operands on the sides `add` expects.
- **`+` and `*` have no sides.** `pop %rcx ; add %rcx,%rax` leaves the sum in rax whichever
  operand came from where, so the `mov` is not needed. `-`, `quot` and `rem` keep the long form,
  because for them the order **is** the answer — and getting that wrong would be a silent wrong
  answer rather than a crash, which is why the test is the operator and not a guess about
  operands.
- **Measured, interleaved, minimum of ten:**

  | | instructions | cycles |
  | --- | --- | --- |
  | `fib32` | 72,094,500 -> **68,569,916** (-4.9%) | 19,667,511 -> **19,293,379** (-1.9%) |
  | `loopsum` | flat | flat |
  | the compiler | flat | flat |

  `fib` is now **1.94x `gcc -O2` on cycles and 1.33x on instructions** — the instruction ratio was
  1.54x three findings ago. The two ratios still disagreeing by that much is the same statement
  C-158 made: what is left is not how much we do, it is how fast the front end can be made to
  supply it.
- **What is left in that sequence.** Three instructions and two memory operations, where a frame
  slot would do it in two: `mov %rax,SLOT` ... `add SLOT,%rax`. That needs the frame-size
  analysis to count spill slots as well as `let` bindings, and a frame one slot too small is
  silent corruption rather than a crash — so it is written down rather than attempted here.
- **`tools/bootstrap.sh` green from the interpreter — 53 binaries byte-identical, fixpoint at
  154,004 bytes; `elf-run` 25/25 and four refusals, `mem`, `vs-c`, `loop` green.**
- **Class:** IMPROVE.
- **Repro:** `taskset -c 2 perf stat ./elf/out/fib32.elf`; the profile is
  `perf record -e cpu_core/cycles/ -c 2000`.


## Predicted, unverified

Read from wat-rs's docs on 2026-09-14. Several of those docs have fallen behind the code, so
each of these stays unverified until a repro runs against the current substrate.

| Book / chapter | Needs | wat-rs doc says | Expected class |
|---|---|---|---|
| ~~Little Schemer ch 9~~ | Y combinator (anonymous recursion via self-application) | no anonymous local recursion (ITERATION-PATTERNS.md) | **overturned: Z works through a self-referential struct, see C-005** |
| ~~Seasoned Schemer ch 12~~ | `letrec` | "NOT IN WAT" (ITERATION-PATTERNS.md) | **verified: named fn refused (R-001); let-bound self-reference fails only at runtime (F-007)** |
| ~~Seasoned Schemer ch 13–14~~ | `letcc` / call/cc, escape use | not mentioned anywhere in the docs | **verified CLEAN via `Result/try` (C-006)** |
| ~~Seasoned Schemer ch 19~~ | re-entrant continuations (generators) | no call/cc; state lives on services | **verified: no call/cc (R-003); generators port to lazy streams (C-017)** |
| ~~Seasoned Schemer ch 15–17~~ | `set!`, closures carrying state | "mutation-free by construction" (CLOJURE-ROSETTA.md) | **overturned: set! ports to Cell services (C-014)** |
| ~~Little Schemer throughout~~ | lists mixing atoms and lists | collections are monomorphic; `:Any` is banned | **resolved: quoted forms (`:wat::WatAST`) are the route, see C-004** |
