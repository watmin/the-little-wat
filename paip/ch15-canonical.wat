;; PAIP chapter 15 (symbolic mathematics with canonical forms), in wat.
;;
;; A polynomial held as a dense vector of coefficients, lowest degree first, trimmed of trailing
;; zeros. The contrast with chapter 8 (C-083) is the whole point of the chapter, and having both
;; ports in this repository makes it concrete rather than rhetorical:
;;
;;   ch8, REWRITE RULES     `x + x` and `2x` are different trees. A rule set may or may not
;;                          reconcile them, the simplifier runs to a fixed point hoping, and two
;;                          of the rules could not be written as patterns at all (C-083).
;;   ch15, CANONICAL FORM   `x + x` and `2x` are the SAME VECTOR the moment they are built.
;;                          `(0 2)` equals `(0 2)`. There is no simplification step to run.
;;
;; The consequence the chapter is really selling: an identity becomes **checkable** rather than
;; provable. `(x+1)² = x² + 2x + 1` is decided by comparing `(1 2 1)` with `(1 2 1)` -- and a FALSE
;; identity is refuted just as cheaply, which a rewrite system cannot promise, because failing to
;; find a proof is not the same as finding a disproof.
;;
;; The wat note is short: this is the one algebra representation in the repository that wants a
;; **dense integer-indexed vector and never updates a cell** -- it builds a new one each time -- so
;; it is the first array-shaped workload here that **F-104 does not touch**. Recording that matters
;; as much as recording the six that did (C-086): the missing positional update hurts exactly the
;; programs that mutate one cell, and not the programs that rebuild.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch15-canonical.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch15-canonical.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Poly (:wat::core::Vector :- [:wat::core::i64]))

;; the canonical form: no trailing zeros, and the zero polynomial is exactly (0)
(:wat::core::defn :paip::trim [p <- :paip::Poly] -> :paip::Poly
  (:wat::core::let [n (:paip::last-nonzero p (:wat::core::- (:wat::core::length p) 1))]
    (:wat::core::if (:wat::core::< n 0) (:wat::core::Vector :- [:wat::core::i64] 0)
      (:paip::take-k p 0 (:wat::core::+ n 1) (:wat::core::Vector :- [:wat::core::i64])))))

(:wat::core::defn :paip::last-nonzero [p <- :paip::Poly i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< i 0) -1
    (:wat::core::if (:wat::core::= (:wat::core::nth p i) 0) (:paip::last-nonzero p (:wat::core::- i 1)) i)))

(:wat::core::defn :paip::take-k [p <- :paip::Poly i <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Poly] -> :paip::Poly
  (:wat::core::if (:wat::core::>= i n) acc
    (:paip::take-k p (:wat::core::+ i 1) n (:wat::core::conj acc (:wat::core::nth p i)))))

(:wat::core::defn :paip::degree [p <- :paip::Poly] -> :wat::core::i64
  (:wat::core::- (:wat::core::length p) 1))

(:wat::core::defn :paip::coeff [p <- :paip::Poly n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n (:wat::core::length p)) (:wat::core::nth p n) 0))

(:wat::core::defn :paip::imax [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

(:wat::core::defn :paip::p+ [a <- :paip::Poly b <- :paip::Poly] -> :paip::Poly
  (:paip::trim (:paip::add-loop a b 0 (:paip::imax (:wat::core::length a) (:wat::core::length b))
                 (:wat::core::Vector :- [:wat::core::i64]))))

(:wat::core::defn :paip::add-loop [a <- :paip::Poly b <- :paip::Poly i <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Poly] -> :paip::Poly
  (:wat::core::if (:wat::core::>= i n) acc
    (:paip::add-loop a b (:wat::core::+ i 1) n
      (:wat::core::conj acc (:wat::core::+ (:paip::coeff a i) (:paip::coeff b i))))))

(:wat::core::defn :paip::p* [a <- :paip::Poly b <- :paip::Poly] -> :paip::Poly
  (:paip::trim (:paip::mul-loop a b 0 (:wat::core::+ (:wat::core::length a) (:wat::core::length b))
                 (:wat::core::Vector :- [:wat::core::i64]))))

(:wat::core::defn :paip::mul-loop [a <- :paip::Poly b <- :paip::Poly k <- :wat::core::i64 n <- :wat::core::i64 acc <- :paip::Poly] -> :paip::Poly
  (:wat::core::if (:wat::core::>= k n) acc
    (:paip::mul-loop a b (:wat::core::+ k 1) n (:wat::core::conj acc (:paip::conv a b k 0 0)))))

(:wat::core::defn :paip::conv [a <- :paip::Poly b <- :paip::Poly k <- :wat::core::i64 i <- :wat::core::i64 s <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> i k) s
    (:paip::conv a b k (:wat::core::+ i 1)
      (:wat::core::+ s (:wat::core::* (:paip::coeff a i) (:paip::coeff b (:wat::core::- k i)))))))

(:wat::core::defn :paip::pscale [p <- :paip::Poly k <- :wat::core::i64] -> :paip::Poly
  (:paip::trim (:wat::core::mapv (:wat::core::fn [c <- :wat::core::i64] -> :wat::core::i64
                                   (:wat::core::* c k)) p)))

(:wat::core::defn :paip::pderiv [p <- :paip::Poly] -> :paip::Poly
  (:paip::trim (:paip::deriv-loop p 1 (:wat::core::Vector :- [:wat::core::i64]))))

(:wat::core::defn :paip::deriv-loop [p <- :paip::Poly i <- :wat::core::i64 acc <- :paip::Poly] -> :paip::Poly
  (:wat::core::if (:wat::core::>= i (:wat::core::length p)) acc
    (:paip::deriv-loop p (:wat::core::+ i 1)
      (:wat::core::conj acc (:wat::core::* i (:paip::coeff p i))))))

(:wat::core::defn :paip::ipow [x <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::<= n 0) acc (:paip::ipow x (:wat::core::- n 1) (:wat::core::* acc x))))

(:wat::core::defn :paip::peval [p <- :paip::Poly x <- :wat::core::i64 i <- :wat::core::i64 s <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length p)) s
    (:paip::peval p x (:wat::core::+ i 1)
      (:wat::core::+ s (:wat::core::* (:paip::coeff p i) (:paip::ipow x i 1))))))

(:wat::core::defn :paip::show-poly [p <- :paip::Poly] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [c <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string c)) p)) ")"))

;; canonical form means equality is a STRUCTURAL comparison, not a search
(:wat::core::defn :paip::same? [a <- :paip::Poly b <- :paip::Poly] -> :wat::core::bool
  (:wat::core::= (:paip::show-poly a) (:paip::show-poly b)))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    x (:wat::core::Vector :- [:wat::core::i64] 0 1)
                    one (:wat::core::Vector :- [:wat::core::i64] 1)
                    x2 (:paip::p* x x)
                    expanded (:paip::p+ x2 (:paip::p+ (:paip::pscale x 2) one))
                    squared (:paip::p* (:paip::p+ x one) (:paip::p+ x one))
                    zero (:paip::p+ x2 (:paip::pscale x2 -1))]
    (:paip::check-chapter "oracle/paip/ch15-canonical.expected"
                          "paip ch15 canonical"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::show-poly x)
                            (int (:paip::degree x))
                            (:paip::show-poly (:paip::p+ x x))
                            ;; x + x and 2x are THE SAME OBJECT, with no simplification step
                            (:paip::b (:paip::same? (:paip::p+ x x) (:paip::pscale x 2)))
                            (:paip::show-poly x2)
                            (int (:paip::degree x2))
                            (:paip::show-poly expanded)
                            (:paip::show-poly squared)
                            ;; the identity is CHECKABLE rather than provable
                            (:paip::b (:paip::same? expanded squared))
                            ;; and a false identity is refuted just as cheaply
                            (:paip::b (:paip::same? squared (:paip::p+ x2 one)))
                            (:paip::show-poly (:paip::pderiv x2))
                            (:paip::show-poly (:paip::pderiv expanded))
                            (int (:paip::peval expanded 3 0 0))
                            (int (:paip::peval squared 3 0 0))
                            ;; the canonical zero, not a tree that means zero
                            (:paip::show-poly zero)
                            (int (:paip::degree zero))))))
