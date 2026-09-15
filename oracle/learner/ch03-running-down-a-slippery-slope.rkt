#lang racket
;; oracle/learner/ch03-running-down-a-slippery-slope.rkt: The Little Learner, chapter 3
;; (Running Down a Slippery Slope). Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch03-running-down-a-slippery-slope.wat must compute the same, in order.

(require malt)
(require "show.rkt")

(define line-xs (tensor 2.0 1.0 4.0 3.0))
(define line-ys (tensor 1.8 1.2 4.2 3.3))

;; the loss of a line at theta: the sum of the squared differences
(show ((line line-xs) (list 0.0 0.0)))
(show (- line-ys ((line line-xs) (list 0.0 0.0))))
(show (sqr (- line-ys ((line line-xs) (list 0.0 0.0)))))
(show (((l2-loss line) line-xs line-ys) (list 0.0 0.0)))
(show (((l2-loss line) line-xs line-ys) (list 0.0099 0.0)))
(show (((l2-loss line) line-xs line-ys) (list 1.0 0.0)))
(show (((l2-loss line) line-xs line-ys) (list 1.0 0.1)))

;; the rate of change of the loss, by hand: nudge w and see how the loss moves
(define obj ((l2-loss line) line-xs line-ys))
(show (- (obj (list 0.0099 0.0)) (obj (list 0.0 0.0))))
(show (/ (- (obj (list 0.0099 0.0)) (obj (list 0.0 0.0))) 0.0099))

;; revise: apply a function to theta revs times
(show (revise (λ (theta) (map (λ (p) (+ p 0.5)) theta)) 4 (list 1.0 2.0)))
(show (revise (λ (theta) (map (λ (p) (* p 0.5)) theta)) 3 (list 8.0 -1.0)))
