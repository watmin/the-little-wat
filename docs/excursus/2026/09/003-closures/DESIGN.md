# DESIGN — excursus 003: closures

> The builder's goal (2026-09-24): *"captures should be like... a very wide amount of things?.. we
> can capture closures in closures?... anything that's named in our scope can be captured?...."* —
> *"alright - let's get it built?.."*

## Why

`elf/` refuses `fn`. `probes/closure-captures.wat` (interpreter `126`, `86`) and
`probes/closure-nested.wat` (`16`, `27`) are the answers it must reach: a `fn` capturing a value, a
function handed a function, a `fn` capturing a closure, closures returned from functions and
composed. NEXT.md's older note settled one thing already, by the four questions: **closures, not
lambda lifting** — a `fn` that compiles until it happens to mention an outer name is a cliff that is
invisible in the source (UX NO).

## What is already on disk (crawled 2026-09-24, at `beb513d`)

- **Function values exist.** A top-level function in operand position is its code address,
  `movabs` (`elf/compile.wat:2249-2253`); `elf/src/fnref.wat` and `fnvec.wat` pass and store them.
- **Indirect calls exist.** `:c::call-indirect` (`:5196`) pushes the arguments, evaluates the head
  into rax, `call *rax`. A function whose address is taken keeps the stack convention (`:5551`).
- **An indirect call already shares every argument** (`:c::push-args`, `:4968`, through `:c::share`):
  the caller cannot know what the callee keeps, and the count says so. Ownership is safe there.
- **The function type drops its argument types.** `[A B :-> R]` is `"fn:2:R"` (`:1387-1460`). The
  export translates it as `partial:` (`:7212`), and the types gate counts `partial` without comparing
  it (`tools/rules/check.wat:31`, `:456`): **16 nodes over the corpus are typed and never checked.**
  wat's checker records the whole type at every one of them
  (`[:wat::core::i64 :wat::core::i64 :-> :wat::core::i64]`).
- **wat's rule for function types is Liskov, measured**: equal arity, arguments CONTRAVARIANT,
  the return COVARIANT, over the variant-to-enum subtyping (`elf/probe/fnty-*.wat`, F-202). Reading
  `unify`'s `Fn` arm (`wat-rs/src/check.rs:16801`) suggested plain structural equality; the probes
  with `wat --check` say otherwise, and the probes are the rule. A Vector stays invariant.
- **The compiler gets it wrong both ways (F-202)**: it compiles a function type-wrong in its
  argument (one answered `1`, one SEGFAULTED) and refuses one with a narrower return.
- **The per-parameter analyses read a `fn` body as ordinary uses.** `:c::use-walk`'s default arm
  folds over every child (`:6100-6140`), so a record parameter mentioned as `(:R/f r)` only inside a
  `fn` would be SCALARISED (held as that one field) and a capture of `r` would store the field, not
  the record. `:c::linear-of` (`:3543`), `:c::read-only?` (`:3598`), the poke scan (`:4794`) and
  `:c::occ` (`:3378`) walk the same way. The counts protect the linear case at run time (a capture
  shares, so an in-place `conj` copies); nothing protects scalarisation — it is syntactic.
- **The compiler already rewrites its arena before the passes.** The pipeline in `:c::compile-as`
  (`:7261`) is collect → `fill-fns` → `poke-fix` → `inl-fns` (the inliner, `:c::mknode-ty` `:6617`,
  keeping each made node's origin and type for the gates) → `argreg-fns` → pass 1 → pass 2.

## The shape — three stones, each landing what the next needs

**Stone 1 — whole function types.** `[A B :-> R]` is spelled with its argument types; the export
translates it to wat's spelling; the types gate compares function types like any other, and
`partial` becomes must-be-zero. An indirect call checks its arguments against the function type, as
a direct call checks against the declaration. **No byte of any corpus program moves.** Closures make
function types common — every closure, every capture of one — and they cannot arrive into a gate
that is blind to them.

**Stone 2 — one representation for every function value: a closure object.** `[count][code][cap…]`,
the pointer at `code`, the Vector/record layout the runtime already has. A top-level function used
as a value is a STATIC object with count 0 — a literal, exactly as a String literal is
(`:c::static-str`) — so `fn:` becomes a pointer type and takes the literal guard (stone 6's table
gains its row). An indirect call becomes `call [rax]` with **the closure itself in rax**: a
top-level function ignores rax, a closure's code saves it. `fnref`/`fnvec` must agree; every moved
program is explained by the new call and the new value. Still no `fn` form.

**Stone 3 — the `fn` form, by closure conversion as an arena rewrite at the FRONT of the pipeline.**
Each `fn` becomes a lifted function in the table, and at its site a closure-construction node whose
arguments are the captured names, bare. Every later analysis then sees an ordinary node with bare
symbol arguments — which every conservative walk already treats as a retain — and never sees a `fn`
body inside another function. **The scalarisation trap has no form after the rewrite.** In the
lifted function a capture is a counted read out of the closure (`:c::read-out` gains a `Read`
variant; `tools/reads.sh` fails any other spelling); building the closure shares each capture
(a capture is a store into a container — F-188's class). Nested closures capture transitively,
because an inner `fn`'s rewrite sees the outer one's captures as its locals.

## The one contract decision — how a capture gets its type

A captured name's type is known at the `fn` site, in the enclosing function's environment. The
lifted function is compiled somewhere else. The candidates, by the four questions:

| candidate | Obvious | Simple | Honest | Good UX |
|---|---|---|---|---|
| the rewrite walks scopes itself to type each capture | YES | **NO** — a second scope walk beside the typer, two derivations of one fact (what stone 4 of 002 removed) | — | — |
| the capture's type is `:c::type-of` of the name AT THE SITE, recorded when the site is typed, read when the lifted function is | YES | YES — one derivation, the waist | YES | YES |
| annotate every capture in the source | YES | YES | YES | **NO** — the language does not ask for it |

**The second.** It is the one-derivation answer; stone 3's disconfirming probe must show that the
site is typed before the lifted body is (both passes), or show the order that makes it so, BEFORE
stone 3 is briefed.

## Out of scope — rejected

Tail calls through a closure (an indirect call is never a tail call today, `:5189-5195`, and this
does not change it) · specialising a closure per instantiation · `mal/stepA_mal.wat` (the acceptance
target after stone 3, its own stone) · reclamation of closure objects (excursus 001 stone 1's work)
· anything in `../wat-rs`.

## The disconfirming probe for stone 3 — capture types (run 2026-09-26, after stone 2 landed)

The contract decision above assumed "the site is typed before the lifted body, in both passes". The
probe, against `caebf4b`, says **not as the pipeline stands** — and names the one thing to change.

1. **A pass threads no `Prog` between functions.** `:c::pass` hands every `:c::compile-fn`
   (`elf/compile.wat:6336`) the same `pg`; only the tail, `fnames` and `faddrs` flow forward, in
   `:c::PassR`. So a capture type recorded at a site can reach a later function only through
   `PassR` — a table beside `faddrs`.
2. **A typer-only walk to an arbitrary site does not exist.** `:c::ty-bind` (`:1864`) is the typer's
   walk of a `let` only; a walk that stands at any `fn` site with its whole environment would be a
   second scope walk beside the typer — the candidate this design already scored Simple NO.
3. **Exactly one pre-pass reaches the typer**: static call graph from `fill-fns`, `poke-fix`,
   `inl-fns`, `argreg-fns` — only `argreg-fns`, by `argreg-mark → argreg-fn? → callfree? →
   noret-seq? → scratch-safe? → word-cmp? → type-of`. And `:c::argreg-mark` asks `argreg-fn?` of
   EVERY function; address-taken filtering comes after (`argreg-cands`, `taken-kids`). So as the
   pipeline stands, **a lifted body would be typed before any site records its captures**, and the
   typer would refuse it (totality doing its job).

**What stone 3 therefore carries:** the rewrite marks each lifted function LIFTED in its `:c::Fn`
row; a lifted function is always reached through `call [rax]`, so `argreg-mark` gives it `nargs 0`
WITHOUT asking `argreg-fn?` — its body is never typed before the passes. Capture types travel in
`PassR` (recorded when the site is typed, read when the lifted body is compiled). Lifted functions
are appended in depth-first order (the parent, then each `fn` in it, then theirs), so every site is
typed before its body in pass 1 and in pass 2. A new pre-pass that types bodies would reopen this —
the brief makes that a STOP.
