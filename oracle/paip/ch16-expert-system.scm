;; oracle/paip/ch16-expert-system.scm: our own Scheme on the topic of PAIP chapter 16, expert
;; systems -- CERTAINTY FACTORS and the arithmetic for combining evidence that neither proves nor
;; disproves. Our code and our examples; Norvig's own code is not read or copied.
;;
;; Certainty factors run from -100 (certainly false) to 100 (certainly true), scaled by 100 so the
;; arithmetic is exact integers and the two implementations cannot disagree about rounding.
;;
;; The chapter's substance is that the combining rules are NOT ordinary logic: `and` is a minimum,
;; `or` is a maximum, and combining two pieces of evidence for the same conclusion is a rule that
;; is deliberately neither addition nor probability. The rules' awkward cases -- evidence that
;; contradicts, and evidence below the cutoff -- are what the tests below press.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define true-cf 100) (define false-cf -100) (define cutoff 20)

(define (cf-and a b) (min a b))
(define (cf-or a b) (max a b))

;; combining two certainty factors for the SAME conclusion
(define (cf-combine a b)
  (cond ((and (> a 0) (> b 0)) (- (+ a b) (quotient (* a b) 100)))
        ((and (< a 0) (< b 0)) (+ (+ a b) (quotient (* a b) 100)))
        (else (let ((d (- 100 (min (abs a) (abs b)))))
                (if (= d 0) 0 (quotient (* (+ a b) 100) d))))))

(define (believable? cf) (> cf cutoff))

(show (cf-and 70 50))
(show (cf-or 70 50))
(show (cf-and -30 50))
(show (cf-or -30 50))

;; two pieces of supporting evidence reinforce, but never reach certainty from below it
(show (cf-combine 50 50))
(show (cf-combine 50 80))
(show (cf-combine 90 90))
(show (< (cf-combine 90 90) 100))
;; two pieces of opposing evidence reinforce downward the same way
(show (cf-combine -50 -50))
;; CONTRADICTORY evidence cancels toward the middle -- this is the rule that is not ordinary logic
(show (cf-combine 70 -70))
(show (cf-combine 80 -20))
(show (cf-combine 20 -80))
;; certainty absorbs everything
(show (cf-combine 100 -50))
(show (cf-combine 100 50))

;; --- a two-rule chain: the premise's certainty limits the conclusion's ---
;; rule: if A (cf 60) then B with strength 80  =>  B gets 60*80/100
(define (apply-rule premise strength) (quotient (* premise strength) 100))
(show (apply-rule 60 80))
(show (apply-rule 100 80))
(show (apply-rule 20 80))
;; a premise below the cutoff should not fire at all
(show (believable? (apply-rule 20 80)))
(show (believable? (apply-rule 60 80)))
;; and two rules concluding the same thing combine
(show (cf-combine (apply-rule 60 80) (apply-rule 50 60)))
