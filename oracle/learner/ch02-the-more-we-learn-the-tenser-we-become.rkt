#lang racket
;; oracle/learner/ch02-the-more-we-learn-the-tenser-we-become.rkt: The Little Learner,
;; chapter 2 (The More We Learn, the Tenser We Become). Our own examples on the chapter's
;; topics, run with malt; books/little-learner/ch02-the-more-we-learn-the-tenser-we-become.wat
;; must compute the same, in order.

(require malt)
(require "show.rkt")

;; tensors, their ranks, shapes, lengths and entries
(show (tensor 1.0 2.0 3.0))
(show (rank 5.0))
(show (rank (tensor 1.0 2.0)))
(show (rank (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))))
(show (shape 7.0))
(show (shape (tensor (tensor 1.0 2.0 3.0) (tensor 4.0 5.0 6.0))))
(show (shape (tensor (tensor (tensor 1.0) (tensor 2.0)) (tensor (tensor 3.0) (tensor 4.0)))))
(show (tlen (tensor 1.0 2.0 3.0)))
(show (tref (tensor 5.0 6.0 7.0) 1))
(show (tref (tensor (tensor 1.0 2.0) (tensor 3.0 4.0)) 1))

;; rank by recursion, the book's way: count the trefs down to a scalar
(define ranked
  (λ (t a)
    (cond
      ((scalar? t) a)
      (else (ranked (tref t 0) (add1 a))))))
(show (ranked (tensor (tensor (tensor 8.0))) 0))
(show (ranked 9.0 0))

;; a line of a tensor of xs gives a tensor of ys
(show ((line (tensor 2.0 1.0 4.0 3.0)) (list 0.5 1.0)))
(show ((line (tensor (tensor 1.0 2.0) (tensor 3.0 4.0))) (list 2.0 -1.0)))
(show ((line (tensor 0.1 0.2 0.3)) (list 3.0 0.7)))
