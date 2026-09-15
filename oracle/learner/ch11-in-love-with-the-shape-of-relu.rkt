#lang racket
;; oracle/learner/ch11-in-love-with-the-shape-of-relu.rkt: The Little Learner, chapter 11 (In
;; Love with the Shape of Relu). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch11-in-love-with-the-shape-of-relu.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; refr: a list from its i-th member on (each layer takes its two, and passes the rest on)
(show (refr (list 1.0 2.0 3.0 4.0) 2))

;; (k-relu k): k relu layers, each taking the next two members of theta
(define theta-2layer
  (list (tensor (tensor 1.0 -1.0) (tensor 0.5 0.5)) (tensor 0.0 0.1)
        (tensor (tensor 1.0 2.0)) (tensor -0.5)))
(show (((k-relu 0) (tensor 2.0 1.0)) theta-2layer))
(show (((k-relu 1) (tensor 2.0 1.0)) theta-2layer))
(show (((k-relu 2) (tensor 2.0 1.0)) theta-2layer))
(show (((k-relu 2) (tensor (tensor 2.0 1.0) (tensor -3.0 4.0))) theta-2layer))
(show (gradient-of (λ (theta) (sum (((k-relu 2) (tensor 2.0 1.0)) theta))) theta-2layer))

;; a 2-layer network learning xor
(define xs (tensor (tensor 0.0 0.0) (tensor 0.0 1.0) (tensor 1.0 0.0) (tensor 1.0 1.0)))
(define ys (tensor (tensor 0.0) (tensor 1.0) (tensor 1.0) (tensor 0.0)))
(define theta0
  (list (tensor (tensor 0.8 -0.6) (tensor -0.7 0.9) (tensor 0.3 0.4)) (tensor 0.1 0.0 -0.1)
        (tensor (tensor 0.5 0.6 -0.4)) (tensor 0.05)))
(show (((l2-loss (k-relu 2)) xs ys) theta0))
(define fitted
  (with-hypers ((revs 800) (alpha 0.05))
    (naked-gradient-descent ((l2-loss (k-relu 2)) xs ys) theta0)))
(show fitted)
(show (((l2-loss (k-relu 2)) xs ys) fitted))
(show (((k-relu 2) xs) fitted))
