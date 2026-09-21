;; The same record loop as elf/bench/rec.wat with the record named ONCE per iteration -- the new
;; value comes from the counter rather than from a field read, so `:c::linear?` admits it and
;; `assoc` reaches `slot_set_own` (F-140).
;;
;; rec.wat names it twice, because computing the new value reads a field. That is F-141: the
;; read happens BEFORE the write and cannot observe it, but the test counts mentions.
(:wat::core::defrecord :b::St [a <- :wat::core::i64  b <- :wat::core::i64
                               c <- :wat::core::i64  d <- :wat::core::i64])

(:wat::core::defn :b::step [s <- :b::St i <- :wat::core::i64 n <- :wat::core::i64] -> :b::St
  (:wat::core::if (:wat::core::= i n) s
    (:b::step (:wat::core::assoc s :a i) (:wat::core::+ i 1) n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:b::St/a (:b::step (:b::St :a 0 :b 1 :c 2 :d 3) 0 2000000))))
