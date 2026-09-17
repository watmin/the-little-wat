;; eopl/lib/types.wat — EOPL chapter 7: type reconstruction by unification.
;;
;; The INFERRED language of §7.4, applied to the unannotated LETREC syntax already in lib/letrec.wat
;; -- so no new expression type is needed and the inferencer reads the same programs the
;; interpreters run. That is the point of the chapter: the checker and the evaluator agree about
;; what a program means, or one of them is wrong.
;;
;; Everything is a Pure enum. Substitutions are an association list, which is the honest EOPL
;; representation; the occurs check is explicit, because omitting it is the classic way to get a
;; type checker that loops instead of rejecting.

(:wat::load-file! "letrec.wat")

(:wat::core::defenum :eopl::Type :wat::enum::Pure
  :TInt  []
  :TBool []
  :TFun  [arg <- :eopl::Type  res <- :eopl::Type]
  :TVar  [id <- :wat::core::i64])

(:wat::core::defenum :eopl::Subst :wat::enum::Pure
  :SEmpty []
  :SBind  [id <- :wat::core::i64  ty <- :eopl::Type  rest <- :eopl::Subst])

(:wat::core::defenum :eopl::TyEnv :wat::enum::Pure
  :TyEmpty  []
  :TyExtend [name <- :wat::core::String  ty <- :eopl::Type  rest <- :eopl::TyEnv])

;; the result of inference: a type, the substitution learned so far, and the next fresh variable
(:wat::core::defenum :eopl::Res :wat::enum::Pure
  :ROk  [ty <- :eopl::Type  sub <- :eopl::Subst  next <- :wat::core::i64]
  :RErr [msg <- :wat::core::String])

(:wat::core::defn :eopl::ty-lookup [env <- :eopl::TyEnv name <- :wat::core::String] -> :eopl::Type
  (:wat::core::match env
    [:eopl::TyEnv.TyEmpty {} (:eopl::Type.TVar {:id -1})]
    [:eopl::TyEnv.TyExtend {:name n :ty ty :rest rest}
      (:wat::core::if (:wat::core::= n name) ty (:eopl::ty-lookup rest name))]))

(:wat::core::defn :eopl::sub-lookup [s <- :eopl::Subst id <- :wat::core::i64] -> :eopl::Type
  (:wat::core::match s
    [:eopl::Subst.SEmpty {} (:eopl::Type.TVar {:id id})]
    [:eopl::Subst.SBind {:id i :ty ty :rest rest}
      (:wat::core::if (:wat::core::= i id) ty (:eopl::sub-lookup rest id))]))

;; apply a substitution all the way down
(:wat::core::defn :eopl::apply-sub [t <- :eopl::Type s <- :eopl::Subst] -> :eopl::Type
  (:wat::core::match t
    [:eopl::Type.TInt {} t]
    [:eopl::Type.TBool {} t]
    [:eopl::Type.TFun {:arg a :res r}
      (:eopl::Type.TFun {:arg (:eopl::apply-sub a s) :res (:eopl::apply-sub r s)})]
    [:eopl::Type.TVar {:id id}
      (:wat::core::let [found (:eopl::sub-lookup s id)]
        (:wat::core::match found
          [:eopl::Type.TVar {:id id2}
            (:wat::core::if (:wat::core::= id2 id) t (:eopl::apply-sub found s))]
          [:eopl::Type.TInt {} found]
          [:eopl::Type.TBool {} found]
          [:eopl::Type.TFun {:arg a :res r} (:eopl::apply-sub found s)]))]))

;; THE OCCURS CHECK. Without it `proc(x) (x x)` builds an infinite type and the checker loops
;; instead of rejecting -- the classic omission.
(:wat::core::defn :eopl::occurs? [id <- :wat::core::i64 t <- :eopl::Type] -> :wat::core::bool
  (:wat::core::match t
    [:eopl::Type.TInt {} false]
    [:eopl::Type.TBool {} false]
    [:eopl::Type.TVar {:id i} (:wat::core::= i id)]
    [:eopl::Type.TFun {:arg a :res r}
      (:wat::core::if (:eopl::occurs? id a) true (:eopl::occurs? id r))]))

(:wat::core::defenum :eopl::URes :wat::enum::Pure
  :UOk  [sub <- :eopl::Subst]
  :UErr [msg <- :wat::core::String])

(:wat::core::defn :eopl::unify [t1 <- :eopl::Type t2 <- :eopl::Type s <- :eopl::Subst] -> :eopl::URes
  (:wat::core::let [a (:eopl::apply-sub t1 s) b (:eopl::apply-sub t2 s)]
    (:wat::core::match a
      [:eopl::Type.TVar {:id id}
        (:wat::core::match b
          [:eopl::Type.TVar {:id id2}
            (:wat::core::if (:wat::core::= id id2) (:eopl::URes.UOk {:sub s})
              (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty b :rest s})}))]
          [:eopl::Type.TInt {} (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty b :rest s})})]
          [:eopl::Type.TBool {} (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty b :rest s})})]
          [:eopl::Type.TFun {:arg x :res y}
            (:wat::core::if (:eopl::occurs? id b)
              (:eopl::URes.UErr {:msg "occurs check: infinite type"})
              (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty b :rest s})}))])]
      [:eopl::Type.TInt {}
        (:wat::core::match b
          [:eopl::Type.TInt {} (:eopl::URes.UOk {:sub s})]
          [:eopl::Type.TVar {:id id} (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty a :rest s})})]
          [:eopl::Type.TBool {} (:eopl::URes.UErr {:msg "int vs bool"})]
          [:eopl::Type.TFun {:arg x :res y} (:eopl::URes.UErr {:msg "int vs function"})])]
      [:eopl::Type.TBool {}
        (:wat::core::match b
          [:eopl::Type.TBool {} (:eopl::URes.UOk {:sub s})]
          [:eopl::Type.TVar {:id id} (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty a :rest s})})]
          [:eopl::Type.TInt {} (:eopl::URes.UErr {:msg "bool vs int"})]
          [:eopl::Type.TFun {:arg x :res y} (:eopl::URes.UErr {:msg "bool vs function"})])]
      [:eopl::Type.TFun {:arg a1 :res r1}
        (:wat::core::match b
          [:eopl::Type.TFun {:arg a2 :res r2}
            (:wat::core::match (:eopl::unify a1 a2 s)
              [:eopl::URes.UErr {:msg m} (:eopl::URes.UErr {:msg m})]
              [:eopl::URes.UOk {:sub s2} (:eopl::unify r1 r2 s2)])]
          [:eopl::Type.TVar {:id id}
            (:wat::core::if (:eopl::occurs? id a)
              (:eopl::URes.UErr {:msg "occurs check: infinite type"})
              (:eopl::URes.UOk {:sub (:eopl::Subst.SBind {:id id :ty a :rest s})}))]
          [:eopl::Type.TInt {} (:eopl::URes.UErr {:msg "function vs int"})]
          [:eopl::Type.TBool {} (:eopl::URes.UErr {:msg "function vs bool"})])])))

(:wat::core::defn :eopl::ty->string [t <- :eopl::Type] -> :wat::core::String
  (:wat::core::match t
    [:eopl::Type.TInt {} "int"]
    [:eopl::Type.TBool {} "bool"]
    [:eopl::Type.TVar {:id id} (:wat::string::concat "t" (:wat::i64::to-string id))]
    [:eopl::Type.TFun {:arg a :res r}
      (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "(" (:eopl::ty->string a) " -> " (:eopl::ty->string r) ")"))]))

;; ─── inference: reconstruct a type for the UNANNOTATED syntax ─────────────────────────────────
;; `infer` threads two things: the substitution learned so far, and the next fresh variable id.
;; EOPL writes this with a mutable counter; wat has none outside a service (F-051 charges 224 µs a
;; message), so the counter is threaded, which is also what makes the function pure.

(:wat::core::defn :eopl::infer
  [e <- :eopl::Exp env <- :eopl::TyEnv s <- :eopl::Subst n <- :wat::core::i64] -> :eopl::Res
  (:wat::core::match e
    [:eopl::Exp.Const {:n k} (:eopl::Res.ROk {:ty (:eopl::Type.TInt {}) :sub s :next n})]
    [:eopl::Exp.Var {:name name} (:eopl::Res.ROk {:ty (:eopl::ty-lookup env name) :sub s :next n})]

    [:eopl::Exp.Diff {:a a :b b}
      (:wat::core::match (:eopl::infer a env s n)
        [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
        [:eopl::Res.ROk {:ty ta :sub s1 :next n1}
          (:wat::core::match (:eopl::unify ta (:eopl::Type.TInt {}) s1)
            [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "diff lhs: " m)})]
            [:eopl::URes.UOk {:sub s2}
              (:wat::core::match (:eopl::infer b env s2 n1)
                [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
                [:eopl::Res.ROk {:ty tb :sub s3 :next n2}
                  (:wat::core::match (:eopl::unify tb (:eopl::Type.TInt {}) s3)
                    [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "diff rhs: " m)})]
                    [:eopl::URes.UOk {:sub s4}
                      (:eopl::Res.ROk {:ty (:eopl::Type.TInt {}) :sub s4 :next n2})])])])])]

    [:eopl::Exp.IsZero {:e inner}
      (:wat::core::match (:eopl::infer inner env s n)
        [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
        [:eopl::Res.ROk {:ty ti :sub s1 :next n1}
          (:wat::core::match (:eopl::unify ti (:eopl::Type.TInt {}) s1)
            [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "zero?: " m)})]
            [:eopl::URes.UOk {:sub s2} (:eopl::Res.ROk {:ty (:eopl::Type.TBool {}) :sub s2 :next n1})])])]

    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::match (:eopl::infer c env s n)
        [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
        [:eopl::Res.ROk {:ty tc :sub s1 :next n1}
          (:wat::core::match (:eopl::unify tc (:eopl::Type.TBool {}) s1)
            [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "if test: " m)})]
            [:eopl::URes.UOk {:sub s2}
              (:wat::core::match (:eopl::infer t env s2 n1)
                [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
                [:eopl::Res.ROk {:ty tt :sub s3 :next n2}
                  (:wat::core::match (:eopl::infer f env s3 n2)
                    [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
                    [:eopl::Res.ROk {:ty tf :sub s4 :next n3}
                      (:wat::core::match (:eopl::unify tt tf s4)
                        [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "if branches: " m)})]
                        [:eopl::URes.UOk {:sub s5} (:eopl::Res.ROk {:ty tt :sub s5 :next n3})])])])])])]

    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:eopl::infer rhs env s n)
        [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
        [:eopl::Res.ROk {:ty tr :sub s1 :next n1}
          (:eopl::infer body (:eopl::TyEnv.TyExtend {:name name :ty tr :rest env}) s1 n1)])]

    [:eopl::Exp.Proc {:param param :body body}
      (:wat::core::let [tv (:eopl::Type.TVar {:id n})]
        (:wat::core::match (:eopl::infer body
                             (:eopl::TyEnv.TyExtend {:name param :ty tv :rest env})
                             s (:wat::core::+ n 1))
          [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
          [:eopl::Res.ROk {:ty tb :sub s1 :next n1}
            (:eopl::Res.ROk {:ty (:eopl::Type.TFun {:arg tv :res tb}) :sub s1 :next n1})]))]

    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:eopl::infer rator env s n)
        [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
        [:eopl::Res.ROk {:ty tf :sub s1 :next n1}
          (:wat::core::match (:eopl::infer rand env s1 n1)
            [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
            [:eopl::Res.ROk {:ty ta :sub s2 :next n2}
              (:wat::core::let [tr (:eopl::Type.TVar {:id n2})]
                (:wat::core::match (:eopl::unify tf (:eopl::Type.TFun {:arg ta :res tr}) s2)
                  [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "call: " m)})]
                  [:eopl::URes.UOk {:sub s3}
                    (:eopl::Res.ROk {:ty tr :sub s3 :next (:wat::core::+ n2 1)})]))])])]

    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::let
        [tx (:eopl::Type.TVar {:id n})
         tr (:eopl::Type.TVar {:id (:wat::core::+ n 1)})
         n1 (:wat::core::+ n 2)
         envf (:eopl::TyEnv.TyExtend {:name fname :ty (:eopl::Type.TFun {:arg tx :res tr}) :rest env})
         envb (:eopl::TyEnv.TyExtend {:name param :ty tx :rest envf})]
        (:wat::core::match (:eopl::infer fbody envb s n1)
          [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
          [:eopl::Res.ROk {:ty tb :sub s1 :next n2}
            (:wat::core::match (:eopl::unify tb tr s1)
              [:eopl::URes.UErr {:msg m} (:eopl::Res.RErr {:msg (:wat::string::concat "letrec body: " m)})]
              [:eopl::URes.UOk {:sub s2} (:eopl::infer body envf s2 n2)])]))]))

;; the entry point: infer, then resolve the answer through the substitution
(:wat::core::defn :eopl::type-of [e <- :eopl::Exp] -> :eopl::Res
  (:wat::core::match (:eopl::infer e (:eopl::TyEnv.TyEmpty {}) (:eopl::Subst.SEmpty {}) 0)
    [:eopl::Res.RErr {:msg m} (:eopl::Res.RErr {:msg m})]
    [:eopl::Res.ROk {:ty t :sub s :next n}
      (:eopl::Res.ROk {:ty (:eopl::apply-sub t s) :sub s :next n})]))
