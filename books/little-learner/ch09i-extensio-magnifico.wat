;; The Little Learner, Interlude V (Extensio Magnifico!).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch09i-extensio-magnifico.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch09i-extensio-magnifico.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    th (:wat::core::fn [ps <- :ll::Vs] -> :ll::V (:ll::lst ps))
                    t2 (tt [(t [3.0 4.0 5.0]) (t [7.0 8.0 9.0])])
                    t1 (t [4.0 5.0 6.0])
                    ;; ext1 and ext2 at ranks above 0
                    sum-of-rows (:ll::ext1 :ll::sum-1 1)
                    dot-1-1 (:ll::ext2 (:wat::core::fn [a <- :ll::V b <- :ll::V] -> :ll::V (:ll::sum-1 (:ll::* a b))) 1 1)]
    (:ll::check-chapter "oracle/learner/ch09i-extensio-magnifico.expected"
                        "little-learner ch09i extensio-magnifico"
                        (:wat::core::Vector :- [:ll::V]
                          ;; *-2-1: each row of a rank-2 tensor times a rank-1 tensor
                          (:ll::*-2-1 t2 t1)
                          (:ll::*-2-1 t2 (tt [(t [4.0 5.0 6.0]) (t [4.0 5.0 6.0]) (t [4.0 5.0 6.0])]))
                          (:ll::dot-product-2-1 t2 t1)
                          (sum-of-rows (tt [(t [1.0 2.0]) (t [3.0 4.0])]))
                          (sum-of-rows (tt [(tt [(t [1.0 2.0])]) (tt [(t [3.0 4.0])])]))
                          (dot-1-1 (tt [(t [1.0 2.0]) (t [3.0 4.0])]) (t [5.0 6.0]))
                          (dot-1-1 (t [1.0 2.0]) (tt [(t [3.0 4.0]) (t [5.0 6.0])]))
                          ;; rectify: below 0 becomes 0
                          (:ll::rectify (t [-1.0 0.5 -0.0 2.0]))
                          (:ll::rectify (tt [(t [-3.0 3.0]) (t [0.0 -0.1])]))
                          ;; gradients through them
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (:ll::rectify (:ll::ref p 0))))
                                            (th [(t [-1.0 2.0 3.0])]))
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::dot-product-2-1 (:ll::ref p 0) (:ll::ref p 1)))
                                            (th [(tt [(t [1.0 2.0]) (t [3.0 4.0])]) (t [5.0 6.0])]))
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (:ll::*-2-1 (:ll::ref p 0) t1)))
                                            (th [t2]))))))
