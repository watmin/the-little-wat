# WEIGH — excursus 008 stone 3b-3a: the worklist

## Round 1 (2026-10-03), against Grok's dirty tree on `271c768`

**Read.** I traced `:c::pend-glue-body` by hand.
- **Linking.** It refuses an object, and an old head, at or above `2^47`. It builds `(1<<63) | (k<<47) | head` into
  `[rax-8]`, makes the object the head, and returns when busy.
- **Draining.** Otherwise it sets busy, pops the head, and stores `next` back BEFORE the body runs. It recovers `k`
  (`shr 47; and 0xffff`), dispatches through the `closize`-style cascade (push, call `mbody:`, pop, then free or
  poison), and loops. When the head is 0 it clears busy. An unknown `k` stops.
- **Ordering.** `:c::member-k` (the count of `mbody:` entries before a type's own) and `:c::members-of` (the cascade's
  order) agree.
- **Scope.** `elf/refuse-*.wat` are `tools/gen-refuse.sh`'s regenerated copies of `elf/compile.wat`. The real diff is
  `compile.wat`, `lib/runtime.wat` (the two header words), `lib/x86.wat` (`:c::cc-less`, 12) and three `tools/reads.sh`
  ALLOW rows, each reading the allocator header or a dead object's count slot.

**My runs** (binaries built as `tools/probe.sh` builds them; `taskset -c 2`, three runs):

| row | mine | the score's |
|---|---|---|
| 1 — 36 fixtures, plain and check | **72 / 72 `agree`** | 72 |
| 2 — list peak RSS | 5,948 · 4,988 · 3,956 KB (was 78–80 MB) | 4,600–5,792 |
| 3 — tree | 7,764 · 8,456 · 7,560 KB (was 141–142 MB) | 7,248–8,000 |
| 4 — mutual | 4,632 · 5,352 · 5,332 KB (was 79 MB) | 4,224–5,716 |
| 5 — closure, closure-chain (3b-3b's) | 6,568 · 5,944 · 7,456; 47,012 · 48,700 · 48,320 KB | unchanged, as predicted |
| 6 — `ulimit -s 256` | all five exit 0, same answers | same |
| 7 — census, list | 2,000,000 `vec_new`; 2,000,000 `free.record.youngest`; `live_bytes 0` | same |

| 11 — `tools/verify.sh` | `verify: ok`: fixpoint 610,494; elf-run ok; rules 0 conflicts in 16,864 pairs; types 0 in 32,217 nodes | same |
| 11 — `WAT_DROP_CHECK=1` | bootstrap ok, fixpoint 738,709; `SKIP_BUILD=1 elf-run` on that stamp `ok`, with the same rules and types lines | same |

(Both of my first verifies were killed by MY one-hour `timeout` at `tools/rules.sh`, after bootstrap and elf-run had
passed. Stage 0 took 54–58 min with the machine shared. The check half was finished on its stamp, and the plain half
re-run whole.)

The cascade works as `CRAWL-…-freeing.md` §4 drew it. Every record is freed as the YOUNGEST, so the bump rewinds cell by
cell; there are no free-list pushes and nothing is given up.

**Two things fail Honest:**

- **R1 — the `2^47` refusal names the wrong cause.** Both refusals in `pend` jump to `:c::at-uflow`, so a heap
  address above the encoding's range would print `wat: reference count underflow`. It is a different fact. The rule is
  that every stop names its own cause, as `wat: heap exhausted` does. Give it a named stop of its own, for example
  `wat: heap address beyond the worklist's 47 bits`, exit 70, through the `:c::rt-abort` shape `:c::rt-oom` uses.
- **R2 — F-212, found weighing row 7.** The census's `heap.hiwater_bytes` is the heap top at EXIT, not the high-water
  mark. Its comment's premise ("`r15` only ever grows") has been false since 3b-2's youngest free. The list fixture
  prints `0`. Keep a running maximum of `r15` in the CENSUS build only, so the plain build stays byte-identical. Or
  rename the line to what it measures. Say which, and why.

R1 is new code in this stone; R2 is a discovered defect, and the builder's rule fixes those before building on them.
Both are small. The landing follows round 2's gates (the brief's: fixtures both ways, the native chains,
both verifies).

**Round 2's ground.** The shared wat binary was rebuilt at wat-rs `89e3d49cd` before this round. That build carries
FxHash for the interpreter's name maps, the lookup without its discarded provenance clone, and the deftest deadline
stopgap; it is −13% instructions on wat-rs's `call-heavy` and unobservable by contract. Its first stage 0 is a test
of that contract: every binary must come out byte-identical. Record stage 0's milliseconds in the SCORE as a data
point; the last plain stage 0 was 2,885,078 ms on a shared machine.

## Round 2, weighed — LANDED (2026-10-04)

**Read.** Both refusals in `pend` jump to `:c::at-range`, and an unknown `k` still jumps to underflow. The census's
`:c::census-note-top` compares unsigned and only raises the stored mark; it is emitted only in census builds. No bump
site passes `r10` as `top` (all 17 checked: `r11`, `rcx` or `rsi`).

**My runs** on this tree, wat-rs `89e3d49cd`:
- 36 fixtures × plain and check: 72 / 72 agree.
- `tools/verify.sh`: `verify: ok`, at a fixpoint of 612,458 bytes.
- `WAT_DROP_CHECK=1 tools/verify.sh`: `verify: ok`, at a fixpoint of 740,885 bytes, matching Grok's. Rules: 0
  conflicts in 16,903 pairs. Types: 0 in 32,296 nodes.

Stage 0 on the FxHash wat-rs build was 2,891,543 ms (Grok's run) and 2,310,572 ms (mine, check build). The machine was
shared both times, so the speedup is not established by wall time.

**3b-3a lands.** Recursive types drop in a loop with a flat stack: list 79 MB → 4–6 MB, tree 141 → 8 MB, mutual 79 → 5
MB. One signed guard refuses both poison and a pending link. F-212 is closed. Next in this excursus is 3b-3b (closure
glue on the worklist).
