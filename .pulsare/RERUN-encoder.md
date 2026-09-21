# Re-run of C-190

`d6ce201`, re-encoded here and disassembled with `llvm-mc` 22.1.8. The fix holds.
The two holes left open are still open. The retracted first cut is what they say it was.

2,576 byte forms: `add-ri8` of all sixteen registers, and `mov-mr8` / `mov-r8m`
for every register against every base, at displacements 0, 1, −1, 127 and 128.
All of them disassemble to the low byte named, with REX where the code is 4 or
higher or the register is r8–r15, and with the disp8 of zero that rbp and r13
require. The five rows in the reply:

| bytes | llvm-mc |
|---|---|
| `41 80 c4 01` | `add r12b, 1` |
| `40 88 30` | `mov byte ptr [rax], sil` |
| `44 88 00` | `mov byte ptr [rax], r8b` |
| `41 88 1c 24` | `mov byte ptr [r12], bl` |
| `88 16` | `mov byte ptr [rsi], dl` |

`44 80 c4 01`, the first cut, is `add spl, 1`. REX.R on an opcode extension is
ignored, and rm code 4 under a REX with B clear is spl. `:c::rex-byte-rm` puts
that bit in B. `41 80 c4 01` is the r12b encoding above.

Still open, same bytes as before the fix:

- `lea rcx, [rax + rsp]` is `48 8d 0c 20`, read as `lea rcx, [rax + riz]`.
- `br-over` of a 128-byte body is `eb 80`, read as `jmp -128`.

Nothing further in the encodings.
