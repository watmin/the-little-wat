#!/bin/bash
# step.sh <namesfile> : drops only in those functions, check on; prints TRAP or OK
cd /tmp/stone3a-orch
{ printf '\n'; cat "$1"; printf '\n'; } > allow.txt
WAT_DROP_CHECK=1 timeout -s KILL 120 ./s1.elf > st1.log 2>&1; r1=$?
[ $r1 -ne 0 ] && { echo "S1FAIL $r1"; exit 2; }
cp elf/out/compiler.elf s2.elf
WAT_DROP_CHECK=1 timeout -s KILL 120 ./s2.elf > st2.log 2>&1; r2=$?
if [ $r2 -eq 132 ]; then echo TRAP; elif [ $r2 -eq 0 ]; then echo OK; else echo "OTHER $r2"; fi
