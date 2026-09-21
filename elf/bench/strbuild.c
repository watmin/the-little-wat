/* Controls for elf/bench/strbuild.wat, and there are two of them on purpose.
 *
 * FILL is what gcc makes of the naive `s[i]='x'` loop: a vectorised memset, no per-element
 * work at all. It is the floor, not an opponent -- C is not appending there, it is filling a
 * buffer it already sized.
 *
 * APPEND is the like-for-like: a call per character that checks capacity and grows, which is
 * what `str_cat_own` does. wat's `concat` has VALUE semantics -- it returns a new String -- so
 * it must check ownership at runtime; C's `s[i]=c` promises nothing and checks nothing.
 * Comparing against FILL measures the semantics, comparing against APPEND measures the code.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *buf; static size_t len, cap;

__attribute__((noinline)) static void append(char c) {
  if (len + 1 > cap) { cap = cap ? cap * 2 : 16; buf = realloc(buf, cap); }
  buf[len++] = c;
}

int main(int argc, char **argv) {
  long n = 5000000 * argc;
  if (argc > 1 && argv[1][0] == 'f') {           /* FILL */
    char *s = malloc(n + 1);
    for (long i = 0; i < n; i++) s[i] = 'x';
    printf("%ld\n", n); free(s); return 0;
  }
  for (long i = 0; i < n; i++) append('x');      /* APPEND */
  printf("%zu\n", len); free(buf); return 0;
}
