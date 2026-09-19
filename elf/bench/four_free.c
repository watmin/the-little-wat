/* four.c with libc removed entirely: raw syscalls, own entry point.
   This is the honest size opponent -- what C looks like when it stops paying for libc. */
static long sys_write(long fd, const char *b, long n) {
  long r; __asm__ volatile ("syscall" : "=a"(r) : "a"(1), "D"(fd), "S"(b), "d"(n)
                            : "rcx", "r11", "memory"); return r; }
static void sys_exit(long c) {
  __asm__ volatile ("syscall" :: "a"(60), "D"(c)); __builtin_unreachable(); }
void _start(void) { sys_write(1, "4\n", 2); sys_exit(0); }
