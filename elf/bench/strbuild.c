/* The control for elf/bench/strbuild.wat: build an n-character string by appending.
   C appends into a buffer it owns; the comparison that matters is not this one but
   strbuild vs strbuild2, which have no C compiler in them at all (F-141). */
#include <stdio.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  (void)argv;
  long n = 200000 * argc;
  char *s = malloc(n + 1);
  for (long i = 0; i < n; i++) s[i] = 'x';
  s[n] = 0;
  printf("%ld\n", (long)n);
  free(s);
  return 0;
}
