# NOTE — excursus 008: freeing and reuse landed (3b-2, M2, the census, R3)

2026-10-02. The builder: *"i see no reason not to land it - it feels like it makes sense we have more instructions
because we are doing more stuff"*.

**What landed:** a count reaching zero frees the object — to the bump when it is the youngest, otherwise onto a
size-class free list (exact multiples of 8 small, powers of two large) linked through its count word; every
allocation goes through one door (`:c::rt-bump`), which takes from the lists first. The region release (C-120,
`push r15` / `pop r15` per statement) is RETIRED — it collided with the lists (`elf/probe/m2-region-collision.wat`).
`WAT_HEAP_CENSUS=1` is a diagnostic build that counts allocation, free and reuse by routine, kind and allocating
function. R3: a built-in that reads a non-Symbol temporary drops it after the read (`:c::drop-if-last`, and
`:c::cat-fold`'s read operands).

**The orchestrator's measurement — main's compiler (`956b4bb`) vs this one, both compiling main's tree:**

| | main | landed | change |
|---|---:|---:|---:|
| peak RSS (KB) | 446,156 – 446,324 | 298,232 – 298,460 | −33% |
| user instructions | 6.233 – 6.237 B | 8.416 – 8.417 B | +35% |
| user cycles (pinned P-core) | 2.849 – 2.889 B | 3.400 – 3.421 B | +19% |
| compiler binary | 410,790 B | 529,502 B | +29% |

**Gates, the orchestrator's runs:** `tools/verify.sh` → `verify: ok` (529,502 bytes); `WAT_DROP_CHECK=1
tools/verify.sh` → `verify: ok` (634,126 bytes).

**Still never freed (the census, R3):** `:c::buf-add` (~115 MB — old versions of the code-buffer Vector) and `rd/add`
(~76 MB — the reader's arena) whose counts never come down; `:c::patch` (~31 MB); closures (no glue — 3b-3); a
self-recursive type (no worklist — 3b-3). Pages are never returned to the OS (M4): RSS is still a high-water mark.

**Next, the builder's order:** the two retention sites (`buf-add`, `rd/add`) → 3b-3 (closure glue, the worklist) →
M4 (pages back) → a performance stone.
