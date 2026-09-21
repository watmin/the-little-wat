# SCORE — the encoder, against llvm-mc

Tree `3ef4797`. Every byte below was produced by calling `elf/lib/x86.wat`
through the interpreter and disassembled with `llvm-mc` 22.1.8
(`-triple=x86_64 -output-asm-variant=1`), which has never seen this encoder.
4,513 forms. The register numbering used throughout is the file's own:
0 rbx, 1 r12, 2 r13, 3 rbp, 4 r8 … 7 r11, 8 rax, 9 rcx, 10 rdx, 11 rsi,
12 rdi, 13 rsp, 14 r14, 15 r15.

## What matches

The 64-bit surface is right, including the four registers the brief named.

- 2,560 register/register forms — `add sub cmp and or xor imul mov test bsr`,
  every source against every destination — disassemble to that instruction.
  Push and pop of all sixteen, the shifts, `neg`, `div`, `idiv`, `inc`, `dec`
  likewise. `shr` by one is the `d1` opcode; llvm prints `shr rbx` rather than
  `shr rbx, 1`. The bytes `48 d1 eb` are that instruction.
- `lea`, `mov reg, mem` and `mov mem, reg` for all sixteen bases at
  displacements 0, ±1, 127, 128, −128, −129 and 4096. rsp and r12 take a SIB
  (`lea rax, [r12]` is `49 8d 04 24`). rbp and r13 at displacement 0 take a
  disp8 of zero rather than the mod-0 "no base" encoding (`lea rax, [r13]` is
  `49 8d 45 00`). r12 as an index is a real index (`lea rcx, [rax + r12]`).
  The header example `(:c::lea r15 rax 8 24 rcx)` disassembles as
  `lea rcx, [r15 + 8*rax + 24]`.
- The hand-written frame opcodes — `:c::store`, `:c::load`, `:c::reg-load` for
  rbx, r12, r13 and rbp, against both rbp and rsp, on both sides of the disp8
  boundary — disassemble to the same instructions as the general encoder.
- `:c::mov-rax-lit` is the one immediate that widens. 2147483647 is
  `mov rax, imm32`. 2147483648 and −2147483649 are `movabs` of those values.
  −2147483648 stays the imm32 form, which is the correct boundary.
- `:c::sub-rsp` / `:c::add-rsp` switch at the same boundary, and 0 emits
  nothing. `jcc` 0..15, short and near, and `:c::negate-cc` flips the low bit.
- The fixed opcodes are what their names say: `c3`, `c9`, `48 99` (`cqo`),
  `0f 05`, `f3 48 ab`, `f3 48 a5`, `f3 a4`, `f3 a6`. llvm prints the implicit
  operands on the string ops; the bytes are the opcodes.

The grep asked for is empty. `:c::Prog`, `:c::Env`, `:c::Out`, `:c::Kids` and
`:c::Bnd` do not occur in `x86.wat`. The file is not loadable on its own:
`:c::hexlen` (three call sites) and `:c::str-data` (`:c::movzb-sib`) are
defined in `runtime.wat`. `str-data` is the one wat fact in the file — a
string's bytes start at offset 8. It is not one of the record types the split
was drawn to keep out.

No second width tracks a relocating address. The forms that choose a width
choose it from a literal or a frame size, both stable across the two passes.
Addresses stay on `:c::mov-rax`, which is ten bytes regardless. That part of
the comment is what the bytes do.

## What does not match

Three holes. Each emits a legal instruction for a different operand, which is
why none of the existing oracles can see it.

### 1. The byte forms never emit REX

`:c::mov-mr8`, `:c::mov-r8m` and `:c::add-ri8` concatenate an opcode and a
ModRM built from `:c::rcode`, and stop. No `:c::rex`, no `:c::rex-m`.

Of the 144 forms tried (every register as the byte operand; bases rax, rsp,
r12, r13), 124 disassemble to a different register. The 20 that match are
exactly al, cl, dl and bl, and only with a base that itself needs no REX.

| call | bytes | llvm-mc |
|---|---|---|
| `mov-mr8` bl, `[r12]` | `88 1c 24` | `mov byte ptr [rsp], bl` |
| `mov-r8m` `[r12]`, bl | `8a 1c 24` | `mov bl, byte ptr [rsp]` |
| `add-ri8` r12, 1 | `80 c4 01` | `add ah, 1` |
| `mov-mr8` sil, `[rax]` | `88 30` | `mov byte ptr [rax], dh` |
| `mov-mr8` r8b, `[rax]` | `88 00` | `mov byte ptr [rax], al` |

r12's code is 4. Without REX.B that code is rsp in the address and ah in the
byte register. r8's code is 0, so without REX it is al. The comment above
these functions names spl, bpl, sil and dil and says they are not used this
way. It does not name r8–r15 or a base of r12, and the functions do not
refuse any of them.

Shipped callers stay inside the safe subset: `add-ri8` of rdx, `mov-mr8` of
rdx into `[rsi]` and of rax into `[rdi]`, `mov-r8m` of `[rsi]` into rdx.
`:c::movzb` is not one of these — it goes through `:c::rm` and does emit REX,
and r12-as-index is correct there. So nothing in this tree executes the bad
encoding. The next caller that passes any other register gets a byte the
disassembler reads as a different one, and every oracle stays green.

### 2. rsp as an index is silently "no index"

SIB index code 4 with REX.X clear means there is no index. rsp is code 4 and
`:c::rext?` of it is false, which is correct for rsp as a *base* and fatal for
rsp as an *index*. The encoder does not refuse it.

| call | llvm-mc |
|---|---|
| `lea rcx, [rax + rsp]` | `lea rcx, [rax + riz]` |
| `lea rcx, [rax + 2*rsp]` | `lea rcx, [rax + 2*riz]` |
| `lea rcx, [r12 + rsp]` | `lea rcx, [r12]` |

`riz` is llvm's name for the no-index encoding. The scale is ignored by the
processor when the index field says none, so these are not `[rax+rsp]` at any
scale. r12 as an index is fine, because it sets REX.X and the same code 4
then really is r12. No shipped call passes rsp as an index. Same shape as the
byte hole: legal bytes, wrong operand, nothing to catch it until something
emits it.

### 3. A too-wide immediate is truncated, except on the one path that checks

`:asm::le` of a value into fewer bytes keeps the low bytes and does not
report that the value did not fit.

| value | `:asm::le` width 1 | same bytes as |
|---|---|---|
| −129 | `7f` | +127 |
| 128 | `80` | −128 |
| 256 | `00` | 0 |

`:c::disp8?` and `:c::imm32?` know the ranges, and the 64-bit memory forms and
`:c::mov-rax-lit` consult them. The other immediate forms consult `disp8?`
only to pick between one byte and four, and then trust `:asm::le`. Four is
not checked against `imm32?`.

| call | llvm-mc reads it as |
|---|---|
| `cmp-ri rax, 2147483648` | `cmp rax, -2147483648` |
| `add-ri`, `sub-ri`, `and-ri`, `mov-ri`, `imul3` of the same | the same truncation |
| `cmp-ri rax, -2147483649` | `cmp rax, 2147483647` |
| `mov-rax-lit` of 2147483648 | `movabs rax, 2147483648` |
| `shl-ri rax, 256` | `shl rax, 0` |
| `shl-ri rax, -1` | `shl rax, 255` |

`:c::mov-ri` is what an integer literal is lowered through
(`elf/compile.wat`, the `"int"` arm of the select emitter and the literal
arm beside it). A literal inside signed 32 is fine — the sweep matches there.
A literal outside it becomes the low four bytes, sign-extended, and the
interpreter would have kept the i64. `elf-run` would catch that on a program
that returns the constant. Nothing in the suite is that program.

The branch helpers do not consult `disp8?` at all. `:c::br-over` of a
256-hex-digit body (128 bytes) encodes `eb 80`, which llvm-mc reads as
`jmp -128`. A forward skip of 128 became a backward jump of 128. The shipped
uses — the short arms in `str_eq`, `str_starts`, the digit loop — are well
under that. `:c::br-len` will do the same the first time a length handed to
it is outside −128..127, and it will still assemble.

## What this does not touch

No timed binary was shown to contain a wrong encoding. The 64-bit instructions
those loops are made of are the instructions their disassembly says they are.
The holes are forms the encoder will emit, and does not emit today, for which
every green oracle would stay green.
