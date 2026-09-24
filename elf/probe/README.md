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
| `regabi.wat` | every shape the per-function register convention has to get right at once: arity 1, 2 and 3 leaves; a call-free leaf with a self tail call, whose back edge must write rdi and rsi rather than rbx and r12; a leaf whose arguments are not in parameter order, which must stay on the stack path; a String parameter, which has to be SHARED in rax before it is placed; a call site whose argument is itself a call, which forces the push-and-pop-into-registers path; and a function whose ADDRESS is taken, which must keep the stack convention because `call *rax` cannot know an arity. |
| `callrel-stop1.wat` | the caller-side release's soundness case: a callee conjs its LINEAR parameter and returns i64, so the call is released, and the caller reads its Vector back after 20,000 later allocations. It agrees because `:c::share` and `vec_conj_own`'s arm word are the SAME word at `[ptr-8]` -- a shared Vector reads 2, path 3 wants exactly 1, and the runtime copies. |
| `callrel-borrow.wat` | **the half that is NOT closed, and it diverges at HEAD too.** The pointer reaches the callee as `(nth g 3)` -- not a symbol, so `:c::share` never increments it -- and `vec_conj_own` extends a live container's element in place. The interpreter says the row is 3 long and ends in 30; the compiler says 4, ending in `99` without the caller-side release and in `0` with it, because the rewind frees the extension the length still counts. |
| `f170-cond-test.wat` | a write site inside a `cond` clause's TEST, with the clause body reading the name afterwards. `:c::live-after` walked kids from index 1 -- right for `(f a b)`, wrong for `(test body)` -- so the write looked dead and was done in place. Native printed 4, the interpreter 3. |
