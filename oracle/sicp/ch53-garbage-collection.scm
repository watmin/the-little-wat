;; oracle/sicp/ch53-garbage-collection.scm: our own Scheme on the topic of SICP §5.3, storage
;; allocation and garbage collection -- memory as two parallel vectors of cars and cdrs, `cons` as
;; bumping a free pointer, and STOP-AND-COPY: two semispaces, a root, and broken hearts so that a
;; shared structure is copied once and stays shared. Our code and our examples.
;;
;; The section's claim worth checking is not that GC frees memory -- that is obvious -- but that
;; copying PRESERVES SHARING. A list whose tail is reachable twice must still be one list after the
;; collection, not two copies, and the broken heart is the only thing that makes that true.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; a pointer is an index; -1 is nil. A cell is (cars[i], cdrs[i]).
;; A car holds either a number (tagged 'n) or a pointer (tagged 'p).
(define (mk-mem size) (list (make-vector size 0) (make-vector size 0) 0))
(define (cars m) (car m))
(define (cdrs m) (cadr m))
(define (free m) (caddr m))
(define (set-free m f) (list (cars m) (cdrs m) f))

(define (mcons m a d)
  (let ((i (free m)))
    (vector-set! (cars m) i a)
    (vector-set! (cdrs m) i d)
    (cons i (set-free m (+ i 1)))))

(define (mcar m i) (vector-ref (cars m) i))
(define (mcdr m i) (vector-ref (cdrs m) i))

;; build (1 2 3) as a chain; every car is ('n . k), every cdr is a pointer or -1
(define (build-list m vals)
  (if (null? vals) (cons -1 m)
      (let* ((r (build-list m (cdr vals)))
             (tail (car r)) (m1 (cdr r)))
        (mcons m1 (cons 'n (car vals)) tail))))

(define (mlist->scheme m p)
  (if (= p -1) '() (cons (cdr (mcar m p)) (mlist->scheme m (mcdr m p)))))

(define mem0 (mk-mem 40))
(define built (build-list mem0 '(1 2 3)))
(define lst (car built))
(define mem1 (cdr built))

(show (mlist->scheme mem1 lst))
(show (free mem1))

;; a second list SHARING the tail of the first
(define built2 (mcons mem1 (cons 'n 99) (mcdr mem1 lst)))
(define shared (car built2))
(define mem2 (cdr built2))
(show (mlist->scheme mem2 shared))
(show (free mem2))
;; the two lists share a cell: the cdr of `shared` IS the cdr of `lst`
(show (= (mcdr mem2 shared) (mcdr mem2 lst)))

;; --- STOP AND COPY ---
;; copy the structure reachable from each root into a fresh memory, leaving broken hearts behind
(define (collect m roots size)
  (let ((new (mk-mem size)) (forward (make-vector size -1)))
    (define (relocate p mm)
      (if (= p -1) (cons -1 mm)
          (if (not (= (vector-ref forward p) -1))
              (cons (vector-ref forward p) mm)      ; a broken heart: already copied
              (let* ((i (free mm))
                     (mm1 (set-free mm (+ i 1))))
                (vector-set! forward p i)           ; leave the broken heart BEFORE recurring
                (vector-set! (cars mm1) i (mcar m p))
                (let ((r (relocate (mcdr m p) mm1)))
                  (vector-set! (cdrs (cdr r)) i (car r))
                  (cons i (cdr r)))))))
    (let loop ((rs roots) (mm new) (out '()))
      (if (null? rs) (list (reverse out) mm)
          (let ((r (relocate (car rs) mm)))
            (loop (cdr rs) (cdr r) (cons (car r) out)))))))

;; collect with BOTH lists live: sharing must survive
(define c1 (collect mem2 (list lst shared) 40))
(define new-roots (car c1))
(define mem3 (cadr c1))
(show (mlist->scheme mem3 (car new-roots)))
(show (mlist->scheme mem3 (cadr new-roots)))
(show (free mem3))
;; the shared tail is STILL shared after copying -- this is what broken hearts buy
(show (= (mcdr mem3 (cadr new-roots)) (mcdr mem3 (car new-roots))))

;; collect with only the FIRST list live: the extra cell is reclaimed
(define c2 (collect mem2 (list lst) 40))
(show (mlist->scheme (cadr c2) (car (car c2))))
(show (free (cadr c2)))
;; 4 cells were in use, 3 survive
(show (- (free mem2) (free (cadr c2))))

;; collect with NOTHING live
(define c3 (collect mem2 '() 40))
(show (free (cadr c3)))
