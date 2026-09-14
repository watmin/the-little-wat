;; The Little Schemer, ch 4 (Numbers Games): the definitions. Needs lib/ch01-toys.wat
;; loaded first. No main here.
;;
;; Representation, chosen to match how wat is written today (Sept 2026):
;;   - numbers are i64, and arithmetic is built from add1 / sub1 / zero? by recursion.
;;   - a tup (list of numbers) is a (Vector :- [i64]), wat's idiomatic list of numbers.
;;   - lats that MIX numbers and symbols stay quoted S-expressions (:wat::WatAST), wat's
;;     idiomatic carrier for heterogeneous data. A number inside one is an AST node; it
;;     becomes an i64 through eval-ast! (FINDINGS.md, C-007).
;; Walking a Vector with rest rebuilds it on every step (O(n^2) overall, wat/seq.wat:16). The
;; data here is tiny, and the chapter is about the recursion itself.

;; ── natural-number arithmetic from three primitives ────────────────────────────────

(wat.core/defn ls/add1 [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn ls/sub1 [n :- wat.type/i64] :- wat.type/i64 (wat.core/- n 1))
(wat.core/defn ls/zero? [n :- wat.type/i64] :- wat.type/bool (wat.core/= n 0))
(wat.core/defn ls/one? [n :- wat.type/i64] :- wat.type/bool (wat.core/= n 1))

(wat.core/defn ls/o+ [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (ls/zero? m) n (ls/add1 (ls/o+ n (ls/sub1 m)))))

(wat.core/defn ls/o- [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (ls/zero? m) n (ls/sub1 (ls/o- n (ls/sub1 m)))))

(wat.core/defn ls/o* [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (ls/zero? m) 0 (ls/o+ n (ls/o* n (ls/sub1 m)))))

(wat.core/defn ls/o> [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((ls/zero? n) false)
    ((ls/zero? m) true)
    (:else (ls/o> (ls/sub1 n) (ls/sub1 m)))))

;; The book calls this <. A name containing `<` is a lex error in wat (FINDINGS.md, F-008).
(wat.core/defn ls/less? [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((ls/zero? m) false)
    ((ls/zero? n) true)
    (:else (ls/less? (ls/sub1 n) (ls/sub1 m)))))

(wat.core/defn ls/o= [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((ls/o> n m) false)
    ((ls/less? n m) false)
    (:else true)))

;; the book's up-arrow: n to the power m
(wat.core/defn ls/pow [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (ls/zero? m) 1 (ls/o* n (ls/pow n (ls/sub1 m)))))

;; the book's division sign: how many times m fits in n
(wat.core/defn ls/quotient [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (ls/less? n m) 0 (ls/add1 (ls/quotient (ls/o- n m) m))))

;; ── tups: (Vector :- [i64]) ─────────────────────────────────────────────────────────

(wat.core/defn ls/addtup [tup :- (wat.type/Vector :- [wat.type/i64])] :- wat.type/i64
  (wat.core/if (wat.core/empty? tup)
    0
    (ls/o+ (wat.core/first tup) (ls/addtup (wat.core/rest tup)))))

;; pairwise sum; when one tup runs out, the rest of the other carries over
(wat.core/defn ls/tup+ [t1 :- (wat.type/Vector :- [wat.type/i64])
                        t2 :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/cond
    ((wat.core/empty? t1) t2)
    ((wat.core/empty? t2) t1)
    (:else (wat.core/concat [(ls/o+ (wat.core/first t1) (wat.core/first t2))]
                            (ls/tup+ (wat.core/rest t1) (wat.core/rest t2))))))

;; ── lats that mix numbers and symbols: quoted S-expressions ─────────────────────────

(wat.core/defn ls/number? [x :- :wat::WatAST] :- wat.type/bool
  (wat.core/= (wat.core/ast-kind x) "int"))

;; a number node's value (C-007)
(wat.core/defn ls/ast->i64 [n :- :wat::WatAST] :- wat.type/i64
  (:wat::core::Result/expect (:wat::eval-ast! n) "ls/ast->i64: expected a number literal"))

(wat.core/defn ls/length [lat :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/null? lat) 0 (ls/add1 (ls/length (ls/cdr lat)))))

;; the n-th element, counting from 1
(wat.core/defn ls/pick [n :- wat.type/i64 lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/one? n) (ls/car lat) (ls/pick (ls/sub1 n) (ls/cdr lat))))

;; the lat without its n-th element, counting from 1
(wat.core/defn ls/rempick [n :- wat.type/i64 lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/one? n)
    (ls/cdr lat)
    (ls/cons (ls/car lat) (ls/rempick (ls/sub1 n) (ls/cdr lat)))))

(wat.core/defn ls/no-nums [lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/number? (ls/car lat)) (ls/no-nums (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ls/no-nums (ls/cdr lat))))))

;; the numbers of a mixed lat, as a real tup: this crosses from S-expressions to i64s
(wat.core/defn ls/all-nums [lat :- :wat::WatAST] :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/cond
    ((ls/null? lat) [])
    ((ls/number? (ls/car lat))
     (wat.core/concat [(ls/ast->i64 (ls/car lat))] (ls/all-nums (ls/cdr lat))))
    (:else (ls/all-nums (ls/cdr lat)))))

;; atoms equal: numbers compared as numbers, everything else with eq?
(wat.core/defn ls/eqan? [a1 :- :wat::WatAST a2 :- :wat::WatAST] :- wat.type/bool
  (wat.core/cond
    ((wat.core/and (ls/number? a1) (ls/number? a2)) (ls/o= (ls/ast->i64 a1) (ls/ast->i64 a2)))
    ((wat.core/or (ls/number? a1) (ls/number? a2)) false)
    (:else (ls/eq? a1 a2))))

(wat.core/defn ls/occur [a :- :wat::WatAST lat :- :wat::WatAST] :- wat.type/i64
  (wat.core/cond
    ((ls/null? lat) 0)
    ((ls/eqan? (ls/car lat) a) (ls/add1 (ls/occur a (ls/cdr lat))))
    (:else (ls/occur a (ls/cdr lat)))))
