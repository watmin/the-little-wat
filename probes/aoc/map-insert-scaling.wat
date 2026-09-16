;; probes/aoc/map-insert-scaling.wat: does putting one more entry in a hash map copy the map?
;;
;; aoc/day05-paths.wat takes 125 s where its Clojure reference takes 2.8 s, and nearly all of
;; its work is hashmap::assoc and hashset::conj — a frontier of buckets and a set of settled
;; squares, 90000 of them. aoc/day03-words.wat put 5000 words into a map of 199 keys in about
;; 0.6 s, which is 120 µs an entry: a hash insert should be a fraction of that.
;;
;; Each structure is filled at n and at 2n, timed with wat's own clock. Doubling the entries
;; should double the time; four times the time means each insert copies what is already there.
;;
;; Run from the repository root: wat probes/aoc/map-insert-scaling.wat

(:wat::core::typealias :probe::Map (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
(:wat::core::typealias :probe::Set (:wat::core::HashSet :- [:wat::core::i64]))

(:wat::core::defn :probe::fill-map [n <- :wat::core::i64 i <- :wat::core::i64 m <- :probe::Map] -> :probe::Map
  (:wat::core::if (:wat::core::>= i n)
    m
    (:probe::fill-map n (:wat::core::+ i 1) (:wat::hashmap::assoc m i i))))

(:wat::core::defn :probe::fill-set [n <- :wat::core::i64 i <- :wat::core::i64 s <- :probe::Set] -> :probe::Set
  (:wat::core::if (:wat::core::>= i n)
    s
    (:probe::fill-set n (:wat::core::+ i 1) (:wat::hashset::conj s i))))

;; reading is the other half of the question: is a lookup cheap on a big map?
(:wat::core::defn :probe::read-map [m <- :probe::Map n <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::read-map m n (:wat::core::+ i 1)
      (:wat::core::+ acc (:wat::core::match (:wat::hashmap::get m i)
                           [:wat::core::Option.Some {:value v} v]
                           [:wat::core::Option.None {} 0])))))

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t0 (:probe::ms)
                    m2 (:probe::fill-map 2000 0 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
                    t1 (:probe::ms)
                    m4 (:probe::fill-map 4000 0 (:wat::core::HashMap :- [:wat::core::i64 :wat::core::i64]))
                    t2 (:probe::ms)
                    s2 (:probe::fill-set 2000 0 (:wat::core::HashSet :- [:wat::core::i64]))
                    t3 (:probe::ms)
                    s4 (:probe::fill-set 4000 0 (:wat::core::HashSet :- [:wat::core::i64]))
                    t4 (:probe::ms)
                    sum (:probe::read-map m4 4000 0 0)
                    t5 (:probe::ms)]
    (:wat::core::do
      (:probe::report "2000 entries into a hash map" (:wat::core::- t1 t0))
      (:probe::report "4000 entries into a hash map" (:wat::core::- t2 t1))
      (:probe::report "2000 elements into a hash set" (:wat::core::- t3 t2))
      (:probe::report "4000 elements into a hash set" (:wat::core::- t4 t3))
      (:probe::report "4000 lookups in the 4000-entry map" (:wat::core::- t5 t4))
      (:wat::test::assert-eq (:wat::core::length m2) 2000)
      (:wat::test::assert-eq (:wat::core::length m4) 4000)
      (:wat::test::assert-eq (:wat::hashset::length s2) 2000)
      (:wat::test::assert-eq (:wat::hashset::length s4) 4000)
      (:wat::test::assert-eq sum 7998000))))
