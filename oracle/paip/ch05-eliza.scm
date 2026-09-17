;; oracle/paip/ch05-eliza.scm: our own Scheme on the topic of PAIP chapter 5, ELIZA -- pattern
;; matching with SEGMENT VARIABLES, and rules that turn an input into a reply by substituting what
;; was matched. Our code and our examples; Norvig's own code is not read or copied.
;;
;; The chapter's real content is the matcher, not the psychiatry. A single variable ?x matches one
;; word; a SEGMENT variable ?*x matches zero or more, and matching one requires trying every split
;; and BACKTRACKING when the rest of the pattern fails. That is the part worth checking, so the
;; tests below drive the matcher directly as well as through the rules.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define (single-var? x) (and (symbol? x) (let ((s (symbol->string x)))
                                           (and (> (string-length s) 1) (char=? #\? (string-ref s 0))
                                                (not (char=? #\* (string-ref s 1)))))))
(define (segment-var? x) (and (symbol? x) (let ((s (symbol->string x)))
                                            (and (> (string-length s) 2) (char=? #\? (string-ref s 0))
                                                 (char=? #\* (string-ref s 1))))))
(define (seg-name x) (string->symbol (substring (symbol->string x) 2)))
(define (var-name x) (string->symbol (substring (symbol->string x) 1)))

;; bindings: an alist of name -> list of words. 'fail is a distinct answer from '() (no bindings).
(define (bind name val b) (cons (cons name val) b))
(define (lookup name b) (let ((h (assq name b))) (if h (cdr h) #f)))

(define (pat-match pattern input b)
  (cond ((eq? b 'fail) 'fail)
        ((null? pattern) (if (null? input) b 'fail))
        ((segment-var? (car pattern)) (segment-match pattern input b 0))
        ((single-var? (car pattern))
         (if (null? input) 'fail
             (let* ((n (var-name (car pattern))) (old (lookup n b)))
               (if old
                   (if (equal? old (list (car input))) (pat-match (cdr pattern) (cdr input) b) 'fail)
                   (pat-match (cdr pattern) (cdr input) (bind n (list (car input)) b))))))
        ((and (pair? input) (eq? (car pattern) (car input))) (pat-match (cdr pattern) (cdr input) b))
        (else 'fail)))

;; try every split: the segment takes the first `start` words, the rest of the pattern takes on
(define (segment-match pattern input b start)
  (if (> start (length input)) 'fail
      (let* ((n (seg-name (car pattern)))
             (seg (list-head input start))
             (rest (list-tail input start))
             (old (lookup n b)))
        (if (and old (not (equal? old seg)))
            (segment-match pattern input b (+ start 1))
            (let ((r (pat-match (cdr pattern) rest (if old b (bind n seg b)))))
              (if (eq? r 'fail) (segment-match pattern input b (+ start 1)) r))))))

(define (list-head l n) (if (= n 0) '() (cons (car l) (list-head (cdr l) (- n 1)))))

;; --- the matcher, directly ---
(show (not (eq? 'fail (pat-match '(i need a ?x) '(i need a vacation) '()))))
(show (lookup 'x (pat-match '(i need a ?x) '(i need a vacation) '())))
(show (eq? 'fail (pat-match '(i need a ?x) '(i really need a vacation) '())))
(show (lookup 'x (pat-match '(?*x need a ?y) '(i really need a vacation) '())))
(show (lookup 'y (pat-match '(?*x need a ?y) '(i really need a vacation) '())))
;; a segment matching nothing at all
(show (lookup 'x (pat-match '(?*x need a ?y) '(need a break) '())))
;; two segments: the first is as SHORT as possible, because splits are tried in order
(show (lookup 'x (pat-match '(?*x is ?*y) '(a b is c d) '())))
(show (lookup 'y (pat-match '(?*x is ?*y) '(a b is c d) '())))
;; the same variable twice must match the same words
(show (eq? 'fail (pat-match '(?x and ?x) '(cats and dogs) '())))
(show (lookup 'x (pat-match '(?x and ?x) '(cats and cats) '())))
(show (eq? 'fail (pat-match '(hello) '(goodbye) '())))
(show (not (eq? 'fail (pat-match '() '() '()))))

;; --- the rules, and a reply ---
(define rules
  '(((?*x i need ?*y) (why do you need ?*y ?) (would it really help to get ?*y ?))
    ((?*x i am ?*y) (how long have you been ?*y ?))
    ((?*x hello ?*y) (hello there what brings you here ?))
    ((?*x) (please go on))))

(define (substitute-in template b)
  (cond ((null? template) '())
        ((segment-var? (car template))
         (let ((v (lookup (seg-name (car template)) b)))
           (append (if v v (list (car template))) (substitute-in (cdr template) b))))
        ((single-var? (car template))
         (let ((v (lookup (var-name (car template)) b)))
           (append (if v v (list (car template))) (substitute-in (cdr template) b))))
        (else (cons (car template) (substitute-in (cdr template) b)))))

(define (eliza input)
  (let loop ((rs rules))
    (if (null? rs) '(i am not sure what you mean)
        (let ((b (pat-match (car (car rs)) input '())))
          (if (eq? b 'fail) (loop (cdr rs)) (substitute-in (cadr (car rs)) b))))))

(show (eliza '(i need a vacation)))
(show (eliza '(well i need a long holiday)))
(show (eliza '(i am feeling sad)))
(show (eliza '(hello there)))
(show (eliza '(the weather is fine)))
