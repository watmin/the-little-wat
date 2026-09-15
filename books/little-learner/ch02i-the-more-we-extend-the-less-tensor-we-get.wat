;; The Little Learner, Interlude I (The More We Extend, the Less Tensor We Get).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch02i-the-more-we-extend-the-less-tensor-we-get.rkt, run by
;; tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch02i-the-more-we-extend-the-less-tensor-we-get.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))]
    (:ll::check-chapter "oracle/learner/ch02i-the-more-we-extend-the-less-tensor-we-get.expected"
                        "little-learner ch02i the-more-we-extend-the-less-tensor-we-get"
                        (:wat::core::Vector :- [:ll::V]
                          ;; extended arithmetic: same shapes, a scalar with a tensor, and different ranks
                          (:ll::+ (t [2.0 7.0]) (t [4.0 3.0]))
                          (:ll::+ (n 4.0) (t [1.0 2.0 3.0]))
                          (:ll::+ (tt [(t [1.0 2.0]) (t [3.0 4.0])]) (t [10.0 20.0]))
                          (:ll::+ (tt [(t [1.0]) (t [2.0])]) (tt [(t [0.5]) (t [0.25])]))
                          (:ll::* (t [2.0 3.0]) (t [4.0 5.0]))
                          (:ll::- (t [5.0 6.0]) (n 1.5))
                          (:ll::/ (t [1.0 2.0]) (t [3.0 7.0]))
                          ;; extended unary functions
                          (:ll::sqr (t [1.5 -2.0]))
                          (:ll::sqrt (t [4.0 2.0]))
                          (:ll::exp (t [0.0 1.0]))
                          (:ll::log (t [1.0 10.0]))
                          ;; sum: of a rank-1 tensor a scalar; of a rank-2 tensor, each row's sum
                          (:ll::sum (t [10.5 12.25 -3.0]))
                          (:ll::sum (tt [(t [1.0 2.0]) (t [3.0 4.0])]))
                          (:ll::sum (t [0.1 0.2 0.3]))))))
