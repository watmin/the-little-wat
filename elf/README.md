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
(wat.core/defn user/NAME [p :- wat.type/i64 ...] :- T  BODY...)
(wat.core/if COND THEN ELSE)          ; a real forward branch, patched
(wat.core/let [a E b E] BODY...)      ; slots in the frame, innermost shadowing outward
(user/NAME args...)                   ; a call, arguments on the stack, recursion included
(wat.kernel/println EXPR)             ; EXPR to rax, then call print_i64
(wat.kernel/println "literal")        ; written directly, string in the data tail
(wat.core/do BODY...)                 ; a sequence; the last form is the value
(wat.core/+ - * quot rem)             ; n-ary, folded left
(wat.core/< > <= >= = not=)           ; cmp + setcc + movzx, so a bool is 0 or 1 in rax
```

integer literals, negatives included, nested to any depth — and both spellings of every name
(`wat.core/+` and `:wat::core::+`), because the reader keeps whichever the source used.

And an **intrinsic set that is the compiler's own, not wat's**:

```clojure
(wat.os/getpid) (wat.os/getppid) (wat.os/fork)   ; a bare syscall, result in rax
(wat.os/exit N)                                   ; exit(N)
(wat.os/wait)                                     ; wait4, answering the raw status
(wat.os/mmap N)                                   ; anonymous read+write memory
(wat.os/clone SP)                                 ; a child sharing the address space
(wat.os/peek A) (wat.os/poke A V)                 ; eight bytes at an address
```

## Processes and threads

`elf/native/fork.wat` forks, and the parent reads the child's exit status back:

```clojure
(wat.core/defn user/child [] :- wat.type/i64
  (wat.kernel/println 2)
  (wat.os/exit 7))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println 1)
  (wat.core/let [parent (wat.os/getpid)
                 pid (wat.os/fork)]
    (wat.core/if (wat.core/= pid 0)
      (user/child)
      (wat.core/let [st (wat.os/wait)]
        (wat.kernel/println (wat.core/rem (wat.core/quot st 256) 256))
        (wat.kernel/println (wat.core/if (wat.core/> pid 0) 1 0))
        (wat.kernel/println (wat.core/if (wat.core/= (wat.os/getpid) parent) 1 0)))))
  (wat.kernel/println 4))
```

`1 2 7 1 1 4` — 698 bytes. The `7` is the child's exit code, decoded out of `wait4`'s status
word with `quot` and `rem`.

`elf/native/threads4.wat` starts **four threads** that share an address space, each writing its
own slot in an `mmap`'d page, and sums them: `1000`, in 1269 bytes, the same every run.

`clone` is called with `CLONE_VM | CLONE_FS | CLONE_FILES | SIGCHLD`. `CLONE_VM` is what makes it
a thread — the address space is shared, so a `poke` on one side is visible on the other.
`SIGCHLD` rather than `CLONE_THREAD` is what keeps it waitable with the same `wait4` the fork
program uses: a thread proper is not a child in `wait`'s sense, and this compiler has no futex.

**One thing to know about the frames.** `clone` gives the child a fresh `rsp` but it inherits
`rbp`, so the child reads its locals out of the *parent's* frame — which works only because the
address space is shared, and only for as long as that frame is live. `threads4.wat` is written so
the parent reaps every child at the bottom of its recursion, before any frame unwinds. A compiler
that wanted real threads would give the child its own frame at the clone site.

`elf/src/fib.wat` is the program that shows it is real: two mutually independent recursive
functions, a `let`, and arithmetic wide enough to need 64 bits.

```clojure
(wat.core/defn user/fib [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/< n 2)
    n
    (wat.core/+ (user/fib (wat.core/- n 1)) (user/fib (wat.core/- n 2)))))

(wat.core/defn user/fact [n :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/<= n 1) 1 (wat.core/* n (user/fact (wat.core/- n 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/fib 20))
  (wat.kernel/println (user/fact 15))
  (wat.core/let [x (user/fib 10)]
    (wat.kernel/println (wat.core/+ x (user/fact 5)))))
```

659 bytes of native code; prints `6765`, `1307674368000`, `175`; agrees with the interpreter.

## What compiling is worth

`fib(27)`, the same source both ways, measured by `tools/elf-run.sh` on each run:

```
interpreted  3391 ms    native   6 ms    565x
interpreted  4165 ms    native   5 ms    833x
```

The native figure is mostly `execve`, so the ratio moves with machine load and is a floor rather
than a measurement. Five hundred times is the conservative reading. This is the number NEXT.md §7's baseline was taken to make sense of,
arriving from the other direction: the interpreter's per-operation cost is what a compiler
removes, and it removes essentially all of it.

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

**Two passes over the whole program.** A call needs the callee's address, and a callee's address
depends on the length of everything placed before it, so no function can be compiled without
knowing about all of them. Pass one compiles every function with every address zero, purely to
measure; the addresses follow from the lengths; pass two compiles again with the real table. Every
immediate and displacement is fixed width, so the passes are the same length — and the compiler
*asserts* that, function by function.

**Forward branches are patched, not predicted.** `if` emits its `jz` with a zero operand,
compiles the branch, and overwrites the operand once it knows how far it went. That is F-104
again — no positional update — on a String this time, so the patch is a `subs` either side of the
hole. Crafting Interpreters chapter 23 (C-106) is the same problem on a Vector.

**The calling convention.** Arguments are pushed left to right and popped by the caller; inside
the callee, argument *i* of *n* is at `[rbp + 16 + 8*(n-1-i)]` and `let` slots are below at
`[rbp - 8*(slot+1)]`. The frame size is worked out before the body is compiled, by walking it for
the deepest simultaneous `let` demand. The entry point is a 19-byte stub — `call user/main`, then
`exit(0)` — which is the only code in the output not compiled from a `defn`.

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

## Where the compiled language stops being wat

Everything in the first list above is wat, and `elf/src/*.wat` is checked by running each program
**both ways** and requiring identical output and exit status. Nothing in the intrinsic list is:
the interpreter has no `wat.os/fork`, so `elf/native/*.wat` cannot be run by it at all and has no
differential oracle — only a fixed expected output in `tools/elf-run.sh`.

That is the same position a C compiler is in with `write`: it does not implement it either, and
C's answer is libc. wat has no equivalent. Its OS surface — `:wat::io::`, `:wat::kernel::spawn-*`
— is implemented in Rust *inside the interpreter*, so a compiled program cannot reach it.
**F-119** is that gap, and it is a roadmap question rather than a defect: a compiled wat needs an
intrinsic set defined independently of the interpreter, or the two languages drift apart exactly
here.

## What is still missing, in order of what it would prove

`let`, `if` and user functions are done. What stands between this and a compiler that could
compile *itself*:

1. **Strings as values** — not just literals to print. Length, `subs`, concatenation; which means
   a heap, or at least an arena, and a representation for a string that is not "bytes in the
   data section".
2. **Vectors and records** — every one of this compiler's data structures. Allocation, field
   offsets, and something to free them or a decision not to.
3. **`match`** — which is `if` with a tag test and destructuring, so the hard part is the data
   representation rather than the control flow.
4. **The wat runtime's verbs** — `read-string` itself, `ast->children`, `Bytes::from-hex`. A
   self-hosting compiler either reimplements them or links against the substrate.

That is the honest distance: the control flow and the calling convention are solved, and
everything remaining is about **data**. This file is 430 lines of wat and compiles a language
with no heap; compiling the language it is written in needs one.
