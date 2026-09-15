;; probes/mal/service-roundtrip-cost.wat: what does one message to a service cost? Make-a-Lisp's
;; environments live on a store service (mal/lib/env.wat), and a mal call costs about 3.3 ms,
;; about a dozen messages. Here the smallest service there is, the Seasoned Schemer's counter
;; (one i64, on a thread), gets 5000 add messages in a loop.
;;
;; Run: time wat probes/mal/service-roundtrip-cost.wat   (then subtract a trivial program's
;; startup, about 0.3 s, and divide by 5000)

(:wat::load-file! "../../books/seasoned-schemer/lib/counter.wat")

(:wat::core::defn :probe::adds [c <- :ss::CounterRef n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    (:ss::counter-get c)
    (:wat::core::do
      (:ss::counter-add! c 1)
      (:probe::adds c (:wat::core::- n 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:probe::adds (:ss::new-counter 0) 5000)))
