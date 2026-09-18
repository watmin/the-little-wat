;; Advent of Code's exponential-string shape, in wat: a polymer that grows between every pair.
;;
;; The input is a template, a blank line, then rules `AB -> C`: after a step, every adjacent pair
;; AB has a C inserted between them. The string doubles every step, so after 40 steps it is
;; astronomical and cannot be built — the answer is a count of PAIRS, not of characters.
;;
;; Part one: the commonest element's count minus the rarest's, after 10 steps.
;; Part two: the same after 40 steps.
;;
;; day10 made this point with nine counters; this one makes it with a hundred, keyed by STRING,
;; which is the part that costs. Two `HashMap`s are rebuilt from scratch on every step -- 100
;; pair keys and 10 element keys, forty times -- and F-057 says a `HashMap` copies on every
;; insert where a `PersistentMap` shares. At a hundred keys it does not matter; day05 is where
;; the same choice cost 115 seconds. The rule table is read-only, so it stays a `HashMap`.
;;
;; The counts reach 2.1 x 10^12, which is inside i64. day10's reached 2.6 x 10^21 and was not.
;;
;; The puzzle and its input are ours (aoc/input/day14-polymer.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day14-polymer.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day14-polymer.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Tally (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
(:wat::core::typealias :aoc::Rules (:wat::core::HashMap :- [:wat::core::String :wat::core::String]))

;; pair counts and element counts travel together, because a step changes both
(:wat::core::defrecord :aoc::State [pairs <- :aoc::Tally  counts <- :aoc::Tally])

(:wat::core::defn :aoc::get0 [t <- :aoc::Tally k <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::hashmap::get t k)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :aoc::add [t <- :aoc::Tally k <- :wat::core::String n <- :wat::core::i64] -> :aoc::Tally
  (:wat::hashmap::assoc t k (:wat::core::+ (:aoc::get0 t k) n)))

(:wat::core::defn :aoc::rule-for [r <- :aoc::Rules k <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::hashmap::get r k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} ""]))

(:wat::core::defn :aoc::parse-rules [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Rules] -> :aoc::Rules
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:wat::core::let [parts (:wat::string::split (:wat::core::nth ls i) " -> ")]
      (:aoc::parse-rules ls (:wat::core::+ i 1)
        (:wat::hashmap::assoc acc (:wat::core::nth parts 0) (:wat::core::nth parts 1))))))

(:wat::core::defn :aoc::seed-pairs [s <- :wat::core::String i <- :wat::core::i64 acc <- :aoc::Tally] -> :aoc::Tally
  (:wat::core::if (:wat::core::>= (:wat::core::+ i 1) (:wat::string::length s)) acc
    (:aoc::seed-pairs s (:wat::core::+ i 1)
      (:aoc::add acc (:wat::string::subs s i (:wat::core::+ i 2)) 1))))

(:wat::core::defn :aoc::seed-counts [s <- :wat::core::String i <- :wat::core::i64 acc <- :aoc::Tally] -> :aoc::Tally
  (:wat::core::if (:wat::core::>= i (:wat::string::length s)) acc
    (:aoc::seed-counts s (:wat::core::+ i 1)
      (:aoc::add acc (:wat::string::subs s i (:wat::core::+ i 1)) 1))))

;; one pair, expanded: AB with rule C becomes AC and CB, and one more C exists
(:wat::core::defn :aoc::expand [r <- :aoc::Rules st <- :aoc::State ks <- :aoc::Lines
                                old <- :aoc::Tally i <- :wat::core::i64] -> :aoc::State
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) st
    (:wat::core::let
      [pair (:wat::core::nth ks i)
       n (:aoc::get0 old pair)
       m (:aoc::rule-for r pair)
       l (:wat::string::concat (:wat::string::subs pair 0 1) m)
       rt (:wat::string::concat m (:wat::string::subs pair 1 2))]
      (:aoc::expand r
        (:aoc::State :pairs (:aoc::add (:aoc::add (:aoc::State/pairs st) l n) rt n)
                     :counts (:aoc::add (:aoc::State/counts st) m n))
        ks old (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::step [r <- :aoc::Rules st <- :aoc::State] -> :aoc::State
  (:aoc::expand r
    (:aoc::State :pairs (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])
                 :counts (:aoc::State/counts st))
    (:wat::hashmap::keys (:aoc::State/pairs st)) (:aoc::State/pairs st) 0))

(:wat::core::defn :aoc::steps [r <- :aoc::Rules st <- :aoc::State n <- :wat::core::i64] -> :aoc::State
  (:wat::core::if (:wat::core::= n 0) st (:aoc::steps r (:aoc::step r st) (:wat::core::- n 1))))

(:wat::core::defn :aoc::spread [t <- :aoc::Tally ks <- :aoc::Lines i <- :wat::core::i64
                                lo <- :wat::core::i64 hi <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) (:wat::core::- hi lo)
    (:wat::core::let [n (:aoc::get0 t (:wat::core::nth ks i))]
      (:aoc::spread t ks (:wat::core::+ i 1)
        (:wat::core::if (:wat::core::< n lo) n lo)
        (:wat::core::if (:wat::core::> n hi) n hi)))))

(:wat::core::defn :aoc::answer [r <- :aoc::Rules st <- :aoc::State n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [done (:aoc::steps r st n)
                    ks (:wat::hashmap::keys (:aoc::State/counts done))]
    (:aoc::spread (:aoc::State/counts done) ks 1
      (:aoc::get0 (:aoc::State/counts done) (:wat::core::nth ks 0))
      (:aoc::get0 (:aoc::State/counts done) (:wat::core::nth ks 0)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [blocks (:wat::string::split (:wat::io::read-file "aoc/input/day14-polymer.txt") "\n\n")
     template (:wat::string::trim (:wat::core::nth blocks 0))
     rules (:aoc::parse-rules (:aoc::non-empty (:wat::string::split (:wat::core::nth blocks 1) "\n")) 0
             (:wat::core::HashMap :- [:wat::core::String :wat::core::String]))
     start (:aoc::State
             :pairs (:aoc::seed-pairs template 0 (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
             :counts (:aoc::seed-counts template 0 (:wat::core::HashMap :- [:wat::core::String :wat::core::i64])))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day14-polymer.expected"
                         "aoc day14 polymer"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::answer rules start 10))
                           (int (:aoc::answer rules start 40))))))
