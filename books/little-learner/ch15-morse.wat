;; The Little Learner, chapter 15 (the Morse chapter).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch15-morse.rkt, run by tools/learner-oracle.sh).
;;
;; malt's Morse networks (malt/examples/morse.rkt) are four fcn or residual blocks and
;; signal-avg, trained with adam for 20000 revisions. malt's learner representation can't
;; run that, and this port is well over 100 times slower than malt (ch 13), so the same
;; blocks are built small here, with a fixed patterned theta, and checked without training.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch15-morse.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

;; malt's blocks, from malt/examples/morse.rkt (MIT)
(:wat::core::defn :ll::fcn-block [b <- :wat::core::i64 m <- :wat::core::i64 d <- :wat::core::i64] -> :ll::Block
  (:ll::block (:ll::k-recu 2) (:wat::core::Vector :- [:ll::Ints] [b m d] [b] [b m b] [b])))

(:wat::core::defn :ll::signal-avg-block [] -> :ll::Block
  (:ll::block :ll::signal-avg (:wat::core::Vector :- [:ll::Ints])))

(:wat::core::defn :ll::skip [f <- [:ll::V :-> [:ll::V :-> :ll::V]] j <- :wat::core::i64] -> [:ll::V :-> [:ll::V :-> :ll::V]]
  (:wat::core::fn [t <- :ll::V] -> [:ll::V :-> :ll::V]
    (:wat::core::fn [theta <- :ll::V] -> :ll::V
      (:ll::+ ((f t) theta) (:ll::correlate (:ll::ref theta j) t)))))

(:wat::core::defn :ll::skip-block [ba <- :ll::Block d <- :wat::core::i64 b <- :wat::core::i64] -> :ll::Block
  (:wat::core::let [shape-list (:ll::Block/ls ba)]
    (:ll::block (:ll::skip (:ll::Block/fn ba) (:wat::core::length shape-list))
                (:wat::core::concat shape-list (:wat::core::Vector :- [:ll::Ints] [b 1 d])))))

(:wat::core::defn :ll::residual-block [b <- :wat::core::i64 m <- :wat::core::i64 d <- :wat::core::i64] -> :ll::Block
  (:ll::skip-block (:ll::fcn-block b m d) d b))

;; a fixed theta for a list of shapes: entry (i j k ...) of the n-th member is
;; ((7i + 3j + k + n + 1) mod 11 - 5) / 10, the index padded with 0s
(:wat::core::defn :ll::pattern [n <- :wat::core::i64 idx <- :ll::Ints] -> :ll::V
  (:wat::core::let [at (:wat::core::fn [p <- :wat::core::i64] -> :wat::core::i64
                         (:wat::core::if (:wat::core::> (:wat::core::length idx) p) (:wat::core::nth idx p) 0))
                    x (:wat::core::+ (:wat::core::+ (:wat::core::+ (:wat::core::* 7 (at 0)) (:wat::core::* 3 (at 1))) (:wat::core::+ (at 2) n)) 1)]
    (:ll::num (:wat::core::/ (:wat::i64::to-f64 (:wat::core::- (:wat::i64::mod x 11) 5)) 10.0))))

(:wat::core::defn :ll::patterned-theta [shapes <- (:wat::core::Vector :- [:ll::Ints])] -> :ll::V
  (:ll::lst (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :ll::V
                                (:ll::build-tensor (:wat::core::nth shapes n)
                                  (:wat::core::fn [idx <- :ll::Ints] -> :ll::V (:ll::pattern n idx))))
                              (:wat::core::range 0 (:wat::core::length shapes)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    col (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                          (:ll::tensor (:wat::core::mapv (:wat::core::fn [x <- :wat::core::f64] -> :ll::V (t [x])) xs)))
                    signal (col [0.0 1.0 1.0 0.0 1.0 1.0])
                    tiny-fcn (:ll::stack-blocks (:wat::core::Vector :- [:ll::Block] (:ll::fcn-block 2 3 1) (:ll::fcn-block 3 3 2) (:ll::signal-avg-block)))
                    theta-fcn (:ll::patterned-theta (:ll::Block/ls tiny-fcn))
                    tiny-residual (:ll::stack-blocks (:wat::core::Vector :- [:ll::Block] (:ll::residual-block 2 3 1) (:ll::residual-block 3 3 2) (:ll::signal-avg-block)))
                    theta-res (:ll::patterned-theta (:ll::Block/ls tiny-residual))]
    (:ll::check-chapter "oracle/learner/ch15-morse.expected"
                        "little-learner ch15 morse"
                        (:wat::core::Vector :- [:ll::V]
                          ;; signal-avg: the average of a signal's segments, channel by channel
                          ((:ll::signal-avg (tt [(t [1.0 2.0]) (t [3.0 4.0]) (t [5.0 9.0])])) (:ll::lst (:wat::core::Vector :- [:ll::V])))
                          ;; a small fcn network
                          (:ll::shapes-value (:ll::Block/ls tiny-fcn))
                          (:ll::ref theta-fcn 2)
                          (((:ll::Block/fn tiny-fcn) signal) theta-fcn)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (((:ll::Block/fn tiny-fcn) signal) p))) theta-fcn)
                          ;; a small residual network
                          (:ll::shapes-value (:ll::Block/ls tiny-residual))
                          (((:ll::Block/fn tiny-residual) signal) theta-res)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (((:ll::Block/fn tiny-residual) signal) p))) theta-res)))))
