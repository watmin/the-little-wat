;; eopl/ch04-parameter-passing.wat — EOPL chapter 4: by-value, by-name, by-need.
;;
;; The three disciplines differ in exactly one thing -- WHEN and HOW OFTEN an argument is
;; evaluated -- and on a pure terminating program they all give the same answer, so the difference
;; is only visible in COST. Two programs separate all three:
;;
;;   USED TWICE     `let f = proc(x) -(x,x) in f(EXPENSIVE)`
;;                    by-value 1x   by-name 2x   by-need 1x
;;   NEVER USED     `let f = proc(x) 42 in f(EXPENSIVE)`
;;                    by-value 1x   by-name 0x   by-need 0x
;;
;; by-need is by-name PLUS memoization, which is exactly F-100's distinction: `:wat::stream::` is
;; by-name (a forced suspension is not remembered) and P-027's `Susp<T>` is what makes it by-need.
;; So this chapter is the same finding seen from the language-design side rather than the
;; data-structure side, and it uses the same stand-in (okasaki/lib/susp.wat).
;;
;; The table below runs at depth 400 to keep the suite quick. At depth 1200 the same programs
;; measure by-value 97 ms, by-name 44669 ms, by-need 147 ms -- 460x -- and the growth is
;; asymptotic rather than a constant factor: by-name rises ~4x per doubling (O(n^2)) where by-need
;; rises ~2x (O(n)). Each use of `n` re-walks the thunk chain to the top and `n` is used twice per
;; level, so the work sums to O(n^2); it is quadratic rather than exponential precisely because
;; those two uses sit at the same level rather than nested.
;;
;; Run: wat eopl/ch04-parameter-passing.wat

(:wat::load-file! "lib/lazy.wat")

(:wat::core::defn :c4::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c4::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; EXPENSIVE: letrec f(n) = if zero?(n) then 0 else f(-(n,1)) in f(depth)
(:wat::core::defn :c4::expensive [depth <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Letrec
    {:fname "g" :param "n"
     :fbody (:eopl::Exp.If
              {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name "n"})})
               :t (:eopl::Exp.Const {:n 0})
               :f (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "g"})
                                    :rand (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "n"})
                                                            :b (:eopl::Exp.Const {:n 1})})})})
     :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "g"})
                             :rand (:eopl::Exp.Const {:n depth})})}))

;; let f = proc(x) -(x,x) in f(EXPENSIVE)   -- the argument is used TWICE
(:wat::core::defn :c4::used-twice [depth <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Call
    {:rator (:eopl::Exp.Proc {:param "x"
              :body (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "x"}) :b (:eopl::Exp.Var {:name "x"})})})
     :rand (:c4::expensive depth)}))

;; let f = proc(x) 42 in f(EXPENSIVE)       -- the argument is NEVER used
(:wat::core::defn :c4::never-used [depth <- :wat::core::i64] -> :eopl::Exp
  (:eopl::Exp.Call
    {:rator (:eopl::Exp.Proc {:param "x" :body (:eopl::Exp.Const {:n 42})})
     :rand (:c4::expensive depth)}))

(:wat::core::defn :c4::ms [e <- :eopl::Exp st <- :eopl::Strategy] -> :wat::core::i64
  (:wat::core::let [t0 (:c4::now) v (:eopl::l-run e st)]
    (:wat::core::do (:eopl::l-num v)
      (:wat::core::/ (:wat::core::- (:c4::now) t0) 1000000))))

(:wat::core::defn :c4::row [label <- :wat::core::String e <- :eopl::Exp] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    "  " label
    "   by-value=" (:wat::i64::to-string (:c4::ms e (:eopl::Strategy.ByValue {}))) "ms"
    "   by-name=" (:wat::i64::to-string (:c4::ms e (:eopl::Strategy.ByName {}))) "ms"
    "   by-need=" (:wat::i64::to-string (:c4::ms e (:eopl::Strategy.ByNeed {}))) "ms"))))

(:wat::core::defn :c4::agree? [e <- :eopl::Exp want <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:eopl::l-num (:eopl::l-run e (:eopl::Strategy.ByValue {}))) want)
    (:wat::core::if (:wat::core::= (:eopl::l-num (:eopl::l-run e (:eopl::Strategy.ByName {}))) want)
      (:wat::core::= (:eopl::l-num (:eopl::l-run e (:eopl::Strategy.ByNeed {}))) want)
      false)
    false))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [d 400]
    (:wat::core::do
      (:c4::say "all three agree, used twice " (:wat::core::if (:c4::agree? (:c4::used-twice 50) 0) "PASS" "FAIL"))
      (:c4::say "all three agree, never used " (:wat::core::if (:c4::agree? (:c4::never-used 50) 42) "PASS" "FAIL"))
      (:wat::kernel::println "---- the same answer, three different costs ----")
      (:c4::row "argument used TWICE " (:c4::used-twice d))
      (:c4::row "argument NEVER used " (:c4::never-used d)))))
