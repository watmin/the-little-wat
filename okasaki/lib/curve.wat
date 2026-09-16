;; okasaki/lib/curve.wat — the measurement F-097 left as the port's real contribution.
;;
;; F-097 established that every structure here loses to a native competitor on constant factors,
;; because an interpreted node visit costs ~2 us whatever the algorithm. So wall-clock comparisons
;; are not the point. The ASYMPTOTIC CURVE is: it is a property of the structure, and the ~2 us
;; constant divides out of a ratio.
;;
;; Read a doubling series like this:
;;
;;   O(1) amortized   ns/op stays FLAT as n doubles
;;   O(log n)         ns/op grows by a roughly CONSTANT ADDITIVE step per doubling
;;   O(n)             ns/op DOUBLES per doubling
;;
;; So the ratio between successive rows is the verdict, and it is what a bound claim means
;; operationally.

(:wat::core::defn :curve::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

(:wat::core::defn :curve::row
  [label <- :wat::core::String n <- :wat::core::i64 ops <- :wat::core::i64 ns <- :wat::core::i64]
  -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    "  " label "  n=" (:wat::i64::to-string n)
    "  ops=" (:wat::i64::to-string ops)
    "  ns/op=" (:wat::i64::to-string (:wat::core::/ ns ops))))))
