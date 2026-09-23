/* Peak RSS of a child, in KB, on stderr. The program's own stdout is discarded.
   Why a C helper in a wat repo: there is no /usr/bin/time here, bash cannot read a
   dead child's VmHWM, and `perf stat -e minor-faults` is WRONG on this machine --
   transparent huge pages make 100 MB arrive as ~50 faults, so fault count does not
   track memory. It reported a 2,000,000-element vector as 1.1 MB. getrusage does
   track it: validated against a known mmap-and-touch at 1/10/100/500 MB, reading
   1.5/11.9/101.9/501.9. See F-185. */
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/resource.h>
int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: maxrss PROGRAM [ARGS...]\n"); return 2; }
  pid_t p = fork();
  if (p == 0) { freopen("/dev/null", "w", stdout); execvp(argv[1], &argv[1]); _exit(127); }
  int st; waitpid(p, &st, 0);
  struct rusage ru; getrusage(RUSAGE_CHILDREN, &ru);
  fprintf(stderr, "%ld\n", ru.ru_maxrss);
  return WIFEXITED(st) ? WEXITSTATUS(st) : 1;
}
