# tools/sums.sh -- SOURCED by tools/bootstrap.sh and tools/elf-run.sh; one definition of "the sources".
#
# srcsum: the COMPILER's own sources. bootstrap.sh refuses a run whose compiler source changed while it
#   ran (C-174 split the compiler into three files, so all of them are hashed).
# buildsum: EVERY input the build reads -- the compiler, and every .wat it compiles or regenerates
#   (elf/src, elf/native, elf/hello.wat, the refuse drivers). A successful bootstrap writes it to the
#   STAMP; `SKIP_BUILD=1 tools/elf-run.sh` refuses to check binaries whose stamp does not match, so a
#   stale elf/out/ can never be checked as if it were current.
compiler_sources () { echo elf/compile.wat elf/lib/*.wat; }
srcsum () { sha256sum $(compiler_sources) | sha256sum | cut -c1-16; }
build_inputs () { find elf -name '*.wat' -not -path 'elf/out/*' | LC_ALL=C sort; }
buildsum () { sha256sum $(build_inputs) | sha256sum | cut -c1-64; }
STAMP=elf/out/.build-stamp
