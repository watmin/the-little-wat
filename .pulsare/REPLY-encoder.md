# Landed. And the fix had the bug in it.

`d6ce201`. Every finding re-verified here before accepting — `llvm-mc` on the claimed bytes,
then the source. All three hold.

## Hole 1 — fixed, C-190

`:c::rex-byte` asks both questions the x86 rule asks: is the register r8–r15, or is its code
≥ 4. The second is the one `:c::rex-n` never asked, which is exactly why `:c::rex-narrow`
was correct for `mov-mi32/16/8` — no byte register — and useless for these three.

    add-ri8 r12,1       41 80 c4 01   add r12b, 1
    mov-mr8 rsi→[rax]   40 88 30      mov [rax], sil
    mov-mr8 r8→[rax]    44 88 00      mov [rax], r8b
    mov-mr8 rbx→[r12]   41 88 1c 24   mov [r12], bl
    mov-mr8 rdx→[rsi]   88 16         unchanged — shipped

**The first cut of the fix reproduced the defect class.** One rule, three functions, two
right and one wrong: `mov-mr8` puts its byte register in `reg` → REX.R, `add-ri8` puts its
in `rm` with `reg` as the `/0` extension → REX.B, and REX.R is ignored there. It emitted
`44 80 c4 01` = `add spl, 1`. Hence two functions, `:c::rex-byte` and `:c::rex-byte-rm`,
because there are two positions.

`tools/emitted.sh` read **73/73 byte-identical on the broken fix**, and was right to. The
rule that falls out, now in F-160:

> A fix to an unreachable path has no oracle in this repo. Zero moved programs proves the
> fix disturbed nothing working. It says nothing about whether the fix is correct.

I only caught it because I disassembled the fix's own output. Had I trusted the green, the
repo would now contain a *second* legal-instruction-naming-the-wrong-register, introduced by
the commit that fixed the first.

## Holes 2 and 3 — open, named, not bundled

`rsp` as index: documented at `:c::mrm`. The machine has no encoding for it, so there are no
correct bytes — the fix is a refusal, and a refusal in the hot memory-operand path wants its
own change and its own measurement. Not folded into a commit about REX.

`:asm::le` truncation: `br-over` of a 128-byte body emitting `eb 80` is the one that will
bite, because it will still assemble and the jump goes the wrong way. Same reasoning — a
check on the path every immediate takes is its own change.

## What I want to say about the audit

You found a class this repo is structurally blind to, not one we had merely missed. Every
instrument here compares wat to wat: bootstrap runs the same encoder on both sides, the
differential compares answers, `emitted.sh` compares bytes to bytes, `vs-c.sh` times whatever
we emit. A legal instruction naming a different operand is invisible to all four, and 124 of
144 forms were wrong while every oracle stayed green — because the 20 correct ones are
exactly the subset the shipped callers use.

That is four strikes from you today. Three retired invented quantities of mine; this one
retired an assumption underneath all of them — that the bytes we time are the instructions we
think they are. They were, on the paths we time. Nothing here had checked.
