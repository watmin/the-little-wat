;; probes/eopl/mutual-tco.wat — does wat's TCO span MUTUAL tail calls, or only self-calls?
;;
;; Run: wat probes/eopl/mutual-tco.wat <n>
;;
;; This decides whether EOPL chapter 6.5's registerization is a CHOICE in wat or a REQUIREMENT.
;; If only self-calls are optimized, an interpreter written as two mutually tail-calling
;; procedures (`value-of/k` and `apply-cont`) cannot run deep, and the registerized `step`/
;; trampoline shape would be forced. Measured 2026-09-16, wat-rs a3218644d: mutual tail calls
;; survive n=10,000,000 — the same ceiling as self tail calls. Registerization is NOT forced.
;;
;; `ping` and `pong` each call the other in tail position and do nothing else.

(:wat::core::defn :m::pong [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:m::ping (:wat::core::- n 1))))

(:wat::core::defn :m::ping [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:m::pong (:wat::core::- n 1))))

;; the self-call control of the same shape
(:wat::core::defn :m::solo [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:m::solo (:wat::core::- n 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [args (:wat::runtime::argv)
                    n (:wat::core::if (:wat::core::> (:wat::core::length args) 2)
                        (:wat::core::match (:wat::string::to-i64 (:wat::core::nth args 2))
                          [:wat::core::Option.Some {:value v} v]
                          [:wat::core::Option.None {} 1000000])
                        1000000)]
    (:wat::core::do
      (:wat::kernel::println
        (:wat::string::concat "mutual  n=" (:wat::i64::to-string n)
          " => " (:wat::i64::to-string (:m::ping n)) "   (no segfault = mutual TCO holds)"))
      (:wat::kernel::println
        (:wat::string::concat "self    n=" (:wat::i64::to-string n)
          " => " (:wat::i64::to-string (:m::solo n)))))))
