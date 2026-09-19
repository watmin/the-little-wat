/* 100000 integers to stdout, for the I/O comparison. */
#include <stdio.h>
int main(void) { for (long i = 0; i < 100000; i++) printf("%ld\n", i); return 0; }
