#!/usr/bin/env python3
# tools/mal-shim.py: lets Make-a-Lisp's own test runner (vendor/mal/runtest.py) drive a wat mal.
#
# runtest.py talks to a REPL: it waits for a prompt, sends a line, and reads what is printed up
# to the next prompt. A wat program can't be that REPL by itself (FINDINGS F-049):
#   - its only stdout is :wat::kernel::println, which writes each value as one line of EDN, so
#     a String arrives quoted and escaped, every write ends its line, and no prompt can be
#     printed;
#   - its stdin is read by EDN frame, so a line that opens more than it closes, "(+ 1 2", runs
#     on into the next line instead of arriving alone.
# So both directions go as EDN, the only thing wat speaks, and this shim is the terminal the
# wat program lacks. It prints the prompt; sends each input line to the program as one EDN
# string; and turns each EDN string the program prints back into raw text, until the program
# prints :mal/done, its end-of-output marker. mal's readline asks for a line mid-form: the
# program prints :mal/readline and then its prompt, and the shim prints the prompt, reads the
# next input line, and sends it on.
#
# Usage: tools/mal-shim.py WAT-BINARY mal/stepN_name.wat

import json
import subprocess
import sys


def main():
    wat, prog = sys.argv[1], sys.argv[2]
    p = subprocess.Popen([wat, prog], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True, bufsize=1)
    while True:
        sys.stdout.write("user> ")
        sys.stdout.flush()
        line = sys.stdin.readline()
        if not line:
            p.stdin.close()
            p.wait()
            return
        # a terminal echoes what is typed; runtest.py (run with --no-pty) expects the echo
        sys.stdout.write(line)
        # an EDN string's escapes are JSON's for the text mal's tests send
        p.stdin.write(json.dumps(line.rstrip("\r\n")) + "\n")
        p.stdin.flush()
        while True:
            out = p.stdout.readline()
            if not out:
                sys.stdout.write("mal-shim: the wat program ended\n")
                sys.stdout.flush()
                return
            out = out.rstrip("\n")
            if out == ":mal/done":
                break
            if out == ":mal/readline":
                prompt = json.loads(p.stdout.readline().rstrip("\n"))
                sys.stdout.write(prompt)
                sys.stdout.flush()
                answer = sys.stdin.readline()
                sys.stdout.write(answer)
                p.stdin.write(json.dumps(answer.rstrip("\r\n")) + "\n")
                p.stdin.flush()
                continue
            try:
                text = json.loads(out)
            except ValueError:
                text = out  # not an EDN string (a failure record): pass it on as it came
            if not isinstance(text, str):
                text = out
            sys.stdout.write(text + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
