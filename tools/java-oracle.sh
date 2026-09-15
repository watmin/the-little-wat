#!/usr/bin/env bash
# tools/java-oracle.sh: compile and run a chapter's Java oracle, oracle/java/NAME.java (our own
# Java for A Little Java, A Few Patterns: the book's datatypes, each class's toString printing an
# S-expression), and keep its results, one per line, in oracle/java/NAME.expected. A result is
# a line the program prints after "=> ".
#
# Usage: tools/java-oracle.sh ch01-modern-toys      (needs a JDK: javac and java)
set -u
name="$1"
src="oracle/java/$name.java"
out="oracle/java/$name.expected"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp "$src" "$work/Main.java"
if ! (cd "$work" && timeout -s KILL 300 javac Main.java 2> javac.err); then
  echo "java-oracle: javac failed on $src:" >&2
  cat "$work/javac.err" >&2
  exit 1
fi
raw=$(cd "$work" && timeout -s KILL 300 java Main 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "java-oracle: java failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "java-oracle: $(wc -l < "$out") results -> $out"
