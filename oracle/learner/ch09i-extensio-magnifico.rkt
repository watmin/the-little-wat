#lang racket
;; oracle/learner/ch09i-extensio-magnifico.rkt: The Little Learner, Interlude V (Extensio
;; Magnifico!). Our own examples on the interlude's topics, run with malt;
;; books/little-learner/ch09i-extensio-magnifico.wat must compute the same, in order.

(require malt)
(require "show.rkt")

(define t2 (tensor (tensor 3.0 4.0 5.0) (tensor 7.0 8.0 9.0)))
(define t1 (tensor 4.0 5.0 6.0))

;; *-2-1: each row of a rank-2 tensor times a rank-1 tensor, at every level of the first
(show (*-2-1 t2 t1))
(show (*-2-1 t2 (tensor (tensor 4.0 5.0 6.0) (tensor 4.0 5.0 6.0) (tensor 4.0 5.0 6.0))))
(show (dot-product-2-1 t2 t1))

;; ext1 and ext2 at ranks above 0
(define sum-of-rows (ext1 sum-1 1))
(show (sum-of-rows (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))))
(show (sum-of-rows (tensor (tensor (tensor 1.0 2.0)) (tensor (tensor 3.0 4.0)))))
(define dot-1-1 (ext2 (λ (a b) (sum-1 (* a b))) 1 1))
(show (dot-1-1 (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)) (tensor 5.0 6.0)))
(show (dot-1-1 (tensor 1.0 2.0) (tensor (tensor 3.0 4.0) (tensor 5.0 6.0))))

;; rectify: below 0 becomes 0
(show (rectify (tensor -1.0 0.5 -0.0 2.0)))
(show (rectify (tensor (tensor -3.0 3.0) (tensor 0.0 -0.1))))

;; gradients through them
(show (gradient-of (λ (theta) (sum (rectify (ref theta 0)))) (list (tensor -1.0 2.0 3.0))))
(show (gradient-of (λ (theta) (dot-product-2-1 (ref theta 0) (ref theta 1)))
                   (list (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)) (tensor 5.0 6.0))))
(show (gradient-of (λ (theta) (sum (*-2-1 (ref theta 0) t1))) (list t2)))
