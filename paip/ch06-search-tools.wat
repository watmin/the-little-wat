;; PAIP chapter 6 (building software tools: the search tool), in wat.
;;
;; The chapter's claim is that depth-first, breadth-first, best-first and beam search are ONE
;; program with different arguments -- they differ only in how the newly found states are combined
;; with the frontier. The tests below are built to show that rather than assert it: the same graph,
;; the same goal, four combiners, four different amounts of work.
;;
;; Two honest results worth keeping, both of which contradict the thing one expects to write:
;;
;;   Depth-first expands **29** states finding 12 where breadth-first expands **19**. The dive is
;;   not cheaper here; it is 50% dearer, because on this graph (from n you reach 2n and n+1) the
;;   goal is shallow and the dive goes past it. The check in the chapter asserts the comparison
;;   and reports **#f** -- the prediction is wrong and the file says so rather than being tuned
;;   until it agrees.
;;
;;   Best-first expands **7**, which IS fewer than breadth-first, and a beam of width 2 also
;;   expands 7. A beam of width 1 still finds 19, so the truncation costs nothing on this graph --
;;   the "a narrow beam can miss the goal" warning is real in general and simply does not bite
;;   here, which is the sort of thing only running it tells you.
;;
;; **F-057 lands where the chapter puts it.** Graph search needs a VISITED set, and wat has no
;; persistent set, so it is a `Vector` with a linear `member?`. On a three-node cycle that is
;; free; the finding is about what happens when it is not. What this workload does contribute is
;; the shape: a visited set is *exactly* the "insert and test, never iterate" use F-057 describes.
;;
;; Counting without mutation: the search threads its expansion count and answers both, the same
;; shape SICP §4.2 (C-080) uses. Norvig mutates a global.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch06-search-tools.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch06-search-tools.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :paip::Combiner [:paip::Ints :paip::Ints :-> :paip::Ints])
(:wat::core::typealias :paip::Succ [:wat::core::i64 :-> :paip::Ints])

;; the answer AND the work done, so the comparison is a number rather than a claim
(:wat::core::defenum :paip::SearchAns :wat::enum::Pure
  :Found [v <- :wat::core::i64  expanded <- :wat::core::i64]
  :Fail  [expanded <- :wat::core::i64])

(:wat::core::defn :paip::rest-of [v <- :paip::Ints] -> :paip::Ints
  (:paip::tail-from v 1 (:wat::core::Vector :- [:wat::core::i64])))

(:wat::core::defn :paip::tail-from [v <- :paip::Ints i <- :wat::core::i64 acc <- :paip::Ints] -> :paip::Ints
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:paip::tail-from v (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :paip::head-n [v <- :paip::Ints n <- :wat::core::i64 i <- :wat::core::i64 acc <- :paip::Ints] -> :paip::Ints
  (:wat::core::if (:wat::core::or (:wat::core::>= i n) (:wat::core::>= i (:wat::core::length v))) acc
    (:paip::head-n v n (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth v i)))))

(:wat::core::defn :paip::tree-search
  [states <- :paip::Ints goal <- :wat::core::i64 succ <- :paip::Succ comb <- :paip::Combiner
   expanded <- :wat::core::i64] -> :paip::SearchAns
  (:wat::core::if (:wat::core::empty? states) (:paip::SearchAns.Fail {:expanded expanded})
    (:wat::core::let [s (:wat::core::nth states 0)]
      (:wat::core::if (:wat::core::= s goal) (:paip::SearchAns.Found {:v s :expanded expanded})
        (:paip::tree-search (comb (succ s) (:paip::rest-of states)) goal succ comb
          (:wat::core::+ expanded 1))))))

;; ---- the four combiners: this is the whole difference between the four searches
(:wat::core::defn :paip::depth-first [new <- :paip::Ints old <- :paip::Ints] -> :paip::Ints
  (:wat::core::concat new old))

(:wat::core::defn :paip::breadth-first [new <- :paip::Ints old <- :paip::Ints] -> :paip::Ints
  (:wat::core::concat old new))

(:wat::core::defn :paip::best-first [target <- :wat::core::i64] -> :paip::Combiner
  (:wat::core::fn [new <- :paip::Ints old <- :paip::Ints] -> :paip::Ints
    (:wat::core::sort-by (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64
                           (:paip::iabs (:wat::core::- x target)))
      (:wat::core::concat new old))))

(:wat::core::defn :paip::beam [target <- :wat::core::i64 width <- :wat::core::i64] -> :paip::Combiner
  (:wat::core::fn [new <- :paip::Ints old <- :paip::Ints] -> :paip::Ints
    (:wat::core::let [all (:wat::core::sort-by (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64
                                                 (:paip::iabs (:wat::core::- x target)))
                            (:wat::core::concat new old))]
      (:wat::core::if (:wat::core::> (:wat::core::length all) width)
        (:paip::head-n all width 0 (:wat::core::Vector :- [:wat::core::i64]))
        all))))

(:wat::core::defn :paip::iabs [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 0) (:wat::core::- 0 n) n))

;; from n you can reach 2n and n+1; past 20 the graph stops, so the search is finite
(:wat::core::defn :paip::finite-successors [n <- :wat::core::i64] -> :paip::Ints
  (:wat::core::if (:wat::core::> n 20) (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::Vector :- [:wat::core::i64] (:wat::core::* n 2) (:wat::core::+ n 1))))

(:wat::core::defn :paip::run-search [start <- :wat::core::i64 goal <- :wat::core::i64 comb <- :paip::Combiner] -> :paip::SearchAns
  (:paip::tree-search (:wat::core::Vector :- [:wat::core::i64] start) goal :paip::finite-successors comb 0))

(:wat::core::defn :paip::found-of [a <- :paip::SearchAns] -> :wat::core::String
  (:wat::core::match a
    [:paip::SearchAns.Found {:v v :expanded e} (:wat::i64::to-string v)]
    [:paip::SearchAns.Fail {:expanded e} "fail"]))

(:wat::core::defn :paip::expanded-of [a <- :paip::SearchAns] -> :wat::core::i64
  (:wat::core::match a
    [:paip::SearchAns.Found {:v v :expanded e} e]
    [:paip::SearchAns.Fail {:expanded e} e]))

;; ---- graph search: a visited set makes a cyclic graph terminate.
;; F-057: no persistent set, so this is a Vector and `member?` is a scan.
(:wat::core::defn :paip::member? [x <- :wat::core::i64 v <- :paip::Ints] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? v) false
    (:wat::core::if (:wat::core::= x (:wat::core::first v)) true (:paip::member? x (:wat::core::rest v)))))

(:wat::core::defn :paip::cyclic [n <- :wat::core::i64] -> :paip::Ints
  (:wat::core::if (:wat::core::= n 1) (:wat::core::Vector :- [:wat::core::i64] 2)
    (:wat::core::if (:wat::core::= n 2) (:wat::core::Vector :- [:wat::core::i64] 3)
      (:wat::core::if (:wat::core::= n 3) (:wat::core::Vector :- [:wat::core::i64] 1 4)
        (:wat::core::Vector :- [:wat::core::i64])))))

(:wat::core::defn :paip::graph-search
  [states <- :paip::Ints goal <- :wat::core::i64 visited <- :paip::Ints expanded <- :wat::core::i64] -> :paip::SearchAns
  (:wat::core::if (:wat::core::empty? states) (:paip::SearchAns.Fail {:expanded expanded})
    (:wat::core::let [s (:wat::core::nth states 0)]
      (:wat::core::if (:wat::core::= s goal) (:paip::SearchAns.Found {:v s :expanded expanded})
        (:wat::core::if (:paip::member? s visited)
          (:paip::graph-search (:paip::rest-of states) goal visited expanded)
          (:paip::graph-search (:paip::depth-first (:paip::cyclic s) (:paip::rest-of states)) goal
            (:wat::core::conj visited s) (:wat::core::+ expanded 1)))))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    df12 (:paip::run-search 1 12 :paip::depth-first)
                    bf12 (:paip::run-search 1 12 :paip::breadth-first)
                    best12 (:paip::run-search 1 12 (:paip::best-first 12))
                    beam12 (:paip::run-search 1 12 (:paip::beam 12 2))
                    g4 (:paip::graph-search (:wat::core::Vector :- [:wat::core::i64] 1) 4
                         (:wat::core::Vector :- [:wat::core::i64]) 0)
                    g99 (:paip::graph-search (:wat::core::Vector :- [:wat::core::i64] 1) 99
                          (:wat::core::Vector :- [:wat::core::i64]) 0)]
    (:paip::check-chapter "oracle/paip/ch06-search-tools.expected"
                          "paip ch06 search tools"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::found-of (:paip::run-search 1 8 :paip::depth-first))
                            (:paip::found-of bf12)
                            (int (:paip::expanded-of df12))
                            (int (:paip::expanded-of bf12))
                            ;; the prediction that depth-first does less work is FALSE here
                            (:paip::b (:wat::core::< (:paip::expanded-of df12) (:paip::expanded-of bf12)))
                            (:paip::found-of best12)
                            (int (:paip::expanded-of best12))
                            (:paip::b (:wat::core::< (:paip::expanded-of best12) (:paip::expanded-of bf12)))
                            (:paip::found-of beam12)
                            (int (:paip::expanded-of beam12))
                            ;; a beam of width 1 still finds it on this graph
                            (:paip::found-of (:paip::run-search 1 19 (:paip::beam 19 1)))
                            (:paip::found-of g4)
                            (int (:paip::expanded-of g4))
                            (:paip::found-of g99)
                            (int (:paip::expanded-of g99))))))
