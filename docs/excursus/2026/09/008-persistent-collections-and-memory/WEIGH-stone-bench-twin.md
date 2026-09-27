# WEIGH — excursus 008 bench stone: the twin must do the same work

2026-09-27.

## Credited

Every answer agrees where it finished; the cells that did not finish are named with their reason; the
clock is monotonic and arity-checked; peak RSS and tails recorded per cell; Clojure's GC tail visible
even warm (W4 at 10^6: max 85.7 ms against p50 0.099 ms); W3 flat at ~956 KiB across sizes (the record
stays uniquely owned); `tools/verify.sh` ok and all 100 corpus programs byte-identical; the machine and
commit named. **W4 is a fair fight** — every old version is kept, so both sides must share structure (in
`w4.wat` `v2` is used twice; in Rust `v.clone()` is kept): compiled wat 1.49 billion instructions against
Rust `VectorSync`'s 9.27 billion.

## Back — R1: W1, W2, W3's Rust twin does different work

The wat programs build with a UNIQUELY OWNED accumulator (`(user/build … (conj v i))`, the old `v` dead),
which extends IN PLACE. The Rust program calls rpds's PERSISTENT operations — `v = v.push_back(i)`
(`rust/src/main.rs:39`, `:57`) and `r = r.set(0, …)` (`:75`) — which path-copy and allocate on every step
though nothing else holds `v`. The 40–60x on those rows is our in-place path against Rust's persistent
path. Idiomatic Rust for "one owner, keep only the latest" is `push_back_mut` / `set_mut` (in place when
the value is uniquely owned) — that is the twin.

**Fix:** W1–W3's Rust twin uses `push_back_mut` / `set_mut` on an owned `VectorSync`. Keep the persistent
variant as a SECOND, labelled column so both are visible. Re-measure those rows with the same method;
update `BENCH-baseline.md` and the SCORE's prose (its W1/W2 paragraph compares against the persistent
path). W4 and W5 stand. Apply the same test to the other opponents and say so: does each one's W1–W3 do
what its language's idiom does for one owner (Clojure: plain `conj`; note transients as the idiomatic
fast path, measured or not, labelled)?
