;; The Little Learner, chapter 11 (In Love with the Shape of Relu).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch11-in-love-with-the-shape-of-relu.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch11-in-love-with-the-shape-of-relu.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    th (:wat::core::fn [ps <- :ll::Vs] -> :ll::V (:ll::lst ps))
                    theta-2layer (th [(tt [(t [1.0 -1.0]) (t [0.5 0.5])]) (t [0.0 0.1])
                                      (tt [(t [1.0 2.0])]) (t [-0.5])])
                    x (t [2.0 1.0])
                    ;; a 2-layer network learning xor
                    xs (tt [(t [0.0 0.0]) (t [0.0 1.0]) (t [1.0 0.0]) (t [1.0 1.0])])
                    ys (tt [(t [0.0]) (t [1.0]) (t [1.0]) (t [0.0])])
                    theta0 (th [(tt [(t [0.8 -0.6]) (t [-0.7 0.9]) (t [0.3 0.4])]) (t [0.1 0.0 -0.1])
                                (tt [(t [0.5 0.6 -0.4])]) (t [0.05])])
                    obj ((:ll::l2-loss (:ll::k-relu 2)) xs ys)
                    fitted ((:ll::naked-gradient-descent (:ll::hypers 800 0.05)) obj theta0)]
    (:ll::check-chapter "oracle/learner/ch11-in-love-with-the-shape-of-relu.expected"
                        "little-learner ch11 in-love-with-the-shape-of-relu"
                        (:wat::core::Vector :- [:ll::V]
                          ;; refr: a list from its i-th member on
                          (:ll::refr (th [(:ll::num 1.0) (:ll::num 2.0) (:ll::num 3.0) (:ll::num 4.0)]) 2)
                          ;; (k-relu k): k relu layers, each taking the next two members of theta
                          (((:ll::k-relu 0) x) theta-2layer)
                          (((:ll::k-relu 1) x) theta-2layer)
                          (((:ll::k-relu 2) x) theta-2layer)
                          (((:ll::k-relu 2) (tt [(t [2.0 1.0]) (t [-3.0 4.0])])) theta-2layer)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (((:ll::k-relu 2) x) p))) theta-2layer)
                          ;; the xor network
                          (obj theta0)
                          fitted
                          (obj fitted)
                          (((:ll::k-relu 2) xs) fitted)))))
