/* The control for elf/bench/parse.c: the same walk with no field extraction. */
#include <stdio.h>
#include <sys/mman.h>
int main(void) {
  long n = 2000000;
  long *p = mmap(0, n*16, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0);
  for (long i = 0; i < n; i++) { p[i*2] = i; p[i*2+1] = i; }
  long total = 0;
  for (long i = 0; i < n; i++) total += p[i*2];
  printf("%ld\n", total);
  return 0;
}
