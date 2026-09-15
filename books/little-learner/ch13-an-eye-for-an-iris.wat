;; The Little Learner, chapter 13 (An Eye for an Iris).
;; Our own examples on the chapter's topics, and the book's own training run, computed with the
;; port of malt (lib/malt.wat) and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch13-an-eye-for-an-iris.rkt, run by tools/learner-oracle.sh).
;;
;; The Iris data and the book's printed initial theta come from malt's examples (MIT), read
;; from oracle/learner/ch13-an-eye-for-an-iris.data; the book's sampled run replays malt's
;; draws from oracle/learner/ch13-an-eye-for-an-iris.draws.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch13-an-eye-for-an-iris.wat

(:wat::load-file! "../seasoned-schemer/lib/counter.wat")
(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/sampling.wat")
(:wat::load-file! "lib/check.wat")

;; the network: two dense relu blocks, 4 inputs to 8 neurons to 3
(:wat::core::defn :ll::dense-block [n <- :wat::core::i64 m <- :wat::core::i64] -> :ll::Block
  (:ll::block :ll::relu (:wat::core::Vector :- [:ll::Ints] [m n] [m])))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [data (:ll::non-empty (:wat::string::split (:wat::io::read-file "oracle/learner/ch13-an-eye-for-an-iris.data") "\n"))
                    draw-lines (:ll::non-empty (:wat::string::split (:wat::io::read-file "oracle/learner/ch13-an-eye-for-an-iris.draws") "\n"))
                    train-xs (:ll::read-value (:wat::core::nth data 0))
                    train-ys (:ll::read-value (:wat::core::nth data 1))
                    test-xs (:ll::read-value (:wat::core::nth data 2))
                    test-ys (:ll::read-value (:wat::core::nth data 3))
                    initial-theta (:ll::read-value (:wat::core::nth data 4))
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    iris-network (:ll::stack-blocks (:wat::core::Vector :- [:ll::Block] (:ll::dense-block 4 8) (:ll::dense-block 8 3)))
                    iris-classifier (:ll::Block/fn iris-network)
                    ;; the book's run: 2000 revisions, each over 8 sampled training rows
                    h (:ll::Hypers :revs 2000 :alpha 0.0002 :batch-size 8 :mu 0.0 :beta 0.0)
                    tll-iris-theta ((:ll::naked-gradient-descent h)
                                    (:ll::sampling-obj h (:ll::draws draw-lines 0) (:ll::l2-loss iris-classifier) train-xs train-ys)
                                    initial-theta)]
    (:ll::check-chapter "oracle/learner/ch13-an-eye-for-an-iris.expected"
                        "little-learner ch13 an-eye-for-an-iris"
                        (:wat::core::Vector :- [:ll::V]
                          (:ll::shapes-value (:ll::Block/ls iris-network))
                          ;; argmax and =-1
                          (:ll::argmax (t [0.1 0.7 0.2]))
                          (:ll::argmax (tt [(t [0.5 0.5 0.1]) (t [0.0 0.2 0.3])]))
                          (:ll::=-1 (t [1.0 2.0 3.0]) (t [1.0 0.0 3.0]))
                          ;; the untrained classifier on the test set, and its accuracy
                          ((iris-classifier test-xs) initial-theta)
                          (:ll::accuracy (:ll::model iris-classifier initial-theta) test-xs test-ys)
                          ;; the book's run, and the trained classifier's accuracy
                          tll-iris-theta
                          (:ll::accuracy (:ll::model iris-classifier tll-iris-theta) test-xs test-ys)))))
