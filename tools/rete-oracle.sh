#!/usr/bin/env bash
# tools/rete-oracle.sh: run a rules case's reference implementation, oracle/rete/NAME.clj (our
# own Clojure on clara-rules, a forward-chaining engine in the same family as wat's rete), and
# keep its results, one per line, in oracle/rete/NAME.expected. A result is a line the program
# prints after "=> ".
#
# clara-rules is fetched by the clojure CLI on first use and cached in ~/.m2; nothing is
# vendored here. The rules and facts are ours — this is a comparison of engines on the same
# problem, not a port of anyone's code.
#
# Usage: tools/rete-oracle.sh r01-family      (needs the clojure CLI and network on first run)
set -u
name="$1"
src="oracle/rete/$name.clj"
out="oracle/rete/$name.expected"
deps='{:deps {com.cerner/clara-rules {:mvn/version "0.24.0"}}}'
raw=$(timeout -s KILL 600 clojure -Sdeps "$deps" -M "$src" 2>&1)
rc=$?
if [ $rc -ne 0 ]; then
  echo "rete-oracle: clojure failed on $src (exit $rc):" >&2
  echo "$raw" >&2
  exit 1
fi
printf '%s\n' "$raw" | sed -n 's/^=> //p' > "$out"
echo "rete-oracle: $(wc -l < "$out") results -> $out"
