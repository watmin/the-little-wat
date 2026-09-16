;; probes/aoc/sorted-structures.wat: is there an ordered collection in wat — a sorted set, a
;; sorted map, a priority queue, a heap? Dijkstra's frontier is one, and the Clojure reference
;; for our shortest-path puzzle uses a sorted set (oracle/aoc/day05-paths.clj).
;;
;; What wat has is :wat::core::sort and :wat::core::sort-by, which sort a whole collection at
;; once. This asks for each of the ordered structures by name; every one the resolver refuses
;; is one that isn't there.
;;
;; Run from the repository root: wat probes/aoc/sorted-structures.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [sorted (:wat::core::sorted-set 3 1 2)
                    by-key (:wat::core::sorted-map 3 "c" 1 "a")
                    queue (:wat::core::priority-queue)
                    heap (:wat::core::heap)
                    tree (:wat::core::BTreeMap :- [:wat::core::i64 :wat::core::i64])]
    (:wat::core::do
      (:wat::kernel::println sorted)
      (:wat::kernel::println by-key)
      (:wat::kernel::println queue)
      (:wat::kernel::println heap)
      (:wat::kernel::println tree))))
