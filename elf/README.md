# A wat program that emits a native executable

`elf/hello.wat` computes the bytes of an x86-64 Linux ELF, writes them, and reads them back to
check. The result runs on the kernel with no interpreter, no runtime and no libc.

```
$ tools/elf-run.sh
== emitting ==
"elf: elf/out/hello.elf    166  bytes   text 31    tail 15    verified byte for byte"
"elf: elf/out/exit42.elf   132  bytes   text 12    tail 0     verified byte for byte"
"elf: ok"

== what the kernel makes of them ==
elf/out/hello.elf       166 bytes  ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, no section header
elf/out/exit42.elf      132 bytes  ELF 64-bit LSB executable, x86-64, version 1 (SYSV), statically linked, no section header

== running ==
hello.elf   printed 'hello from wat' and exited 0
exit42.elf  exited 42, which wat computed as 6 * 7
```

The 166-byte one is byte-for-byte identical to a reference built independently in Python.

## The one thing that makes it possible

wat has **no byte literal**. An integer literal is an `i64`, there is no `to-u8`, and
`(:wat::core::Vector :- [:wat::core::u8] 127)` is refused —

> `:wat::core::vec: parameter #1 expects :wat::core::u8; got :wat::core::i64`

Only three things in the language produce a `Vector<u8>`: `IOReader/read-all` (bytes that already
exist in a file), `IOWriter/to-bytes` (bytes already written), and **`:wat::core::Bytes::from-hex`**,
which decodes a String of hex digits. That last one is the whole door. A wat program can compute
a hex string — ordinary string work — and hand it to `from-hex` to become arbitrary binary,
including every byte above `0x7f` that a String could never carry as UTF-8.

So the shape of the program is **assemble to hex, decode once at the end**. F-118 is the finding
that it has to be that shape.

## What it does

A two-pass assembler, for the reason every assembler is two passes: the code contains the address
of the message, and the address depends on how long the code is.

1. **Pass one** emits the text with the address left at zero, only to measure it.
2. Every address then follows from the lengths — entry, message address, file size.
3. **Pass two** emits the same text with the real address, and the program asserts the two passes
   produced the same number of bytes. That invariant is what makes the technique sound.

The layout, all of it computed rather than written down:

| offset | size | what |
|---|---|---|
| `0x00` | 64 | ELF header — `ET_EXEC`, `EM_X86_64`, entry `0x400078` |
| `0x40` | 56 | one program header — `PT_LOAD`, `R+X`, the whole file at `0x400000` |
| `0x78` | 31 | text — `write(1, msg, len)` then `exit(0)` |
| `0x97` | 15 | the message |

There are no section headers at all. Change the message and the file re-lays itself.

The second binary exists to show the code is being **chosen** rather than pasted: same headers,
same layout arithmetic, different instructions, and a status (`42`) that wat worked out as `6 * 7`.

## ASCII, without a character type

wat has no character-to-integer verb, so `:elf::code-of` finds a character's code by its **index**
in the 95-character printable range, which starts at 32. That is the entire encoder, and it is
another face of F-062 (a String has no elements): the scan is one `subs` per candidate.

## What wat cannot do here

- **Set the executable bit.** `:wat::io::` is `open-file`, `read-file`, `list-dir`, `TempDir` and
  `TempFile`; there is no `chmod`. `open-file` creates with the default mode.
- **Run the result.** `:wat::kernel::spawn-process` forks a wat child that evaluates a source
  string — not an arbitrary program. There is no `exec`.

So `tools/elf-run.sh` does those two steps, and they are the only part of this that is not wat.
Note that the exec bit only has to be set **once**: `open-file` truncates an existing file rather
than replacing it, so after the first `chmod +x` a wat program alone keeps producing runnable
binaries at that path.

## What it checks

`wat elf/hello.wat` is self-checking and exits non-zero if anything is wrong:

- the two assembler passes agree on the text's length;
- the blob's length equals the `p_filesz` the program header claims;
- the writer reported writing exactly that many bytes;
- and the file read back off the disk is identical, hex for hex, to what was assembled.

What it cannot check from inside wat is that the binary **runs**. That is `tools/elf-run.sh`.
