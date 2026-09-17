;; eopl/ch04-mutable-pairs.wat — EOPL chapter 4, MUTABLE-PAIRS.
;;
;; EOPL's point in this section is deflationary: mutable aggregates need NO new store machinery.
;; A pair is two adjacent cells in the store the previous language already had. The observable
;; consequence is ALIASING — `let p = newpair(1,2) in let q = p in (setleft q 99; left p)` sees 99,
;; because p and q name the same cell index, not two copies.
;;
;; That is exactly the distinction wat's own containers draw (F-057 / C-023): PersistentMap SHARES
;; and HashMap COPIES. The interpreter here has to reproduce sharing on top of a persistent store,
;; and it does so the way EOPL does: by passing around an index, not a value.

(:wat::load-file! "lib/mutpairs.wat")

(:wat::core::defn :user::show [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got)
      (:wat::core::if (:wat::core::= got want) "   PASS" "   FAIL"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch4: MUTABLE-PAIRS ----")

    ;; newpair(3,4) then left/right
    (:user::show "left(newpair(3,4))  "
      (:mp::run (:mp::Exp.Left {:p (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 3})
                                                      :r (:mp::Exp.Lit {:n 4})})})) 3)
    (:user::show "right(newpair(3,4)) "
      (:mp::run (:mp::Exp.Right {:p (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 3})
                                                       :r (:mp::Exp.Lit {:n 4})})})) 4)

    ;; ALIASING: let p = newpair(1,2) in let q = p in (setleft q 99; left p)
    (:user::show "aliasing: setleft q, read p"
      (:mp::run
        (:mp::Exp.Let {:name "p"
                       :e (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 1}) :r (:mp::Exp.Lit {:n 2})})
                       :body (:mp::Exp.Let {:name "q"
                                            :e (:mp::Exp.Var {:name "p"})
                                            :body (:mp::Exp.Seq
                                                    {:a (:mp::Exp.SetLeft {:p (:mp::Exp.Var {:name "q"})
                                                                           :v (:mp::Exp.Lit {:n 99})})
                                                     :b (:mp::Exp.Left {:p (:mp::Exp.Var {:name "p"})})})})}))
      99)

    ;; two DISTINCT pairs do not alias, even though both are freshly built the same way
    (:user::show "distinct pairs stay apart "
      (:mp::run
        (:mp::Exp.Let {:name "p"
                       :e (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 1}) :r (:mp::Exp.Lit {:n 2})})
                       :body (:mp::Exp.Let {:name "q"
                                            :e (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 1})
                                                                  :r (:mp::Exp.Lit {:n 2})})
                                            :body (:mp::Exp.Seq
                                                    {:a (:mp::Exp.SetLeft {:p (:mp::Exp.Var {:name "q"})
                                                                           :v (:mp::Exp.Lit {:n 99})})
                                                     :b (:mp::Exp.Left {:p (:mp::Exp.Var {:name "p"})})})})}))
      1)

    ;; setright reaches the SECOND cell, so left is untouched: a real two-cell layout, not a tag
    (:user::show "setright leaves left alone"
      (:mp::run
        (:mp::Exp.Let {:name "p"
                       :e (:mp::Exp.NewPair {:l (:mp::Exp.Lit {:n 7}) :r (:mp::Exp.Lit {:n 8})})
                       :body (:mp::Exp.Seq
                               {:a (:mp::Exp.SetRight {:p (:mp::Exp.Var {:name "p"})
                                                       :v (:mp::Exp.Lit {:n 99})})
                                :b (:mp::Exp.Add {:a (:mp::Exp.Left {:p (:mp::Exp.Var {:name "p"})})
                                                  :b (:mp::Exp.Right {:p (:mp::Exp.Var {:name "p"})})})})}))
      106)))
