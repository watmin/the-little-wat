;; SICP §1.3 (abstractions with higher-order procedures), in wat.
;;
;; This is the section that leans hardest on procedures as VALUES: passed in, returned out, and
;; composed. All of it ports -- `sum` takes a term and a successor, `average-damp` returns a
;; closure, `deriv` returns a closure over another closure, and `repeated` builds one by
;; recursion. wat's function types carry it: `[:wat::core::f64 :-> :wat::core::f64]`.
;;
;; Two frictions, both already in the ledger and both showing up here as EXTRA PARAMETERS:
;;
;;   1. SICP's `fixed-point` defines `try` internally and recurses. A let-bound closure in wat
;;      cannot name itself (F-007; F-054 asks for the fix), so `try` is lifted to the top level
;;      and `f` is threaded through it. Same boundary §1.1's block structure hit: the internal
;;      definitions that are NOT recursive stay internal, the recursive one cannot.
;;   2. `deriv` needs a `dx`. In Scheme it is a free variable of the enclosing file; here it is a
;;      plain top-level defn, which is fine, but it means the returned closure captures a
;;      constant rather than a binding -- a distinction that matters only if anything could ever
;;      change it, and in wat nothing can (C-053).
;;
;; Floats are reported as tolerance comparisons rather than printed, so guile's and wat's float
;; formatting cannot make a passing chapter look like a failing one.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch13-higher-order.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch13-higher-order.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::F [:wat::core::f64 :-> :wat::core::f64])
(:wat::core::typealias :sicp::G [:wat::core::i64 :-> :wat::core::i64])

;; F-038, fourth sighting, and it lands on the one chapter whose whole subject is passing
;; procedures as values: a BUILTIN verb cannot be used as a value. `(:sicp::fixed-point
;; :wat::math::cos 1.0)` passes the checker and dies at run time --
;;   "not callable: expected Function, got wat::core::keyword `:wat::math::sin`"
;; -- so every builtin that SICP would hand to a higher-order procedure has to be wrapped in a
;; user-defined `defn` first. A user function IS a value; a builtin is a keyword that only the
;; call position understands.
(:wat::core::defn :sicp::sin [x <- :wat::core::f64] -> :wat::core::f64 (:wat::math::sin x))
(:wat::core::defn :sicp::cos [x <- :wat::core::f64] -> :wat::core::f64 (:wat::math::cos x))

(:wat::core::defn :sicp::near? [a <- :wat::core::f64 b <- :wat::core::f64 eps <- :wat::core::f64] -> :wat::core::bool
  (:wat::core::< (:wat::f64::abs (:wat::core::- a b)) eps))

(:wat::core::defn :sicp::square [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))
(:wat::core::defn :sicp::cube [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x (:wat::core::* x x)))
(:wat::core::defn :sicp::fsquare [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* x x))
(:wat::core::defn :sicp::fcube [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* x (:wat::core::* x x)))
(:wat::core::defn :sicp::inc [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ n 1))
(:wat::core::defn :sicp::identity [x <- :wat::core::i64] -> :wat::core::i64 x)

;; ---- procedures as ARGUMENTS: one `sum` for every summation
(:wat::core::defn :sicp::sum
  [term <- :sicp::G a <- :wat::core::i64 next <- :sicp::G b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) 0
    (:wat::core::+ (term a) (:sicp::sum term (next a) next b))))

(:wat::core::defn :sicp::sum-integers [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:sicp::sum :sicp::identity a :sicp::inc b))

(:wat::core::defn :sicp::sum-cubes [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:sicp::sum :sicp::cube a :sicp::inc b))

;; the same pattern, multiplying instead -- the abstraction was the shape, not the operator
(:wat::core::defn :sicp::product
  [term <- :sicp::G a <- :wat::core::i64 next <- :sicp::G b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) 1
    (:wat::core::* (term a) (:sicp::product term (next a) next b))))

;; ---- an integral over f64, the same shape
(:wat::core::defn :sicp::fsum
  [term <- :sicp::F a <- :wat::core::f64 next <- :sicp::F b <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::if (:wat::core::> a b) 0.0
    (:wat::core::+ (term a) (:sicp::fsum term (next a) next b))))

(:wat::core::defn :sicp::integral
  [f <- :sicp::F a <- :wat::core::f64 b <- :wat::core::f64 dx <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::* (:sicp::fsum f (:wat::core::+ a (:wat::core::/ dx 2.0))
                   (:wat::core::fn [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::+ x dx))
                   b)
    dx))

;; ---- procedures as GENERAL METHODS: half-interval search
(:wat::core::defn :sicp::search
  [f <- :sicp::F neg <- :wat::core::f64 pos <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::let [mid (:wat::core::/ (:wat::core::+ neg pos) 2.0)]
    (:wat::core::if (:wat::core::< (:wat::f64::abs (:wat::core::- pos neg)) 0.0001) mid
      (:wat::core::let [tv (f mid)]
        (:wat::core::if (:wat::core::> tv 0.0) (:sicp::search f neg mid)
          (:wat::core::if (:wat::core::< tv 0.0) (:sicp::search f mid pos) mid))))))

(:wat::core::defn :sicp::half-interval
  [f <- :sicp::F a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::let [av (f a) bv (f b)]
    (:wat::core::if (:wat::core::and (:wat::core::< av 0.0) (:wat::core::> bv 0.0)) (:sicp::search f a b)
      (:wat::core::if (:wat::core::and (:wat::core::< bv 0.0) (:wat::core::> av 0.0)) (:sicp::search f b a)
        0.0))))

;; ---- fixed points. SICP's `try` is internal and recursive; F-007 forces it out here, and `f`
;; has to be threaded through it as a parameter.
(:wat::core::defn :sicp::fp-try [f <- :sicp::F guess <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::let [next (f guess)]
    (:wat::core::if (:sicp::near? guess next 0.00001) next (:sicp::fp-try f next))))

(:wat::core::defn :sicp::fixed-point [f <- :sicp::F first-guess <- :wat::core::f64] -> :wat::core::f64
  (:sicp::fp-try f first-guess))

(:wat::core::defn :sicp::average [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::/ (:wat::core::+ a b) 2.0))

;; ---- procedures RETURNED from procedures
(:wat::core::defn :sicp::average-damp [f <- :sicp::F] -> :sicp::F
  (:wat::core::fn [x <- :wat::core::f64] -> :wat::core::f64 (:sicp::average x (f x))))

(:wat::core::defn :sicp::dx [] -> :wat::core::f64 0.00001)

(:wat::core::defn :sicp::deriv [g <- :sicp::F] -> :sicp::F
  (:wat::core::fn [x <- :wat::core::f64] -> :wat::core::f64
    (:wat::core::/ (:wat::core::- (g (:wat::core::+ x (:sicp::dx))) (g x)) (:sicp::dx))))

(:wat::core::defn :sicp::newton-transform [g <- :sicp::F] -> :sicp::F
  (:wat::core::fn [x <- :wat::core::f64] -> :wat::core::f64
    (:wat::core::- x (:wat::core::/ (g x) ((:sicp::deriv g) x)))))

(:wat::core::defn :sicp::newtons-method [g <- :sicp::F guess <- :wat::core::f64] -> :wat::core::f64
  (:sicp::fixed-point (:sicp::newton-transform g) guess))

(:wat::core::defn :sicp::sqrt-newton [x <- :wat::core::f64] -> :wat::core::f64
  (:sicp::newtons-method
    (:wat::core::fn [y <- :wat::core::f64] -> :wat::core::f64 (:wat::core::- (:sicp::fsquare y) x))
    1.0))

;; ---- one abstraction covering both square roots: a transform is itself an argument
(:wat::core::defn :sicp::fixed-point-of-transform
  [g <- :sicp::F transform <- [:sicp::F :-> :sicp::F] guess <- :wat::core::f64] -> :wat::core::f64
  (:sicp::fixed-point (transform g) guess))

(:wat::core::defn :sicp::sqrt-damp [x <- :wat::core::f64] -> :wat::core::f64
  (:sicp::fixed-point-of-transform
    (:wat::core::fn [y <- :wat::core::f64] -> :wat::core::f64 (:wat::core::/ x y))
    :sicp::average-damp 1.0))

(:wat::core::defn :sicp::sqrt-newt [x <- :wat::core::f64] -> :wat::core::f64
  (:sicp::fixed-point-of-transform
    (:wat::core::fn [y <- :wat::core::f64] -> :wat::core::f64 (:wat::core::- (:sicp::fsquare y) x))
    :sicp::newton-transform 1.0))

;; ---- compose and repeated
(:wat::core::defn :sicp::compose [f <- :sicp::G g <- :sicp::G] -> :sicp::G
  (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (f (g x))))

(:wat::core::defn :sicp::repeated [f <- :sicp::G n <- :wat::core::i64] -> :sicp::G
  (:wat::core::if (:wat::core::= n 1) f
    (:sicp::compose f (:sicp::repeated f (:wat::core::- n 1)))))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:sicp::check-chapter "oracle/sicp/ch13-higher-order.expected"
                          "sicp ch13 higher-order"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:sicp::sum-integers 1 10))
                            (int (:sicp::sum-cubes 1 10))
                            (:sicp::b (:wat::core::= (:sicp::sum-cubes 1 10) (:sicp::square (:sicp::sum-integers 1 10))))
                            (int (:sicp::sum (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))
                                   1 (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1)) 10))
                            (int (:sicp::product :sicp::identity 1 :sicp::inc 5))
                            (:sicp::b (:sicp::near? (:sicp::integral :sicp::fcube 0.0 1.0 0.001) 0.25 0.001))
                            (:sicp::b (:sicp::near? (:sicp::half-interval
                                                      (:wat::core::fn [x <- :wat::core::f64] -> :wat::core::f64
                                                        (:wat::core::- (:sicp::fsquare x) 2.0)) 1.0 2.0)
                                        1.4142135 0.001))
                            (:sicp::b (:sicp::near? (:sicp::half-interval :sicp::sin 2.0 4.0) 3.14159 0.001))
                            (:sicp::b (:sicp::near? (:sicp::fixed-point :sicp::cos 1.0) 0.7390851 0.0001))
                            (:sicp::b (:sicp::near? (:sicp::fixed-point
                                                      (:sicp::average-damp
                                                        (:wat::core::fn [y <- :wat::core::f64] -> :wat::core::f64
                                                          (:wat::core::/ 2.0 y))) 1.0)
                                        1.4142135 0.0001))
                            (:sicp::b (:sicp::near? ((:sicp::average-damp :sicp::fsquare) 10.0) 55.0 0.0001))
                            (:sicp::b (:sicp::near? ((:sicp::deriv :sicp::fcube) 5.0) 75.0 0.01))
                            (:sicp::b (:sicp::near? (:sicp::sqrt-newton 9.0) 3.0 0.0001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt-newton 2.0) 1.4142135 0.0001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt-damp 25.0) 5.0 0.0001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt-newt 25.0) 5.0 0.0001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt-damp 25.0) (:sicp::sqrt-newt 25.0) 0.001))
                            (int ((:sicp::compose :sicp::square :sicp::inc) 6))
                            (int ((:sicp::repeated :sicp::square 2) 5))
                            (int ((:sicp::repeated :sicp::inc 10) 0))))))
