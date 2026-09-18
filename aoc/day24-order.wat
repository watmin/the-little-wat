;; Advent of Code's dependency shape, in wat: jobs with prerequisites, put in order.
;;
;; Each line says `a before b`. Every job named anywhere must be done, and a job may only start
;; once everything that must come before it is finished.
;;
;; Part one: the order, choosing the alphabetically first job whenever several are ready — one
;; answer, as a comma-separated string.
;; Part two: the length of the longest chain of dependencies, counted in jobs.
;;
;; Part one needs the jobs in alphabetical order, and here `sort` is exactly right: the keys are
;; strings, the order wanted is the natural one, and there is nothing to sort BY. day17 is where
;; the same verb was the wrong shape, and day23 is where sorting twenty thousand to look at a
;; hundred was the only route. Three puzzles, three different verdicts on one verb.
;;
;; Part two is a depth memoised on the job's own name -- the chain is short and the graph small,
;; so a `PersistentMap` carried through the recursion is cheaper than day21's Lru and needs no
;; capacity guessed in advance (P-028).
;;
;; The puzzle and its input are ours (aoc/input/day24-order.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day24-order.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day24-order.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Names (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :aoc::Adj (:wat::core::HashMap :- [:wat::core::String :aoc::Names]))
(:wat::core::typealias :aoc::Counts (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
(:wat::core::typealias :aoc::Depths (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))

(:wat::core::defrecord :aoc::Edge [a <- :wat::core::String  b <- :wat::core::String])
(:wat::core::typealias :aoc::Edges (:wat::core::Vector :- [:aoc::Edge]))

(:wat::core::defn :aoc::after-of [adj <- :aoc::Adj k <- :wat::core::String] -> :aoc::Names
  (:wat::core::match (:wat::hashmap::get adj k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :aoc::deg-of [d <- :aoc::Counts k <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::hashmap::get d k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :aoc::parse [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Edges] -> :aoc::Edges
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:wat::core::let [w (:aoc::non-empty (:wat::string::split (:wat::core::nth ls i) " "))]
      (:aoc::parse ls (:wat::core::+ i 1)
        (:wat::core::conj acc (:aoc::Edge :a (:wat::core::nth w 0) :b (:wat::core::nth w 2)))))))

(:wat::core::defn :aoc::build-adj [es <- :aoc::Edges i <- :wat::core::i64 acc <- :aoc::Adj] -> :aoc::Adj
  (:wat::core::if (:wat::core::>= i (:wat::core::length es)) acc
    (:wat::core::let [e (:wat::core::nth es i)]
      (:aoc::build-adj es (:wat::core::+ i 1)
        (:wat::hashmap::assoc acc (:aoc::Edge/a e)
          (:wat::core::conj (:aoc::after-of acc (:aoc::Edge/a e)) (:aoc::Edge/b e)))))))

(:wat::core::defn :aoc::build-deg [es <- :aoc::Edges i <- :wat::core::i64 acc <- :aoc::Counts] -> :aoc::Counts
  (:wat::core::if (:wat::core::>= i (:wat::core::length es)) acc
    (:wat::core::let [b (:aoc::Edge/b (:wat::core::nth es i))]
      (:aoc::build-deg es (:wat::core::+ i 1)
        (:wat::hashmap::assoc acc b (:wat::core::+ (:aoc::deg-of acc b) 1))))))

(:wat::core::defn :aoc::all-names [es <- :aoc::Edges i <- :wat::core::i64
                                   acc <- (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool])]
  -> (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool])
  (:wat::core::if (:wat::core::>= i (:wat::core::length es)) acc
    (:wat::core::let [e (:wat::core::nth es i)]
      (:aoc::all-names es (:wat::core::+ i 1)
        (:wat::map::assoc (:wat::map::assoc acc (:aoc::Edge/a e) true) (:aoc::Edge/b e) true)))))

;; the alphabetically first job with nothing left before it and nothing done yet
(:wat::core::defn :aoc::next-ready [jobs <- :aoc::Names deg <- :aoc::Counts
                                    done <- (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool])
                                    i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length jobs)) "")
    ((:wat::core::and (:wat::core::= (:aoc::deg-of deg (:wat::core::nth jobs i)) 0)
                      (:wat::core::not (:wat::map::contains-key? done (:wat::core::nth jobs i))))
      (:wat::core::nth jobs i))
    (:else (:aoc::next-ready jobs deg done (:wat::core::+ i 1)))))

(:wat::core::defn :aoc::release [deg <- :aoc::Counts ns <- :aoc::Names i <- :wat::core::i64] -> :aoc::Counts
  (:wat::core::if (:wat::core::>= i (:wat::core::length ns)) deg
    (:aoc::release (:wat::hashmap::assoc deg (:wat::core::nth ns i)
                     (:wat::core::- (:aoc::deg-of deg (:wat::core::nth ns i)) 1))
      ns (:wat::core::+ i 1))))

(:wat::core::defn :aoc::topo [jobs <- :aoc::Names adj <- :aoc::Adj deg <- :aoc::Counts
                              done <- (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool])
                              acc <- :aoc::Names] -> :aoc::Names
  (:wat::core::let [n (:aoc::next-ready jobs deg done 0)]
    (:wat::core::if (:wat::core::= n "") acc
      (:aoc::topo jobs adj
        ;; -1 keeps a finished job from being picked again
        (:aoc::release (:wat::hashmap::assoc deg n -1) (:aoc::after-of adj n) 0)
        (:wat::map::assoc done n true)
        (:wat::core::conj acc n)))))

;; ---- longest chain, memoised on the job name
(:wat::core::defrecord :aoc::D [depths <- :aoc::Depths  v <- :wat::core::i64])

(:wat::core::defn :aoc::depth [adj <- :aoc::Adj d <- :aoc::Depths n <- :wat::core::String] -> :aoc::D
  (:wat::core::match (:wat::map::get d n)
    [:wat::core::Option.Some {:value v} (:aoc::D :depths d :v v)]
    [:wat::core::Option.None {}
      (:wat::core::let [r (:aoc::depth-each adj d (:aoc::after-of adj n) 0 0)
                        v (:wat::core::+ 1 (:aoc::D/v r))]
        (:aoc::D :depths (:wat::map::assoc (:aoc::D/depths r) n v) :v v))]))

(:wat::core::defn :aoc::depth-each [adj <- :aoc::Adj d <- :aoc::Depths ns <- :aoc::Names
                                    i <- :wat::core::i64 best <- :wat::core::i64] -> :aoc::D
  (:wat::core::if (:wat::core::>= i (:wat::core::length ns)) (:aoc::D :depths d :v best)
    (:wat::core::let [r (:aoc::depth adj d (:wat::core::nth ns i))]
      (:aoc::depth-each adj (:aoc::D/depths r) ns (:wat::core::+ i 1)
        (:wat::core::if (:wat::core::> (:aoc::D/v r) best) (:aoc::D/v r) best)))))

(:wat::core::defn :aoc::longest [adj <- :aoc::Adj jobs <- :aoc::Names i <- :wat::core::i64
                                 d <- :aoc::Depths best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length jobs)) best
    (:wat::core::let [r (:aoc::depth adj d (:wat::core::nth jobs i))]
      (:aoc::longest adj jobs (:wat::core::+ i 1) (:aoc::D/depths r)
        (:wat::core::if (:wat::core::> (:aoc::D/v r) best) (:aoc::D/v r) best)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [es (:aoc::parse (:aoc::lines "aoc/input/day24-order.txt") 0 (:wat::core::Vector :- [:aoc::Edge]))
     jobs (:wat::core::sort (:wat::map::keys (:aoc::all-names es 0
             (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool]))))
     adj (:aoc::build-adj es 0 (:wat::core::HashMap :- [:wat::core::String :aoc::Names]))
     deg (:aoc::build-deg es 0 (:wat::core::HashMap :- [:wat::core::String :wat::core::i64]))
     order (:aoc::topo jobs adj deg
             (:wat::core::PersistentMap :- [:wat::core::String :wat::core::bool])
             (:wat::core::Vector :- [:wat::core::String]))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day24-order.expected"
                         "aoc day24 order"
                         (:wat::core::Vector :- [:wat::core::String]
                           (:wat::string::join "," order)
                           (int (:aoc::longest adj jobs 0
                                  (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]) 0))))))
