#lang racket
;; oracle/learner/ch06-an-apple-a-day.rkt: The Little Learner, chapter 6 (An Apple a Day).
;; Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch06-an-apple-a-day.wat must compute the same, in order.
;;
;; Stochastic descent samples a batch of rows at every revision with Racket's (random n).
;; Before each sampled run, record-draws prints the draws malt is about to make
;; (oracle/learner/NAME.draws), and the wat side replays them.

(require malt)
(require "show.rkt")

(random-seed 7)

;; samples: batch-size random indices below n (malt conses them, so they come out reversed)
(record-draws 6 5)
(show (samples 6 5))

;; trefs: the rows at a list of indices
(show (trefs (tensor 10.0 20.0 30.0) (list 2 0 2)))
(show (trefs (tensor (tensor 1.0 2.0) (tensor 3.0 4.0) (tensor 5.0 6.0)) (list 1 1 0)))

;; stochastic gradient descent of a line: each revision's loss is over 4 sampled rows
(define line-xs (tensor 2.0 1.0 4.0 3.0))
(define line-ys (tensor 1.8 1.2 4.2 3.3))
(record-draws 4 4000)   ; 1000 revisions of 4 (a literal: malt's * makes a dual)
(show (with-hypers ((revs 1000) (alpha 0.01) (batch-size 4))
        (naked-gradient-descent (sampling-obj (l2-loss line) line-xs line-ys) (list 0.0 0.0))))

;; and of a quad, 3 rows of 5 at a time
(define quad-xs (tensor -1.0 0.0 1.0 2.0 3.0))
(define quad-ys (tensor 2.55 2.1 4.35 10.2 18.25))
(record-draws 5 2400)   ; 800 revisions of 3
(show (with-hypers ((revs 800) (alpha 0.001) (batch-size 3))
        (naked-gradient-descent (sampling-obj (l2-loss quad) quad-xs quad-ys) (list 0.0 0.0 0.0))))
