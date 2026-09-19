/* maxrss.c -- run a program and report its peak resident memory.
 *
 * There is no /usr/bin/time on this machine and the compiled binaries cannot measure themselves
 * (no getrusage intrinsic, and adding one would make the compiled language diverge further --
 * F-119). So this forks, execs, and reads ru_maxrss out of wait4.
 *
 *   gcc -O2 -o out_maxrss maxrss.c && ./out_maxrss ./prog args...
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/resource.h>

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: maxrss PROG [ARGS...]\n"); return 2; }
  pid_t pid = fork();
  if (pid < 0) { perror("fork"); return 2; }
  if (pid == 0) {
    freopen("/dev/null", "w", stdout);
    execv(argv[1], &argv[1]);
    perror("exec");
    _exit(127);
  }
  int status; struct rusage ru;
  if (wait4(pid, &status, 0, &ru) < 0) { perror("wait4"); return 2; }
  printf("%ld\n", ru.ru_maxrss);            /* KiB */
  return WIFEXITED(status) ? WEXITSTATUS(status) : 1;
}
