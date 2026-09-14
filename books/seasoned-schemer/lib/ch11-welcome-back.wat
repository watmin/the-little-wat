;; The Seasoned Schemer, ch 11 (Welcome Back to the Show): the definitions. Accumulators:
;; an extra argument that carries what the recursion has seen so far. Needs
;; ../little-schemer/lib/ch01-toys.wat loaded first (car, cdr, null?, eq?). No main here.
;;
;; The Seasoned Schemer lives in the ss/ namespace. Tups are (Vector :- [i64]), as in
;; Little Schemer ch 4.

;; two-in-a-row?: does some atom appear twice in a row? The accumulator is the previous atom.
(wat.core/defn ss/two-in-a-row-b? [preceding :- :wat::WatAST lat :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/null? lat)
    false
    (wat.core/or (ls/eq? (ls/car lat) preceding)
                 (ss/two-in-a-row-b? (ls/car lat) (ls/cdr lat)))))

(wat.core/defn ss/two-in-a-row? [lat :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/null? lat)
    false
    (ss/two-in-a-row-b? (ls/car lat) (ls/cdr lat))))

;; sum-of-prefixes: each number replaced by the sum of it and every number before it. The
;; accumulator, sonssf, is the sum of the numbers seen so far.
(wat.core/defn ss/sum-of-prefixes-b [sonssf :- wat.type/i64
                                     tup    :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/empty? tup)
    []
    (wat.core/let [s (wat.core/+ sonssf (wat.core/first tup))]
      (wat.core/concat [s] (ss/sum-of-prefixes-b s (wat.core/rest tup))))))

(wat.core/defn ss/sum-of-prefixes [tup :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (ss/sum-of-prefixes-b 0 tup))

;; pick on a tup, counting from 1
(wat.core/defn ss/pick [n :- wat.type/i64 tup :- (wat.type/Vector :- [wat.type/i64])] :- wat.type/i64
  (wat.core/nth tup (wat.core/- n 1)))

;; scramble: each number n is replaced by the number n places back, counting itself as 1.
;; The accumulator, rev-pre, is the numbers seen so far, most recent first.
(wat.core/defn ss/scramble-b [tup     :- (wat.type/Vector :- [wat.type/i64])
                              rev-pre :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (wat.core/if (wat.core/empty? tup)
    []
    (wat.core/let [rp (wat.core/concat [(wat.core/first tup)] rev-pre)]
      (wat.core/concat [(ss/pick (wat.core/first tup) rp)]
                       (ss/scramble-b (wat.core/rest tup) rp)))))

(wat.core/defn ss/scramble [tup :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (ss/scramble-b tup []))
