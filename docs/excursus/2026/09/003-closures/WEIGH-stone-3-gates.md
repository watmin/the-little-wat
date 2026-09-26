# WEIGH — excursus 003 stone 3: the code is credited; the gates and the cost go back

2026-09-26.

## Credited

The shape the probe required, as built: the front rewrite (`:c::close` sites, `:lifted` rows,
depth-first), `argreg-mark` skipping lifted rows, captures decided and typed at the site and carried
in `PassR`, the object `[count 1][code][cap…]` through `vec_new`, captures stored with `:c::share`,
the lifted prologue saving rax and binding each capture once through `:c::read-out` (`Read.Cap`),
`reads: ok`. All seven fixtures agree natively, the builder's `126`/`86` and `16`/`27` among them; no
existing program moved; a byte-identical fixpoint at 295,560 bytes.

**The share mutant, accepted with its reason:** a capture puts the name at the site as a bare symbol,
so the linearity analysis already refuses the owned in-place `conj` on it — the count at the store is
a second wall no fixture can isolate. It stays: correctness rests on the count being complete
(F-188), not on `own?`. Record that reasoning in the SCORE and in the prose at the capture store.

## Back

**T1 — `TYPE-CONFLICT 31`.** The made nodes reuse the `fn` form's origin, so the compiler exports types
at columns where wat's checker typed a DIFFERENT node, and at least one export's raw type is `fn0`,
which is not stone 1's spelling of any function type. Every made node must export at the position of
the source node it STANDS FOR (a lifted body's nodes are the `fn` body's own nodes; the `:c::close`
site is the `fn` form, typed as the function type); a made node that stands for no source node exports
nothing. Find where `fn0` comes from.

**T2 — `unplaced 10`.** A lifted function's parameters are a `fn` form's parameters. The gate places a
`CParam` only on parameter *i* of a `defn`; teach it the `fn` form's parameter vector as well, in the
same placement rule (plain wat for any parsing, rules only join). Then the gate compares a lifted
function's parameters exactly as a `defn`'s.

**T3 — the cost compares different work.** The new compiler's `main` compiles seven more programs.
Measure both compilers on the SAME input: the previous corpus list, with the new compiler's extra
seven `:c::compile` calls removed from a scratch copy of its driver (or the previous compiler given
them too) — say which, and give instructions and cycles as before.

Then `tools/elf-run.sh` IN FULL (exit 0, `rules: 0`, `types: 0`, `partial 0`, `unplaced 0`) and a fresh
bootstrap. Append a re-strike section to the SCORE.

---

**Credited, 2026-09-26, on the orchestrator's own runs:** `tools/elf-run.sh` exit 0 (99 native binaries;
`rules: 0` in 12,047 pairs; `types: 0` in 20,372 nodes; `unplaced 0`, `partial 0`; over 139 programs),
the seven closure programs agreeing natively — `closure-captures` `126 86`, `closure-nested` `16 27`,
`fn-vec` `2 3 2`, `fn-rec` `42`, `fn-capfn` `23`, `fn-loop` `6`, `fn-nocap` `42`; `tools/bootstrap.sh`
byte-identical at **294,005 bytes**; `reads: ok`; the 89 existing programs byte-identical, the seven
new ones adopted.

**The cost, recorded as a cost:** on the SAME input, **+2.467% instructions** in both rounds —
**68.3 million** (2,838,307,906 − 2,769,959,866; the SCORE's "6,834,804" drops a digit, its percentage
is right). It is the front rewrite walking every node, in programs with no `fn` as well; cycles are
not claimed against the 1.8% floor. A candidate for the performance work, not a defect.
