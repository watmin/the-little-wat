;; The Little Learner, Interlude IV (Smooth Operator).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch08i-smooth-operator.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch08i-smooth-operator.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    wb (:wat::core::fn [w <- :ll::V b <- :wat::core::f64] -> :ll::V
                         (:ll::lst (:wat::core::Vector :- [:ll::V] w (:ll::num b))))
                    line-obj ((:ll::l2-loss :ll::line) (t [2.0 1.0 4.0 3.0]) (t [1.8 1.2 4.2 3.3]))
                    plane-xs (:ll::tensor (:wat::core::Vector :- [:ll::V]
                                            (t [1.0 2.05]) (t [1.0 3.0]) (t [2.0 2.0])
                                            (t [2.0 3.91]) (t [3.0 6.13]) (t [4.0 8.09])))
                    plane-ys (t [13.99 15.99 18.0 22.4 30.2 37.94])
                    plane-obj ((:ll::l2-loss :ll::plane) plane-xs plane-ys)
                    h (:wat::core::fn [revs <- :wat::core::i64 alpha <- :wat::core::f64 mu <- :wat::core::f64 beta <- :wat::core::f64] -> :ll::Hypers
                        (:ll::Hypers :revs revs :alpha alpha :batch-size 0 :mu mu :beta beta))]
    (:ll::check-chapter "oracle/learner/ch08i-smooth-operator.expected"
                        "little-learner ch08i smooth-operator"
                        (:wat::core::Vector :- [:ll::V]
                          ;; smooth: a decaying average, decay-rate * average + (1 - decay-rate) * g
                          (:ll::smooth (n 0.9) (n 0.0) (n 50.3))
                          (:ll::smooth (n 0.9) (n 5.03) (n 22.7))
                          (:ll::smooth (n 0.9) (t [0.8 3.1 2.2]) (t [1.0 1.1 3.0]))
                          (:ll::smooth (n 0.5) (:ll::smooth (n 0.5) (:ll::smooth (n 0.5) (n 0.0) (n 1.0)) (n 1.0)) (n 1.0))
                          ;; rms: each parameter's step is alpha over the root of a smoothed square of its gradients
                          ((:ll::rms-gradient-descent (h 1000 0.01 0.0 0.9)) line-obj (theta [0.0 0.0]))
                          ((:ll::rms-gradient-descent (h 3000 0.01 0.0 0.9)) plane-obj (wb (t [0.0 0.0]) 0.0))
                          ((:ll::rms-gradient-descent (h 50 0.1 0.0 0.5)) line-obj (theta [1.0 1.0]))))))
