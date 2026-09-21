# BRIEF — audit the assembly tooling itself

Three strikes in a row landed on my *claims*. This asks you at the layer underneath: the
thing that emits the bytes. Every performance argument in FINDINGS.md rests on the encoder
being correct, and the encoder has never been audited against anything except our own
output.

## Why this layer, and why now

The oracles that work here all share a shape: **two independent things that must agree.**

- `tools/bootstrap.sh` — the interpreted compiler's output against the native compiler's,
  74 binaries byte-identical, then stage1 == stage2. Catches "the compiler disagrees with
  itself."
- `tools/elf-run.sh` — 30 compiled programs against the wat-rs interpreter running the same
  source. Catches "the compiled answer is wrong."
- `tools/emitted.sh` (new today) — this build's emitted code against the previous build's.
  Catches "a refactor that claimed to be pure was not."
- `tools/vs-c.sh` — four C builds per section, every run pinned.

**None of them audits the encoder against an independent assembler.** If
`elf/lib/x86.wat` emits a wrong-but-consistent encoding, every oracle above stays green:
the interpreter and the native compiler agree because they run the same encoder, the
differential agrees because the wrong bytes still compute the right answer, and the
fixpoint agrees because it is the same bytes twice. The failure mode is an instruction
that is *legal, decodes to something else than intended, and happens to work*.

`tools/rt-disasm.sh` is the closest thing — it asks the compiler for a routine's bytes and
runs objdump beside the claim each routine makes. That is one direction (do the bytes
disassemble to what the comment says) over 34 runtime routines. It does not cover the
encoder's full surface, and nothing cross-checks against `as`/`llvm-mc`.

## The rooms

- `elf/lib/x86.wat` — the whole encoder, ~670 lines. Knows nothing about wat: the grep for
  `:c::Prog|:c::Env|:c::Out|:c::Kids|:c::Bnd` must return 0, and that seam is load-bearing.
  Registers are renumbered so the four callee-saved ones are indices 0–3 (`:c::rcode` maps
  to the x86 encoding). REX/ModRM/SIB are built by `:c::rex`, `:c::modrm`, `:c::mrm`,
  `:c::rm`, `:c::rr`, `:c::rm-at`.
- `elf/lib/asm.wat` — the hex/number layer beneath it (`:asm::le`, `:asm::le-neg`,
  `:asm::u8`, `:asm::ascii`). You already found a real bug through `:asm::le-neg` today.
- `elf/bench/asmbits.wat` — exercises that layer both directions.
- `tools/rt-disasm.sh` — the existing one-directional check.

## What I am asking

**Find a way to cross-check the encoder against something that did not come from us.**
`as`, `llvm-mc`, `objdump`, Capstone — whatever this machine has. The shape I imagine is:
enumerate what `x86.wat` can emit across its operand space, encode each one, and disassemble
it with an independent tool; any disagreement is a defect. But the shape is yours to choose —
you looked at a coredump today and got further than I did reasoning from the diff.

Specifically worth probing, because each would survive every oracle we have:

1. **Operand-space holes.** `:c::rcode`/`:c::rext?` renumber sixteen registers. Does every
   (src, dst) pair encode correctly, including `rsp`/`rbp`/`r12`/`r13`, which are the four
   that need SIB or forced-disp8 special cases? `r12` as a base means SIB; `r13` as a base
   with mod=0 means disp8. If one of those is wrong in a form we never emit today, it is a
   landmine for the next instruction someone adds.
2. **Width selection.** `:c::disp8?`/`:c::imm32?` choose encoding width from a VALUE. Both
   passes must agree, and `mov-rax` deliberately keeps a fixed-width `movabs` for that
   reason. Is any *other* value-dependent width reachable by something that changes between
   the measuring pass and the emitting pass?
3. **Byte registers.** `:c::mov-mr8`/`:c::mov-r8m` emit no REX, so indices 4–7 would name
   `ah/ch/dh/bh` rather than `spl/bpl/sil/dil`. C-182 used `%dl` and is fine. Is any caller
   one refactor away from silently addressing the wrong half-register?
4. **The seam.** Does `x86.wat` still know nothing about wat? A single `:c::Prog` in there
   and the module boundary C-174 bought is gone.

## What I am NOT asking

Do not re-audit the findings. F-155 through F-158 are settled and you settled them.

## Ground

Tree at `3ef4797`. `./tools/bootstrap.sh` self-hosts to a byte-identical fixpoint in ~7
minutes and regenerates the negative tests; `./tools/elf-run.sh` runs the differential;
`./tools/emitted.sh check` reports any emitted program whose bytes moved.

An encoder defect found here invalidates more than a finding — it would mean some of the
binaries we have been timing are not the instructions we think they are.
