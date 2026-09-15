;; The Little Learner, chapter 14 (It's Really Not That Convoluted).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch14-its-really-not-that-convoluted.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch14-its-really-not-that-convoluted.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    th (:wat::core::fn [ps <- :ll::Vs] -> :ll::V (:ll::lst ps))
                    ;; a one-channel signal or filter from its values
                    col (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                          (:ll::tensor (:wat::core::mapv (:wat::core::fn [x <- :wat::core::f64] -> :ll::V (t [x])) xs)))
                    signal (col [1.0 2.0 4.0 8.0 16.0])
                    theta-c (th [(tt [(col [1.0 0.0 -1.0]) (col [0.5 0.5 0.5])]) (t [0.0 -1.0])])
                    theta-k (th [(tt [(col [1.0 0.0 -1.0]) (col [0.5 0.5 0.5])]) (t [0.0 -1.0])
                                 (tt [(tt [(t [0.2 -0.1]) (t [0.3 0.4]) (t [-0.5 0.1])])]) (t [0.25])])
                    ;; a one-filter recu layer learning to report each segment's rise from the last
                    xs (tt [(col [1.0 2.0 4.0 3.0 5.0]) (col [0.0 1.0 1.0 3.0 2.0]) (col [2.0 2.0 5.0 6.0 6.0])])
                    ys (tt [(col [1.0 1.0 2.0 0.0 2.0]) (col [0.0 1.0 0.0 2.0 0.0]) (col [2.0 0.0 3.0 1.0 0.0])])
                    theta0 (th [(tt [(col [0.1 0.2 0.3])]) (t [0.1])])
                    obj ((:ll::l2-loss :ll::recu) xs ys)]
    (:ll::check-chapter "oracle/learner/ch14-its-really-not-that-convoluted.expected"
                        "little-learner ch14 its-really-not-that-convoluted"
                        (:wat::core::Vector :- [:ll::V]
                          ((:ll::corr signal) theta-c)
                          ((:ll::recu signal) theta-c)
                          (((:ll::k-recu 2) signal) theta-k)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (:ll::sum (((:ll::k-recu 2) signal) p)))) theta-k)
                          (obj theta0)
                          ((:ll::naked-gradient-descent (:ll::hypers 200 0.01)) obj theta0)))))
