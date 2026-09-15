#lang racket
;; oracle/learner/ch14-its-really-not-that-convoluted.rkt: The Little Learner, chapter 14 (It's
;; Really Not That Convoluted). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch14-its-really-not-that-convoluted.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; a one-channel signal of 5 segments
(define signal (tensor (tensor 1.0) (tensor 2.0) (tensor 4.0) (tensor 8.0) (tensor 16.0)))

;; corr: a bank of 2 filters (a difference and an average) and their biases
(define theta-c
  (list (tensor (tensor (tensor 1.0) (tensor 0.0) (tensor -1.0))
                (tensor (tensor 0.5) (tensor 0.5) (tensor 0.5)))
        (tensor 0.0 -1.0)))
(show ((corr signal) theta-c))
;; recu: corr, rectified
(show ((recu signal) theta-c))

;; k-recu: layers of recu, each taking a bank and its biases from theta
(define theta-k
  (list (tensor (tensor (tensor 1.0) (tensor 0.0) (tensor -1.0))
                (tensor (tensor 0.5) (tensor 0.5) (tensor 0.5)))
        (tensor 0.0 -1.0)
        (tensor (tensor (tensor 0.2 -0.1) (tensor 0.3 0.4) (tensor -0.5 0.1)))
        (tensor 0.25)))
(show (((k-recu 2) signal) theta-k))
(show (gradient-of (λ (theta) (sum (sum (((k-recu 2) signal) theta)))) theta-k))

;; a one-filter recu layer learning to report each segment's rise from the last
(define xs (tensor (tensor (tensor 1.0) (tensor 2.0) (tensor 4.0) (tensor 3.0) (tensor 5.0))
                   (tensor (tensor 0.0) (tensor 1.0) (tensor 1.0) (tensor 3.0) (tensor 2.0))
                   (tensor (tensor 2.0) (tensor 2.0) (tensor 5.0) (tensor 6.0) (tensor 6.0))))
(define ys (tensor (tensor (tensor 1.0) (tensor 1.0) (tensor 2.0) (tensor 0.0) (tensor 2.0))
                   (tensor (tensor 0.0) (tensor 1.0) (tensor 0.0) (tensor 2.0) (tensor 0.0))
                   (tensor (tensor 2.0) (tensor 0.0) (tensor 3.0) (tensor 1.0) (tensor 0.0))))
(define theta0 (list (tensor (tensor (tensor 0.1) (tensor 0.2) (tensor 0.3))) (tensor 0.1)))
(show (((l2-loss recu) xs ys) theta0))
(show (with-hypers ((revs 200) (alpha 0.01)) (naked-gradient-descent ((l2-loss recu) xs ys) theta0)))
