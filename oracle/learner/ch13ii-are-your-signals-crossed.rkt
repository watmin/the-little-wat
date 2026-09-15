#lang racket
;; oracle/learner/ch13ii-are-your-signals-crossed.rkt: The Little Learner, Interlude VII (Are
;; Your Signals Crossed?). Our own examples on the interlude's topics, run with malt;
;; books/little-learner/ch13ii-are-your-signals-crossed.wat must compute the same, in order.
;;
;; correlate slides each filter of a bank along a signal: at every position, the sum of the
;; filter's rows dotted with the signal's rows it overlaps (off the ends counts nothing).

(require malt)
(require "show.rkt")

;; malt's own example: a signal of 6 two-channel rows and a bank of 4 filters of 3 rows
(define signal (tensor (tensor 1.0 2.0) (tensor 3.0 4.0) (tensor 5.0 6.0)
                       (tensor 7.0 8.0) (tensor 9.0 10.0) (tensor 11.0 12.0)))
(define bank (tensor (tensor (tensor 1.0 2.0) (tensor 3.0 4.0) (tensor 5.0 6.0))
                     (tensor (tensor 7.0 8.0) (tensor 9.0 10.0) (tensor 11.0 12.0))
                     (tensor (tensor 13.0 14.0) (tensor 15.0 16.0) (tensor 17.0 18.0))
                     (tensor (tensor 19.0 20.0) (tensor 21.0 22.0) (tensor 23.0 24.0))))
(show (correlate bank signal))

;; one filter, (1 0 -1), on a one-channel signal: a difference detector
(show (correlate (tensor (tensor (tensor 1.0) (tensor 0.0) (tensor -1.0)))
                 (tensor (tensor 1.0) (tensor 2.0) (tensor 4.0) (tensor 8.0) (tensor 16.0))))
;; a smoothing filter
(show (correlate (tensor (tensor (tensor 0.25) (tensor 0.5) (tensor 0.25)))
                 (tensor (tensor 0.1) (tensor 0.9) (tensor 0.3) (tensor 0.7))))

;; gradients through correlate, for the bank and for the signal
(show (gradient-of (λ (theta) (sum (sum (correlate (ref theta 0) signal)))) (list bank)))
(show (gradient-of (λ (theta) (sum (sum (correlate bank (ref theta 0))))) (list signal)))
