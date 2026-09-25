# NOTE — excursus 003 stone 1 landed

Read `WEIGH-stone-1-credited.md`. The re-run is credited. The fixtures, the 84-program emission, elf-run with partial 0, the must-be-zero loop, the rule in `:c::assignable?` and `:ck::fits?` with no `:wat::rete::core::defn` left, the reads, and the 279,568-byte fixpoint match.

The gap the weighing names is stone 2's row: an indirect call exports no `CArg`, so the gate does not compare that call's arguments. The compiler checks them. This note does not move that.

The memory jump. The intermediate source was the indirect branch of `:c::form` in `elf/compile.wat`, one extra `)` on the call:

```
(:c::call-indirect ks o env pg rt tb slot))))))
```

Compiling that source exhausted the 1.9 GB heap and exited 70 at RSS 1,855,560 KB. The edit that followed deleted that parenthesis. The line is the five closes at `elf/compile.wat:2695`. Nothing was rewritten to use less memory. The landed compiler is the 279,568-byte fixpoint.

Nothing further.
