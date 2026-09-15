;; The Little Learner, chapter 8 (The Nearer Your Destination, the Slower You Become).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch08-the-nearer-your-destination-the-slower-you-become.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch08-the-nearer-your-destination-the-slower-you-become.wat

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
    (:ll::check-chapter "oracle/learner/ch08-the-nearer-your-destination-the-slower-you-become.expected"
                        "little-learner ch08 the-nearer-your-destination-the-slower-you-become"
                        (:wat::core::Vector :- [:ll::V]
                          ;; zeroes: a tensor of zeroes of the same shape
                          (:ll::zeroes (t [1.5 -2.0 3.0]))
                          (:ll::zeroes (:ll::tensor (:wat::core::Vector :- [:ll::V] (t [1.0 2.0]) (t [3.0 4.0]))))
                          ;; velocity: each revision keeps a fraction mu of the last change
                          ((:ll::velocity-gradient-descent (h 1000 0.01 0.9 0.0)) line-obj (theta [0.0 0.0]))
                          ((:ll::velocity-gradient-descent (h 100 0.01 0.5 0.0)) line-obj (theta [0.0 0.0]))
                          ((:ll::velocity-gradient-descent (h 1000 0.001 0.9 0.0)) plane-obj (wb (t [0.0 0.0]) 0.0))
                          ((:ll::velocity-gradient-descent (h 1000 0.001 0.0 0.0)) plane-obj (wb (t [0.0 0.0]) 0.0))))))
