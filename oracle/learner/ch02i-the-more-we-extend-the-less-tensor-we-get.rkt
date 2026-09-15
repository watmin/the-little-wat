#lang racket
;; oracle/learner/ch02i-the-more-we-extend-the-less-tensor-we-get.rkt: The Little Learner,
;; Interlude I (The More We Extend, the Less Tensor We Get). Our own examples on the
;; interlude's topics, run with malt;
;; books/little-learner/ch02i-the-more-we-extend-the-less-tensor-we-get.wat must compute the
;; same, in order.

(require malt)
(require "show.rkt")

;; extended arithmetic: same shapes, a scalar with a tensor, and different ranks
(show (+ (tensor 2.0 7.0) (tensor 4.0 3.0)))
(show (+ 4.0 (tensor 1.0 2.0 3.0)))
(show (+ (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)) (tensor 10.0 20.0)))
(show (+ (tensor (tensor 1.0) (tensor 2.0)) (tensor (tensor 0.5) (tensor 0.25))))
(show (* (tensor 2.0 3.0) (tensor 4.0 5.0)))
(show (- (tensor 5.0 6.0) 1.5))
(show (/ (tensor 1.0 2.0) (tensor 3.0 7.0)))

;; extended unary functions
(show (sqr (tensor 1.5 -2.0)))
(show (sqrt (tensor 4.0 2.0)))
(show (exp (tensor 0.0 1.0)))
(show (log (tensor 1.0 10.0)))

;; sum: of a rank-1 tensor a scalar; of a rank-2 tensor, each row's sum
(show (sum (tensor 10.5 12.25 -3.0)))
(show (sum (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))))
(show (sum (tensor 0.1 0.2 0.3)))
