;; The Little Learner, chapter 12 (Rock Around the Block).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch12-rock-around-the-block.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch12-rock-around-the-block.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

;; a dense relu block of m neurons over n inputs: weights (m n), biases (m)
(:wat::core::defn :ll::dense [m <- :wat::core::i64 n <- :wat::core::i64] -> :ll::Block
  (:ll::block :ll::relu (:wat::core::Vector :- [:ll::Ints] [m n] [m])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    th (:wat::core::fn [ps <- :ll::Vs] -> :ll::V (:ll::lst ps))
                    net (:ll::stack-blocks (:wat::core::Vector :- [:ll::Block] (:ll::dense 3 2) (:ll::dense 1 3)))
                    net3 (:ll::stack-blocks (:wat::core::Vector :- [:ll::Block] (:ll::dense 3 2) (:ll::dense 2 3) (:ll::dense 1 2)))
                    theta0 (th [(tt [(t [0.8 -0.6]) (t [-0.7 0.9]) (t [0.3 0.4])]) (t [0.1 0.0 -0.1])
                                (tt [(t [0.5 0.6 -0.4])]) (t [0.05])])
                    xs (tt [(t [0.0 0.0]) (t [0.0 1.0]) (t [1.0 0.0]) (t [1.0 1.0])])
                    ys (tt [(t [0.0]) (t [1.0]) (t [1.0]) (t [0.0])])
                    theta3 (th [(tt [(t [0.8 -0.6]) (t [-0.7 0.9]) (t [0.3 0.4])]) (t [0.1 0.0 -0.1])
                                (tt [(t [0.5 0.6 -0.4]) (t [-0.2 0.3 0.9])]) (t [0.0 0.2])
                                (tt [(t [1.1 -0.5])]) (t [0.3])])]
    (:ll::check-chapter "oracle/learner/ch12-rock-around-the-block.expected"
                        "little-learner ch12 rock-around-the-block"
                        (:wat::core::Vector :- [:ll::V]
                          ;; a block: a function of t and theta, and the shapes of the theta it takes
                          (:ll::shapes-value (:ll::Block/ls (:ll::dense 3 2)))
                          ;; stacking: theta is split between the blocks
                          (:ll::shapes-value (:ll::Block/ls net))
                          (:ll::shapes-value (:ll::Block/ls net3))
                          (((:ll::Block/fn net) (t [2.0 1.0])) theta0)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (((:ll::Block/fn net) xs) p))) theta0)
                          (((:ll::Block/fn net3) (t [1.0 -1.0])) theta3)
                          (((:ll::Block/fn net3) xs) theta3)
                          ;; the stacked net trains exactly as (k-relu 2) does
                          ((:ll::naked-gradient-descent (:ll::hypers 800 0.05)) ((:ll::l2-loss (:ll::Block/fn net)) xs ys) theta0)))))
