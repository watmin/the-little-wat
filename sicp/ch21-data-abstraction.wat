;; SICP §2.1 (data abstraction), in wat.
;;
;; The section's argument is that constructors and selectors are the whole interface: arithmetic
;; written against `numer`/`denom` cannot tell what is underneath, so the representation may be
;; replaced without touching a client. It closes by asking what a PAIR is and answering that it
;; need not be data at all -- `cons` can return a procedure (Exercise 2.4).
;;
;; Both halves port, and the second is the interesting one in a typed language: wat can type the
;; procedural pair. `pcons` answers `[[i64 i64 :-> i64] :-> i64]` -- a function that takes a
;; CHOOSER and applies it. The rationals below are then rebuilt on it and every result is
;; unchanged, which is the section's claim made mechanical rather than argued.
;;
;; A note wat earns on its own: wat HAS rationals, `:wat::rational::`, natively. They are not used
;; here, because the section is about building the abstraction rather than finding it -- and
;; because that surface is four verbs (`+ - *`, `to-f64`) with no division, no comparison and no
;; `to-string` (F-060, C-047). SICP's hand-built version is strictly more capable than wat's
;; built-in one, which is worth knowing.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch21-data-abstraction.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order. guile's `write` quotes strings, so
;; `:sicp::q` puts the quotes back.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch21-data-abstraction.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defn :sicp::my-gcd [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= b 0) a (:sicp::my-gcd b (:wat::i64::rem a b))))

(:wat::core::defn :sicp::iabs [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 0) (:wat::core::- 0 n) n))

;; ---- representation 1: a struct with two fields
(:wat::core::defstruct :sicp::Rat [n <- :wat::core::i64  d <- :wat::core::i64])

;; the reduction lives in the CONSTRUCTOR, so every client gets it for free
(:wat::core::defn :sicp::make-rat [n <- :wat::core::i64 d <- :wat::core::i64] -> :sicp::Rat
  (:wat::core::let [g (:sicp::my-gcd (:sicp::iabs n) (:sicp::iabs d))
                    sign (:wat::core::if (:wat::core::< (:wat::core::* n d) 0) -1 1)]
    (:sicp::Rat :n (:wat::core::* sign (:wat::i64::quot (:sicp::iabs n) g))
                :d (:wat::i64::quot (:sicp::iabs d) g))))

(:wat::core::defn :sicp::numer [x <- :sicp::Rat] -> :wat::core::i64 (:sicp::Rat/n x))
(:wat::core::defn :sicp::denom [x <- :sicp::Rat] -> :wat::core::i64 (:sicp::Rat/d x))

;; every operation below goes through numer/denom and never through the fields
(:wat::core::defn :sicp::add-rat [x <- :sicp::Rat y <- :sicp::Rat] -> :sicp::Rat
  (:sicp::make-rat (:wat::core::+ (:wat::core::* (:sicp::numer x) (:sicp::denom y))
                                  (:wat::core::* (:sicp::numer y) (:sicp::denom x)))
                   (:wat::core::* (:sicp::denom x) (:sicp::denom y))))

(:wat::core::defn :sicp::sub-rat [x <- :sicp::Rat y <- :sicp::Rat] -> :sicp::Rat
  (:sicp::make-rat (:wat::core::- (:wat::core::* (:sicp::numer x) (:sicp::denom y))
                                  (:wat::core::* (:sicp::numer y) (:sicp::denom x)))
                   (:wat::core::* (:sicp::denom x) (:sicp::denom y))))

(:wat::core::defn :sicp::mul-rat [x <- :sicp::Rat y <- :sicp::Rat] -> :sicp::Rat
  (:sicp::make-rat (:wat::core::* (:sicp::numer x) (:sicp::numer y))
                   (:wat::core::* (:sicp::denom x) (:sicp::denom y))))

(:wat::core::defn :sicp::div-rat [x <- :sicp::Rat y <- :sicp::Rat] -> :sicp::Rat
  (:sicp::make-rat (:wat::core::* (:sicp::numer x) (:sicp::denom y))
                   (:wat::core::* (:sicp::denom x) (:sicp::numer y))))

(:wat::core::defn :sicp::equal-rat? [x <- :sicp::Rat y <- :sicp::Rat] -> :wat::core::bool
  (:wat::core::= (:wat::core::* (:sicp::numer x) (:sicp::denom y))
                 (:wat::core::* (:sicp::numer y) (:sicp::denom x))))

;; ---- representation 2: a pair that is NOTHING BUT A PROCEDURE (Exercise 2.4)
;; pcons answers a function that takes a chooser and applies it to the two components.
(:wat::core::typealias :sicp::Chooser [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64])
(:wat::core::typealias :sicp::PPair [:sicp::Chooser :-> :wat::core::i64])

(:wat::core::defn :sicp::pcons [x <- :wat::core::i64 y <- :wat::core::i64] -> :sicp::PPair
  (:wat::core::fn [m <- :sicp::Chooser] -> :wat::core::i64 (m x y)))

(:wat::core::defn :sicp::pcar [z <- :sicp::PPair] -> :wat::core::i64
  (z (:wat::core::fn [p <- :wat::core::i64 q <- :wat::core::i64] -> :wat::core::i64 p)))

(:wat::core::defn :sicp::pcdr [z <- :sicp::PPair] -> :wat::core::i64
  (z (:wat::core::fn [p <- :wat::core::i64 q <- :wat::core::i64] -> :wat::core::i64 q)))

;; the same rationals, over the procedural pair -- only the constructor and selectors changed
(:wat::core::defn :sicp::make-rat2 [n <- :wat::core::i64 d <- :wat::core::i64] -> :sicp::PPair
  (:wat::core::let [g (:sicp::my-gcd (:sicp::iabs n) (:sicp::iabs d))
                    sign (:wat::core::if (:wat::core::< (:wat::core::* n d) 0) -1 1)]
    (:sicp::pcons (:wat::core::* sign (:wat::i64::quot (:sicp::iabs n) g))
                  (:wat::i64::quot (:sicp::iabs d) g))))

;; ---- intervals, the section's other example
(:wat::core::defstruct :sicp::Interval [lo <- :wat::core::i64  hi <- :wat::core::i64])

(:wat::core::defn :sicp::add-interval [x <- :sicp::Interval y <- :sicp::Interval] -> :sicp::Interval
  (:sicp::Interval :lo (:wat::core::+ (:sicp::Interval/lo x) (:sicp::Interval/lo y))
                   :hi (:wat::core::+ (:sicp::Interval/hi x) (:sicp::Interval/hi y))))

;; ---- printing, as the Scheme oracle prints (guile's `write` quotes strings)
(:wat::core::defn :sicp::q [s <- :wat::core::String] -> :wat::core::String
  (:wat::string::concat "\"" s "\""))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::rat->string [x <- :sicp::Rat] -> :wat::core::String
  (:sicp::q (:wat::string::concat (:wat::i64::to-string (:sicp::numer x)) "/"
              (:wat::i64::to-string (:sicp::denom x)))))

(:wat::core::defn :sicp::rat2->string [x <- :sicp::PPair] -> :wat::core::String
  (:sicp::q (:wat::string::concat (:wat::i64::to-string (:sicp::pcar x)) "/"
              (:wat::i64::to-string (:sicp::pcdr x)))))

(:wat::core::defn :sicp::int->string [i <- :sicp::Interval] -> :wat::core::String
  (:sicp::q (:wat::string::concat "[" (:wat::i64::to-string (:sicp::Interval/lo i)) ","
              (:wat::i64::to-string (:sicp::Interval/hi i)) "]")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    one-half (:sicp::make-rat 1 2)
                    one-third (:sicp::make-rat 1 3)]
    (:sicp::check-chapter "oracle/sicp/ch21-data-abstraction.expected"
                          "sicp ch21 data abstraction"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::rat->string one-half)
                            (:sicp::rat->string (:sicp::add-rat one-half one-third))
                            (:sicp::rat->string (:sicp::sub-rat one-half one-third))
                            (:sicp::rat->string (:sicp::mul-rat one-half one-third))
                            (:sicp::rat->string (:sicp::div-rat one-half one-third))
                            (:sicp::b (:sicp::equal-rat? (:sicp::make-rat 1 2) (:sicp::make-rat 2 4)))
                            (:sicp::b (:sicp::equal-rat? (:sicp::make-rat 1 2) (:sicp::make-rat 1 3)))
                            (:sicp::rat->string (:sicp::make-rat 6 9))
                            (:sicp::rat->string (:sicp::make-rat -6 9))
                            (:sicp::rat->string (:sicp::make-rat 6 -9))
                            (:sicp::rat->string (:sicp::make-rat -6 -9))
                            (:sicp::rat->string (:sicp::add-rat one-third (:sicp::add-rat one-third one-third)))
                            (int (:sicp::pcar (:sicp::pcons 3 4)))
                            (int (:sicp::pcdr (:sicp::pcons 3 4)))
                            (:sicp::rat2->string (:sicp::make-rat2 6 9))
                            (:sicp::rat2->string (:sicp::make-rat2 -6 -9))
                            (:sicp::int->string (:sicp::add-interval (:sicp::Interval :lo 1 :hi 2)
                                                                     (:sicp::Interval :lo 3 :hi 5)))
                            (:sicp::int->string (:sicp::Interval :lo 1 :hi 2))))))
