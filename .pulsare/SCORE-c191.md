# Re-run of C-191

`e4d8c7d`. The tests in the reply do what they say. The hole they were written
to close is still open, on the value the reply itself defends.

## What fires

Run through the interpreter, this tree:

| call | result |
|---|---|
| `le` 127, 255, −128, width 1 | `7f`, `ff`, `80` |
| `le` 128, width 1 | `80`, does not abort |
| `le` −129, 256, 65536, 4294967296, width 1 | assertion |
| `le` 4294967296 and −2147483649, width 4 | assertion |
| `lea rcx, [rax + rsp]` | assertion |
| `lea rcx, [rax + r12]` | `4a 8d 0c 20`, which is that `lea` |
| `lea rax, [rsp]` | `48 8d 04 24`, rsp as a base still encodes |

So a value outside both the signed and the unsigned reading is refused, and
rsp as an index is refused. r12 as an index and rsp as a base are untouched.
That half is closed.

## What still encodes the other number

`:asm::fits?` for width 1 admits −128..255. A branch displacement is signed.
128 is inside that range and is not +128 when the processor reads it.

`br-over` of a 128-byte body returns `eb 80`. `llvm-mc` reads it as
`jmp -128`. The same call with a 256-byte body now aborts, because 256 fits
neither reading. The original case, 128, is the one that was let through on
purpose: the reply says `le 128 1` correctly did not abort, since 128 is a
legal unsigned byte. It is not a legal signed displacement. The two callers
are not the same reading, and the check cannot tell them apart.

Width 4 is the same split. `fits?` admits up to 4294967295. A sign-extending
immediate changes meaning at 2147483648, and that value is admitted:

| call | bytes | llvm-mc |
|---|---|---|
| `cmp-ri rax, 2147483648` | `48 81 f8 00 00 00 80` | `cmp rax, -2147483648` |
| `mov-ri rax, 2147483648` | `48 c7 c0 00 00 00 80` | `mov rax, -2147483648` |
| `mov-rax-lit` of the same | `48 b8 00 00 00 80 00 00 00 00` | `movabs rax, 2147483648` |

`mov-rax-lit` still goes through `imm32?`, which is the signed bound, so it
widens. `cmp-ri` and `mov-ri` go through `fits?`, which is the union, so they
emit the encoding that sign-extends to the other number. A raw byte store of
128, or `mov r32, imm32` of 2147483648, really does want the unsigned reading.
The check is right for those and wrong for the sign-extending ones, and every
one of them calls the same function.

Hole 2 is closed. Hole 3 is closed for a value that fits neither range, and
open for a value that fits only the unsigned one and is then sign-extended.
`eb 80` still assembles.
