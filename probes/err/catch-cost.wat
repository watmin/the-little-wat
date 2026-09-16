;; probes/err/catch-cost.wat: what does catching a failure cost?
;;
;; wat's whole error vocabulary is small: :wat::core::Result (a two-variant Pure enum),
;; Result/try, Result/expect, :wat::core::try, :wat::kernel::assertion-failed!, and
;; :wat::test::run-thread, whose death comes back as RunResult.Failed. That last one is a TEST
;; verb, and it is the only general catch in the language — books/little-typer/lib/pie.wat leans
;; on it for all 108 of Pie's refusals, and two probes use it the same way.
;;
;; If catching costs a millisecond, error handling cannot go in a loop, and every program that
;; wants to recover has to be written to avoid failing in the first place. The baselines this
;; repository already has: a plain function call is about 2 us (F-051), and a message to a
;; service about 224 us.
;;
;; Three things timed over the same number of iterations:
;;   1. a plain call that succeeds            -- the floor
;;   2. run-thread around a call that succeeds -- what the catch costs when nothing fails
;;   3. run-thread around a call that dies     -- what a caught failure costs
;;
;; Run from the repository root: wat probes/err/catch-cost.wat

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String n <- :wat::core::i64 ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms for "
                                                (:wat::i64::to-string n) ", "
                                                (:wat::i64::to-string (:wat::core::/ (:wat::core::* ms 1000) n)) " us each")))

(:wat::core::defn :probe::fine [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ x 1))

(:wat::core::defn :probe::dies [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::kernel::assertion-failed! :message "probe: expected failure"))

;; 1. the floor: plain calls
(:wat::core::defn :probe::plain [n <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::plain n (:wat::core::+ i 1) (:wat::core::+ acc (:probe::fine i)))))

;; 2. run-thread around something that succeeds
(:wat::core::defn :probe::caught-ok [n <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::caught-ok n (:wat::core::+ i 1)
      (:wat::core::match (:wat::test::run-thread (:probe::fine i))
        [:wat::kernel::RunResult.Passed {} (:wat::core::+ acc 1)]
        [:wat::kernel::RunResult.Failed {:failure f} acc]))))

;; 3. run-thread around something that dies
(:wat::core::defn :probe::caught-fail [n <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::caught-fail n (:wat::core::+ i 1)
      (:wat::core::match (:wat::test::run-thread (:probe::dies i))
        [:wat::kernel::RunResult.Passed {} acc]
        [:wat::kernel::RunResult.Failed {:failure f} (:wat::core::+ acc 1)]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n  2000
                    t0 (:probe::ms)
                    a  (:probe::plain n 0 0)
                    t1 (:probe::ms)
                    b  (:probe::caught-ok n 0 0)
                    t2 (:probe::ms)
                    c  (:probe::caught-fail n 0 0)
                    t3 (:probe::ms)]
    (:wat::core::do
      (:probe::report "plain calls" n (:wat::core::- t1 t0))
      (:probe::report "run-thread, succeeding" n (:wat::core::- t2 t1))
      (:probe::report "run-thread, failing" n (:wat::core::- t3 t2))
      (:wat::test::assert-eq b n)
      (:wat::test::assert-eq c n))))
