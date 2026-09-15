;; The Little Learner, chapter 10 (Doing the Neuron Dance).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch10-doing-the-neuron-dance.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch10-doing-the-neuron-dance.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    th (:wat::core::fn [ps <- :ll::Vs] -> :ll::V (:ll::lst ps))
                    ;; a layer's theta: a weight row per neuron, and a bias per neuron
                    theta2 (th [(tt [(t [3.0 4.0]) (t [1.0 -2.0])]) (t [0.5 -1.5])])
                    batch (tt [(t [2.0 1.0]) (t [-1.0 0.5])])
                    ;; one neuron learning to fire for the first input and for both
                    xs (tt [(t [1.0 0.0]) (t [0.0 1.0]) (t [1.0 1.0])])
                    ys (tt [(t [1.0]) (t [0.0]) (t [1.0])])
                    theta0 (th [(tt [(t [0.5 0.5])]) (t [0.1])])
                    obj ((:ll::l2-loss :ll::relu) xs ys)
                    fitted ((:ll::naked-gradient-descent (:ll::hypers 500 0.01)) obj theta0)]
    (:ll::check-chapter "oracle/learner/ch10-doing-the-neuron-dance.expected"
                        "little-learner ch10 doing-the-neuron-dance"
                        (:wat::core::Vector :- [:ll::V]
                          ;; linear: each neuron's weights dotted with the input, plus its bias
                          ((:ll::linear (t [2.0 1.0])) theta2)
                          ;; relu: the linear result, rectified
                          ((:ll::relu (t [2.0 1.0])) theta2)
                          ((:ll::relu (t [-2.0 1.0])) theta2)
                          ;; a batch of inputs, one row each
                          ((:ll::relu batch) theta2)
                          ;; the gradient of a neuron's summed output
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum ((:ll::relu (t [2.0 1.0])) p))) theta2)
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum ((:ll::relu batch) p))) theta2)
                          ;; one neuron learning
                          (obj theta0)
                          fitted
                          (obj fitted)))))
