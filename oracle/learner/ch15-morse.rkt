#lang racket
;; oracle/learner/ch15-morse.rkt: The Little Learner, chapter 15 (the Morse chapter). Our own
;; examples on the chapter's topics, run with malt; books/little-learner/ch15-morse.wat must
;; compute the same, in order.
;;
;; malt's Morse networks (malt/examples/morse.rkt) are four fcn blocks, or four residual
;; blocks, then signal-avg, trained with adam for 20000 revisions from a random theta. malt's
;; learner representation can't run that (malt's README asks for its flat or nested tensors),
;; and the wat port runs well over 100 times slower than malt (ch 13), so here the same blocks
;; are built small, with a fixed patterned theta, and checked without training.

(require malt)
(require (prefix-in r: racket/base))
(require "show.rkt")

;; malt's blocks, from malt/examples/morse.rkt
(define fcn-block
  (λ (b m d)
    (block (k-recu 2) (list (list b m d) (list b) (list b m b) (list b)))))
(define signal-avg-block (block signal-avg (list)))
(define skip
  (λ (f j)
    (λ (t)
      (λ (theta)
        (+ ((f t) theta) (correlate (ref theta j) t))))))
(define skip-block
  (λ (ba d b)
    (let ((shape-list (block-ls ba)))
      (block (skip (block-fn ba) (len shape-list))
        (append shape-list (list (list b 1 d)))))))
(define residual-block (λ (b m d) (skip-block (fcn-block b m d) d b)))

;; a fixed theta for a list of shapes: entry (i j k ...) of the n-th member is
;; ((7i + 3j + k + n + 1) mod 11 - 5) / 10, the index padded with 0s
(define pattern
  (λ (n idx)
    (let ((i (if (r:> (length idx) 0) (list-ref idx 0) 0))
          (j (if (r:> (length idx) 1) (list-ref idx 1) 0))
          (k (if (r:> (length idx) 2) (list-ref idx 2) 0)))
      (exact->inexact (r:/ (r:- (modulo (r:+ (r:* 7 i) (r:* 3 j) k n 1) 11) 5) 10)))))
(define patterned-theta
  (λ (shapes)
    (for/list ((s shapes) (n (in-naturals)))
      (build-tensor s (λ (idx) (pattern n idx))))))

;; signal-avg: the average of a signal's segments, channel by channel
(show ((signal-avg (tensor (tensor 1.0 2.0) (tensor 3.0 4.0) (tensor 5.0 9.0))) (list)))

(define signal (tensor (tensor 0.0) (tensor 1.0) (tensor 1.0) (tensor 0.0) (tensor 1.0) (tensor 1.0)))

;; a small fcn network: two fcn blocks (2 filters, then 3) and signal-avg
(define tiny-fcn (stack-blocks (list (fcn-block 2 3 1) (fcn-block 3 3 2) signal-avg-block)))
(show (block-ls tiny-fcn))
(define theta-fcn (patterned-theta (block-ls tiny-fcn)))
(show (ref theta-fcn 2))
(show (((block-fn tiny-fcn) signal) theta-fcn))
(show (gradient-of (λ (theta) (sum (((block-fn tiny-fcn) signal) theta))) theta-fcn))

;; a small residual network: the same, each block with a skip correlation added
(define tiny-residual (stack-blocks (list (residual-block 2 3 1) (residual-block 3 3 2) signal-avg-block)))
(show (block-ls tiny-residual))
(define theta-res (patterned-theta (block-ls tiny-residual)))
(show (((block-fn tiny-residual) signal) theta-res))
(show (gradient-of (λ (theta) (sum (((block-fn tiny-residual) signal) theta))) theta-res))
