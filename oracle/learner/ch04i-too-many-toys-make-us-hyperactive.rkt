#lang racket
;; oracle/learner/ch04i-too-many-toys-make-us-hyperactive.rkt: The Little Learner, Interlude II
;; (Too Many Toys Make Us Hyperactive). Our own examples on the interlude's topics, run with
;; malt; books/little-learner/ch04i-too-many-toys-make-us-hyperactive.wat must compute the
;; same, in order. malt's hyperparameters are bound dynamically, with with-hypers.

(require malt)
(require "show.rkt")

(define line-xs (tensor 2.0 1.0 4.0 3.0))
(define line-ys (tensor 1.8 1.2 4.2 3.3))
(define obj ((l2-loss line) line-xs line-ys))

(show (with-hypers ((revs 1000) (alpha 0.01)) (naked-gradient-descent obj (list 0.0 0.0))))
(show (with-hypers ((revs 100) (alpha 0.001)) (naked-gradient-descent obj (list 0.0 0.0))))
(show (with-hypers ((revs 10) (alpha 0.05)) (naked-gradient-descent obj (list 1.0 1.0))))
(show (with-hypers ((revs 0) (alpha 0.01)) (naked-gradient-descent obj (list 3.0 4.0))))

;; malt's own test: descending (30 - x)^2 from 3
(show (with-hypers ((revs 400) (alpha 0.01))
        (naked-gradient-descent (λ (theta) (sqr (- 30.0 (ref theta 0)))) (list 3.0))))

;; nested bindings: the inner one wins inside it, the outer one is back after it
(show (with-hypers ((revs 5) (alpha 0.01))
        (list (naked-gradient-descent obj (list 0.0 0.0))
              (with-hypers ((alpha 0.02)) (naked-gradient-descent obj (list 0.0 0.0)))
              (naked-gradient-descent obj (list 0.0 0.0)))))
