;; SICP §1.1 (the elements of programming), in wat.
;;
;; The section's subject is that a procedure definition is an abstraction whose inside you may
;; then forget, and that `if` must NOT evaluate both arms. Both port without friction: wat's
;; `defn` is the abstraction and `:wat::core::if` is a special form, so the diverging arm below
;; is never entered.
;;
;; The one place the section does NOT port is §1.1.8, BLOCK STRUCTURE. SICP's final `sqrt` nests
;; `good-enough?`, `improve` and `iter` inside `sqrt`, so they share `x` without passing it. wat
;; can capture `x` in a `let`-bound closure, but a let-bound closure cannot name ITSELF (F-007,
;; and F-054 asks for the fix), so the recursive helper has to be lifted to the top level and `x`
;; threaded through every call by hand. The two versions below are written both ways to show that
;; the difference is exactly one thing: whether the recursive helper can be internal.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch11-elements.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch11-elements.wat

(:wat::load-file! "lib/check.wat")

;; ---- compound procedures, and composing them
(:wat::core::defn :sicp::square [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))

(:wat::core::defn :sicp::sum-of-squares [x <- :wat::core::i64 y <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ (:sicp::square x) (:sicp::square y)))

(:wat::core::defn :sicp::f [a <- :wat::core::i64] -> :wat::core::i64
  (:sicp::sum-of-squares (:wat::core::+ a 1) (:wat::core::* a 2)))

;; ---- conditionals
(:wat::core::defn :sicp::abs-val [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< x 0) (:wat::core::- 0 x) x))

;; `if` is a SPECIAL FORM, not a call. If it were a call, applicative order would evaluate this
;; arm before choosing, and the program would not terminate. wat has TCO, so this would spin
;; rather than overflow -- it is never entered, which is the point.
(:wat::core::defn :sicp::loop-forever [n <- :wat::core::i64] -> :wat::core::i64
  (:sicp::loop-forever n))

(:wat::core::defn :sicp::safe-if-demo [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> x 0) x (:sicp::loop-forever x)))

;; ---- Newton's method for square roots
(:wat::core::defn :sicp::fabs [x <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::if (:wat::core::< x 0.0) (:wat::core::- 0.0 x) x))

(:wat::core::defn :sicp::fsquare [x <- :wat::core::f64] -> :wat::core::f64 (:wat::core::* x x))

(:wat::core::defn :sicp::average [a <- :wat::core::f64 b <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::/ (:wat::core::+ a b) 2.0))

(:wat::core::defn :sicp::good-enough? [guess <- :wat::core::f64 x <- :wat::core::f64] -> :wat::core::bool
  (:wat::core::< (:sicp::fabs (:wat::core::- (:sicp::fsquare guess) x)) 0.001))

(:wat::core::defn :sicp::improve [guess <- :wat::core::f64 x <- :wat::core::f64] -> :wat::core::f64
  (:sicp::average guess (:wat::core::/ x guess)))

(:wat::core::defn :sicp::sqrt-iter [guess <- :wat::core::f64 x <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::if (:sicp::good-enough? guess x) guess
    (:sicp::sqrt-iter (:sicp::improve guess x) x)))

(:wat::core::defn :sicp::my-sqrt [x <- :wat::core::f64] -> :wat::core::f64 (:sicp::sqrt-iter 1.0 x))

;; ---- §1.1.8 block structure, as close as wat gets.
;; SICP nests all three helpers inside `sqrt` so they share `x`. Here the two NON-recursive
;; helpers can genuinely be internal -- they are let-bound closures capturing `x`, and neither
;; takes `x` as a parameter, which is the whole of what block structure buys. The RECURSIVE one
;; cannot: a let-bound closure has no name to call itself by (F-007), so `iter` stays at the top
;; level and `x` is threaded after all. The internal/external line falls exactly at recursion.
(:wat::core::defn :sicp::sqrt2 [x <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::let [good? (:wat::core::fn [guess <- :wat::core::f64] -> :wat::core::bool
                            (:wat::core::< (:sicp::fabs (:wat::core::- (:sicp::fsquare guess) x)) 0.001))
                    improve2 (:wat::core::fn [guess <- :wat::core::f64] -> :wat::core::f64
                               (:sicp::average guess (:wat::core::/ x guess)))]
    ;; and here the nesting stops: `iter` must be a top-level defn to be recursive
    (:sicp::sqrt2-iter good? improve2 1.0)))

(:wat::core::defn :sicp::sqrt2-iter
  [good? <- [:wat::core::f64 :-> :wat::core::bool]
   improve2 <- [:wat::core::f64 :-> :wat::core::f64]
   guess <- :wat::core::f64] -> :wat::core::f64
  (:wat::core::if (good? guess) guess (:sicp::sqrt2-iter good? improve2 (improve2 guess))))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::near? [a <- :wat::core::f64 b <- :wat::core::f64 eps <- :wat::core::f64] -> :wat::core::bool
  (:wat::core::< (:sicp::fabs (:wat::core::- a b)) eps))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:sicp::check-chapter "oracle/sicp/ch11-elements.expected"
                          "sicp ch11 elements"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:sicp::square 21))
                            (int (:sicp::sum-of-squares 3 4))
                            (int (:sicp::f 5))
                            (int (:sicp::abs-val -7))
                            (int (:sicp::abs-val 7))
                            (int (:sicp::safe-if-demo 42))
                            (:sicp::b (:sicp::near? (:sicp::my-sqrt 9.0) 3.0 0.001))
                            (:sicp::b (:sicp::near? (:sicp::my-sqrt 2.0) 1.4142135 0.001))
                            (:sicp::b (:sicp::near? (:sicp::fsquare (:sicp::my-sqrt 25.0)) 25.0 0.001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt2 9.0) 3.0 0.001))
                            (:sicp::b (:sicp::near? (:sicp::sqrt2 2.0) (:sicp::my-sqrt 2.0) 0.0000001))
                            (int (:wat::core::+ (:sicp::square 6) (:sicp::square 10)))
                            (:sicp::b (:wat::core::= (:sicp::f 5) (:wat::core::+ 36 100)))))))
