;; eopl/ch07-checked.wat — EOPL chapter 7's CHECKED language, and why the book ships both.
;;
;; This file exists because of a correction. I reported chapter 7 as done having built only
;; INFERRED (C-063), which is half of it: EOPL pairs a CHECKER with an INFERENCER on purpose, and
;; the pairing is the lesson.
;;
;; INFERRED invents types and therefore has NO ANNOTATION TO DISAGREE WITH. CHECKED is given
;; annotations, and its job is to catch the ones that are WRONG -- a question inference cannot
;; even ask. The last row below is the whole point: one program, rejected by the checker and
;; happily accepted by the inferencer, which quietly infers a *different* type than the one the
;; programmer wrote down.
;;
;; Run: wat eopl/ch07-checked.wat

(:wat::load-file! "lib/checked.wat")

(:wat::core::defn :cc::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :cc::check [e <- :chk::Exp] -> :wat::core::String
  (:wat::core::match (:chk::type-of e (:eopl::TyEnv.TyEmpty {}))
    [:chk::Res.COk {:ty t} (:eopl::ty->string t)]
    [:chk::Res.CErr {:msg m} (:wat::string::concat "REJECTED: " m)]))

(:wat::core::defn :cc::accepted? [e <- :chk::Exp] -> :wat::core::bool
  (:wat::core::match (:chk::type-of e (:eopl::TyEnv.TyEmpty {}))
    [:chk::Res.COk {:ty t} true] [:chk::Res.CErr {:msg m} false]))

(:wat::core::defn :cc::ok [label <- :wat::core::String e <- :chk::Exp] -> :wat::core::nil
  (:cc::say (:wat::string::concat (:wat::core::if (:cc::accepted? e) "PASS  " "FAIL  ") label) (:cc::check e)))
(:wat::core::defn :cc::rej [label <- :wat::core::String e <- :chk::Exp] -> :wat::core::nil
  (:cc::say (:wat::string::concat (:wat::core::if (:cc::accepted? e) "FAIL  " "PASS  ") label) (:cc::check e)))

(:wat::core::defn :cc::int [] -> :eopl::Type (:eopl::Type.TInt {}))
(:wat::core::defn :cc::bool [] -> :eopl::Type (:eopl::Type.TBool {}))

;; proc(x : int) -(x,1)
(:wat::core::defn :cc::good-proc [] -> :chk::Exp
  (:chk::Exp.Proc {:param "x" :ptype (:cc::int)
    :body (:chk::Exp.Diff {:a (:chk::Exp.Var {:name "x"}) :b (:chk::Exp.Lit {:n 1})})}))

;; letrec int f(n : int) = if zero?(n) then 0 else f(-(n,1)) in f(5)
(:wat::core::defn :cc::good-letrec [] -> :chk::Exp
  (:chk::Exp.Letrec
    {:rtype (:cc::int) :fname "f" :param "n" :ptype (:cc::int)
     :fbody (:chk::Exp.If
              {:c (:chk::Exp.IsZero {:e (:chk::Exp.Var {:name "n"})})
               :t (:chk::Exp.Lit {:n 0})
               :f (:chk::Exp.Call {:rator (:chk::Exp.Var {:name "f"})
                                   :rand (:chk::Exp.Diff {:a (:chk::Exp.Var {:name "n"})
                                                          :b (:chk::Exp.Lit {:n 1})})})})
     :body (:chk::Exp.Call {:rator (:chk::Exp.Var {:name "f"}) :rand (:chk::Exp.Lit {:n 5})})}))

;; --- wrong ANNOTATIONS: the class of error only a checker can see --------------------------
;; proc(x : bool) -(x,1)   -- declared bool, used as int
(:wat::core::defn :cc::wrong-param [] -> :chk::Exp
  (:chk::Exp.Proc {:param "x" :ptype (:cc::bool)
    :body (:chk::Exp.Diff {:a (:chk::Exp.Var {:name "x"}) :b (:chk::Exp.Lit {:n 1})})}))

;; letrec bool f(n : int) = -(n,1) in f(5)   -- body returns int, declared bool
(:wat::core::defn :cc::wrong-result [] -> :chk::Exp
  (:chk::Exp.Letrec
    {:rtype (:cc::bool) :fname "f" :param "n" :ptype (:cc::int)
     :fbody (:chk::Exp.Diff {:a (:chk::Exp.Var {:name "n"}) :b (:chk::Exp.Lit {:n 1})})
     :body (:chk::Exp.Call {:rator (:chk::Exp.Var {:name "f"}) :rand (:chk::Exp.Lit {:n 5})})}))

;; (proc(x : int) x)(zero?(0))   -- argument type does not match the annotation
(:wat::core::defn :cc::wrong-arg [] -> :chk::Exp
  (:chk::Exp.Call {:rator (:chk::Exp.Proc {:param "x" :ptype (:cc::int) :body (:chk::Exp.Var {:name "x"})})
                   :rand (:chk::Exp.IsZero {:e (:chk::Exp.Lit {:n 0})})}))

;; the same shape as :cc::wrong-param, but UNANNOTATED, for the inferencer
(:wat::core::defn :cc::same-unannotated [] -> :eopl::Exp
  (:eopl::Exp.Proc {:param "x"
    :body (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name "x"}) :b (:eopl::Exp.Const {:n 1})})}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- annotated and correct ----")
    (:cc::ok  "proc(x : int) -(x,1)          " (:cc::good-proc))
    (:cc::ok  "letrec int f(n : int) = ...   " (:cc::good-letrec))
    (:wat::kernel::println "---- WRONG ANNOTATIONS: the class only a checker can see ----")
    (:cc::rej "proc(x : bool) -(x,1)         " (:cc::wrong-param))
    (:cc::rej "letrec bool f(n : int) = -(n,1)" (:cc::wrong-result))
    (:cc::rej "(proc(x : int) x)(zero?(0))   " (:cc::wrong-arg))
    (:wat::kernel::println "---- why EOPL ships both ----")
    (:cc::say "  CHECKED on proc(x : bool) -(x,1)" (:cc::check (:cc::wrong-param)))
    (:cc::say "  INFERRED on the same shape, unannotated"
      (:wat::core::match (:eopl::type-of (:cc::same-unannotated))
        [:eopl::Res.ROk {:ty t :sub s :next n} (:wat::string::concat "accepted as " (:eopl::ty->string t))]
        [:eopl::Res.RErr {:msg m} (:wat::string::concat "REJECTED: " m)]))
    (:wat::kernel::println "     -- the inferencer has no annotation to disagree with, so it cannot")
    (:wat::kernel::println "        catch a programmer who wrote down the wrong type.")))
