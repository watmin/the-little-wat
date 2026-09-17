;; oracle/paip/ch18-othello.scm: our own Scheme on the topic of PAIP chapter 18, search and the
;; game of Othello -- a real board, real move generation with flipping, and MINIMAX with
;; ALPHA-BETA pruning. Our code and our examples; Norvig's own code is not read or copied.
;;
;; The chapter's measurable claim is that alpha-beta returns the SAME move as minimax while
;; visiting far fewer nodes, so both searches count their nodes and the counts are compared.
;;
;; Run by tools/paip-oracle.sh with guile; every "=> " line is an expected result.

(define (show v) (display "=> ") (write v) (newline))

(define empty 0) (define black 1) (define white 2)
(define (opponent p) (if (= p black) white black))

;; an 8x8 board as a 64-vector, row-major; (r,c) -> r*8+c
(define (idx r c) (+ (* r 8) c))
(define (on-board? r c) (and (>= r 0) (< r 8) (>= c 0) (< c 8)))
(define (bref b r c) (vector-ref b (idx r c)))

(define (initial-board)
  (let ((b (make-vector 64 empty)))
    (vector-set! b (idx 3 3) white) (vector-set! b (idx 4 4) white)
    (vector-set! b (idx 3 4) black) (vector-set! b (idx 4 3) black)
    b))

(define dirs '((-1 -1) (-1 0) (-1 1) (0 -1) (0 1) (1 -1) (1 0) (1 1)))

;; the pieces flipped in one direction, or '() if the move does not capture that way
(define (flips-in b r c dr dc player)
  (let loop ((rr (+ r dr)) (cc (+ c dc)) (acc '()))
    (cond ((not (on-board? rr cc)) '())
          ((= (bref b rr cc) empty) '())
          ((= (bref b rr cc) player) acc)
          (else (loop (+ rr dr) (+ cc dc) (cons (idx rr cc) acc))))))

(define (all-flips b r c player)
  (apply append (map (lambda (d) (flips-in b r c (car d) (cadr d) player)) dirs)))

(define (legal? b r c player)
  (and (= (bref b r c) empty) (not (null? (all-flips b r c player)))))

(define (legal-moves b player)
  (let loop ((i 0) (out '()))
    (if (= i 64) (reverse out)
        (let ((r (quotient i 8)) (c (remainder i 8)))
          (loop (+ i 1) (if (legal? b r c player) (cons i out) out))))))

(define (make-move b i player)
  (let ((nb (vector-copy b)) (r (quotient i 8)) (c (remainder i 8)))
    (vector-set! nb i player)
    (for-each (lambda (f) (vector-set! nb f player)) (all-flips b r c player))
    nb))

(define (count-pieces b p)
  (let loop ((i 0) (n 0)) (if (= i 64) n (loop (+ i 1) (if (= (vector-ref b i) p) (+ n 1) n)))))
(define (difference b p) (- (count-pieces b p) (count-pieces b (opponent p))))

(show (count-pieces (initial-board) black))
(show (count-pieces (initial-board) white))
(show (legal-moves (initial-board) black))
(show (length (legal-moves (initial-board) black)))
(show (difference (initial-board) black))
;; playing 19 (row 2, col 3) flips one white and gives black five
(show (count-pieces (make-move (initial-board) 19 black) black))
(show (count-pieces (make-move (initial-board) 19 black) white))
(show (legal-moves (make-move (initial-board) 19 black) white))

;; --- minimax, counting nodes ---
(define nodes 0)
(define (minimax b player depth)
  (set! nodes (+ nodes 1))
  (if (= depth 0) (difference b player)
      (let ((ms (legal-moves b player)))
        (if (null? ms) (- (minimax b (opponent player) (- depth 1)))
            (let loop ((ms ms) (best -1000))
              (if (null? ms) best
                  (let ((v (- (minimax (make-move b (car ms) player) (opponent player) (- depth 1)))))
                    (loop (cdr ms) (if (> v best) v best)))))))))

;; --- alpha-beta, counting nodes ---
(define ab-nodes 0)
(define (alpha-beta b player depth alpha beta)
  (set! ab-nodes (+ ab-nodes 1))
  (if (= depth 0) (difference b player)
      (let ((ms (legal-moves b player)))
        (if (null? ms) (- (alpha-beta b (opponent player) (- depth 1) (- beta) (- alpha)))
            (let loop ((ms ms) (alpha alpha))
              (if (or (null? ms) (>= alpha beta)) alpha
                  (let ((v (- (alpha-beta (make-move b (car ms) player) (opponent player)
                                          (- depth 1) (- beta) (- alpha)))))
                    (loop (cdr ms) (if (> v alpha) v alpha)))))))))

(define (run-minimax d) (set! nodes 0) (let ((v (minimax (initial-board) black d))) (list v nodes)))
(define (run-ab d) (set! ab-nodes 0) (let ((v (alpha-beta (initial-board) black d -1000 1000))) (list v ab-nodes)))

(show (car (run-minimax 1)))
(show (car (run-ab 1)))
(show (car (run-minimax 3)))
(show (car (run-ab 3)))
;; the same answer, and alpha-beta visits far fewer nodes
(show (= (car (run-minimax 3)) (car (run-ab 3))))
(show (cadr (run-minimax 3)))
(show (cadr (run-ab 3)))
(show (< (cadr (run-ab 3)) (cadr (run-minimax 3))))
