#lang racket
;; oracle/learner/ch07-the-crazy-ates.rkt: The Little Learner, chapter 7 (The Crazy "ates").
;; Our own examples on the chapter's topics, run with malt;
;; books/little-learner/ch07-the-crazy-ates.wat must compute the same, in order.
;;
;; malt's gradient-descent is built from three functions: inflate each parameter into an
;; accompanied one, update an accompanied parameter with its gradient, and deflate it back.

(require malt)
(require "show.rkt")

(define line-xs (tensor 2.0 1.0 4.0 3.0))
(define line-ys (tensor 1.8 1.2 4.2 3.3))
(define obj ((l2-loss line) line-xs line-ys))

;; lonely: a parameter accompanied by nothing, in a list of one
(define lonely-i (λ (p) (list p)))
(define lonely-d (λ (pa) (ref pa 0)))
(define lonely-u (λ (pa g) (list (- (ref pa 0) (* alpha g)))))
(define lonely-gradient-descent (gradient-descent lonely-i lonely-d lonely-u))

;; counted: a parameter accompanied by how many times it has been revised
(define counted-i (λ (p) (list p 0.0)))
(define counted-d (λ (pa) (ref pa 0)))
(define counted-u (λ (pa g) (list (- (ref pa 0) (* alpha g)) (+ (ref pa 1) 1.0))))
(define counted-gradient-descent (gradient-descent counted-i counted-d counted-u))

(show (with-hypers ((revs 1000) (alpha 0.01)) (naked-gradient-descent obj (list 0.0 0.0))))
(show (with-hypers ((revs 1000) (alpha 0.01)) (lonely-gradient-descent obj (list 0.0 0.0))))
(show (with-hypers ((revs 1000) (alpha 0.01)) (counted-gradient-descent obj (list 0.0 0.0))))
(show (with-hypers ((revs 3) (alpha 0.01)) (lonely-gradient-descent obj (list 5.0 -5.0))))

;; the pieces themselves
(show (lonely-i 3.0))
;; (outside a with-hypers, malt's alpha is the symbol unset-hyper-alpha, and the update fails
;; far away, in vector-map's contract; the wat side can't be written without its Hypers)
(show (with-hypers ((alpha 0.01)) (counted-u (list 2.0 7.0) 10.0)))
(show (with-hypers ((alpha 0.5)) (lonely-u (list 2.0) 10.0)))
