;; oracle/paip/ch20-unification-grammar.scm: our own Scheme on the topic of PAIP chapter 20,
;; unification grammars -- a grammar whose categories carry FEATURES, unified as the parse is
;; built, so that agreement is enforced by the grammar rather than by extra rules. Our code, our
;; grammar and our examples; Norvig's own code is not read or copied.
;;
;; A category is (name number), where number is sg, pl, or the variable ?n. A rule shares a
;; variable between its parts -- S -> NP(?n) VP(?n) -- so "the man sees" parses and "the man see"
;; does not, with no separate rule for each number.
;;
;; The contrast with chapter 19 is that a plain CFG would need every rule TWICE, once per number,
;; and the number of rules multiplies with every feature added.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define (var? x) (eq? x '?n))
;; a terminal in a right-hand side is written (word) with no number, so an absent number means
;; "unconstrained" rather than an error
(define (cat-name c) (car c))
(define (cat-num c) (if (null? (cdr c)) '?n (cadr c)))

;; a binding is sg, pl, or #f for "not yet decided"
(define (unify-num a b bnd)
  (cond ((eq? bnd 'fail) 'fail)
        ((and (var? a) (var? b)) bnd)
        ((var? a) (if (or (not bnd) (eq? bnd b)) b 'fail))
        ((var? b) (if (or (not bnd) (eq? bnd a)) a 'fail))
        ((eq? a b) bnd)
        (else 'fail)))

;; grammar: (lhs rhs...) where each element is (name number)
(define grammar
  '(((S ?n)  ((NP ?n) (VP ?n)))
    ((NP ?n) ((D ?n) (N ?n)))
    ((VP ?n) ((V ?n) (NP *)))     ; * means "a fresh, independent number"
    ((VP ?n) ((V ?n)))
    ((D sg)  ((the-sg)))
    ((D pl)  ((the-pl)))
    ((N sg)  ((man)))
    ((N pl)  ((men)))
    ((V sg)  ((sees)))
    ((V pl)  ((see)))))

;; the lexicon is written with distinct words for the two determiners so that the grammar, not the
;; spelling, is what decides; "the" would be ambiguous and hide the point
(define (rules-for name) (filter (lambda (r) (eq? name (cat-name (car r)))) grammar))
(define (terminal? name) (null? (rules-for name)))

;; parse: (remaining binding) for every way `cat` can begin `words` under `bnd`
(define (parse cat words bnd)
  (if (eq? bnd 'fail) '()
      ;; `*` starts a FRESH binding scope: the object's number is independent of the subject's,
      ;; and whatever it settles on is discarded when the object is finished
      (if (eq? (cat-num cat) '*)
          (map (lambda (r) (list (car r) bnd)) (parse (list (cat-name cat) '?n) words #f))
      (let ((name (cat-name cat)))
        (if (terminal? name)
            (if (and (pair? words) (eq? (car words) name)) (list (list (cdr words) bnd)) '())
            (apply append
                   (map (lambda (r)
                          (let ((b2 (unify-num (cat-num cat) (cat-num (car r)) bnd)))
                            (if (eq? b2 'fail) '() (parse-seq (cadr r) words b2))))
                        (rules-for name))))))))

(define (parse-seq cats words bnd)
  (if (null? cats) (list (list words bnd))
      (apply append (map (lambda (r) (parse-seq (cdr cats) (car r) (cadr r)))
                         (parse (car cats) words bnd)))))

(define (parses words) (filter (lambda (r) (null? (car r))) (parse '(S ?n) words #f)))
(define (ok? words) (not (null? (parses words))))

;; --- agreement enforced by one rule, not by two ---
(show (ok? '(the-sg man sees)))
(show (ok? '(the-pl men see)))
;; the number disagrees between subject and verb
(show (ok? '(the-sg man see)))
(show (ok? '(the-pl men sees)))
;; the number disagrees WITHIN the noun phrase
(show (ok? '(the-sg men sees)))
(show (ok? '(the-pl man see)))
;; a transitive use: the object's number is free and need not match the subject's
(show (ok? '(the-sg man sees the-pl men)))
(show (ok? '(the-pl men see the-sg man)))
(show (ok? '(the-sg man sees the-sg man)))
;; but the subject must still agree
(show (ok? '(the-sg man see the-pl men)))
(show (length (parses '(the-sg man sees))))
(show (length (parses '(the-sg man sees the-pl men))))
(show (length (parses '(the-sg man see))))
;; the binding that survives says which number the sentence settled on
(show (cadr (car (parses '(the-sg man sees)))))
(show (cadr (car (parses '(the-pl men see)))))
