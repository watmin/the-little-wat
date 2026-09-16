;; Project Euler, three problems that turn on arbitrary-precision integers.
;;
;;   p16  the sum of the digits of 2^1000
;;   p20  the sum of the digits of 100!
;;   p25  the index of the first Fibonacci term with 1000 digits (F1 = F2 = 1)
;;
;; Project Euler's problem statements are not reproduced; those three sentences are the problems
;; in our own words. The answers must be the reference implementation's
;; (oracle/euler/p16-p20-p25-digits.clj, run by tools/euler-oracle.sh).
;;
;; These three were chosen to press where the ledger was thinnest. F-047 says a wat bigint
;; computes but cannot be compared; it turns out it also has no to-string (F-060), where every
;; other scalar does. So:
;;
;;   - a bigint's DIGITS come from :wat::edn::write, whose answer ends in "N" — 2^1000 renders as
;;     303 characters, of which 302 are digits. Every digit walk here trims that suffix first.
;;   - p25 never compares two bigints. It asks whether the digit COUNT has reached 1000, which is
;;     an i64 comparison, and sidesteps F-047 entirely. That is the honest route, and it is also
;;     the one Clojure's own (count (str b)) takes.
;;
;; Run from the repository root (it reads the expected file by path):
;;   wat euler/p16-p20-p25-digits.wat

(:wat::load-file! "lib/check.wat")

;; ---- a bigint's digits

;; what the EDN writer says, without its trailing N
(:wat::core::defn :euler::digits [b <- :wat::core::bigint] -> :wat::core::String
  (:wat::core::let [s (:wat::edn::write b)
                    n (:wat::string::length s)]
    (:wat::string::subs s 0 (:wat::core::- n 1))))

(:wat::core::defn :euler::to-int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 s)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message (:wat::string::concat "not a number: " s))]))

(:wat::core::defn :euler::sum-chars [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:euler::sum-chars s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:euler::to-int (:wat::string::subs s i (:wat::core::+ i 1)))))))

(:wat::core::defn :euler::digit-sum [b <- :wat::core::bigint] -> :wat::core::i64
  (:wat::core::let [d (:euler::digits b)]
    (:euler::sum-chars d 0 (:wat::string::length d) 0)))

(:wat::core::defn :euler::digit-count [b <- :wat::core::bigint] -> :wat::core::i64
  (:wat::string::length (:euler::digits b)))

;; ---- the numbers themselves

;; 2^n, by doubling: wat has no bigint pow, and no bit shift either (F-035)
(:wat::core::defn :euler::pow2 [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:euler::pow2 (:wat::core::- n 1) (:wat::bigint::+ acc acc))))

(:wat::core::defn :euler::factorial [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:euler::factorial (:wat::core::- n 1) (:wat::bigint::* acc (:wat::i64::to-bigint n)))))

;; the index of the first Fibonacci term with d digits, by LENGTH — never comparing two bigints
(:wat::core::defn :euler::fib-index [d <- :wat::core::i64 a <- :wat::core::bigint b <- :wat::core::bigint i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= (:euler::digit-count b) d)
    i
    (:euler::fib-index d b (:wat::bigint::+ a b) (:wat::core::+ i 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [one (:wat::i64::to-bigint 1)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:euler::check-answers "oracle/euler/p16-p20-p25-digits.expected"
                           "euler p16 p20 p25 digits"
                           (:wat::core::Vector :- [:wat::core::String]
                             ;; p16, and a small one beside it so a wrong answer says where
                             (int (:euler::digit-sum (:euler::pow2 1000 one)))
                             (int (:euler::digit-sum (:euler::pow2 15 one)))
                             ;; p20, likewise
                             (int (:euler::digit-sum (:euler::factorial 100 one)))
                             (int (:euler::digit-sum (:euler::factorial 10 one)))
                             ;; p25, by digit count rather than by comparison (F-047)
                             (int (:euler::fib-index 1000 one one 2))
                             (int (:euler::fib-index 3 one one 2))
                             ;; the counts themselves, so the N-trimming is checked directly
                             (int (:euler::digit-count (:euler::pow2 1000 one)))
                             (int (:euler::digit-count (:euler::factorial 100 one)))))))
