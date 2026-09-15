;; The Little Learner, chapter 4 (Slip-slidin' Away).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch04-slip-slidin-away.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch04-slip-slidin-away.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    grad :ll::gradient-of
                    p0 (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::ref th 0))
                    p1 (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::ref th 1))
                    line-xs (t [2.0 1.0 4.0 3.0])
                    line-ys (t [1.8 1.2 4.2 3.3])
                    obj ((:ll::l2-loss :ll::line) line-xs line-ys)
                    alpha (n 0.01)
                    ;; theta minus alpha times the gradient, parameter by parameter, as malt's
                    ;; (map (λ (p g) (- p (* alpha g))) theta (gradient-of obj theta))
                    step (:wat::core::fn [th <- :ll::V] -> :ll::V
                           (:wat::core::let [g (:ll::gradient-of obj th)]
                             (:ll::lst (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :ll::V
                                                           (:ll::- (:ll::ref th i) (:ll::* alpha (:ll::ref g i))))
                                                         (:wat::core::range 0 (:ll::len th))))))]
    (:ll::check-chapter "oracle/learner/ch04-slip-slidin-away.expected"
                        "little-learner ch04 slip-slidin-away"
                        (:wat::core::Vector :- [:ll::V]
                          ;; gradients of functions of theta
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::sqr (p0 th))) (theta [27.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::+ (:ll::* (n 3.0) (:ll::sqr (p0 th))) (p1 th))) (theta [2.0 5.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::* (p0 th) (p1 th))) (theta [3.0 4.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::/ (p0 th) (p1 th))) (theta [1.0 4.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::- (p0 th) (p1 th))) (theta [1.0 4.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::exp (p0 th))) (theta [1.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::log (p0 th))) (theta [2.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::sqrt (p0 th))) (theta [9.0]))
                          (grad (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::sum (:ll::sqr (p0 th))))
                                (:ll::lst (:wat::core::Vector :- [:ll::V] (t [1.0 2.0 3.0]))))
                          ;; the gradient of the line's loss
                          (grad obj (theta [0.0 0.0]))
                          (grad obj (theta [1.0 0.1]))
                          ;; descending: theta minus alpha times the gradient, again and again
                          (step (theta [0.0 0.0]))
                          (:ll::revise step 1000 (theta [0.0 0.0]))
                          (obj (:ll::revise step 1000 (theta [0.0 0.0])))))))
