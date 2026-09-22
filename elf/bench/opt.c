/* The same loop in C: a tagged union returned BY VALUE. System V puts it in RAX:RDX, so C
   allocates nothing either -- this is the honest opponent for our tier 1, not a strawman.
   The payload mirrors our String: a length-prefixed buffer, so `length` is one load on both
   sides rather than a strlen walk. */
#include <stdio.h>
typedef enum { A_SOME, A_NONE } tag_t;
typedef struct { tag_t tag; const long *value; } a_t;
__attribute__((noinline)) static a_t pick(const long *s, long n) {
  a_t r; if (n < 0) { r.tag = A_NONE; r.value = 0; } else { r.tag = A_SOME; r.value = s; }
  return r;
}
int main(void) {
  static const long buf[2] = { 4, 0 };
  long acc = 0;
  for (long i = 0; i < 20000000L; i++) { a_t o = pick(buf, i); acc += (o.tag == A_SOME) ? o.value[0] : 0; }
  printf("%ld\n", acc);
  return 0;
}
