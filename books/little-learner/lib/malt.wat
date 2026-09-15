;; books/little-learner/lib/malt.wat: malt, The Little Learner's library, ported to wat by
;; hand from its learner representation (the book's Appendix A): tensors as nested vectors,
;; dual numbers for reverse-mode automatic differentiation, and the extension of scalar
;; functions to tensors of any rank.
;; Ported from malt (https://github.com/themetaschemer/malt), MIT License,
;; Copyright (c) 2021 Anurag Mendhekar, Daniel P. Friedman (vendor/malt/LICENSE).
;;
;; Every floating-point operation happens in malt's order, so results can be compared with
;; malt's bit for bit: sum-1 counts down from the last entry, a gradient accumulates as
;; (+ z g), (- z) is a true negation, and each derivative is malt's formula.
;;
;; Divergences wat forces:
;; - malt's gradient table is a hasheq keyed by the leaf duals themselves. wat values have no
;;   identity, so each leaf dual carries its position in theta, and the table is a HashMap
;;   from that position to the gradient.
;; - A dual's link is a closure, so values are an Impure enum (a Pure one may not hold a
;;   function).
;; - Racket's numbers are exact or inexact; here every number is an f64.

(:wat::core::typealias :ll::Sigma (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64]))

;; How a dual passes its gradient on: a constant passes nothing; a leaf of theta adds it to
;; its entry in the table; a computed dual's step passes it on to the duals it came from.
(:wat::core::defenum :ll::Link :wat::enum::Impure
  :Const []
  :Leaf  [id <- :wat::core::i64]
  :Step  [f <- [:wat::core::f64 :ll::Sigma :-> :ll::Sigma]])

;; A value: a number, a dual (its real part and its link), a tensor, or a list (theta, and
;; the gradients of theta, are lists).
(:wat::core::defenum :ll::V :wat::enum::Impure
  :Num  [x <- :wat::core::f64]
  :Dual [r <- :wat::core::f64  k <- :ll::Link]
  :Ten  [es <- (:wat::core::Vector :- [:ll::V])]
  :Lst  [es <- (:wat::core::Vector :- [:ll::V])])

(:wat::core::typealias :ll::Vs (:wat::core::Vector :- [:ll::V]))

(:wat::core::defn :ll::fail :- [T] [msg <- :wat::core::String] -> :T
  (:wat::kernel::assertion-failed! :message (:wat::string::concat "malt: " msg)))

;; ---- values

(:wat::core::defn :ll::num [x <- :wat::core::f64] -> :ll::V (:ll::V.Num {:x x}))
(:wat::core::defn :ll::tensor [es <- :ll::Vs] -> :ll::V (:ll::V.Ten {:es es}))
(:wat::core::defn :ll::lst [es <- :ll::Vs] -> :ll::V (:ll::V.Lst {:es es}))

(:wat::core::defn :ll::scalar? [v <- :ll::V] -> :wat::core::bool
  (:wat::core::match v
    [:ll::V.Num {:x x} true]
    [:ll::V.Dual {:r r :k k} true]
    [:ll::V.Ten {:es es} false]
    [:ll::V.Lst {:es es} false]))

;; ρ: a scalar's real part.
(:wat::core::defn :ll::rho [v <- :ll::V] -> :wat::core::f64
  (:wat::core::match v
    [:ll::V.Num {:x x} x]
    [:ll::V.Dual {:r r :k k} r]
    [:ll::V.Ten {:es es} (:ll::fail "the real part of a tensor")]
    [:ll::V.Lst {:es es} (:ll::fail "the real part of a list")]))

;; κ: a scalar's link. A plain number is a constant.
(:wat::core::defn :ll::link [v <- :ll::V] -> :ll::Link
  (:wat::core::match v
    [:ll::V.Num {:x x} (:ll::Link.Const {})]
    [:ll::V.Dual {:r r :k k} k]
    [:ll::V.Ten {:es es} (:ll::fail "the link of a tensor")]
    [:ll::V.Lst {:es es} (:ll::fail "the link of a list")]))

(:wat::core::defn :ll::elems [v <- :ll::V] -> :ll::Vs
  (:wat::core::match v
    [:ll::V.Num {:x x} (:ll::fail "the entries of a number")]
    [:ll::V.Dual {:r r :k k} (:ll::fail "the entries of a dual")]
    [:ll::V.Ten {:es es} es]
    [:ll::V.Lst {:es es} es]))

;; Lists: ref, refr, len.
(:wat::core::defn :ll::ref [l <- :ll::V i <- :wat::core::i64] -> :ll::V
  (:wat::core::nth (:ll::elems l) i))

(:wat::core::defn :ll::refr [l <- :ll::V i <- :wat::core::i64] -> :ll::V
  (:wat::core::let [es (:ll::elems l)]
    (:ll::lst (:wat::core::mapv (:wat::core::fn [j <- :wat::core::i64] -> :ll::V (:wat::core::nth es j))
                                (:wat::core::range i (:wat::core::length es))))))

(:wat::core::defn :ll::len [l <- :ll::V] -> :wat::core::i64
  (:wat::core::length (:ll::elems l)))

;; Tensors: tref, tlen, shape, rank.
(:wat::core::defn :ll::tref [t <- :ll::V i <- :wat::core::i64] -> :ll::V
  (:wat::core::nth (:ll::elems t) i))

(:wat::core::defn :ll::tlen [t <- :ll::V] -> :wat::core::i64
  (:wat::core::length (:ll::elems t)))

(:wat::core::defn :ll::shape [t <- :ll::V] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:ll::scalar? t)
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] (:ll::tlen t)) (:ll::shape (:ll::tref t 0)))))

(:wat::core::defn :ll::rank [t <- :ll::V] -> :wat::core::i64
  (:wat::core::length (:ll::shape t)))

;; ---- building and reshaping tensors (learner/tensors/B- and C-)

(:wat::core::typealias :ll::Ints (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :ll::ints-from [s <- :ll::Ints k <- :wat::core::i64] -> :ll::Ints
  (:wat::core::mapv (:wat::core::fn [j <- :wat::core::i64] -> :wat::core::i64 (:wat::core::nth s j))
                    (:wat::core::range k (:wat::core::length s))))

;; (build-tensor s f): the tensor of shape s whose entry at index idx is (f idx).
(:wat::core::defn :ll::build-tensor [s <- :ll::Ints f <- [:ll::Ints :-> :ll::V]] -> :ll::V
  (:ll::built s f (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :ll::built [s <- :ll::Ints f <- [:ll::Ints :-> :ll::V] idx <- :ll::Ints] -> :ll::V
  (:ll::tensor (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :ll::V
                                   (:wat::core::let [idx2 (:wat::core::conj idx i)]
                                     (:wat::core::if (:wat::core::= (:wat::core::length s) 1)
                                       (f idx2)
                                       (:ll::built (:ll::ints-from s 1) f idx2))))
                                 (:wat::core::range 0 (:wat::core::nth s 0)))))

(:wat::core::defn :ll::size-of [s <- :ll::Ints] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a x)) 1 s))

;; Each position's stride: the size of the dimensions after it.
(:wat::core::defn :ll::strides [s <- :ll::Ints] -> :ll::Ints
  (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:ll::size-of (:ll::ints-from s (:wat::core::+ i 1))))
                    (:wat::core::range 0 (:wat::core::length s))))

;; An index's offset among the entries in order, and back.
(:wat::core::defn :ll::flat-ref [strides <- :ll::Ints idx <- :ll::Ints] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a (:wat::core::* (:wat::core::nth strides i) (:wat::core::nth idx i))))
                     0 (:wat::core::range 0 (:wat::core::length strides))))

(:wat::core::defn :ll::invert-reference [strides <- :ll::Ints k <- :wat::core::i64 idx <- :wat::core::i64] -> :ll::Ints
  (:wat::core::if (:wat::core::= k (:wat::core::length strides))
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] (:wat::i64::quot idx (:wat::core::nth strides k)))
                        (:ll::invert-reference strides (:wat::core::+ k 1) (:wat::i64::rem idx (:wat::core::nth strides k))))))

(:wat::core::defn :ll::deep-tref [t <- :ll::V idx <- :ll::Ints] -> :ll::V
  (:wat::core::foldl (:wat::core::fn [acc <- :ll::V i <- :wat::core::i64] -> :ll::V (:ll::tref acc i)) t idx))

;; (reshape s t): t's entries, in order, in a tensor of shape s.
(:wat::core::defn :ll::reshape [s <- :ll::Ints t <- :ll::V] -> :ll::V
  (:wat::core::if (:wat::core::= (:ll::size-of s) (:ll::size-of (:ll::shape t)))
    (:wat::core::let [t-strides (:ll::strides (:ll::shape t))
                      s-strides (:ll::strides s)]
      (:ll::build-tensor s (:wat::core::fn [idx <- :ll::Ints] -> :ll::V
                             (:ll::deep-tref t (:ll::invert-reference t-strides 0 (:ll::flat-ref s-strides idx))))))
    (:ll::fail "cannot reshape: the sizes differ")))

;; A shape as a value, a list of numbers, the way malt's shape prints.
(:wat::core::defn :ll::shape-value [t <- :ll::V] -> :ll::V
  (:ll::lst (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :ll::V (:ll::num (:wat::i64::to-f64 n))) (:ll::shape t))))

;; ---- the chain rule

(:wat::core::defn :ll::at [s <- :ll::Sigma id <- :wat::core::i64] -> :wat::core::f64
  (:wat::core::match (:wat::core::get s id)
    [:wat::core::Option.Some {:value g} g]
    [:wat::core::Option.None {} 0.0]))

;; Pass gradient z to d: malt's ((κ d) d z σ). A leaf is malt's end-of-chain,
;; (hash-set σ d (+ z g)).
(:wat::core::defn :ll::chain [d <- :ll::V z <- :wat::core::f64 s <- :ll::Sigma] -> :ll::Sigma
  (:wat::core::match (:ll::link d)
    [:ll::Link.Const {} s]
    [:ll::Link.Leaf {:id id} (:wat::core::assoc s id (:wat::core::+ z (:ll::at s id)))]
    [:ll::Link.Step {:f f} (f z s)]))

;; prim1 and prim2: a scalar function from its real-part function and its derivative.
;; malt's binary ∇-fn returns both gradients at once; here they are two functions, each
;; computing its own formula exactly as malt's does.
(:wat::core::defn :ll::prim1
  [rho-fn <- [:wat::core::f64 :-> :wat::core::f64]
   grad-fn <- [:wat::core::f64 :wat::core::f64 :-> :wat::core::f64]]
  -> [:ll::V :-> :ll::V]
  (:wat::core::fn [da <- :ll::V] -> :ll::V
    (:wat::core::let [ra (:ll::rho da)]
      (:ll::V.Dual {:r (rho-fn ra)
                    :k (:ll::Link.Step {:f (:wat::core::fn [z <- :wat::core::f64 s <- :ll::Sigma] -> :ll::Sigma
                                              (:ll::chain da (grad-fn ra z) s))})}))))

(:wat::core::defn :ll::prim2
  [rho-fn <- [:wat::core::f64 :wat::core::f64 :-> :wat::core::f64]
   ga-fn <- [:wat::core::f64 :wat::core::f64 :wat::core::f64 :-> :wat::core::f64]
   gb-fn <- [:wat::core::f64 :wat::core::f64 :wat::core::f64 :-> :wat::core::f64]]
  -> [:ll::V :ll::V :-> :ll::V]
  (:wat::core::fn [da <- :ll::V db <- :ll::V] -> :ll::V
    (:wat::core::let [ra (:ll::rho da)
                      rb (:ll::rho db)]
      (:ll::V.Dual {:r (rho-fn ra rb)
                    :k (:ll::Link.Step {:f (:wat::core::fn [z <- :wat::core::f64 s <- :ll::Sigma] -> :ll::Sigma
                                              (:ll::chain db (gb-fn ra rb z) (:ll::chain da (ga-fn ra rb z) s)))})}))))

;; ---- scalar operations, malt's formulas (learner/ext-ops/A-scalar-ops.rkt)

(:wat::core::defn :ll::neg [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* -1.0 x))

(:wat::core::defn :ll::+-0-0 [da <- :ll::V db <- :ll::V] -> :ll::V
  ((:ll::prim2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::+ a b))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 z)
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 z))
   da db))

(:wat::core::defn :ll::--0-0 [da <- :ll::V db <- :ll::V] -> :ll::V
  ((:ll::prim2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::- a b))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 z)
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 (:ll::neg z)))
   da db))

(:wat::core::defn :ll::*-0-0 [da <- :ll::V db <- :ll::V] -> :ll::V
  ((:ll::prim2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* a b))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* b z))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* a z)))
   da db))

(:wat::core::defn :ll::/-0-0 [da <- :ll::V db <- :ll::V] -> :ll::V
  ((:ll::prim2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::/ a b))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64
                 (:wat::core::* z (:wat::core::/ 1.0 b)))
               (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64
                 (:wat::core::* z (:wat::core::/ (:ll::neg a) (:wat::core::* b b)))))
   da db))

(:wat::core::defn :ll::exp-0 [da <- :ll::V] -> :ll::V
  ((:ll::prim1 (:wat::core::fn [a <- :wat::core::f64] -> :wat::core::f64 (:wat::math::exp a))
               (:wat::core::fn [a <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* z (:wat::math::exp a))))
   da))

(:wat::core::defn :ll::log-0 [da <- :ll::V] -> :ll::V
  ((:ll::prim1 (:wat::core::fn [a <- :wat::core::f64] -> :wat::core::f64 (:wat::math::ln a))
               (:wat::core::fn [a <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* z (:wat::core::/ 1.0 a))))
   da))

(:wat::core::defn :ll::sqrt-0 [da <- :ll::V] -> :ll::V
  ((:ll::prim1 (:wat::core::fn [a <- :wat::core::f64] -> :wat::core::f64 (:wat::math::sqrt a))
               (:wat::core::fn [a <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64
                 (:wat::core::/ z (:wat::core::* 2.0 (:wat::math::sqrt a)))))
   da))

(:wat::core::defn :ll::abs-0 [da <- :ll::V] -> :ll::V
  ((:ll::prim1 (:wat::core::fn [a <- :wat::core::f64] -> :wat::core::f64 (:wat::f64::abs a))
               (:wat::core::fn [a <- :wat::core::f64 z <- :wat::core::f64] -> :wat::core::f64
                 (:wat::core::if (:wat::core::< a 0.0) (:ll::neg z) z)))
   da))

;; ---- extension (learner/tensors/D-extend.rkt)

(:wat::core::defn :ll::of-rank? [n <- :wat::core::i64 t <- :ll::V] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= n 0) (:ll::scalar? t))
    ((:ll::scalar? t) false)
    (:else (:ll::of-rank? (:wat::core::- n 1) (:ll::tref t 0)))))

(:wat::core::defn :ll::of-ranks? [n <- :wat::core::i64 t <- :ll::V m <- :wat::core::i64 u <- :ll::V] -> :wat::core::bool
  (:wat::core::if (:ll::of-rank? n t) (:ll::of-rank? m u) false))

(:wat::core::defn :ll::tmap [g <- [:ll::V :-> :ll::V] t <- :ll::V] -> :ll::V
  (:ll::tensor (:wat::core::mapv g (:ll::elems t))))

(:wat::core::defn :ll::tmap2 [g <- [:ll::V :ll::V :-> :ll::V] t <- :ll::V u <- :ll::V] -> :ll::V
  (:wat::core::let [es (:ll::elems t)
                    fs (:ll::elems u)]
    (:ll::tensor (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :ll::V (g (:wat::core::nth es i) (:wat::core::nth fs i)))
                                   (:wat::core::range 0 (:wat::core::length es))))))

(:wat::core::defn :ll::ext1 [f <- [:ll::V :-> :ll::V] n <- :wat::core::i64] -> [:ll::V :-> :ll::V]
  (:wat::core::fn [t <- :ll::V] -> :ll::V
    (:wat::core::if (:ll::of-rank? n t) (f t) (:ll::tmap (:ll::ext1 f n) t))))

(:wat::core::defn :ll::ext2 [f <- [:ll::V :ll::V :-> :ll::V] n <- :wat::core::i64 m <- :wat::core::i64] -> [:ll::V :ll::V :-> :ll::V]
  (:wat::core::fn [t <- :ll::V u <- :ll::V] -> :ll::V
    (:wat::core::if (:ll::of-ranks? n t m u) (f t u) (:ll::desc (:ll::ext2 f n m) n t m u))))

(:wat::core::defn :ll::desc [g <- [:ll::V :ll::V :-> :ll::V] n <- :wat::core::i64 t <- :ll::V m <- :wat::core::i64 u <- :ll::V] -> :ll::V
  (:wat::core::cond
    ((:ll::of-rank? n t) (:ll::desc-u g t u))
    ((:ll::of-rank? m u) (:ll::desc-t g t u))
    ((:wat::core::= (:ll::tlen t) (:ll::tlen u)) (:ll::tmap2 g t u))
    ((:wat::core::> (:ll::rank t) (:ll::rank u)) (:ll::desc-t g t u))
    ((:wat::core::> (:ll::rank u) (:ll::rank t)) (:ll::desc-u g t u))
    (:else (:ll::fail "shapes are incompatible for ext2"))))

(:wat::core::defn :ll::desc-t [g <- [:ll::V :ll::V :-> :ll::V] t <- :ll::V u <- :ll::V] -> :ll::V
  (:ll::tmap (:wat::core::fn [e <- :ll::V] -> :ll::V (g e u)) t))

(:wat::core::defn :ll::desc-u [g <- [:ll::V :ll::V :-> :ll::V] t <- :ll::V u <- :ll::V] -> :ll::V
  (:ll::tmap (:wat::core::fn [e <- :ll::V] -> :ll::V (g t e)) u))

;; ---- the extended operations the book uses

(:wat::core::defn :ll::+ [t <- :ll::V u <- :ll::V] -> :ll::V ((:ll::ext2 :ll::+-0-0 0 0) t u))
(:wat::core::defn :ll::- [t <- :ll::V u <- :ll::V] -> :ll::V ((:ll::ext2 :ll::--0-0 0 0) t u))
(:wat::core::defn :ll::* [t <- :ll::V u <- :ll::V] -> :ll::V ((:ll::ext2 :ll::*-0-0 0 0) t u))
(:wat::core::defn :ll::/ [t <- :ll::V u <- :ll::V] -> :ll::V ((:ll::ext2 :ll::/-0-0 0 0) t u))
(:wat::core::defn :ll::exp [t <- :ll::V] -> :ll::V ((:ll::ext1 :ll::exp-0 0) t))
(:wat::core::defn :ll::log [t <- :ll::V] -> :ll::V ((:ll::ext1 :ll::log-0 0) t))
(:wat::core::defn :ll::sqrt [t <- :ll::V] -> :ll::V ((:ll::ext1 :ll::sqrt-0 0) t))
(:wat::core::defn :ll::abs [t <- :ll::V] -> :ll::V ((:ll::ext1 :ll::abs-0 0) t))
(:wat::core::defn :ll::sqr [t <- :ll::V] -> :ll::V (:ll::* t t))

;; sum-1 adds a rank-1 tensor's entries from the last down, starting from 0.0, as malt's does.
(:wat::core::defn :ll::summed [t <- :ll::V i <- :wat::core::i64 a <- :ll::V] -> :ll::V
  (:wat::core::let [next-a (:ll::+ a (:ll::tref t i))]
    (:wat::core::if (:wat::core::= i 0) next-a (:ll::summed t (:wat::core::- i 1) next-a))))

(:wat::core::defn :ll::sum-1 [t <- :ll::V] -> :ll::V
  (:ll::summed t (:wat::core::- (:ll::tlen t) 1) (:ll::num 0.0)))

(:wat::core::defn :ll::sum [t <- :ll::V] -> :ll::V ((:ll::ext1 :ll::sum-1 1) t))

;; ---- gradients (learner/autodiff/A-autodiff.rkt)

;; map*: f over every scalar of a list or tensor.
(:wat::core::defn :ll::map* [f <- [:ll::V :-> :ll::V] y <- :ll::V] -> :ll::V
  (:wat::core::match y
    [:ll::V.Num {:x x} (f y)]
    [:ll::V.Dual {:r r :k k} (f y)]
    [:ll::V.Ten {:es es} (:ll::tensor (:wat::core::mapv (:wat::core::fn [e <- :ll::V] -> :ll::V (:ll::map* f e)) es))]
    [:ll::V.Lst {:es es} (:ll::lst (:wat::core::mapv (:wat::core::fn [e <- :ll::V] -> :ll::V (:ll::map* f e)) es))]))

;; malt's (map* dual* theta), with each leaf numbered in order: the number is its key in the
;; gradient table.
(:wat::core::defstruct :ll::Numbered [v <- :ll::V  next <- :wat::core::i64])
(:wat::core::defstruct :ll::NumberedVs [vs <- :ll::Vs  next <- :wat::core::i64])

(:wat::core::defn :ll::dualize [y <- :ll::V next <- :wat::core::i64] -> :ll::Numbered
  (:wat::core::match y
    [:ll::V.Num {:x x} (:ll::Numbered :v (:ll::V.Dual {:r x :k (:ll::Link.Leaf {:id next})}) :next (:wat::core::+ next 1))]
    [:ll::V.Dual {:r r :k k} (:ll::Numbered :v (:ll::V.Dual {:r r :k (:ll::Link.Leaf {:id next})}) :next (:wat::core::+ next 1))]
    [:ll::V.Ten {:es es} (:wat::core::let [n (:ll::dualize-all es next)] (:ll::Numbered :v (:ll::tensor (:ll::NumberedVs/vs n)) :next (:ll::NumberedVs/next n)))]
    [:ll::V.Lst {:es es} (:wat::core::let [n (:ll::dualize-all es next)] (:ll::Numbered :v (:ll::lst (:ll::NumberedVs/vs n)) :next (:ll::NumberedVs/next n)))]))

(:wat::core::defn :ll::dualize-all [es <- :ll::Vs next <- :wat::core::i64] -> :ll::NumberedVs
  (:wat::core::foldl (:wat::core::fn [acc <- :ll::NumberedVs e <- :ll::V] -> :ll::NumberedVs
                       (:wat::core::let [n (:ll::dualize e (:ll::NumberedVs/next acc))]
                         (:ll::NumberedVs :vs (:wat::core::conj (:ll::NumberedVs/vs acc) (:ll::Numbered/v n)) :next (:ll::Numbered/next n))))
                     (:ll::NumberedVs :vs (:wat::core::Vector :- [:ll::V]) :next next)
                     es))

(:wat::core::defn :ll::leaf-id [d <- :ll::V] -> :wat::core::i64
  (:wat::core::match (:ll::link d)
    [:ll::Link.Leaf {:id id} id]
    [:ll::Link.Const {} (:ll::fail "not a leaf of theta")]
    [:ll::Link.Step {:f f} (:ll::fail "not a leaf of theta")]))

;; ∇σ: send 1.0 back from every scalar of y. A list goes first to last; a tensor last to
;; first, as malt's ∇σ-list and ∇σ-vector do.
(:wat::core::defn :ll::grad-sigma [y <- :ll::V s <- :ll::Sigma] -> :ll::Sigma
  (:wat::core::match y
    [:ll::V.Num {:x x} (:ll::chain y 1.0 s)]
    [:ll::V.Dual {:r r :k k} (:ll::chain y 1.0 s)]
    [:ll::V.Ten {:es es} (:wat::core::foldl (:wat::core::fn [acc <- :ll::Sigma e <- :ll::V] -> :ll::Sigma (:ll::grad-sigma e acc)) s (:wat::core::reverse es))]
    [:ll::V.Lst {:es es} (:wat::core::foldl (:wat::core::fn [acc <- :ll::Sigma e <- :ll::V] -> :ll::Sigma (:ll::grad-sigma e acc)) s es)]))

;; ∇ (gradient-of): the gradient of f at theta, shaped like theta.
(:wat::core::defn :ll::gradient-of [f <- [:ll::V :-> :ll::V] theta <- :ll::V] -> :ll::V
  (:wat::core::let [wrt (:ll::Numbered/v (:ll::dualize theta 0))
                    s (:ll::grad-sigma (f wrt) (:wat::core::HashMap :- [:wat::core::i64 :wat::core::f64]))]
    (:ll::map* (:wat::core::fn [d <- :ll::V] -> :ll::V (:ll::num (:ll::at s (:ll::leaf-id d)))) wrt)))

;; ---- the book's functions (malted/)

;; ((line x) theta) = w*x + b, theta = (w b)
(:wat::core::defn :ll::line [xs <- :ll::V] -> [:ll::V :-> :ll::V]
  (:wat::core::fn [theta <- :ll::V] -> :ll::V
    (:ll::+ (:ll::* (:ll::ref theta 0) xs) (:ll::ref theta 1))))

;; (dot-product w t) = (sum (* w t)) (malted/A-core.rkt)
(:wat::core::defn :ll::dot-product [w <- :ll::V t <- :ll::V] -> :ll::V
  (:ll::sum (:ll::* w t)))

;; ((quad x) theta) = a*x^2 + (b*x + c), theta = (a b c) (malted/B-layer-fns.rkt)
(:wat::core::defn :ll::quad [x <- :ll::V] -> [:ll::V :-> :ll::V]
  (:wat::core::fn [theta <- :ll::V] -> :ll::V
    (:wat::core::let [a (:ll::ref theta 0)
                      b (:ll::ref theta 1)
                      c (:ll::ref theta 2)]
      (:ll::+ (:ll::* a (:ll::sqr x)) (:ll::+ (:ll::* b x) c)))))

;; ((plane t) theta) = (dot-product w t) + b, theta = (w b)
(:wat::core::defn :ll::plane [t <- :ll::V] -> [:ll::V :-> :ll::V]
  (:wat::core::fn [theta <- :ll::V] -> :ll::V
    (:ll::+ (:ll::dot-product (:ll::ref theta 0) t) (:ll::ref theta 1))))

;; (((l2-loss target) xs ys) theta): the sum of the squared differences between ys and the
;; target's predictions (malted/C-loss.rkt).
(:wat::core::defn :ll::l2-loss [target <- [:ll::V :-> [:ll::V :-> :ll::V]]] -> [:ll::V :ll::V :-> [:ll::V :-> :ll::V]]
  (:wat::core::fn [xs <- :ll::V ys <- :ll::V] -> [:ll::V :-> :ll::V]
    (:wat::core::fn [theta <- :ll::V] -> :ll::V
      (:wat::core::let [pred-ys ((target xs) theta)]
        (:ll::sum (:ll::sqr (:ll::- ys pred-ys)))))))

;; revise: f applied to theta revs times (malted/D-gradient-descent.rkt).
(:wat::core::defn :ll::revise [f <- [:ll::V :-> :ll::V] revs <- :wat::core::i64 theta <- :ll::V] -> :ll::V
  (:wat::core::if (:wat::core::= revs 0) theta (:ll::revise f (:wat::core::- revs 1) (f theta))))

;; ---- hyperparameters and gradient descent (malted/D- through I-)

;; malt's hyperparameters (revs, alpha, batch-size, mu, beta) are dynamically bound globals,
;; set by with-hypers inside a dynamic-wind (tools/A-hypers.rkt). wat has no dynamic binding
;; and no ambient mutable state, so they are a value, passed to whatever needs them.
(:wat::core::defstruct :ll::Hypers
  [revs <- :wat::core::i64
   alpha <- :wat::core::f64
   batch-size <- :wat::core::i64
   mu <- :wat::core::f64
   beta <- :wat::core::f64])

(:wat::core::defn :ll::hypers [revs <- :wat::core::i64 alpha <- :wat::core::f64] -> :ll::Hypers
  (:ll::Hypers :revs revs :alpha alpha :batch-size 0 :mu 0.0 :beta 0.0))

(:wat::core::defn :ll::each [f <- [:ll::V :-> :ll::V] l <- :ll::V] -> :ll::V
  (:ll::lst (:wat::core::mapv f (:ll::elems l))))

;; malt's (gradient-descent inflate deflate update): inflate each parameter, then revs times
;; update each inflated parameter with the gradient taken at the deflated ones, then deflate.
(:wat::core::defn :ll::gradient-descent
  [h <- :ll::Hypers
   inflate <- [:ll::V :-> :ll::V]
   deflate <- [:ll::V :-> :ll::V]
   update <- [:ll::V :ll::V :-> :ll::V]]
  -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:wat::core::fn [obj <- [:ll::V :-> :ll::V] theta <- :ll::V] -> :ll::V
    (:wat::core::let [f (:wat::core::fn [big-theta <- :ll::V] -> :ll::V
                          (:wat::core::let [g (:ll::gradient-of obj (:ll::each deflate big-theta))]
                            (:ll::lst (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :ll::V (update (:ll::ref big-theta i) (:ll::ref g i)))
                                                        (:wat::core::range 0 (:ll::len big-theta))))))]
      (:ll::each deflate (:ll::revise f (:ll::Hypers/revs h) (:ll::each inflate theta))))))

(:wat::core::defn :ll::identity [p <- :ll::V] -> :ll::V p)

;; ---- the non-dual operators (learner/ext-ops/J-nd-ops.rkt)
;;
;; malt's descents update parameters with extended operators that make no duals
;; (base-no-duals.rkt): the same arithmetic on real parts, answering plain numbers, so an
;; accompaniment (a velocity, a smoothed square) never carries a link back into the last
;; revision.

(:wat::core::defn :ll::rho2 [f <- [:wat::core::f64 :wat::core::f64 :-> :wat::core::f64]] -> [:ll::V :ll::V :-> :ll::V]
  (:wat::core::fn [a <- :ll::V b <- :ll::V] -> :ll::V (:ll::num (f (:ll::rho a) (:ll::rho b)))))

(:wat::core::defn :ll::rho1 [f <- [:wat::core::f64 :-> :wat::core::f64]] -> [:ll::V :-> :ll::V]
  (:wat::core::fn [a <- :ll::V] -> :ll::V (:ll::num (f (:ll::rho a)))))

(:wat::core::defn :ll::+-rho [t <- :ll::V u <- :ll::V] -> :ll::V
  ((:ll::ext2 (:ll::rho2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::+ a b))) 0 0) t u))
(:wat::core::defn :ll::--rho [t <- :ll::V u <- :ll::V] -> :ll::V
  ((:ll::ext2 (:ll::rho2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::- a b))) 0 0) t u))
(:wat::core::defn :ll::*-rho [t <- :ll::V u <- :ll::V] -> :ll::V
  ((:ll::ext2 (:ll::rho2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* a b))) 0 0) t u))
(:wat::core::defn :ll::/-rho [t <- :ll::V u <- :ll::V] -> :ll::V
  ((:ll::ext2 (:ll::rho2 (:wat::core::fn [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64 (:wat::core::/ a b))) 0 0) t u))
(:wat::core::defn :ll::sqrt-rho [t <- :ll::V] -> :ll::V
  ((:ll::ext1 (:ll::rho1 (:wat::core::fn [a <- :wat::core::f64] -> :wat::core::f64 (:wat::math::sqrt a))) 0) t))
(:wat::core::defn :ll::sqr-rho [t <- :ll::V] -> :ll::V (:ll::*-rho t t))

;; zeroes: 0.0 in place of every scalar (zeroes-ρ)
(:wat::core::defn :ll::zeroes [t <- :ll::V] -> :ll::V
  ((:ll::ext1 (:wat::core::fn [x <- :ll::V] -> :ll::V (:ll::num 0.0)) 0) t))

;; smooth: decay-rate * average + (1.0 - decay-rate) * g (malted/E-gd-common.rkt)
(:wat::core::defn :ll::smooth [decay-rate <- :ll::V average <- :ll::V g <- :ll::V] -> :ll::V
  (:ll::+-rho (:ll::*-rho decay-rate average) (:ll::*-rho (:ll::--rho (:ll::num 1.0) decay-rate) g)))

;; ---- the descents (malted/F- through I-)

;; naked: p - alpha * g
(:wat::core::defn :ll::naked-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h :ll::identity :ll::identity
    (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V (:ll::--rho pa (:ll::*-rho (:ll::num (:ll::Hypers/alpha h)) g)))))

(:wat::core::defn :ll::first-of [pa <- :ll::V] -> :ll::V (:ll::ref pa 0))

(:wat::core::defn :ll::with-zeroes [p <- :ll::V] -> :ll::V
  (:ll::lst (:wat::core::Vector :- [:ll::V] p (:ll::zeroes p))))

;; velocity: v = mu * (last v) - alpha * g, and p + v (malted/G-velocity.rkt)
(:wat::core::defn :ll::velocity-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h :ll::with-zeroes :ll::first-of
    (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V
      (:wat::core::let [v (:ll::--rho (:ll::*-rho (:ll::num (:ll::Hypers/mu h)) (:ll::ref pa 1))
                                      (:ll::*-rho (:ll::num (:ll::Hypers/alpha h)) g))]
        (:ll::lst (:wat::core::Vector :- [:ll::V] (:ll::+-rho (:ll::ref pa 0) v) v))))))

;; rms: r = (smooth beta (last r) g^2), alpha-hat = alpha / (sqrt r + epsilon), and
;; p - alpha-hat * g. malt's rms has its own epsilon, 10e-8 (malted/H-rms.rkt).
(:wat::core::defn :ll::rms-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h :ll::with-zeroes :ll::first-of
    (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V
      (:wat::core::let [r (:ll::smooth (:ll::num (:ll::Hypers/beta h)) (:ll::ref pa 1) (:ll::sqr-rho g))
                        alpha-hat (:ll::/-rho (:ll::num (:ll::Hypers/alpha h)) (:ll::+-rho (:ll::sqrt-rho r) (:ll::num 10e-8)))]
        (:ll::lst (:wat::core::Vector :- [:ll::V] (:ll::--rho (:ll::ref pa 0) (:ll::*-rho alpha-hat g)) r))))))

;; adam: r as rms's, v = (smooth mu (last v) g), and p - alpha-hat * v, with the common
;; epsilon, 1.0e-8 (malted/I-adam.rkt, E-gd-common.rkt).
(:wat::core::defn :ll::adam-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h
    (:wat::core::fn [p <- :ll::V] -> :ll::V
      (:wat::core::let [zeroed (:ll::zeroes p)] (:ll::lst (:wat::core::Vector :- [:ll::V] p zeroed zeroed))))
    :ll::first-of
    (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V
      (:wat::core::let [r (:ll::smooth (:ll::num (:ll::Hypers/beta h)) (:ll::ref pa 2) (:ll::sqr-rho g))
                        alpha-hat (:ll::/-rho (:ll::num (:ll::Hypers/alpha h)) (:ll::+-rho (:ll::sqrt-rho r) (:ll::num 1.0e-8)))
                        v (:ll::smooth (:ll::num (:ll::Hypers/mu h)) (:ll::ref pa 1) g)]
        (:ll::lst (:wat::core::Vector :- [:ll::V] (:ll::--rho (:ll::ref pa 0) (:ll::*-rho alpha-hat v)) v r))))))
