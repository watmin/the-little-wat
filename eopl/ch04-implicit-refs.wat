;; eopl/ch04-implicit-refs.wat — EOPL chapter 4: IMPLICIT-REFS and CALL-BY-REFERENCE.
;;
;; EXPLICIT-REFS (ch04-explicit-refs.wat) makes the programmer write `newref`/`deref`/`setref`.
;; IMPLICIT-REFS pushes all of that below the surface: every variable is bound to a REFERENCE, a
;; bare `x` dereferences, and `set x = e` assigns through the cell. The language now looks like an
;; ordinary imperative one while the interpreter stays pure -- the store is still threaded.
;;
;; CALL-BY-REFERENCE is then not a new language but a two-line change, which is EOPL's actual
;; lesson: when the argument is a bare variable, pass ITS cell instead of allocating a fresh one.
;; One program tells the two apart, and it is the classic one.
;;
;; Run: wat eopl/ch04-implicit-refs.wat

(:wat::load-file! "lib/implicit.wat")

(:wat::core::defn :ci::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; let x = 5 in (set x = 9; x)          -- assignment through an implicit reference
(:wat::core::defn :ci::assign [] -> :imp::Exp
  (:imp::Exp.Let {:name "x" :e (:imp::Exp.Lit {:n 5})
    :body (:imp::Exp.Seq {:a (:imp::Exp.Set {:name "x" :e (:imp::Exp.Lit {:n 9})})
                          :b (:imp::Exp.Var {:name "x"})})}))

;; let x = 1 in let y = 2 in (set x = 10; x + y)   -- two cells stay independent
(:wat::core::defn :ci::two-cells [] -> :imp::Exp
  (:imp::Exp.Let {:name "x" :e (:imp::Exp.Lit {:n 1})
    :body (:imp::Exp.Let {:name "y" :e (:imp::Exp.Lit {:n 2})
      :body (:imp::Exp.Seq {:a (:imp::Exp.Set {:name "x" :e (:imp::Exp.Lit {:n 10})})
                            :b (:imp::Exp.Add {:a (:imp::Exp.Var {:name "x"})
                                               :b (:imp::Exp.Var {:name "y"})})})})}))

;; THE PROGRAM THAT SEPARATES THE TWO CONVENTIONS:
;;   let x = 0 in let f = proc(y) set y = 99 in ((f x); x)
;; by value     -- f writes to its own cell, x is untouched      -> 0
;; by reference -- f writes through x's cell                     -> 99
(:wat::core::defn :ci::alias [] -> :imp::Exp
  (:imp::Exp.Let {:name "x" :e (:imp::Exp.Lit {:n 0})
    :body (:imp::Exp.Let {:name "f"
            :e (:imp::Exp.Lit {:n 0})   ;; placeholder cell; the proc is bound below
            :body (:imp::Exp.Seq
                    {:a (:imp::Exp.Call {:rator (:imp::Exp.Proc {:param "y"
                                                  :body (:imp::Exp.Set {:name "y" :e (:imp::Exp.Lit {:n 99})})})
                                         :rand (:imp::Exp.Var {:name "x"})})
                     :b (:imp::Exp.Var {:name "x"})})})}))

;; a non-variable argument cannot alias anything, so both conventions agree
(:wat::core::defn :ci::non-var-arg [] -> :imp::Exp
  (:imp::Exp.Call {:rator (:imp::Exp.Proc {:param "y"
                            :body (:imp::Exp.Seq {:a (:imp::Exp.Set {:name "y" :e (:imp::Exp.Lit {:n 99})})
                                                  :b (:imp::Exp.Var {:name "y"})})})
                   :rand (:imp::Exp.Add {:a (:imp::Exp.Lit {:n 1}) :b (:imp::Exp.Lit {:n 1})})}))

(:wat::core::defn :ci::both [label <- :wat::core::String e <- :imp::Exp] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    "  " label
    "   by-value=" (:wat::i64::to-string (:imp::run e (:imp::Strategy.ByValue {})))
    "   by-reference=" (:wat::i64::to-string (:imp::run e (:imp::Strategy.ByReference {})))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:ci::say "set through an implicit ref  "
      (:wat::core::if (:wat::core::= (:imp::run (:ci::assign) (:imp::Strategy.ByValue {})) 9) "PASS" "FAIL"))
    (:ci::say "two cells stay independent   "
      (:wat::core::if (:wat::core::= (:imp::run (:ci::two-cells) (:imp::Strategy.ByValue {})) 12) "PASS" "FAIL"))
    (:wat::kernel::println "---- the same program under both calling conventions ----")
    (:ci::both "(f x); x   where f assigns to its parameter" (:ci::alias))
    (:ci::both "the argument is an expression, not a variable" (:ci::non-var-arg))
    (:wat::kernel::println "     -- by reference the callee writes through the CALLER'S cell;")
    (:wat::kernel::println "        by value it gets its own. A non-variable argument cannot alias,")
    (:wat::kernel::println "        so both conventions agree on the second row.")))
