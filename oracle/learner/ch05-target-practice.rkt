#lang racket
;; oracle/learner/ch05-target-practice.rkt: The Little Learner, chapter 5 (Target Practice).
;; Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch05-target-practice.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; a quad: a*x^2 + b*x + c
(define quad-xs (tensor -1.0 0.0 1.0 2.0 3.0))
(define quad-ys (tensor 2.55 2.1 4.35 10.2 18.25))
(show ((quad 3.0) (list 4.5 2.1 7.8)))
(show ((quad quad-xs) (list 1.0 1.0 1.0)))
(show (((l2-loss quad) quad-xs quad-ys) (list 0.0 0.0 0.0)))
(show (gradient-of ((l2-loss quad) quad-xs quad-ys) (list 0.0 0.0 0.0)))
(show (with-hypers ((revs 1000) (alpha 0.001))
        (naked-gradient-descent ((l2-loss quad) quad-xs quad-ys) (list 0.0 0.0 0.0))))

;; a plane: the dot product of a weight tensor with x, plus b
(show (dot-product (tensor 1.0 2.0 3.0) (tensor 4.0 5.0 6.0)))
(show ((plane (tensor 1.0 2.0)) (list (tensor 3.0 4.0) 5.0)))
(define plane-xs
  (tensor (tensor 1.0 2.05) (tensor 1.0 3.0) (tensor 2.0 2.0)
          (tensor 2.0 3.91) (tensor 3.0 6.13) (tensor 4.0 8.09)))
(define plane-ys (tensor 13.99 15.99 18.0 22.4 30.2 37.94))
(show ((plane plane-xs) (list (tensor 1.0 1.0) 0.5)))
(show (((l2-loss plane) plane-xs plane-ys) (list (tensor 0.0 0.0) 0.0)))
(show (gradient-of ((l2-loss plane) plane-xs plane-ys) (list (tensor 0.0 0.0) 0.0)))
(show (with-hypers ((revs 1000) (alpha 0.001))
        (naked-gradient-descent ((l2-loss plane) plane-xs plane-ys) (list (tensor 0.0 0.0) 0.0))))
