;; probes/euler/letter-lookup-cost.wat: what does the naive letter lookup cost, against a map?
;;
;; euler/p22-names-scores.wat needs each letter's alphabetical value, and wat has no char->int
;; and no index-of (F-062). Two ways to get one:
;;
;;   SCAN  walk "ABCDEFGHIJKLMNOPQRSTUVWXYZ" with subs until the letter matches — up to 26 more
;;         subs calls per letter, on top of the one that read the letter.
;;   MAP   build a PersistentMap from letter to value once, then look up.
;;
;; The solution uses the map, on the reasoning that 26 subs calls at about 16.7 us each (F-062)
;; would dominate. That is a PREDICTION until it is measured, and this session has already had
;; one confident hypothesis overturned by its own control (the char-indexed seek turned out to
;; be under 20% of the scan cost, not the cause of it). So: measure both, over the same work
;; p22 actually does.
;;
;; 2000 names of about 13 letters is roughly 26000 letters. Both methods walk the same letters.
;;
;; Run from the repository root: wat probes/euler/letter-lookup-cost.wat

(:wat::core::typealias :probe::Values (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::report [what <- :wat::core::String ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat what ": " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :probe::alphabet [] -> :wat::core::String "ABCDEFGHIJKLMNOPQRSTUVWXYZ")

;; SCAN: find the letter by walking the alphabet
(:wat::core::defn :probe::scan-value [c <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i 26)
    0
    (:wat::core::if (:wat::core::= (:wat::string::subs (:probe::alphabet) i (:wat::core::+ i 1)) c)
      (:wat::core::+ i 1)
      (:probe::scan-value c (:wat::core::+ i 1)))))

;; MAP: build once, then look up
(:wat::core::defn :probe::values-from [i <- :wat::core::i64 acc <- :probe::Values] -> :probe::Values
  (:wat::core::if (:wat::core::>= i 26)
    acc
    (:probe::values-from (:wat::core::+ i 1)
      (:wat::map::assoc acc (:wat::string::subs (:probe::alphabet) i (:wat::core::+ i 1)) (:wat::core::+ i 1)))))

(:wat::core::defn :probe::map-value [vs <- :probe::Values c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::map::get vs c)
    [:wat::core::Option.Some {:value n} n]
    [:wat::core::Option.None {} 0]))

;; walk one string, summing letter values, each way
(:wat::core::defn :probe::sum-by-scan [s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::sum-by-scan s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:probe::scan-value (:wat::string::subs s i (:wat::core::+ i 1)) 0)))))

(:wat::core::defn :probe::sum-by-map [vs <- :probe::Values s <- :wat::core::String i <- :wat::core::i64 n <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:probe::sum-by-map vs s (:wat::core::+ i 1) n
      (:wat::core::+ acc (:probe::map-value vs (:wat::string::subs s i (:wat::core::+ i 1)))))))

;; a string of about 26000 letters, the size p22 walks
(:wat::core::defn :probe::grow [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n)
    s
    (:probe::grow (:wat::string::concat s s) n)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [vs (:probe::values-from 0 (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64]))
                    s  (:probe::grow (:probe::alphabet) 26000)
                    n  26000
                    t0 (:probe::ms)
                    a  (:probe::sum-by-scan s 0 n 0)
                    t1 (:probe::ms)
                    b  (:probe::sum-by-map vs s 0 n 0)
                    t2 (:probe::ms)]
    (:wat::core::do
      (:probe::report "26000 letters, alphabet scanned" (:wat::core::- t1 t0))
      (:probe::report "26000 letters, map looked up" (:wat::core::- t2 t1))
      (:wat::test::assert-eq a b))))
