;; oracle/paip/ch14-knowledge.scm: our own Scheme on the topic of PAIP chapter 14, knowledge
;; representation -- a semantic network with INHERITANCE, and the two things that make knowledge
;; representation hard rather than merely tedious: a default that a subclass can OVERRIDE, and a
;; cycle that must not hang the query. Our code and our examples; Norvig's own code is not read or
;; copied.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; facts: (isa child parent) and (has thing slot value)
(define facts
  '((isa penguin bird) (isa bird animal) (isa canary bird)
    (isa opus penguin) (isa tweety canary)
    (has animal alive yes) (has animal legs 4)
    (has bird legs 2) (has bird flies yes)
    (has penguin flies no)
    (has opus color black)))

(define (parents-of x) (map caddr (filter (lambda (f) (and (eq? (car f) 'isa) (eq? (cadr f) x))) facts)))
(define (own-slot x slot)
  (let ((h (filter (lambda (f) (and (eq? (car f) 'has) (eq? (cadr f) x) (eq? (caddr f) slot))) facts)))
    (if (null? h) #f (cadddr (car h)))))

;; the query: ask the thing itself, then its parents, depth first, and STOP at the first answer.
;; `seen` is what makes a cyclic network terminate.
(define (get-slot x slot seen)
  (if (memq x seen) #f
      (or (own-slot x slot)
          (let loop ((ps (parents-of x)))
            (if (null? ps) #f
                (or (get-slot (car ps) slot (cons x seen)) (loop (cdr ps))))))))

(define (q x slot) (get-slot x slot '()))

;; --- inheritance up the chain ---
(show (q 'opus 'color))
(show (q 'opus 'alive))
(show (q 'tweety 'alive))
(show (q 'bird 'legs))
(show (q 'animal 'legs))
;; a subclass OVERRIDES a default: birds fly, penguins do not, and opus is a penguin
(show (q 'bird 'flies))
(show (q 'penguin 'flies))
(show (q 'opus 'flies))
(show (q 'tweety 'flies))
;; the override is what makes this interesting: two birds, two answers
(show (eq? (q 'opus 'flies) (q 'tweety 'flies)))
;; legs comes from bird, not from animal, because bird is nearer
(show (q 'opus 'legs))
(show (eq? (q 'opus 'legs) (q 'animal 'legs)))
;; a slot nobody has
(show (q 'opus 'salary))
;; how many ancestors does opus have?
(define (ancestors x seen)
  (if (memq x seen) '()
      (let loop ((ps (parents-of x)) (out '()))
        (if (null? ps) out
            (loop (cdr ps) (append out (list (car ps)) (ancestors (car ps) (cons x seen))))))))
(show (ancestors 'opus '()))
(show (length (ancestors 'opus '())))
