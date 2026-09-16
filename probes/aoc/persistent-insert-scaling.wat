;; probes/aoc/persistent-insert-scaling.wat: does PersistentMap share structure where HashMap
;; copies?
;;
;; probes/aoc/map-insert-scaling.wat showed that filling a HashMap is quadratic: 2000 entries
;; take 84 ms and 4000 take 341 ms. wat also has :wat::core::PersistentMap and
;; :wat::core::PersistentVector, whose names promise the structural sharing that makes an
;; insert cheap. If they deliver it, the fault in F-057 is that the obvious container is the
;; slow one; if they don't, nothing in wat shares.
;;
;; Each is filled at n and at 2n, timed with wat's own clock, beside the HashMap for comparison.
;;
;; Run from the repository root: wat probes/aoc/persistent-insert-scaling.wat

(:wat::core::typealias :probe::Hash (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
(:wat::core::typealias :probe::Persist (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defn :probe::fill-hash [n <- :wat::core::i64 i <- :wat::core::i64 m <- :probe::Hash] -> :probe::Hash
  (:wat::core::if (:wat::core::>= i n)
    m
    (:probe::fill-hash n (:wat::core::+ i 1) (:wat::hashmap::assoc m i i))))

(:wat::core::defn :probe::fill-persist [n <- :wat::core::i64 i <- :wat::core::i64 m <- :probe::Persist] -> :probe::Persist
  (:wat::core::if (:wat::core::>= i n)
    m
    (:probe::fill-persist n (:wat::core::+ i 1) (:wat::map::assoc m i i))))

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t0 (:probe::ms)
                    h2 (:probe::fill-hash 2000 0 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
                    t1 (:probe::ms)
                    h4 (:probe::fill-hash 4000 0 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
                    t2 (:probe::ms)
                    p2 (:probe::fill-persist 2000 0 (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))
                    t3 (:probe::ms)
                    p4 (:probe::fill-persist 4000 0 (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))
                    t4 (:probe::ms)]
    (:wat::core::do
      (:probe::report "2000 entries into a HashMap" (:wat::core::- t1 t0))
      (:probe::report "4000 entries into a HashMap" (:wat::core::- t2 t1))
      (:probe::report "2000 entries into a PersistentMap" (:wat::core::- t3 t2))
      (:probe::report "4000 entries into a PersistentMap" (:wat::core::- t4 t3))
      (:wat::test::assert-eq (:wat::core::length h2) 2000)
      (:wat::test::assert-eq (:wat::core::length h4) 4000)
      (:wat::test::assert-eq (:wat::map::length p2) 2000)
      (:wat::test::assert-eq (:wat::map::length p4) 4000))))
