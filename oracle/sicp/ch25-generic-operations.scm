;; oracle/sicp/ch25-generic-operations.scm: our own Scheme on the topic of SICP §2.5, systems with
;; generic operations -- one `add` and one `mul` over ordinary integers, rationals and complex
;; numbers, plus a TOWER of types and coercion by RAISING a value up it until two operands meet.
;; Our code and our examples, not the book's text.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))
(define (my-gcd a b) (if (= b 0) a (remainder-gcd b a)))
(define (remainder-gcd b a) (my-gcd b (remainder a b)))

;; a number is tagged: ('int n) | ('rat n d) | ('complex re im)
(define (make-int n) (list 'int n))
(define (make-rat n d)
  (let* ((g (gcd (abs n) (abs d))) (s (if (< (* n d) 0) -1 1)))
    (list 'rat (* s (quotient (abs n) g)) (quotient (abs d) g))))
(define (make-complex re im) (list 'complex re im))
(define (tag x) (car x))

(define (show-num x)
  (cond ((eq? (tag x) 'int) (number->string (cadr x)))
        ((eq? (tag x) 'rat) (string-append (number->string (cadr x)) "/" (number->string (caddr x))))
        ((eq? (tag x) 'complex)
         (string-append (number->string (cadr x)) "+" (number->string (caddr x)) "i"))
        (else "?")))

;; --- the TOWER: int -> rat -> complex. `raise` moves a value up exactly one level. ---
(define (level x) (cond ((eq? (tag x) 'int) 0) ((eq? (tag x) 'rat) 1) (else 2)))
(define (raise-1 x)
  (cond ((eq? (tag x) 'int) (make-rat (cadr x) 1))
        ((eq? (tag x) 'rat) (make-complex (/ (cadr x) (caddr x)) 0))
        (else x)))
(define (raise-to x n) (if (>= (level x) n) x (raise-to (raise-1 x) n)))

(show (show-num (make-int 7)))
(show (show-num (make-rat 6 9)))
(show (show-num (make-complex 3 4)))
(show (show-num (raise-1 (make-int 7))))
(show (show-num (raise-1 (raise-1 (make-int 7)))))
(show (level (make-int 1)))
(show (level (make-rat 1 2)))
(show (level (make-complex 1 1)))

;; --- generic add/mul: raise both operands to the higher level, then use that level's rule ---
(define (add-same a b)
  (cond ((eq? (tag a) 'int) (make-int (+ (cadr a) (cadr b))))
        ((eq? (tag a) 'rat)
         (make-rat (+ (* (cadr a) (caddr b)) (* (cadr b) (caddr a))) (* (caddr a) (caddr b))))
        (else (make-complex (+ (cadr a) (cadr b)) (+ (caddr a) (caddr b))))))
(define (mul-same a b)
  (cond ((eq? (tag a) 'int) (make-int (* (cadr a) (cadr b))))
        ((eq? (tag a) 'rat) (make-rat (* (cadr a) (cadr b)) (* (caddr a) (caddr b))))
        (else (make-complex (- (* (cadr a) (cadr b)) (* (caddr a) (caddr b)))
                            (+ (* (cadr a) (caddr b)) (* (caddr a) (cadr b)))))))

(define (generic-add a b)
  (let ((n (max (level a) (level b)))) (add-same (raise-to a n) (raise-to b n))))
(define (generic-mul a b)
  (let ((n (max (level a) (level b)))) (mul-same (raise-to a n) (raise-to b n))))

(show (show-num (generic-add (make-int 3) (make-int 4))))
(show (show-num (generic-mul (make-int 3) (make-int 4))))
(show (show-num (generic-add (make-rat 1 2) (make-rat 1 3))))
(show (show-num (generic-mul (make-rat 1 2) (make-rat 2 3))))
(show (show-num (generic-add (make-complex 1 2) (make-complex 3 4))))
(show (show-num (generic-mul (make-complex 1 2) (make-complex 3 4))))

;; the point of the tower: MIXED operands work, without a rule for every pair
(show (show-num (generic-add (make-int 1) (make-rat 1 2))))
(show (show-num (generic-add (make-rat 1 2) (make-int 1))))
(show (show-num (generic-add (make-int 1) (make-complex 3 4))))
(show (show-num (generic-mul (make-int 2) (make-rat 3 4))))

;; and the tower is what keeps the number of rules linear rather than quadratic
(show (= 3 (length '(int rat complex))))
(show (level (generic-add (make-int 1) (make-complex 0 0))))
