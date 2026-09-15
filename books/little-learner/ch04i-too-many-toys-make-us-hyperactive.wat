;; The Little Learner, Interlude II (Too Many Toys Make Us Hyperactive).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch04i-too-many-toys-make-us-hyperactive.rkt, run by tools/learner-oracle.sh).
;;
;; malt binds its hyperparameters dynamically: (with-hypers ((revs 1000) (alpha 0.01)) ...)
;; sets globals for the extent of its body. wat has no dynamic binding, so here they are a
;; :ll::Hypers value handed to the descent; a nested with-hypers is a second value.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch04i-too-many-toys-make-us-hyperactive.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    obj ((:ll::l2-loss :ll::line) (t [2.0 1.0 4.0 3.0]) (t [1.8 1.2 4.2 3.3]))
                    naked (:wat::core::fn [revs <- :wat::core::i64 alpha <- :wat::core::f64] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
                            (:ll::naked-gradient-descent (:ll::hypers revs alpha)))]
    (:ll::check-chapter "oracle/learner/ch04i-too-many-toys-make-us-hyperactive.expected"
                        "little-learner ch04i too-many-toys-make-us-hyperactive"
                        (:wat::core::Vector :- [:ll::V]
                          ((naked 1000 0.01) obj (theta [0.0 0.0]))
                          ((naked 100 0.001) obj (theta [0.0 0.0]))
                          ((naked 10 0.05) obj (theta [1.0 1.0]))
                          ((naked 0 0.01) obj (theta [3.0 4.0]))
                          ;; malt's own test: descending (30 - x)^2 from 3
                          ((naked 400 0.01) (:wat::core::fn [th <- :ll::V] -> :ll::V (:ll::sqr (:ll::- (n 30.0) (:ll::ref th 0))))
                                            (theta [3.0]))
                          ;; nested bindings: the inner one wins inside it, the outer one is back after it
                          (:ll::lst (:wat::core::Vector :- [:ll::V]
                                      ((naked 5 0.01) obj (theta [0.0 0.0]))
                                      ((naked 5 0.02) obj (theta [0.0 0.0]))
                                      ((naked 5 0.01) obj (theta [0.0 0.0]))))))))
