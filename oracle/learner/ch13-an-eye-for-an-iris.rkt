#lang racket
;; oracle/learner/ch13-an-eye-for-an-iris.rkt: The Little Learner, chapter 13 (An Eye for an
;; Iris). Our own examples on the chapter's topics, and the book's own training run, run with
;; malt; books/little-learner/ch13-an-eye-for-an-iris.wat must compute the same, in order.
;;
;; The Iris data and the book's printed initial theta come from malt's examples
;; (malt/examples/iris, MIT); they are written out as data (NAME.data) for the wat side, and
;; the draws of the book's sampled run are recorded (NAME.draws).

(require malt)
(require malt/examples/iris)
(require "show.rkt")

(show-data iris-train-xs)
(show-data iris-train-ys)
(show-data iris-test-xs)
(show-data iris-test-ys)
(show-data tll-iris-initial-theta)

;; the network: two dense relu blocks, 4 inputs to 8 neurons to 3
(define dense-block (λ (n m) (block relu (list (list m n) (list m)))))
(define iris-network (stack-blocks (list (dense-block 4 8) (dense-block 8 3))))
(define iris-classifier (block-fn iris-network))
(show (block-ls iris-network))

;; argmax: the index of the largest (from the last down, so a tie goes to the later one);
;; =-1: 1.0 where two tensors agree, 0.0 where they don't
(show (argmax (tensor 0.1 0.7 0.2)))
(show (argmax (tensor (tensor 0.5 0.5 0.1) (tensor 0.0 0.2 0.3))))
(show (=-1 (tensor 1.0 2.0 3.0) (tensor 1.0 0.0 3.0)))

;; the untrained classifier on the test set, and its accuracy
(show ((iris-classifier iris-test-xs) tll-iris-initial-theta))
(show (accuracy (model iris-classifier tll-iris-initial-theta) iris-test-xs iris-test-ys))

;; the book's run: 2000 revisions, each over 8 sampled training rows
(random-seed 11)
(record-draws (tlen iris-train-xs) 16000)   ; 2000 revisions of 8 (a literal: malt's * makes a dual)
(define tll-iris-theta
  (with-hypers ((revs 2000) (alpha 0.0002) (batch-size 8))
    (naked-gradient-descent
      (sampling-obj (l2-loss iris-classifier) iris-train-xs iris-train-ys)
      tll-iris-initial-theta)))
(show tll-iris-theta)
(show (accuracy (model iris-classifier tll-iris-theta) iris-test-xs iris-test-ys))
