;; probes/mal/function-call-cost.wat: the baseline for probes/mal/service-roundtrip-cost.wat.
;; The same loop, 5000 times, adding 1, with a plain function call where that probe sends a
;; message to a counter service.
;;
;; Run: time wat probes/mal/function-call-cost.wat

(:wat::core::defn :probe::add [c <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ c k))

(:wat::core::defn :probe::adds [c <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    c
    (:probe::adds (:probe::add c 1) (:wat::core::- n 1))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:probe::adds 0 5000)))
