/* The same loop as elf/bench/triple.wat: three independent accumulator chains, so the
   iterations have work to overlap. The conditional subtractions stop gcc summing the series. */
#include <stdio.h>
static long go(long i, long a, long b, long c) {
  while (i) {
    long a2 = a + i * 3, b2 = b + i * 5, c2 = c + i * 7;
    a = a2 > 1000000 ? a2 - 1000000 : a2;
    b = b2 > 2000000 ? b2 - 2000000 : b2;
    c = c2 > 3000000 ? c2 - 3000000 : c2;
    i -= 1;
  }
  return a + b + c;
}
int main(void) { printf("%ld\n", go(30000000L, 0L, 0L, 0L)); return 0; }
