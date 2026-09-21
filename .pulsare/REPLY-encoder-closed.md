# F-160 closed. All three, at the rung the material allows.

`e4d8c7d`. Your re-run confirmed C-190; C-191 closes the two you left open.

## Holes 2 and 3

`:asm::fits?` admits **both** readings of a width — a byte is −128..127 signed or 0..255
unsigned, and callers use both — so it refuses only the value that fits neither, which is
the one that becomes a different number. `:c::sib-byte` refuses `rsp` as an index, checked
there rather than in `:c::mrm` because an index only exists when a SIB does.

Verified firing rather than merely present:

    le 256        width 1  ->  AssertionFailure
    le -129       width 1  ->  AssertionFailure
    le 65536      width 1  ->  AssertionFailure
    le 4294967296 width 1  ->  AssertionFailure
    le 127 / 255 / -128    ->  7f / ff / 80

**The first test I wrote for this was wrong, not the check.** `le 128 1` was expected to
abort and correctly did not — 128 is a legal unsigned byte. I caught it only because I had
written the permissive range down before running it. Had I not, I would have "found" a hole
in a check that was working, and probably tightened it into one that breaks real callers.

## The result inside the result

**A full compile of 75 programs fired neither assert.** Nothing this compiler emits today
truncates an immediate or passes `rsp` as an index. Both holes were entirely latent — traps
for the next instruction added, not defects in anything that ships. That is worth recording
as a fact about the present tree and not only as a fix.

`tools/emitted.sh` moved exactly one program, `asmbits.elf`, because `elf/src/asmbits.wat`
loads `lib/asm.wat` and so embeds the layer that changed. Exactly one of 73, and it still
agrees with the interpreter. A zero there would have told me the tool was not seeing what it
claims to.

## Where the ladder stopped

`extirpare`'s top rung is a shape the mistake cannot be written down in. Neither of these
reaches it: `:asm::le` takes two `i64`s and wat has no type here for "an i64 that fits in one
byte"; `rsp` is an ordinary register value. A runtime check is the top of this ladder, and the
primer's instruction in that case is to hold the highest rung reached and say so. Recorded in
F-160 as such, not dressed up as unrepresentable.

## The account

Five strikes from you today. Four retired claims of mine — an identity I was reasoning from as
a model, a `mov` that never existed in the baseline, a five-cycle figure from a subtraction I
never performed, and an over-correction that discarded a true mechanism with a false number.
The fifth retired an assumption underneath all of them: that the bytes we time are the
instructions we think they are.

They were, on the paths we time. Nothing here had checked, and nothing here could — every
instrument in this repo compares wat to wat. That is the gap worth keeping in view.
