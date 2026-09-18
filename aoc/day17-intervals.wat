;; Advent of Code's interval shape, in wat: blocked ranges over a large space.
;;
;; Each line is an inclusive range `lo-hi` of blocked values, over 0 to 999999999. The ranges
;; overlap and arrive in no order.
;;
;; Part one: the lowest value that is not blocked.
;; Part two: how many values are not blocked.
;;
;; **The puzzle is about sorting, and wat's `sort` takes no key.** There is `:wat::core::sort`
;; over a whole collection and nothing that sorts BY something -- no `sort-by`, no comparator
;; argument -- so a pair cannot be sorted on its first element. The route is to pack the pair
;; into one integer: `lo * 1000000000 + hi`, which orders by `lo` and then by `hi` because both
;; halves are below the multiplier. That is why the space stops at 999999999 rather than at
;; 2^32: `lo * 2^32 + hi` would be 1.8 x 10^19 and i64 tops out at 9.2 x 10^18 -- and day10
;; showed that wat TRAPS on that rather than wrapping, so the packing would have died loudly
;; rather than silently. Choosing the universe to fit the packing is the kind of decision a
;; comparator would have made unnecessary.
;;
;; The puzzle and its input are ours (aoc/input/day17-intervals.txt); Advent of Code's own texts
;; and inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day17-intervals.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day17-intervals.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))

;; the multiplier is the size of the space, so lo and hi both fit below it
(:wat::core::defn :aoc::limit [] -> :wat::core::i64 999999999)
(:wat::core::defn :aoc::mul [] -> :wat::core::i64 1000000000)

(:wat::core::defn :aoc::pack [lo <- :wat::core::i64 hi <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::* lo (:aoc::mul)) hi))

(:wat::core::defn :aoc::lo-of [k <- :wat::core::i64] -> :wat::core::i64 (:wat::core::/ k (:aoc::mul)))
(:wat::core::defn :aoc::hi-of [k <- :wat::core::i64] -> :wat::core::i64 (:wat::core::rem k (:aoc::mul)))

(:wat::core::defn :aoc::parse [ls <- :aoc::Lines i <- :wat::core::i64 acc <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) acc
    (:wat::core::let [parts (:wat::string::split (:wat::core::nth ls i) "-")]
      (:aoc::parse ls (:wat::core::+ i 1)
        (:wat::core::conj acc (:aoc::pack (:aoc::to-int (:wat::core::nth parts 0))
                                          (:aoc::to-int (:wat::core::nth parts 1))))))))

;; one sweep over the sorted ranges: the first gap is the answer to part one, and every gap adds
;; to part two
(:wat::core::defrecord :aoc::Sweep
  [cur <- :wat::core::i64  lowest <- :wat::core::i64  allowed <- :wat::core::i64])

(:wat::core::defn :aoc::sweep [ks <- :aoc::Ints i <- :wat::core::i64 s <- :aoc::Sweep] -> :aoc::Sweep
  (:wat::core::if (:wat::core::>= i (:wat::core::length ks)) s
    (:wat::core::let
      [k (:wat::core::nth ks i)
       lo (:aoc::lo-of k)
       hi (:aoc::hi-of k)
       gap (:wat::core::if (:wat::core::> lo (:aoc::Sweep/cur s))
             (:wat::core::- lo (:aoc::Sweep/cur s)) 0)
       nxt (:wat::core::+ hi 1)]
      (:aoc::sweep ks (:wat::core::+ i 1)
        (:aoc::Sweep
          :cur (:wat::core::if (:wat::core::> nxt (:aoc::Sweep/cur s)) nxt (:aoc::Sweep/cur s))
          :lowest (:wat::core::if (:wat::core::and (:wat::core::= (:aoc::Sweep/lowest s) -1)
                                                   (:wat::core::> gap 0))
                    (:aoc::Sweep/cur s) (:aoc::Sweep/lowest s))
          :allowed (:wat::core::+ (:aoc::Sweep/allowed s) gap))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [packed (:wat::core::sort
              (:aoc::parse (:aoc::lines "aoc/input/day17-intervals.txt") 0
                (:wat::core::Vector :- [:wat::core::i64])))
     done (:aoc::sweep packed 0 (:aoc::Sweep :cur 0 :lowest -1 :allowed 0))
     tail (:wat::core::if (:wat::core::> (:wat::core::+ (:aoc::limit) 1) (:aoc::Sweep/cur done))
            (:wat::core::- (:wat::core::+ (:aoc::limit) 1) (:aoc::Sweep/cur done)) 0)
     lowest (:wat::core::if (:wat::core::= (:aoc::Sweep/lowest done) -1)
              (:aoc::Sweep/cur done) (:aoc::Sweep/lowest done))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day17-intervals.expected"
                         "aoc day17 intervals"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int lowest)
                           (int (:wat::core::+ (:aoc::Sweep/allowed done) tail))))))
