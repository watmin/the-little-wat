# EXPECTATIONS — excursus 008 stone 2: every reference is counted

Written BEFORE the strike.

| # | what | command | expected |
|---|---|---|---|
| 1 | ⛔ `poke` typed | a probe poking a String; `elf/native/thread*.wat` | refused at compile time naming the form; the thread programs agree |
| 2 | ⛔ each copy counts | the five per-routine fixtures | each agrees with the interpreter |
| 3 | ⛔ each increment is load-bearing | one mutant per routine dropping its increment | its fixture diverges — or the SCORE names why no fixture can isolate it |
| 4 | ⛔ no unclassified copy | `tools/copies.sh` | ok; a planted uncounted pointer copy fails it |
| 5 | ⛔ gates | full `tools/elf-run.sh` | exit 0; `rules: 0`, `types: 0`; `copies.sh` and `reads.sh` run inside it |
| 6 | emission | `tools/emitted.sh check` + a diff | every move is the runtime's |
| 7 | self-hosts | `tools/bootstrap.sh` | byte-identical fixpoint |
| 8 | cost | the SCORE | instructions and cycles vs this commit's compiler at its own fixpoint; per-routine split if STOP-2 nears |

Runtime prediction: 3–5 hours. Trap-door: a Vector's element kind is known to the COMPILER, not always
to the runtime routine it calls — which is exactly STOP-1.
