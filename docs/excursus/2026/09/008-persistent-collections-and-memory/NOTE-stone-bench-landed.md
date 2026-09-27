# NOTE — excursus 008 bench stone landed

Read `WEIGH-stone-bench-twin.md`. The re-run is credited, including R1.

The baseline is the table in `BENCH-baseline.md`, taken before stone 3 drops anything. `wat.os/clock-ns` is the only compiler change. Every answer agrees where a program finished. The cells that did not finish are named with the reason. Peak RSS and batch tails are recorded. Clojure's GC tail is visible warm: W4 at 10^6, max 85.7 ms against a p50 of 0.099 ms. W3 stays at about 956 KiB across sizes, because the record stays uniquely owned. `tools/verify.sh` exited 0 and all 100 corpus programs are byte-identical. The machine is a 12th Gen Intel i7-1270P with 32 GB RAM and 64 GB swap. The commit named in the baseline is `4f89874`, and the tree stays dirty.

W4 keeps every old version, so both sides share structure. Compiled wat is 1.49 billion instructions against Rust `VectorSync`'s 9.27 billion, at similar memory. That is the trie-to-trie comparison: 6.2× in wat's favour.

W1–W3 are a different comparison. Compiled wat grows a uniquely owned vector with `vec_conj_own`, which stays a flat array doubled in place and never becomes a trie, so it behaves like Rust's `Vec`. `rpds` stays a trie even when owned through `push_back_mut` / `set_mut`. The 12–15× there is representation. The imperative C loop, 10.5 million instructions on W1 at 10^6, is the floor for that shape. The persistent `push_back` / `set` column stays in the table, labelled as the other API. Clojure's plain `conj` is the persistent idiom; `transient` / `conj!` was measured and sits on the same JVM-startup floor. C `malloc`/`free` was already the one-owner buffer. The wat interpreter runs the same uniquely owned source.

The orchestrator's own spot-checks at 10^6, pinned, user-mode instructions, answer `499999500000`: compiled wat W1 63.0 M, W4 1.4916 B; Rust one-owner W1 932.35 M, Rust W4 9.2584 B. Those are the score's figures.

Nothing further. The tree stays dirty.
