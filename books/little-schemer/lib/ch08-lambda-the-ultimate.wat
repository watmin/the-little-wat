;; The Little Schemer, ch 8 (Lambda the Ultimate): the definitions. Functions as values:
;; passed in (rember-f), returned (eq?-c, the curried forms, insert-g, atom-to-function),
;; and used as collectors, i.e. continuation-passing style (the -co functions, generic
;; over what the collector returns). Needs lib/ch01-toys.wat, lib/ch04-numbers-games.wat
;; (arithmetic, number?, ast->i64, length) and lib/ch06-shadows.wat (operator, first-sub-exp,
;; second-sub-exp) loaded first. No main here.
;;
;; The book's name&co functions are spelled name-co here. That is a choice, not a limit:
;; `&` is legal inside a name (probes/name-ampersand.wat).

;; ── passing and returning functions ────────────────────────────────────────────────

;; rember-f: remove the first s for which (test? s a) holds.
(wat.core/defn ls/rember-f [test? :- [:wat::WatAST :wat::WatAST :-> wat.type/bool]
                            a     :- :wat::WatAST
                            l     :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((test? (ls/car l) a) (ls/cdr l))
    (:else (ls/cons (ls/car l) (ls/rember-f test? a (ls/cdr l))))))

;; eq?-c: curried eq?, returning a closure over a.
(wat.core/defn ls/eq?-c [a :- :wat::WatAST] :- [:wat::WatAST :-> wat.type/bool]
  (wat.core/fn [x :- :wat::WatAST] :- wat.type/bool
    (ls/eq? x a)))

;; rember-c: rember-f curried. The returned function recurs by rebuilding itself from the
;; top-level name, so no local self-reference is needed (R-001).
(wat.core/defn ls/rember-c [test? :- [:wat::WatAST :wat::WatAST :-> wat.type/bool]]
  :- [:wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/fn [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
    (wat.core/cond
      ((ls/null? l) (ls/empty-list))
      ((test? (ls/car l) a) (ls/cdr l))
      (:else (ls/cons (ls/car l) ((ls/rember-c test?) a (ls/cdr l)))))))

;; insert-g: one insert, parameterised by what to do at the match (seq).
(wat.core/defn ls/seqL [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (ls/cons new (ls/cons old l)))
(wat.core/defn ls/seqR [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (ls/cons old (ls/cons new l)))
(wat.core/defn ls/seqS [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (ls/cons new l))
(wat.core/defn ls/seqrem [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  l)

(wat.core/defn ls/insert-g [seq :- [:wat::WatAST :wat::WatAST :wat::WatAST :-> :wat::WatAST]]
  :- [:wat::WatAST :wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/fn [new :- :wat::WatAST old :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
    (wat.core/cond
      ((ls/null? l) (ls/empty-list))
      ((ls/eq? (ls/car l) old) (seq new old (ls/cdr l)))
      (:else (ls/cons (ls/car l) ((ls/insert-g seq) new old (ls/cdr l)))))))

;; atom-to-function: an operator symbol becomes the arithmetic function it names.
(wat.core/defn ls/atom-to-function [x :- :wat::WatAST]
  :- [wat.type/i64 wat.type/i64 :-> wat.type/i64]
  (wat.core/cond
    ((ls/eq? x (wat.core/quote +)) ls/o+)
    ((ls/eq? x (wat.core/quote *)) ls/o*)
    (:else ls/pow)))

;; value-f: ch 6's prefix value, dispatching through atom-to-function.
(wat.core/defn ls/value-f [nexp :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/atom? nexp)
    (ls/ast->i64 nexp)
    ((ls/atom-to-function (ls/operator nexp))
       (ls/value-f (ls/first-sub-exp nexp))
       (ls/value-f (ls/second-sub-exp nexp)))))

(wat.core/defn ls/multirember-f [test? :- [:wat::WatAST :wat::WatAST :-> wat.type/bool]]
  :- [:wat::WatAST :wat::WatAST :-> :wat::WatAST]
  (wat.core/fn [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
    (wat.core/cond
      ((ls/null? lat) (ls/empty-list))
      ((test? (ls/car lat) a) ((ls/multirember-f test?) a (ls/cdr lat)))
      (:else (ls/cons (ls/car lat) ((ls/multirember-f test?) a (ls/cdr lat)))))))

;; multiremberT: the test already knows what it is looking for.
(wat.core/defn ls/multiremberT [test? :- [:wat::WatAST :-> wat.type/bool]
                                lat   :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((test? (ls/car lat)) (ls/multiremberT test? (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ls/multiremberT test? (ls/cdr lat))))))

;; ── collectors: the answer is handed to col, which decides what to make of it ──────

;; multirember-co: col receives (the lat without a) and (the a's that were removed).
(wat.core/defn ls/multirember-co :- [T]
  [a   :- :wat::WatAST
   lat :- :wat::WatAST
   col :- [:wat::WatAST :wat::WatAST :-> T]]
  :- T
  (wat.core/cond
    ((ls/null? lat) (col (ls/empty-list) (ls/empty-list)))
    ((ls/eq? (ls/car lat) a)
     (ls/multirember-co a (ls/cdr lat)
       (wat.core/fn [newlat :- :wat::WatAST seen :- :wat::WatAST] :- T
         (col newlat (ls/cons (ls/car lat) seen)))))
    (:else
     (ls/multirember-co a (ls/cdr lat)
       (wat.core/fn [newlat :- :wat::WatAST seen :- :wat::WatAST] :- T
         (col (ls/cons (ls/car lat) newlat) seen))))))

;; multiinsertLR: new before every oldL and after every oldR.
(wat.core/defn ls/multiinsertLR [new  :- :wat::WatAST
                                 oldL :- :wat::WatAST
                                 oldR :- :wat::WatAST
                                 lat  :- :wat::WatAST]
  :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) oldL)
     (ls/cons new (ls/cons oldL (ls/multiinsertLR new oldL oldR (ls/cdr lat)))))
    ((ls/eq? (ls/car lat) oldR)
     (ls/cons oldR (ls/cons new (ls/multiinsertLR new oldL oldR (ls/cdr lat)))))
    (:else (ls/cons (ls/car lat) (ls/multiinsertLR new oldL oldR (ls/cdr lat))))))

;; multiinsertLR-co: col receives the new lat, and how many left and right inserts happened.
(wat.core/defn ls/multiinsertLR-co :- [T]
  [new  :- :wat::WatAST
   oldL :- :wat::WatAST
   oldR :- :wat::WatAST
   lat  :- :wat::WatAST
   col  :- [:wat::WatAST wat.type/i64 wat.type/i64 :-> T]]
  :- T
  (wat.core/cond
    ((ls/null? lat) (col (ls/empty-list) 0 0))
    ((ls/eq? (ls/car lat) oldL)
     (ls/multiinsertLR-co new oldL oldR (ls/cdr lat)
       (wat.core/fn [newlat :- :wat::WatAST L :- wat.type/i64 R :- wat.type/i64] :- T
         (col (ls/cons new (ls/cons oldL newlat)) (ls/add1 L) R))))
    ((ls/eq? (ls/car lat) oldR)
     (ls/multiinsertLR-co new oldL oldR (ls/cdr lat)
       (wat.core/fn [newlat :- :wat::WatAST L :- wat.type/i64 R :- wat.type/i64] :- T
         (col (ls/cons oldR (ls/cons new newlat)) L (ls/add1 R)))))
    (:else
     (ls/multiinsertLR-co new oldL oldR (ls/cdr lat)
       (wat.core/fn [newlat :- :wat::WatAST L :- wat.type/i64 R :- wat.type/i64] :- T
         (col (ls/cons (ls/car lat) newlat) L R))))))

;; ── evens-only*: numbers at any depth ─────────────────────────────────────────────

(wat.core/defn ls/even? [n :- wat.type/i64] :- wat.type/bool
  (ls/o= (ls/o* (ls/quotient n 2) 2) n))

;; evens-only*: keep only the even numbers, at any depth.
(wat.core/defn ls/evens-only* [l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) (ls/empty-list))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/even? (ls/ast->i64 (ls/car l)))
       (ls/cons (ls/car l) (ls/evens-only* (ls/cdr l)))
       (ls/evens-only* (ls/cdr l))))
    (:else (ls/cons (ls/evens-only* (ls/car l)) (ls/evens-only* (ls/cdr l))))))

;; evens-only*-co: col receives the evens-only list, the product of the evens, and the sum
;; of the odds.
(wat.core/defn ls/evens-only*-co :- [T]
  [l   :- :wat::WatAST
   col :- [:wat::WatAST wat.type/i64 wat.type/i64 :-> T]]
  :- T
  (wat.core/cond
    ((ls/null? l) (col (ls/empty-list) 1 0))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/even? (ls/ast->i64 (ls/car l)))
       (ls/evens-only*-co (ls/cdr l)
         (wat.core/fn [newl :- :wat::WatAST p :- wat.type/i64 s :- wat.type/i64] :- T
           (col (ls/cons (ls/car l) newl) (ls/o* (ls/ast->i64 (ls/car l)) p) s)))
       (ls/evens-only*-co (ls/cdr l)
         (wat.core/fn [newl :- :wat::WatAST p :- wat.type/i64 s :- wat.type/i64] :- T
           (col newl p (ls/o+ (ls/ast->i64 (ls/car l)) s))))))
    (:else
     (ls/evens-only*-co (ls/car l)
       (wat.core/fn [al :- :wat::WatAST ap :- wat.type/i64 as :- wat.type/i64] :- T
         (ls/evens-only*-co (ls/cdr l)
           (wat.core/fn [dl :- :wat::WatAST dp :- wat.type/i64 ds :- wat.type/i64] :- T
             (col (ls/cons al dl) (ls/o* ap dp) (ls/o+ as ds)))))))))
