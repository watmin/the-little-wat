;; oracle/sicp/ch33-mutable-data.scm: our own Scheme on the topic of SICP §3.3, mutable data: a
;; queue that grows at one end and shrinks at the other, and a table that remembers what was put
;; in it. Our code and our examples, not the book's text.
;;
;; The queue is the book's shape: a pair of pointers into a list, changed by set-car! and
;; set-cdr!, so that inserting at the rear costs nothing.
;;
;; Run by tools/sicp-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

;; ---- a queue: a pair of pointers into one list

(define (make-queue) (cons '() '()))
(define (front-ptr q) (car q))
(define (rear-ptr q) (cdr q))
(define (empty-queue? q) (null? (front-ptr q)))

(define (insert-queue! q item)
  (let ((cell (cons item '())))
    (if (empty-queue? q)
        (begin (set-car! q cell) (set-cdr! q cell))
        (begin (set-cdr! (rear-ptr q) cell) (set-cdr! q cell)))
    (front-ptr q)))

(define (delete-queue! q)
  (if (empty-queue? q)
      'empty
      (begin (set-car! q (cdr (front-ptr q)))
             (if (null? (front-ptr q)) (set-cdr! q '()) #t)
             (front-ptr q))))

(define (front-queue q)
  (if (empty-queue? q) 'empty (car (front-ptr q))))

;; ---- a table: a list of key/value records, changed in place

(define (make-table) (list 'table))

(define (find-record key records)
  (cond ((null? records) #f)
        ((equal? key (caar records)) (car records))
        (else (find-record key (cdr records)))))

(define (lookup key table)
  (let ((record (find-record key (cdr table))))
    (if record (cdr record) 'missing)))

(define (insert! key value table)
  (let ((record (find-record key (cdr table))))
    (if record
        (set-cdr! record value)
        (set-cdr! table (cons (cons key value) (cdr table)))))
  value)

;; ---- the queue

(define q (make-queue))
(show (empty-queue? q))
(show (front-queue q))
(show (delete-queue! q))
(show (insert-queue! q 1))
(show (insert-queue! q 2))
(show (insert-queue! q 3))
(show (front-queue q))
(show (empty-queue? q))
(show (delete-queue! q))
(show (delete-queue! q))
(show (insert-queue! q 4))
(show (delete-queue! q))
(show (delete-queue! q))
(show (empty-queue? q))

;; ---- a second queue is its own

(define q2 (make-queue))
(show (insert-queue! q2 9))
(show (front-queue q))

;; ---- the table

(define t (make-table))
(show (lookup "a" t))
(show (insert! "a" 1 t))
(show (lookup "a" t))
(show (insert! "b" 2 t))
(show (lookup "b" t))
(show (insert! "a" 11 t))
(show (lookup "a" t))
(show (lookup "b" t))
(show (lookup "c" t))
