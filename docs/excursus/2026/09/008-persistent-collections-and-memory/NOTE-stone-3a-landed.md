# NOTE — excursus 008 stone 3a landed: the count comes down, placed correctly and checked

2026-09-28. Nine rounds (`WEIGH-stone-3-rescoped.md`, `SCORE-stone-3-the-drop.md`). Struck by Grok (rounds 1-2)
and, while Grok was out of credits, Claude Sonnet (rounds 3-9); weighed by Claude Opus.

**The orchestrator's gates, on its own runs:** `WAT_DROP_CHECK=1 tools/verify.sh` → `verify: ok` — the compiler
compiles itself under the underflow check (392,489 bytes, stage1 == stage2) and the whole corpus runs under it
with zero underflows; `tools/verify.sh` → `verify: ok` (370,551 bytes). `elf/probe/drop-*.wat` agree both ways
(`drop-cons.wat` is 3b's: no terminator without drop glue).

**What the stone is.** Every reference dies somewhere and there the compiler emits its drop, through one
emission (`:c::emit-drop` → `:c::drop-hex`). A check build (`WAT_DROP_CHECK=1`, read once per compile into
`:c::Prog/dchk`) makes every decrement refuse a count below one and end with `wat: reference count underflow`,
exit 70. Nothing is freed yet (3b): a count at zero changes nothing but in-place growth, which a count of 1
licenses.

**The roots it took, each a class:** stale register/frame reloads (R1); F-208, one evaluation order, the head
after the arguments (R4); an untracked `push` shifting rsp-relative locals, now the `tools/rsp.sh` gate (R7);
a consuming built-in's box used at the call, not where it sits (R9); a name's value leaving through an `if`
arm or a body's tail uncounted — `:c::expr-val` (R16); a read-only parameter's uncounted pass-through
dropped again by a nested `if` (R20). Tooling: the build stamp removed before `elf/out` is touched (R13).

**How the last two were found** — two native hops for an instrumented compiler (a `--fast` seed decides
stage 1's code), and a hardware watchpoint on an object's count word (`probe-3a-twohop-step.sh`, round 7).

**Next:** 3b — drop glue per type (a worklist for recursive types) and freeing to the bump when youngest; then
the bench against `BENCH-baseline.md` and the compiler's cost against stones 1 and 2.
