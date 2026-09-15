;; The Little Learner, chapter 7 (The Crazy "ates").
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch07-the-crazy-ates.rkt, run by tools/learner-oracle.sh).
;;
;; malt's update functions read the hyperparameter alpha, a dynamically bound global; here
;; each is made from a Hypers value and closes over it.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch07-the-crazy-ates.wat

(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/check.wat")

(:wat::core::defn :ll::pair [a <- :ll::V b <- :ll::V] -> :ll::V (:ll::lst (:wat::core::Vector :- [:ll::V] a b)))
(:wat::core::defn :ll::single [a <- :ll::V] -> :ll::V (:ll::lst (:wat::core::Vector :- [:ll::V] a)))

;; lonely: a parameter accompanied by nothing, in a list of one
(:wat::core::defn :ll::lonely-i [p <- :ll::V] -> :ll::V (:ll::single p))
(:wat::core::defn :ll::lonely-d [pa <- :ll::V] -> :ll::V (:ll::ref pa 0))
(:wat::core::defn :ll::lonely-u [h <- :ll::Hypers] -> [:ll::V :ll::V :-> :ll::V]
  (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V
    (:ll::single (:ll::- (:ll::ref pa 0) (:ll::* (:ll::num (:ll::Hypers/alpha h)) g)))))
(:wat::core::defn :ll::lonely-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h :ll::lonely-i :ll::lonely-d (:ll::lonely-u h)))

;; counted: a parameter accompanied by how many times it has been revised
(:wat::core::defn :ll::counted-i [p <- :ll::V] -> :ll::V (:ll::pair p (:ll::num 0.0)))
(:wat::core::defn :ll::counted-d [pa <- :ll::V] -> :ll::V (:ll::ref pa 0))
(:wat::core::defn :ll::counted-u [h <- :ll::Hypers] -> [:ll::V :ll::V :-> :ll::V]
  (:wat::core::fn [pa <- :ll::V g <- :ll::V] -> :ll::V
    (:ll::pair (:ll::- (:ll::ref pa 0) (:ll::* (:ll::num (:ll::Hypers/alpha h)) g))
               (:ll::+ (:ll::ref pa 1) (:ll::num 1.0)))))
(:wat::core::defn :ll::counted-gradient-descent [h <- :ll::Hypers] -> [[:ll::V :-> :ll::V] :ll::V :-> :ll::V]
  (:ll::gradient-descent h :ll::counted-i :ll::counted-d (:ll::counted-u h)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    obj ((:ll::l2-loss :ll::line) (t [2.0 1.0 4.0 3.0]) (t [1.8 1.2 4.2 3.3]))
                    h (:ll::hypers 1000 0.01)]
    (:ll::check-chapter "oracle/learner/ch07-the-crazy-ates.expected"
                        "little-learner ch07 the-crazy-ates"
                        (:wat::core::Vector :- [:ll::V]
                          ((:ll::naked-gradient-descent h) obj (theta [0.0 0.0]))
                          ((:ll::lonely-gradient-descent h) obj (theta [0.0 0.0]))
                          ((:ll::counted-gradient-descent h) obj (theta [0.0 0.0]))
                          ((:ll::lonely-gradient-descent (:ll::hypers 3 0.01)) obj (theta [5.0 -5.0]))
                          ;; the pieces themselves
                          (:ll::lonely-i (n 3.0))
                          ((:ll::counted-u h) (theta [2.0 7.0]) (n 10.0))
                          ((:ll::lonely-u (:ll::hypers 0 0.5)) (theta [2.0]) (n 10.0))))))
