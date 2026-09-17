;; PAIP chapter 18 (search and the game of Othello), in wat.
;;
;; A real 8x8 board, real move generation with flipping in eight directions, and MINIMAX with
;; ALPHA-BETA pruning. The chapter's measurable claim is that alpha-beta returns the SAME move as
;; minimax while visiting far fewer nodes, so both searches count their nodes:
;;
;;     depth 3, minimax     73 nodes
;;     depth 3, alpha-beta  37 nodes      same answer
;;
;; **F-104 lands here on the most natural case there is: a game board.** Placing a piece means
;; changing one square of a 64-square vector, and neither wat vector type has a positional update
;; (`core::assoc` takes a HashMap or a Record, `map::assoc` a PersistentMap, and `:wat::vector::`
;; is six verbs on PersistentVector, none of them an update -- F-108). So `set-at` below rebuilds
;; the whole board, and a move that flips k pieces rebuilds it k+1 times.
;;
;; That is the sixth workload in this repository to route around F-104, and the most ordinary:
;; a board, a store (C-066), a garbage collector's memory (C-081), a register machine's stack.
;; The pattern across all six is the same -- *dense integer indices, one cell changing* -- which is
;; exactly the shape a vector exists for. Every one of them ends up either rebuilding or reaching
;; for a `PersistentMap` keyed by an integer, which is a tree standing in for an array.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch18-othello.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch18-othello.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Board (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :paip::opponent [p <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= p 1) 2 1))

(:wat::core::defn :paip::idx [r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:wat::core::* r 8) c))

(:wat::core::defn :paip::on-board? [r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::and (:wat::core::>= r 0) (:wat::core::< r 8))
                   (:wat::core::and (:wat::core::>= c 0) (:wat::core::< c 8))))

(:wat::core::defn :paip::bref [b <- :paip::Board r <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::nth b (:paip::idx r c)))

;; F-104: no positional update, so changing one square rebuilds the board
(:wat::core::defn :paip::set-at [b <- :paip::Board i <- :wat::core::i64 v <- :wat::core::i64] -> :paip::Board
  (:paip::set-loop b i v 0 (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::set-loop [b <- :paip::Board i <- :wat::core::i64 v <- :wat::core::i64
                                   k <- :wat::core::i64 acc <- :paip::Board] -> :paip::Board
  (:wat::core::if (:wat::core::>= k (:wat::core::length b)) acc
    (:paip::set-loop b i v (:wat::core::+ k 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= k i) v (:wat::core::nth b k))))))

(:wat::core::defn :paip::empty-board [k <- :wat::core::i64 acc <- :paip::Board] -> :paip::Board
  (:wat::core::if (:wat::core::>= k 64) acc (:paip::empty-board (:wat::core::+ k 1) (:wat::core::conj acc 0))))

(:wat::core::defn :paip::initial-board [] -> :paip::Board
  (:paip::set-at (:paip::set-at (:paip::set-at (:paip::set-at
    (:paip::empty-board 0 (:wat::core::Vector :- [:wat::core::i64]))
    (:paip::idx 3 3) 2) (:paip::idx 4 4) 2) (:paip::idx 3 4) 1) (:paip::idx 4 3) 1))

;; the eight directions, as parallel dr/dc vectors
(:wat::core::defn :paip::drs [] -> :paip::Board
  (:wat::core::Vector :- [:wat::core::i64] -1 -1 -1 0 0 1 1 1))
(:wat::core::defn :paip::dcs [] -> :paip::Board
  (:wat::core::Vector :- [:wat::core::i64] -1 0 1 -1 1 -1 0 1))

;; the pieces flipped in ONE direction, or nothing if that direction does not capture
(:wat::core::defn :paip::flips-in
  [b <- :paip::Board r <- :wat::core::i64 c <- :wat::core::i64 dr <- :wat::core::i64 dc <- :wat::core::i64
   player <- :wat::core::i64 acc <- :paip::Board] -> :paip::Board
  (:wat::core::let [rr (:wat::core::+ r dr) cc (:wat::core::+ c dc)]
    (:wat::core::if (:wat::core::not (:paip::on-board? rr cc)) (:wat::core::Vector :- [:wat::core::i64])
      (:wat::core::let [v (:paip::bref b rr cc)]
        (:wat::core::if (:wat::core::= v 0) (:wat::core::Vector :- [:wat::core::i64])
          (:wat::core::if (:wat::core::= v player) acc
            (:paip::flips-in b rr cc dr dc player (:wat::core::conj acc (:paip::idx rr cc)))))))))

(:wat::core::defn :paip::all-flips
  [b <- :paip::Board r <- :wat::core::i64 c <- :wat::core::i64 player <- :wat::core::i64
   d <- :wat::core::i64 acc <- :paip::Board] -> :paip::Board
  (:wat::core::if (:wat::core::>= d 8) acc
    (:paip::all-flips b r c player (:wat::core::+ d 1)
      (:wat::core::concat acc
        (:paip::flips-in b r c (:wat::core::nth (:paip::drs) d) (:wat::core::nth (:paip::dcs) d)
          player (:wat::core::Vector :- [:wat::core::i64]))))))

(:wat::core::defn :paip::flips-at [b <- :paip::Board i <- :wat::core::i64 player <- :wat::core::i64] -> :paip::Board
  (:paip::all-flips b (:wat::i64::quot i 8) (:wat::i64::rem i 8) player 0
    (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::legal? [b <- :paip::Board i <- :wat::core::i64 player <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::= (:wat::core::nth b i) 0)
    (:wat::core::not (:wat::core::empty? (:paip::flips-at b i player)))))

(:wat::core::defn :paip::legal-moves [b <- :paip::Board player <- :wat::core::i64 i <- :wat::core::i64 acc <- :paip::Board] -> :paip::Board
  (:wat::core::if (:wat::core::>= i 64) acc
    (:paip::legal-moves b player (:wat::core::+ i 1)
      (:wat::core::if (:paip::legal? b i player) (:wat::core::conj acc i) acc))))

(:wat::core::defn :paip::moves [b <- :paip::Board player <- :wat::core::i64] -> :paip::Board
  (:paip::legal-moves b player 0 (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::apply-flips [b <- :paip::Board fs <- :paip::Board k <- :wat::core::i64 player <- :wat::core::i64] -> :paip::Board
  (:wat::core::if (:wat::core::>= k (:wat::core::length fs)) b
    (:paip::apply-flips (:paip::set-at b (:wat::core::nth fs k) player) fs (:wat::core::+ k 1) player)))

(:wat::core::defn :paip::make-move [b <- :paip::Board i <- :wat::core::i64 player <- :wat::core::i64] -> :paip::Board
  (:paip::apply-flips (:paip::set-at b i player) (:paip::flips-at b i player) 0 player))

(:wat::core::defn :paip::count-pieces [b <- :paip::Board p <- :wat::core::i64 i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i 64) n
    (:paip::count-pieces b p (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= (:wat::core::nth b i) p) (:wat::core::+ n 1) n))))

(:wat::core::defn :paip::pieces [b <- :paip::Board p <- :wat::core::i64] -> :wat::core::i64
  (:paip::count-pieces b p 0 0))

(:wat::core::defn :paip::difference [b <- :paip::Board p <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::- (:paip::pieces b p) (:paip::pieces b (:paip::opponent p))))

;; ---- the two searches, each counting its nodes
(:wat::core::defenum :paip::Node :wat::enum::Pure
  :N [v <- :wat::core::i64  nodes <- :wat::core::i64])

(:wat::core::defn :paip::minimax [b <- :paip::Board player <- :wat::core::i64 depth <- :wat::core::i64 nodes <- :wat::core::i64] -> :paip::Node
  (:wat::core::let [n (:wat::core::+ nodes 1)]
    (:wat::core::if (:wat::core::= depth 0) (:paip::Node.N {:v (:paip::difference b player) :nodes n})
      (:wat::core::let [ms (:paip::moves b player)]
        (:wat::core::if (:wat::core::empty? ms)
          (:wat::core::match (:paip::minimax b (:paip::opponent player) (:wat::core::- depth 1) n)
            [:paip::Node.N {:v v :nodes n2} (:paip::Node.N {:v (:wat::core::- 0 v) :nodes n2})])
          (:paip::mm-loop b player depth ms 0 -1000 n))))))

(:wat::core::defn :paip::mm-loop
  [b <- :paip::Board player <- :wat::core::i64 depth <- :wat::core::i64 ms <- :paip::Board
   i <- :wat::core::i64 best <- :wat::core::i64 nodes <- :wat::core::i64] -> :paip::Node
  (:wat::core::if (:wat::core::>= i (:wat::core::length ms)) (:paip::Node.N {:v best :nodes nodes})
    (:wat::core::match (:paip::minimax (:paip::make-move b (:wat::core::nth ms i) player)
                         (:paip::opponent player) (:wat::core::- depth 1) nodes)
      [:paip::Node.N {:v v :nodes n2}
        (:wat::core::let [score (:wat::core::- 0 v)]
          (:paip::mm-loop b player depth ms (:wat::core::+ i 1)
            (:wat::core::if (:wat::core::> score best) score best) n2))])))

(:wat::core::defn :paip::alpha-beta
  [b <- :paip::Board player <- :wat::core::i64 depth <- :wat::core::i64
   alpha <- :wat::core::i64 beta <- :wat::core::i64 nodes <- :wat::core::i64] -> :paip::Node
  (:wat::core::let [n (:wat::core::+ nodes 1)]
    (:wat::core::if (:wat::core::= depth 0) (:paip::Node.N {:v (:paip::difference b player) :nodes n})
      (:wat::core::let [ms (:paip::moves b player)]
        (:wat::core::if (:wat::core::empty? ms)
          (:wat::core::match (:paip::alpha-beta b (:paip::opponent player) (:wat::core::- depth 1)
                               (:wat::core::- 0 beta) (:wat::core::- 0 alpha) n)
            [:paip::Node.N {:v v :nodes n2} (:paip::Node.N {:v (:wat::core::- 0 v) :nodes n2})])
          (:paip::ab-loop b player depth ms 0 alpha beta n))))))

(:wat::core::defn :paip::ab-loop
  [b <- :paip::Board player <- :wat::core::i64 depth <- :wat::core::i64 ms <- :paip::Board
   i <- :wat::core::i64 alpha <- :wat::core::i64 beta <- :wat::core::i64 nodes <- :wat::core::i64] -> :paip::Node
  ;; the cutoff: once alpha reaches beta the rest of this node cannot matter
  (:wat::core::if (:wat::core::or (:wat::core::>= i (:wat::core::length ms)) (:wat::core::>= alpha beta))
    (:paip::Node.N {:v alpha :nodes nodes})
    (:wat::core::match (:paip::alpha-beta (:paip::make-move b (:wat::core::nth ms i) player)
                         (:paip::opponent player) (:wat::core::- depth 1)
                         (:wat::core::- 0 beta) (:wat::core::- 0 alpha) nodes)
      [:paip::Node.N {:v v :nodes n2}
        (:wat::core::let [score (:wat::core::- 0 v)]
          (:paip::ab-loop b player depth ms (:wat::core::+ i 1)
            (:wat::core::if (:wat::core::> score alpha) score alpha) beta n2))])))

(:wat::core::defn :paip::mm [d <- :wat::core::i64] -> :paip::Node
  (:paip::minimax (:paip::initial-board) 1 d 0))
(:wat::core::defn :paip::ab [d <- :wat::core::i64] -> :paip::Node
  (:paip::alpha-beta (:paip::initial-board) 1 d -1000 1000 0))

(:wat::core::defn :paip::val-of [n <- :paip::Node] -> :wat::core::i64
  (:wat::core::match n [:paip::Node.N {:v v :nodes k} v]))
(:wat::core::defn :paip::nodes-of [n <- :paip::Node] -> :wat::core::i64
  (:wat::core::match n [:paip::Node.N {:v v :nodes k} k]))

(:wat::core::defn :paip::show-moves [ms <- :paip::Board] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) ms)) ")"))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    b0 (:paip::initial-board)
                    b1 (:paip::make-move b0 19 1)]
    (:paip::check-chapter "oracle/paip/ch18-othello.expected"
                          "paip ch18 othello"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::pieces b0 1))
                            (int (:paip::pieces b0 2))
                            (:paip::show-moves (:paip::moves b0 1))
                            (int (:wat::core::length (:paip::moves b0 1)))
                            (int (:paip::difference b0 1))
                            (int (:paip::pieces b1 1))
                            (int (:paip::pieces b1 2))
                            (:paip::show-moves (:paip::moves b1 2))
                            (int (:paip::val-of (:paip::mm 1)))
                            (int (:paip::val-of (:paip::ab 1)))
                            (int (:paip::val-of (:paip::mm 3)))
                            (int (:paip::val-of (:paip::ab 3)))
                            ;; the same answer, far fewer nodes
                            (:paip::b (:wat::core::= (:paip::val-of (:paip::mm 3)) (:paip::val-of (:paip::ab 3))))
                            (int (:paip::nodes-of (:paip::mm 3)))
                            (int (:paip::nodes-of (:paip::ab 3)))
                            (:paip::b (:wat::core::< (:paip::nodes-of (:paip::ab 3)) (:paip::nodes-of (:paip::mm 3))))))))
