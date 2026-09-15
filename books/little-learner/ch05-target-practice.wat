;; The Little Learner, chapter 5 (Target Practice).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch05-target-practice.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch05-target-practice.wat

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
                    naked (:ll::naked-gradient-descent (:ll::hypers 1000 0.001))
                    ;; a quad: a*x^2 + b*x + c
                    quad-xs (t [-1.0 0.0 1.0 2.0 3.0])
                    quad-ys (t [2.55 2.1 4.35 10.2 18.25])
                    quad-obj ((:ll::l2-loss :ll::quad) quad-xs quad-ys)
                    ;; a plane: the dot product of a weight tensor with x, plus b
                    plane-xs (:ll::tensor (:wat::core::Vector :- [:ll::V]
                                            (t [1.0 2.05]) (t [1.0 3.0]) (t [2.0 2.0])
                                            (t [2.0 3.91]) (t [3.0 6.13]) (t [4.0 8.09])))
                    plane-ys (t [13.99 15.99 18.0 22.4 30.2 37.94])
                    plane-obj ((:ll::l2-loss :ll::plane) plane-xs plane-ys)]
    (:ll::check-chapter "oracle/learner/ch05-target-practice.expected"
                        "little-learner ch05 target-practice"
                        (:wat::core::Vector :- [:ll::V]
                          ((:ll::quad (n 3.0)) (theta [4.5 2.1 7.8]))
                          ((:ll::quad quad-xs) (theta [1.0 1.0 1.0]))
                          (quad-obj (theta [0.0 0.0 0.0]))
                          (:ll::gradient-of quad-obj (theta [0.0 0.0 0.0]))
                          (naked quad-obj (theta [0.0 0.0 0.0]))
                          (:ll::dot-product (t [1.0 2.0 3.0]) (t [4.0 5.0 6.0]))
                          ((:ll::plane (t [1.0 2.0])) (wb (t [3.0 4.0]) 5.0))
                          ((:ll::plane plane-xs) (wb (t [1.0 1.0]) 0.5))
                          (plane-obj (wb (t [0.0 0.0]) 0.0))
                          (:ll::gradient-of plane-obj (wb (t [0.0 0.0]) 0.0))
                          (naked plane-obj (wb (t [0.0 0.0]) 0.0))))))
