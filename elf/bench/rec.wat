;; **What a record field UPDATE costs**, against the same thing as a C struct store.
;;
;; A String and a Vector each have an ownership fast path -- `str_cat_own` and `vec_conj_own` --
;; that the compiler takes when it has proved the operand is a last use (F-127, C-151). A record
;; has none: `assoc` is always `slot_set`, which allocates a new record and copies every field.
;; The compiler's own header says so -- "concat, conj and assoc are all copies" -- and the
;; compiler does it to ITSELF, since `:c::emit` is `(assoc (assoc o :code ...) ...)` on every
;; instruction it emits.
;;
;; This threads one record through a loop, updating one field each time. In C that is a store.
(:wat::core::defrecord :b::St [a <- :wat::core::i64  b <- :wat::core::i64
                               c <- :wat::core::i64  d <- :wat::core::i64])

(:wat::core::defn :b::step [s <- :b::St i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= i n) (:b::St/a s)
    (:b::step (:wat::core::assoc s :a (:wat::core::+ (:b::St/a s) i))
              (:wat::core::+ i 1) n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println
    (:b::step (:b::St :a 0 :b 1 :c 2 :d 3) 0 2000000)))
