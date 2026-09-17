;; oracle/paip/ch17-constraints.scm: our own Scheme on the topic of PAIP chapter 17, labeling by
;; CONSTRAINT SATISFACTION -- Waltz filtering. Lines in a diagram are variables, their possible
;; labels are domains, and each junction is a catalogue of the label combinations it permits.
;; Filtering removes from every domain the labels no permitted combination supports, and repeats
;; until nothing changes. Our code, our catalogue and our examples; Norvig's own code is not read
;; or copied.
;;
;; The chapter's claim is that propagation alone -- no search, no backtracking -- often reduces the
;; problem to a single interpretation, and that when it does not, it still removes most of the
;; space before any search begins. Both outcomes are tested.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; labels: + convex, - concave, L and R occluding
(define all-labels '(+ - L R))

;; a junction constrains the lines meeting at it, as a list of PERMITTED tuples
;; (junction name (line ...) ((label ...) ...))
(define (jname j) (car j)) (define (jlines j) (cadr j)) (define (jtuples j) (caddr j))

;; our catalogue: an L junction permits four of the sixteen pairs; a fork permits three triples
(define L-pairs '((+ R) (- L) (L +) (R -)))
;; the fork's third triple is the one consistent with two L junctions in a row:
;;   (a,b) = (+ R) is an L pair, and (b,c) = (R -) is an L pair, so (+ R -) can survive
(define fork-triples '((+ + +) (- - -) (+ R -)))

(define diagram
  (list (list 'j1 '(a b) L-pairs)
        (list 'j2 '(b c) L-pairs)
        (list 'j3 '(a b c) fork-triples)))

;; domains: an alist of line -> list of still-possible labels
(define (dom d v) (cdr (assq v d)))
(define (set-dom d v labels) (map (lambda (p) (if (eq? (car p) v) (cons v labels) p)) d))
(define (initial-domains vars) (map (lambda (v) (cons v all-labels)) vars))

;; a tuple is still possible if every line's label is still in that line's domain
(define (tuple-ok? d lines tuple)
  (let loop ((ls lines) (ts tuple))
    (cond ((null? ls) #t)
          ((memq (car ts) (dom d (car ls))) (loop (cdr ls) (cdr ts)))
          (else #f))))

;; the labels a junction still supports for one of its lines
(define (supported d j line)
  (let ((i (index-of line (jlines j))))
    (let loop ((ts (jtuples j)) (out '()))
      (cond ((null? ts) (reverse out))
            ((and (tuple-ok? d (jlines j) (car ts)) (not (memq (list-ref (car ts) i) out)))
             (loop (cdr ts) (cons (list-ref (car ts) i) out)))
            (else (loop (cdr ts) out))))))

(define (index-of x l) (let loop ((l l) (i 0)) (cond ((null? l) -1) ((eq? x (car l)) i) (else (loop (cdr l) (+ i 1))))))

(define (intersect a b) (filter (lambda (x) (memq x b)) a))

;; one pass: narrow every line at every junction
(define (pass d js)
  (if (null? js) d
      (pass (let loop ((ls (jlines (car js))) (d d))
              (if (null? ls) d
                  (loop (cdr ls) (set-dom d (car ls) (intersect (dom d (car ls)) (supported d (car js) (car ls)))))))
            (cdr js))))

(define (propagate d js)
  (let ((d2 (pass d js))) (if (equal? d d2) d (propagate d2 js))))

(define (sizes d) (map (lambda (p) (length (cdr p))) d))
(define (total d) (apply + (sizes d)))

(define vars '(a b c))
(define start (initial-domains vars))

(show (total start))
(show (sizes start))
;; one junction alone already removes possibilities
(show (sizes (pass start (list (car diagram)))))
;; the whole diagram, propagated to a fixed point
(define final (propagate start diagram))
(show (sizes final))
(show (total final))
(show (dom final 'a))
(show (dom final 'b))
(show (dom final 'c))
;; propagation alone reduced the space from 4*4*4 to a single interpretation
(show (< (total final) (total start)))
(show (= 3 (total final)))

;; --- a diagram with NO consistent labeling: propagation empties a domain ---
(define impossible
  (list (list 'k1 '(a b) '((+ +)))
        (list 'k2 '(a b) '((- -)))))
(define bad (propagate (initial-domains '(a b)) impossible))
(show (sizes bad))
(show (total bad))
(show (= 0 (total bad)))

;; --- a diagram that propagation does NOT decide: two interpretations survive ---
(define ambiguous (list (list 'm1 '(a b) '((+ +) (- -)))))
(define amb (propagate (initial-domains '(a b)) ambiguous))
(show (sizes amb))
(show (dom amb 'a))
(show (> (total amb) 2))
