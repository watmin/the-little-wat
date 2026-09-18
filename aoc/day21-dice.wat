;; Advent of Code's memoisation shape, in wat: a board game played two ways.
;;
;; Two players move around a ten-square track; landing on a square adds its number to the score.
;;
;; Part one: a deterministic die, rolled three times a turn, cycling 1 to 100. Play to 1000 and
;; answer the loser's score times the number of rolls.
;; Part two: a three-sided die that splits the universe on every roll -- 27 futures a turn, 7
;; distinct sums. Play to 21, and answer how many universes the more successful player wins in.
;; Without memoisation the search is astronomically wide; with it there are 16172 states.
;;
;; **This is the second workload for P-028, and it asks the question day06 could not.** day06's
;; recurrence needed a memo of capacity 3 -- its own order -- so the Lru's fixed size was never
;; a problem, and P-028's ask was narrowed to "a cell whose size the caller does not have to
;; know". Here the caller CANNOT know it: 16172 is a property of the search, not of the input,
;; and the only way to find it is to run the search. So the capacity is chosen by bounding the
;; state space instead -- 10 positions x 21 scores x 10 x 21 = 44100 -- which is the arithmetic
;; a growable memo would have made unnecessary. Get it wrong and nothing fails; the program
;; silently recomputes.
;;
;; The key is packed into one i64 because an Lru takes one key, and the four fields are small.
;; The value is a `defrecord` of two counts, which the Lru carries without complaint.
;;
;; The puzzle and its input are ours (aoc/input/day21-dice.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day21-dice.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day21-dice.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defrecord :aoc::Wins [a <- :wat::core::i64  b <- :wat::core::i64])
(:wat::core::typealias :aoc::Memo (:wat::cache::Lru :- [:wat::core::i64 :aoc::Wins]))

;; ---- part one: the deterministic die
(:wat::core::defrecord :aoc::Game
  [pa <- :wat::core::i64  sa <- :wat::core::i64  pb <- :wat::core::i64  sb <- :wat::core::i64
   die <- :wat::core::i64  rolls <- :wat::core::i64])

(:wat::core::defn :aoc::roll3 [die <- :wat::core::i64] -> :wat::core::i64
  ;; three consecutive faces of a 100-sided die, starting after `die`
  (:wat::core::+ (:wat::core::+ (:wat::core::+ (:wat::core::rem die 100) 1)
                                (:wat::core::+ (:wat::core::rem (:wat::core::+ die 1) 100) 1))
                 (:wat::core::+ (:wat::core::rem (:wat::core::+ die 2) 100) 1)))

(:wat::core::defn :aoc::advance [p <- :wat::core::i64 s <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::rem (:wat::core::+ (:wat::core::- p 1) s) 10) 1))

;; the players swap every turn, so only one branch is written
(:wat::core::defn :aoc::deterministic [g <- :aoc::Game] -> :wat::core::i64
  (:wat::core::let
    [s (:aoc::roll3 (:aoc::Game/die g))
     p (:aoc::advance (:aoc::Game/pa g) s)
     sc (:wat::core::+ (:aoc::Game/sa g) p)
     rolls (:wat::core::+ (:aoc::Game/rolls g) 3)]
    (:wat::core::if (:wat::core::>= sc 1000) (:wat::core::* (:aoc::Game/sb g) rolls)
      (:aoc::deterministic
        (:aoc::Game :pa (:aoc::Game/pb g) :sa (:aoc::Game/sb g)
                    :pb p :sb sc
                    :die (:wat::core::+ (:aoc::Game/die g) 3) :rolls rolls)))))

;; ---- part two: 7 distinct sums, with how many of the 27 futures give each
(:wat::core::defn :aoc::sum-of [i <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ i 3))
(:wat::core::defn :aoc::ways-of [i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::nth (:wat::core::Vector :- [:wat::core::i64] 1 3 6 7 6 3 1) i))

(:wat::core::defn :aoc::key-of [pa <- :wat::core::i64 sa <- :wat::core::i64
                                pb <- :wat::core::i64 sb <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::* (:wat::core::+ (:wat::core::* (:wat::core::+ (:wat::core::* pa 21) sa) 11) pb) 21) sb))

(:wat::core::defn :aoc::quantum [m <- :aoc::Memo pa <- :wat::core::i64 sa <- :wat::core::i64
                                 pb <- :wat::core::i64 sb <- :wat::core::i64] -> :aoc::Wins
  (:wat::core::let [k (:aoc::key-of pa sa pb sb)]
    (:wat::core::match (:wat::cache::Lru::get m k)
      [:wat::core::Option.Some {:value w} w]
      [:wat::core::Option.None {}
        (:wat::core::let [w (:aoc::roll-each m pa sa pb sb 0 (:aoc::Wins :a 0 :b 0))]
          (:wat::core::do (:wat::cache::Lru::put m k w) w))])))

(:wat::core::defn :aoc::roll-each [m <- :aoc::Memo pa <- :wat::core::i64 sa <- :wat::core::i64
                                   pb <- :wat::core::i64 sb <- :wat::core::i64
                                   i <- :wat::core::i64 acc <- :aoc::Wins] -> :aoc::Wins
  (:wat::core::if (:wat::core::>= i 7) acc
    (:wat::core::let
      [n (:aoc::ways-of i)
       p (:aoc::advance pa (:aoc::sum-of i))
       s (:wat::core::+ sa p)]
      (:wat::core::if (:wat::core::>= s 21)
        (:aoc::roll-each m pa sa pb sb (:wat::core::+ i 1)
          (:wat::core::assoc acc :a (:wat::core::+ (:aoc::Wins/a acc) n)))
        ;; the players swap, so the opponent's wins come back first
        (:wat::core::let [w (:aoc::quantum m pb sb p s)]
          (:aoc::roll-each m pa sa pb sb (:wat::core::+ i 1)
            (:aoc::Wins :a (:wat::core::+ (:aoc::Wins/a acc) (:wat::core::* n (:aoc::Wins/b w)))
                        :b (:wat::core::+ (:aoc::Wins/b acc) (:wat::core::* n (:aoc::Wins/a w))))))))))

(:wat::core::defn :aoc::start-of [l <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [ws (:aoc::non-empty (:wat::string::split l " "))]
    (:aoc::to-int (:wat::core::nth ws (:wat::core::- (:wat::core::length ws) 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [ls (:aoc::lines "aoc/input/day21-dice.txt")
     p1 (:aoc::start-of (:wat::core::nth ls 0))
     p2 (:aoc::start-of (:wat::core::nth ls 1))
     ;; 10 positions x 21 scores, twice -- the bound a growable memo would not have needed
     m (:wat::cache::Lru::new 44100)
     w (:aoc::quantum m p1 0 p2 0)
     best (:wat::core::if (:wat::core::> (:aoc::Wins/a w) (:aoc::Wins/b w)) (:aoc::Wins/a w) (:aoc::Wins/b w))
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day21-dice.expected"
                         "aoc day21 dice"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::deterministic (:aoc::Game :pa p1 :sa 0 :pb p2 :sb 0 :die 0 :rolls 0)))
                           (int best)))))
