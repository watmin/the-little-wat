# After Friedman: more acceptance tests

Queued for once the Friedman books are exhausted. Each one tests wat against something
with a known right answer, and each leans on a different part of the language. The same
rules apply as for the books: every gap goes into FINDINGS.md with a repro, and code is our
own, not copied from the sources.

Ordered by how directly each tests what wat claims to be.

## elf/ — the live queue (2026-09-24, HEAD a0830a6)

**This section is a MAP, not the truth.** The truth is `FINDINGS.md` and the git log; every line
below names where to read and is deliberately too short to stand in for the reading. If it ever
grows long enough to feel like sufficient orientation, prune it — that feeling is the failure.

**Freshness probe:** written against **`21c737d`**. `git diff --stat 21c737d HEAD -- elf/compile.wat
elf/lib tools` must print NOTHING -- the compiler and its tools are as this map describes. If it prints anything else this map is stale: trust the git log and `FINDINGS.md` over every
line below, and read the newest entries before you move.

### NEXT STRIKE — closures' stone 2 (excursus 003), with Grok

**Read `docs/excursus/2026/09/003-closures/DESIGN.md` first** -- three stones: whole function types
(F-202), one closure representation for every function value, then the `fn` form by closure
conversion at the front of the pipeline. Then `002-no-guesses/` for the typer and the gates.

**On waking:** 003 stone 2 (every function value is a closure object; the gate sees indirect-call
arguments) is with Grok in THIS repo. wat-rs `the-little-wat` is at `4f6ebcf12`, its floor's only reds
F-197's two lints. Read `/home/watmin/Work/holon/.pulsare/to-claude`; on `kind=scored` weigh stone 2
against its EXPECTATIONS on your own runs, then draw stone 3 (the `fn` form) -- its disconfirming
probe (capture types recorded at the site, read by the lifted body) comes BEFORE its brief.

**Where it stands (2026-09-24).** The compiler's typer is ONE derivation, total: every guess is a
compile-time refusal. Two rete gates -- self-agreement and agreement with wat's checker -- run in
`elf-run`, read ZERO, and FAIL the build on any conflict. F-194, F-195, F-196 and F-199 are closed.

**Next, in order:**
1. **DONE — stone 5, variant types (D9 closed).** The compiler knows `Opt.Some`/`Opt.None` as types,
   enforces Liskov itself, and a unit variant's `T` is fixed by its use. `refined 0`.
1b. **DONE — stone 5b, `{:keys […]}` destructuring** of a variant or record; the parent refused. First
   strike by Grok via pulsare.
1c. **DONE — stone 6, the count guard per variant**, -5.558% instructions (cycles inside the floor).
   Refuted once: it exposed **F-200** (an enum over an enum laid out as its payload, `Some(None)`
   read as `None`), fixed at the root in `:c::enum-tier`. Lesson: check a derivation row against a
   payload of EVERY kind the tier admits, including another enum.
2. **Closures** -- the builder's goal, excursus 003. Stone 1 DONE (whole function types, F-202);
   stones 2 and 3 are drawn in its DESIGN; stone 3 needs its disconfirming probe (capture types). Fixtures with known interpreter
   answers are `probes/closure-captures.wat` (126, 86: capture of a value, of a function, of a
   closure) and `probes/closure-nested.wat` (16, 27: closures returned from functions, composed).
   The native compiler refuses `fn` today. A capture is a STORE into a container -- the F-188 class -- so
   the ownership count and both gates must cover it.
2a. **DONE — excursus 004, `eval-step!` steps what `eval` runs (F-204, F-198)** (wat-rs `4f6ebcf12`). It stepped
   no user code at all: every user function refused, every symbol head refused, a `let`-bound `fn`
   never ending. The builder: *"let's get this fixed - we have a strong habit of fixing what's broken
   when we encounter it"*. Grok builds wat-rs in its OWN target dir until 003 stone 1 is weighed.
2a'. **DONE — excursus 005, the compiler's reader is total (F-205).** Five standing refusals.
2a''. **DONE — excursus 006, a macro says what it returns (F-206)** (wat-rs `365ebc014`). NEXT: rebase the
   parked `the-little-wat-004-eval-step` onto it (its renderer already landed here) and finish 004. The
   builder's four-questions ruling: candidate E. `CRAWL.md` sized it: one declaration changes; the
   real work is type-checking macro bodies at all. 004's stepping is credited and waits on it.
2a'''. **DONE — excursus 007: `to-string` is the written form; `name` is the name (F-207)** (wat-rs `40ddeac4d`). The builder
   accepted the four-YES derivation. 006's re-strike (70 stdlib errors, five classes; 17 of them want
   `name`) and then 004's stepping follow, each parked on its own pushed wat-rs branch meanwhile.
2b. **Then persistent collections, excursus 008** -- the builder's ruling (2026-09-24): *"in our
   compiler - all of the collections must be persistent - the only thing that differs between our
   compiler and wat-rs runtime would be perf -- we'll deal with this once we have closures"*. The
   compiled Vector included; model wat-rs's `PVec`/`PMap` (array, then an rpds trie, promotion
   unobservable). **One excursus with memory**: the builder's ask was never built -- *"grow and
   shrink as we need ... we always know when and how much memory we need - just like in rust -
   without any form of a GC"*. The heap is still a fixed 1.9 GB mmap that ABORTS when full
   (`runtime.wat:984`), a runtime panic totality forbids. 001's DESIGN narrowed the ask ("page
   release is cosmetic", no growth) without saying so. Scope: a count that comes DOWN and an inline
   drop (rpds is `Arc`: the same mechanism), an allocator that reuses holes, grow/shrink with the
   OS, exhaustion as a matchable error.
3. Inside that excursus: stone 1 of excursus 001 (caller-side release, branch `excursus-001-stone-1`): it needs a
   rebase onto this typer, an `allocates?` gate, and a real §7 gate before it is struck.

**Open, recorded:** F-201 (a variant as a type argument, `Opt.Some<Color.Red>`, refused where
`Opt<Color>` is wanted -- a valid program, not traced) · F-007 (bare unknown heads pass `--check`) · F-191 (a valid program segfaults, not
yet traced) · F-197 (the wat-rs floor's pre-existing reds) · F-198 (`eval-step!`: namespaced quoted
heads; an empty capture called a closure — four-questions answer: "a captured environment that binds
nothing is not a closure") · the two wat-rs step tests stone 3 left red, for the builder. The wat-rs branch
`the-little-wat` is PUSHED after every commit (the builder, 2026-09-25: GitHub is the DR site).

### LANDED since this section last read "next" (2026-09-23)

C-206/C-207 (frame fix + tier-1 alias), C-210 (share elision), **C-211 (the register convention,
-11.4%)** -- cumulative `optm` **780,000,354 -> 620,902,187, -20.5%**. F-184 repaired
`elf/bench/opt.c`, which had been measuring gcc's constant propagation rather than the enum
representation: the honest gcc -O2 figure is 321,835,409 (1.93x ahead of us), not 220,528,567
(2.82x). Cross-language instruction counts are USER-MODE counts -- our 1.9 GB heap mmap faults in
~15.8M kernel instructions that C never pays, and that constant stops cancelling the moment C is
on the other side of the ratio.

**THE TOOLCHAIN MOVED.** `elf/` now measures against wat-rs branch **`the-little-wat`** (commit
`7dee55858`), not `main` — it carries clj's seven bitwise ops, which C-171 needed and which do not
exist on main. `run.sh` prints the rev it ran against; if it says something other than a
`the-little-wat` commit, the bit-op programs will not load. The branch is **strictly additive**
by rule, so every finding written before it stays valid. If `git log --oneline -1` says
something else, trust the log and `FINDINGS.md` over every line here, and re-read the newest
entries before moving.

### — DATED HISTORY below this line (2026-09-20/21). Context, not the queue. —

### Where we stand — FOUR opponents, every run pinned (2026-09-21)

Run `tools/vs-c.sh`. It builds `gcc -O0`, `gcc -O2`, `clang -O0`, `clang -O2` for every section
(F-146) and pins every timed run (F-149) — unpinned, this hybrid CPU times two programs in
different frequency domains and the board measures the scheduler. Wall-clock across two board
RUNS is not comparable at all: gcc's own `triple` read 68 ms and 101 ms on one thermally loaded
afternoon with no code change.

| | ours | best C | shape |
|---|---|---|---|
| size, a program that prints 4 | 600 B | 856 KB static / 968 B free-standing | we win |
| startup, 500 runs | 472 ms | 607 (gcc -O0) | we win, all four |
| buffered output, 100k integers | 7 ms | 11 (clang -O0) | we win, all four |
| `loopsum` — latency-bound loop | 145 ms | 173 (gcc -O2) | we win, all four |
| **strings, BUILDING 5M appends** | **25 ms** | 26 (clang -O0), 31 (gcc -O2) | **we win, all four** (C-182) |
| strings, SCANNING 194 KB | 5 ms | 3 (clang -O2) | slightly behind |
| tail calls, 1M deep | constant stack | not guaranteed | tie/win |
| `triple` — throughput-bound | 93 ms | 63 (clang -O2) | behind — see F-155/F-157 |
| `fib32` — call-heavy | 14 ms | 10 (gcc -O2); **clang -O2 is 16** | behind gcc only (F-132/F-133) |
| **records, 2M field updates** | 11 ms | 3 (clang -O2) | behind — F-158 |

**Strings crossed over.** C-182 found `rep movsb` copying ONE byte and put a `cmp $1 / jne`
ahead of it: 15.5 cyc/append to 6.03, from 1.89x behind to ahead of all four. It ADDED two
instructions. Read F-147.

**`triple` has had six measured attempts and no win** (F-151, F-153, F-155, F-156, F-157). We
issue 20 uops to gcc's 15 while retiring a slightly HIGHER fraction of issue slots. Three of the
five extra are overflow checks on the accumulator adds; two are a separate induction variable.

**Records: `rec` 6.0–6.4 cyc/it, `recflat` (same loop, accumulator in a register) 1.50.** Two
measured endpoints, nothing claimed between them — F-158 retired the derivation that used to sit
there.

### The three rules the measurements have settled

1. **The binding constraint depends on the SHAPE of the code** (C-153, C-164). Latency-bound
   loops hide our extra instructions; throughput-bound ones do not; call-heavy code is bound by
   neither.
2. **On front-end-bound code the unit of cost is a TAKEN BRANCH, not an instruction** (C-167).
   Nine `fib` experiments removed work and were paid nothing; the two that removed control flow
   were paid in full — shrink-wrapping -11.2%, the `jcc`+`jmp` collapse **-22.1% for -4.6%
   instructions**.
3. **An optimisation that is free in C may be illegal for us, because our arithmetic traps**
   (F-131, F-132). Strength reduction swaps an `imul` for a `sub` and gcc owes nothing while we
   still owe the `jo`; reassociating a sum is what gives `gcc -O2` its `fib`, and trapping
   forbids it outright. **When a C compiler is ahead, check what semantics bought it** before
   treating the gap as our defect.

### The compiler is three files now (C-174)

`elf/compile.wat` 4,055 · `elf/lib/x86.wat` 498 · `elf/lib/runtime.wat` 637. Cut where `partire`
found the seams, not by size. **Read the module you need, not the file**: an instruction or an
addressing mode is `lib/x86.wat`; a support routine or a heap layout is `lib/runtime.wat`;
everything about the wat dialect is `compile.wat`. Neither lower module names `:c::Prog`,
`:c::Env`, `:c::Out`, `:c::Kids` or `:c::Bnd` — that grep returning 0 is what makes the seam real,
so keep it at 0.

### In flight (2026-09-21)

**Eight codegen changes landed, two reverted, and the reverts are the finding.** C-177 (tail
argument already in place), C-178 (literal operand straight to rcx — sped the compiler up on
ITSELF), C-179 (assoc receiver rematerialised), C-180 (counter step in its own register), C-181
(register-vs-register compare), C-182 (**the one real win**), C-183 (field read from a register),
C-188 (the back edge tests for itself). Reverted after measurement: C-185/C-187 (cmov, now
settled three times over — F-153), C-189 (binding into its destination's register — F-156).

**Three oracles were not checking what their names said.** `tools/emitted.sh` is NEW: nothing
compared a build against the PREVIOUS build, so a refactor claiming purity had no oracle at all —
`bootstrap.sh`'s "74 binaries byte-identical" compares the compiler against ITSELF. The refusal
fixtures had drifted seven changes while still passing (F-152); `bootstrap.sh` regenerates them
now. And `vs-c.sh` did not pin (F-149).

**A latent bug shipped inside a green commit.** C-186 took a frame displacement from the Out
BEFORE the initialiser instead of after; every gate passed because initialisers usually balance
their own pushes. Found by reading the diff for intent, not by any check.

### The measurement hierarchy, learned the expensive way (2026-09-21)

Read F-154, F-157, F-158 before trusting any number in this repo.

1. **uops and the retiring fraction** — stable to 1% across a thermally loaded afternoon.
2. **cycles, pinned, same binary, repeated** — good.
3. **cycles across two BUILDS** — only for effects above ~25%; three of today's mistakes lived here.
4. **wall-clock within one board run** — ratios only.
5. **wall-clock across board runs** — not comparable. gcc's own number moved 48%.
6. **synthetic shape microbenchmarks** — ±50% from code layout. Useless below ~25% (F-154).

**And `cycles = uops / (6 × retiring%)` is `slots / 6` rewritten** — an identity, not a model
(F-157). It equals the cycles counter only when `slots/cycles` is 6, which is a property of the
run, not the program. Report uops, retiring slots, slots and cycles separately; say so when
`slots/cycles` is not 6.

**Every wrong claim this session had the same shape:** a real dependence or a real counter, then
a quantity derived by a subtraction or division never performed. Three reached a committed record
because nothing stood between the strike and the commit. A peer (grok, via `pulsare`) struck all
three, plus one over-correction where the retraction went further than the evidence.

### Next: strings and records must be shown sound, then the REPL

The builder's ordering (2026-09-20): *"repl is our target after we know strings and records are
sound -- we are clear out the hex literals to get our maintainability better before we work on
capability and then our first real app"*.

**RECORDS ARE MEASURED NOW, AND THEY ARE THE GAP (F-140).** `assoc` allocates a new record and
copies every field -- always. Strings and Vectors each have a last-use ownership path from
F-127/C-151 (`str_cat_own`, `vec_conj_own`); records have none, and nothing had recorded the
omission.

  rec.wat (record assoc)     158.90 ms
  recflat.wat (bare i64)       8.31 ms      <- the identical loop, nothing allocated
  rec.c (gcc -O2)              5.29 ms

**19.1x, and it is the MEMORY not the instructions**: the instruction count only doubles, but
2M records at 48 bytes is 91 MB of fresh heap streamed through the cache to carry one changing
integer -- 501 page faults against 2.

**The fix is `slot_set_own`**, chosen by the same `own?` flag the `concat` and `conj` paths
already thread (`elf/compile.wat:1370`, `:1804`). The last-use analysis exists; `assoc` was never
wired to it. **The compiler would be its own first beneficiary** -- `:c::emit` is
`(assoc (assoc o :code ...) ...)` on the `:c::Out` record, once per instruction emitted.

**AND THE ANALYSIS ITSELF IS THE DEEPER GAP (F-141).** `str_cat_own` fires and is the difference
between linear and quadratic -- but `:c::linear?` decides ownership by COUNTING MENTIONS
(`:c::occ-sum`, at most one), not by asking whether a use is the LAST one in evaluation order.

  strbuild.wat   (acc mentioned once)   200000 in 19 ms; 3,200,000 in 46 ms, linear
  strbuild2.wat  (mentioned twice)      HEAP EXHAUSTED at 200000; quadratic

The second mention is a read that happens BEFORE the write and cannot observe it. One harmless
extra read changes the complexity class.

**So F-140 and F-141 are ONE piece of work.** Wiring `assoc` to the existing `own?` would hand
records a path that the natural idiom cannot reach, because
`(assoc s :a (+ (St/a s) i))` mentions `s` twice. Give records a path AND make the test a
liveness question -- "is this the last use, in evaluation order" -- or neither pays.

The analysis is SOUND (it never wrongly permits a mutation), which is why both are Improve and
not Fix. It is sufficient where it should be necessary-and-sufficient.

### The next objective is a REPL, not an XDP driver (2026-09-20, the builder's call)

**"getting an actual repl (after all the hex clean up) is the better proof of competence"** --
and wat-rs's own REPL is judged poor, so this is a chance to do it properly rather than port one.

**`mal/` is the ladder and the oracle, not the goal.** Eleven steps, 909 of mal's own tests green
under the interpreter. But `mal/step0_repl.wat` says in its own header that it is NOT a terminal:
*"A wat program can't print raw text or a prompt, and can't read an unbalanced line alone
(F-049, F-050), so the shim is the terminal"* -- it is driven by `tools/mal-shim.py`.

**The compiler accepts none of mal's vocabulary.** Measured against `stepA_mal.wat`:
`match` (117 uses), `defenum`, `fn`, `rest`/`first`/`second`/`third`, `empty?`, `concat`, `into`,
`mapv`, `hashmap/assoc` -- zero compile today. So the target is `step0`, then `step1`, each with
mal's own tests as the check; `stepA` is far off.

**What a native REPL actually needs, and all of it is ours:**

| piece | state |
|---|---|
| **read** — text to AST | **DONE.** `elf/lib/reader.wat` already compiles; it is part of the compiler |
| **input** — a line from stdin | missing: `read(0, ...)`, one syscall. The runtime has `read-file` only |
| **print** — raw text | missing: `print_str` QUOTES and ESCAPES (EDN rendering), so it cannot emit a prompt |
| **eval** | the work |

`eval` has two shapes: an AST interpreter in wat (sane, incremental, mal steps 2+ over the
reader we already have), or -- since the stub already `mmap`s and we already emit machine code --
compiling each form into an exec page and jumping to it. The second is the better stunt and the
same compiler either way.

**Do it after the hex conversion**, because `print_str` and `buf_put` are exactly the routines
being converted and should change once, in expression form.

### Anonymous `fn` — needed soon, and the cheap version is the wrong one

The builder's call (2026-09-20): *"we'll need anon fn as we mature the lang... its acceptable to
skip it now.. but we'll need it soon"*. The demand is named: `mal/stepA_mal.wat` uses `fn` twelve
times, and a REPL's `eval` is closures by nature.

**When it is built, build CLOSURES, not lambda lifting.** The four questions on the cheap version
(lift a `fn` with no free variables to a top-level `defn`, refuse the rest) came out
Obvious YES / Simple YES / Honest YES / **UX NO** -- a form that compiles until you happen to
reference an outer binding is F-129's inline cliff again: behaviour turning on a property that is
invisible in the source. There is no cheap version worth shipping.

What the real one needs: a closure VALUE (code pointer plus captured environment -- `vec_new`
already allocates), an INDIRECT call (`call *%rax`; the compiler emits direct `rel32` only),
the function type as a value type in the type pass, and a decision about how last-use ownership
(C-151/F-127) interacts with a captured binding.

**The type is spelled `[ArgType... :-> RetType]`, and this document had it wrong.** It said
`:fn(A,B)->R`, which is the pre-arc-109 spelling that arc 155 retired -- implementing it would
have aimed the parser at a form wat does not have. Verified against `wat-rs/src/types.rs:4897`,
which matches the keyword `:->`; the zero-ary form is `[:-> R]` (`types.rs:164`). Note `:-` and
`:->` are DIFFERENT tokens: `:-` separates parametric arguments, as in
`(:wat::core::Vector :- [T])`; `:->` is the function arrow.

```clojure
[:-> U]              ;; 0-ary
[T :-> U]            ;; 1-ary
[K V :-> U]          ;; 2-ary
[A B C D E :-> Z]    ;; 5-ary
```

**Closures are NOT the fix for the walk duplication, and that framing was wrong too.** The
composition failure F-169 measures has two layers. Layer A -- the tail-position rule
re-derived by hand in nine walks -- is the RELIABILITY problem, it is what produced F-168, and
it needs no new language feature: one shared structural query plus the polarity audit. Layer B
-- the recursion-and-combine skeleton duplicated nine times, 23 functions -- is the bulk
problem, and that one does need closures, because the walks genuinely differ in how they
combine (`occ` maxes `if`-arms, `use-union` unions them). Build closures for the REPL and
`mal`, which are their own justification; take Layer B as the bonus that follows.

Small and separate: the refusal says `cannot compile call: (wat.core/fn ...)`. A `fn` is not a
call. The compiler has a good named refusal for top-level forms and wants one here (F-128's family).

### Open — correctness

* **Two `defn`s may share a name.** `:c::buf-len` was defined twice (the compiler's own output
  buffer, and a new runtime header offset) and nothing objected until a CALL SITE tripped on the
  arity: `cannot compile wrong number of arguments: (:c::buf-len)`. Whether wat-rs's checker
  catches a duplicate top-level `defn` at all is **unprobed** — worth a probe, because the failure
  currently surfaces arbitrarily far from the cause.

* **`999999` as "name not found"** and the **`"vec:"`/`"rec:"` string-tagged type encoding**
  (C-139). A magic number where an `Option` belongs, and a record wearing a string. C-170 declined
  to repeat the pattern — its "unknown" is the lattice top, not a sentinel — so the shape of the
  fix is now demonstrated in the same file.

### The strategy, after F-132 and F-133

**Against `gcc -O2` we already win three of six**: size 0.63x, buffered output 0.47x, `loopsum`
0.72x. We lose two, and both losses have a named cause that is **semantic, not a defect**: the
surviving overflow checks (`triple`) and the calls that reassociation would remove (`fib`).

So superiority is not forced by re-fighting `gcc -O2` on transforms our contract forbids. It is
forced on **the levers that are ours and not gcc's**:

  * **whole-program, no ABI, no separate compilation** — our calling convention, register
    allocation and layout are decided with the entire program in hand;
  * **we emit the ELF ourselves** — no assembler and no linker, so code placement and alignment
    are ours to choose, and F-132 measured that placement is worth up to 25% on an *identical*
    instruction stream;
  * **no libc** — 70 bytes of runtime against glibc, which is where size and I/O are already won;
  * **stronger semantics give us facts** — C-170 elides checks using bounds a C compiler has no
    reason to compute.

**And the untested ground is where the goal actually lives.** All six benchmarks are arithmetic
micro-loops. Nothing has measured wat against C on strings, records, memory traffic or syscalls —
which is what an XDP driver is made of, and where a 70-byte runtime and no libc should tell most.
**Breadth on realistic shapes is the next move, not another peephole on fib.**

### Open — performance, with what each is worth

* ~~**strings**~~ **CLOSED 2026-09-21, C-182 — we beat all four C builds.** `rep movsb` was
  copying ONE byte; a `cmp $1 / jne` ahead of it took an append from 15.5 cyc to 6.03. The fix
  ADDED two instructions, which is why five attempts at removing instructions had bought nothing.
  Read F-147 before optimising anything else.
* **records — 11 ms against `clang -O2`'s 3.** The dependence is a loop-carried store and reload
  of one qword: `slot_set_own` writes `[rax+8]` one instruction before `ret`, the next iteration
  loads `[rbx+8]`, and that value is the next call's argument. `rec1` stores without reloading.
  **Endpoints, measured, nothing in between:** `rec` 6.0–6.4 cyc/it, `recflat` (same loop,
  accumulator in a register) 1.50. F-158 retired the five-cycle figure that used to sit here and
  the IPC split that produced it. Closing it means keeping the field in a register, which F-150
  disqualified as a peephole — parameters take registers by POSITION, so a four-parameter
  function has none spare and record speed would depend on the arity of its enclosing function.
  **A register allocator is the prerequisite, not the follow-up.**
* **`triple` — six measured attempts, no win** (F-151, F-153, F-155, F-156, F-157). 20 uops to
  gcc's 15, at a slightly HIGHER retiring fraction. Three of the five extra uops are the
  accumulator overflow checks; two are the separate induction variable. **cmov is settled three
  times now** — C-169, then C-185 and C-187 today, each rebuilt in ignorance of the last: the
  select is NINE uops either way, so it was never a saving, and it costs the `cmp`/`jcc`
  macro-fusion. The comment above `:c::sel-ok?` says so; read it before touching that function.
* **`triple`'s three surviving `+` checks.** F-130 prices all overflow checks at 32% of that loop;
  C-170 took the four an interval analysis can reach. The remaining three are **unreachable by
  intervals** — the accumulators climb 89M an iteration and never converge (probe in C-170).
  Closing them needs a different instrument (summing the progression). **Nothing in the corpus
  asks for that yet, so it is named, not queued.**
* ~~**`fib` at 1.50x**~~ **CLOSED 2026-09-20, F-132 — it was never the holdout.** `fib` runs at
  **~0.40 taken branches per cycle whoever compiles it** (five builds, ours and gcc's, all on the
  line), and our 1.47x more taken branches IS the 1.50x cycle gap. Of our 6.10M taken branches,
  **3.5M are one per leaf and irreducible** (fib(32) has fib(33) = 3,524,578 leaves); the other
  2.60M are `call`+`ret`. So the only compressible quantity is the call count, and the transform
  that would cut it — reassociating the sum — **is illegal under trapping arithmetic**. Deeper
  inlining is measured and priced: depth 6 is -5.2% cycles for **3.5x the code** and **+22%
  compiler time**, which fails the UX question. Depth 4 stays. **F-133 then computed the floor:
  the 3,524,578 leaf tests are irreducible, so even with ZERO calls the best possible is
  8,687,816 cycles = **0.88x gcc** — the entire headroom on this program is twelve percent, and
  `gcc -O2` is already sitting on it. Call-site base-case peeling was priced too: it halves the
  calls exactly and is still only **-4.9% for +52% code**, because the peel test is itself a
  taken branch. `fib` is CLOSED as a performance item — finished, not hard.
* **F-129, the inline cliff.** `:c::inl-limit` counts SOURCE NODES, so naming an intermediate
  (30 nodes -> 35, limit 34) costs **2.26x cycles**. Raising the limit is not the fix — the corpus
  at 60 grows five programs by +62% to +118%. **Charge for generated code, not syntax.**
  `elf/bench/fibreg.wat` keeps it measured.

### Rules that bite, learned the hard way

* **R-005** — `timeout -s KILL`; SIGTERM does not stop a busy wat program.
* **R-006** — never time the compiler where it lives; it cannot rewrite its own running image, and
  the crash reads as a fast run. Use `tools/cc-time.sh`, which refuses to time a failure.
* **C-163** — interleave, minimum fourteen repetitions. A single run is not a measurement; one
  cost this queue a 10-point mis-prediction on 2026-09-20.
* Run `tools/bootstrap.sh` **without** `--fast` before committing, and never edit the tree while
  it runs — stage 0 and stage 1 would compile different sources.

### Settled, with the evidence in FINDINGS.md

`F-126`/`C-150` quot and rem trap · `F-127`/`C-151` ownership of a grown String · `C-152` the
compiler's String-as-Vector · `C-154`..`C-161` the operand peepholes · `C-162`/`C-163` a register
calling convention and a spill slot, both measured and reverted · `C-164` the throughput benchmark
· `C-165` eight registers, cycle-neutral · `C-166` the dominating comparison · `C-167` the branch
that was two branches · `F-129`/`C-168` the inline cliff and the double-stored binding · `C-169`
`cmov` measured and rejected · `F-130`/`F-131` the price of trapping arithmetic and the refutation
of strength reduction · `C-170`/`R-006` bounds, and the crash that timed fast · `F-132`/`F-133`
`fib` closed, floor computed · `F-134`/`C-171` the bitwise gate, packets 11.63x -> 2.35x ·
`F-135`/`C-172` the string gate, scanning 34.83x -> 3.41x · `C-173` the instruction DSL ·
`F-136`/`C-174` duplicate `defn` names, and the three-module split · `C-175`–`C-176` the record
owning path and liveness over mention-counting · `F-139` the byte/char split · `C-177`–`C-183`
seven peepholes and what each was worth · `F-147`/`C-182` **strings crossed over** ·
`F-146`/`F-149` four opponents and the unpinned board · `F-152` the fixtures that drifted seven
changes · `F-150` scalar replacement disqualified, allocator named · `C-188` the back edge ·
`F-151`/`F-153`/`F-154` cmov falsified again and the layout noise floor · `F-155`–`F-158` the
uop identity, the invented quantities, and the three peer strikes that retired them.

---

**YOU ARE NEW.** You did not live the work described above; you are reading a cache someone else
wrote in a familiar voice. Before you propose or change anything: run `recolligere` from the
datamancy grimoire against the disk, check the freshness probe at the top of this section, and
read the newest `FINDINGS.md` entries yourself. The feeling that you are continuing where you left
off is the failure mode, not the all-clear.

## Where the book queue stands (2026-09-18) — **every numbered item is closed**

§1–§5 done, §6 declined, §7–§8 built as instruments, §9–§12 ported and complete. The list this
file was written to work through is finished; what follows is kept as the record of how each item
was settled, not as a queue.

**§4 is now finished too** (2026-09-18): 25 puzzles, 70 answers, against its stated ambition of
"one year" (C-114). Every suite in FINDINGS.md's status table reads complete. Project Euler (6
problems) was never a numbered item and has no stated end.

The measurement this file was queued on, 2026-09-16:

| era | findings | involving a port | probe of wat only |
|---|---|---|---|
| F/C-001…050 | 100 | 40 | 55 |
| F/C-051…075 | 25 | **18** | 6 |
| F/C-076…095 | 20 | 1 | **18** |

It said the namespace sweep was exhausted and that porting still worked, so §7–§12 returned to
porting. **That was right**: F/C-096 onward is almost entirely port-driven, and §12 alone produced
F-112 through F-117 plus C-098 to C-113 — including three findings (F-113, F-116, F-117) that no
probe of wat's own namespaces would have reached, because each needed a program large enough to
need the missing thing twice.

## Where §1–§6 stand (2026-09-15)

§1–§5 are done, each in its own directory with its own oracle, and all of them run under
`./run.sh`:

| | suite | result |
|---|---|---|
| §1 | Clojure Koans | `koans/` — 229 rows: 29 literal, 163 the wat way, 17 with no route, 20 refused by design (C-030) |
| §2 | Make-a-Lisp | `mal/` — 11/11 steps, 909 of mal's own tests (C-032) |
| §3 | SICP chapter 3 | `sicp/` — 4 chapters, 65 results against guile |
| §4 | Advent of Code | `aoc/` — **25 puzzles, 70 answers** against Clojure (C-114) |
| §5 | PAIP chapters 11–12 | `paip/` — 2 chapters, 58 results against guile (C-033, C-034) |

**§6, the Shield slice, is not being built** — the builder's call, 2026-09-15. It needs
`holon-lab-ddos` (a Clojure detection pipeline with known behaviour) and traffic to run it
against, neither of which is on this machine; and §6 names the builder as the only oracle for
the right answer, so there is no honest way to grade it here. `holon-rs` does carry the VSA
encoding, if the item is ever revived.

## 1. Clojure Koans / 4Clojure: is wat actually a Clojure dialect?

- **What:** hundreds of small problems, each already an assertion with a known answer.
- **Stresses:** breadth of Clojure semantics, form by form.
- **Why here:** the most direct acceptance test of the Clojure/EDN syntax migration. Each
  koan either ports close to literally or shows exactly where wat departs from Clojure.
  Output: a "ports literally / needs a wat idiom / impossible" table to set against the
  codemod work.
- **Lead:** wat-rs already has `tests/clj_expr_oracle/` (a `corpus.txt` turned up on
  2026-09-14; contents not yet inspected). If it is a Clojure-oracle harness, the koans
  slot straight in.

## 2. Make-a-Lisp (kanaka/mal): can wat build a language?

- **What:** a Lisp interpreter in 11 steps (reader, printer, environments, TCO, macros,
  try/catch, atoms, self-hosting). Every step ships an official test suite that checks what
  the interpreter prints for given input.
- **Stresses:** string parsing, recursive data, closures, error handling. The "atoms" step
  is mutable state, a natural test of state-on-services.
- **Why here:** there is a public scoreboard of about 90 host languages, so "wat passes
  step A" means something well known.

## 3. SICP, especially chapters 3–4: streams, state, the metacircular evaluator

- **Stresses:** lazy streams (§3.5) test `:wat::stream` properly. Chapter 3's bank accounts
  and queues test services as the home for state. The chapter 4 evaluator is a sequel to
  Little Schemer chapter 10.

## 4. Advent of Code — **COMPLETE: 25 days, 70 answers (2026-09-18)**

- **What:** real input files, parsing, grids, hash maps, and a known right answer for every
  puzzle.
- **Stresses:** what the textbooks never touch: reading files, splitting strings,
  performance. `wat`'s startup (~350–450ms per run on the i7-1270P laptop) will show up.
- **Answered (C-114).** Startup is 0.29 s, a fifth of the JVM's, and never the problem. Size is
  fine — 20000 sorted and mapped in 3.9 s. What costs is REBUILDING: the four slowest puzzles all
  rebuild per element, which is F-104 and F-116. The most expensive single gap for ordinary work
  is F-061: seven validation rules that are one-line regular expressions elsewhere are 150 lines
  of wat against 60 of Clojure.

## 5. Norvig's PAIP — **COMPLETE: 20 of 20 portable chapters (2026-09-16)**

- **Stresses:** heavy symbolic pattern-matching, which is where quoted data versus typed
  data gets decided. Pairs naturally with The Reasoned Schemer.

**Builder's ruling, 2026-09-16:** *"i think we just get full coverage - prove we handled all of
the books' various nuance, not just arguing 'meh, they're the same'"*. PAIP was probe-driven (two
chapters chosen to press quoted data); it becomes a full port.

**PAIP is 25 chapters, and several are about Common Lisp itself rather than about an algorithm.**
Those are listed below as **no portable content** rather than dropped silently — the same
treatment Okasaki ch 1 got (C-075). A chapter that teaches `loop`, `declare` or ANSI CL packages
has nothing to port to wat, and saying so is a decision on the record.

| ch | topic | status |
|---|---|---|
| 1 | Introduction to Lisp | **no portable content** — Common Lisp syntax and evaluation |
| 2 | **A Simple Lisp Program** | **done** (C-082) | hits F-036 head-on; threading the seed made it testable |
| 3 | Overview of Lisp | **no portable content** — a tour of CL's own primitives |
| 4 | **GPS** | **done** (C-082) | means-ends analysis; the bugs tested as carefully as the successes |
| 5 | **ELIZA** | **done** (C-083) | segment variables, backtracking over splits |
| 6 | **Building software tools — search** | **done** (C-083) | four searches, one program; depth-first is DEARER here (29 vs 19) |
| 7 | **STUDENT** | **done** (C-085) | `isolate` is correct only under a precondition its own code never checks |
| 8 | **Symbolic mathematics** | **done** (C-083) | a rule table is open to new rows and closed to new KINDS of question |
| 9 | **Efficiency issues** | **done** (C-084) | transparent `memoize` IS writable (an Lru in a closure); it is allowed to FORGET, hence P-028 |
| 10 | Low-level efficiency | **no portable content** — CL declarations and open-coding |
| 11 | **Logic programming** | **done** (C-033) |
| 12 | **Compiling logic programs** | **done** (C-033) |
| 13 | **Object-oriented programming** | **done** (C-085, F-109) | `defclause` IS multiple dispatch — this row first said the opposite; see F-109's retraction |
| 14 | **Knowledge representation** | **done** (C-086) | override and cycles; F-057's visited set is load-bearing for TERMINATION here |
| 15 | **Canonical forms** | **done** (C-089) | the best pairing with ch8: an identity becomes checkable rather than provable |
| 16 | **Expert systems** | **done** (C-089) | certainty factors; a range [-100,100] the type system cannot say |
| 17 | **Constraint satisfaction** | **done** (C-089) | decided / impossible / ambiguous all tested; F-104's purest case |
| 18 | **Othello** | **done** (C-086) | alpha-beta 37 nodes against minimax's 73; F-104 lands on a game board |
| 19 | **Natural language** | **done** (C-090) | ambiguity: two parses, and the TREES differ |
| 20 | **Unification grammars** | **done** (C-090) | agreement by unification; one rule where a CFG needs two |
| 21 | **A grammar of English** | **done** (C-090) | subcategorization and relative clauses |
| 22 | **Scheme: an interpreter** | **done** (C-087) | the interpreted language gets `call/cc`; a value domain with continuations cannot cross a service boundary |
| 23 | **Compiling Lisp** | **done** (C-088) | peephole: 7 instructions to 3; a compiler pass is almost entirely cases |
| 24 | ANSI Common Lisp | **no portable content** |
| 25 | Troubleshooting | **no portable content** |

**COMPLETE — 20 of 20 portable chapters done.** The five marked *no portable content* teach Common Lisp itself. Oracle: our own Scheme on each chapter's topic, run by guile
(`tools/paip-oracle.sh`). Norvig's own code is never read or copied.

## 6. Capstone: a slice of the builder's own Shield packet detector

- **What:** take a detection pipeline already built in Clojure, with known behaviour (e.g.
  a rate or entropy anomaly detector over a packet stream). Port it to wat using streams,
  services and holon's VSA encoding, then compare outputs on the same traffic.
- **Why:** every test above measures wat against a textbook; this one measures it against
  its purpose. The builder is the only oracle for the right answer, which makes it a true
  user acceptance test rather than a benchmark.
- **Lead:** `holon-lab-ddos` presumably already has pieces of this. It is not cloned on the
  daily driver yet.

## 7. A performance baseline, before the byte-code work — **DONE 2026-09-16** (`BASELINE.md`)

The builder's next phase is "byte code" / a jump DAG. A before/after can only be captured
**before**, and the numbers are currently scattered across the ledger:

| | measured |
|---|---|
| a message to a service | 224 µs, ~100 function calls (F-051) |
| the formatter | ~10 KB/s, ~800 ms fixed floor (F-075) |
| deporder over the same kind of source | ~1 MB/s (C-050) — 100× the formatter |
| `bracket::map`, thread pool | 1.69× on 16 runners, vs 5.90× for OS processes (F-094) |
| copying vs sharing containers | 135 s → 20.6 s on one AoC day (F-057) |
| the interpreter | 100–430× the JVM, 13× guile, >100× Racket |

**Deliverable:** `bench/` plus `tools/bench.sh`, one runnable suite emitting a dated table, so
the jump-DAG work has a baseline to be measured against. Nothing else here expires.

## 8. Turn the repo into a regression instrument — **DONE 2026-09-16**

17 oracle scripts exist; the recent ones (`doc-names-audit`, `cli-surface`, `fix-roundtrip`,
`bracket-os-oracle`) are reproducible *measurements* rather than one-shot investigations.

**Delivered:** `./audit.sh` runs `tools/recheck.sh`, `tools/doc-names-audit.sh`,
`tools/cli-surface.sh` and `tools/bench.sh` against any build and emits a dated report;
`--full` adds the slow ones (`fix-roundtrip`, `bracket-os-oracle`).

`tools/recheck.sh` is the signal. A probe *documents* a defect — it passes while the defect is
present — so "did the probe pass?" is the wrong question. Each check is instead a minimal program
plus the verdict expected **while the finding is open**, and a flip means the status changed.
11 checks at first run: `OPEN=11 FIXED=0`, which is correct for an unchanged build.

Two things were got wrong building it, both now fixed in place: the F-096 check did one accessor
per iteration and reported **FIXED** because the 3.6 µs loop overhead compressed a real 5.0× to
2.15× (the harness's own lesson, violated one file over); and an attempt to auto-detect
arity-specific retirements failed because a generic re-probe cannot know whether a verb takes
positional or keyword arguments — it is now an explicit, documented list of one.

**Still to add:** checks for the findings without a crisp machine-checkable signature. 11 of
~96 are covered.

## A pattern in §10 and §11, worth naming (2026-09-16)

Both ports stopped early, and for the same *kind* of reason — not "wat is slow at this" but
**"the mechanism the book is built on does not exist"**:

| | stopped at | because |
|---|---|---|
| §10 Okasaki | ~~ch 5 of 11~~ → **ch 7**, once a suspension was built | F-100 was the block; `lib/susp.wat` (P-027's stand-in) removed it |
| §11 Downey | ch 3 of ~15 | **F-102** — a service cannot release a held caller, so every blocking primitive is a spin |

That is a better outcome than finishing either book would have been. Both findings are single,
sharp, load-bearing gaps that each unlock a whole half of a textbook, and both were reached within
three chapters. The remaining chapters would have re-measured the same absence five or ten times.

It also sharpens how to choose the next port: **pick the book whose central mechanism wat already
has**, so the port tests wat's quality rather than re-discovering one missing primitive. On that
test §12 (a bytecode VM: a flat instruction array, a dispatch loop, an explicit stack) is the
safest of the remaining candidates — it needs no laziness, no blocking, and no deep recursion,
which also routes around F-099.

## What this repository already knows that bears on a CEK evaluator (2026-09-16)

The builder names a CEK machine as a long-term goal, 6+ months out. Several things measured here
bear on it directly, so they are collected rather than scattered.

**`eopl/lib/cps.wat` is already a CEK machine.** `State` is Control + Environment + Kontinuation,
`step` is the transition function, `drive` is the trampoline. It is small (about 90 lines) and it
runs, so it is available as a shape to argue with.

| what is known | where | why it matters for CEK |
|---|---|---|
| a non-tail recursion past ~110000 frames **segfaults**, exit 139, empty stderr | F-099 | **this is the reason to do it.** A CEK evaluator puts wat's own evaluation depth in the heap, so the ceiling becomes available memory and the failure becomes catchable rather than SIGSEGV. Not a patch — the defect ceases to exist |
| wat's TCO is preserved **through** an interpreter written in wat | C-061 | the hard part of a CEK migration is not pushing a K frame for a tail call. The current implementation already identifies tail position correctly, even across an interpreter boundary — that discipline is in place before the rewrite starts |
| builtin 360 ns · match-2 675 ns · user-fn 795 ns · **defrecord accessor 6130 ns** | `BASELINE.md`, F-096 | the before/after. §7 was taken for exactly this, *before* the byte-code work, because it cannot be taken afterwards |
| a **record** field holding a user enum deep-copies; an **enum variant** shares | F-098 | a K chain is literally "an enum holding the rest of the chain". If a K frame were a record, every push would copy the tail and the machine would be O(n²). Fatal if any of the machinery is written in wat; irrelevant if it is all Rust |
| a CEK transition in wat-the-language costs **~14 200 ns, flat** over 36k–576k transitions | measured here | not what wat-rs would reach in Rust, but the flatness confirms the shape is O(1) per step, and ~18-20 dispatch operations per transition is a sanity check for sizing |

**One opportunity, not a requirement.** R-003 records that wat has no `call/cc`. A CEK machine
makes the continuation a first-class value by construction, so that capability would fall out of
the rewrite rather than needing to be added to it.

## §9–§12: four books, ranked by what they'd stress

Not ranked by how good the book is — by which part of wat each one puts under load. The
Friedman books tested wat as a **Lisp**; these test it as a language host, a container library,
a concurrency runtime and a compiler target respectively.

| | book | what it stresses | why now |
|---|---|---|---|
| §9 | **EOPL** (Friedman & Wand) | wat as a **language host** | the big uncovered Friedman; everything else in the roadmap sits on it |
| §10 | **Okasaki** | the **container** story | lands on defects already measured: F-057, F-055, F-023, the missing persistent set |
| §11 | **Downey, Semaphores** | the **concurrency** runtime | F-094 left a live question; rare self-oracling corpus |
| §12 | **Crafting Interpreters II** | wat as a **compiler target** | rehearses the jump-DAG shape §7 baselined |

**If only one: EOPL.** It is Friedman, it is big, it is uncovered, and it exercises the part of
wat that everything else here depends on. The execution order below still opens with §10, because
Okasaki aims at defects that are already measured and so pays back fastest — EOPL is the largest
investment, not the first one.

## 9. EOPL — *Essentials of Programming Languages* (Friedman & Wand) — **COMPLETE — 22 of 22 languages/topics done**

**Scope correction, 2026-09-16.** What is done is a *slice* of ch 3 (the LETREC language) and a
*slice* of ch 5 (the CPS interpreter). That is two machines over one language — enough to produce
C-061, not enough to call the book ported. EOPL is nine chapters:

| ch | language / topic | status | note |
|---|---|---|---|
| 1 | **inductive sets of data** | **done** (C-074) | follow the grammar — enforced by exhaustive match, not remembered |
| 2 | **data abstraction, environment representations** | **done** (C-074, F-107) | one client, three representations incl. a closure; the surface encoding is refused (F-029) |
| 3 | **LET** | **done** (C-074) | built separately, per the no-skipping ruling |
| 3 | **PROC** | **done** (C-074) | two productions and one Val variant — which is what makes Val and Env mutually recursive |
| 3 | **LETREC** | **done** (C-061) | the language the three machines run |
| 4 | **EXPLICIT-REFS** | **done** (C-066) | store threaded as a PersistentMap; mutation priced three ways |
| 4 | **IMPLICIT-REFS** | **done** (C-068) | every variable is a reference; `deref` never written |
| 4 | **MUTABLE-PAIRS** | **done** (C-069) | a pair is two adjacent cells; aliasing needs no new machinery |
| 4 | **call-by-name / call-by-need** | **done** (C-062) | by-name O(n²) vs by-need O(n) |
| 4 | **call-by-reference** | **done** (C-068) | the whole switch is one predicate: is the argument a bare variable? |
| 5 | **CPS interpreter** | **done** (C-061) | lifts F-099's ceiling |
| 5 | **exceptions** | **done** (C-065) | a handler is a continuation frame |
| 5 | **threads** | **done** (C-064) | the mutex wat itself cannot express |
| 6 | **CPS transformation** | **done** (C-070) | source to source; the ceiling moves 20000 -> 100000+ under the SAME interpreter |
| 6 | **registerization** | **done** (F-105) | costs ~1.9x in wat: `step` must allocate the State it returns. Mutual TCO holds to 10M, so it is a choice |
| 7 | **CHECKED** (a checker over annotations) | **done** (C-067) | rejects wrong annotations; inference cannot |
| 7 | **INFERRED** (reconstruction by unification) | **done** (C-063) | unification, occurs check |
| 8 | **simple modules** | **done** (C-071) | `from m take x` consults the interface, never the body |
| 8 | **opaque types, parameterized modules** | **done** (C-071, F-106) | `opaque t` vs `transparent t = int` is one word and decides everything; wat has `newtype`'s distinctness but no sealing |
| 9 | **CLASSES** | **done** (C-072) | `c2.m2`=23 and `c2.m3`=11 — same method name, two starting points for the walk |
| 9 | **TYPED-OO** | **done** (C-073) | subsumption; and wat's surfaces already give the interface half, heterogeneous dispatch included |

**Builder's ruling, 2026-09-16: no skipping.** *"I think the cost of duplication is worth coverage
of the books. I'd rather not have omissions in the books."* This repository is the validation
testbed for the Clojure-ification, so a gap in coverage is a gap in validation — an argument that
overrides "chapter 6 overlaps §12" and "Little Java already did OO".

**Correction that ruling forced.** I had been skipping *within* chapters as well as between them
and reporting the chapter as done: chapter 7's **CHECKED** language was never built (only
INFERRED), and chapter 4 had IMPLICIT-REFS, MUTABLE-PAIRS and call-by-reference outstanding. Both
holes are now closed (C-067, C-068, C-069); the table above is the honest state.

**Order from here:** ~~ch 4~~ (C-068, C-069) and ~~ch 6~~ (C-070, F-105) are **complete** as of
2026-09-16, and so are ~~ch 8~~ (C-071, F-106), ~~ch 9~~ (C-072, C-073) and ~~ch 1-3~~ (C-074,
F-107). **EOPL is finished — 22 of 22, nine chapters, no omissions.** The no-skipping ruling cost
four extra languages that a "close enough" reading would have dropped (ch7 CHECKED, ch4
MUTABLE-PAIRS, ch3 LET and PROC), and two of them paid for themselves: CHECKED produced C-067 and
ch2's dictionary produced **F-107**, a fresh defect found in a chapter I would otherwise have
skipped as covered. **22 of 22 done. The book is complete.** No skipping.

The big uncovered Friedman. Interpreters, type checkers, continuations, stores, an
explicit-control evaluator — incremental, every chapter runnable, and it tests wat as a
**language host**, which is what the rest of the roadmap sits on. Oracle: the book's own
expected values, and Racket/guile for the reference implementations.

## 10. Okasaki — *Purely Functional Data Structures* — **ch 2–11 DONE 2026-09-16 — the queue and list line of the book is complete**

**Coverage audit, 2026-09-16.** This section had said "ch 2, 3, 5–11" and called itself complete.
Chapter 4 (LAZY EVALUATION) was missing: `okasaki/lib/llist.wat` had the operations, and every
later chapter's header cites "ch 4 LAZINESS", but the chapter that CHECKS the incremental /
monolithic distinction had never been written. Now `okasaki/ch04-lazy-evaluation.wat` (C-075).
**Chapter 1 is the book's introduction and has no data structure to port** — stated here so its
absence is a decision on the record rather than another silent gap.

~30 structures, each small and runnable, each with a stated amortized bound. Lands directly
on the weak spot this repo has already measured: F-057 (copying vs sharing containers), F-055
(`rest` clones, so walking is quadratic), F-023 (`conj` clones), and the **missing persistent
set** (a visited set has to be a `PersistentMap` to `true`). Laziness and amortization are
wat's `:wat::stream::` territory, which F-088 showed is documented as an API that does not
exist. Oracle: the book's bounds, and timing curves rather than single points (C-050's method).

## 11. Downey — *The Little Book of Semaphores* — **COMPLETE, ch 1-7 (2026-09-17)**

**The "blocked past ch 3 by F-102" label was wrong** (2026-09-17). F-102 makes every wait a spin,
which is expensive, not impossible — `semaphores/lib/sem.wat` is a counting semaphore built that
way, and every pattern in the book is a composition of it. What the spin costs is reported by each
puzzle as a poll count, which is the only thing these ports measure that a language with blocking
would not have to.

~30 concurrency puzzles with known-correct answers **and** known failure modes — a rare
**self-oracling** corpus, where a wrong implementation fails in a way the book already names. F-094 measured `bracket::map`'s thread pool at 29% of what the
same machine does with OS processes, so this is a live battleground. **No networking** — the
builder's call, 2026-09-16: networking is simulated via IPC anyway (processes over unnamed
Unix domain sockets, threads over crossbeam-style channels), so the puzzles run against
`:wat::spawn::`/`:wat::bracket::`/`:wat::service::` directly.

## 12. *Crafting Interpreters*, Part II — the bytecode VM — **COMPLETE 2026-09-18, ch 14-30, 17 programs**

Chapter 30 was recorded here as "no portable content" and that was half right: the content does not
port (NaN boxing, a hash-table bitmask) and the METHOD does. Re-reading the ruling — which C-103
is the standing reason to do — produced C-113, which **reversed a recommendation made on this
page** about the VM's stack type.

A flat instruction array, a dispatch loop, a value stack, jump patching. Not for the book's
sake: it rehearses the exact machinery §7's baseline is being taken for, and it tests whether
wat can host the shape of its own next phase.

**Three numbers this section already has, before a line is written.** They are the reason to do
it in this order rather than first:

| | |
|---|---|
| **C-081** (SICP §5.5) | the same expression costs **11** machine steps interpreted and **8** compiled, from 3 top-level instructions. The payoff of compiling, as a count |
| **F-105** (EOPL ch6.5) | `step : State -> State` is **~1.9×** slower than mutually tail-calling procedures, because `step` must allocate the state it returns. The registerized shape is the slower one |
| **BASELINE.md** | builtin 360 ns, match-2 675, user-fn 795, closure 853, defstruct accessor 1219, **defrecord accessor 6130** — so the dispatch loop's own arithmetic has a floor |

**Chapter table.** Nystrom's Part II is chapters 14–30. Several are about C rather than about a
VM, and are listed as **no portable content** rather than dropped silently — the treatment Okasaki
ch 1 and PAIP's CL chapters got.

| ch | topic | status |
|---|---|---|
| 14 | **Chunks of bytecode** | **done** (C-098) | an opcode is an enum carrying its operand; offsets count instructions, not bytes |
| 15 | **A virtual machine** | **done** (C-098) | **registerized costs ~2.3-2.5x; hoisting the chunk out of the loop saves ~30% more; they compound to 3-4x** |
| 16 | **Scanning on demand** | **done** (C-099) | 38 token kinds, all asserted produced; on-demand pull works (8 tokens < a tenth of the file); **record-per-character vs record-per-token is ~2.5x**, and F-062 leaves no hoist available |
| 17 | **Compiling expressions** | **done** (C-100) | the compiler reproduces ch14's hand-built chunk exactly and ch15's VM gives ch15's answer; the rule table of function pointers was built in a probe — `defstruct` row works, `defrecord` row refused (F-114) |
| 18 | **Types of values** | **done** (C-101) | a tagged union is a `defenum`; `valuesEqual` is `(= a b)` (F-019 clarified); Nystrom's NaN bug in `<=` reproduced; runtime errors are a `Step.Fail` value, one match per instruction. Runs on `:loxv::` so ch15's measurements keep their code |
| 19 | **Strings** | **done** (C-102) | one enum variant and one `string::concat`; `Obj`/`ObjString`/`freeObjects` are C's memory management. Debt: ch26's collector must build its own heap |
| 20 | **Hash tables** | **done** (C-103) — **the earlier ruling was half wrong** | the table itself is not worth rewriting (C-078 priced wat's two), but the chapter's **interning** is a language decision, and its cost claim is about a C program: measured, it buys **nothing at 10 characters** and about a quarter at 100 000 |
| 21 | **Global variables** | **done** (C-104) | statements, a globals table, assignment as an expression, `synchronize()` counted rather than assumed; `canAssign` checked on five invalid targets. Cost: **F-115** |
| 22 | **Local variables** | **done** (C-105) | a local costs no instruction to create, checked through the emitted code; both compile errors checked; `OP_SET_LOCAL` is F-104 in an inner loop (76 µs at one local, 404 µs at forty) and the probe it prompted found **F-116** |
| 23 | **Jumping back and forth** | **done** (C-106) | the backpatch chapter 14 predicted: a patch rebuilds the code vector, **~7 µs per instruction already emitted**, so patches are quadratic in program length (90 `if`s: 1.06 s against 0.16 s) |
| 24 | **Calls and functions** | **done** (C-107) | functions as values with their own chunks, a stack of compilers, call frames. A frame is allocated per **call**, not per instruction, so it cost less than ch22-23. A native is a name, not a closure (F-114). Two checks pin the ch24/ch25 boundary |
| 25 | **Closures** | **done** (C-108) | the one chapter whose DESIGN had to change: an upvalue is a `Value*` into the stack, and wat cannot share a mutable location, so the pointer became an index into a VM-owned cell table. Sharing, non-sharing and closing all checked |
| 26 | **Garbage collection** | **done** (C-109) — and it was more than "partly covered" | chapter 25's cell table was a **real leak**, so this is mark-sweep over something that actually needed collecting: 30 cells with the collector off, 8 with it on. Every root checked, marking transitive |
| 27 | **Classes and instances** | **done** (C-110) | `var a = f; a.x = 2; print f.x;` forced the **second** VM-owned index table in three chapters — **F-117**. A class needed none of it: immutable once declared |
| 28 | **Methods and initializers** | **done** (C-111) | cost **nothing** — `this` is local slot 0, so a closure inside a method captures it like any other local. `init` differs in exactly two compiled details |
| 29 | **Superclasses** | **done** (C-112) | `super` checked to be **lexical** through a three-level hierarchy: `CBA` with a C receiver. `OP_INHERIT` is `OP_METHOD`'s move again |
| 30 | **Optimization** | **done** (C-113) — the content does not port, the **method** does | NaN boxing and the hash-table bitmask are about C; benchmarking before optimising is not, and it **reversed a recommendation made on this page** (see below) |

**A recommendation this page made and chapter 30 reversed.** `probes/lox/stack-ops.wat` (F-116)
showed that a `Vector`'s rebuild-pop is quadratic where a `PersistentVector`'s is linear — 121 ms
against 34 ms for one pop at depth 4000 — and this page concluded that the lox VM's stack should
therefore be a `PersistentVector`, listing the switch as work to do. **It should not.**
`probes/lox/stack-mix.wat` runs the operation mix a VM actually performs at the depths it actually
reaches, and the `Vector` wins at every one of them: 89% of the cost at depth 4, 80% at 32, 82% at
128, crossing over only past 256. `PersistentVector`'s `get` answers an `Option`, and the unwrap on
every read costs more than the clone it saves. F-116's numbers stand; the advice did not (C-113).

**Oracle.** Unlike the other suites there is no second implementation to compare against: the VM
IS the thing being tested. So each chapter checks its own invariants — a program's value, the
instruction count, the stack's high-water mark — and where a result can be cross-checked against
an existing port (SICP §5.5's compiler, C-081) it is.

## Suggested order — **spent 2026-09-18**

The order this section recommended was §7, §8, then §10, §11, §9, §12. That is the order it was
done in, and every item is closed. The ordering advice is kept because its reasoning still holds
for whatever comes next: instruments before ports, ports aimed at defects already measured before
ports chosen for being books, and the largest interpreter last so it can be written against
whatever the byte-code work has become.

A note on spelling, 2026-09-16: the builder expects to drop the o.g. wat syntax for a
Clojure/EDN-compliant scheme within weeks, with "typed Clojure" as the end game. New ports
should be written in whatever spelling is current and **not** hand-tuned for the migration;
`tools/fix-roundtrip.sh` already exists to convert the corpus and differential-test the result
when the flip lands.
