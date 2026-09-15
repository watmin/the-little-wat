#lang racket
;; oracle/learner/ch08-the-nearer-your-destination-the-slower-you-become.rkt: The Little
;; Learner, chapter 8 (The Nearer Your Destination, the Slower You Become). Our own examples on
;; the chapter's topics, run with malt;
;; books/little-learner/ch08-the-nearer-your-destination-the-slower-you-become.wat must compute
;; the same, in order.

(require malt)
(require "show.rkt")

(define line-obj ((l2-loss line) (tensor 2.0 1.0 4.0 3.0) (tensor 1.8 1.2 4.2 3.3)))
(define plane-obj
  ((l2-loss plane)
   (tensor (tensor 1.0 2.05) (tensor 1.0 3.0) (tensor 2.0 2.0)
           (tensor 2.0 3.91) (tensor 3.0 6.13) (tensor 4.0 8.09))
   (tensor 13.99 15.99 18.0 22.4 30.2 37.94)))

;; zeroes: a tensor of zeroes of the same shape
(show (zeroes (tensor 1.5 -2.0 3.0)))
(show (zeroes (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))))

;; velocity: each revision keeps a fraction mu of the last change
(show (with-hypers ((revs 1000) (alpha 0.01) (mu 0.9)) (velocity-gradient-descent line-obj (list 0.0 0.0))))
(show (with-hypers ((revs 100) (alpha 0.01) (mu 0.5)) (velocity-gradient-descent line-obj (list 0.0 0.0))))
(show (with-hypers ((revs 1000) (alpha 0.001) (mu 0.9)) (velocity-gradient-descent plane-obj (list (tensor 0.0 0.0) 0.0))))
(show (with-hypers ((revs 1000) (alpha 0.001) (mu 0.0)) (velocity-gradient-descent plane-obj (list (tensor 0.0 0.0) 0.0))))
