;; The Little MLer, chapter 7 (Functions Are People, Too): functions as values, returned by
;; functions and held inside data. Our own code.

(wat.core/defn ml/identity :- [A] [x :- A] :- A x)
(wat.core/defn ml/true-maker :- [A] [x :- A] :- wat.type/bool true)

;; datatype bool_or_int = Hot of bool | Cold of int
(:wat::core::defenum :ml::BoolOrInt :wat::enum::Pure
  :Hot  [v <- :wat::core::bool]
  :Cold [n <- :wat::core::i64])

;; hot_maker returns the constructor Hot itself, bool -> bool_or_int, as ML's does: a tagged
;; variant's bare keyword is its constructor, a function value (C-022).
(wat.core/defn ml/hot-maker :- [A] [x :- A] :- [wat.type/bool :-> :ml::BoolOrInt]
  :ml::BoolOrInt.Hot)

;; datatype chain = Link of int * (int -> chain): an endless sequence, unfolded on demand.
;; It holds a function, so it is Impure (a Pure enum cannot hold one, R-002).
(:wat::core::defenum :ml::Chain :wat::enum::Impure
  :Link [i <- :wat::core::i64  f <- [:wat::core::i64 :-> :ml::Chain]])

(wat.core/defn ml/link [i :- wat.type/i64 f :- [wat.type/i64 :-> :ml::Chain]] :- :ml::Chain
  (:ml::Chain.Link {:i i :f f}))

;; The n-th item of a chain, counting from 1.
(wat.core/defn ml/chain-item [n :- wat.type/i64 c :- :ml::Chain] :- wat.type/i64
  (:wat::core::match c
    [:ml::Chain.Link {:i i :f f}
      (wat.core/if (wat.core/= n 1) i (ml/chain-item (wat.core/- n 1) (f i)))]))

;; ints: 1, 2, 3, ...; skips: every other int.
(wat.core/defn ml/ints [n :- wat.type/i64] :- :ml::Chain (ml/link (wat.core/+ n 1) ml/ints))
(wat.core/defn ml/skips [n :- wat.type/i64] :- :ml::Chain (ml/link (wat.core/+ n 2) ml/skips))

(wat.core/defn ml/divides-evenly [n :- wat.type/i64 c :- wat.type/i64] :- wat.type/bool
  (wat.core/= (:wat::core::mod n c) 0))

(wat.core/defn ml/is-mod-5-or-7 [n :- wat.type/i64] :- wat.type/bool
  (wat.core/or (ml/divides-evenly n 5) (ml/divides-evenly n 7)))

;; some_ints: the ints after n divisible by 5 or 7.
(wat.core/defn ml/some-ints [n :- wat.type/i64] :- :ml::Chain
  (wat.core/if (ml/is-mod-5-or-7 (wat.core/+ n 1))
    (ml/link (wat.core/+ n 1) ml/some-ints)
    (ml/some-ints (wat.core/+ n 1))))

(wat.core/defn ml/has-no-divisors [n :- wat.type/i64 c :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((wat.core/= c 1) true)
    ((ml/divides-evenly n c) false)
    (:else (ml/has-no-divisors n (wat.core/- c 1)))))

(wat.core/defn ml/is-prime [n :- wat.type/i64] :- wat.type/bool
  (ml/has-no-divisors n (wat.core/- n 1)))

;; primes: the primes after n.
(wat.core/defn ml/primes [n :- wat.type/i64] :- :ml::Chain
  (wat.core/if (ml/is-prime (wat.core/+ n 1))
    (ml/link (wat.core/+ n 1) ml/primes)
    (ml/primes (wat.core/+ n 1))))

;; fibs(n)(m) = Link(n + m, fibs(m)): curried, so each link's next function is a closure
;; that remembers the previous number.
(wat.core/defn ml/fibs [n :- wat.type/i64] :- [wat.type/i64 :-> :ml::Chain]
  (wat.core/fn [m :- wat.type/i64] :- :ml::Chain
    (ml/link (wat.core/+ n m) (ml/fibs m))))
