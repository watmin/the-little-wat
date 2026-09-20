/* The same work as elf/bench/scan.wat: count the byte 'e' in a text file. */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  FILE *f = fopen("elf/out/scan.txt", "rb");
  fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
  char *s = malloc(n + 1);
  if (fread(s, 1, n, f) != (size_t)n) return 1;
  fclose(f);
  long acc = 0;
  for (long i = 0; i < n; i++) if (s[i] == 'e') acc++;
  printf("%ld\n", acc);
  return 0;
}
