;; probes/euler/char-at-exponent.wat: is the char-indexed subs walk climbing toward quadratic?
;;
;; probes/euler/char-at-scaling.wat measured three sizes: 112 ms, 244 ms, 588 ms for 10000,
;; 20000 and 40000 characters. The ratios are 2.18x and 2.41x — superlinear, and RISING, but
;; nowhere near the 4x a quadratic scan would give. Over the whole range it is about n^1.2.
;;
;; The mechanism is documented: :wat::string::subs is CHAR-indexed (src/intrinsic/string.rs:542,
;; "the CHAR-indexed substring [start, end)"). Finding character i in a UTF-8 string means
;; walking to it, so (subs s i (i+1)) is O(i), and a full scan is O(n^2) in principle — but
;; scanning bytes is cheap, so at small n the per-call overhead dominates and the exponent looks
;; closer to 1.
;;
;; Which term wins at scale is the difference between "text work is verbose" and "text work is
;; unusable". The rising ratio says the quadratic term is taking over; a fourth point says how
;; fast. If 80000 costs about 1400 ms the exponent is still ~1.2; if it costs 2400 ms or more,
;; the walk has taken over and the ratio is heading for 4x.
;;
;; Run from the repository root: wat probes/euler/char-at-exponent.wat

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :probe::grow [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n)
    s
    (:probe::grow (:wat::string::concat s s) n)))

(:wat::core::defn :probe::scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan s (:wat::core::+ i 1) n
      (:wat::core::if (:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "a")
        (:wat::core::+ acc 1)
        acc))))

;; the same scan, but reading only the FIRST character every time: same number of subs calls,
;; none of them deep into the string. The difference between this and the walk above is the
;; cost of the char-indexed seek itself.
(:wat::core::defn :probe::scan-head [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan-head s (:wat::core::+ i 1) n
      (:wat::core::if (:wat::core::= (:wat::string::subs s 0 1) "a")
        (:wat::core::+ acc 1)
        acc))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s4 (:probe::grow "abcd" 40000)
                    s8 (:probe::grow "abcd" 80000)
                    t0 (:probe::ms)
                    c4 (:probe::scan s4 0 40000 0)
                    t1 (:probe::ms)
                    c8 (:probe::scan s8 0 80000 0)
                    t2 (:probe::ms)
                    h8 (:probe::scan-head s8 0 80000 0)
                    t3 (:probe::ms)]
    (:wat::core::do
      (:probe::report "40000 characters, walking" (:wat::core::- t1 t0))
      (:probe::report "80000 characters, walking" (:wat::core::- t2 t1))
      (:probe::report "80000 subs calls, all at index 0" (:wat::core::- t3 t2))
      (:wat::test::assert-eq c4 10000)
      (:wat::test::assert-eq c8 20000)
      (:wat::test::assert-eq h8 80000))))
