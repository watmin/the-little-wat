#lang racket
;; oracle/learner/ch08i-smooth-operator.rkt: The Little Learner, Interlude IV (Smooth
;; Operator). Our own examples on the interlude's topics, run with malt;
;; books/little-learner/ch08i-smooth-operator.wat must compute the same, in order.

(require malt)
(require "show.rkt")

(define line-obj ((l2-loss line) (tensor 2.0 1.0 4.0 3.0) (tensor 1.8 1.2 4.2 3.3)))
(define plane-obj
  ((l2-loss plane)
   (tensor (tensor 1.0 2.05) (tensor 1.0 3.0) (tensor 2.0 2.0)
           (tensor 2.0 3.91) (tensor 3.0 6.13) (tensor 4.0 8.09))
   (tensor 13.99 15.99 18.0 22.4 30.2 37.94)))

;; smooth: a decaying average, decay-rate * average + (1 - decay-rate) * g
(show (smooth 0.9 0.0 50.3))
(show (smooth 0.9 5.03 22.7))
(show (smooth 0.9 (tensor 0.8 3.1 2.2) (tensor 1.0 1.1 3.0)))
(show (smooth 0.5 (smooth 0.5 (smooth 0.5 0.0 1.0) 1.0) 1.0))

;; rms: each parameter's step is alpha over the root of a smoothed square of its gradients
(show (with-hypers ((revs 1000) (alpha 0.01) (beta 0.9)) (rms-gradient-descent line-obj (list 0.0 0.0))))
(show (with-hypers ((revs 3000) (alpha 0.01) (beta 0.9)) (rms-gradient-descent plane-obj (list (tensor 0.0 0.0) 0.0))))
(show (with-hypers ((revs 50) (alpha 0.1) (beta 0.5)) (rms-gradient-descent line-obj (list 1.0 1.0))))
