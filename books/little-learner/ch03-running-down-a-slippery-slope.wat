;; The Little Learner, chapter 3 (Running Down a Slippery Slope).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch03-running-down-a-slippery-slope.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch03-running-down-a-slippery-slope.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    line-xs (t [2.0 1.0 4.0 3.0])
                    line-ys (t [1.8 1.2 4.2 3.3])
                    obj ((:ll::l2-loss :ll::line) line-xs line-ys)
                    each (:wat::core::fn [g <- [:ll::V :-> :ll::V]] -> [:ll::V :-> :ll::V]
                           (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::lst (:wat::core::mapv g (:ll::elems th)))))]
    (:ll::check-chapter "oracle/learner/ch03-running-down-a-slippery-slope.expected"
                        "little-learner ch03 running-down-a-slippery-slope"
                        (:wat::core::Vector :- [:ll::V]
                          ;; the loss of a line at theta: the sum of the squared differences
                          ((:ll::line line-xs) (theta [0.0 0.0]))
                          (:ll::- line-ys ((:ll::line line-xs) (theta [0.0 0.0])))
                          (:ll::sqr (:ll::- line-ys ((:ll::line line-xs) (theta [0.0 0.0]))))
                          (obj (theta [0.0 0.0]))
                          (obj (theta [0.0099 0.0]))
                          (obj (theta [1.0 0.0]))
                          (obj (theta [1.0 0.1]))
                          ;; the rate of change of the loss, by hand: nudge w and see how the loss moves
                          (:ll::- (obj (theta [0.0099 0.0])) (obj (theta [0.0 0.0])))
                          (:ll::/ (:ll::- (obj (theta [0.0099 0.0])) (obj (theta [0.0 0.0]))) (n 0.0099))
                          ;; revise: apply a function to theta revs times
                          (:ll::revise (each (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::+ p (n 0.5)))) 4 (theta [1.0 2.0]))
                          (:ll::revise (each (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::* p (n 0.5)))) 3 (theta [8.0 -1.0]))))))
