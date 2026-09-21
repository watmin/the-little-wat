;; The control for elf/bench/rec.wat: the IDENTICAL loop with the accumulator threaded as a bare
;; i64 instead of a record field. Same arithmetic, same iteration count, same tail call -- the
;; only difference is that nothing is allocated.
;;
;; The ratio between this and rec.wat is what `assoc` on a record costs, with no C compiler in
;; the picture to fold anything away.
(:wat::core::defn :b::step [a <- :wat::core::i64 i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= i n) a
    (:b::step (:wat::core::+ a i) (:wat::core::+ i 1) n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:b::step 0 0 2000000)))
