;; oracle/paip/ch19-natural-language.scm: our own Scheme on the topic of PAIP chapter 19, an
;; introduction to natural language -- a context-free grammar and a parser that returns EVERY
;; parse, because the interesting fact about natural language is that sentences are ambiguous.
;; Our code, our grammar and our examples; Norvig's own code is not read or copied.
;;
;; The parser is top-down and returns (tree . remaining-words) for every way a category can begin
;; the input. Ambiguity then shows up as more than one complete parse, and the classic case is
;; prepositional-phrase attachment: "I saw the man with the telescope" has two readings and the
;; grammar cannot choose between them.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; grammar: (category (right-hand-side ...) ...)
(define grammar
  '((S (NP VP))
    (NP (D N) (D N PP) (Pro))
    (VP (V NP) (V NP PP))
    (PP (P NP))
    (D (the) (a))
    (N (man) (telescope) (park))
    (Pro (I))
    (V (saw))
    (P (with) (in))))

(define (rules-for cat) (let ((h (assq cat grammar))) (if h (cdr h) '())))
(define (terminal? x) (null? (rules-for x)))

;; every (tree remaining) for one category at the front of `words`
(define (parse cat words)
  (if (terminal? cat)
      (if (and (pair? words) (eq? (car words) cat)) (list (list cat (cdr words))) '())
      (apply append (map (lambda (rhs) (parse-rhs cat rhs words)) (rules-for cat)))))

(define (parse-rhs cat rhs words)
  (map (lambda (r) (list (cons cat (car r)) (cadr r))) (parse-seq rhs words)))

;; every (list-of-trees remaining) for a sequence of categories
(define (parse-seq cats words)
  (if (null? cats) (list (list '() words))
      (apply append
             (map (lambda (r)
                    (map (lambda (r2) (list (cons (car r) (car r2)) (cadr r2)))
                         (parse-seq (cdr cats) (cadr r))))
                  (parse (car cats) words)))))

;; only the parses that consumed every word
(define (parses-of words) (filter (lambda (r) (null? (cadr r))) (parse 'S words)))

(define s1 '(the man saw the telescope))
(define s2 '(I saw the man with the telescope))
(define s3 '(the man saw a park in the park))

(show (length (parses-of s1)))
(show (car (car (parses-of s1))))
;; the classic ambiguity: two readings, and the grammar cannot choose
(show (length (parses-of s2)))
(show (length (parses-of s3)))
;; a sentence the grammar cannot parse at all
(show (length (parses-of '(the saw man))))
(show (length (parses-of '(man))))
;; partial parses: how many ways can NP begin these words?
(show (length (parse 'NP '(the man saw the telescope))))
(show (length (parse 'NP '(the man with the telescope))))
(show (length (parse 'Pro '(I saw))))
(show (length (parse 'V '(saw the man))))
(show (length (parse 'V '(the man))))
;; the two readings of s2 differ in where the PP attaches -- the trees are not equal
(show (equal? (car (car (parses-of s2))) (car (cadr (parses-of s2)))))
(show (length (parse 'S s2)))
