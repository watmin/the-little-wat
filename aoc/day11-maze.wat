;; Advent of Code's maze shape, in wat: a grid of walls, walked breadth-first.
;;
;; Part one: the fewest steps from the top-left corner to the bottom-right one.
;; Part two: how many squares are reachable from the corner at all.
;;
;; **This is the puzzle where F-116's missing `pop` would hurt, and does not.** A textbook BFS
;; takes one cell off the FRONT of a queue at a time, and wat has no way to do that in constant
;; time: there is no `pop`, no `subvec`, `take`/`drop` answer a Stream (F-088), and neither vector
;; type has a positional update (F-104). A queue of a few hundred cells popped one at a time
;; rebuilds the queue a few hundred times per level.
;;
;; The way out is not a workaround so much as a better shape: step the WHOLE FRONTIER at once.
;; A level-synchronous BFS never pops anything -- it builds the next frontier from the current
;; one and drops it whole -- and it is the same algorithm with the same answers. `day08`'s stack
;; is the other half of this pair: there the pop was unavoidable and the depth was nine, so it
;; cost nothing; here the width reaches 129 and the pop is avoidable entirely.
;;
;; F-057 again for the seen set: no set shares structure, so it is a `PersistentMap` to `true`.
;;
;; The puzzle and its input are ours (aoc/input/day11-maze.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day11-maze.clj, run by tools/aoc-oracle.sh).
;;
;; Run from the repository root:
;;   wat aoc/day11-maze.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Cells (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :aoc::Seen (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]))

;; a level of the search: who is on the frontier, what has been seen, and how far we are
(:wat::core::defrecord :aoc::Bfs
  [frontier <- :aoc::Cells  seen <- :aoc::Seen  dist <- :wat::core::i64
   goal-dist <- :wat::core::i64  reached <- :wat::core::i64])

(:wat::core::defn :aoc::open? [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                               r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::>= r 0)
    (:wat::core::and (:wat::core::>= c 0)
      (:wat::core::and (:wat::core::< r h)
        (:wat::core::and (:wat::core::< c w)
          (:wat::core::= (:wat::string::subs (:wat::core::nth g r) c (:wat::core::+ c 1)) "."))))))

;; one neighbour, added to the next frontier if it is open and new
(:wat::core::defn :aoc::visit [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                               st <- :aoc::Bfs nxt <- :aoc::Cells
                               r <- :wat::core::i64 c <- :wat::core::i64] -> :aoc::Bfs
  (:wat::core::let [k (:wat::core::+ (:wat::core::* r w) c)]
    (:wat::core::if (:wat::core::not (:aoc::open? g h w r c)) st
      (:wat::core::if (:wat::map::contains-key? (:aoc::Bfs/seen st) k) st
        (:wat::core::assoc (:wat::core::assoc st :seen (:wat::map::assoc (:aoc::Bfs/seen st) k true))
          :frontier (:wat::core::conj nxt k))))))

;; `visit` answers the state with the cell already in its `frontier` field, so the four
;; neighbours chain through it and the field IS the next frontier being built
(:wat::core::defn :aoc::expand [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                cur <- :aoc::Cells i <- :wat::core::i64 st <- :aoc::Bfs] -> :aoc::Bfs
  (:wat::core::if (:wat::core::>= i (:wat::core::length cur)) st
    (:wat::core::let [k (:wat::core::nth cur i)
                      r (:wat::core::/ k w)
                      c (:wat::core::rem k w)
                      a (:aoc::visit g h w st (:aoc::Bfs/frontier st) (:wat::core::+ r 1) c)
                      b (:aoc::visit g h w a (:aoc::Bfs/frontier a) (:wat::core::- r 1) c)
                      d (:aoc::visit g h w b (:aoc::Bfs/frontier b) r (:wat::core::+ c 1))
                      e (:aoc::visit g h w d (:aoc::Bfs/frontier d) r (:wat::core::- c 1))]
      (:aoc::expand g h w cur (:wat::core::+ i 1) e))))

(:wat::core::defn :aoc::in? [xs <- :aoc::Cells k <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length xs)) false)
    ((:wat::core::= (:wat::core::nth xs i) k) true)
    (:else (:aoc::in? xs k (:wat::core::+ i 1)))))

;; one whole level, and nothing is ever taken off the front of anything
(:wat::core::defn :aoc::levels [g <- :aoc::Lines h <- :wat::core::i64 w <- :wat::core::i64
                                goal <- :wat::core::i64 st <- :aoc::Bfs] -> :aoc::Bfs
  (:wat::core::if (:wat::core::= (:wat::core::length (:aoc::Bfs/frontier st)) 0) st
    (:wat::core::let
      [cur (:aoc::Bfs/frontier st)
       cleared (:wat::core::assoc st :frontier (:wat::core::Vector :- [:wat::core::i64]))
       grown (:aoc::expand g h w cur 0 cleared)
       d (:wat::core::+ (:aoc::Bfs/dist st) 1)
       nxt (:aoc::Bfs/frontier grown)
       found (:wat::core::if (:wat::core::and (:wat::core::= (:aoc::Bfs/goal-dist grown) -1)
                                              (:aoc::in? nxt goal 0))
               d (:aoc::Bfs/goal-dist grown))]
      (:aoc::levels g h w goal
        (:wat::core::assoc (:wat::core::assoc (:wat::core::assoc grown :dist d) :goal-dist found)
          :reached (:wat::core::+ (:aoc::Bfs/reached grown) (:wat::core::length nxt)))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [g (:aoc::lines "aoc/input/day11-maze.txt")
     h (:wat::core::length g)
     w (:wat::string::length (:wat::core::nth g 0))
     goal (:wat::core::- (:wat::core::* h w) 1)
     start (:aoc::Bfs :frontier (:wat::core::Vector :- [:wat::core::i64] 0)
                      :seen (:wat::map::assoc (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::bool]) 0 true)
                      :dist 0 :goal-dist -1 :reached 1)
     done (:aoc::levels g h w goal start)
     int (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x))]
    (:aoc::check-answers "oracle/aoc/day11-maze.expected"
                         "aoc day11 maze"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:aoc::Bfs/goal-dist done))
                           (int (:aoc::Bfs/reached done))))))
