#lang racket
;; oracle/learner/ch12-rock-around-the-block.rkt: The Little Learner, chapter 12 (Rock Around
;; the Block). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch12-rock-around-the-block.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; a block: a function of t and theta, and the shapes of the theta it takes
(define dense (λ (m n) (block relu (list (list m n) (list m)))))
(show (block-ls (dense 3 2)))

;; stacking: the first block's output is the second's input, and theta is split between them
(define net (stack-blocks (list (dense 3 2) (dense 1 3))))
(show (block-ls net))
(define net3 (stack-blocks (list (dense 3 2) (dense 2 3) (dense 1 2))))
(show (block-ls net3))

(define theta0
  (list (tensor (tensor 0.8 -0.6) (tensor -0.7 0.9) (tensor 0.3 0.4)) (tensor 0.1 0.0 -0.1)
        (tensor (tensor 0.5 0.6 -0.4)) (tensor 0.05)))
(show (((block-fn net) (tensor 2.0 1.0)) theta0))
(define xs (tensor (tensor 0.0 0.0) (tensor 0.0 1.0) (tensor 1.0 0.0) (tensor 1.0 1.0)))
(define ys (tensor (tensor 0.0) (tensor 1.0) (tensor 1.0) (tensor 0.0)))
(show (gradient-of (λ (theta) (sum (((block-fn net) xs) theta))) theta0))

(define theta3
  (list (tensor (tensor 0.8 -0.6) (tensor -0.7 0.9) (tensor 0.3 0.4)) (tensor 0.1 0.0 -0.1)
        (tensor (tensor 0.5 0.6 -0.4) (tensor -0.2 0.3 0.9)) (tensor 0.0 0.2)
        (tensor (tensor 1.1 -0.5)) (tensor 0.3)))
(show (((block-fn net3) (tensor 1.0 -1.0)) theta3))
(show (((block-fn net3) xs) theta3))

;; the stacked net trains exactly as (k-relu 2) does
(show (with-hypers ((revs 800) (alpha 0.05))
        (naked-gradient-descent ((l2-loss (block-fn net)) xs ys) theta0)))
