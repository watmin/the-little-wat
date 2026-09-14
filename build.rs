//! Rebuild the test crate whenever the SET of files under `wat-tests/` changes.
//!
//! `wat::test! {}` lists `wat-tests/` once, when the macro expands, and marks each file it
//! found with `include_bytes!`. So cargo rebuilds when an existing file's contents change,
//! but not when a file is added or removed. A new chapter file was silently never compiled
//! and the run still reported green (FINDINGS.md, F-002).
//!
//! This script closes that gap in two parts:
//! - `rerun-if-changed` on the directory makes cargo rescan the tree on every build.
//! - The sorted file listing is exported as `WAT_FRIEDMAN_WAT_TESTS`, which
//!   `tests/test.rs` reads with `env!`. Adding or removing a file changes the value, and
//!   the test crate recompiles, re-running discovery.

use std::fs;
use std::path::{Path, PathBuf};

fn collect_wat(dir: &Path, out: &mut Vec<PathBuf>) {
    let Ok(entries) = fs::read_dir(dir) else { return };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_dir() {
            collect_wat(&path, out);
        } else if path.extension().is_some_and(|ext| ext == "wat") {
            out.push(path);
        }
    }
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=wat-tests");

    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("wat-tests");
    let mut files = Vec::new();
    collect_wat(&root, &mut files);
    files.sort();

    let listing: Vec<String> = files
        .iter()
        .map(|p| p.strip_prefix(&root).unwrap_or(p).display().to_string())
        .collect();
    println!("cargo:rustc-env=WAT_FRIEDMAN_WAT_TESTS={}", listing.join(";"));
}
