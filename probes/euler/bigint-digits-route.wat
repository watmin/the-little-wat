;; probes/euler/bigint-digits-route.wat: the road to a bigint's digits, and what it costs.
;;
;; probes/euler/bigint-to-string.wat showed there is no :wat::bigint::to-string — the reference
;; is unresolved at startup, where every other scalar has one (i64::to-string, f64::to-string).
;; probes/euler/bigint-surface.wat showed :wat::edn::write gets there anyway: 2^1000 comes back
;; as 303 characters, the first a "1" and the LAST an "N". So the digits are reachable, with a
;; suffix to strip and a length that is digits plus one.
;;
;; Three things to settle before Project Euler's digit problems are written on that road:
;;   1. does trimming the "N" give exactly the digits, and does the count then match Clojure's
;;      (2^1000 has 302 digits, 100! has 158)?
;;   2. can those digits be summed one character at a time, i.e. does string::to-i64 read a
;;      one-character substring?
;;   3. is the digit COUNT a usable stand-in for the comparison F-047 says is refused? p25 asks
;;      for the first Fibonacci term with 1000 digits, which never needs two bigints compared —
;;      only a length against an i64.
;;
;; Run from the repository root: wat probes/euler/bigint-digits-route.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

;; a bigint's digits: what the EDN writer says, without its trailing N
(:wat::core::defn :probe::digits [b <- :wat::core::bigint] -> :wat::core::String
  (:wat::core::let [s (:wat::edn::write b)
                    n (:wat::string::length s)]
    (:wat::string::subs s 0 (:wat::core::- n 1))))

(:wat::core::defn :probe::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "not a number: " s))]))

;; sum the characters of a digit string
(:wat::core::defn :probe::digit-sum-from [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::digit-sum-from s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:probe::to-int (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :probe::digit-sum [b <- :wat::core::bigint] -> :wat::core::i64
  (:wat::core::let [d (:probe::digits b)]
    (:probe::digit-sum-from d 0 (:wat::string::length d) 0)))

(:wat::core::defn :probe::pow2 [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0) acc (:probe::pow2 (:wat::core::- n 1) (:wat::bigint::+ acc acc))))

(:wat::core::defn :probe::fact [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0) acc (:probe::fact (:wat::core::- n 1) (:wat::bigint::* acc (:wat::i64::to-bigint n)))))

;; the first Fibonacci term with d digits — by LENGTH, never comparing two bigints (F-047)
(:wat::core::defn :probe::fib-index [d <- :wat::core::i64 a <- :wat::core::bigint b <- :wat::core::bigint i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= (:wat::string::length (:probe::digits b)) d)
    i
    (:probe::fib-index d b (:wat::bigint::+ a b) (:wat::core::+ i 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [one (:wat::i64::to-bigint 1)
                    p1000 (:probe::pow2 1000 one)
                    f100  (:probe::fact 100 one)]
    (:wat::core::do
      ;; 1. trimming, and the digit counts Clojure reports
      (:probe::show "2^10 digits" (:probe::digits (:probe::pow2 10 one)))
      (:probe::show "digit count of 2^1000 (Clojure says 302)" (:wat::i64::to-string (:wat::string::length (:probe::digits p1000))))
      (:probe::show "digit count of 100! (Clojure says 158)" (:wat::i64::to-string (:wat::string::length (:probe::digits f100))))
      ;; 2. summing them
      (:probe::show "digit sum of 2^15 (Clojure says 26)" (:wat::i64::to-string (:probe::digit-sum (:probe::pow2 15 one))))
      (:probe::show "digit sum of 10! (Clojure says 27)" (:wat::i64::to-string (:probe::digit-sum (:probe::fact 10 one))))
      (:probe::show "digit sum of 2^1000 (Clojure says 1366)" (:wat::i64::to-string (:probe::digit-sum p1000)))
      (:probe::show "digit sum of 100! (Clojure says 648)" (:wat::i64::to-string (:probe::digit-sum f100)))
      ;; 3. length as a stand-in for a comparison
      (:probe::show "first Fibonacci with 3 digits (Clojure says 12)" (:wat::i64::to-string (:probe::fib-index 3 one one 2)))
      (:probe::show "first Fibonacci with 1000 digits (Clojure says 4782)" (:wat::i64::to-string (:probe::fib-index 1000 one one 2))))))
