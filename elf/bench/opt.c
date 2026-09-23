/* The same loop in C: a tagged union returned BY VALUE. System V puts it in RAX:RDX, so C
   allocates nothing either -- this is the honest opponent for our tier 1, not a strawman.
   The payload mirrors our String: a length-prefixed buffer, so `length` is one load on both
   sides rather than a strlen walk.

   **Both inputs are opaque ON PURPOSE, and F-182 is why.** The first version of this file
   passed a `static const` buffer and looped over literal bounds. gcc proved n >= 0 from those
   bounds and emitted a three-instruction `pick.constprop.0` that never reads its argument:
   `lea buf,%rdx; xor %eax,%eax; ret` -- the sign test gone, the A_NONE arm gone, the payload
   folded to a link-time address. The C column was not measuring a cheaper enum, it was
   measuring a function that returns two compile-time constants, and it read 220,528,567
   instructions against the 321,835,409 an honest `pick` costs: a 46% understatement that
   made our deficit look like 2.82x when it is 1.93x.

   The two volatile reads are hoisted OUT of the loop by both compilers (verified in the
   disassembly), so they add nothing per iteration -- they only deny a whole-program proof
   that deletes the benchmark. This is not handicapping gcc: with the inputs unknown it still
   emits better code than we do, a branchless `cmovs` where we branch. A row whose opponent
   optimises away the operation in the header is not a comparison, it is a broken fixture --
   the same mistake rec.c made when a literal bound let it fold to a closed form. */
#include <stdio.h>
typedef enum { A_SOME, A_NONE } tag_t;
typedef struct { tag_t tag; const long *value; } a_t;
__attribute__((noinline)) static a_t pick(const long *s, long n) {
  a_t r; if (n < 0) { r.tag = A_NONE; r.value = 0; } else { r.tag = A_SOME; r.value = s; }
  return r;
}
static const long buf[2] = { 4, 0 };
static const long *volatile buf_p = buf;   /* denies constprop of the payload */
static volatile long base_v = 0;           /* denies the proof that i >= 0 */
int main(void) {
  const long *s = (const long *)buf_p;
  long base = base_v, acc = 0;
  for (long i = base; i < base + 20000000L; i++) {
    a_t o = pick(s, i); acc += (o.tag == A_SOME) ? o.value[0] : 0;
  }
  printf("%ld\n", acc);
  return 0;
}
