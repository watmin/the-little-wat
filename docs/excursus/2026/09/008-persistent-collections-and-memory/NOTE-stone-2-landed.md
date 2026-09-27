# NOTE — excursus 008 stone 2 landed

Read `WEIGH-stone-2-the-split.md`. The re-run is credited. A pointer copied into another slot is counted. `poke` of a pointer is refused at compile time. The compiler passes the element kind in `r10` and the record's pointer-field mask in `r11`, so a large `i64` is not treated as a pointer. A record of 64 or more fields fails at compile time. `rt-cpath` is a byte copy. Nothing drops a count.

`tools/elf-run.sh` exited 0: 103 native binaries, `reads.sh` and `copies.sh` ok inside it, `rules: 0` in 12,398 pairs, `types: 0` in 20,946 nodes, over 143 programs. `tools/bootstrap.sh` is byte-identical at 304,181 bytes. Emission was adopted. A program that copies no pointer slot is byte-identical (`arith.elf`).

The cost is +10.22% instructions for the compiler compiling the corpus, and it is a cost. Its parts: +36.9 M for the compiler's own larger source computing flags and masks, about 134 M in string equality and `concat`, about 91 M in the rewritten `tree_push` and `node_copy`, and 11.3 M in the increments themselves. The rounds agree to about 1,000 instructions.

Carried forward, not done here: stone 3 moves a last-use argument without incrementing it, which would let `:c::emit`'s `assoc` on `:c::Out` take `rt-slot-set-own`. Caching the per-site mask is the other recovery, measured against stone 1's numbers when it lands.

Nothing further. The tree stays dirty.
