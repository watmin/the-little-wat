;; The Little Learner, chapter 6 (An Apple a Day).
;; Our own examples on the chapter's topics, computed with the port of malt (lib/malt.wat)
;; and compared, value by value and exactly, with malt itself
;; (oracle/learner/ch06-an-apple-a-day.rkt, run by tools/learner-oracle.sh).
;;
;; Stochastic descent samples rows with Racket's random numbers. The oracle records the
;; draws malt makes, one line per sampled run (oracle/learner/ch06-an-apple-a-day.draws), and
;; each run here replays its line, counting its place on a counter service.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-learner/ch06-an-apple-a-day.wat

(:wat::load-file! "../seasoned-schemer/lib/counter.wat")
(:wat::load-file! "lib/malt.wat")
(:wat::load-file! "lib/sampling.wat")
(:wat::load-file! "lib/check.wat")

;; A line of the draws file as integers.
(:wat::core::defn :ll::parse-ints [line <- :wat::core::String] -> :ll::Ints
  (:wat::core::mapv (:wat::core::fn [w <- :wat::core::String] -> :wat::core::i64
                      (:wat::core::match (:wat::string::to-f64 w)
                        [:wat::core::Option.Some {:value x}
                          (:wat::core::match (:wat::f64::to-i64 x)
                            [:wat::core::Option.Some {:value k} k]
                            [:wat::core::Option.None {} (:ll::fail (:wat::string::concat "not an integer draw: " w))])]
                        [:wat::core::Option.None {} (:ll::fail (:wat::string::concat "not a draw: " w))]))
                    (:wat::string::split line " ")))

;; The k-th recorded run's draws, with a fresh counter of how many are used.
(:wat::core::defn :ll::draws [lines <- :ll::Lines k <- :wat::core::i64] -> :ll::Draws
  (:ll::Draws :seq (:ll::parse-ints (:wat::core::nth lines k)) :used (:ss::new-counter 0)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [lines (:ll::non-empty (:wat::string::split (:wat::io::read-file "oracle/learner/ch06-an-apple-a-day.draws") "\n"))
                    n :ll::num
                    t (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                        (:ll::tensor (:wat::core::mapv :ll::num xs)))
                    theta (:wat::core::fn [xs <- (:wat::core::Vector :- [:wat::core::f64])] -> :ll::V
                            (:ll::lst (:wat::core::mapv :ll::num xs)))
                    ints (:wat::core::fn [ks <- :ll::Ints] -> :ll::V
                           (:ll::lst (:wat::core::mapv (:wat::core::fn [k <- :wat::core::i64] -> :ll::V (n (:wat::i64::to-f64 k))) ks)))
                    line-xs (t [2.0 1.0 4.0 3.0])
                    line-ys (t [1.8 1.2 4.2 3.3])
                    quad-xs (t [-1.0 0.0 1.0 2.0 3.0])
                    quad-ys (t [2.55 2.1 4.35 10.2 18.25])
                    h-line (:ll::Hypers :revs 1000 :alpha 0.01 :batch-size 4 :mu 0.0 :beta 0.0)
                    h-quad (:ll::Hypers :revs 800 :alpha 0.001 :batch-size 3 :mu 0.0 :beta 0.0)]
    (:ll::check-chapter "oracle/learner/ch06-an-apple-a-day.expected"
                        "little-learner ch06 an-apple-a-day"
                        (:wat::core::Vector :- [:ll::V]
                          ;; samples: batch-size random indices below n, reversed
                          (ints (:ll::samples (:ll::draws lines 0) 5))
                          ;; trefs: the rows at a list of indices
                          (:ll::trefs (t [10.0 20.0 30.0]) [2 0 2])
                          (:ll::trefs (:ll::tensor (:wat::core::Vector :- [:ll::V] (t [1.0 2.0]) (t [3.0 4.0]) (t [5.0 6.0]))) [1 1 0])
                          ;; stochastic gradient descent of a line: each revision over 4 sampled rows
                          ((:ll::naked-gradient-descent h-line)
                           (:ll::sampling-obj h-line (:ll::draws lines 1) (:ll::l2-loss :ll::line) line-xs line-ys)
                           (theta [0.0 0.0]))
                          ;; and of a quad, 3 rows of 5 at a time
                          ((:ll::naked-gradient-descent h-quad)
                           (:ll::sampling-obj h-quad (:ll::draws lines 2) (:ll::l2-loss :ll::quad) quad-xs quad-ys)
                           (theta [0.0 0.0 0.0]))))))
