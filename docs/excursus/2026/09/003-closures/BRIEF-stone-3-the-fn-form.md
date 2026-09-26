# BRIEF — excursus 003 stone 3: the `fn` form compiles

> The builder, 2026-09-24: *"captures should be like... a very wide amount of things?.. we can capture
> closures in closures?... anything that's named in our scope can be captured?...."* — *"let's get it
> built"*. Stone 1 made function types whole; stone 2 made every function value a closure object with
> the closure in rax at entry. This stone makes `fn` produce one.

## YOU ARE NEW TO THIS — read first

1. `docs/excursus/2026/09/003-closures/DESIGN.md` — WHOLE, and its last section above all: the
   disconfirming probe for this stone, which names the pipeline change it requires
2. `SCORE-stone-2-one-closure-representation.md` and `WEIGH-stone-2-one-row.md` — the object layout,
   `:c::fn-val`, `call [rax]`, the gate's `IArg`
3. `FINDINGS.md` — `### F-188` (a store into a container is counted; a read out is counted), `### F-202`
4. `002-no-guesses/SCORE-stone-6-…` and `WEIGH-stone-6-refuted.md` — the count guard's table, and why
   every derivation row is checked against every kind of value

## THE CONTRACT

`(fn [p <- :T …] -> :R body)` evaluates to a HEAP closure object `[count 1][code][cap…]` whose code is
a lifted function; calling it through stone 2's `call [rax]` runs the body with its parameters AND the
values it captured. Anything named in the enclosing scope can be captured — a value, a Vector, a
record, a function value, another closure. Capture is a copy of the value (wat is immutable), so the
closure sees the value at the moment it was built.

## THE SHAPE — as the probe requires

1. **The rewrite, at the FRONT of the pipeline** (`:c::compile-as`, before `fill-fns`; made nodes
   through `:c::mknode-ty`, each keeping its origin for the gates): each `fn` node becomes a LIFTED
   function row — marked lifted in its `:c::Fn` — and, at the site, a closure-building node whose
   arguments are the CANDIDATE captures as bare symbols: the symbols in the body, minus the `fn`'s own
   parameters, minus global names. Its head is a spelling no source file can produce. Every later
   analysis then sees bare symbol arguments (a retain, to every conservative walk) and never a `fn`
   body inside another function — the scalarisation trap (`DESIGN.md`) has no form.
2. **Lifted functions are appended depth-first** (the parent, then each `fn` in it, then theirs), so a
   site is compiled before its body in pass 1 and in pass 2.
3. **`:c::argreg-mark` gives a lifted function `nargs 0` WITHOUT asking `:c::argreg-fn?`** — it is only
   ever reached through `call [rax]` — so no pre-pass types its body.
4. **At the site** (compiled in the parent, where the environment is known): each candidate the
   environment binds is a capture; its type is `:c::type-of` there (the one typer); a candidate the
   environment does not bind is not captured. The site allocates `[count 1][code][cap…]` through the
   allocator records use, stores the lifted function's code, and stores each capture WITH `:c::share`
   (a capture is a store into a container — F-188). The capture list and types are recorded into a
   table threaded through `:c::PassR`, beside `fnames` / `faddrs`.
5. **In the lifted function**: the prologue saves rax (the closure) to a frame slot; each capture is
   bound, by the recorded table, to a read out of the closure through `:c::read-out` (a new `Read`
   variant — a capture is a value held by a container, so it is counted; `tools/reads.sh` classifies
   it). Its parameters are its declared ones; its captures are NOT parameters, so the per-parameter
   analyses (`linear`, `ronly`, `scalar`, pokers) never treat a capture as one.
6. **Typing**: a `fn` form's type is its declared function type (stone 1's spelling). The types gate
   compares it with wat's checker like any node.

## THE FIXTURES

- `probes/closure-captures.wat` — interpreter `126`, `86`. `probes/closure-nested.wat` — `16`, `27`.
  Both must AGREE natively. Move them into the corpus (`elf/src/`, listed in `COMPARED`, compiled by
  `:user::main`) — stone 2's lesson.
- **New, each first on the interpreter:** a closure capturing a Vector whose callee `conj`s it (the
  original keeps its length — the capture's count protects it); a closure capturing a RECORD parameter
  that the body uses only through one field (the scalarisation trap: must agree); a capture of a
  function value and of another closure; a closure built in a loop, each capturing a different value;
  a `fn` with no captures.
- A mutant that drops the `:c::share` at the capture store must make the Vector fixture diverge.

## STOP TRIGGERS

- **STOP-1 — a pre-pass types a lifted body**, or anything needs capture types before the site is
  compiled. Report the path.
- **STOP-2 — deciding captures needs a second scope walk or a second typer.** Report what forced it.
- **STOP-3 — a closure body tail-calls, clones or pokes** in a way the current conventions cannot
  carry. Report the shape; do not improvise a convention.
- **STOP-4 — a gate above zero, or a red.** Capture it; never re-run it.

## OUT OF SCOPE

Tail calls through a closure · reclaiming closure objects (excursus 008) · a `fn` that captures a
mutable cell (wat has none) · `mal/stepA_mal.wat` (the acceptance target after this stone).

## METHOD

`timeout -s KILL` on every wat run; assert every text replacement; `cond` ends in `(:else …)`, no `_`,
no catch-all; leave the tree alone while `tools/bootstrap.sh` / `tools/elf-run.sh` runs; bootstrap
WITHOUT `--fast`; `tools/elf-run.sh` IN FULL; `tools/emitted.sh` and a diff for every moved program;
cost (instructions and cycles, the 1.8% floor) against this commit's compiler at its own fixpoint.
**Commit nothing; leave the tree dirty.** Write `SCORE-stone-3-the-fn-form.md` here.
