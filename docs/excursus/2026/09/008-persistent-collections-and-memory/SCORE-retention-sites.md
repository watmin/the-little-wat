# SCORE — excursus 008: the two retention sites

The census still charges `:c::buf-add` and `rd/add` for bytes that are live at exit. R1 names
what still holds them. The census-on header keeps a live count per site per kind, and a live
count plus one payload address per record type. A record constructor stamps its type into the
high half of the site word. A copying `assoc` stamps the copy. An in-place `assoc` finds the
stamp already there and does not count the object again. At exit the report prints
`skind <kind> <count>` for each nonzero kind under a site, and `hold` / `holdn` / `holda` for
each record type whose live count is not zero.

The run below is the census-on compiler before the owning-`assoc` change. `/tmp/ret-b.elf` is
673,288 bytes. `setarch -R`, the flag unset at the run because the stamps are already in its
code. Stderr is `/tmp/ret-census.err`.

## The kind line

The first print of those kind counts was `r11` after `syscall`, not the counter. Linux writes
the saved `rflags` into `r11`: 514 is `0x202`, 530 is `0x212`. `:c::census-skind` had the count
in `r11`, tested it, then called `:c::rt-say-stderr`. The zero test was real, so which kinds a
site printed was real. The printed count was not. Hold lines were already real: that count is
copied to `r13` before any `write`.

Parking the count under the short message does not work. `:c::abort-chunks` stores a 5–7 byte
tail as a whole quadword, and `"skind record "` is 13 bytes, so the store lands on a count
that was pushed just above the reserved frame and clears it. The count is parked in `r8`,
which `:c::rt-say-stderr` and `:c::rt-say-int-stderr` leave alone, and moved back to `rax`
for the integer print. `r10` cannot hold it: that register is the site-table length the
back-edge compares.

## The hold names

The first hold table walked the name blob with the same index as the counter. The type id
stamped into a record is the record index plus one, so slot 0 of the counter array is always
zero and every printed name was the next record's name. The length word at payload+0 is the
field count and named the objects the printer had mislabelled: a 28-field record is
`:c::Prog`, a 6-field record is `:rd::St`, a 2-field record is `:c::Buf`. The walker now
loads the counter and the sample at `+8`, so name `i` pairs with type id `i+1`. The kind
table was never shifted. The names below are from the run after that correction. The blob
prints `rec::c::Out` because the prefix is the characters `rec:` joined to the record's own
spelling `:c::Out`.

`holda` is the payload of the newest stamp of that type. It is stale when that newest
object was freed later. The watched object below was chosen by reading a live count word in
the heap dump, not by subtracting 8 from a printed `holda`.

## R1 — what is live at exit

Totals, `/tmp/ret-census.err`:

| | |
|---|---:|
| alloc_count | 13,435,463 |
| alloc_bytes | 821,142,296 |
| reuse_bytes | 355,277,864 |
| free_count | 10,797,074 |
| free_bytes | 489,668,760 |
| pushed_bytes | 356,542,576 |
| free_list.remaining_bytes | 1,264,712 |
| live_bytes | 331,473,536 |
| hiwater_bytes | 358,645,480 |

The two charged sites, live objects still attributed to them:

| site | live bytes | kinds |
|---|---:|---|
| `:c::buf-add` | 116,915,816 | record 280,685; flat_vector 101,059; trie_vector 244,013; trie_node 340,225 |
| `rd/add` | 77,190,728 | record 83,227; owned_vector 552; trie_vector 73,676; trie_node 255,966 |

Around them: `:c::patch` 31,480,976 (string 18,860; record 1,014; flat_vector 4,348);
`:c::mknode-ty` 14,378,896 (record 11,410; flat_vector 132; trie_vector 9,834; trie_node 47,931);
`:c::buf-fold` 8,221,088 (string 16,873); `:c::last-leaf` 7,285,264;
`:c::emit` 6,050,408 (record 58,177); `rd/seq` 5,002,720 (string 24,264);
`:c::popn` 2,110,160 (record 20,290); `:c::push` 294,592 (record 2,830);
`:c::buf0` record 5,248 and flat_vector 5,248.
`:c::buf-add` records plus `:c::buf0` records are 285,933 allocations of a `:c::Buf`.
285,928 of them are still live. `:c::census-holds` and `:c::census-walk` allocate about
2.48 MB and 1.79 MB while printing; they are not the retention.

Live records, same file. A type absent from this list has a zero count (PassR, GPassR, CZ,
HG, BindR among them):

| record | live | newest payload (`holda`, may be stale) |
|---|---:|---:|
| `:rd::Node` | 89,414 | 140637636596472 |
| `:rd::St` | 2,282 | 140637636595360 |
| `:c::Buf` | 285,928 | 140637821880160 |
| `:c::Cap` | 22 | 140637477127992 |
| `:c::Out` | 100,732 | 140637821346680 |
| `:c::Bind` | 20,969 | 140637820181352 |
| `:c::Bnd` | 15,902 | 140637820463512 |
| `:c::Fn` | 7,077 | 140637730156984 |
| `:c::Rec` | 86 | 140637623221072 |
| `:c::Enum` | 13 | 140637530787104 |
| `:c::Alias` | 32 | 140637622965560 |
| `:c::Src` | 101 | 140637622826576 |
| `:c::Prog` | 12,098 | 140637820227216 |
| `:c::TC` | 63,792 | 140637821344440 |
| `:c::Use` | 20,972 | 140637819493584 |
| `:c::NodeR` | 1,440 | 140637636601920 |

The sum of live record-kind counts across sites equals the sum of these hold counts.

## One count word

Hardware watch of one live object under `setarch -R` in gdb. The dump is
`/tmp/ret-heap.bin`, mapping base `0x7fe8b6604000`, 400 MB, from the compiler one printer
fix earlier (673,268 bytes). Log `/tmp/ret-gdb-buf.log`. The process exited normally.
1,887 hits.

The object is an `:rd::St`, type id 2, not a `:c::Buf`. Payload
`140637636590120`, count word `140637636590112`. The site word is `0x2000003f9`: type 2,
site index 1017. Length word 6, node field −1, which is what `rd/stop` writes. Birth is
`movq $1, (%r15)` in the copying allocator (`pc=0x48f016`, value 1). The count then
oscillates between 1 and 2 for the whole compile. The floor stays 1. The last writes take
it through 2, 3, 4 and back down. The last hit is `pc=0x488412`, value 1. It never reaches 0.

Those PCs are that older binary. The printer fix inserted 20 bytes after `0x427d00` and
before the free walk, so a PC at `0x47a975` or `0x488412` is 20 bytes higher in
`/tmp/ret-b.elf`. The early `inc` at `0x427c67` (`mov 0xd0(%rax); incq -8(%rax)`) is the
same instruction in both. The assoc change in this score is later still; these PCs are the
compiler before that change.

The 1↔2 pairs are a temporary share of one field and a drop of that temporary. The
instruction before the increment is `mov 0xd0(%rax)` or `mov 0xd0(%rbx)`. Field 25 of
`:c::Prog` is `src`, and 25×8 plus the length word is `0xd0`. The matching decrement is
the record-drop of a Prog, which walks `otys` (`0xc0`), `oorgs` (`0xc8`), then `src`.
That drop takes this St from 2 to 1. One other Prog still holds it. The net of each
share/drop pair is zero. The surviving count is the Prog that still points at this St.

## Who points

`/tmp/ret-parents` scanned that same 400 MB dump. It accepts a record whose site word has
a type id in 1..29, a site index ≤ 4096, a count in 1..5,000,000, and a length word in
1..40. 620,842 records. The scanned count of each type equals that dump's header counter
(Node 89,408, St 2,282, Buf 285,920, Out 100,732, Prog 12,098, NodeR 1,440). Those header
counters are a handful below `/tmp/ret-census.err` for Node, Buf, and TC. The pointer
classes are from this dump.

| watched | live in the dump | who points | unreachable, count still > 0 |
|---|---:|---|---:|
| `:rd::St` (type 2) | 2,282 | `:c::Prog` field 25 (`src`) × 12,098 | 0 |
| `:c::Buf` (type 3) | 285,920 | `:c::Out` field 1 × 100,732 and field 2 × 100,732 | 173,138 |
| `:c::Out` (type 5) | 100,732 | no record field | 100,726 |
| `:c::Prog` (type 13) | 12,098 | `:c::NodeR` field 0 × 1,440 | 10,960 |

Edges minus count, for Buf: −1 on 173,138, 0 on 110,700, +1 on 2,082. The −1 bucket is
exactly the orphan count, so those Bufs have count 1 and no qword in the dump equal to
their payload. For Out: ≤ −2 on 22, −1 on 100,704, 0 on 6. For Prog: ≤ −2 on 8,992, −1 on
2,478, 0 on 628. For St: 0 on 2,279, +1 on 1, ≥ +2 on 2, and none below 0. St counts match
the Prog/`src` pointers. 12,098 Progs and 2,282 Sts is about five Progs sharing each St.
89,414 Nodes and 2,282 Sts is the reader's arena, about 39 nodes per St.

Out's two Buf fields are 201,464 slots. They cannot account for 285,928 live Bufs. The
rest are the orphans: a slot was overwritten and nothing dropped the old Buf. The Outs
that still point at Bufs are themselves unreachable, with a positive count, so those Bufs
are only reachable from garbage. NodeR holds 1,440 of the Progs. The other Progs have no
record pointer and still hold their `src` Sts.

This is not data the compiler has to keep. Each `:c::compile` returns nil. A Prog's `src`
would be legitimate only for a Prog that was still reachable. These Progs and Outs are not.

## R2 — the class

The holder is the owning `assoc`. `:c::linear?` treats a parameter as linear when it occurs
once, or when its only write is as the receiver of `assoc` / `conj` / `concat` and nothing
reads the name after that write. `:c::assoc-form` then took `:c::at-slot-own`
(`:c::rt-slot-set-own`).

That entry compares the count with 1. When the count is 1 it stores the new value over the
slot and leaves the old value's count untouched. When the count is anything else it falls
into the copying `slot_set` and returns the copy. The owning path did not `:c::drop-saved`
the source afterwards (`drop?` is the negation of `own?`). The copying path increments
pointer fields of the copy and does not drop the source either; the compiler's non-owning
path is what drops the source, once, or twice when the binding's own reference is also last.

`:c::emit` is `(assoc (assoc o :code (buf-add (Out/code o) hex)) :rax "")`. Inside `emit`
the name `o` is read only before the write, so it is linear there. The caller `push` uses
`o` again (`Out/sp`), so the caller increments before the call and `emit` takes the owning
path on a record whose count is 2. Two results, and they are the two piles in the scan:

- Count 1, the caller moved the only reference. The store overwrites `:code` or `:tail`
  and the old `:c::Buf` stays at count 1 with no pointer. Those are the 173,138 orphan Bufs.
- Count greater than 1, the caller kept a reference. The owning path returns a copy and
  does not drop the reference this call holds. The source `:c::Out` stays at a positive
  count after the caller drops its own pointer. Those are the unreachable Outs, and they
  still point at their Bufs. The same shape on `:c::Prog`/`src` is the unreachable Progs,
  which is why the Sts stay live: every live St is still stored in some Prog.

`:c::buf-add` builds a new `:c::Buf`. Its argument is not a write-head receiver, so the
leak of the Buf record is the later overwrite, not `buf-add` forgetting the argument while
an Out still holds it. `rd/add` builds a new `:rd::St`. Replacing `:c::Prog`/`src` with
`assoc` is the same owning update. Conj and concat were left as they are. The runtime
entry `:c::rt-slot-set-own` is still in `elf/lib/runtime.wat`; `assoc` no longer calls it.

The owning path in `:c::assoc-form` now branches on the count itself. Count 1 and a pointer
field: save `rax`/`rcx`/`rdx`, load the old slot, `:c::emit-drop` of that field's type,
restore, then store the new value. Count not 1: the copying `slot_set`, then
`:c::drop-saved` once. The census type stamp stays after the join. It is idempotent, and
the new field value was already counted by the expression that produced it. A non-pointer
field skips the drop and still takes the copy when the count is not 1.

`elf/probe/drop-assoc-own.wat` is that shape and nothing else. `user/step` reads the field
it replaces and never reads the record again, so four steps update one Box in place and
must drop each displaced string. `user/both` prints the original record's string after the
update, so that update has to copy: an in-place store would make the first printed line
`ab!!!!z`. The three lines are `ab!!!!`, `ab!!!!`, `ab!!!!z`.

| run | result |
|---|---|
| `tools/probe.sh elf/probe/drop-assoc-own.wat` | agree, exit 0 |
| `WAT_DROP_CHECK=1 tools/probe.sh elf/probe/drop-assoc-own.wat` | agree, exit 0 |
| same probe compiled by the interpreter with `WAT_HEAP_CENSUS=1`, then run | stdout the same three lines, exit 0 |

The census of that run (`/tmp/ret-fix-probe.err`): alloc_count 8, alloc_bytes 240,
free_count 8, free_bytes 240, live_bytes 0, hiwater 72. One `vec_new` (the Box) and one
`slot_set` (the shared update in `user/both`). Six `str_cat` allocations: the initial
heap string, four `!` steps, and the `z`. Both records were freed (one youngest, one
pushed) and all six strings were freed. No `hold` line. The Box and the strings it
displaced are at zero live.

### Recount after the owning `assoc` (`/tmp/ret-fix-census.err`)

The same chain, seed `/tmp/ret-seed.elf`, then a census-off compiler, then a census-on
compiler, then that binary with the flag unset under `setarch -R`. All three stages
exited 0. This binary does not contain the cond drop below.

| | before | after owning `assoc` |
|---|---:|---:|
| alloc_count | 13,435,463 | 13,521,486 |
| alloc_bytes | 821,142,296 | 831,123,704 |
| reuse_bytes | 355,277,864 | 479,812,344 |
| free_count | 10,797,074 | 11,801,091 |
| free_bytes | 489,668,760 | 593,024,856 |
| pushed_bytes | 356,542,576 | 481,077,976 |
| live_bytes | 331,473,536 | 238,098,848 |
| hiwater_bytes | 358,645,480 | 257,935,968 |

`:c::buf-add` 47,901,488: record 286, flat_vector 40, trie_vector 67,172, trie_node 166,189.
`rd/add` 77,445,248: record 83,444, owned_vector 552, trie_vector 73,894, trie_node 256,838.
`:c::buf0` record 8 and flat_vector 8. `:c::emit` 18,512 (record 178). `:c::push` 480
(record 2). `:c::patch` 20,131,472 (string 10,412; record 24; flat_vector 104).
`:c::mknode-ty` is still 14,378,896 (record 11,410). `:c::no-tail` 4,404,672 (record 61,176).

| record | before | after |
|---|---:|---:|
| `:c::Buf` | 285,928 | 292 |
| `:c::Out` | 100,732 | 200 |
| `:rd::St` | 2,282 | 2,282 |
| `:c::Prog` | 12,098 | 12,106 |
| `:c::TC` | 63,792 | 64,024 |
| `:rd::Node` | 89,414 | 89,632 |
| `:c::NodeR` | 1,440 | 1,440 |
| `:c::Use` | 20,972 | 20,972 |

The orphan Buf records and the unreachable Out records are gone. What `:c::buf-add` still
charges is the tries inside the Bufs that remain. `rd/add`, the Sts, the Progs, and the
TCs did not move. `:c::mknode-ty` is the same 11,410 records: `pg` is not linear there,
because a later field read follows the inner write, so that update never took the owning
path. The owning `assoc` is the class for the orphan Bufs and Outs. It is not the class
for the Progs or the St arenas.

### The silent `cond` clause

`:c::drop-arm` runs from `:c::if-cmp` and `:c::if-form` only. `:c::cond-form` is not
lowered to `if`. It compiled each clause as a test, a `jz`, a body, and a `jmp`, and
dropped nothing for a name the body does not mention. `:c::expr` is one `cond`. Its
integer and symbol arms return an Out and never mention `tc`. `(:c::no-tail)` allocates
a fresh `:c::TC` for every non-tail subexpression, and 61,176 of the 64,024 live TCs are
charged to `:c::no-tail`.

The drop now sits at the start of each clause body, and on the path where every clause
has failed, before `mov rax, 0`. A pointer binding is dropped when it is not scalarised,
the clause does not mention it at all (`:c::occ-sum` from the test, or the fall-through),
some other clause body contains a last use, and it is not read-only unless another
clause body leads to a self call. A use that lives only in a clause test is left alone:
that test already dropped it when it was the last use, and dropping again on a body that
did not run would free it twice. A name the test mentions is kept too. `:c::form` binds
`head` to the node's text and mentions it in the test; dropping that string freed the
text the next clause still had to read. `:c::leads-self?` is called as `[node pg]`.

`elf/probe/drop-cond-arm.wat` is that shape. `user/pick` returns 1, 2, or 4, thirty
times, so the lines are 30, 60, and 120. `user/miss` takes an `:else` that does not
mention the record and returns 0. The interpreter's `cond` requires a terminal `:else`,
so the probe has one; the native compiler also emits the exhausted-clause path, and a
fixture without `:else` (`/tmp/ret-cond.wat`) printed the same `30/60/120/0` with
live_bytes 0.

`elf/probe/drop-cond-arm.wat`, `/tmp/ret-bump.wat`, and `elf/probe/drop-ronly-arm.wat`
agreed both ways while the predicate was `:c::ptr-ty?` and `:c::occ-sum` started at the
test. The native compiler the seed emitted for `drop-cond-arm.wat` was byte-identical
to the interpreter (4,332 bytes). The type list now in `:c::cond-name-dead?` does not
match `:user::TC`, so that agreement is the general rule, and the fixture has to be
run again once the shipped predicate covers a user record.

A compiler whose own `:c::expr` and `:c::form` were emitted with that general drop
stops on `elf/src/fn-rec.wat`. Stderr is `compile: cannot compile call: (f 2)`. That
is `:c::fn-ty?` failing on the head, before the argument `2` is compiled. The same
compiler had already verified `fn-box.wat`, `fn-vecpass.wat`, `closure-nested.wat`,
`fnref.wat`, and `fn-vec.wat`. The seed that emits the drop, and the census build it
produces, both exit 0; the compiler that *contains* the drop exits 70. Log
`/tmp/ret-cond-census.err`. A one-stage build cannot test a predicate change: the
seed's baked `:c::cond-form` is what emits the drops, and the seed predates them, so
the first output's own `expr` and `form` still have no drop. `/tmp/ret-tc.elf` was
that mistake (the all-pointer generator compiling a TC-only source) and is not a
TC-only result.

Two stages from `/tmp/ret-seed.elf` are the test. The seed compiles the restricted
source into stage 1 (the generator emits the restricted drop; stage 1's own `expr`
does not drop). Stage 1 compiles the same source into stage 2 (stage 2's `expr`
drops). Running stage 2 is the self-compile.

Dropping only `"rec::c::TC"` self-compiles. Stage 2 is `/tmp/ret-t2.elf` (546,138
bytes), exit 0, `compile: ok`. Census `/tmp/ret-tc-census.err` (built by stage 1 with
`WAT_HEAP_CENSUS=1`, run under `setarch -R` with the flag unset): live_bytes
235,924,376; hiwater 255,445,832. `rd/add` 77,966,176. `:c::buf-add` 48,141,024.
`:c::no-tail` 980,928 (record 13,624). `:c::mknode-ty` 14,378,896 (record 11,410).
Holds: Node 90,078; St 2,282; Buf 292; Cap 4; Out 200; Bind 21,175; Bnd 16,000;
Fn 7,082; Rec 86; Enum 13; Alias 32; Src 101; Prog 12,140; TC 14,454; Use 21,236;
NodeR 1,440. About 47,000 of the `:c::no-tail` TCs are gone. The ones that remain
are the clauses that mention `tc` and pass it on (the list arm of `:c::expr`, and
`let` / `if` / `call` in `:c::form`). `rd/add`, the Sts, the Progs, and the Buf tries
stay.

Adding `"rec::c::Prog"` also self-compiles. `/tmp/ret-pg2.elf` is 548,448 bytes
(code 490,659, data 47,150), exit 0, `compile: ok`. Census
`/tmp/ret-pg-census.err`, same method: alloc_count 13,579,736; alloc_bytes
836,417,488; reuse_bytes 484,110,840; free_count 11,900,492; free_bytes 600,146,448;
pushed_bytes 485,377,480; free_list.remaining_bytes 1,266,640; live_bytes
236,271,040; hiwater 255,796,440. `rd/add` 77,975,520 (record 83,898; owned_vector
552; trie_vector 74,348; trie_node 258,654). `:c::buf-add` 48,262,864 (record 286;
flat_vector 40; trie_vector 67,856; trie_node 167,417). `:c::emit` 18,512.
`:c::no-tail` 981,408 (record 13,626). `:c::mknode-ty` 14,339,952 (record 11,326).
Holds: Node 90,086; St 2,240; Buf 292; Cap 4; Out 200; Bind 21,175; Bnd 15,994;
Fn 6,940; Rec 86; Enum 13; Alias 32; Src 101; Prog 11,973; TC 14,454; Use 21,236;
NodeR 1,440.

Against the post-assoc census, TC 64,024 became 14,454 and Prog 12,106 became
11,973. St 2,282 became 2,240. Out stayed 200 and Buf stayed 292. NodeR stayed
1,440. `rd/add` stayed near 78 MB and `:c::buf-add` stayed near 48 MB. Most `pg`
occurrences sit in the taken clause, so the silent drop rarely fires for a Prog.
The 1,440 Progs in NodeR are a field store. The St arenas are the `src` of the
Progs that stay live. The tries `:c::buf-add` still charges sit in the 292 Bufs
inside the 200 Outs. The list is a bisect, not the rule the fixture needs:
`:user::TC` is `rec::user::TC`.

Adding `"rec::c::Out"` also self-compiles. Stage 2 is `/tmp/ret-out2.elf`,
548,802 bytes, exit 0, `compile: ok` (`/tmp/ret-out2-run.log`). Census
`/tmp/ret-out-census.err`, built by stage 1 with `WAT_HEAP_CENSUS=1`, run under
`setarch -R` with the flag unset: alloc_count 13,583,789; alloc_bytes
836,641,600; reuse_bytes 484,231,072; free_count 11,904,323; free_bytes
600,340,392; pushed_bytes 485,497,712; free_list.remaining_bytes 1,266,640;
live_bytes 236,301,208; hiwater 255,831,912. `rd/add` 77,984,864 (record 83,906;
owned_vector 552; trie_vector 74,356; trie_node 258,686). `:c::buf-add`
48,274,832 (record 286; flat_vector 40; trie_vector 67,856; trie_node 167,461).
`:c::no-tail` 980,928 (record 13,624). `:c::mknode-ty` 14,339,952 (record
11,326). Holds: Node 90,094; St 2,240; Buf 292; Cap 4; Out 200; Bind 21,175;
Bnd 15,994; Fn 6,940; Rec 86; Enum 13; Alias 32; Src 101; Prog 11,973; TC
14,454; Use 21,236; NodeR 1,440.

Out stayed 200. Buf stayed 292. Prog stayed 11,973. St stayed 2,240. The silent
clause does not see these: the taken clause still names `o` and `pg`.

The heap of that census run, dumped at `exit` under `setarch -R` (base
`0x7fe8b6604000`, first 512 MB, `/tmp/ret-heap-out.bin`), scanned by
`/tmp/ret-parents-out`. Scanned counts match the hold table (Out 200, Buf 292,
Prog 11,973, St 2,240, NodeR 1,440).

| watched | live | who points | no pointer in the dump |
|---|---:|---|---:|
| `:c::Buf` | 292 | `:c::Out` field 1 × 200 and field 2 × 200 | 0 |
| `:c::Out` | 200 | no record field | 198 |
| `:c::Prog` | 11,973 | `:c::NodeR` field 0 × 1,440 | 10,833 |
| `:rd::St` | 2,240 | `:c::Prog` field 25 (`src`) × 11,973 | 0 |
| `:c::NodeR` | 1,440 | no pointer at all | 1,440 |

Edges minus count: Buf is balanced (291 at 0, one at ≥ +2). Out is −1 on the
198 with no pointer and 0 on the other two (those two pointers sit outside any
record). NodeR is −1 on all 1,440, so each has count 1 and nothing points at
it. Prog is ≤ −2 on 8,785, −1 on 2,560, 0 on 628. Every St is a live Prog's
`src`. Every Buf is a live Out's `code` or `tail`. The NodeRs are the only
record parents of a Prog, and they are unreachable themselves, so the Progs
they point at are unreachable too. The tries `:c::buf-add` still charges are
the Bufs inside the 200 Outs. The bytes `rd/add` still charges are the arenas
inside the 2,240 Sts, held by the Progs.

A fixture of `:c::mknode-ty`'s nested `assoc` (`/tmp/ret-mk.wat`, thirty calls,
census on) prints 30 and reports live_bytes 0. A tail-recursive `let` that
reads the bound record in the recursive argument (`/tmp/ret-pass.wat`) prints
465 and reports live_bytes 0. Those shapes drop.

### The short-circuit operand

`:c::last-walk` walks an `and` or an `or` as a sequence, so the consuming drop
is placed in a later operand. `:c::and-form` jumps over that operand when the
value in rax is already the answer. `/tmp/ret-and.wat` is thirty fresh records
whose only use sits in the skipped operand: before the drop, live_bytes 1,680
and 30 `:user::Box`; after it, live_bytes 0.

The drop runs on the jump, for a record the current operand does not mention,
when a later operand holds a last use. A name the operand mentions may be the
value rax is about to return (`or`). All pointer types on that edge segfault
the compiler that contains them: `/tmp/ret-ao2.elf` dies at `mov 0x8(%rdi,%rax,8),%rax`
with `rdi` zero, inside the trie walk. Restricting the edge to types that start
with `rec:` self-compiles. Stage 2 is `/tmp/ret-ar2.elf`, 554,750 bytes, exit 0,
`compile: ok`. Census `/tmp/ret-ar-census.err`: live_bytes 236,166,968; hiwater
255,694,760. `rd/add` 78,302,320 (record 84,177; owned_vector 552; trie_vector
74,628; trie_node 259,774). `:c::buf-add` 48,541,632 (record 288; flat_vector
40; trie_vector 68,054; trie_node 168,411). `:c::no-tail` 983,664 (record
13,662). `:c::mknode-ty` 13,707,120 (record 9,230). Holds: Node 90,366; St
1,612; Buf 292; Cap 4; Out 200; Bind 21,251; Bnd 16,028; Fn 6,955; Rec 86;
Enum 13; Alias 32; Src 101; Prog 9,985; TC 14,494; Use 21,288. NodeR is absent.

Against the Out-drop census, NodeR 1,440 became 0, Prog 11,973 became 9,985,
and St 2,240 became 1,612. Out stayed 200 and Buf stayed 292. `rd/add` and
`:c::buf-add` did not come down: the remaining Progs still hold the St arenas,
and the 200 Outs still hold the Bufs. The user-record fixture still drops,
because `:user::Box` is a `rec:`.

The heap of that census run (`/tmp/ret-heap-ar.bin`, base `0x7fe8b6604000`,
first 512 MB) scanned with the same parent walk. Scanned counts match the hold
table: Out 200, Buf 292, Prog 9,985, St 1,612, NodeR 0.

| watched | live | who points | no pointer in the dump |
|---|---:|---|---:|
| `:c::Buf` | 292 | `:c::Out` field 1 × 200 and field 2 × 200 | 0 |
| `:c::Out` | 200 | no record field | 200 |
| `:c::Prog` | 9,985 | no record field | 9,982 |
| `:rd::St` | 1,612 | `:c::Prog` field 25 (`src`) × 9,985 | 0 |
| `:c::NodeR` | 0 | | 0 |

Every Out has count 1 and nothing points at it. 1,472 Progs are the same
(count 1, no pointer). The other 8,513 Progs also have no pointer, and their
counts run from 2 up to 426,223 on one record: those references were
incremented and then abandoned. Three Prog pointers sit outside any record.
Every Buf is still an Out's `code` or `tail`. Every St is still a Prog's
`src`, and 9,985 `src` slots share 1,612 arenas. The and/or drop removed the
NodeR parents. What remains has no parent left to drop.

### A discarded statement

`:c::seq` used to drop a discarded value only when its head was `concat`,
`subs`, `conj`, `assoc`, or `to-string`. A name is its binding's drop. Anything
else — a call, a constructor — was left at the count it was born with.
`/tmp/ret-do.wat` is thirty `(user/make i)` statements whose value is ignored:
before the drop, live_bytes 720 and 30 `:user::Box`; after it, live_bytes 0.
The first spelling of that drop asked `:c::type-of` of every non-symbol
non-final form and dropped it when the answer started with `rec:` (and, before
that, when the answer was any pointer). Both spellings fail the same way, and
the failure is the question, not the decrement. `:c::type-of-form`'s last arm
refuses with `a call this pass does not know`. `elf/bench/parse.wat` is a `do`
whose first statement is `wat.os/poke`. Stage 2 of each chain exits 70 at that
form, line 18 column 7, after compiling `elf/bench/tripleclamp.wat`. The
all-pointer stage 1 is `/tmp/ret-ds1.elf`. The `rec:` stage 1 is
`/tmp/ret-dr1.elf`. Neither was run again.

The drop now names the record from the head and does not call `:c::type-of`.
A constructor's type is `rec:` joined to the head. A known function contributes
`:c::Fn/ret` when that starts with `rec:`. A builtin, including `wat.os/poke`,
contributes nothing, and the five heads that already dropped still use their
own type. The head-only spelling, compiled by the interpreter, still frees the fixture:
stdout `0`, live_bytes 0, hiwater 0, probe code 519.

That compiler self-compiles. Stage 2 is `/tmp/ret-dq2.elf`, 556,043 bytes,
`compile: ok`. Census `/tmp/ret-dq-census.err` (`/tmp/ret-dq-b.elf`, 692,236
bytes): live_bytes 236,487,200, hiwater 256,035,544. Against the and/or census
(236,166,968) the holder did not fall. Out 200, Buf 292, St 1,612. Prog 9,985
became 10,009. Node 90,492, Bind 21,273, Use 21,452, Bnd 16,050, TC 14,506,
Fn 6,960. The discarded direct call is a real leak, and it is not these bytes.

The heap of that run is `/tmp/ret-heap-dq.bin`, base `0x7fe8b6604000`. Every
one of the 200 Outs has count 1. 178 were allocated in `:c::emit` and 22 in
`:c::patch`. They pair: 100 with `base` 0 (pass one) and 100 with a real base
and the same code length, tail length, `sp`, and `fk`. 98 of those shapes are
distinct. On the pass-one half, `sp` is 8 for 69 of them, so the copy was taken
while one value was still pushed. Nothing in the dump points at them. Their
`code` and `tail` are still every live Buf.

### A silent cond clause, every record

`:c::cond-name-dead?` had been three spellings, `rec::c::TC`, `rec::c::Prog`,
and `rec::c::Out`. `:user::TC` is none of those. The same test `:c::and-name-dead?`
uses is `rec:`. Dropping every pointer, which is wider than that, is the
compiler that died on `(f 2)`. `elf/probe/drop-cond-arm.wat` under that prefix, compiled by the interpreter,
prints `30`, `60`, `120`, `0` and reports live_bytes 0, hiwater 40. Stage 2 of
the compiler that contains it is `/tmp/ret-dc2.elf`, 556,029 bytes, `compile:
ok`. The census-on run of `/tmp/ret-dc-b.elf` is SIGSEGV, exit 139, while
compiling `elf/bench/tripleclamp.wat` (the previous file, `triple2.wat`, had
been printed). The faulting instruction is `mov r12, [r9]` in a free-list pop,
and `r9` is -1. A word on the unwind is `0x6c6961662d79743a`, the bytes
`:ty-fail`. The prefix is wider than the free list can stand. The source keeps
the three names.

`elf/probe/drop-assoc-own.wat`, compiled by the interpreter from this
source, agrees both ways. Plain and `WAT_DROP_CHECK=1` both print
`ab!!!!`, `ab!!!!`, `ab!!!!z` and exit 0.

### A call's result, named

`:c::assoc-form`'s owning arm bound the nested call as `called` and then
built the drop around that name. The name is a second use, so the call's
result was shared before the drop saw it. Both arms now pass the call
straight into `:c::drop-saved`. A one-file assoc no longer reports an
`:c::Out`. On the whole tree the same edit moves the holders that the
owning `assoc` had left (`/tmp/ret-dq-census.err` against
`/tmp/ret-called-census.err`):

| | named `called` | call inside the drop |
|---|---:|---:|
| live_bytes | 236,487,200 | 236,309,728 |
| hiwater_bytes | 256,035,544 | 255,847,488 |
| `:c::Out` | 200 | 22 |
| `:c::Buf` | 292 | 44 |
| `:rd::St` | 1,612 | 1,612 |
| `:c::Prog` | 10,009 | 10,009 |

`:c::buf-add` 48,489,272 and `rd/add` 78,444,816 after it. The 22 Outs are
still count 1 with nothing pointing at them. Each is a `:c::patch` copy
(stamp low half 432), length 11, and the code Buf still ends in the
unpatched `e9 00 00 00 00`. Un-naming the join in `:c::if-cmp`,
`:c::if-form`, and `:c::cond-form` fixpointed and left Out at 22. That
edit was reverted.

### The match base case

`elf/src/shapes.wat` compiled alone reproduces the 22 as one Out per pass.
`/tmp/ret-shapes.err`, `/tmp/ret-shapes2.err`, `/tmp/ret-shapes3.err`, and
`/tmp/ret-shapes4.err` each hold `:c::Out` 2 and `:c::Buf` 4, live_bytes
2,726,912. The program is 54,385 bytes, code 519. Un-naming the arm's
patched Out, and a one-mention `:c::patch-jmp`, leave those two holds
where they are. The base case of `:c::match-arms` was the bare parameter
`o`. That arm is shrink-wrapped: `:c::wrap-head` emits it as an early
return, and the early return increments the parameter. The other arm
still holds the reference, so the join copies and the unpatched buffer
stays.

The base case is now `(:wat::core::let [moved o] moved)`. A `let` is not
a wrap value, so this arm is not an early return. `/tmp/ret-shapes5.err`:
no `:c::Out`, no `:c::Buf`, live_bytes 2,724,080, hiwater 3,289,144, the
same 54,385 bytes and code 519. `:c::TC` 8 became 6. `:rd::St` stays 1
and `:c::Prog` stays 14.

The whole tree, seed `/tmp/ret-called2.elf`, three stages, the last two
identical at 556,871 bytes (`/tmp/ret-move-s3.elf`). Census-on
`/tmp/ret-move-b.elf` is 693,354 bytes. `/tmp/ret-move-census.err`, run
under `setarch -R` with the flag unset:

| | 22 Outs | after the `let` |
|---|---:|---:|
| live_bytes | 236,309,728 | 236,546,120 |
| hiwater_bytes | 255,847,488 | 256,100,312 |
| `:c::Out` | 22 | 0 |
| `:c::Buf` | 44 | 0 |
| `:rd::St` | 1,612 | 1,612 |
| `:c::Prog` | 10,009 | 10,021 |
| `:rd::Node` | 90,488 | 90,567 |
| `:c::buf-add` | 48,489,272 | 48,553,464 |
| `rd/add` | 78,444,816 | 78,537,088 |

No `hold` line for `:c::Out` or `:c::Buf`. `:c::buf-add` no longer charges
a record; it still charges 68,023 trie vectors and 168,502 trie nodes.
`rd/add` still charges 84,378 records. Live bytes and the high-water mark
went up. The compiler source grew (`:c::patch-jmp`, the `let`, and the
nodes those add), and that growth is larger than the Out and Buf payload
that was freed. `elf/out/compiler.elf` was restored to the 556,871
fixpoint.

### What still holds the arenas

The heap of the shapes run after the `let` is `/tmp/ret-heap-shapes6.bin`
(base `140637468901376`, 3,602,336 bytes). Out 0, Buf 0. One `:rd::St`,
born in `rd/tops`, count 14. Fourteen `:c::Prog` records, every one of
them storing that St in field 25 (`src`). Thirteen of the fourteen have
no qword in the dump equal to their payload. The fourteenth has one.
Their counts are 1, 1, 1, 3, 15, 24, 43, 43, 43, 58, 73, 162, and 186.
The references were incremented and then abandoned; the stack is gone at
exit. The St stays because those Progs stay.

On the whole tree the same pair is 1,612 Sts and 10,021 Progs. The byte
charge that remains on `rd/add` is those arenas. The trie charge that
remains on `:c::buf-add` is not a live Buf.

### A `let` that rebinds the name

The backward walk has one live-set slot per spelling. A `let` that binds
`b` again, `(let [b (assoc b :s …)] (use b))`, walks the body first. The
body's `b` is the inner record, and it puts the spelling into the live
set before the init is walked. The init's `b` is the outer record, and
it is never marked last, so the copy path increments it and drops it
once. The outer record stays at count 1.

`/tmp/ret-shadow.wat` is that shape: `user/go` rebinds its parameter and
prints the new string's length, `3`. Before the walk knew about `let`,
the census (`/tmp/ret-shadow.run.err`) was alloc_count 2, free_count 1,
live_bytes 56, one `rec::user::Box`. The inner copy was freed. The
parameter was not.

`:c::last-let` walks the body with every name that `let` binds removed
from the incoming live set, then walks the inits from last to first. A
later pair's init sees the earlier binding of the same spelling. The
first pair's init sees the name from outside the `let`, still live when
something after the `let` reads it. The binder itself is not a read.

`elf/probe/drop-shadow.wat` prints `3`. `tools/probe.sh` and
`WAT_DROP_CHECK=1 tools/probe.sh` both agree, exit 0. Compiled with
`WAT_HEAP_CENSUS=1` (`/tmp/ret-shadow2.run.err`): alloc_count 2,
free_count 2, live_bytes 0. No `hold` line. The same three-rebind,
three-call shape (`/tmp/ret-rebind.wat`) also ends at live_bytes 0.
`drop-assoc-own`, `drop-cond-arm`, and `drop-ronly-arm` still agree both
ways.

The compiler that contains the walk fixpoints. Seed
`/tmp/ret-move-s3.elf`, stages 559,277 then 559,292 and 559,292
(`/tmp/ret-let-s3.elf`). Census-on `/tmp/ret-let-b.elf` is 696,283 bytes.
`/tmp/ret-let-census.err`:

| | before the `let` walk | after |
|---|---:|---:|
| live_bytes | 236,546,120 | 237,160,624 |
| hiwater_bytes | 256,100,312 | 256,930,136 |
| `:c::Out` | 0 | 0 |
| `:c::Buf` | 0 | 0 |
| `:rd::St` | 1,612 | 1,612 |
| `:c::Prog` | 10,021 | 10,041 |
| `:c::buf-add` | 48,553,464 | 48,722,920 |
| `rd/add` | 78,537,088 | 78,975,088 |

`elf/src/shapes.wat` alone, compiled by that compiler with the flag set
(`/tmp/ret-shbox-on.err`): live_bytes 2,724,048, `:rd::St` 1, `:c::Prog`
14, `:c::buf-add` 61,776, `rd/add` 5,496. No Out, no Buf. The same 14
Progs and the one St are still there. The rebinding walk frees the
fixture's outer record. It does not free the compiler's Progs, and the
Sts stay because the Progs stay.

Every `elf/probe/drop-*.wat` except `drop-cons.wat`, plus `f209-*`,
`m2-region-collision`, and `r3-*`, agrees under `tools/probe.sh` and
under `WAT_DROP_CHECK=1 tools/probe.sh`. `drop-shadow` is in that run.
The native chain above is the plain fixpoint of this source. The check
fixpoint, `tools/verify.sh`, and the pinned RSS and cycle runs are not
in this file yet: the 1,612 Sts are still live.

### Where the fourteen Progs are born

The shapes heap after the `let` walk (`/tmp/ret-heap-shbox.bin`, base
`140637468901376`) still has one St, count 14, site `rd/tops`, and
fourteen Progs. The two hottest are count 184 and count 160, both
stamped `:c::compile-as`. A fixed watch on the Prog that
`:c::empty-prog` returns shows that object go 1 to 2 and back to 1 at
the copy immediately after the call. It is not the survivor.

Birth of a Prog is the `movabs` that ors type 13 into the stamp. In
`/tmp/ret-shbox/elf/out/compiler.elf` the count-184 object is the only
birth at `0x48b755`, the `:gaddrs` assoc that builds `pg0`, and it is
what pass one receives. The count-160 object is the only birth at
`0x48beb0`, the `:final` assoc passed to pass two. The four count-43
and count-58 objects are the four births at `0x4770df`, the last
`assoc` of `:c::compile-fn`'s rebinding, two functions times two
passes. Two of those four are stamped `:asm::nibble` and `:asm::le-pos`
because the return-address search landed there. The instruction that
allocates them is the compile-fn assoc.

A location watch on the 184 and the 160 (`/tmp/ret-inc.log`) gives the
program counter after each write of the count word. Most writes pair.
`:c::has-clone?` increments `pg` and `:c::kindv`, `:c::text`, or
`:c::kidsof` decrements it before returning. What does not pair, on
both objects, is `:c::any-clone?` at `+0xbd`: 190 increments of `pg`
before the call to `:c::has-clone?`, and the next write of that count
is not a decrement. `:c::lvl-scan` adds 174 more on the pass-one object
only.

`:c::any-clone?` is `(or (has-clone? (nth ks i) pg) (any-clone? ks … pg))`.
The later arm holds the last use, so the first arm shares. Shapes has
no `clone`, so `:c::has-clone?` returns false and the later arm does
run. The share is still there because `:c::has-clone?` itself never
drops `pg`. Its second clause is `((not= (kindv a pg) List) false)`.
The test mentions `pg`. The body does not. A later clause does, so the
test is not marked last and the call shares. Taking the clause skips
the later use.

`:c::cond-name-dead?` already drops a `rec::c::Prog` on a taken clause
when the clause does not mention it. The occurrence count starts at
the test, so a mention in the test suppresses the drop even when the
body never reads the name. That is the remaining root. The same clause
shape is `elf/probe/drop-cond-test.wat`.

The occurrence sum in `:c::cond-name-dead?` now starts at the body.
The type test is still only `rec::c::TC`, `rec::c::Prog`, and
`rec::c::Out`. Before that change, one call on the leak path
(`/tmp/ret-ctest-before2.run.err`) allocated 2, freed 0, live_bytes
56, and printed `hold rec::c::Prog`, stdout `0`. After it, the three
calls (the argument is 0, then 1, then 7) print

```
0
0
1
```

`/tmp/ret-ctest-after3.run.err`: alloc_count 6, free_count 6,
live_bytes 0, no hold line. The first call takes the body that reads
the record. The second takes the silent body whose test reads it. The
third takes `:else`. The compiler's own Progs are not in that run.

A compiler built by the previous seed still contains the old predicate, so
its own `:c::has-clone?` does not drop and a shapes run of that binary
(`/tmp/ret-ctbox-on.err`, heap `/tmp/ret-heap-ct.bin`) is the same fourteen
Progs at the same counts. The next compiler
(`/tmp/ret-ctfull/elf/out/compiler.elf`, 559,292 bytes) is this source
built by that seed. It then builds the census-on shapes compiler
(`/tmp/ret-ct2/elf/out/compiler.elf`, 687,119 bytes). Shapes still reports
`:rd::St` 1, `:c::Prog` 14, live_bytes 2,724,048
(`/tmp/ret-ct2-on.err`). The counts moved. The two `:c::compile-as`
objects went from 184 and 160 to 48 and 24. `:c::any-clone?`'s share is
no longer one of the refs still held. What is still held, from a
location watch (`/tmp/ret-inc2.log`):

| object | end count | refs still held |
| --- | --- | --- |
| `:c::compile-as` pass one, born `0x48ba76` | 48 | 21 `:c::lvl-scan+0x72`, 5 `:c::last-walk+0x297`, 4 `:c::last-kids+0x8d`, and smaller shares from `:c::compile-fn` and `:c::pass` |
| `:c::compile-as` pass two, born `0x48c1d1` | 24 | the same set without `:c::lvl-scan` |
| `:c::argreg-mark`, born `0x46ecb4` | 73 | 70 `:c::taken-scan+0x94`, 2 `:c::argreg-fns` |

Both `+0x72` and `+0x94` are the `incq` of `pg` at the self-call. The
parameter is not read-only — the same call also passes it to
`:c::lvl-node` or `:c::taken-kids` — so `:c::tail-share` increments it.
The frame then jumps. `:c::lvl-scan`'s base arm drops `pg` once, because
that arm does not mention it. `:c::taken-scan`'s base arm drops its two
vectors and returns the accumulator; it does not drop `pg`.

A user scan whose helper reads the record once
(`/tmp/ret-tscan-before`, `user/touch` returns the string length)
already prints `2` and frees: alloc 2, free 2, live_bytes 0. The
helper drops the record, and that drop cancels the self-call's share.
`:c::taken-kids` does not. Its own shares pair, and the scanner's
share stays.

Skipping that increment for every same-slot parameter, not only a
read-only one, is not the repair. A compiler emitted that way
(`/tmp/ret-ct3/elf/out/compiler.elf`) stops on `shapes.wat` with
`compile: unknown type: :user::Shape`. `:c::tail-share` still requires
the parameter to be read-only. The seventy `:c::taken-scan` shares and
the twenty-one `:c::lvl-scan` shares are still the refs the next edit
has to name without that blanket pass.

Three user programs, compiled by the interpreter from this source and
censused before any further edit. Each builds one `:c::Prog` and scans
it four steps. A helper that only passes the record through
(`/tmp/ret-scan-kids.wat`) frees: alloc 2, free 2, live_bytes 0. A
helper that reads the record in one arm and returns an integer
(`/tmp/ret-scan-head.wat`) also frees, and prints 8. The helper that
mentions the record in its recursive arm and then passes it in the
same slot (`/tmp/ret-scan-mention.wat`, `user/kids`) does not. The
scan prints 0. The census is alloc 2, free 0, live_bytes 56, `hold
rec::c::Prog` (`/tmp/ret-scan-mention.run.err`). That is the witness
for the next edit. The other two are the shapes that already cancel
the self-call's share.

That witness was the wrong class. `user/kids` reads one field and then
passes the record through, so the prologue loads the field into the
parameter register and the record pointer is gone before the base arm.
The two-field program (`/tmp/ret-scan-arm.wat`) does not do that. Its
helper's test reads one field and the arm taken when the test fails
returns 0. Before this edit the census was alloc 3, free 0, live_bytes
96, `hold rec::c::Prog`, and the answer was 2. The early return is
`:c::wrap-head`: the whole body is one `if`, the THEN arm is a literal,
and that arm is compiled before the frame exists. It emitted the
compare, the literal and `ret`, and never the arm drop `:c::if-form`
would have placed. `:c::taken-start` is that shape. Its non-list arm
returned 0 without dropping `pg`, and `:c::taken-kids`'s base drop
cancelled that share instead of `:c::taken-scan`'s.

`:c::wrap-head` now asks `:c::arm-dead?` with this function's own
last-use set. A drop widens the branch to four bytes; an arm with
nothing to drop keeps the one-byte branch. The same program then
prints 2 with alloc 3, free 3, live_bytes 0
(`/tmp/ret-scan-arm2.run.err`). The seventy `:c::taken-scan` shares
are still a shapes recount away: the compiler that emits
`:c::taken-start` has to be one that already contains this drop.

That recount is `/tmp/ret-wh2-on.err`. The seed `/tmp/ret-let-s3.elf`
(census off, 559,292 bytes) compiled this source into
`/tmp/ret-wh1/elf/out/compiler.elf` (560,215 bytes). That compiler, with
the census flag on, compiled the shapes-only main into
`/tmp/ret-wh2/elf/out/compiler.elf` (689,354 bytes). Running that binary
is the census. The first one it emitted segfaulted at `decq -8(%rax)`
with `rax` zero (`/tmp/ret-wh2-gdb.txt`, file offset `0x6cabe`). The
drop had reloaded a register parameter from its spill slot, and the
prologue that writes that slot had not run. The slot's displacement
collapsed onto the zero just pushed to save `rax`. `:c::drop-loaded`
now copies the argument register when `fk` is still zero. The same
two-stage run then prints `compile: ok` and

```
compile: elf/src/shapes.wat     -> elf/out/shapes.elf      54385 bytes   fns 2    code 519    data 0     verified
```

Live records are still `:rd::St` 1 and `:c::Prog` 14. live_bytes
2,658,112 (was 2,724,048). hiwater 3,229,968 (was 3,289,144). The
fourteen Prog count words, read from the heap at exit
(`/tmp/ret-wh-heap.bin`), sum to 192. They were 264. The difference is
72, all of it on the `:c::argreg-mark` record, whose count went from 73
to 1. That 72 is the unmatched stack from `/tmp/ret-inc2.log`: the
seventy `:c::taken-scan` shares and the two `:c::argreg-fns` shares.
The other thirteen counts are the same set, including the two
`:c::compile-as` records at 48 and 24. The twenty-one `:c::lvl-scan`
shares are still inside the 48. The one `:rd::St` is still live; its
count word is 14. The tree's `elf/out/compiler.elf` is still the
559,292-byte census-off binary.

`:c::lvl-scan`'s base does drop `pg`. The shares that stayed were the
ones `:c::lvl-head` never dropped. That function's only read of `pg`
is `(:c::Prog/recs pg)` in a later clause's test. A clause taken
before that test skips the read, and `:c::cond-name-dead?` only
treated a last use in some other clause's body as a reason to drop.
`/tmp/ret-lvl-head.wat` is that shape: it prints 10 with alloc 3, free
0, live_bytes 96, `hold rec::c::Prog`. The same shape with a use in
another clause's body (`/tmp/ret-lvl-node.wat`) already freed.

`:c::later-test-last?` is that later test. A clause drops when its
body does not mention the name and a later test holds the last use.
The fall-off end does not, because every test has already run. The
same program then prints 10 with alloc 3, free 3, live_bytes 0
(`/tmp/ret-lvl-head2.run.err`). Three calls, the early clause and the
clause whose test reads the record and the else, print 10, 18, 0 with
alloc 9, free 9 (`/tmp/ret-lvl-head3.run.err`).

The shapes recount of that source is another two-stage run.
`/tmp/ret-wh1/elf/out/compiler.elf` is 560,847 bytes and
`/tmp/ret-wh2/elf/out/compiler.elf` is 690,956. Shapes again prints
`compile: ok` and 54,385 bytes. `:rd::St` is still 1 and `:c::Prog` is
still 14. live_bytes stays 2,658,112 and hiwater stays 3,229,968,
because the records are still held. The fourteen count words now sum
to 159. They were 192. The 33 are two `:c::compile-as` records, 48 to
24 and 15 to 6. The third `:c::compile-as` record is still 24, and
`:c::argreg-mark` is still 1. The one `:rd::St` still has count 14.

`:c::and-name-dead?` dropped a record on an `and` or `or` jump only
when that operand did not mention the name. `:c::last-walk` puts the
last use in a later operand, and the jump is taken when that operand
does not run. An operand that mentions the record and returns a
machine word kept the caller's count: the mention is not the value in
rax. `/tmp/ret-or-mention.wat` is that shape. Before the change it
prints 1 with alloc 3, free 0, live_bytes 96, `hold rec::c::Prog`
(`/tmp/ret-or-mention2.run.err`). The same shape whose first operand
does not mention the record already freed (`/tmp/ret-or-silent.run.err`).
The predicate now also drops when the operand's type is not a pointer.
The same program then prints 1 with alloc 3, free 3, live_bytes 0
(`/tmp/ret-or-m3.run.err`). Both arms, the short-circuit and the later
operand, print 1 and 1 with alloc 6, free 6 (`/tmp/ret-or-both.run.err`).
An `or` whose first operand returns the record still holds it, alloc 3,
free 0, live_bytes 96, and it did that before this predicate too
(`/tmp/ret-or-id.run.err`, `/tmp/ret-or-id-old.run.err`). A plain return
of the same record frees (`/tmp/ret-or-id-plain.run.err`).

The shapes recount of that source: `/tmp/ret-wh1/elf/out/compiler.elf`
is 560,944 bytes and `/tmp/ret-wh2/elf/out/compiler.elf` is 694,407.
Shapes prints `compile: ok` and 54,385 bytes. `:rd::St` is still 1 and
`:c::Prog` is now 10. It was 14. live_bytes 2,656,336 (was 2,658,112)
and hiwater 3,220,920 (was 3,229,968). The ten count words sum to 124.
They were 159. `:c::compile-as` is 16, 16, 6, and 1. It was 24, 24, 6,
1, and 1: one count of 1 was freed and the two 24s are 16. `:c::compile-fn`
is 23 and 10. It was 26, 13, and 1, and that 1 was freed. `:c::argreg-mark`'s
1 was freed. `:asm::le-pos` is 38. It was 41, and a second record at
that site with count 1 was freed. `:asm::nibble` is 10 (was 13).
`:c::inl-fns` is 1 (was 4). `:c::argreg-clear` is still 3. The one
`:rd::St` has count 10. It was 14. The tree's `elf/out/compiler.elf` is
still the 559,292-byte census-off binary.

The St's count is one `src` share per live Prog. The heap of that shapes
run (`/tmp/ret-wh-heap.bin`, base `0x7fe8b6604000`) has ten Progs and one
`:rd::St`. Every Prog's field 25 is that same St. `rd/tops` already drops
its input. The St falls when the Progs fall.

The two `:c::compile-as` records at count 16 are the `:gaddrs` assoc and
the `:final` assoc. A watch on each (`/tmp/ret-inc3.log`) leaves the same
fifteen increments: four in `:c::last-kids`, two in `:c::pass`, six in
`:c::compile-fn`, two in `:c::last-walk`, and one in `:c::value-head?`.
The value-head share is the call to `:c::op-head?`. The `acc-index` clause
increments `pg` and then decrements it once on the way into `variant-tag`.
That decrement meets the `acc-index` share. `:c::acc-index` reads only
`(:c::Prog/recs pg)`, so the prologue keeps that field and never drops the
pointer. The caller's increment has nothing to meet it.

`:c::borrowed-param?` rebuilds the callee's scalar set the way
`:c::compile-fn` does. A scalarised parameter is passed without an
increment. When that argument is also the caller's last use,
`:c::drop-borrows` drops it after the call returns. An indirect call has
no callee and still shares. `/tmp/ret-scalar-or.wat` is the shape: the
callee returns before the field read, and a later `or` operand still
reads the record. Before the change it prints 1 with alloc 3, free 0,
live_bytes 96, `hold rec::c::Prog`. After it, the same program prints 1
with alloc 3, free 3, live_bytes 0 (`/tmp/ret-scalar-or2.run.err`). A
last use that is only that call prints 2 with alloc 2, free 2
(`/tmp/ret-scalar-last.run.err`). The short-circuit, where the later
operand does not run, prints 1 with alloc 3, free 3
(`/tmp/ret-scalar-true.run.err`). The earlier `or` mention, the wrap-head
arm, and the lvl-head fixture still free.

The shapes recount of that source: `/tmp/ret-wh1/elf/out/compiler.elf` is
564,016 bytes and `/tmp/ret-wh2/elf/out/compiler.elf` is 697,849. Shapes
prints `compile: ok` and 54,385 bytes. There is no `hold` line for
`:c::Prog`, `:rd::St`, or `:c::Src`. live_bytes is 2,648,816 (was
2,656,336) and hiwater is 3,218,816 (was 3,220,920). `:c::compile-as` no
longer charges a record. It was five. `:c::compile-fn` no longer charges
a record. It was two. `:asm::nibble`, `:asm::le-pos`, and
`:c::argreg-clear` are absent. `rd/add` is 3,432 bytes and 61 records. It
was 5,496 and 87. `:c::buf-add` is still 61,776 trie bytes and still not
a live Buf. What remains is `:rd::Node` 61, `:c::Bind` 14, `:c::Fn` 8,
and `:c::Enum` 1. The tree's `elf/out/compiler.elf` is still the
559,292-byte census-off binary.

### The five arena generations

The 61 nodes were five owned vectors, lengths 1, 5, 13, 29, and 61, blocks
32, 64, 128, 256, and 512. Each had count 1 and nothing pointing at it.
They are the generations `rd/add` abandoned. `rd/add` is `(conj arena
(Node ...))`. The node is allocated before the conj, so the arena is not
the youngest block, and a full owned block takes path 4 of
`:c::rt-vec-conj-own`: copy into a new owned vector and return the copy.
The copy inherited the source's elements, and the source was never freed.
The St's own arena was the length-87 vector in the next block, and the St
drop already freed that one. These five were orphans before the borrow.

Path 4 now frees the source after `rep movsq` and does not run
`:c::count-copied`. Paths 2 and 3 are the same bytes. The heap top the
bump left in `r11` is kept in `rsi` for the commit; `r15` during the copy
is the new block, so the youngest test compares the source's end with
`rsi`. The census credit for that free addresses `kind * 48` as a byte
offset (lea scale 1). A scale of 8 wrote into the site table and the
fixture never returned. With the scale corrected, the copy tail still
committed `r11` after the free had reused that register, so the heap
top became a free-list slot and the fixture still never returned.
`rsi` is the top from the moment the copy finishes.

`/tmp/ret-arena.wat` grows a vector to 14. Before the free, stdout was 14
and live_bytes was 248. After it, stdout is 14, live_bytes is 0, and
alloc_bytes equals free_bytes at 840 (`/tmp/ret-arena-after.run.out`,
`/tmp/ret-arena-after.run.err`). The empty flat is one pushed free of 24.
The three overflowed owned blocks are pushed frees of 224. The last owned
block is the youngest free of 256. One `vec_new` reused the 24-byte hole.

The shapes census of this source (`/tmp/ret-wh2-on.err`, logs kept beside
it as `pre-path4`): stage 1 is 569,229 bytes, stage 2 is 704,014, shapes
prints `compile: ok` and 54,601 bytes. There is no `hold` line for
`:rd::Node`. `rd/add` is absent. It was 3,432 bytes, 61 records, and 5
owned vectors. live_bytes is 2,648,304 (was 2,648,816). hiwater is
3,222,264 (was 3,218,816); the compiler is holding a larger
`:c::rt-vec-conj-own`, 13,952 string bytes where it was 2,432.
`:c::buf-add` is still 61,776. What remains is `:c::Bind` 14, `:c::Fn` 6
(was 8), and `:c::Enum` 1. `rd/empty-kids` is 144 bytes and 6 flat
vectors (was 1,800 and 75). `rd/kids-of` is 1,216 bytes and 16 owned
vectors (was 2,784 and 52). The tree's `elf/out/compiler.elf` is still
the 559,292-byte census-off binary.

The drop probes agree, plain and with `WAT_DROP_CHECK=1`: every
`elf/probe/drop-*.wat` except `drop-cons.wat`, plus both `f209-*`,
`m2-region-collision`, and the three `r3-*` (64 runs, `/tmp/ret-probe-gates`).
`tools/reads.sh` and `tools/rsp.sh` are clean. `tools/copies.sh` names
`rt-vec-conj-own` as the copy that keeps the counts by freeing the source,
and its planted uncounted copy still fails.

`tools/bootstrap.sh --fast` does not fixpoint. The old seed (559,292)
compiles this source to a 569,229-byte compiler (`/tmp/ret-a.elf`, also
`elf/out/stage1.elf`). That compiler's shapes binary matches the
interpreter byte for byte and prints `0`, `7`, `42`. The compiler it
then emits is 574,199 bytes (`/tmp/ret-b.elf`). Running it faults in a
trie load through a null child (`movq 0x8(%rdi,%rax,8), %rax` at
`0x47ff5c`, `rdi` = 0) or hangs before the first flushed line. The
census-off arena fixture still prints 14. `elf/out/compiler.elf` is
restored to the 559,292-byte seed. The self-host is the open gate.

### The promotion trie

The paragraph above, that `--fast` does not fixpoint and that
`elf/out/compiler.elf` was restored to 559,292, records the tree at the
path-4 edit. The self-host has since closed. What follows is the rest of
the same holder.

`rd/add` conjs a `:rd::Node` onto the arena. A flat vector that the owned
path has extended past `:c::arr-max` (8) promotes on the next copying
conj. `vec_conj` called `tree_from_arr`, which pushes every element of
that flat into a fresh trie and drops each trie it replaces, then jumped
to `tree_push` for the new element. `tree_push` copies the trie it is
given. Nothing dropped the trie `tree_from_arr` returned. Its count stayed
1, and the heap scan found no pointer to the header except the header's
own root field. The leaf under it still held the elements, so their counts
stayed at 1 after every later copy of the arena had been freed.

On the load-file run that was one promotion whose flat length was 12: one
trie vector, one trie node, twelve `:rd::Node` records. The same shape is
what `:c::buf-add` still charged after the earlier drops (one trie vector
and one trie node per abandoned promotion). The watched header was
`0x7fe8b6665f60` on the binary before this edit (`/tmp/ret-prom-load`,
713,340 bytes, `setarch -R`). At `tree_from_arr`'s `ret` (`0x4989d8`, the
breakpoint in `/tmp/ret-len12.py`) its count was 1, the caller was
`0x4989f3`, and the count word was never written again (`writes 0` in
`/tmp/ret-len12.txt`). At exit the twelve element counts were 1. Birth
counts on those elements were 2.

`vec_conj` now calls `tree_push` and then drops that trie with the glue
and free the conj site already passed in `r11` and `r8`. The flat source
is still the caller's drop. The length test's short branch skips the whole
of that sequence (63 bytes) and lands on the flat copy.

Load-file census after the drop (`/tmp/ret-prom-run.err`, `compile: ok`,
`one.elf` 13,847 bytes): no `hold` line for `:rd::Node`, no `rd/add`, no
`:c::buf-add`. live_bytes 651,000 (was 776,232 with the twelve nodes).
hiwater 1,063,928 (was 1,184,096). What that run still holds is `:c::Bind`
303, `:c::Bnd` 144, `:c::Fn` 124, `:c::Rec` 4, `:c::Enum` 2, `:c::Alias` 2.
No Out, no Buf, no St, no Prog.

The same runtime on shapes (`/tmp/ret-rc-shapes.err`): `compile: ok`,
6,803 bytes. No `:rd::Node`, no `rd/add`, no `:c::buf-add`. live_bytes
139,744, hiwater 205,280. `:c::Bind` 14, `:c::Fn` 6, `:c::Enum` 1, the
record counts the path-4 shapes census already had. `many.wat`
(`/tmp/ret-rc-many.err`): `compile: ok`, 2,547 bytes, no `:rd::Node`.
live_bytes 223,272, hiwater 351,488, `:c::Fn` 3.

Full-corpus census (`/tmp/ret-selfc.err`, the census compiler run from a
copy so it could write `elf/out/compiler.elf`): `compile: ok`, compiler
584,491 bytes. No `:rd::Node`, no `rd/add`, no `:c::buf-add`. live_bytes
57,013,544. hiwater 84,767,656. The live records are `:c::Bind` 30,717,
`:c::Bnd` 14,042, `:c::Fn` 5,528, `:c::Rec` 86, `:c::Enum` 13, `:c::Alias`
32, `:c::Use` 106,334. Those are the compiler's own tables at the end of
compiling itself. They are not the two sites.

### Gates

`tools/reads.sh`, `tools/copies.sh`, and `tools/rsp.sh` are clean
(`/tmp/ret-reads.log`, `/tmp/ret-copies.log`, `/tmp/ret-rsp.log`; the rsp
exception is still line 8856, the prologue's own `push rbp`). The probe
list is every `elf/probe/drop-*.wat` except `drop-cons.wat`, both
`f209-*`, `m2-region-collision`, and the three `r3-*`: 32 plain and 32
with `WAT_DROP_CHECK=1`, all agree (`/tmp/ret-probes-status.txt`).

`tools/bootstrap.sh --fast` from the 574,794 seed differs on 47 of 102
binaries and does not fixpoint (`/tmp/ret-boot1.log`). That is the one
spurious differ a runtime change produces. The second `--fast` fixpoints:
stage 2 equals stage 3 at 584,491 bytes, 102 binaries identical
(`/tmp/ret-boot2.log`). `WAT_DROP_CHECK=1 tools/bootstrap.sh --fast`
fixpoints on the first pass at 702,794 bytes (`/tmp/ret-check1.log`). The
plain compiler was back at `elf/out/compiler.elf` before the R3 runs;
the check compiler is `/tmp/ret-check-fp.elf`.

`tools/verify.sh` (interpreter stage 0, 2,510,338 ms, then the native
stage): stage 1 equals stage 2 at 584,491 bytes, 102 binaries identical,
then `verify: ok`. elf-run: 103 native binaries, 54 agree with the
interpreter, 3 syscall-only, 11 refusals and 4 traps both ways, rules 0
conflicts in 16,504 pairs, types 0 conflicts in 31,598 nodes
(`/tmp/ret-verify1.log`).

`WAT_DROP_CHECK=1 tools/verify.sh` (`/tmp/ret-verify2.log`): interpreter
stage 0 in 3,008,104 ms, compiler 702,794 bytes. Stage 1 equals stage 2 at
702,794, 102 binaries identical. elf-run is the same agreement as the
plain run (103 native, 54 agree, 3 syscall-only, 11 refusals, 4 traps,
rules 0 in 16,504, types 0 in 31,598). `verify: ok`.

That check verify left the 702,794-byte compiler on disk. One plain
`tools/bootstrap.sh --fast` seeded from it (`/tmp/ret-boot-restore.log`)
fixpoints at 584,491: 103 binaries in 6,703 ms, stage 1 in 6,263 ms, 102
identical, stage 2 equals stage 3. That is `elf/out/compiler.elf` now.

### R3

Census-off compiler `/tmp/ret-fp-now.elf` (584,491 bytes, the plain
fixpoint), cwd `/tmp/ret-r3` (this tree, via symlinks to the current
`elf` sources, not the `956b4bb` snapshot), three runs, `taskset -c 2
perf stat -e instructions:u,cycles:u` around `/tmp/maxrss`. Each run exits
0. The compiler left in the sandbox is 584,491 bytes and matches
`/tmp/ret-fp-now.elf`.

| | this source | NOTE-M2-landed |
| --- | --- | --- |
| peak RSS (KB) | 78,144 – 78,788 | 298,232 – 298,460 |
| user instructions | 13.161848074 – 13.161848990 B | 8.416 – 8.417 B |
| user cycles (pinned P-core) | 4.984 – 5.125 B | 3.400 – 3.421 B |

The instruction and cycle counts are `cpu_core` (the atom counters did not
count). RSS is `ru_maxrss`. The rise against M2 is the whole retention
series since that note, measured on this binary, not an attribution to the
promotion drop alone. Runs: `/tmp/ret-r3-1.perf` and `.rss` through `-3`
(78,388 / 78,144 / 78,788 KB; instructions 13,161,848,990 / 13,161,848,304
/ 13,161,848,074; cycles 5,125,027,385 / 4,994,839,989 / 4,984,258,500).

Self-compile census of the two sites, same source: `rd/add` absent,
`:c::buf-add` absent, live_bytes 57,013,544, hiwater 84,767,656.

## Round 2 (2026-10-02)

The three-name gate in `:c::cond-name-dead?` is gone. The clause drop
applies to every `rec:` that is not scalarised. Strings, vectors, and
functions stay out: `(wat.core/length (wat.core/conj v 99))` faults when a
clause drop meets the temporary `conj` already consumed. `tools/verify.sh`
was not re-run; the round-1 `verify: ok` covers the 584,491 / 702,794
compilers.

### R1 — the second drop

The general `rec:` rule freed a block the compiler was still using, then
decremented the free-list link that the free had written into the count
word. The pop of that link is the fault. On the plain compiler that
contains the rule (`/var/tmp/ret-r2/stage2-584910.elf`, 584,910 bytes) it
is `mov (%r9), %r12` at `0x482530`, the shared free-list pop. `r9` was
`0x7fe8b8ecfd98ff` (a pointer minus one), `r10` was the 32-byte slot at
`r14+0x28`, and the caller was `:c::use-field`. `:c::Use` is the two-field
record the three names left out.

`:c::use-union` is the shape. Its fourth test is
`(= (Use/f a) (Use/f b))`. No later body mentions `b`, so that field read
is a last-use node and `:c::drop-if-last` decrements `b` while the test is
evaluated, whether the compare succeeds or not. The compare of two
different fields fails, and the `:else` body does not mention `b`. Another
clause returns `b`, so the body drop fired too. The first decrement freed
the record. The second wrote `link-1` into the count word. The next
`:c::use-field` popped it.

A last use in this clause's own test still suppresses this clause's body
drop (`:c::last-in-sub?`). A last use in an earlier test now suppresses it
as well (`:c::earlier-test-last?`), including on the fall-off, which has
run every test. A test that only mentions the name, with the use still
ahead, still drops. `elf/probe/drop-cond-test.wat` agrees both ways
(`0|0|1`). `elf/probe/drop-cond-arm.wat` agrees both ways (`30|60|120|0`),
which is the `:user::TC` the three names did not cover. A witness of
`:c::use-union` (`/var/tmp/ret-r2/use-union.wat`) agrees both ways
(`2|1|2|1|9`).

`WAT_DROP_CHECK=1` does not stop this bug. The poison count is −1, and the
guard is `cmp [rax-8], 1; jb` (unsigned), so −1 does not trip. The check
build also does not free, so the corrupted link is never popped. The
check-on compiler that contained the old general rule
(`/var/tmp/ret-r2/B-check.elf`) printed `compile: ok` for that reason.
The plain compiler is the one that shows the fault.

The compiler that contains the fix reproduces itself. The 584,491 seed
compiled the new source to 585,202 bytes; that compiler compiled it again
to 585,593 and printed `compile: ok`, including `tripleclamp.wat` and
`compile.wat`. A second run of the 585,593 binary wrote 585,593 again.
The two output directories, 92 binaries, are identical
(`/var/tmp/ret-r2/fix1`, `/var/tmp/ret-r2/fix2`). `elf/out/compiler.elf`
is that binary.

### R2 — the two fixtures

`elf/probe/drop-shadow.wat` matches `HEAD` (the shadowed strings: inner,
inner, outer). The record rebind is `elf/probe/drop-let-rebind.wat`.
Both agree plain and under `WAT_DROP_CHECK=1`
(`"inner"|"inner"|"outer"` and `3`).

### R3 — where the instructions went

Same input as `NOTE-M2-landed.md`: main's `956b4bb` tree, checked out at
`/var/tmp/ret-r2/tree956`. Each compiler's own `:user::main` compiled that
tree. `taskset -c 2`, `perf stat -e instructions:u,cycles:u` (the
`cpu_core` counters; `cpu_atom` did not count), RSS from `elf/bench/maxrss.c`
via `/var/tmp/ret-r2/maxrss`. Logs `/var/tmp/ret-r2/r3-*.perf` and `.rss`.

| | instructions | cycles | peak RSS (KB) |
| --- | ---: | ---: | ---: |
| M2 landed (the weigh's runs) | 8.416 – 8.417 B | 3.400 – 3.421 B | 298,232 – 298,460 |
| three-name seed, 584,491 | 11.143616545 – 11.143617422 B | 4.299 – 4.371 B | 67,872 – 68,568 |
| this round, 585,593 | 11.354078447 – 11.354079040 B | 4.412 – 4.622 B | 64,108 – 65,244 |

The three-name seed sits on the weigh's strike column (11.147 – 11.150 B,
67,572 – 68,656 KB). This round is +210.46 M instructions against that
seed and about −3 MB RSS: the extra records the general rule now drops,
`:c::Use` among them. Against M2 the same input is +2.938 B instructions
(+35%) and −78% RSS.

The cost is the drop sequence, counted by compiling the same tree with
one piece removed. A plain pointer drop is `dec [rax-8]`, `cmp [rax-8], 0`,
`jne` over the zero body, then the free. A type with glue pushes `rax`,
calls the glue, pops `rax`, then frees. The free writes the old list head
into the block's first word (the count word) and the block address into
the size-class slot. The next allocation of that class pops the slot
(`mov head`; `mov (head), next`). That pop, and the fresh bump it
replaces, is the list traffic.

The owning `assoc`, when the count is 1, compares, pushes `rax`/`rcx`/`rdx`,
loads the displaced field, runs that drop, pops, and stores the new field.
The copying path pushes the box, calls `slot_set`, and `:c::drop-saved`
pops the box, pushes the result, moves the box into `rax`, drops, and pops
the result back. A clause drop is `:c::drop-kept`: reload the binding,
push `rax`, drop, pop `rax`.

| piece removed | instructions saved | RSS of that compiler (KB) | `decq -8(%rax)` sites in the binary |
| --- | ---: | ---: | ---: |
| clause drops (`:c::cond-name-dead?` false) | 307.55 M | 76,364 – 77,172 | 5,409 (full has 5,594) |
| `and`/`or` short-circuit drops | 88.76 M | 70,868 – 71,072 | 5,459 |
| owning and copying `assoc` drops | 38.38 M | 64,656 | 5,593 |
| every `:c::emit-drop` | 1,816.37 M | 736,060 – 737,064 | 23 |

The three named pieces are 434.7 M of the 1,816.4 M. The rest is the other
`emit-drop` sites (a last-use read, a `let` going out of scope, a discarded
pointer, the path-4 free, the promotion trie) together with the list
traffic those frees add. Taking every drop out costs the memory the series
won: 736 MB against 64–65 MB. The clause drops alone are the piece that
moves RSS among the three named sites (+12 MB when they are absent).
The `assoc` drops are 38 M instructions and do not move RSS on this input.

Per site, one drop that reaches zero is the decrement, the glue call when
the type has pointer fields, and one free-list push. Each later allocation
of that size class pays one pop instead of a fresh bump. The `assoc`
paying path adds three pushes, the field load, and three pops around the
field's drop, or `:c::drop-saved`'s save and restore around the copy.
A clause drop adds the reload and the `push`/`pop` of `rax` around the
same decrement.

## Round 3 (2026-10-03) — poison stops a second decrement, and the clause drop is every pointer

The check-only guard in `:c::dropchk-hex` now matches the increment side.
Before `dec` it emits `:c::cmp-mi` of `:c::rax` at −8 against
`:c::poison-count` (−1) and `:c::jcc-rel32` of `:c::cc-zero` to
`:c::at-uflow`, then the existing `cmp [rax-8], 1; jb` (`488378f801` and
`:c::cc-below`). The `jb` displacement is measured from the end of that
longer sequence (`here + prefix +` the poison compare and its rel32 `+`
the five-byte compare and its rel32). The plain path, `dchk` false, is
still the bare decrement and the zero body.

A check build that takes a count to zero stores −1 and does not free, so
the count word stays −1. The new compare is equality with that word, so
the jump is taken before `dec`. A non-literal 0 is still below 1 as an
unsigned quantity, so the `jb` is taken. The literal skip that wraps the
guard matches a count of exactly 0, and a poisoned word is −1, so the
skip does not hide it. `:c::countchk-hex` already jumps on the same
equality when a count is incremented. No live count equals poison.

The mutant is not in the tree. A sandbox copy of the compiler
(`/var/tmp/ret-r3/mutant.wat`) emits the drop sequence a second time when
`dchk` is set; the second copy's relocations are computed from an `Out`
advanced past the first copy and past the outer literal or tag prefix.
The program is a two-field record, `:user::Box` of `n` and `m`, and prints
the sum. The non-mutant compiler prints `8` plain and under
`WAT_DROP_CHECK=1`. The check build of that program has one drop site,
`cmpq $-1, -8(%rax); je; cmpq $1, -8(%rax); jb; decq -8(%rax)`. The mutant
plain build prints `8`. The mutant check build exits 70 and prints
`wat: reference count underflow`, with two of those poison sites.

`:c::cond-name-dead?` now asks `:c::ptr-ty?` (a string, `vec:`, `rec:`,
`henum:`, `penum:`, or `fn:`). A scalarised name stays out. The
earlier-test and this-test last-use suppressions are the round-2 ones.
`:c::and-name-dead?` still requires `rec:`.

`(wat.core/length (wat.core/conj v 99))` drops the temporary result of
`conj`. `length` of a non-symbol drops that result once. `conj` copies
when the name is still used later, so the result is a new vector and a
clause drop, when it fires, drops the name. `conj` is in place only for a
linear name, and a linear name has no later clause holding a last use, so
the clause predicate does not drop it as well. The last-use suppressions
do not look at the kind. Widening the kind test does not decrement the
temporary and the name as one word.

The widened compiler's own check build (798,499 bytes) self-hosted to
`compile: ok` with no underflow. Its plain build fixpointed at 603,509
bytes and self-hosted. Corpus answers matched the `rec:`-only compiler,
plain and under the check. Three fixtures agree with the interpreter both
ways: a vector clause prints `20`, `60`, `200`, `1`, `3` (the `1` is the
taken clause whose test is `(= (length (conj v 99)) 4)` and whose `:else`
would have used `v`); a string clause prints `20`, `40`, `60`, `2`, `2`;
a function clause prints `1`, `4`, `5`. The `drop-*` probes agree both
ways, including `drop-cond-arm`, `drop-cond-test`, `drop-shadow`,
`drop-let-rebind`, and `drop-concat-box`. `drop-3b-list` and
`drop-vec-cycle` timed out in the interpreter at 30 s; plain and check
printed the same line. `drop-cons` faults in the interpreter as well.

### The gates, on this source

`tools/verify.sh`, then `WAT_DROP_CHECK=1 tools/verify.sh`. Each is a full
bootstrap from the interpreter, then `elf-run`. Round 1's 584,491 /
702,794 and round 2's 585,593 do not cover this compiler.

| | fixpoint | `elf-run` |
| --- | ---: | --- |
| plain | stage 1 = stage 2, 603,509 bytes | `verify: ok` |
| `WAT_DROP_CHECK=1` | stage 1 = stage 2, 798,499 bytes | `verify: ok` |

Both logs: 103 native binaries, 54 agreeing with the interpreter, 3 using
syscalls the interpreter has no implementation of, 11 refusals and 4
traps, both ways. Rules: 0 conflicts in 16,539 argument-parameter pairs
(16,462 equal, 77 a variant to its enum) over 169 programs. Types: 0
conflicts in 31,665 nodes both typed. `reads`, `copies`, and `rsp` each
printed ok. The check verify ran second, so `elf/out/compiler.elf` is the
798,499-byte check build. The plain fixpoint used below is
`/var/tmp/ret-r3/final-plain.elf`, copied before that overwrite.

Same input as round 2: main's `956b4bb` tree at `/var/tmp/ret-r3/tree956`,
compiled by the plain 603,509-byte compiler. `taskset -c 2`,
`perf stat -e instructions:u,cycles:u` (the `cpu_core` counters), RSS from
`/var/tmp/ret-r2/maxrss`. A separate run printed `compile: ok` and wrote
that tree's compiler as 521,931 bytes. Logs `/var/tmp/ret-r3/m1.perf`
through `m3.perf`.

| run | instructions | cycles | peak RSS (KB) |
| --- | ---: | ---: | ---: |
| 1 | 12,736,117,443 | 5,095,875,280 | 56,096 |
| 2 | 12,736,119,560 | 5,129,007,659 | 57,832 |
| 3 | 12,736,119,138 | 5,082,553,754 | 57,888 |

Against round 2's 11,354,078,447–11,354,079,040 this is +1.382 B
instructions. Peak RSS is 56,096–57,888 KB, against that round's
64,108–65,244 KB. Nothing was committed.

