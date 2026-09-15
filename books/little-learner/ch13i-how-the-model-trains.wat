;; The Little Learner, Interlude VI (How the Model Trains).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch13i-how-the-model-trains.rkt, run by tools/learner-oracle.sh).
;;
;; malt's grid-search binds each combination of hypers dynamically around its body; here
;; each combination is a Hypers value handed to the body, and the answer is an Option.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch13i-how-the-model-trains.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :ll::found [o <- (:wat::core::Option :- [:ll::V])] -> :ll::V
  (:wat::core::match o
    [:wat::core::Option.Some {:value theta} theta]
    [:wat::core::Option.None {} (:ll::fail "grid-search found nothing good enough")]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    wb (:wat::core::fn [w <- :ll::V b <- :wat::core::f64] -> :ll::V
                         (:ll::lst (:wat::core::Vector :- [:ll::V] w (:ll::num b))))
                    line-obj ((:ll::l2-loss :ll::line) (t [2.0 1.0 4.0 3.0]) (t [1.8 1.2 4.2 3.3]))
                    plane-obj ((:ll::l2-loss :ll::plane)
                               (:ll::tensor (:wat::core::Vector :- [:ll::V]
                                              (t [1.0 2.05]) (t [1.0 3.0]) (t [2.0 2.0])
                                              (t [2.0 3.91]) (t [3.0 6.13]) (t [4.0 8.09])))
                               (t [13.99 15.99 18.0 22.4 30.2 37.94]))
                    below (:wat::core::fn [obj <- [:ll::V :-> :ll::V] limit <- :wat::core::f64] -> [:ll::V :-> :wat::core::bool]
                            (:wat::core::fn [th <- :ll::V] -> :wat::core::bool (:wat::core::< (:ll::rho (obj th)) limit)))
                    descend (:wat::core::fn [obj <- [:ll::V :-> :ll::V] th0 <- :ll::V] -> [:ll::Hypers :-> :ll::V]
                              (:wat::core::fn [h <- :ll::Hypers] -> :ll::V ((:ll::naked-gradient-descent h) obj th0)))]
    (:ll::check-chapter "oracle/learner/ch13i-how-the-model-trains.expected"
                        "little-learner ch13i how-the-model-trains"
                        (:wat::core::Vector :- [:ll::V]
                          (:ll::found (:ll::grid-search (below line-obj 0.2) [10 100 1000] [0.0001 0.001 0.01]
                                                        (descend line-obj (theta [0.0 0.0]))))
                          (:ll::found (:ll::grid-search (below line-obj 0.14) [10 100 1000] [0.0001 0.001 0.01]
                                                        (descend line-obj (theta [0.0 0.0]))))
                          (:ll::found (:ll::grid-search (below plane-obj 1.0) [100 500 1000] [0.0001 0.001]
                                                        (descend plane-obj (wb (t [0.0 0.0]) 0.0))))))))
