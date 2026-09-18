;; Project Euler, in wat: the rational surface, pressed the way p16/p20/p25 pressed the bigint one.
;;
;; p57 -- the continued-fraction convergents of the square root of two: 3/2, 7/5, 17/12, …, each
;;        built from the last by n/d -> (n+2d)/(n+d). In how many of the first thousand does the
;;        numerator have more digits than the denominator?
;; p71 -- list every reduced fraction below 3/7 with denominator at most a million, in order of
;;        size. What is the numerator of the one immediately to the left of 3/7?
;;
;; **Three corrections to this repository's own record came out of choosing these problems**, and
;; they matter more than the answers:
;;
;;   1. C-077 and C-089 said `:wat::rational::` is "four verbs (`+ - *`, `to-f64`) with no
;;      division, no comparison and no `to-string`". **Wrong on three counts.** It is SEVEN verbs
;;      — `+ - * /`, `numerator`, `denominator`, `to-f64` — it HAS division, and equality works
;;      (`(= 1/2 2/4)` is true, so rationals normalise). There is a rational LITERAL too: `3/4`
;;      reads, and `(+ 3/4 1/4)` is `1N`. The earlier count came from grepping only `docs/` and
;;      `wat/` and missing `src/`.
;;
;;   2. What is actually missing is **ORDERING**, and that is what p71 needs:
;;        (:wat::core::< 1/4 3/4)
;;        => ":wat::core::<: parameter #1 expects an orderable type (i64, u8, f64, S…)"
;;      So p71 cannot compare two fractions and must cross-multiply instead — `a/b < c/d` becomes
;;      `a*d < c*b`, which is correct for positive denominators and silently wrong if one is
;;      negative, a precondition the type system cannot state (the same shape PAIP ch7 hit, C-085).
;;
;;   3. **This is F-047 generalised.** Both of wat's arbitrary-precision numeric types support
;;      equality and neither supports order, and they are the same two that lack a `to-string`
;;      (F-060's correction). One sentence covers all of it: *bigint and rational can be built,
;;      combined and compared for equality, and cannot be ordered or printed.*
;;
;; p57 then needs the bigint half: the thousandth numerator is 383 digits long, so the convergents
;; must be bigints, and the digit counts come out through `:wat::core::str` with the trailing `N`
;; stripped — F-060's route.
;;
;; The oracle is Clojure (oracle/euler/p57-p71-rationals.clj), which compares ratios and bigints
;; with `<` directly. That is the difference this file is measuring.
;;
;; Run from the repository root:
;;   wat euler/p57-p71-rationals.wat

(:wat::load-file! "lib/check.wat")

;; ---- p57: convergents as bigint pairs
(:wat::core::defstruct :eu::Conv [n <- :wat::core::bigint  d <- :wat::core::bigint])

(:wat::core::defn :eu::step [c <- :eu::Conv] -> :eu::Conv
  (:eu::Conv :n (:wat::bigint::+ (:eu::Conv/n c) (:wat::bigint::* (:wat::i64::to-bigint 2) (:eu::Conv/d c)))
             :d (:wat::bigint::+ (:eu::Conv/n c) (:eu::Conv/d c))))

;; F-060: a bigint has no `to-string`. `:wat::core::str` answers the digits with a trailing `N`,
;; so every use has to strip it -- once for the digit COUNT and once for the digits themselves.
;; Clojure's `(str 3N)` is "3"; wat's is "3N".
(:wat::core::defn :eu::bigstr [b <- :wat::core::bigint] -> :wat::core::String
  (:wat::core::let [s (:wat::core::str b)]
    (:wat::string::subs s 0 (:wat::core::- (:wat::string::length s) 1))))

(:wat::core::defn :eu::digits [b <- :wat::core::bigint] -> :wat::core::i64
  (:wat::string::length (:eu::bigstr b)))

(:wat::core::defn :eu::wider? [c <- :eu::Conv] -> :wat::core::bool
  (:wat::core::> (:eu::digits (:eu::Conv/n c)) (:eu::digits (:eu::Conv/d c))))

(:wat::core::defn :eu::count-wider [c <- :eu::Conv i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n) acc
    (:eu::count-wider (:eu::step c) (:wat::core::+ i 1) n
      (:wat::core::if (:eu::wider? c) (:wat::core::+ acc 1) acc))))

(:wat::core::defn :eu::nth-conv [c <- :eu::Conv k <- :wat::core::i64] -> :eu::Conv
  (:wat::core::if (:wat::core::<= k 0) c (:eu::nth-conv (:eu::step c) (:wat::core::- k 1))))

(:wat::core::defn :eu::last-conv [c <- :eu::Conv i <- :wat::core::i64 n <- :wat::core::i64] -> :eu::Conv
  (:wat::core::if (:wat::core::>= i n) c (:eu::last-conv (:eu::step c) (:wat::core::+ i 1) n)))

(:wat::core::defn :eu::first-conv [] -> :eu::Conv
  (:eu::Conv :n (:wat::i64::to-bigint 3) :d (:wat::i64::to-bigint 2)))

;; ---- p71: ordering fractions WITHOUT an order on rationals.
;; a/b < c/d  <=>  a*d < c*b, for positive b and d -- a precondition nothing in the type can state.
(:wat::core::defn :eu::lt? [a <- :wat::core::i64 b <- :wat::core::i64 c <- :wat::core::i64 d <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::< (:wat::core::* a d) (:wat::core::* c b)))

(:wat::core::defstruct :eu::Frac [n <- :wat::core::i64  d <- :wat::core::i64])

(:wat::core::defn :eu::best-below [d <- :wat::core::i64 limit <- :wat::core::i64 best <- :eu::Frac] -> :eu::Frac
  (:wat::core::if (:wat::core::> d limit) best
    ;; the largest n with n/d < 3/7 is floor((3d-1)/7)
    (:wat::core::let [n (:wat::i64::quot (:wat::core::- (:wat::core::* 3 d) 1) 7)]
      (:eu::best-below (:wat::core::+ d 1) limit
        (:wat::core::if (:eu::lt? (:eu::Frac/n best) (:eu::Frac/d best) n d)
          (:eu::Frac :n n :d d) best)))))

(:wat::core::defn :eu::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    c0 (:eu::first-conv)
                    c7 (:eu::nth-conv c0 7)
                    last1000 (:eu::last-conv c0 1 1000)
                    answer (:eu::best-below 2 1000000 (:eu::Frac :n 0 :d 1))]
    (:euler::check-answers "oracle/euler/p57-p71-rationals.expected"
                        "euler p57 p71 rationals"
                        (:wat::core::Vector :- [:wat::core::String]
                          (int 1000)
                          (:eu::bigstr (:eu::Conv/n c0))
                          (:eu::bigstr (:eu::Conv/d c0))
                          (:eu::bigstr (:eu::Conv/n c7))
                          (:eu::bigstr (:eu::Conv/d c7))
                          (int (:eu::count-wider c0 0 1000 0))
                          (int (:eu::digits (:eu::Conv/n last1000)))
                          (:eu::b (:wat::core::> (:eu::digits (:eu::Conv/n last1000)) 300))
                          (int (:eu::Frac/n answer))
                          (int (:eu::Frac/d answer))
                          ;; the ordering facts, reproduced by cross-multiplication
                          (:eu::b (:eu::lt? 1 4 3 4))
                          (:eu::b (:eu::lt? 428570 999997 3 7))
                          (:eu::b (:wat::core::= 1/2 2/4))))))
