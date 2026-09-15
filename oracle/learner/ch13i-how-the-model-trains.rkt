#lang racket
;; oracle/learner/ch13i-how-the-model-trains.rkt: The Little Learner, Interlude VI (How the
;; Model Trains). Our own examples on the interlude's topics, run with malt;
;; books/little-learner/ch13i-how-the-model-trains.wat must compute the same, in order.
;;
;; grid-search tries every combination of hyperparameter values, the first one listed
;; outermost, and answers the first trained theta that is good enough.

(require malt)
(require "show.rkt")

(define line-obj ((l2-loss line) (tensor 2.0 1.0 4.0 3.0) (tensor 1.8 1.2 4.2 3.3)))
(define plane-obj
  ((l2-loss plane)
   (tensor (tensor 1.0 2.05) (tensor 1.0 3.0) (tensor 2.0 2.0)
           (tensor 2.0 3.91) (tensor 3.0 6.13) (tensor 4.0 8.09))
   (tensor 13.99 15.99 18.0 22.4 30.2 37.94)))

(show (grid-search (λ (theta) (< (line-obj theta) 0.2))
                   ((revs 10 100 1000) (alpha 0.0001 0.001 0.01))
                   (naked-gradient-descent line-obj (list 0.0 0.0))))
(show (grid-search (λ (theta) (< (line-obj theta) 0.14))
                   ((revs 10 100 1000) (alpha 0.0001 0.001 0.01))
                   (naked-gradient-descent line-obj (list 0.0 0.0))))
(show (grid-search (λ (theta) (< (plane-obj theta) 1.0))
                   ((revs 100 500 1000) (alpha 0.0001 0.001))
                   (naked-gradient-descent plane-obj (list (tensor 0.0 0.0) 0.0))))
