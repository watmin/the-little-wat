;; probes/euler/char-at-scaling.wat: is scanning a String by subs linear, or quadratic?
;;
;; probes/euler/char-at-cost.wat measured two sizes: 10000 characters took 97 ms and 20000 took
;; 225 ms. That is 2.3x for a doubling — more than linear, less than quadratic — and one
;; doubling cannot tell the difference between a quadratic scan and a linear one with noise in
;; it. This session has already turned exactly that distinction into the most useful finding in
;; the ledger (F-057: HashMap quadruples where PersistentMap doubles), so it is worth a third
;; point rather than a hedge.
;;
;; Three sizes, each double the last, in one run:
;;   linear      -> times roughly double       (1x, 2x, 4x)
;;   quadratic   -> times roughly quadruple    (1x, 4x, 16x)
;;
;; The string is built once per size by doubling, and the clock is started after it is built, so
;; only the scan is timed.
;;
;; Run from the repository root: wat probes/euler/char-at-scaling.wat

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :probe::grow [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n)
    s
    (:probe::grow (:wat::string::concat s s) n)))

;; touch every character once — the commonest thing a text program does
(:wat::core::defn :probe::scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::scan s (:wat::core::+ i 1) n
      (:wat::core::if (:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "a")
        (:wat::core::+ acc 1)
        acc))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s1 (:probe::grow "abcd" 10000)
                    s2 (:probe::grow "abcd" 20000)
                    s3 (:probe::grow "abcd" 40000)
                    t0 (:probe::ms)
                    c1 (:probe::scan s1 0 10000 0)
                    t1 (:probe::ms)
                    c2 (:probe::scan s2 0 20000 0)
                    t2 (:probe::ms)
                    c3 (:probe::scan s3 0 40000 0)
                    t3 (:probe::ms)]
    (:wat::core::do
      (:probe::report "10000 characters" (:wat::core::- t1 t0))
      (:probe::report "20000 characters" (:wat::core::- t2 t1))
      (:probe::report "40000 characters" (:wat::core::- t3 t2))
      (:wat::test::assert-eq c1 2500)
      (:wat::test::assert-eq c2 5000)
      (:wat::test::assert-eq c3 10000))))
