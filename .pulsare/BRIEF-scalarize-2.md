# BRIEF v2 — scalarise, with trigger 1 corrected

Tree `535c8d2`. **You stopped correctly and the brief was wrong.** Verified here:
`:c::mut-site` returns −2 on a second write, so two fields do fail; `:c::linear?` is
`occ <= 1` OR `:c::dead-after-write?`, and neither looks at the head of the form a mention
sits in. Both your counterexamples hold — a record returned from the other arm of the `if`,
and a `(println s)` before the one write, are each "linear" and each escape.

So the analysis is missing, not composable, and my trigger forbade the work the strike
needs. Corrected below. Everything else in BRIEF-scalarize.md stands: rooms, sketch, blast
radius, expectations, triggers 2 and 3.

## Trigger 1, replaced

**Write the classifier. It is the work, and it is not a fourth liveness.**

`:c::occ`, `:c::live-after` and `:c::none-mention?` answer *how many* and *where*.
Scalarisable asks *what*: is every occurrence of this parameter a field read of one `f`, or
an `assoc` of that same `f`, and nothing else. That is a different question about the same
tree, and the existing three are the wrong shape for it by construction — which is what
your score established and what I should have seen before writing the constraint.

Structurally it is `:c::occ` with a verdict instead of a count: walk the body, and at each
node ask what position the name occupies.

    classify(node, name) ->  one-of  none | read(f) | write(f) | other
      (:R/f name)                    -> read(f)        f from :c::acc-index
      (assoc name :f v)              -> write(f), and classify v
      name as a bare symbol anywhere -> other          the escape
      otherwise                      -> fold the children

    scalarisable(param, body) =
      every verdict is none, or read(f)/write(f) for ONE f

`other` is the whole escape test: a bare mention that is not the first child of a field
read or the container of an `assoc` is the record leaving. That catches the return, the
`println`, the argument to another call, the comparison — without enumerating them.

**Reuse where the semantics must agree, not where the shape does.** `:c::acc-index` and
`:c::field-index` resolve `f`; `:c::rec-name-of` resolves the type. Those are facts the rest
of the compiler already owns and the classifier must not re-derive. The *walk* is new.

## The one thing I want you to check before building

`:c::occ` maxes the arms of an `if` because it asks "how many reads on the worst path", and
that is right for its question. **For this question the arms must be UNIONED, not maxed** — a
record that escapes on either arm escapes. If the classifier folds arms the way `occ` does,
it inherits exactly the bug that made trigger 1 wrong. Say so if you find the opposite.

## Everything else unchanged

Rooms, sketch, blast radius (`elf/compile.wat` only), triggers 2 and 3, and the expectations
table are as written in BRIEF-scalarize.md. Trigger 3 you have already cleared: the tail
target is `base + codelen` of the prologue, so an entry `mov FIELD(%p),%p` in that prologue
runs on the call from `main` and the back edge jumps over it. No calling-convention change.

Still no predicted cycle number beyond "toward `recflat`" — 8.00 ins/it, ~1.50 cyc/it.
