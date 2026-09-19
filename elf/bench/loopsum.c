/* The same loop as elf/bench/loopsum.wat, for the compute comparison. The conditional
   subtraction keeps gcc from solving it in closed form. */
#include <stdio.h>
static long go(long i, long acc) {
  while (i) { long a = acc + i * 3; acc = a > 1000000 ? a - 1000000 : a; i -= 1; }
  return acc;
}
int main(void) { printf("%ld\n", go(100000000L, 0L)); return 0; }
