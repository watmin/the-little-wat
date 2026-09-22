# elf/probe -- shapes that broke the compiler, kept so they cannot break it again

These are not part of the compiled corpus (`elf/src`, `elf/bad`, `elf/bench`, `elf/native`).
They are small programs that once miscompiled, run with `tools/probe.sh`, which compiles one
of them and diffs the native answer against the interpreter's in about three seconds.

    tools/probe.sh elf/probe/f168-and-tail.wat

| probe | what it pins |
|---|---|
| `f168-and-tail.wat` | a self tail call as the last operand of an `and`. Before C-196 the generator compiled it as a loop while `:c::tail-self?` answered false, and the loop never ended. |
| `f168-and-tail-vec.wat` | the same shape reading a vector. **This one did not crash** -- it exited 0 and printed `false\|false` where the interpreter prints `true\|false`. A silently wrong answer is the reason this directory exists. |
