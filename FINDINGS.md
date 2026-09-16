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
| SICP (NEXT.md §3) | 4 chapters, 65 results | all pass (`sicp/README.md`). Our own Scheme on each section's topic is the oracle, run by guile (`tools/sicp-oracle.sh`), and every printed result must match. §3.1 local state (20): an account as a service, two access points as two peers on one address. §3.3 mutable data (25): a queue and a table as services, since wat has no mutable pairs to build the book's two-pointer queue from (the Arena, C-016, is the other route). §3.4 concurrency (11): four workers on one account at once through `:wat::bracket::map`, where the service is the serializer, so the book's unserialized bug can't be written. §3.5 streams (9): the stream operations written on `:wat::stream::lazy`. Not ported: §4.1's evaluator, which Make-a-Lisp already covers. F-052, F-053 (a forced stream doesn't remember), F-054 (a definition can't name itself) |
| Advent of Code (NEXT.md §4) | 5 puzzles, 10 answers | in progress, all matching (`aoc/README.md`). The puzzles and their inputs are ours, in Advent of Code's shape — its own texts and inputs are not redistributable — each with a Clojure reference implementation (`tools/aoc-oracle.sh`) whose answers the wat solution must print. day01 sonar (2000 readings), day02 smoke (a 100×100 grid, read one character at a time), day03 words (5000 words in a hash map), day04 binary (the bits of 1000 numbers, as arithmetic: F-035), day05 paths (Dijkstra over 3600 then 90000 squares, as a bucket queue: F-056). Times: wat 1.1 s, 1.8 s, 0.9 s, 1.0 s, 20.6 s against Clojure's 2.6 s, 2.4 s, 2.5 s, 2.5 s, 2.8 s. The first four are in Clojure's range with a fifth of its startup. The fifth is nearly all map and set updates, and took 135 s until its frontier moved from `HashMap`/`HashSet` to `PersistentMap`, which shares structure where those copy — a dozen lines, 6.5× (F-057), and the conversion ran into F-058. F-055, F-056, F-057, F-058 |
| PAIP (NEXT.md §5) | 2 chapters, 58 results | unification ports to quoted data with no term language at all, and passed first run (C-033, `paip/README.md`). Our own Scheme is the oracle, run by guile (`tools/paip-oracle.sh`); Norvig's code is not read or copied. A pattern is an ordinary quoted form and a variable is the symbol `?x`, so `paip/lib/unify.wat` walks `:wat::WatAST` itself: `ast-kind` gates, `ast-name` reads a symbol's text (it raises on anything else, so the kind test must come first), `ast->children` decomposes, `with-children` rebuilds, `=` is structural, and `ast->source` prints exactly as guile does. The substitution maps a variable's name — not its node — to a term, and is a `PersistentMap` (F-057). Failure is `Option.None`. Chapter 12's Prolog then runs on quoted clauses too (C-034, 33 results): a clause is a quoted list, the database is a value rather than a service (nothing mutates, and F-051 charges 224 µs a message), backtracking is eager (F-053 means a stream would not memoise), and a clause's variables are renamed apart with `symbol-node` through a threaded counter, since wat has no mutable variable. Cyclic mutual recursion is accepted. **F-059 is where quoted data runs out:** PAIP's membership clauses carry a list with a variable tail, and wat's reader has no dotted pair — `(?i . ?rest)` reads as three children with a symbol named `.` in the middle, then prints back unchanged. Those clauses cannot be written, in either implementation. That is NEXT.md §5's answer: quoted data carries symbolic pattern matching as far as the improper list, and no further |
| Project Euler (after NEXT.md) | 4 problems, 17 answers | p16, p20 and p25 — the digit sum of 2^1000, the digit sum of 100!, and the first Fibonacci term with 1000 digits. Chosen to press where the ledger was thinnest: F-047 (a bigint computes but cannot be compared) had been found in a single koan row and never exercised by a workload. The oracle is our own Clojure (`tools/euler-oracle.sh`); Project Euler's problem statements are not reproduced. **F-060:** a bigint has no `to-string` where every other scalar does, and its whole surface is six verbs (`+ - * /`, `to-f64`, `to-rational`) — no comparison, no modulo. Its digits come only from `:wat::edn::write`, which appends `N`, so `length` is digits + 1; and `to-f64`, the thing a user finds instead, silently loses the number (2^1000 becomes 17 significant digits and 285 zeroes). p25 never compares two bigints: it asks whether the digit count has reached 1000, which is an i64 comparison. Then p22 names scores (C-035) adds the text half, chosen because it is made of the two things wat is worst at: **F-061**, the whole regex surface is `matches?` answering a bool — a capture group compiles and what it matched can never be read, though wat-rs depends on the entire `regex` crate — so the file is parsed by trim, split and `subs`; and **F-062**, a String has no characters, no `index-of`, `replace`, `split-lines` or `blank?`, `reverse` refuses it and `split` refuses `""`, so every letter is a one-character `subs` at about 16.7 µs. Scoring by scanning the alphabet costs 2751 ms against 395 ms through a `PersistentMap` (7.0×, measured — not the 26× the reasoning suggested). String sort order matches Clojure exactly, checked rather than assumed. F-047, F-060, F-061, F-062 |
| The rete (after NEXT.md) | 2 cases, 16 results | wat ships a production rule engine and nothing here had touched it — nor had any documentation (F-065: zero word-boundary hits in USER-GUIDE, CHEATSHEET, CLOJURE-ROSETTA or the docs README, against 134 verbs and 4154 lines of wat). `rete/r01-chaining.wat` puts the same supply-chain rules to wat and to clara-rules (`tools/rete-oracle.sh`) and all 8 results agree (C-036): a guarded join, forward chaining through a derived fact, negation over that derived fact, existence that doesn't collapse into a join, and an accumulator over derived facts. The engine is correct; only the documentation is missing. `r02-retraction.wat` then asks what r01 left out — what happens to a derived fact when its support goes — and seven of eight scenarios agree with clara, including transitive retraction and re-insertion. The eighth is **F-066**: two supports deriving the identical fact leave wat holding one and clara holding two, because wat's closure is a set of facts and clara's memory is a bag of derivations; each engine's accumulator then follows its own model. Both fire the rule twice, so it is a collapse, not a missing join. Then **F-067**, found by putting one session through wat's own two implementations rather than through clara: `fire-rules$oracle` — which wat-rs calls "the SPEC / differential oracle" — and the public `fire-fixpoint` both keep a stale `0` from the accumulator's empty first pass beside the correct answer, where `fire-rules` keeps only the answer. Bare folds (`count`, `sum`) leak; Option folds (`min`, `max`) don't, because `None` is dropped rather than asserted |
| SQLite (after NEXT.md) | 1 case, 17 results | wat ships `:wat::sqlite::` — open / open-readonly / execute-ddl / execute / select / begin / commit / pragma — and nothing here had touched it. `sqlite/s01-crud.wat` puts the same schema and queries to wat and to the sqlite3 CLI (`tools/sqlite-oracle.sh`), the same engine wat binds, and all 17 agree (C-037): bound parameters, NULL through `Cell.Nil`, aggregates over a nullable column, GROUP BY with NULL as its own group, update, delete, ordering, and a zero-row result. **Two things it does better than the language around it:** the read-only connection is capability-honest and a write through one is refused *at startup*, not by the database; and failures arrive as `Result` values (`Error.Transient/Constraint/Fatal`), so a program survives four of them without the thread-spawning catch F-063 priced at 1.3 ms. **F-068:** `begin` and `commit` exist, `rollback` does not, on a surface explicitly closed to additions — though raw `execute conn "ROLLBACK"` works and does undo the write. Rows are positional: `select` answers vectors of `Cell`s with no column names. F-034 confirmed again: a `REAL` holding 2.0 renders as `2` |
| The Store contract (after NEXT.md) | 1 case, 5 results | wat ships a backend-agnostic storage contract, `:wat::query::Store` (DynamoDB-shaped pk/sk/data with named GSIs), and **two** services satisfying it — `mem-store` and `sqlite-store`. `wat/query/mem.wat` says the in-memory one exists partly to be "differential-tested against", so the backends check each other and no external oracle is needed. `store/q01-two-backends.wat` drives ensure-schema, a put, three keyset pages and a GSI scan through one `Store`-typed function against both peers: all five results identical (C-038). wat-rs asserts the same inside its own harness; the addition here is that it holds for an **ordinary program**, with no deftest or fixture loader. A dialed peer really is the surface — not F-029, since that surface is non-parametric. **F-069:** a consumer writes more outcome arms than logic — 56 of 182 lines are match arms, and wat-rs's own fixture lands at exactly 182 too, with a 529-character `connect` line because F-052 forbids factoring the dial into a helper |
| wat's own documentation (probes only) | 626 examples executed | wat reflects every `@example` in its source into typed records and ships a runner for them, so the documentation is executable. The runner is masked: one unguarded comparison raises and hides every other example, which wat-rs records in a NOTE with three refuted fixes and an `#[ignore]`d gate saying "FIVE failures, ONE cause". Unmasked by wrapping each verdict in `:wat::test::run-thread`, the count is **134 of 485 runnable** (F-070): 44 stale constructor spellings, 23 stale variant spellings, the builder's 5 angle-bracket cases reproduced exactly, 19 eval-context limits, 6 maskers, 17 genuine mismatches, 20 other. The NOTE's open question — whether the runner can guard its own comparison — is answered yes: `run-thread` exists and `wat/test.wat` loads at #34 against `wat/doctest.wat` at #38; it looks absent only because F-063 puts wat's one general catch in the test namespace. Its picture is also incomplete: `eval-ast!` raises past its own Result too. Its unidentified "instance 2" is `:wat::core::Option/expect`. F-071: the match-arm refusal names `<enum>::<Variant>` as the remedy — the spelling it just refused |
| The holon algebra (probes only) | 12 VSA laws, 3 probes | `:wat::holon::` is wat's largest surface — 94 verbs — and the layer wat exists for. It needs no oracle: a vector-symbolic architecture has laws. Ternary vectors, d = 10000. **Eleven of twelve hold exactly** (C-039): identity, quasi-orthogonality, bind commutes, bind makes a new vector, bundle stays similar to its parts, bundle commutes, permute destroys similarity, permute inverts, permute distributes over bind. **F-072:** the twelfth — the self-inverse axiom — holds only to cosine 0.818, stable at 0.815 ± 0.003 over six pairs, and compounds multiplicatively (0.667 at two rounds, 0.543 at three), so nesting is bounded at about three levels before dropping under the 0.49 that `presence?` requires. There is no unbind verb, so binding twice is the only way back, and nothing documents any of it. A codebook lookup still wins by two orders of magnitude. **F-073:** `coincident?` is documented as "whether a's cosine clears the coincident floor" but implemented as `(1 - cosine) < floor` — the opposite test; the floor is a tolerance below identity (0.99), not a similarity threshold (0.01). Confirmed three times over by `coincident-explain`'s own `min-sigma-to-pass`. **F-074:** `presence?` refuses the raw `Vector`s that `vector-bind`/`bundle`/`permute` produce, so the looser recognition test is unreachable from the raw path — exactly where F-072 puts you |
| The formatter (probes only) | 62 stdlib files | `:wat::fmt::` is grep facts + 54 rete rules + a dumb emitter, with the rules deliberately unbaked in `wat-scripts/fmt/rules/`. **Idempotent on all 62 files of wat's own stdlib, 0 failures** (C-040) — the right property, and it holds. It is not a pure layout tool: formatting changes the parse of 14 files, and every one of those diffs is purely the **param-spec migration** (107 `[]` insertions, zero deletions) — deliberate, since enums will require a param-spec, and a useful census of what is still on the bare spelling. **F-075:** it runs at about 10 KB/s with an ~800 ms fixed floor (two files of 2 KB and 5 KB both took 812 ms), so `service.wat` takes 22.9 s and the cheapest possible format costs 0.8 s. Linear, not quadratic — the cost is honest, just high; caching the compiled rule network across formats would pay the floor once per process |
| The docs, compiled (tools only) | 203 verbs verified | **F-087:** every `:wat::` verb the four user-facing documents name, handed to the compiler one at a time. **68 MISSING, 19 RETIRED, 116 EXISTS — 87 of 203 rejected (43%).** **49 of 159 fenced code blocks (30%)** carry at least one, and 26 use the retired `:wat::core::define`. The material is primary, not cautionary: §4 "Writing functions" is headed ``### `define` — named registration``; the "slightly richer first program" is refused for `-> :()`; a reference table at L3703 gives signatures for six `:wat::stream::` verbs where the namespace has four, none of them those. The refusals are excellent — almost all name their replacement and cite the arc — so the substrate holds the mapping the prose lacks, which is F-076's shape at forty times the scale |
| wat-fix (probes + tools) | 16 programs round-tripped | **F-092:** `wat/fix.wat` is the wat-to-wat converter whose header reads "THE PROVING POINT: wat writes wat", and whose documented STASH-DANCE applies it to a whole corpus at once. Converted 16 green self-contained probes and ran both: **7 identical, 8 no longer start, 1 failed to convert.** Four causes, and **three of them have no correct output at all**: only the fn-type bracket is a mis-dispatch (`to-symbol` vs `to-type-form` differ correctly; `fix-seq` can't see which bracket it is in), while `:wat::WatAST`, `Type/method` and a `defenum` name have **no faithful-Clojure spelling** — every candidate is unresolved, and `Result/try` canonicalizes its `/` back to `::`, a different name. The fix for those three is to refuse, not rewrite. **F-093:** and the 7 that converted cleanly each lost call-site type checking. The same program declared `i64 -> i64` and handed a String is **refused at startup** in rust-scheme and **runs, printing the String, exit 0** in faithful-Clojure. Declarations are checked (unknown annotation types and bad return literals are both caught); the argument at the call is not. F-014's consequence, and the codemod's `head-rule` exists to move every call into that spelling |
| Rationals (probes only) | 1 probe | **C-047:** exact and Clojure-faithful. `1/3+1/3+1/3 = 1` is **true** where the f64 control `0.1+0.2 = 0.3` is **false**; commutativity, associativity, distributivity and `x*(1/x)=1` all hold; arbitrary precision (no i64 overflow); `1/0` refused at lex time. The one surprise is Clojure's: `4/2` reads as `i64`, not `rational` — verified identical in **clj 1.12.6** (`(class 4/2)` is `java.lang.Long`) — so `:wat::rational::+` refuses `4/2` while the generic `:wat::core::+` takes it. The namespace is named **zero** times in any user-facing page. **F-090:** and the collapse leaks. `:wat::rational::+` declares `-> :wat::core::rational` and returns a **bigint** when the result is whole (the code comment: "this stone's pinned collapse"). `+ - * /` were all made lenient enough to absorb it; **`to-f64` was not**, so `(to-f64 (+ 1/2 1/2))` type-checks and dies at runtime. A well-typed two-call program with no user types in it. **F-091:** a lex error names no file, line or column — only a byte offset into `parser.rs` |
| The CLI (tools only) | 4 modes | **F-089:** `wat --help`, `-h`, `--version` are all read as *filenames* — `read --help: No such file or directory`, exit 66 (`EX_NOINPUT`). The usage block exists but prints only when `wat` is run with **no arguments at all** (exit 64, `EX_USAGE`). It names four modes; **only `--check` appears in any user-facing page** — `--repl`, `--mcp` and `--grep` have **zero** mentions across all four. The REPL works: `(:wat::core::+ 2 3)` → `5`. `--fmt`/`--lint`/`--test` are not modes at all (the formatter, linter and test runner are wat-level libraries, which is reasonable and also unstated). F-087 seen from the other side: the docs name 87 verbs the substrate lacks, the substrate has 3 modes the docs lack |
| Streams (probes only) | 1 probe | **F-088:** the documented stream API and the real one are **disjoint**. The docs name 9 verbs (`map`, `take`, `collect`, `fold`, `chunks`, `flat-map`, `for-each`, `spawn-producer`, `from-receiver`, `with-state`, …) and **none exists**; the substrate has 4 (`cons`, `empty`, `lazy`, `next`) and **none is documented**. Same shape for `:wat::config::` (7 named, 0 exist; 1 exists, 0 named) and `:wat::list::` (2 named, the namespace has no verbs at all). `:wat::kernel::` is the largest absence at 15 — channels, `process-send`/`recv`, `fork-program`, `run-sandboxed`. This closes a real road: `filterv` refuses a `PersistentVector` (F-080) → `filter` answers a `Stream` → the documented `collect` does not exist → `(length <Stream>)` type-checks and dies at runtime (F-031). The probe supplies the missing collect in six lines (P-025) |
| Telemetry (probes only) | 3 probes | **C-045:** the journal's sort key holds the property its read path depends on — `time-sk` is 38 chars for every input across the whole i64 range (1677–2262), and lexicographic order matched chronological order on all 10 adjacent pairs, including both extremes and either side of the epoch. `mem.wat` really does compare `sk` as a String, so this is load-bearing. **C-046:** surface-splice works in both directions — the spliced accessors read correctly, ctor order is splice-first, and a function typed `[s <- :wat::telemetry::Scope]` **accepts a `Metric` that spliced it**, which is the contrast with F-029. wat's own source never consumes `Scope` as a surface (zero uses); this probe is its first. **F-085:** the user guide's uuid backward-compat note is wrong about 3 of the 4 spellings it names. **F-086:** the three telemetry headers describe a primed `:wat::telemetry'` namespace that exists only in their own comments |
| The cache (probes only) | 3 probes | **C-044:** `:wat::cache::Lru` is a real LRU, not a FIFO wearing the name — the decisive case (cap 2, put a, put b, **get a**, put c evicts **b**) passes with its no-get control (evicts **a**) beside it, plus 9 more assertions on displacement, update and the `len` bound over 500 puts. Its two declared panics fire with the offending value and are recoverable through `run-thread`. **F-083:** but `HolographicLru::put` **deletes an entry when the same key is put twice** — `Lru::put` displaces on BOTH over-capacity and already-present, the `Option` says which is which nowhere, and the dual-eviction step removes the key just inserted. Capacity 8, one key: len 1 → **0**. The gate that covers this file has five cases, mutation-tests the eviction path, and writes every key exactly once. **F-084:** the capacity guard names the internal `:rust::` shim and leaks a Rust backtrace note |
| wat-grep (probes only) | 534 files, 137,690 nodes, 2 probes | `:wat::grep::` is the code-search engine the formatter is built on, and it appears in **no user-facing page**. **C-043:** both laws its own header declares hold exactly over this repository — `Span == Node` at 137,690 each with **0 violations**, `Node > Named` with 0 — and the `Written` predicate ("EXACT, not a heuristic", evidenced by wat-rs on 222 nodes) scales to 137,690: of 6,156 Named-without-Written nodes, **zero are Symbols**, and the 1,313 Keyword exclusions are exactly the four reader-synthesized names. It also reports the corpus's 2 unparseable files as `Unreadable` and returns everything else — the same input that makes `lint-source` raise and discard 531 files (F-078). **F-080:** `filterv` alone among nine core sequence verbs has no `PersistentVector` clause, and every vector in `grep::Facts` is one. **F-081:** 4,843 of the 6,156 exclusions (79%) are string literals — 0 of 80,027 `Written` facts is a `StringLit`, because a string's span covers its quotes — and the header explains the guard purely in terms of the reader. **F-082:** the header's pinned `wat/fix.wat Node=4316 Span=4316` measures 4929/4929 at HEAD, 14.2% stale after 18 days of file growth, beside an invariant that held exactly |
| The linter (probes only) | 99 stdlib + 256 self findings, 5 probes | `:wat::lint::` is a pure-wat linter with two form-level rules, and `lint-stdlib` is zero-argument. **Both rules are correct and precisely scoped** (C-041), verified with positive, negative and threshold cases — `concat-abuse` fires on interleaving and not on clean code; `nested-if-=-ladder` fires at 3 literals and not at 2, on strings and keywords, and correctly ignores value-returning chains because it is a membership rule. It flags its own file 6 times. **F-076:** all 99 stdlib findings are `concat-abuse`, each recommending `:wat::core::format` — which exists (`core.wat:1681`), works, and appears in **zero** user-facing docs. Two witnesses: the stdlib is flagged 99 times, and this repository holds 339 `string::concat` calls against 0 `format` calls, written by a model that never found it. **F-077:** `lint.wat` ships its ladder fix report-only because "ast-span returns ONLY the START … not possible with the current substrate primitives" — but `ast-end-span` exists, works, and is documented in that same file's own `FixEdit` record. **C-042:** pointed at this repository's own 530 programs it returns **256 findings, every one `concat-abuse`** — `nested-if-=-ladder` fires 0 times across 592 files from two independent authors, and 59 of the 256 carry a fix (23%, against the stdlib's 15%). **F-078:** getting that number at all needed a workaround — one file that does not lex makes `lint-source` raise and discard every finding from the other 531, and the raise names only `byte 258`, never the file. **F-079:** the third rule, `load-order`, is reachable only through `lint-stdlib`, which is hardcoded to wat's own sources; outside code gets 2 of 3 |
| The others | — | Friedman's two textbooks, *Essentials of Programming Languages* (with Wand) and *Scheme and the Art of Programming* (with Springer), are not queued. NEXT.md lists the acceptance tests that come after the books |

### Relay to wat-rs, by task

Every open finding, grouped by the kind of wat-rs task it would become. The two lists below
give each one's detail.
 · F-089 `--repl`, `--grep` and `--mcp` are named in the binary's own usage and in none of the four user-facing pages — and `wat --help` is read as a filename (exit 66), so the usage block is reachable only by running `wat` with no arguments at all |
| Task | Findings · **F-088 for `:wat::stream::`, `:wat::config::` and `:wat::list::` the documented API and the real one are DISJOINT — 9 documented stream verbs, none exist; 4 real ones, none documented; `:wat::list::` has no verbs at all** |
|---|--- · **F-083 re-putting a key into a `HolographicLru` DELETES it: `Lru::put`'s `Option` cannot distinguish an over-capacity eviction from an update, so the dual-eviction step removes the key just inserted — and the shipped `hologram-svc` inherits it** · **F-087 87 of the 203 verb names the user-facing docs teach are rejected by the compiler (68 unresolved, 19 explicitly retired), and 49 of 159 code blocks (30%) contain at least one — including §4's `define` section, the "slightly richer first program", and a reference table for six `:wat::stream::` verbs in a namespace that has four, none of them those** · F-089 a `--help` flag: the usage text already exists and is unreachable except by invoking `wat` bare |
| **Fix** (behaviour is wrong) | F-001 debug build panics · F-002 new test file never run · F-003 `wat.test/deftest` skipped · F-004 `()` in `wat.core/quote` refused · F-009 constructors fail at runtime · F-010 fn-typed param misread · F-012 `wat/load-file!` no-op · F-014 symbol-headed calls unchecked · F-016 flat `cond` crashes · F-017 `wat.core/match` arms misread · F-018 `wat.core/def u/x` defines nothing · F-021 `~@` of a vector form in a program body · F-022 `wat.core/defmacro` defines nothing · F-024 `wat.core/let` body checked without bindings · F-026 retired nested pattern passes · F-030 printing a newtype panics · F-031 `length` on a String passes the checker · F-038 a builtin verb as a function value passes the checker in two of three places · F-019 a variant keeps its narrowed type, so two values of one enum can't be compared with `=` · F-020 a unit variant isn't a value · F-029 a fn generic over a surface refuses the structs that implement it (hit in two books: ML functors, Java visitors) · F-039 an `extend-type` that leaves a feature out passes the checker; the call fails at runtime · F-041 `str` takes one argument, and more pass the checker · F-042 `#(…)` read as the symbol `#` · F-043 a map in call position passes the checker · F-044 a keyword lookup `(:k m)` isn't type-checked · F-045 `first` and `rest` die on an empty collection · F-048 a record's accessor binds a generic T to `:wat::core::Record` · F-050 end of input in the middle of a frame panics ("disconnected") · F-052 a function can't declare a connected peer as its return type · F-058 a `PersistentMap` constructor refuses a bracketed type that isn't a keyword, where its `HashMap` twin accepts the same nesting · F-059 a dotted pair reads as a three-element list with `.` as an ordinary symbol, then prints back as a dotted pair — so an improper list round-trips while meaning something else · **F-067 wat's rete disagrees with its own declared SPEC: a bare accumulator (`count`, `sum`) asserts its result over the empty first pass, so `fire-rules$oracle` and the public `fire-fixpoint` keep a stale `0` beside the right answer where `fire-rules` does not** · F-070 `wat/doctest.wat` guards neither its comparison nor its evaluations, so one bad example masks all 485 — and the guard it needs (`:wat::test::run-thread`) is already loaded at that point (test.wat #34, doctest.wat #38) · **F-078 one unlexable file makes `lint-source` raise and discard every finding from every other file in the batch — 531 good files lost to one negative probe** · **F-080 `:wat::core::filterv` has no `PersistentVector` clause, where its eight sibling sequence verbs all do — so the fact base `:wat::grep::` produces cannot be filtered with the obvious verb** · F-084 the cache's capacity guard names the internal `:rust::cache::Lru::new` rather than the `:wat::cache::Lru::new` that was called, and leaks a raw Rust panic plus `RUST_BACKTRACE` note to stderr even when recovered (C-037's family, third witness) · **F-085 `USER-GUIDE.md`'s uuid backward-compat note is wrong about 3 of the 4 spellings it names — it MANDATES `Uuid/v4`, which the checker refuses, and promises `:wat::telemetry::uuid::v4` "still works" when it does not exist** · F-086 telemetry's three headers document a primed namespace `:wat::telemetry'` that appears 14 times in comments and 0 times in code, including a `~@:wat::telemetry'::Scope` sample that would not parse · F-088 `:wat::stream::collect` — the documented way back from a `Stream` to a vector, which does not exist, leaving `filterv`'s refusal (F-080) with no exit (P-025) · **F-090 a well-typed program crashes: `:wat::rational::+` declares `-> :wat::core::rational` and returns a `bigint` when the result reduces to a whole number — the code comment calls it "this stone's pinned collapse" — and `to-f64`, alone among the five verbs, was never made lenient enough to absorb it** · **F-092 `fix-text`, wat's own wat-to-wat codemod ("THE PROVING POINT: wat writes wat"), breaks 9 of 16 independent green programs — 8 of them no longer start — in four distinct ways, including converting `:wat::WatAST` into `wat/WatAST` when no symbol spelling of `WatAST` resolves at all** · **F-093 a wrongly-typed argument at a Clojure-spelled call is not checked: a function declared `i64 -> i64` accepts a String, returns it and exits 0 — and the codemod's whole job is to move call heads into that spelling (F-014's consequence)** |
| **Correct** (a diagnostic misleads or points the wrong way) | F-006/F-008 errors located in wat-rs's Rust or stdlib source (again: `src/check.rs:15104`, `wat/core.wat:66`) · F-007 unknown bare call name caught only at runtime · F-011 `<WatAST>` shown for both values · F-015 docstring refusal reported at the call · F-025 the non-exhaustive error suggests `_` · F-034 an f64 prints without its decimal point · F-037 an undefined function reported as a missing struct field · F-054 a definition naming itself is reported as a keyword's type error · F-040 a defstruct in a Pure enum: the containment error offers only `:wat::enum::Impure`, never `defrecord`, and is located in `src/check.rs` · the Peer `:messages` hint names `defrecord` for an enum · the "malformed form" label on `first` and `rest` of an empty collection (F-045) · F-058's refusal carries `:remedies []`, though the remedy is a single typealias · F-068 nothing says that a sqlite transaction is abandoned by passing `"ROLLBACK"` to `execute`, since the surface lists no `rollback` · C-037 the read-only write refusal names the internal `:rust::sqlite::ReadConnection` rather than the user-facing `:wat::sqlite::ReadConnection` (the F-006/F-008 family) · **F-071 the match-arm refusal says "write `<enum>::<Variant>`" — the exact spelling it just refused; the accepted form is `<enum>.<Variant>`, and its bare-variant sibling names the dot form correctly** · **F-073 `coincident?` is documented as "cosine clears the floor" and implemented as `(1 - cosine) < floor` — the opposite test, so a floor of 0.01 reads as permissive when it admits only near-identity** · F-077 `lint.wat`'s header blocks its own auto-fix on `ast-span` having no end location, while the same file's `FixEdit` record uses `ast-end-span` — which exists and works · F-078's raise says only `lex error at byte 258` and locates itself at `wat/lint.wat:586`; `source::File` carries the `:path` and `lint-file` holds the record, but the error drops it, so the offending file must be found by grepping the corpus outside wat · **F-091 a lex error names no file, no line and no column — only a byte offset — and locates itself inside `crates/wat-reader/src/parser.rs`, where every other diagnostic class carries `{:file :line :col :end}`. This is why F-078 needed a 532-file grep outside wat** |
| **Clean** (docs behind the code) | the docs never map Clojure's `defprotocol`/`extend-protocol` to `defsurface`/`extend-type` (`CLOJURE-ROSETTA.md` has neither) · the user guide's retired verb names (`:wat::core::f64::to-string`, `:wat::std::math::exp`, `:wat::core::i64::to-f64`, the `log` alias) · the cheatsheet's `first` returning an Option · no top-level doc mentions `defstruct`, or says that a `defrecord` may cross a boundary and a `defstruct` may not (F-040) · the user guide's first stdin program (§2) is refused as written · a Clojure-name to wat-route table for the koans' missing names (`vals` → `:wat::hashmap::values`, `pr-str` → `:wat::edn::write`, `atom` → a service …) · F-063 nothing says that `Result/try` propagates rather than catches, or that the only general catch is `:wat::test::run-thread` · **F-065 the rete — 134 verbs, 4154 lines, `defrule`, `defquery`, negation, existence, nine accumulators — appears in no user-facing page at all** · F-066 nothing says whether a rete closure is a set of facts or a bag of derivations, and the two count differently · F-068 a `rollback` verb: `:wat::sqlite::` has `begin` and `commit` and no way to spell the third, on a surface closed to additions · **F-070 67 of wat's own `@example` lines are written in spellings two completed migrations retired — 44 use the bare `(Vector 1 2)` constructor, 23 use `Enum::Variant` arms or a bare `:None`. The examples are the documentation, and this is a codemod rather than a judgement call** · F-072 nothing says that `bind` is its own inverse, that the inverse is lossy at ~0.82 a round, that the loss compounds, or that recovery is by nearest neighbour rather than reconstruction · **F-076 `:wat::core::format` — the idiom the linter recommends 99 times against wat's own stdlib — appears in no user-facing page; this repository wrote 339 `string::concat` calls and 0 `format` calls for want of it** · F-081 the `Written` guard's stated rationale covers 21% of what it excludes: 4,843 of 6,156 exclusions are string literals, and 0 of 80,027 `Written` facts are one, which the header never says · F-082 `grep.wat`'s header pins `wat/fix.wat Node=4316 Span=4316` beside a permanent invariant; the invariant held exactly and the number is 14.2% stale after 18 days of the file growing · **`:wat::grep::` — 489 lines, 13 verbs, the engine the formatter is built on — appears in no user-facing page (the F-065 shape)** · `:wat::rational::` — five verbs and a reader literal of its own — is named zero times across all four user-facing pages (C-047) · `:wat::runtime::argv` is `[binary script …user args]` and is named zero times in any user-facing page, though the CLI usage advertises `wat <entry.wat> [args…]` |
| **Improve** (works, but slowly or narrowly) | F-057 `HashMap` and `HashSet` copy on every insert where `PersistentMap` shares (10× at 4000 entries, and widening), and nothing points the user to the sharing one — a 90000-square search takes 135 s on the copying containers and 20.6 s on the sharing ones, for a dozen lines of change · F-055 `rest` on a Vector clones it, so walking one is quadratic where `nth` is constant · F-023 `conj` clones a Vector · F-027/F-028 no tuple patterns, and nested arms never cover a variant · F-033 taking a WatAST apart copies every subtree · a Peer surface must declare every datatype its messages carry, so one datatype shared by two services is restated in each (Friction, A Little Java ch 10) · `take-nth` takes its count first, `take`/`drop` the collection · `cond` refused in a macro body where `if` is allowed · F-051 a message to a service costs about 224 µs, a hundred function calls, so a mal call on a service-held environment costs 3 ms · the interpreter's speed: 100 to 430 times the JVM (miniKanren), 13 times guile (J-Bob), over 100 times Racket (malt) · F-077 with `ast-end-span` available, `lint.wat`'s ladder auto-fix is unblocked — 84 of its 99 findings currently carry no fix · **F-069 a service consumer writes more outcome arms than logic — 56 of 182 lines, and wat-rs's own fixture lands at the same 182 with a 529-character `connect` line; there is no way to say "every other outcome is a failure" once** · F-075 the formatter runs at ~10 KB/s with an ~800 ms fixed floor per invocation (23 s for a 231 KB file); the floor is the rete network rebuilt from 54 rules every time, and caching it across formats would pay it once per process |
| **Extend** (missing) | F-005 no symbol spelling for types outside `wat::core` · F-013 `#_` · F-032 `λ Π Σ →` in symbols · F-035 bit operations · F-036 random numbers · the Clojure core names the koans reach for and wat lacks (`inc`, `dec`, `even?`, `comp`, `partial`, `list`, `merge`, `for`, `group-by`, `partition`, `case`, set operations …; the Clojure Koans table) · `first`/`rest` total, like `last` (F-045) · F-046 enumerate a HashSet · F-047 an orderable bigint · F-056 a priority queue, or any ordered collection · F-049 a raw write to stdout (a prompt, plain text) · F-050 a plain `read-line` · F-053 a stream that remembers what it forced · F-054 a definition that can name itself · a String's `reverse`, `index-of` and characters · a persistent **set**: `PersistentVector` and `PersistentMap` share structure, but a sharing set is missing, so a visited set has to be a `PersistentMap` to `true` (F-057) · an improper list, or a reader that says no at the dot rather than admitting a symbol named `.` into a list (F-059) · F-060 a bigint's `to-string`, where every other scalar has one · F-061 a regex that can report what it matched (`find`, `captures`, `replace`, split-on-pattern) — the crate is already a dependency, only `matches?` is exposed · F-062 a String's characters, `index-of`, `replace`, `split-lines`, `blank?` and `reverse`; and `split` on `""` · F-063 a catch that doesn't spawn a thread — recovery costs 1.3 ms and lives in `:wat::test::` · F-064 a stream that remembers a failure, not only a value (F-053) · F-069 whatever would let a `start`+`connect` be factored into a function, since the spawn scope law (F-052) forces every dial to be written inline · F-074 let `presence?` take a raw `Vector`, as `cosine`, `dot` and `coincident?` already do — the raw algebra's own output cannot be handed to it · PROVIDE.md's P-001–P-025 · **F-079 a `lint-files` that runs all three rules over a caller's sources: `lint-stdlib` is hardcoded to `deporder::stdlib-sources`, so outside code gets 2 of 3 from `lint-source`, and rule-zero must be reassembled from `deporder::verify` + `violations->findings` by hand** · F-081 a fact carrying a string literal's INNER span, since `Written` can never hold one and a rewriting rule over string contents is therefore impossible |

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
    Every other scalar has one: `:wat::i64::to-string`, `:wat::f64::to-string`.
  - The whole registered bigint surface is six verbs (`src/intrinsic/bigint.rs`):
    `+`, `-`, `*`, `/`, `to-f64`, `to-rational`. There is no comparison (F-047) and no modulo.
  - `:wat::bigint::to-f64` reaches a String only by losing the number:
    `probes/euler/bigint-surface.wat` renders 2^1000 through f64 as 17 significant digits
    followed by 285 zeroes.
  - `:wat::edn::write` does answer the digits — 2^1000 comes back in full — but as **303**
    characters whose last is `N`, so `length` is digits + 1 and a caller must strip the suffix.
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

### F-087: 87 of the 203 verb names the user-facing docs teach are rejected by the compiler

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

  **87 of 203 — 43% — of the distinct verbs these documents name do not work.**
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

  | namespace | verbs the docs name | of those, that exist | verbs that exist | of those, documented |
  |---|---|---|---|---|
  | `:wat::stream::` | 9 | **0** | 4 | **0** |
  | `:wat::config::` | 7 | **0** | 1 | **0** |
  | `:wat::list::` | 2 | **0** | **0** | — |

  The documented stream API and the actual stream API do not share a single verb. The docs
  name `map`, `filter`, `inspect`, `take`, `collect`, `fold`, `chunks`, `flat-map`, `for-each`,
  `spawn-producer`, `from-receiver`, `with-state`; the substrate has `cons`, `empty`, `lazy`,
  `next`. `:wat::list::` has no verbs at all — the namespace is entirely fictional.
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
