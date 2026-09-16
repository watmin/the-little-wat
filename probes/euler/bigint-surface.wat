;; probes/euler/bigint-surface.wat: what can actually be done with a wat bigint?
;;
;; F-047 says a bigint computes but cannot be compared — "It has :wat::i64::to-bigint, and
;; bigint +, -, * and /". That finding came from two koan probes, and the registered vocabulary
;; does not match it: a grep of wat-rs finds only
;;
;;   :wat::bigint::+  :wat::bigint::-  :wat::bigint::*  :wat::bigint::to-f64
;;   :wat::bigint::to-rational        :wat::i64::to-bigint
;;
;; No division, no comparison, no modulo, and — the one that decides a whole class of problems —
;; no to-string. Project Euler's p16 (digit sum of 2^1000), p20 (digit sum of 100!) and p48
;; (last ten digits of a sum) all need a bigint's DIGITS. If a bigint cannot become a String,
;; none of them can be written, and F-047 understates the gap badly.
;;
;; This file only does what is known to work, and prints what it gets. The things that may be
;; missing are asked in separate files, since a startup refusal ends the program:
;;   probes/euler/bigint-divide.wat     — is there a :wat::bigint::/ as F-047 claims?
;;   probes/euler/bigint-to-string.wat  — can a bigint's digits be reached as a String?
;;
;; Run from the repository root: wat probes/euler/bigint-surface.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

;; 2^n, by doubling — the shape p16 needs
(:wat::core::defn :probe::pow2 [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::pow2 (:wat::core::- n 1) (:wat::bigint::+ acc acc))))

;; n!, the shape p20 needs
(:wat::core::defn :probe::fact [n <- :wat::core::i64 acc <- :wat::core::bigint] -> :wat::core::bigint
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::fact (:wat::core::- n 1) (:wat::bigint::* acc (:wat::i64::to-bigint n)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [one   (:wat::i64::to-bigint 1)
                    two10 (:probe::pow2 10 one)
                    f20   (:probe::fact 20 one)
                    big   (:probe::pow2 1000 one)]
    (:wat::core::do
      ;; arithmetic that is known to exist
      (:probe::show "2^10 by doubling" (:wat::edn::write two10))
      (:probe::show "20!" (:wat::edn::write f20))
      (:probe::show "2^1000" (:wat::edn::write big))
      (:probe::show "2^10 - 2^10" (:wat::edn::write (:wat::bigint::- two10 two10)))
      ;; the lossy escape hatch F-047 says the koan idiom takes
      (:probe::show "2^1000 as f64" (:wat::f64::to-string (:wat::bigint::to-f64 big)))
      ;; does edn::write answer a String whose characters are the digits?
      (:probe::show "length of (edn::write 2^1000)" (:wat::i64::to-string (:wat::string::length (:wat::edn::write big))))
      (:probe::show "first char of it" (:wat::string::subs (:wat::edn::write big) 0 1))
      (:probe::show "last char of it" (:wat::core::let [s (:wat::edn::write big)
                                                        n (:wat::string::length s)]
                                        (:wat::string::subs s (:wat::core::- n 1) n))))))
