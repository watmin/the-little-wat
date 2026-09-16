;; probes/euler/char-at-cost.wat: what does a character cost, when a one-character subs is the
;; only way to get one?
;;
;; wat has no :wat::char:: namespace, no string::chars, no index-of, and split refuses an empty
;; separator, so every character operation goes through (subs s i (+ i 1)). mal's reader does
;; it, aoc/day02 does it, and euler's digit walk does it.
;;
;; aoc/README.md records 10000 one-character subs at about 130 ms, measured inside a puzzle. This
;; measures it directly, at two sizes, so the shape is visible: if doubling the string doubles
;; the time, a character costs a constant and text work is merely verbose; if it quadruples,
;; subs is copying and text work is quadratic in the length of the string.
;;
;; The comparison is a scan that touches every character once — the commonest thing a text
;; program does.
;;
;; Run from the repository root: wat probes/euler/char-at-cost.wat

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

;; build a string of n characters by doubling, so the setup is not what is being measured
(:wat::core::defn :probe::grow [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n)
    s
    (:probe::grow (:wat::string::concat s s) n)))

;; count the "a"s, one character at a time
(:wat::core::defn :probe::scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan s (:wat::core::+ i 1) n
      (:wat::core::if (:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "a")
        (:wat::core::+ acc 1)
        acc))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s10k (:probe::grow "abcd" 10000)
                    s20k (:probe::grow "abcd" 20000)
                    t0 (:probe::ms)
                    c1 (:probe::scan s10k 0 10000 0)
                    t1 (:probe::ms)
                    c2 (:probe::scan s20k 0 20000 0)
                    t2 (:probe::ms)]
    (:wat::core::do
      (:probe::report "scanning 10000 characters by subs" (:wat::core::- t1 t0))
      (:probe::report "scanning 20000 characters by subs" (:wat::core::- t2 t1))
      (:wat::test::assert-eq c1 2500)
      (:wat::test::assert-eq c2 5000))))
