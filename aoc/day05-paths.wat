;; Advent of Code's shortest-path shape, in wat: a grid of risk levels, and the cheapest way
;; across it.
;;
;; Part one: the lowest total risk of any path from the top-left corner to the bottom-right,
;; moving up, down, left or right, counting every square entered.
;; Part two: the same on the grid five times as wide and five times as tall, where each copy's
;; risks are one higher than the copy above and to the left, wrapping from 9 back to 1 — 90000
;; squares.
;;
;; Dijkstra's algorithm wants a priority queue, and the Clojure reference uses a sorted set.
;; wat has no ordered collection at all: no sorted set, no sorted map, no priority queue, no
;; heap, only :wat::core::sort over a whole collection (F-056,
;; probes/aoc/sorted-structures.wat). So the frontier here is a bucket per cost — Dial's
;; algorithm — which works because every step costs between 1 and 9: a hash map from cost to
;; the squares waiting at that cost, walked in increasing order.
;;
;; The puzzle and its input are ours (aoc/input/day05-paths.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day05-paths.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day05-paths.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Grid (:wat::core::Vector :- [(:wat::core::Vector :- [:wat::core::i64])]))
(:wat::core::typealias :aoc::Buckets (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::i64])]))
(:wat::core::typealias :aoc::Settled (:wat::core::HashSet :- [:wat::core::i64]))

;; the frontier: the squares waiting at each cost, and the squares already settled
(:wat::core::defstruct :aoc::Frontier
  [buckets <- :aoc::Buckets
   settled <- :aoc::Settled])

;; one pass over a bucket answers the frontier that is left, and the cost the goal was reached
;; at, or -1
(:wat::core::defstruct :aoc::Step
  [f     <- :aoc::Frontier
   found <- :wat::core::i64])

;; ---- the grid

(:wat::core::defn :aoc::digits-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:aoc::digits-from s (:wat::core::+ i 1) n
      (:wat::core::conj acc (:aoc::to-int (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :aoc::grid [path <- :wat::core::String] -> :aoc::Grid
  (:wat::core::mapv (:wat::core::fn [line <- :wat::core::String] -> :aoc::Ints
                      (:aoc::digits-from line 0 (:wat::string::length line) (:wat::core::Vector :- [:wat::core::i64])))
                    (:aoc::lines path)))

;; the risk of a square, on the grid grown by whatever scale the caller walks
(:wat::core::defn :aoc::risk [g <- :aoc::Grid h <- :wat::core::i64 w <- :wat::core::i64 y <- :wat::core::i64 x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [bump (:wat::core::+ (:wat::core::/ y h) (:wat::core::/ x w))
                    v (:wat::core::+ (:wat::core::nth (:wat::core::nth g (:wat::i64::rem y h)) (:wat::i64::rem x w)) bump)]
    (:wat::core::+ 1 (:wat::i64::rem (:wat::core::- v 1) 9))))

;; ---- the frontier

(:wat::core::defn :aoc::bucket-at [f <- :aoc::Frontier cost <- :wat::core::i64] -> :aoc::Ints
  (:wat::core::match (:wat::hashmap::get (:aoc::Frontier/buckets f) cost)
    [:wat::core::Option.Some {:value cells} cells]
    [:wat::core::Option.None {} (:wat::core::Vector :- [:wat::core::i64])]))

(:wat::core::defn :aoc::push [f <- :aoc::Frontier cost <- :wat::core::i64 cell <- :wat::core::i64] -> :aoc::Frontier
  (:aoc::Frontier :buckets (:wat::hashmap::assoc (:aoc::Frontier/buckets f) cost (:wat::core::conj (:aoc::bucket-at f cost) cell))
                  :settled (:aoc::Frontier/settled f)))

(:wat::core::defn :aoc::drop-bucket [f <- :aoc::Frontier cost <- :wat::core::i64] -> :aoc::Frontier
  (:aoc::Frontier :buckets (:wat::hashmap::dissoc (:aoc::Frontier/buckets f) cost)
                  :settled (:aoc::Frontier/settled f)))

(:wat::core::defn :aoc::settle [f <- :aoc::Frontier cell <- :wat::core::i64] -> :aoc::Frontier
  (:aoc::Frontier :buckets (:aoc::Frontier/buckets f)
                  :settled (:wat::hashset::conj (:aoc::Frontier/settled f) cell)))

(:wat::core::defn :aoc::settled? [f <- :aoc::Frontier cell <- :wat::core::i64] -> :wat::core::bool
  (:wat::hashset::contains? (:aoc::Frontier/settled f) cell))

;; ---- the search

(:wat::core::defn :aoc::push-neighbour [g <- :aoc::Grid h <- :wat::core::i64 w <- :wat::core::i64 side <- :wat::core::i64
                                        f <- :aoc::Frontier y <- :wat::core::i64 x <- :wat::core::i64 cost <- :wat::core::i64] -> :aoc::Frontier
  (:wat::core::if (:wat::core::or (:wat::core::< y 0)
                    (:wat::core::or (:wat::core::< x 0)
                      (:wat::core::or (:wat::core::>= y side) (:wat::core::>= x side))))
    f
    (:wat::core::let [cell (:wat::core::+ (:wat::core::* y side) x)]
      (:wat::core::if (:aoc::settled? f cell)
        f
        (:aoc::push f (:wat::core::+ cost (:aoc::risk g h w y x)) cell)))))

(:wat::core::defn :aoc::relax [g <- :aoc::Grid h <- :wat::core::i64 w <- :wat::core::i64 side <- :wat::core::i64
                               f <- :aoc::Frontier cell <- :wat::core::i64 cost <- :wat::core::i64] -> :aoc::Frontier
  (:wat::core::let [y (:wat::core::/ cell side)
                    x (:wat::i64::rem cell side)
                    f1 (:aoc::push-neighbour g h w side f (:wat::core::- y 1) x cost)
                    f2 (:aoc::push-neighbour g h w side f1 (:wat::core::+ y 1) x cost)
                    f3 (:aoc::push-neighbour g h w side f2 y (:wat::core::- x 1) cost)]
    (:aoc::push-neighbour g h w side f3 y (:wat::core::+ x 1) cost)))

(:wat::core::defn :aoc::walk-bucket [g <- :aoc::Grid h <- :wat::core::i64 w <- :wat::core::i64 side <- :wat::core::i64
                                     f <- :aoc::Frontier cells <- :aoc::Ints i <- :wat::core::i64
                                     cost <- :wat::core::i64 goal <- :wat::core::i64] -> :aoc::Step
  (:wat::core::if (:wat::core::>= i (:wat::core::length cells))
    (:aoc::Step :f f :found -1)
    (:wat::core::let [cell (:wat::core::nth cells i)]
      (:wat::core::if (:aoc::settled? f cell)
        (:aoc::walk-bucket g h w side f cells (:wat::core::+ i 1) cost goal)
        (:wat::core::let [f1 (:aoc::settle f cell)]
          (:wat::core::if (:wat::core::= cell goal)
            (:aoc::Step :f f1 :found cost)
            (:aoc::walk-bucket g h w side (:aoc::relax g h w side f1 cell cost) cells (:wat::core::+ i 1) cost goal)))))))

(:wat::core::defn :aoc::run [g <- :aoc::Grid h <- :wat::core::i64 w <- :wat::core::i64 side <- :wat::core::i64
                             f <- :aoc::Frontier cost <- :wat::core::i64 goal <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [cells (:aoc::bucket-at f cost)
                    s (:aoc::walk-bucket g h w side (:aoc::drop-bucket f cost) cells 0 cost goal)]
    (:wat::core::if (:wat::core::>= (:aoc::Step/found s) 0)
      (:aoc::Step/found s)
      (:aoc::run g h w side (:aoc::Step/f s) (:wat::core::+ cost 1) goal))))

(:wat::core::defn :aoc::cheapest [g <- :aoc::Grid scale <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [h (:wat::core::length g)
                    w (:wat::core::length (:wat::core::first g))
                    side (:wat::core::* scale w)
                    goal (:wat::core::- (:wat::core::* side side) 1)
                    start (:aoc::Frontier :buckets (:wat::core::HashMap :- [:wat::core::i64 (:wat::core::Vector :- [:wat::core::i64])])
                                          :settled (:wat::core::HashSet :- [:wat::core::i64]))]
    (:aoc::run g h w side (:aoc::push start 0 0) 0 goal)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [g (:aoc::grid "aoc/input/day05-paths.txt")
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day05-paths.expected"
                         "aoc day05 paths"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::cheapest g 1))
                           (int (:aoc::cheapest g 5))))))
