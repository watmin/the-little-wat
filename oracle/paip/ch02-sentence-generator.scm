;; oracle/paip/ch02-sentence-generator.scm: our own Scheme on the topic of PAIP chapter 2, a
;; grammar-driven sentence generator -- a rule-based program whose GRAMMAR IS DATA, so that adding
;; a rule adds a sentence without touching the generator. Our code and our examples; Norvig's own
;; code is not read or copied.
;;
;; The chapter does two things with the grammar: GENERATE a random sentence from it, and
;; GENERATE-ALL, enumerating the whole (finite) language. The second needs no randomness and is
;; the better test of the grammar; the first needs a random number, and wat has none (F-036), so
;; both this oracle and the wat port drive the same hand-written linear congruential generator.
;; That keeps the two comparable AND makes the missing primitive visible rather than worked
;; around quietly.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; --- the LCG that stands in for a random number generator ---
(define (lcg-next seed) (modulo (+ (* 1103515245 seed) 12345) 2147483648))
(define (lcg-pick seed n) (modulo (quotient seed 65536) n))

;; --- the grammar, as DATA ---
(define grammar
  '((sentence (noun-phrase verb-phrase))
    (noun-phrase (Article Noun))
    (verb-phrase (Verb noun-phrase))
    (Article (the) (a))
    (Noun (man) (ball) (woman) (table))
    (Verb (hit) (took) (saw) (liked))))

(define (rules-for cat) (let ((h (assq cat grammar))) (if h (cdr h) '())))
(define (category? x) (not (null? (rules-for x))))

;; generate one sentence, threading the seed so the result is reproducible
(define (generate x seed)
  (cond ((category? x)
         (let* ((rs (rules-for x))
                (s1 (lcg-next seed))
                (choice (list-ref rs (lcg-pick s1 (length rs)))))
           (generate-list choice s1)))
        (else (cons (list x) seed))))

(define (generate-list xs seed)
  (if (null? xs) (cons '() seed)
      (let* ((r1 (generate (car xs) seed))
             (r2 (generate-list (cdr xs) (cdr r1))))
        (cons (append (car r1) (car r2)) (cdr r2)))))

(show (car (generate 'sentence 1)))
(show (car (generate 'sentence 2)))
(show (car (generate 'sentence 3)))
(show (car (generate 'sentence 12345)))
;; the same seed gives the same sentence -- the generator is a function, not an effect
(show (equal? (car (generate 'sentence 7)) (car (generate 'sentence 7))))
(show (car (generate 'noun-phrase 99)))
(show (car (generate 'Verb 5)))

;; --- generate-all: the whole language, no randomness needed ---
(define (combine-all xlist ylist)
  (apply append (map (lambda (y) (map (lambda (x) (append x y)) xlist)) ylist)))

(define (generate-all x)
  (cond ((category? x) (apply append (map generate-all-list (rules-for x))))
        (else (list (list x)))))

(define (generate-all-list xs)
  (if (null? xs) (list '())
      (combine-all (generate-all (car xs)) (generate-all-list (cdr xs)))))

(show (length (generate-all 'Article)))
(show (length (generate-all 'Noun)))
(show (length (generate-all 'noun-phrase)))
(show (length (generate-all 'sentence)))
(show (generate-all 'Article))
(show (car (generate-all 'noun-phrase)))
(show (car (generate-all 'sentence)))
;; 2 articles * 4 nouns * 4 verbs * 2 articles * 4 nouns
(show (= (length (generate-all 'sentence)) (* 2 4 4 2 4)))
;; every generated sentence is 5 words long
(show (length (car (generate-all 'sentence))))
