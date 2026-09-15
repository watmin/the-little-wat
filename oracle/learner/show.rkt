#lang racket
;; oracle/learner/show.rkt: print a malt value in the canonical form the wat port checks
;; against. Duals print as their real part; every number is made a flonum
;; (exact->inexact) and printed by Racket's number->string, the shortest round-trip digits;
;; a tensor (a vector) prints as (tensor ...), a list as (list ...). Each value goes on its
;; own line after "=> ", so tools/learner-oracle.sh can ignore anything else malt prints.

(require malt)
(provide show)

(define canon
  (λ (y)
    (cond
      ((dual? y) (canon (ρ y)))
      ((number? y) (number->string (exact->inexact y)))
      ((vector? y) (string-append "(tensor" (apply string-append (map (λ (e) (string-append " " (canon e))) (vector->list y))) ")"))
      ((list? y) (string-append "(list" (apply string-append (map (λ (e) (string-append " " (canon e))) y)) ")"))
      (else (error 'show "cannot show ~a" y)))))

(define show
  (λ (y)
    (printf "=> ~a~%" (canon y))))
