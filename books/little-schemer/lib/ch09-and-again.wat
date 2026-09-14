;; The Little Schemer, ch 9 (...and Again, and Again, and Again): the definitions.
;; Partial functions (some inputs never finish), the argument that no will-stop? can
;; exist, then Y: recursion with no function naming itself.
;; Needs, in order: lib/ch01-toys.wat, ch02 (lat?/member?), ch03 (multirember, firsts),
;; ch04 (arithmetic, number?, ast->i64, pick), ch06 (needed by ch08), ch07 (a-pair?,
;; first, second, build, revpair) and ch08 (even?). No main here.
;;
;; Lambdas that take a function use the keyword spelling :wat::core::fn (F-010).

;; ── partial functions ────────────────────────────────────────────────────────────────

;; looking: follow numbers as 1-based positions in lat until a symbol turns up, then ask
;; whether it is a. Partial: a number that points back at itself never finishes.
(wat.core/defn ls/keep-looking [a    :- :wat::WatAST
                                sorn :- :wat::WatAST
                                lat  :- :wat::WatAST]
  :- wat.type/bool
  (wat.core/if (ls/number? sorn)
    (ls/keep-looking a (ls/pick (ls/ast->i64 sorn) lat) lat)
    (ls/eq? sorn a)))

(wat.core/defn ls/looking [a :- :wat::WatAST lat :- :wat::WatAST] :- wat.type/bool
  (ls/keep-looking a (ls/pick 1 lat) lat))

;; eternity: the most partial function of all. Defined here; never called.
(wat.core/defn ls/eternity [x :- :wat::WatAST] :- wat.type/bool
  (ls/eternity x))

;; shift: ((a b) c) becomes (a (b c)).
(wat.core/defn ls/shift [pair :- :wat::WatAST] :- :wat::WatAST
  (ls/build (ls/first (ls/first pair))
            (ls/build (ls/second (ls/first pair)) (ls/second pair))))

;; align: total, although its recursion is not on a smaller piece of its argument.
(wat.core/defn ls/align [pora :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/atom? pora) pora)
    ((ls/a-pair? (ls/first pora)) (ls/align (ls/shift pora)))
    (:else (ls/build (ls/first pora) (ls/align (ls/second pora))))))

(wat.core/defn ls/length* [pora :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/atom? pora)
    1
    (ls/o+ (ls/length* (ls/first pora)) (ls/length* (ls/second pora)))))

;; weight*: first components count double, a measure that align makes smaller.
(wat.core/defn ls/weight* [pora :- :wat::WatAST] :- wat.type/i64
  (wat.core/if (ls/atom? pora)
    1
    (ls/o+ (ls/o* (ls/weight* (ls/first pora)) 2) (ls/weight* (ls/second pora)))))

;; shuffle: partial. On a pair of pairs such as ((a b) (c d)) it swaps forever.
(wat.core/defn ls/shuffle [pora :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/atom? pora) pora)
    ((ls/a-pair? (ls/first pora)) (ls/shuffle (ls/revpair pora)))
    (:else (ls/build (ls/first pora) (ls/shuffle (ls/second pora))))))

;; C (Collatz): nobody knows whether this is total.
(wat.core/defn ls/C [n :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((ls/one? n) 1)
    ((ls/even? n) (ls/C (ls/quotient n 2)))
    (:else (ls/C (ls/add1 (ls/o* 3 n))))))

;; A (Ackermann): total, but not primitive recursive. Grows very fast.
(wat.core/defn ls/A [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((ls/zero? n) (ls/add1 m))
    ((ls/zero? m) (ls/A (ls/sub1 n) 1))
    (:else (ls/A (ls/sub1 n) (ls/A n (ls/sub1 m))))))

;; will-stop? cannot be written. Suppose it could: define a function f that calls eternity
;; exactly when (will-stop? f) says f stops. Then f stops only if it doesn't. The
;; contradiction is the chapter's point, so there is no code for it here.

;; ── Y: recursion with no function naming itself ─────────────────────────────────────

;; The typed stand-in for self-application, (mk-length mk-length): a Knot holds a function
;; that takes the Knot itself. Generic in the function's argument and result (C-010).
(:wat::core::defstruct :ls::Knot :- [A B]
  [unroll <- [(:ls::Knot :- [A B]) :-> [A :-> B]]])

;; Y (applicative order): Y le = g(knot g), where g k = le (λx. ((k.unroll k) x)).
(wat.core/defn ls/Y :- [A B]
  [le :- [[A :-> B] :-> [A :-> B]]]
  :- [A :-> B]
  (wat.core/let
    [g (wat.core/fn [k :- (:ls::Knot :- [A B])] :- [A :-> B]
         (le (wat.core/fn [x :- A] :- B
               (wat.core/let [u (:ls::Knot/unroll k)
                              h (u k)]
                 (h x)))))
     knot (:ls::Knot :unroll g)]
    (g knot)))

;; length, written without ever referring to itself: the inner function receives "length"
;; as an argument, and Y supplies it.
(wat.core/defn ls/length-Y [] :- [:wat::WatAST :-> wat.type/i64]
  (ls/Y (:wat::core::fn [length <- [:wat::WatAST :-> :wat::core::i64]]
          -> [:wat::WatAST :-> :wat::core::i64]
          (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::i64
            (:wat::core::if (ls/null? l) 0 (ls/add1 (length (ls/cdr l))))))))
