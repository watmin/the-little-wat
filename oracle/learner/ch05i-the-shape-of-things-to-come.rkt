#lang racket
;; oracle/learner/ch05i-the-shape-of-things-to-come.rkt: The Little Learner, Interlude III
;; (The Shape of Things to Come). Our own examples on the interlude's topics, run with malt;
;; books/little-learner/ch05i-the-shape-of-things-to-come.wat must compute the same, in order.

(require malt)
(require "show.rkt")

(define t32 (tensor (tensor 1.0 2.0) (tensor 3.0 4.0) (tensor 5.0 6.0)))

;; the shapes of extended results
(show (shape t32))
(show (shape (+ (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)) (tensor 1.0 2.0))))
(show (* (tensor 1.0 2.0) t32))
(show (shape (* (tensor 1.0 2.0) t32)))
(show (sum (tensor (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)))))
(show (shape (sum (tensor (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))))))
(show (shape (sqr t32)))

;; reshape: the same entries, in another shape
(show (reshape (list 2 3) t32))
(show (reshape (list 6) t32))
(show (reshape (list 3 2) (tensor 1.0 2.0 3.0 4.0 5.0 6.0)))
(show (reshape (list 1 2 3) (tensor 1.0 2.0 3.0 4.0 5.0 6.0)))
(show (shape (reshape (list 1 2 3) (tensor 1.0 2.0 3.0 4.0 5.0 6.0))))
