/* elf/bench/triple.c held to WAT'S SEMANTICS: every add is checked for overflow and traps.
   This is the F-133 comparison applied to the throughput loop -- `gcc -O2` is not the right
   yardstick for a language that traps, because it is compiling a different language.
   __builtin_add_overflow is the same check our `jo` is, expressed where gcc can see it. */
#include <stdio.h>
#include <stdlib.h>
static long go(long i, long a, long b, long c) {
  while (i) {
    long a2, b2, c2;
    if (__builtin_mul_overflow(i, 3L, &a2) || __builtin_add_overflow(a, a2, &a2)) abort();
    if (__builtin_mul_overflow(i, 5L, &b2) || __builtin_add_overflow(b, b2, &b2)) abort();
    if (__builtin_mul_overflow(i, 7L, &c2) || __builtin_add_overflow(c, c2, &c2)) abort();
    a = a2 > 1000000 ? a2 - 1000000 : a2;
    b = b2 > 2000000 ? b2 - 2000000 : b2;
    c = c2 > 3000000 ? c2 - 3000000 : c2;
    i -= 1;
  }
  return a + b + c;
}
int main(void) { printf("%ld\n", go(30000000L, 0L, 0L, 0L)); return 0; }
