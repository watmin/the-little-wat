;; The Little Learner, chapter 2 (The More We Learn, the Tenser We Become).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch02-the-more-we-learn-the-tenser-we-become.rkt, run by
;; tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch02-the-more-we-learn-the-tenser-we-become.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

;; rank by recursion, the book's way: count the trefs down to a scalar
(:wat::core::defn :ll::ranked [t <- :ll::V a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:ll::scalar? t) a (:ll::ranked (:ll::tref t 0) (:wat::core::+ a 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t1 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 c <- :wat::core::f64] -> :ll::V
                         (:ll::tensor (:wat::core::Vector :- [:ll::V] (:ll::num a) (:ll::num b) (:ll::num c))))
                    t2 (:wat::core::fn [a <- :ll::V b <- :ll::V] -> :ll::V (:ll::tensor (:wat::core::Vector :- [:ll::V] a b)))
                    pair (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :ll::V
                           (:ll::tensor (:wat::core::Vector :- [:ll::V] (:ll::num a) (:ll::num b))))
                    one (:wat::core::fn [a <- :wat::core::f64] -> :ll::V (:ll::tensor (:wat::core::Vector :- [:ll::V] (:ll::num a))))
                    theta (:wat::core::fn [w <- :wat::core::f64 b <- :wat::core::f64] -> :ll::V
                            (:ll::lst (:wat::core::Vector :- [:ll::V] (:ll::num w) (:ll::num b))))
                    count (:wat::core::fn [k <- :wat::core::i64] -> :ll::V (:ll::num (:wat::i64::to-f64 k)))]
    (:ll::check-chapter "oracle/learner/ch02-the-more-we-learn-the-tenser-we-become.expected"
                        "little-learner ch02 the-more-we-learn-the-tenser-we-become"
                        (:wat::core::Vector :- [:ll::V]
                          ;; tensors, their ranks, shapes, lengths and entries
                          (t1 1.0 2.0 3.0)
                          (count (:ll::rank (n 5.0)))
                          (count (:ll::rank (pair 1.0 2.0)))
                          (count (:ll::rank (t2 (pair 1.0 2.0) (pair 3.0 4.0))))
                          (:ll::shape-value (n 7.0))
                          (:ll::shape-value (t2 (t1 1.0 2.0 3.0) (t1 4.0 5.0 6.0)))
                          (:ll::shape-value (t2 (t2 (one 1.0) (one 2.0)) (t2 (one 3.0) (one 4.0))))
                          (count (:ll::tlen (t1 1.0 2.0 3.0)))
                          (:ll::tref (t1 5.0 6.0 7.0) 1)
                          (:ll::tref (t2 (pair 1.0 2.0) (pair 3.0 4.0)) 1)
                          ;; rank by recursion
                          (count (:ll::ranked (:ll::tensor (:wat::core::Vector :- [:ll::V] (:ll::tensor (:wat::core::Vector :- [:ll::V] (one 8.0))))) 0))
                          (count (:ll::ranked (n 9.0) 0))
                          ;; a line of a tensor of xs gives a tensor of ys
                          ((:ll::line (:ll::tensor (:wat::core::Vector :- [:ll::V] (n 2.0) (n 1.0) (n 4.0) (n 3.0)))) (theta 0.5 1.0))
                          ((:ll::line (t2 (pair 1.0 2.0) (pair 3.0 4.0))) (theta 2.0 -1.0))
                          ((:ll::line (t1 0.1 0.2 0.3)) (theta 3.0 0.7))))))
