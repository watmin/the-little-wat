;; probes/euler/string-sort-order.wat: does wat sort Strings the way Clojure does?
;;
;; Project Euler's names-scores problem turns entirely on sort order: each name's score is
;; multiplied by its position in the sorted list, so if wat and Clojure disagree about the order
;; of even one pair, every score after it is wrong and the total silently differs.
;;
;; :wat::core::sort is a one-argument clause over sort$native with `<`, and `<` accepts String
;; among its orderable types. But "orderable" and "collates the same way Clojure's compare does"
;; are different claims. The cases that separate implementations:
;;
;;   - case: does "Z" come before or after "a"? (byte order says yes, a case-insensitive
;;     collation says no)
;;   - prefixes: "MARY" before "MARYANN"
;;   - equal names: a stable order, since the real file has repeats
;;   - length vs content: "B" against "AA"
;;
;; Clojure's compare on Strings is String.compareTo — UTF-16 code-unit order, so uppercase
;; sorts before lowercase. This asks whether wat agrees. The expected answers are printed beside
;; each result, from running the same comparisons in Clojure.
;;
;; Run from the repository root: wat probes/euler/string-sort-order.wat

(:wat::core::defn :probe::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :probe::show-bool [label <- :wat::core::String b <- :wat::core::bool] -> :wat::core::nil
  (:probe::show label (:wat::core::if b "true" "false")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; the individual comparisons
    (:probe::show-bool "\"A\" < \"B\" (Clojure: true)" (:wat::core::< "A" "B"))
    (:probe::show-bool "\"Z\" < \"a\" (Clojure: true)" (:wat::core::< "Z" "a"))
    (:probe::show-bool "\"MARY\" < \"MARYANN\" (Clojure: true)" (:wat::core::< "MARY" "MARYANN"))
    (:probe::show-bool "\"B\" < \"AA\" (Clojure: false)" (:wat::core::< "B" "AA"))
    (:probe::show-bool "\"ALEX\" < \"ALICE\" (Clojure: true)" (:wat::core::< "ALEX" "ALICE"))

    ;; and the sort itself, which is what the workload uses
    (:probe::show "sorted (Clojure: AA|ALEX|ALICE|B|MARY|MARYANN|Z|a)"
      (:wat::string::join "|"
        (:wat::core::sort (:wat::core::Vector :- [:wat::core::String]
                            "MARYANN" "a" "B" "ALICE" "Z" "AA" "MARY" "ALEX"))))

    ;; repeats must survive, since the real name list has them
    (:probe::show "sorted with repeats (Clojure: AMY|AMY|BOB)"
      (:wat::string::join "|"
        (:wat::core::sort (:wat::core::Vector :- [:wat::core::String] "BOB" "AMY" "AMY"))))))
