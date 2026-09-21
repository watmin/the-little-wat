/* The control for elf/bench/vecsum.wat: build an array of n longs one element at a time,
   then read every element back by index and sum them.

   LIKE-FOR-LIKE, deliberately. `append` is noinline and checks capacity on every element,
   because wat's `conj` is a call that checks a share count and may promote. A C program
   that malloc'd n*8 up front and filled it would be measuring the allocator, not the
   append -- that is the F-140/F-143 mistake, made twice in this repo already.

   The semantics still differ and the difference is wat's to justify: `conj` returns a VALUE
   and must prove the old vector is dead before extending in place, where `append` promises
   nothing and checks nothing. Comparing against this measures the CODE; the gap that remains
   is what the value semantics cost. */
#include <stdio.h>
#include <stdlib.h>

static long *buf; static size_t len, cap;

__attribute__((noinline)) static void append(long x) {
  if (len + 1 > cap) { cap = cap ? cap * 2 : 16; buf = realloc(buf, cap * sizeof(long)); }
  buf[len++] = x;
}

int main(int argc, char **argv) {
  (void)argv;
  long n = 2000000 * argc;
  for (long i = 0; i < n; i++) append(i);
  long s = 0;
  for (size_t i = 0; i < len; i++) s += buf[i];
  printf("%ld\n", s);
  free(buf);
  return 0;
}
