# BRIEF — excursus 008 stone 3b-3a: the worklist, and glue for recursive types

> Freeing, reuse and the retention sites have landed: the compiler peaks at ~56 MB. A RECURSIVE type still has no glue,
> so dropping a 100,000-cell list frees one cell and leaks the rest (`drop-3b-list` holds ~79 MB). This strike gives every
> recursive type glue that walks in a LOOP: an intrusive worklist threaded through dead objects' count words, with no
> allocation and no stack growth (the builder: drops "synchronous and iterative", memory "very close to what rust feels
> like"). Closures ride on the same worklist next, as 3b-3b, briefed after this one is weighed.

## YOU ARE NEW TO THIS — read first

1. `CRAWL-stone-3b-3.md` (this directory). It has the probe table, the shape (§3), the check build's one-signed-guard
   change (§4), and why closures wait for 3b-3b (§1–2).
2. `elf/compile.wat`, the drop path:
   - `:c::dropchk-hex` (`:4485`): the zero test, then `push rax; call glue; pop rax`, the free, the poison. The member
     drop site changes here.
   - `:c::countchk-hex` (`:4393`): the increment guard.
   - `:c::glue-addr` (`:4956`): what every drop site asks.
3. `elf/compile.wat`, the census and placement. **The stub and the drain live here:**
   - `:c::shape-children` (`:5113`), `:c::cyclic?` (`:5146`), `:c::gtys-from-shapes`, `:c::gtys-from-vecs` (`:5167`),
     `:c::glue-census` (`:5188`).
   - The five always-present pseudo routines: `closize` (`:5401`) is the cascade idiom to copy for dispatch on `k`, and
     `:c::pseudo-addr` (`:5414`), `:c::free-target` (`:5437`).
   - `:c::glue-body` (`:5689`), `:c::glue-pass` (`:5713`), `:c::glue-place` (`:5725`).
   - Where `:c::compile-as` builds `gtys`/`gaddrs` (`:10796`–`:10819`).
4. `elf/lib/runtime.wat`: the `r14` header (`:2660`–`:2790`, `:c::hdr-census-alloc` `:2709`, `:c::hdr-buf` `:2783`). The
   two worklist words go here. Also `:c::poison-count` (`:2823`) and `:c::rt-uflow` (`:2494`).
5. Prior comparable: `BRIEF-M2-the-allocator-reuses-holes.md` / `SCORE-M2-the-allocator-reuses-holes.md`. That strike
   widened the header the same way and added always-present pseudo routines.

## THE WORK

- **W1 — members.** Every type `t` with `(:c::cyclic? t pg)`, whether `rec:`, `henum:` or `vec:`, is a MEMBER with an
  index `k`. Fill the census from declarations, once, before pass one, as `gtys` is. Today `:c::gtys-from-shapes` drops
  cyclic shapes, and `:c::gtys-from-vecs` keeps every `vec:X`, cyclic or not. Afterwards every member has two entries:
  - its STUB, which is what `:c::glue-addr` answers;
  - its BODY: today's `rec`/`henum`/`vec` glue body for that type, unchanged, which only the drain calls. A `vec:`
    member keeps its `node:X` helper.
- **W2 — the worklist.** Two header words, zero-filled: the head and busy. A PENDING word is
  `(1 << 63) | (k << 47) | next`, with `next` the following pending object or 0.
  - **The stub:** `k` into a scratch register, then jump to `pend`.
  - **`pend`**, with `rax` the dead object: write the pending word to `[rax-8]` and make `rax` the head. If busy,
    return. Otherwise set busy and loop:
    1. Pop the head and decode `k` and `next`.
    2. `push` the object, call body `k`, `pop` it.
    3. Free it (plain build; `:c::free-target` of member `k`'s type) or poison it (check build).
    4. Repeat until the head is 0, then clear busy and return.
  - `pend` and its dispatch are one more always-present pseudo routine, dispatching on `k` with the `closize` cascade
    idiom.
- **W3 — the member drop site.** In `:c::dropchk-hex`, when `t`'s glue target is a member, the zero path is the stub
  call alone: no `free-hex` and no `poison`, because the drain owns both. Every other type's path stays byte-identical.
- **W4 — one signed guard (check build).** A count word that is not live is NEGATIVE: poison −1, or a pending word.
  - The decrement guard becomes `cmp [rax-8], 1; jl uflow`, replacing the equality test and the `jb`.
  - The increment guard becomes `cmp [rax-8], 0; jl uflow`, replacing the equality test.
  - Say in the comments why one sign test covers both sentinels, and why the literal 0 still reaches the literal guard.
- **W5 — fixtures.** Add these to `elf/probe/`:
  - `probe-3b3-tree.wat` as `drop-3b-tree.wat`;
  - `probe-3b3-mutual.wat` as `drop-3b-mutual.wat`;
  - a check-build MUTANT that decrements an object while it is pending (for example a second decrement emitted after
    a member's stub call), run only to see the stop, then reverted.

## SKETCH

```
member stub k:      mov r11, k ; jmp pend
pend (rax = dead):  mov r8, [r14+WL_HEAD] ; mov r9, k<<47|1<<63 (from r11) ; or r9, r8 ; mov [rax-8], r9
                    mov [r14+WL_HEAD], rax ; cmp qword [r14+WL_BUSY], 0 ; jne done
                    mov qword [r14+WL_BUSY], 1
loop:               mov rax, [r14+WL_HEAD] ; test rax, rax ; jz idle
                    mov r9, [rax-8] ; (next = r9 & (2^47-1)) -> [r14+WL_HEAD] ; (k = (r9>>47) & 0xffff)
                    cascade on k:  push rax ; call body_k ; pop rax ; call free_k | poison ; jmp loop
idle:               mov qword [r14+WL_BUSY], 0
done:               ret
```

The registers are illustrative. The contract is that `pend` clobbers only what glue plus free already clobber: `rax`,
`rdx`, `r8`–`r11`.

## GATES

- Every `elf/probe/drop-*.wat` (except `drop-cons.wat`), plus `f209-*`, `m2-region-collision` and `r3-*`, agrees via
  `tools/probe.sh` and via `WAT_DROP_CHECK=1 tools/probe.sh`.
- The five fixtures in the crawl's table run with `ulimit -s 256`.
- `tools/rsp.sh` and `tools/reads.sh` are green.
- Native chains run plain and check, three hops (seed → s1 → s2 → s3), because this changes what is EMITTED.
- `tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`.

The scorecard is `EXPECTATIONS-stone-3b-3a-the-worklist.md`.

## STOP TRIGGERS

- **STOP-1** — a heap pointer at or above `2^47` is ever seen. The encoding's premise is false, so report the address.
- **STOP-2** — a member body must call another member's BODY directly, rather than reach it through a stub. The
  member/stub split is wrong.
- **STOP-3** — the check build stops on a fixture or in the self-compile at a root you cannot name.
- **STOP-4** — the compiler's OWN types turn out to include a member. That isn't wrong, but the 2026-09-28 census said
  none, so name them before the self-compile depends on the worklist.

## METHOD

- **Branch and commits.** Work on main at `6ae2fb7` or later notes-only commits. The tree stays dirty; commit nothing.
- **Running and checking.**
  - `timeout -s KILL` on every run.
  - No `_` and no catch-all.
  - Assert every text replacement.
  - Never read an exit code through a pipe.
  - Never re-run a red.
- **Where you work.**
  - No git in the holon root, and no worktrees.
  - Long-lived sandboxes go in `/var/tmp` (`/tmp` is a tmpfs and a reboot wipes it).
- **Running verify.** `tools/verify.sh` takes about 30 min each: run it with `nohup`, then repeat
  `timeout 590 tail --pid=<PID> -f /dev/null`.
- **Who over-drops.** A gdb hardware watchpoint on `[p-8]`, under `setarch -R`.
- **Finishing.** Write `SCORE-stone-3b-3a-the-worklist.md` here AS YOU GO, then `pulsare_yield kind=scored`.
