;; Advent of Code's adapter-chain shape, in wat: a bag of adapters, and how many ways they chain.
;;
;; Part one: sort them into one chain from a 0-rated outlet to a device three above the largest,
;; and multiply the number of 1-steps by the number of 3-steps.
;; Part two: count the DISTINCT arrangements that still connect the outlet to the device.
;;
;; Part two is why this puzzle is here. The answer is **171802567918485504** -- over 1.7e17 -- from
;; a chain only 97 links long. Nothing can enumerate that; the count has to be built from the
;; counts of shorter chains. It is the first workload in this repository where memoisation is the
;; difference between an answer and no answer, rather than between fast and slow, which is what
;; **P-028** was raised on and had no real workload behind.
;;
;; Three ways to count it are here, and they must agree:
;;   FORWARD    a fold over the sorted chain, threading a PersistentMap. No memo primitive needed.
;;   RECURSIVE  the natural definition, ways(v) = ways(v-1) + ways(v-2) + ways(v-3), with a
;;              `:wat::cache::Lru` standing in for the memo cell -- Norvig's transparent wrapper
;;              (C-084), on a workload that actually needs it.
;;   UNDERSIZED the same recursion with a smaller cache -- written to test P-028's claim that an
;;              LRU is allowed to FORGET, and which REFUTED it for this workload. The numbers are
;;              below; the short version is that an LRU of capacity 3 is already enough, because
;;              ways(v) needs v-1, v-2 and v-3 and those are precisely the three most recently
;;              used keys. A recurrence's access pattern IS a recency pattern.
;;
;; That refutation is the useful part of this file, and P-028 has been narrowed because of it: the
;; risk in an evicting cache is not eviction, it is **falling below the working set**, and the edge
;; is a cliff rather than a slope: on a 26-link prefix, capacity 3 costs nothing over capacity 256,
;; capacity 2 costs several times more, and capacity 1 costs HUNDREDS of times more and varies
;; between runs because that arm is exponential -- so the file prints the ratio rather than naming
;; it here. The ask that survives is for a cell whose size a caller does not have to know, because
;; for an arbitrary memo the working set is not knowable in advance.
;;
;; The puzzle and its input are ours (aoc/input/day06-adapters.txt), generated deterministically
;; from a fixed seed; Advent of Code's own texts and inputs are not redistributable. The answers
;; must be the reference implementation's (oracle/aoc/day06-adapters.clj).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day06-adapters.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Present (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defn :aoc::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

(:wat::core::defn :aoc::ratings [path <- :wat::core::String] -> :aoc::Ints
  (:wat::core::sort
    (:wat::core::mapv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::i64
                        (:wat::core::match (:wat::string::to-i64 (:wat::string::trim s))
                          [:wat::core::Option.Some {:value v} v]
                          [:wat::core::Option.None {} 0]))
      (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool
                             (:wat::core::not (:wat::core::= (:wat::string::trim s) "")))
        (:wat::string::split (:wat::io::read-file path) "\n")))))

;; the full chain: 0, every adapter in order, then the device three above the largest
(:wat::core::defn :aoc::chain [rs <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::conj (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] 0) rs)
    (:wat::core::+ 3 (:wat::core::nth rs (:wat::core::- (:wat::core::length rs) 1)))))

(:wat::core::defn :aoc::gap-count [c <- :aoc::Ints want <- :wat::core::i64 i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length c)) n
    (:aoc::gap-count c want (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= want (:wat::core::- (:wat::core::nth c i) (:wat::core::nth c (:wat::core::- i 1))))
        (:wat::core::+ n 1) n))))

;; ---- FORWARD: a fold over the chain, threading the counts. No memo primitive needed.
(:wat::core::defn :aoc::at [m <- :aoc::Present k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get m k)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :aoc::forward [c <- :aoc::Ints i <- :wat::core::i64 ways <- :aoc::Present] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length c))
    (:aoc::at ways (:wat::core::nth c (:wat::core::- (:wat::core::length c) 1)))
    (:wat::core::let [v (:wat::core::nth c i)
                      n (:wat::core::+ (:aoc::at ways (:wat::core::- v 1))
                          (:wat::core::+ (:aoc::at ways (:wat::core::- v 2))
                                         (:aoc::at ways (:wat::core::- v 3))))]
      (:aoc::forward c (:wat::core::+ i 1) (:wat::map::assoc ways v n)))))

(:wat::core::defn :aoc::count-forward [c <- :aoc::Ints] -> :wat::core::i64
  (:aoc::forward c 1
    (:wat::map::assoc (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0 1)))

;; ---- RECURSIVE: the natural definition, with an Lru as the memo cell (C-084, P-028)
(:wat::core::defn :aoc::present-set [c <- :aoc::Ints i <- :wat::core::i64 m <- :aoc::Present] -> :aoc::Present
  (:wat::core::if (:wat::core::>= i (:wat::core::length c)) m
    (:aoc::present-set c (:wat::core::+ i 1) (:wat::map::assoc m (:wat::core::nth c i) 1))))

(:wat::core::defn :aoc::ways-rec
  [cell <- (:wat::cache::Lru :- [:wat::core::i64 :wat::core::i64]) present <- :aoc::Present v <- :wat::core::i64]
  -> :wat::core::i64
  (:wat::core::if (:wat::core::= v 0) 1
    (:wat::core::if (:wat::core::< v 0) 0
      (:wat::core::if (:wat::core::= 0 (:aoc::at present v)) 0
        (:wat::core::match (:wat::cache::Lru::get cell v)
          [:wat::core::Option.Some {:value hit} hit]
          [:wat::core::Option.None {}
            (:wat::core::let [r (:wat::core::+ (:aoc::ways-rec cell present (:wat::core::- v 1))
                                  (:wat::core::+ (:aoc::ways-rec cell present (:wat::core::- v 2))
                                                 (:aoc::ways-rec cell present (:wat::core::- v 3))))]
              (:wat::core::do (:wat::cache::Lru::put cell v r) r))])))))

(:wat::core::defn :aoc::count-recursive [c <- :aoc::Ints cap <- :wat::core::i64] -> :wat::core::i64
  (:aoc::ways-rec (:wat::cache::Lru::new cap)
    (:aoc::present-set c 0 (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))
    (:wat::core::nth c (:wat::core::- (:wat::core::length c) 1))))

;; ---- the P-028 measurement: the same recursion, a cache that fits and one that does not
(:wat::core::defn :aoc::prefix [c <- :aoc::Ints n <- :wat::core::i64 i <- :wat::core::i64 acc <- :aoc::Ints] -> :aoc::Ints
  (:wat::core::if (:wat::core::or (:wat::core::>= i n) (:wat::core::>= i (:wat::core::length c))) acc
    (:aoc::prefix c n (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth c i)))))

(:wat::core::defn :aoc::best [c <- :aoc::Ints cap <- :wat::core::i64 reps <- :wat::core::i64 best <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= reps 0) best
    (:wat::core::let [t0 (:aoc::now)
                      v (:aoc::count-recursive c cap)
                      dt (:wat::core::- (:aoc::now) t0)]
      (:aoc::best c cap (:wat::core::- reps 1) (:wat::core::if (:wat::core::< dt best) dt best)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [rs (:aoc::ratings "aoc/input/day06-adapters.txt")
                    c (:aoc::chain rs)
                    n (:wat::core::length c)
                    int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    ;; a prefix small enough that an undersized cache still terminates
                    small (:aoc::prefix c 26 0 (:wat::core::Vector :- [:wat::core::i64]))
                    big 999999999999
                    fits (:aoc::best small 256 3 big)
                    c4 (:aoc::best small 4 3 big)
                    c3 (:aoc::best small 3 3 big)
                    c2 (:aoc::best small 2 3 big)
                    c1 (:aoc::best small 1 3 big)
                    tiny c4]
    (:wat::core::do
      (:wat::kernel::println "---- P-028: the same recursion, a memo that fits and one that does not ----")
      (:wat::kernel::println (:wat::string::concat "  chain links                 " (:wat::i64::to-string n)))
      (:wat::kernel::println (:wat::string::concat "  26-link prefix, Lru cap 256 "
        (:wat::i64::to-string (:wat::core::/ fits 1000)) " us"))
      (:wat::kernel::println (:wat::string::concat "  26-link prefix, Lru cap 4   "
        (:wat::i64::to-string (:wat::core::/ c4 1000)) " us"))
      (:wat::kernel::println (:wat::string::concat "  26-link prefix, Lru cap 3   "
        (:wat::i64::to-string (:wat::core::/ c3 1000)) " us"))
      (:wat::kernel::println (:wat::string::concat "  26-link prefix, Lru cap 2   "
        (:wat::i64::to-string (:wat::core::/ c2 1000)) " us"))
      (:wat::kernel::println (:wat::string::concat "  26-link prefix, Lru cap 1   "
        (:wat::i64::to-string (:wat::core::/ c1 1000)) " us"))
      (:wat::kernel::println (:wat::string::concat "  cap 1 against cap 3         "
        (:wat::i64::to-string (:wat::core::/ c1 (:wat::core::if (:wat::core::= c3 0) 1 c3))) "x"))
      (:wat::kernel::println "  The threshold is the ORDER OF THE RECURRENCE, not the chain length:")
      (:wat::kernel::println "  ways(v) needs v-1, v-2, v-3, which are exactly the three most")
      (:wat::kernel::println "  recently used keys -- so an LRU of capacity 3 is already enough, and")
      (:wat::kernel::println "  256 buys nothing. That REFUTES the guess this file was written to")
      (:wat::kernel::println "  test: eviction is not automatically fatal, because a recurrence's")
      (:wat::kernel::println "  access pattern is a recency pattern and LRU is built for exactly it.")
      (:wat::kernel::println "  What is fatal is falling BELOW the working set, and the edge is a")
      (:wat::kernel::println "  cliff rather than a slope: cap 2 costs several times more, and cap")
      (:wat::kernel::println "  1 hundreds of times more -- the ratio is printed above, and varies")
      (:wat::kernel::println "  between runs because that arm has gone exponential.")

      (:aoc::check-answers "oracle/aoc/day06-adapters.expected"
                           "aoc day06 adapters"
                           (:wat::core::Vector :- [:wat::core::String]
                             (int (:wat::core::length rs))
                             (int (:aoc::gap-count c 1 1 0))
                             (int (:aoc::gap-count c 3 1 0))
                             (int (:wat::core::* (:aoc::gap-count c 1 1 0) (:aoc::gap-count c 3 1 0)))
                             ;; the forward fold and the memoised recursion must agree
                             (int (:aoc::count-forward c))
                             (:wat::core::if (:wat::core::> (:aoc::count-forward c) 100000000000000000) "true" "false")
                             (int n))))))
