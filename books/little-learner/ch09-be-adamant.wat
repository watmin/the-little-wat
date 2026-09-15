;; The Little Learner, chapter 9 (Be Adamant).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch09-be-adamant.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch09-be-adamant.wat

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
    (:ll::check-chapter "oracle/learner/ch09-be-adamant.expected"
                        "little-learner ch09 be-adamant"
                        (:wat::core::Vector :- [:ll::V]
                          ;; adam: velocity's smoothed gradient, stepped by rms's per-parameter rate
                          ((:ll::adam-gradient-descent (h 1000 0.01 0.85 0.9)) line-obj (theta [0.0 0.0]))
                          ((:ll::adam-gradient-descent (h 1500 0.01 0.85 0.9)) plane-obj (wb (t [0.0 0.0]) 0.0))
                          ((:ll::adam-gradient-descent (h 20 0.1 0.5 0.5)) line-obj (theta [1.0 1.0]))
                          (plane-obj ((:ll::adam-gradient-descent (h 1500 0.01 0.85 0.9)) plane-obj (wb (t [0.0 0.0]) 0.0)))))))
