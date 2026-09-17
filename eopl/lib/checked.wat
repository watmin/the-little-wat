;; eopl/lib/checked.wat — EOPL chapter 7's CHECKED language: a checker, not an inferencer.
;;
;; The difference from lib/types.wat is the whole point of the pairing. INFERRED *invents* types
;; and has no annotation to disagree with. CHECKED is given annotations and its job is to catch
;; the ones that are WRONG -- a question inference cannot even ask, because there is nothing to
;; compare against.
;;
;; So there is no unification and there are no type variables here: types are declared, and the
;; checker compares them for equality. That makes it the simpler algorithm and the stricter tool.
;;
;; Reuses `:eopl::Type` and `ty->string` from lib/types.wat.

(:wat::load-file! "types.wat")

(:wat::core::defenum :chk::Exp :wat::enum::Pure
  :Lit    [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Diff   [a <- :chk::Exp  b <- :chk::Exp]
  :IsZero [e <- :chk::Exp]
  :If     [c <- :chk::Exp  t <- :chk::Exp  f <- :chk::Exp]
  :Let    [name <- :wat::core::String  e <- :chk::Exp  body <- :chk::Exp]
  ;; the annotations -- this is what CHECKED adds
  :Proc   [param <- :wat::core::String  ptype <- :eopl::Type  body <- :chk::Exp]
  :Call   [rator <- :chk::Exp  rand <- :chk::Exp]
  :Letrec [rtype <- :eopl::Type  fname <- :wat::core::String
           param <- :wat::core::String  ptype <- :eopl::Type
           fbody <- :chk::Exp  body <- :chk::Exp])

(:wat::core::defenum :chk::Res :wat::enum::Pure
  :COk  [ty <- :eopl::Type]
  :CErr [msg <- :wat::core::String])

;; structural equality on types -- no unification, just "are these the same type"
(:wat::core::defn :chk::same? [a <- :eopl::Type b <- :eopl::Type] -> :wat::core::bool
  (:wat::core::match a
    [:eopl::Type.TInt {} (:wat::core::match b
                           [:eopl::Type.TInt {} true] [:eopl::Type.TBool {} false]
                           [:eopl::Type.TFun {:arg x :res y} false] [:eopl::Type.TVar {:id i} false])]
    [:eopl::Type.TBool {} (:wat::core::match b
                            [:eopl::Type.TBool {} true] [:eopl::Type.TInt {} false]
                            [:eopl::Type.TFun {:arg x :res y} false] [:eopl::Type.TVar {:id i} false])]
    [:eopl::Type.TVar {:id i} (:wat::core::match b
                                [:eopl::Type.TVar {:id j} (:wat::core::= i j)]
                                [:eopl::Type.TInt {} false] [:eopl::Type.TBool {} false]
                                [:eopl::Type.TFun {:arg x :res y} false])]
    [:eopl::Type.TFun {:arg a1 :res r1}
      (:wat::core::match b
        [:eopl::Type.TFun {:arg a2 :res r2}
          (:wat::core::if (:chk::same? a1 a2) (:chk::same? r1 r2) false)]
        [:eopl::Type.TInt {} false] [:eopl::Type.TBool {} false]
        [:eopl::Type.TVar {:id i} false])]))

(:wat::core::defn :chk::expect
  [got <- :eopl::Type want <- :eopl::Type where <- :wat::core::String] -> :chk::Res
  (:wat::core::if (:chk::same? got want)
    (:chk::Res.COk {:ty got})
    (:chk::Res.CErr {:msg (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      where ": expected " (:eopl::ty->string want) ", got " (:eopl::ty->string got)))})))

(:wat::core::defn :chk::type-of [e <- :chk::Exp env <- :eopl::TyEnv] -> :chk::Res
  (:wat::core::match e
    [:chk::Exp.Lit {:n n} (:chk::Res.COk {:ty (:eopl::Type.TInt {})})]
    [:chk::Exp.Var {:name name} (:chk::Res.COk {:ty (:eopl::ty-lookup env name)})]

    [:chk::Exp.Diff {:a a :b b}
      (:wat::core::match (:chk::type-of a env)
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty ta}
          (:wat::core::match (:chk::expect ta (:eopl::Type.TInt {}) "diff lhs")
            [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
            [:chk::Res.COk {:ty x}
              (:wat::core::match (:chk::type-of b env)
                [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                [:chk::Res.COk {:ty tb}
                  (:wat::core::match (:chk::expect tb (:eopl::Type.TInt {}) "diff rhs")
                    [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                    [:chk::Res.COk {:ty y} (:chk::Res.COk {:ty (:eopl::Type.TInt {})})])])])])]

    [:chk::Exp.IsZero {:e inner}
      (:wat::core::match (:chk::type-of inner env)
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty ti}
          (:wat::core::match (:chk::expect ti (:eopl::Type.TInt {}) "zero?")
            [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
            [:chk::Res.COk {:ty x} (:chk::Res.COk {:ty (:eopl::Type.TBool {})})])])]

    [:chk::Exp.If {:c c :t t :f f}
      (:wat::core::match (:chk::type-of c env)
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty tc}
          (:wat::core::match (:chk::expect tc (:eopl::Type.TBool {}) "if test")
            [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
            [:chk::Res.COk {:ty x}
              (:wat::core::match (:chk::type-of t env)
                [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                [:chk::Res.COk {:ty tt}
                  (:wat::core::match (:chk::type-of f env)
                    [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                    [:chk::Res.COk {:ty tf} (:chk::expect tf tt "if branches")])])])])]

    [:chk::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:chk::type-of rhs env)
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty tr}
          (:chk::type-of body (:eopl::TyEnv.TyExtend {:name name :ty tr :rest env}))])]

    ;; the declared parameter type is TAKEN, not guessed
    [:chk::Exp.Proc {:param param :ptype ptype :body body}
      (:wat::core::match (:chk::type-of body (:eopl::TyEnv.TyExtend {:name param :ty ptype :rest env}))
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty tb} (:chk::Res.COk {:ty (:eopl::Type.TFun {:arg ptype :res tb})})])]

    [:chk::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:chk::type-of rator env)
        [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
        [:chk::Res.COk {:ty tf}
          (:wat::core::match tf
            [:eopl::Type.TFun {:arg a :res r}
              (:wat::core::match (:chk::type-of rand env)
                [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                [:chk::Res.COk {:ty ta}
                  (:wat::core::match (:chk::expect ta a "call argument")
                    [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
                    [:chk::Res.COk {:ty x} (:chk::Res.COk {:ty r})])])]
            [:eopl::Type.TInt {} (:chk::Res.CErr {:msg "call: applying an int"})]
            [:eopl::Type.TBool {} (:chk::Res.CErr {:msg "call: applying a bool"})]
            [:eopl::Type.TVar {:id i} (:chk::Res.CErr {:msg "call: applying a type variable"})])])]

    ;; letrec declares BOTH the parameter and the result type, and both are checked
    [:chk::Exp.Letrec {:rtype rtype :fname fname :param param :ptype ptype :fbody fbody :body body}
      (:wat::core::let
        [envf (:eopl::TyEnv.TyExtend {:name fname :ty (:eopl::Type.TFun {:arg ptype :res rtype}) :rest env})
         envb (:eopl::TyEnv.TyExtend {:name param :ty ptype :rest envf})]
        (:wat::core::match (:chk::type-of fbody envb)
          [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
          [:chk::Res.COk {:ty tb}
            (:wat::core::match (:chk::expect tb rtype "letrec body")
              [:chk::Res.CErr {:msg m} (:chk::Res.CErr {:msg m})]
              [:chk::Res.COk {:ty x} (:chk::type-of body envf)])]))]))
