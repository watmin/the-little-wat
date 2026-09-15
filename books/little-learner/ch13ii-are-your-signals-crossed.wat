;; The Little Learner, Interlude VII (Are Your Signals Crossed?).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch13ii-are-your-signals-crossed.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch13ii-are-your-signals-crossed.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    ;; a one-channel signal or filter from its values
                    col (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                          (:ll::tensor (:wat::core::mapv (:wat::core::fn [x <- :wat::core::f64] -> :ll::V (t [x])) xs)))
                    signal (tt [(t [1.0 2.0]) (t [3.0 4.0]) (t [5.0 6.0]) (t [7.0 8.0]) (t [9.0 10.0]) (t [11.0 12.0])])
                    bank (tt [(tt [(t [1.0 2.0]) (t [3.0 4.0]) (t [5.0 6.0])])
                              (tt [(t [7.0 8.0]) (t [9.0 10.0]) (t [11.0 12.0])])
                              (tt [(t [13.0 14.0]) (t [15.0 16.0]) (t [17.0 18.0])])
                              (tt [(t [19.0 20.0]) (t [21.0 22.0]) (t [23.0 24.0])])])]
    (:ll::check-chapter "oracle/learner/ch13ii-are-your-signals-crossed.expected"
                        "little-learner ch13ii are-your-signals-crossed"
                        (:wat::core::Vector :- [:ll::V]
                          ;; malt's own example: 6 two-channel rows, 4 filters of 3 rows
                          (:ll::correlate bank signal)
                          ;; one filter, (1 0 -1), on a one-channel signal: a difference detector
                          (:ll::correlate (tt [(col [1.0 0.0 -1.0])]) (col [1.0 2.0 4.0 8.0 16.0]))
                          ;; a smoothing filter
                          (:ll::correlate (tt [(col [0.25 0.5 0.25])]) (col [0.1 0.9 0.3 0.7]))
                          ;; gradients through correlate, for the bank and for the signal
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (:ll::sum (:ll::correlate (:ll::ref p 0) signal))))
                                            (:ll::lst (:wat::core::Vector :- [:ll::V] bank)))
                          (:ll::gradient-of (:wat::core::fn [p <- :ll::V] -> :ll::V (:ll::sum (:ll::sum (:ll::correlate bank (:ll::ref p 0)))))
                                            (:ll::lst (:wat::core::Vector :- [:ll::V] signal)))))))
