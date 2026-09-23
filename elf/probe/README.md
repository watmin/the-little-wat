# elf/probe -- shapes that broke the compiler, kept so they cannot break it again

These are not part of the compiled corpus (`elf/src`, `elf/bad`, `elf/bench`, `elf/native`).
They are small programs that once miscompiled, run with `tools/probe.sh`, which compiles one
of them and diffs the native answer against the interpreter's in about three seconds.

    tools/probe.sh elf/probe/f168-and-tail.wat

| probe | what it pins |
|---|---|
| `f168-and-tail.wat` | a self tail call as the last operand of an `and`. Before C-196 the generator compiled it as a loop while `:c::tail-self?` answered false, and the loop never ended. |
| `f168-and-tail-vec.wat` | the same shape reading a vector. **This one did not crash** -- it exited 0 and printed `false\|false` where the interpreter prints `true\|false`. A silently wrong answer is the reason this directory exists. |
| `share-shadow.wat` | two `let` bindings of the same name, each passed to a mutating callee. A share-set keyed on the NAME elides the second, so the inner value keeps its owned marker and is mutated in place -- native `"z2!z1!z2!"` against the interpreter's `"z2z1!z2!"`. Pins that the key must be the BINDING (C-210). |
| `share-join.wat` | a share inside one arm of an `if`, then another after the merge. Carrying the set past the join elides a share the other path still needs -- native `"z1!-z1!"` against `"z1-z1!"` on the false path. Pins that `:c::patch` must clear it (C-210). |
| `nested-vec.wat` | a `(Vector :- [(Vector :- [i64])])`, built with `conj` and read with nested `nth`. Pins the fact that nested containers DO compile -- F-171 claimed they did not, and used that to justify a design decision (C-199). |
| `f170-cond-test.wat` | a write site inside a `cond` clause's TEST, with the clause body reading the name afterwards. `:c::live-after` walked kids from index 1 -- right for `(f a b)`, wrong for `(test body)` -- so the write looked dead and was done in place. Native printed 4, the interpreter 3. |
