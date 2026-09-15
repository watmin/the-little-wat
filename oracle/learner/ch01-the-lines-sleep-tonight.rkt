#lang racket
;; oracle/learner/ch01-the-lines-sleep-tonight.rkt: The Little Learner, chapter 1 (The Lines
;; Sleep Tonight). Our own examples on the chapter's topics, run with malt (the book's
;; library); tools/learner-oracle.sh keeps the shown values, and
;; books/little-learner/ch01-the-lines-sleep-tonight.wat must compute the same, in order.

(require malt)
(require "show.rkt")

;; a line is a function of x that, given parameters theta = (w b), gives w*x + b
(show ((line 8.0) (list 4.0 6.0)))
(show ((line 2.0) (list 0.5 1.5)))
(show ((line -3.0) (list 1.0 0.0)))
(show ((line 0.0) (list 7.0 -2.5)))
(show ((line 0.1) (list 0.2 0.3)))
(show ((line 1e10) (list 1e-10 1.0)))

;; the same x with different parameters: a family of lines
(define line-at-5 (line 5.0))
(show (line-at-5 (list 1.0 0.0)))
(show (line-at-5 (list 2.0 1.0)))
(show (line-at-5 (list -0.5 3.25)))

;; the arithmetic under it
(show (+ 0.1 0.2))
(show (* 3.0 (+ 1.0 2.0)))
(show (- 1.0 3.5))
(show (/ 1.0 3.0))
