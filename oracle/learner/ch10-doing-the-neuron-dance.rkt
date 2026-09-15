#lang racket
;; oracle/learner/ch10-doing-the-neuron-dance.rkt: The Little Learner, chapter 10 (Doing the
;; Neuron Dance). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch10-doing-the-neuron-dance.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; a layer's theta: a weight row per neuron, and a bias per neuron
(define theta2 (list (tensor (tensor 3.0 4.0) (tensor 1.0 -2.0)) (tensor 0.5 -1.5)))

;; linear: each neuron's weights dotted with the input, plus its bias
(show ((linear (tensor 2.0 1.0)) theta2))
;; relu: the linear result, rectified
(show ((relu (tensor 2.0 1.0)) theta2))
(show ((relu (tensor -2.0 1.0)) theta2))
;; a batch of inputs, one row each
(show ((relu (tensor (tensor 2.0 1.0) (tensor -1.0 0.5))) theta2))
;; the gradient of a neuron's summed output
(show (gradient-of (λ (theta) (sum ((relu (tensor 2.0 1.0)) theta))) theta2))
(show (gradient-of (λ (theta) (sum ((relu (tensor (tensor 2.0 1.0) (tensor -1.0 0.5))) theta))) theta2))

;; one neuron learning to fire for the first input and for both
(define xs (tensor (tensor 1.0 0.0) (tensor 0.0 1.0) (tensor 1.0 1.0)))
(define ys (tensor (tensor 1.0) (tensor 0.0) (tensor 1.0)))
(define theta0 (list (tensor (tensor 0.5 0.5)) (tensor 0.1)))
(show (((l2-loss relu) xs ys) theta0))
(show (with-hypers ((revs 500) (alpha 0.01)) (naked-gradient-descent ((l2-loss relu) xs ys) theta0)))
(show (((l2-loss relu) xs ys)
       (with-hypers ((revs 500) (alpha 0.01)) (naked-gradient-descent ((l2-loss relu) xs ys) theta0))))
