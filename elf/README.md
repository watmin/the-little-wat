# wat, compiled

Two programs here. One emits a native executable it was written to emit. The other is a
**compiler**: give it wat source and it emits a native executable for that source.

```
$ tools/elf-run.sh
== hand-written: elf/hello.wat ==
elf: elf/out/hello.elf    166  bytes   text 31    tail 15    verified byte for byte
elf: elf/out/exit42.elf   132  bytes   text 12    tail 0     verified byte for byte

== compiled from wat source: elf/compile.wat ==
compile: elf/src/four.wat   -> elf/out/four.elf      272   bytes   code 47    data 0     verified
compile: elf/src/arith.wat  -> elf/out/arith.elf     463   bytes   code 238   data 0     verified
compile: elf/src/greet.wat  -> elf/out/greet.elf     356   bytes   code 90    data 41    verified

== the check that matters: compiled binary vs wat interpreter ==
four       agree (exit 0, 272 bytes native)
arith      agree (exit 0, 463 bytes native)
greet      agree (exit 0, 356 bytes native)

== and the compiler refuses what it cannot translate ==
refused elf/bad/unsupported.wat, naming the form: (wat.core/quot 10 2)
```

This program —

```clojure
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/+ 2 2)))
```

— becomes a **272-byte static ELF** that prints `4` and exits 0, with no interpreter, no runtime
and no libc.

## Why it is a compiler and not a code generator

Because wat can read its own source. Four verbs are the entire front end:

| verb | gives |
|---|---|
| `:wat::core::read-string` | source text → a `:wat::WatAST` |
| `:wat::core::ast-kind` | `list`, `symbol`, `int`, `string`, `vector`, `keyword` |
| `:wat::core::ast->children` | a node's children |
| `:wat::core::ast->source` | a node's text — the literal for ints, the name for symbols |

`ast->source` makes `ast-name` unnecessary, which matters because `ast-name` **raises** on a node
that is not a symbol, keyword or string literal, and a tree walk meets those constantly.

## The language the compiler accepts

```clojure
(wat.core/defn user/main [] :- wat.type/nil  BODY...)
(wat.kernel/println EXPR)          ; EXPR compiled to rax, then call print_i64
(wat.kernel/println "literal")     ; written directly, string in the data tail
(wat.core/+ a b ...)               ; n-ary, folded left
(wat.core/- a b ...)
(wat.core/* a b ...)
```

integer literals, negatives included, nested to any depth — and both spellings of every name
(`wat.core/+` and `:wat::core::+`), because the reader keeps whichever the source used.

Anything else is a compile error that **names the form**:

```
compile: cannot compile call: (wat.core/quot 10 2)
```

`elf/bad/unsupported.wat` is a perfectly valid wat program — the interpreter runs it and prints
`5`. The refusal is about the compiler's subset, not about the program.

## The code it generates

A stack discipline, which is the obvious thing and the only thing available without a register
allocator. Every expression leaves its value in `rax`; a binary operator evaluates its left side,
pushes, evaluates its right side, pops.

```
48 b8 <imm64>   mov rax, literal
50              push rax
48 89 c1        mov rcx, rax
58              pop rax
48 01 c8        add rax, rcx
48 29 c8        sub rax, rcx
48 0f af c1     imul rax, rcx
e8 <rel32>      call print_i64     -- a real relocation, computed in pass two
```

**Two passes, for the reason every assembler has two.** A `call` needs the distance to
`print_i64`, which sits after the code, so its address is unknown until the code exists. Pass one
compiles with the runtime at address zero purely to measure; pass two compiles again with the
real address. Every immediate is fixed-width, so the passes are the same length — and the
compiler *asserts* that, because it is the invariant the technique rests on.

## The runtime

`print_i64` is 105 bytes of hand-assembled x86-64: sign handling, a divide-by-ten loop building
digits backwards **on the stack** (so the segment never needs to be writable), and one `write`
syscall. It is the only part of the output not computed from the source — the part a C toolchain
would call libc for. It was checked against a negative, a small value, zero and `i64::MAX` before
it was embedded.

## The differential test, and what it caught

For every program in `elf/src/`, `tools/elf-run.sh` runs **both** the compiled binary and the wat
interpreter on the same source and requires identical output and exit status. That is the only
check worth having, and it earned its keep on the first run: the compiler was stripping the
quotes from string literals and expanding their escapes, and

```
$ wat -e '(wat.kernel/println "a\nb")' | od -c
"   a   \   n   b   "  \n
```

`:wat::kernel::println` renders a String as **EDN** — quotes kept, escapes *not* expanded — so
the faithful compilation of a string literal is its source text, verbatim. The compiler is now
simpler than the wrong version was.

## What makes it possible, and what stops it going further

**F-118 is the door.** wat has no byte literal: an integer literal is an `i64`, there is no
`to-u8`, and `(:wat::core::Vector :- [:wat::core::u8] 127)` is refused at check time. The only
verb that can invent a byte is `:wat::core::Bytes::from-hex`, and it is the only route to a byte
above `0x7f` — a String is UTF-8, and every x86-64 `mov` opcode is above `0x7f`. So the whole
toolchain assembles to a **hex string** and decodes once, at the moment of writing the file.

**F-035 costs more here than anywhere else in this repository.** An assembler is bit work by
nature. There are no shifts and no masks, so `& 0xff` is `rem 256`, `>> 8` is `/ 256`, and `~b` is
`255 - b`. Two's complement for negative immediates is done the way the hardware does it —
complement every byte and add one, carrying by hand — because the obvious route, adding 2⁶⁴,
overflows `i64`, which **traps** rather than wrapping. Every encoder was checked against Python's
`struct.pack` before it was used.

**What wat cannot do is about the operating system, not about bytes.** It cannot set the
executable bit (`:wat::io::` has `open-file`, `read-file`, `list-dir`, `TempDir`, `TempFile`, and
no `chmod`) and it cannot run the result (`:wat::kernel::spawn-process` forks a wat child that
evaluates a source string, not an arbitrary program). `tools/elf-run.sh` is those two steps and
the differential check. Note the exec bit only has to be set **once**: `open-file` truncates
rather than replaces, so after the first `chmod +x` a wat program alone keeps producing runnable
binaries at that path.

## The obvious next steps, in order of what they would prove

1. **`let` and local variables** — a stack frame and an environment, which is the first thing
   that makes the generated code larger than the source.
2. **`if`** — a real forward jump, which the two-pass structure already supports.
3. **Function calls** — a calling convention, and the point at which `main` stops being special.
4. **Self-hosting** — the compiler compiling itself, which is what "wat builds wat" would
   actually mean. It is a long way off: this compiler uses strings, records, vectors, `match` and
   recursion, none of which it can compile.

The first three are days of work. The fourth is the real question, and this file is the evidence
that the road to it exists.
