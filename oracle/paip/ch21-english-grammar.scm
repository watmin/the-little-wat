;; oracle/paip/ch21-english-grammar.scm: our own Scheme on the topic of PAIP chapter 21, a grammar
;; of English -- SUBCATEGORIZATION (a verb takes the complements it takes, and no others) and
;; RELATIVE CLAUSES (a noun phrase can contain a sentence, so the grammar is recursive through
;; itself). Our code, our grammar and our examples; Norvig's own code is not read or copied.
;;
;; Chapter 19 showed ambiguity, chapter 20 showed agreement. This one shows the two things a toy
;; grammar always gets wrong: it lets an intransitive verb take an object, and it cannot embed.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; the lexicon carries each verb's SUBCATEGORY, so the grammar need not name verbs at all
(define lexicon
  '((the D) (a D)
    (man N) (dog N) (bone N) (park N)
    (slept V-intrans) (barked V-intrans)
    (saw V-trans) (chased V-trans)
    (gave V-ditrans)
    (that Rel)
    (in P) (with P)))

(define (cats-of word) (map cadr (filter (lambda (e) (eq? (car e) word)) lexicon)))
(define (is? word cat) (if (memq cat (cats-of word)) #t #f))

;; parse returns the list of positions the input could have reached
(define (p-word cat words) (if (and (pair? words) (is? (car words) cat)) (list (cdr words)) '()))

(define (p-np words)
  ;; NP -> D N | D N RelClause | D N PP
  (apply append
         (map (lambda (r1)
                (apply append
                       (map (lambda (r2)
                              (append (list r2) (p-rel r2) (p-pp r2)))
                            (p-word 'N r1))))
              (p-word 'D words))))

(define (p-rel words)
  ;; Rel -> "that" VP   (a relative clause is a VP with the noun as its subject)
  (apply append (map (lambda (r) (p-vp r)) (p-word 'Rel words))))

(define (p-pp words)
  (apply append (map (lambda (r) (p-np r)) (p-word 'P words))))

(define (p-vp words)
  ;; the verb's subcategory decides what may follow it, and nothing else does
  (append
   (p-word 'V-intrans words)
   (apply append (map (lambda (r) (p-np r)) (p-word 'V-trans words)))
   (apply append (map (lambda (r) (apply append (map (lambda (r2) (p-np r2)) (p-np r))))
                      (p-word 'V-ditrans words)))))

(define (p-s words) (apply append (map (lambda (r) (p-vp r)) (p-np words))))
(define (ok? words) (if (memq '() (p-s words)) #t #f))
(define (count words) (length (filter null? (p-s words))))

;; --- subcategorization: each verb takes what it takes ---
(show (ok? '(the dog slept)))
(show (ok? '(the man saw the dog)))
(show (ok? '(the man gave the dog the bone)))
;; an intransitive verb given an object
(show (ok? '(the dog slept the bone)))
;; a transitive verb given none
(show (ok? '(the man saw)))
;; a ditransitive verb given only one
(show (ok? '(the man gave the dog)))
;; and given three
(show (ok? '(the man gave the dog the bone the park)))

;; --- relative clauses: a noun phrase containing a sentence ---
(show (ok? '(the dog that barked slept)))
(show (ok? '(the man that saw the dog slept)))
;; nested one level deeper
(show (ok? '(the man that saw the dog that barked slept)))
;; the relative clause must itself obey subcategorization
(show (ok? '(the dog that slept the bone slept)))

;; --- prepositional phrases. NOTE: this grammar attaches a PP only INSIDE a noun phrase, so
;; "the man saw the dog in the park" has exactly ONE parse here, where chapter 19's grammar --
;; which also had VP -> V NP PP -- gave it two. Ambiguity is a property of the grammar, not of
;; English, and the count below records that rather than the reverse.
(show (ok? '(the man in the park slept)))
(show (count '(the man saw the dog in the park)))
(show (> (count '(the man saw the dog in the park)) 1))
(show (count '(the dog slept)))
