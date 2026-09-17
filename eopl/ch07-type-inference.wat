;; eopl/ch07-type-inference.wat — EOPL chapter 7: type reconstruction by unification.
;;
;; The most relevant chapter in the book for this repository, because wat is itself a typed
;; language heading for "typed Clojure": this is wat hosting a type system rather than being one.
;;
;; The inferencer reads the SAME unannotated syntax the chapter-5 interpreters run, so the two can
;; be cross-checked: every well-typed program is evaluated and its value's shape must match the
;; inferred type. A checker and an evaluator that disagree mean one of them is wrong, and only
;; running both can tell you.
;;
;; Five rejections are included because a type checker that accepts everything passes every
;; positive test. The last of them is the occurs check -- without it `proc(x) (x x)` builds an
;; infinite type and the checker loops instead of rejecting, which is the classic omission.
;;
;; Run: wat eopl/ch07-type-inference.wat

(:wat::load-file! "lib/types.wat")
(:wat::load-file! "lib/cps.wat")

(:wat::core::defn :c7::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :c7::infer-str [e <- :eopl::Exp] -> :wat::core::String
  (:wat::core::match (:eopl::type-of e)
    [:eopl::Res.ROk {:ty t :sub s :next n} (:eopl::ty->string t)]
    [:eopl::Res.RErr {:msg m} (:wat::string::concat "REJECTED: " m)]))

(:wat::core::defn :c7::accepted? [e <- :eopl::Exp] -> :wat::core::bool
  (:wat::core::match (:eopl::type-of e)
    [:eopl::Res.ROk {:ty t :sub s :next n} true]
    [:eopl::Res.RErr {:msg m} false]))

;; SOUNDNESS, informally: the inferred type must match the shape of the value the evaluator gives
(:wat::core::defn :c7::agrees? [e <- :eopl::Exp] -> :wat::core::bool
  (:wat::core::match (:eopl::type-of e)
    [:eopl::Res.RErr {:msg m} false]
    [:eopl::Res.ROk {:ty t :sub s :next n}
      (:wat::core::match t
        [:eopl::Type.TInt {}
          (:wat::core::match (:eopl::run e)
            [:eopl::Val.Num {:n k} true] [:eopl::Val.Bool {:b b} false]
            [:eopl::Val.Clo {:param p :body bd :env en} false])]
        [:eopl::Type.TBool {}
          (:wat::core::match (:eopl::run e)
            [:eopl::Val.Bool {:b b} true] [:eopl::Val.Num {:n k} false]
            [:eopl::Val.Clo {:param p :body bd :env en} false])]
        [:eopl::Type.TFun {:arg a :res r}
          (:wat::core::match (:eopl::run e)
            [:eopl::Val.Clo {:param p :body bd :env en} true]
            [:eopl::Val.Num {:n k} false] [:eopl::Val.Bool {:b b} false])]
        [:eopl::Type.TVar {:id id} false])]))

;; --- the programs ------------------------------------------------------------------------------
(:wat::core::defn :c7::e1 [] -> :eopl::Exp   ;; -(3,2)
  (:eopl::Exp.Diff {:a (:eopl::Exp.Const {:n 3}) :b (:eopl::Exp.Const {:n 2})}))
(:wat::core::defn :c7::e2 [] -> :eopl::Exp   ;; zero?(0)
  (:eopl::Exp.IsZero {:e (:eopl::Exp.Const {:n 0})}))
(:wat::core::defn :c7::e3 [] -> :eopl::Exp   ;; proc(x) -(x,1)
  (:eopl::Exp.Proc {:param "x"
    :body (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "x"}) :b (:eopl::Exp.Const {:n 1})})}))
(:wat::core::defn :c7::e4 [] -> :eopl::Exp   ;; (proc(x) -(x,1))(3)
  (:eopl::Exp.Call {:rator (:c7::e3) :rand (:eopl::Exp.Const {:n 3})}))
(:wat::core::defn :c7::e5 [] -> :eopl::Exp   ;; letrec f(n) = if zero?(n) then 0 else f(-(n,1)) in f(5)
  (:eopl::Exp.Letrec
    {:fname "f" :param "n"
     :fbody (:eopl::Exp.If
              {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name "n"})})
               :t (:eopl::Exp.Const {:n 0})
               :f (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"})
                                    :rand (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "n"})
                                                            :b (:eopl::Exp.Const {:n 1})})})})
     :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "f"}) :rand (:eopl::Exp.Const {:n 5})})}))

;; --- programs that MUST be rejected ------------------------------------------------------------
(:wat::core::defn :c7::bad1 [] -> :eopl::Exp   ;; -(zero?(0), 1)  -- bool where int
  (:eopl::Exp.Diff {:a (:eopl::Exp.IsZero {:e (:eopl::Exp.Const {:n 0})}) :b (:eopl::Exp.Const {:n 1})}))
(:wat::core::defn :c7::bad2 [] -> :eopl::Exp   ;; if 1 then 2 else 3  -- int test
  (:eopl::Exp.If {:c (:eopl::Exp.Const {:n 1}) :t (:eopl::Exp.Const {:n 2}) :f (:eopl::Exp.Const {:n 3})}))
(:wat::core::defn :c7::bad3 [] -> :eopl::Exp   ;; branches disagree
  (:eopl::Exp.If {:c (:eopl::Exp.IsZero {:e (:eopl::Exp.Const {:n 0})})
                  :t (:eopl::Exp.Const {:n 1})
                  :f (:eopl::Exp.IsZero {:e (:eopl::Exp.Const {:n 1})})}))
(:wat::core::defn :c7::bad4 [] -> :eopl::Exp   ;; (3)(4)  -- applying a non-function
  (:eopl::Exp.Call {:rator (:eopl::Exp.Const {:n 3}) :rand (:eopl::Exp.Const {:n 4})}))
(:wat::core::defn :c7::bad5 [] -> :eopl::Exp   ;; proc(x) (x x)  -- the OCCURS CHECK
  (:eopl::Exp.Proc {:param "x"
    :body (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name "x"}) :rand (:eopl::Exp.Var {:name "x"})})}))

(:wat::core::defn :c7::ok [label <- :wat::core::String e <- :eopl::Exp] -> :wat::core::nil
  (:c7::say (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    (:wat::core::if (:c7::agrees? e) "PASS  " "FAIL  ") label))
    (:c7::infer-str e)))

(:wat::core::defn :c7::rej [label <- :wat::core::String e <- :eopl::Exp] -> :wat::core::nil
  (:c7::say (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    (:wat::core::if (:c7::accepted? e) "FAIL  " "PASS  ") label))
    (:c7::infer-str e)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- inferred, and the evaluator agrees with the type ----")
    (:c7::ok "-(3,2)                     " (:c7::e1))
    (:c7::ok "zero?(0)                   " (:c7::e2))
    (:c7::ok "proc(x) -(x,1)             " (:c7::e3))
    (:c7::ok "(proc(x) -(x,1))(3)        " (:c7::e4))
    (:c7::ok "letrec countdown           " (:c7::e5))
    (:wat::kernel::println "---- must be REJECTED (a checker that accepts everything passes every positive test) ----")
    (:c7::rej "-(zero?(0), 1)             " (:c7::bad1))
    (:c7::rej "if 1 then 2 else 3         " (:c7::bad2))
    (:c7::rej "if .. then 1 else zero?(1) " (:c7::bad3))
    (:c7::rej "(3)(4)                     " (:c7::bad4))
    (:c7::rej "proc(x) (x x)  [occurs]    " (:c7::bad5))))
