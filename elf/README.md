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

— becomes a **620-byte static ELF** that prints `4` and exits 0, with no interpreter, no
libc, and no runtime but the 501 bytes this compiler embeds itself.

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
(wat.core/cond (TEST BODY...) ...)    ; a chain of ifs; (:else BODY) for the last
(wat.core/and A B ...)                ; the first falsy operand, or the last
(wat.core/or A B ...)                 ; the first truthy operand, or the last
(wat.core/not A)                      ; test + sete + movzx
(:wat::core:://)                      ; integer division -- keyword spelling only, F-121
```

integer literals, negatives included, nested to any depth — and both spellings of every name
(`wat.core/+` and `:wat::core::+`), because the reader keeps whichever the source used.

**Strings**, as values:

```clojure
(wat.string/concat A B ...)           ; n-ary, folded left through `str_cat`
(wat.string/length S)                 ; a peek at the header
;; a self call in tail position becomes a jmp, not a call -- wat has TCO and so does this
nil, true, false                      ; a machine zero, a one, a zero
"a literal"                           ; a pointer to [len:8][bytes...] in the data tail
```

## Strings, and the heap

A String value is one machine word, like everything else: the address of `[len:8][bytes...]`. So
it rides in `rax` like an integer, and nothing else in the compiler had to change shape to carry
one. Literals live in the read-only data tail. Anything `concat` builds lives in a megabyte the
entry stub `mmap`s, bump-allocated through **r15** — reserved for the program's whole life,
callee-saved in the System V ABI, and the entire memory model. No free, no collector, no bounds
check: a program that wants more than a megabyte gets a segmentation fault, not an error message.

It needed a **type pass**, for exactly one decision: `println` has to know whether to call
`print_i64` or `print_str`, and the argument can be a name, a branch, a call or a `let`. So there
is a two-type static pass (`i64`, `str`) that propagates what the declarations already say —
through parameters, `defn` returns, `let` bindings, `if` arms and `do` tails. It is not
inference. It recognises a wat type by its spelling, which covers `wat.type/String` and
`:wat::core::String` without a table.

`elf/src/strings.wat` is the test, and it runs both ways:

```clojure
(wat.core/defn user/stars [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) acc
    (user/stars (wat.core/- n 1) (wat.string/concat acc "*"))))
```

```
"hello, world!"   "xyxyxy"   6   "hello, then!"   "****...****"   40   "q\" b\\ n\n t\t r\r ."
```

1319 bytes, byte-identical to the interpreter — the escapes included.

### The part that is really a finding

`println` renders a String as **EDN**: quotes around it, `"` and `\` and newline and tab and
carriage return escaped, and every other byte passed through raw. So `print_str` — 158 bytes of
machine code — *is wat's EDN escaping*, and agreeing with the interpreter means reproducing it
exactly.

Every rule in that list was found by **asking the interpreter what it printed**. Nothing says.
And the other half of the same problem: a string in memory has a length in bytes, while
`wat.string/length` counts characters and the string surface has no byte-length verb at all — so
this compiler restricts itself to ASCII, where the two agree, and refuses the rest.
`elf/bad/nonascii.wat` is valid wat that prints `"café"` under the interpreter and is rejected at
compile time rather than silently mis-measured. That is **F-120**.

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

## Why a bump allocator can free

It leaks, and for a while that did not matter: every compiled program was short and the heap is a
megabyte. `elf/src/churn.wat` is the program that does not get away with it — a 32-byte string
allocated per level, its length taken, the string thrown away, fifty thousand levels. That is
2.4 MB against a 1 MiB heap. The interpreter printed `50000`; the binary died with
**`Segmentation fault`, exit 139**.

The fix is eight bytes per statement. A sequence's last form is its value; every form *before* it
has its value discarded, so whatever it allocated is garbage the instant it finishes — and with a
bump allocator, freeing all of it is putting the pointer back:

```
push r15 ; push r15        mark   (twice, to keep the frame 16-byte aligned)
<the statement>
pop  r15 ; pop  r15        release
```

The marks live on the stack, so it nests with no bookkeeping at all.

**Why that is sound** is the interesting half. The release is safe only if nothing outliving the
statement can hold a pointer into what it allocated, and in this language there are exactly two
ways to store a pointer: a `let` slot — written inside the statement, and out of scope when it
ends, because `let` does not carry its environment back out past its body — and **`poke`**, which
can hand an address to anyone. So a statement containing a `poke` anywhere inside it is not
released. The test is a substring of the statement's own source, which is crude in the direction
that costs nothing: a false positive only declines to free memory.

A returned value is never released, because the final form is never marked. That is what keeps
`(defn f [] :- wat.type/String (wat.string/concat ...))` working.

**And where it stops.** Anything whose allocation *escapes upward* still accumulates —
`(user/stars 40 "")` in `strings.wat` is the deliberate example, since each level's result is the
next level's argument and every intermediate string is live until the outermost one is. Scope
cannot free those. Reachability can. The next step in the same direction is a caller-side release
after every call whose return type is not a pointer, sound for the same reason one level up;
after that it is a collector, which is a different program.

### Scope of a name is not lifetime of a value

`elf/src/shadow.wat`:

```clojure
(wat.core/defn u/fn [x :- wat.type/String] :- wat.type/String
  (wat.core/do
    (wat.core/let [x "useless"] nil)
    x))
```

`"not-useless"`. The compiler gets that right by not carrying the `let`'s environment past its
body — one line, and the whole of lexical scope. It is also the case where scope-based freeing
has nothing to do: the shadowed binding is a **literal**, which lives in the read-only data tail
and was never on the heap.

That file also pins down four printable types, because three of them would otherwise diverge in
silence: `(println (> 3 2))` is `true` and not `1`, and `(println nil)` is `nil` and not `0`. The
type pass is the only thing that knows, so `println` dispatches on all four and `elf/src` has a
program for each.

## Tail calls, because wat has them

This one is correctness, not speed. wat's own docs say it:

> Wat has TCO — the stack does not grow regardless of […] The tail call must be the LAST
> expression in the body.
>
> — `wat-rs/docs/ITERATION-PATTERNS.md`, where `defn` + a tail call is *the* documented way to
> iterate with state

Verified both directions: a million levels of tail self-recursion answer `1000000` under the
interpreter, and the same depth **not** in tail position dumps core. So a tail-recursive loop is
ordinary wat, and a compiler that lays every call down as a `call` turns working programs into
segmentation faults — which is exactly what `elf/src/deep.wat` did: interpreter `1000000`,
binary **`Segmentation fault`, exit 139**.

A self tail call is now a `jmp` back to the top of the body with the arguments replaced:

```
<evaluate each new argument, pushing it>    left to right, as an ordinary call would
pop rax ; mov [rbp+16], rax                 then popped BACK into the incoming slots,
pop rax ; mov [rbp+24], rax                 last argument first, because it is on top
jmp body                                    and round again, on the same frame
```

Every argument is evaluated before any of them is stored, which is what makes `(f (g b) (h a))`
safe when the new `a` is computed from the old `b`. Tail position is threaded through the
compiler as a small record and matches wat's own definition: the last form of a body or `do`,
both arms of an `if`, the body of a `let`.

### It broke the threads, which is the interesting part

A tail call **reuses the frame**. That is sound only while the frame is private to this thread —
and `clone` hands a second thread an `rbp` pointing straight at it. With `user/spawn`'s tail call
eliminated, the parent overwrote `i` while four children were still reading it, and
`threads4.elf` fell from **1000 to 400**.

So a function containing `clone` is not tail-call optimised, exactly as a statement containing
`poke` is not heap-released. Two optimisations, two soundness arguments, and the same intrinsic
set breaks both — which is F-119 again from a new direction: an intrinsic set needs a stated
contract about what it does to the machine, not just an opcode.

## Against C

`tools/vs-c.sh` builds the opponents with gcc and states the numbers. Two of them: C as it
normally is (glibc), and C with libc *removed* — `-nostdlib -nostartfiles`, raw syscalls, its own
`_start`. The second is the honest opponent, because it is the same bargain `elf/` makes.

| a program that prints `4` | bytes |
| --- | --- |
| **ours** | **773** |
| C, libc removed | 968 |
| C, glibc, dynamic | 15,968 |
| C, glibc, static | 856,720 |

| 500 runs of a program that does nothing | |
| --- | --- |
| C, libc removed | 405 ms |
| **ours** | **430 ms** |
| C, glibc, static | 596 ms |
| C, glibc, dynamic | 761 ms |

| | ours | gcc -O0 | gcc -O2 |
| --- | --- | --- | --- |
| fib(32) | 53 ms | 51 ms | **13 ms** |
| 100000 integers to stdout | **6 ms** | — | 13 ms |

**What that says, without the flattery.** On size and startup we are *level with C that has had
libc removed* — and against C with glibc we are 1100× smaller and quicker to start, all of which
is libc rather than anything clever here. On compute we are a naive stack machine with no
register allocator and we land exactly on **gcc -O0**; `-O2` is 4× ahead, and closing that is
register allocation and inlining, not tricks.

On output we are now **2.2× faster than glibc**, and that one is worth being precise about. Both
sides do the same ~150 `write` syscalls; the difference is what happens per line on the way to
the buffer. glibc's `printf` walks a format string at runtime, takes the `FILE` lock, checks
stream orientation and consults the locale. Ours knows at compile time that it is printing an
integer, so `print_i64` is a divide loop and `buf_put` is `rep movsb`. That is 70 bytes against
a general-purpose formatter, and the gap is the generality, not the engineering.

(Numbers from one machine, one run, best-of-5. They move with load. They are here to set terms,
not to win an argument.)

## Buffered output, and the oldest bug in it

`println` used to be one `write` syscall per line. Now bytes go into a 4 KiB buffer at **r14**,
laid out as `[used:8][4096 bytes]`, and the syscall happens once per buffer. `buf_put` is 70
bytes, `flush` is 36, and the copy is `rep movsb`.

Buffering is a promise you have to keep on every way out of the program:

* **the entry stub flushes** after `main` returns, or the last line of every program is lost;
* **`exit` flushes** before the syscall, and parks the status on the stack while it does, because
  a flush clobbers `rax`, `rcx`, `rdx`, `rsi` and `rdi`;
* **`fork` flushes** — and this is the interesting one;
* **`clone` flushes**, because `CLONE_VM` means the child shares the buffer rather than copying
  it.

### The fork trap, demonstrated

`fork` duplicates the address space, buffer included. Anything still pending is written **twice**,
once by each side. Compile `elf/native/fork.wat` with the flush removed and the program says so:

```
without flush-before-fork:   1 2 1 7 1 1 4
with    flush-before-fork:   1 2 7 1 1 4
```

The parent had buffered `1\n` and had not written it yet; the child inherited a copy and flushed
it on `exit(7)`. This is the oldest bug in buffered I/O and it has the oldest fix, which is why
the C rule — flush before you fork — is a rule.

## Two negative tests

`elf/bad/unsupported.wat` is refused for a **form** the compiler has no translation for;
`elf/bad/nonascii.wat` is refused for a **representation** it cannot honour. Both are valid wat
that the interpreter runs. The drivers that point the compiler at them are generated from
`compile.wat` by `tools/gen-refuse.sh`, because a negative test that has drifted from the thing
it tests proves nothing — and the committed one had already drifted.

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

Six routines, 501 bytes — the only part of the output not computed from the source, and the
part a C toolchain would call libc for.

| routine | bytes | what it is |
| --- | --- | --- |
| `print_i64` | 87 | sign handling, a divide-by-ten loop building digits backwards **on the stack** (so the segment never needs to be writable), and one `write`. Checked against a negative, a small value, zero and `i64::MAX` before it was embedded. |
| `str_cat` | 97 | two lengths added, a header written at the heap top, two byte-at-a-time copy loops, `r15` bumped past the result. |
| `print_str` | 147 | a quote, a byte loop emitting one byte or two, a quote, a newline, one `write` — **wat's EDN escaping, in machine code**. |
| `print_bool` | 64 | `true` and `false` built on the stack a word at a time, so it needs no data section and no relocation. |
| `buf_put` | 70 | **the thing libc calls stdio** — a 4 KiB buffer at `r14`, one syscall per buffer instead of one per `println`. |
| `flush` | 36 | write what is buffered and empty it. |

They are assembled as **one block**, so they can call each other — which is why the order is
load-bearing: the relative offsets inside it were fixed when it was assembled. The first build of
that block printed nothing at all, because `as` had left `call flush` as `e8 00000000`, an
unresolved relocation that `objcopy` does not apply; the symbols were `.globl`. Making them local
resolved them in place, and `objdump -r` showing no relocations left is the check.

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

## How far from compiling itself

`elf/census.wat` answers that with a number instead of a feeling. It reads the AST of
`elf/compile.wat` and `elf/lib/asm.wat` — the compiler's own source — asks of every form *could
`:c::form` translate this?*, and tallies what is left, most frequent first. It is written in wat,
using the same `read-string` walk the compiler uses.

```
$ wat elf/census.wat
  rank  count  form
  1   65       :wat::core::nth
  2   54       :wat::core::length
  3   21       :wat::core::ast->source
  4   13       :wat::core::ast->children
  5   12       :wat::core::Vector
  6   8        :wat::string::subs
  ...
  51 distinct forms, 274 occurrences -- that is the distance to self-hosting
```

The first count was **56 forms, 297 occurrences**. What the table said to build first was not
what intuition suggested: not `match` (3 uses) or closures (1), but `cond` (18), `/` (14) and the
logical operators — 46 occurrences needing **no new codegen idea at all**. Those are done, and
the total is 274.

**It also moves as you build.** `nth` went 55 → 65 and `length` 44 → 54 over that same change,
because the compiler that has to be compiled had itself grown by five forms. A self-hosting
target is not stationary, and the honest measure is the ratio rather than the count.

`nth` + `length` + `Vector` + `conj` is **137 of the 274 — exactly half — and it is one
feature**: growable indexed sequences on the heap. After that comes the AST surface
(`ast->source`, `ast->children`) and the I/O surface, which are F-119: Rust inside the
interpreter, with no ABI for a compiled program to reach.

## What is still missing, in order of what it would prove

`let`, `if`, user functions, strings and a heap are done. What stands between this and a
compiler that could compile *itself*:

0. ~~**`cond`, `and`, `or`, `not`, `/`**~~ — done (C-123), 46 occurrences, no new codegen.
1. ~~**Strings as values**~~ — done (C-119). A String is a pointer to `[len:8][bytes...]`,
   literals in the data tail and everything else bump-allocated out of an `mmap`'d megabyte.
   `subs` (8 uses) and `contains?` (5) are still missing, and so is any way to give memory back.
2. **Vectors and records** — **half the remaining census**, and every one of this compiler's own
   data structures. Allocation is solved; what is left is field offsets, a length that can grow,
   and either something to free them or a stated decision not to.
3. **`match`** — which is `if` with a tag test and destructuring, so the hard part is the data
   representation rather than the control flow. Same blocker as (2).
4. **The wat runtime's verbs** — `read-string` itself, `ast->children`, `Bytes::from-hex`. A
   self-hosting compiler either reimplements them or links against the substrate.

That is the honest distance, and it moved: the control flow, the calling convention and the heap
are solved, and everything remaining is about **aggregate** data. The bump allocator that carries
strings will carry vectors too — what it will not carry is a compiler that runs long enough to
need the memory back.
