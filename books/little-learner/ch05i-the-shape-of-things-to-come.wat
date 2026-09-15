;; The Little Learner, Interlude III (The Shape of Things to Come).
;; Our own examples on the interlude's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch05i-the-shape-of-things-to-come.rkt, run by tools/learner-oracle.sh).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch05i-the-shape-of-things-to-come.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    tt (:wat::core::fn [rows <- :ll::Vs] -> :ll::V (:ll::tensor rows))
                    t32 (tt [(t [1.0 2.0]) (t [3.0 4.0]) (t [5.0 6.0])])
                    t6 (t [1.0 2.0 3.0 4.0 5.0 6.0])
                    t122 (tt [(tt [(t [1.0 2.0]) (t [3.0 4.0])])])]
    (:ll::check-chapter "oracle/learner/ch05i-the-shape-of-things-to-come.expected"
                        "little-learner ch05i the-shape-of-things-to-come"
                        (:wat::core::Vector :- [:ll::V]
                          ;; the shapes of extended results
                          (:ll::shape-value t32)
                          (:ll::shape-value (:ll::+ (tt [(t [1.0 2.0]) (t [3.0 4.0])]) (t [1.0 2.0])))
                          (:ll::* (t [1.0 2.0]) t32)
                          (:ll::shape-value (:ll::* (t [1.0 2.0]) t32))
                          (:ll::sum t122)
                          (:ll::shape-value (:ll::sum t122))
                          (:ll::shape-value (:ll::sqr t32))
                          ;; reshape: the same entries, in another shape
                          (:ll::reshape [2 3] t32)
                          (:ll::reshape [6] t32)
                          (:ll::reshape [3 2] t6)
                          (:ll::reshape [1 2 3] t6)
                          (:ll::shape-value (:ll::reshape [1 2 3] t6))))))
