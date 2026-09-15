#lang racket
;; oracle/learner/show.rkt: print a malt value in the canonical form the wat port checks
;; against. Duals print as their real part; every number is made a flonum
;; (exact->inexact) and printed by Racket's number->string, the shortest round-trip digits;
;; a tensor (a vector) prints as (tensor ...), a list as (list ...). Each value goes on its
;; own line after "=> ", so tools/learner-oracle.sh can ignore anything else malt prints.

(require malt)
(provide show record-draws)

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

;; record-draws: print the next count draws of (random n) that malt is about to make, without
;; making them. Racket's generator is copied, and the copy draws them; the real one then
;; draws the same numbers when malt asks. One line of numbers after "draws=> ", in draw
;; order, which tools/learner-oracle.sh keeps in NAME.draws for the wat side to replay.
(define record-draws
  (λ (n count)
    (let ((copy (vector->pseudo-random-generator
                  (pseudo-random-generator->vector (current-pseudo-random-generator)))))
      (printf "draws=> ~a~%"
        (string-join (map number->string
                          (parameterize ((current-pseudo-random-generator copy))
                            (for/list ((i count)) (random n))))
                     " ")))))
