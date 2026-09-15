#lang racket
;; oracle/learner/ch04-slip-slidin-away.rkt: The Little Learner, chapter 4 (Slip-slidin'
;; Away). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch04-slip-slidin-away.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; gradients of functions of theta
(show (gradient-of (λ (theta) (sqr (ref theta 0))) (list 27.0)))
(show (gradient-of (λ (theta) (+ (* 3.0 (sqr (ref theta 0))) (ref theta 1))) (list 2.0 5.0)))
(show (gradient-of (λ (theta) (* (ref theta 0) (ref theta 1))) (list 3.0 4.0)))
(show (gradient-of (λ (theta) (/ (ref theta 0) (ref theta 1))) (list 1.0 4.0)))
(show (gradient-of (λ (theta) (- (ref theta 0) (ref theta 1))) (list 1.0 4.0)))
(show (gradient-of (λ (theta) (exp (ref theta 0))) (list 1.0)))
(show (gradient-of (λ (theta) (log (ref theta 0))) (list 2.0)))
(show (gradient-of (λ (theta) (sqrt (ref theta 0))) (list 9.0)))
(show (gradient-of (λ (theta) (sum (sqr (ref theta 0)))) (list (tensor 1.0 2.0 3.0))))

;; the gradient of the line's loss
(define line-xs (tensor 2.0 1.0 4.0 3.0))
(define line-ys (tensor 1.8 1.2 4.2 3.3))
(define obj ((l2-loss line) line-xs line-ys))
(show (gradient-of obj (list 0.0 0.0)))
(show (gradient-of obj (list 1.0 0.1)))

;; descending: theta minus alpha times the gradient, again and again
(define alpha 0.01)
(define step
  (λ (theta)
    (map (λ (p g) (- p (* alpha g))) theta (gradient-of obj theta))))
(show (step (list 0.0 0.0)))
(show (revise step 1000 (list 0.0 0.0)))
(show (obj (revise step 1000 (list 0.0 0.0))))
