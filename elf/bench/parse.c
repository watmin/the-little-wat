/* The same work as elf/bench/parse.wat: walk 16-byte records in mmap'd memory, pull byte fields
   out of a header word, filter on one and accumulate another. The only difference that matters is
   how a field is extracted -- C has `>>` and `&`; wat has neither, so it divides. */
#include <stdio.h>
#include <sys/mman.h>
static long fill(long *p, long n) {
  for (long i = 0; i < n; i++) {
    p[i*2]     = 4 + (i % 1024) * 256 + (i % 8) * 16777216;
    p[i*2 + 1] = i;
  }
  return 0;
}
static long scan(long *p, long n) {
  long hits = 0, total = 0;
  for (long i = 0; i < n; i++) {
    long w     = p[i*2];
    long proto = (w >> 24) & 0xff;
    long len   = (w >> 8) & 0xffff;
    if (proto == 6) { hits++; total += len; }
  }
  return hits * 1000000 + total;
}
int main(void) {
  long n = 2000000;
  long *p = mmap(0, n * 16, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  fill(p, n);
  printf("%ld\n", scan(p, n));
  return 0;
}
