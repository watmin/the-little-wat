/* The control for elf/bench/rec.wat: the same loop over a four-field struct.
   The count comes from argc so gcc cannot fold the loop into a closed form --
   the first version of this file was folded away entirely and measured nothing. */
#include <stdio.h>
struct St { long a, b, c, d; };
int main(int argc, char **argv) {
  (void)argv;
  long n = 2000000 * argc;
  struct St s = {0, 1, 2, 3};
  for (long i = 0; i < n; i++) s.a = s.a + i;
  printf("%ld\n", s.a);
  return 0;
}
