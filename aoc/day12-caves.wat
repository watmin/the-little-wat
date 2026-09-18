;; Advent of Code's graph shape, in wat: a cave system, and every path through it.
;;
;; Each line is an edge, `a-b`. A cave named in lower case is SMALL and may be visited once; a
;; cave named in upper case is BIG and may be visited any number of times. No two big caves are
;; joined, so the walk terminates.
;;
;; Part one: how many distinct paths run from `start` to `end`.
;; Part two: the same, except that ONE small cave on the path may be visited twice.
;;
;; What this one is here for:
;;
;;   * **A map whose values are collections.** `HashMap<String, Vector<String>>` is the natural
;;     adjacency list and wat accepts the nesting — which is worth saying because F-058 records
;;     that the `PersistentMap` spelling of the same shape is REFUSED ("bracketed type must be a
;;     type keyword") unless the inner type is given a name. Here the inner type has a name
;;     anyway, because it reads better.
;;   * **Case, without a character.** "small" means "spelled in lower case", and wat has no
;;     character predicate; `:wat::string::to-lowercase` on the whole name and a comparison is
;;     the test, which is what the Clojure reference does too.
;;   * **Branching recursion that threads a set.** F-057 again: no set shares structure, so
;;     `seen` is a `PersistentMap` to `true` -- but unlike day09's flood fill, this one never has
;;     to give the set BACK. Each path owns its own `seen`, so the recursion returns a count and
;;     nothing else. That is the difference between exploring a graph and consuming one.
;;
;; The puzzle and its input are ours (aoc/input/day12-caves.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day12-caves.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day12-caves.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Names (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :aoc::Adj (:wat::core::HashMap :- [:wat::core::String :aoc::Names]))
(:wat::core::typealias :aoc::Seen (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool]))

(:wat::core::defn :aoc::neighbours [a <- :aoc::Adj k <- :wat::core::String] -> :aoc::Names
  (:wat::core::match (:wat::hashmap::get a k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :aoc::link [a <- :aoc::Adj x <- :wat::core::String y <- :wat::core::String] -> :aoc::Adj
  (:wat::hashmap::assoc a x (:wat::core::conj (:aoc::neighbours a x) y)))

(:wat::core::defn :aoc::build [ls <- :aoc::Lines i <- :wat::core::i64 a <- :aoc::Adj] -> :aoc::Adj
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) a
    (:wat::core::let [parts (:wat::string::split (:wat::core::nth ls i) "-")
                      x (:wat::core::nth parts 0)
                      y (:wat::core::nth parts 1)]
      (:aoc::build ls (:wat::core::+ i 1) (:aoc::link (:aoc::link a x y) y x)))))

;; no character predicate, so "is it lower case" is "does lowercasing change it"
(:wat::core::defn :aoc::small? [s <- :wat::core::String] -> :wat::core::bool
  (:wat::core::= s (:wat::string::to-lowercase s)))

(:wat::core::defn :aoc::walk [a <- :aoc::Adj twice? <- :wat::core::bool node <- :wat::core::String
                              seen <- :aoc::Seen used <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::if (:wat::core::= node "end") 1
    (:aoc::walk-each a twice? (:aoc::neighbours a node) 0 seen used 0)))

(:wat::core::defn :aoc::walk-each [a <- :aoc::Adj twice? <- :wat::core::bool ns <- :aoc::Names
                                   i <- :wat::core::i64 seen <- :aoc::Seen used <- :wat::core::bool
                                   acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ns)) acc
    (:wat::core::let [n (:wat::core::nth ns i)]
      (:aoc::walk-each a twice? ns (:wat::core::+ i 1) seen used
        (:wat::core::+ acc
          (:wat::core::cond
            ((:wat::core::= n "start") 0)
            ((:wat::core::not (:aoc::small? n)) (:aoc::walk a twice? n seen used))
            ((:wat::core::not (:wat::map::contains-key? seen n))
              (:aoc::walk a twice? n (:wat::map::assoc seen n true) used))
            ;; the one small cave that may repeat, spent here
            ((:wat::core::and twice? (:wat::core::not used)) (:aoc::walk a twice? n seen true))
            (:else 0)))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [a (:aoc::build (:aoc::lines "aoc/input/day12-caves.txt") 0
         (:wat::core::HashMap :- [:wat::core::String :aoc::Names]))
     seen0 (:wat::map::assoc (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool]) "start" true)
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day12-caves.expected"
                         "aoc day12 caves"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::walk a false "start" seen0 false))
                           (int (:aoc::walk a true "start" seen0 false))))))
