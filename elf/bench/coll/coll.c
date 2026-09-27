/* Collections bench. argv: WORKLOAD N free|leak
 * free  — malloc/free, mutable, the imperative floor.
 * leak  — the old bump: allocate the next version and never free the last.
 * The size is argv, and a volatile load of it, so the loop is not a constant (F-184).
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static volatile long vsize;

static long nsec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1000000000L + ts.tv_nsec;
}

static int cmp_long(const void *a, const void *b) {
  long x = *(const long *)a, y = *(const long *)b;
  return (x > y) - (x < y);
}

static void tails(long *b, long m) {
  qsort(b, (size_t)m, sizeof(long), cmp_long);
  long p50 = b[(50 * m + 99) / 100 - 1];
  long p99 = b[(99 * m + 99) / 100 - 1];
  long p999 = b[(999 * m + 999) / 1000 - 1];
  printf("TAIL %ld %ld %ld %ld\n", p50, p99, p999, b[m - 1]);
}

static void die(const char *s) { perror(s); exit(2); }

static void w1(long n, int leak, int timed) {
  long *a = malloc((size_t)n * sizeof(long));
  if (!a) die("malloc");
  long *batches = NULL; long m = 0, t0 = 0;
  if (timed) { batches = calloc((size_t)(n / 1000 + 2), sizeof(long)); t0 = nsec(); }
  for (long i = 0; i < n; i++) {
    a[i] = i;
    if (timed && (i + 1) % 1000 == 0) {
      long t1 = nsec(); batches[m++] = t1 - t0; t0 = t1;
    }
  }
  long s = 0;
  for (long i = 0; i < n; i++) s += a[i];
  printf("ANSWER %ld\n", s);
  if (timed) tails(batches, m);
  if (!leak) free(a);
  free(batches);
}

static void w2(long n, int leak, int timed) {
  char **a = malloc((size_t)n * sizeof(char *));
  if (!a) die("malloc");
  long *batches = NULL; long m = 0, t0 = 0;
  if (timed) { batches = calloc((size_t)(n / 1000 + 2), sizeof(long)); t0 = nsec(); }
  long sum = 0;
  for (long i = 0; i < n; i++) {
    char *s = malloc(3);
    if (!s) die("malloc");
    s[0] = 'a'; s[1] = 'b'; s[2] = 0;
    a[i] = s;
    sum += (long)strlen(s);
    if (timed && (i + 1) % 1000 == 0) {
      long t1 = nsec(); batches[m++] = t1 - t0; t0 = t1;
    }
  }
  /* read them back, so the stores are not dead */
  long check = 0;
  for (long i = 0; i < n; i++) check += (long)strlen(a[i]);
  printf("ANSWER %ld\n", check);
  if (check != sum) exit(3);
  if (!leak) {
    for (long i = 0; i < n; i++) free(a[i]);
    free(a);
  }
  if (timed) tails(batches, m);
  free(batches);
}

static void w3(long n, int leak, int timed) {
  long *cur = malloc(sizeof(long));
  if (!cur) die("malloc");
  *cur = 0;
  long *batches = NULL; long m = 0, t0 = 0;
  if (timed) { batches = calloc((size_t)(n / 1000 + 2), sizeof(long)); t0 = nsec(); }
  for (long i = 0; i < n; i++) {
    if (leak) {
      long *next = malloc(sizeof(long));
      if (!next) die("malloc");
      *next = i + 1;
      cur = next;
    } else {
      *cur = i + 1;
    }
    if (timed && (i + 1) % 1000 == 0) {
      long t1 = nsec(); batches[m++] = t1 - t0; t0 = t1;
    }
  }
  printf("ANSWER %ld\n", *cur);
  if (!leak) free(cur);
  if (timed) tails(batches, m);
  free(batches);
}

/* Keep every prefix. Without sharing this is triangular. */
static void w4(long n, int leak, int timed) {
  long **vs = malloc((size_t)n * sizeof(long *));
  if (!vs) die("malloc");
  long *batches = NULL; long m = 0, t0 = 0;
  if (timed) { batches = calloc((size_t)(n / 1000 + 2), sizeof(long)); t0 = nsec(); }
  for (long i = 0; i < n; i++) {
    long *row = malloc((size_t)(i + 1) * sizeof(long));
    if (!row) die("malloc");
    if (i > 0) memcpy(row, vs[i - 1], (size_t)i * sizeof(long));
    row[i] = i;
    vs[i] = row;
    if (!leak && i > 0) { /* keep every version: do not free */ }
    if (timed && (i + 1) % 1000 == 0) {
      long t1 = nsec(); batches[m++] = t1 - t0; t0 = t1;
    }
  }
  long s = 0;
  for (long i = 0; i < n; i++) s += vs[i][i];
  printf("ANSWER %ld\n", s);
  if (!leak) {
    for (long i = 0; i < n; i++) free(vs[i]);
    free(vs);
  }
  if (timed) tails(batches, m);
  free(batches);
}

static void w5(long n, int leak, int timed) {
  char *s = malloc(1);
  if (!s) die("malloc");
  size_t len = 0, cap = 1;
  long *batches = NULL; long m = 0, t0 = 0;
  if (timed) { batches = calloc((size_t)(n / 1000 + 2), sizeof(long)); t0 = nsec(); }
  for (long i = 0; i < n; i++) {
    if (leak) {
      char *nbuf = malloc(len + 1);
      if (!nbuf) die("malloc");
      if (len) memcpy(nbuf, s, len);
      nbuf[len] = 'a';
      s = nbuf;
      len++;
    } else {
      if (len + 1 > cap) {
        cap = cap < 8 ? 8 : cap * 2;
        char *nbuf = realloc(s, cap);
        if (!nbuf) die("realloc");
        s = nbuf;
      }
      s[len++] = 'a';
    }
    if (timed && (i + 1) % 1000 == 0) {
      long t1 = nsec(); batches[m++] = t1 - t0; t0 = t1;
    }
  }
  printf("ANSWER %ld\n", (long)len);
  if (!leak) free(s);
  if (timed) tails(batches, m);
  free(batches);
}

int main(int argc, char **argv) {
  if (argc != 5) {
    fprintf(stderr, "usage: coll WORK N free|leak plain|timed\n");
    return 2;
  }
  vsize = strtol(argv[2], 0, 10);
  long n = vsize;
  int leak = argv[3][0] == 'l';
  int timed = argv[4][0] == 't';
  switch (argv[1][1]) {
    case '1': w1(n, leak, timed); break;
    case '2': w2(n, leak, timed); break;
    case '3': w3(n, leak, timed); break;
    case '4': w4(n, leak, timed); break;
    case '5': w5(n, leak, timed); break;
    default: fprintf(stderr, "bad workload\n"); return 2;
  }
  return 0;
}
