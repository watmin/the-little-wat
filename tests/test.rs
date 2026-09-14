//! Every `.wat` file under `wat-tests/` is discovered here; each `deftest` becomes its
//! own `#[test]`. Same minimal consumer shape as ../wat-rs/examples/with-loader.

wat::test! {}

// The listing of `wat-tests/` that build.rs exports. Reading it here makes this crate depend
// on that listing, so adding or removing a `.wat` file recompiles this crate and re-runs
// the macro's discovery. Without it, a new file is never picked up (FINDINGS.md, F-002).
const _WAT_TESTS_LISTING: &str = env!("WAT_FRIEDMAN_WAT_TESTS");
