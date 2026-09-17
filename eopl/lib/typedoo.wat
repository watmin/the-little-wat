;; eopl/lib/typedoo.wat — EOPL chapter 9.4-9.5: TYPED-OO, a checker with SUBTYPING.
;;
;; CLASSES (eopl/lib/classes.wat) runs the program; this checks it. The new idea over chapter 7's
;; CHECKED is SUBSUMPTION: a `c2` may be used where a `c1` is wanted, because every c2 is a c1.
;; That is the first type rule in this repository that is not an equality.
;;
;; The consequence worth demonstrating is the one that surprises people: a `send` is checked
;; against the receiver's STATIC type, so `send (c1-valued expression) m3()` is rejected even when
;; the value at runtime would be a c2 that has `m3`. The checker is rejecting a program that would
;; have worked -- which is what a sound checker over subtyping must do, and the same shape as
;; C-071's opaque types: the declared view, not the actual one.

(:wat::core::defenum :to::Type :wat::enum::Pure
  :TInt   []
  :TBool  []
  :TClass [name <- :wat::core::String])

(:wat::core::defenum :to::Types :wat::enum::Pure
  :TNil [] :TCons [t <- :to::Type  rest <- :to::Types])

;; a method's SIGNATURE is all the checker needs
(:wat::core::defenum :to::MDecl :wat::enum::Pure
  :MD [name <- :wat::core::String  params <- :to::Types  result <- :to::Type])

(:wat::core::defenum :to::MDecls :wat::enum::Pure
  :MNil [] :MCons [m <- :to::MDecl  rest <- :to::MDecls])

;; `super` is "" for a root class; `iface` is the interface it claims to implement ("" for none)
(:wat::core::defenum :to::CDecl :wat::enum::Pure
  :CD [name <- :wat::core::String  super <- :wat::core::String  iface <- :wat::core::String
       methods <- :to::MDecls])

(:wat::core::defenum :to::CDecls :wat::enum::Pure
  :CNil [] :CCons [c <- :to::CDecl  rest <- :to::CDecls])

(:wat::core::defenum :to::IDecl :wat::enum::Pure
  :ID [name <- :wat::core::String  methods <- :to::MDecls])

(:wat::core::defenum :to::IDecls :wat::enum::Pure
  :INil [] :ICons [i <- :to::IDecl  rest <- :to::IDecls])

(:wat::core::defenum :to::Exp :wat::enum::Pure
  :Lit  [n <- :wat::core::i64]
  :Var  [name <- :wat::core::String]
  :Diff [a <- :to::Exp  b <- :to::Exp]
  :New  [cls <- :wat::core::String]
  :Send [obj <- :to::Exp  meth <- :wat::core::String  args <- :to::Exps]
  ;; call a one-argument function whose parameter type is declared -- how subsumption is exercised
  :Apply [ptype <- :to::Type  arg <- :to::Exp  result <- :to::Type])

(:wat::core::defenum :to::Exps :wat::enum::Pure
  :ENil [] :ECons [e <- :to::Exp  rest <- :to::Exps])

(:wat::core::defenum :to::TEnv :wat::enum::Pure
  :VNil [] :VBind [name <- :wat::core::String  ty <- :to::Type  rest <- :to::TEnv])

(:wat::core::defenum :to::Res :wat::enum::Pure
  :Ok  [ty <- :to::Type]
  :Err [msg <- :wat::core::String])

(:wat::core::defn :to::show [t <- :to::Type] -> :wat::core::String
  (:wat::core::match t
    [:to::Type.TInt {} "int"]
    [:to::Type.TBool {} "bool"]
    [:to::Type.TClass {:name n} n]))

(:wat::core::defn :to::find-class [cs <- :to::CDecls name <- :wat::core::String] -> :to::CDecl
  (:wat::core::match cs
    [:to::CDecls.CNil {} (:to::CDecl.CD {:name "" :super "" :iface "" :methods (:to::MDecls.MNil {})})]
    [:to::CDecls.CCons {:c c :rest rest}
      (:wat::core::match c
        [:to::CDecl.CD {:name n :super sp :iface i :methods ms}
          (:wat::core::if (:wat::core::= n name) c (:to::find-class rest name))])]))

(:wat::core::defn :to::find-iface [is <- :to::IDecls name <- :wat::core::String] -> :to::IDecl
  (:wat::core::match is
    [:to::IDecls.INil {} (:to::IDecl.ID {:name "" :methods (:to::MDecls.MNil {})})]
    [:to::IDecls.ICons {:i i :rest rest}
      (:wat::core::match i
        [:to::IDecl.ID {:name n :methods ms}
          (:wat::core::if (:wat::core::= n name) i (:to::find-iface rest name))])]))

;; ---- SUBTYPING: walk up the class chain, and check the interface a class claims ----
(:wat::core::defn :to::class-sub? [cs <- :to::CDecls a <- :wat::core::String b <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::= a b) true
    (:wat::core::if (:wat::core::= a "") false
      (:wat::core::match (:to::find-class cs a)
        [:to::CDecl.CD {:name n :super sp :iface i :methods ms}
          (:wat::core::if (:wat::core::= n "") false
            ;; a class is a subtype of its superclass AND of the interface it implements
            (:wat::core::if (:wat::core::= i b) true (:to::class-sub? cs sp b)))]))))

(:wat::core::defn :to::subtype? [cs <- :to::CDecls a <- :to::Type b <- :to::Type] -> :wat::core::bool
  (:wat::core::match a
    [:to::Type.TInt {} (:wat::core::match b
                         [:to::Type.TInt {} true]
                         [:to::Type.TBool {} false]
                         [:to::Type.TClass {:name n} false])]
    [:to::Type.TBool {} (:wat::core::match b
                          [:to::Type.TBool {} true]
                          [:to::Type.TInt {} false]
                          [:to::Type.TClass {:name n} false])]
    [:to::Type.TClass {:name an}
      (:wat::core::match b
        [:to::Type.TClass {:name bn} (:to::class-sub? cs an bn)]
        [:to::Type.TInt {} false]
        [:to::Type.TBool {} false])]))

;; a method is found by walking UP, exactly as at run time -- but from the STATIC class
(:wat::core::defn :to::find-method-here [ms <- :to::MDecls name <- :wat::core::String] -> :to::MDecl
  (:wat::core::match ms
    [:to::MDecls.MNil {} (:to::MDecl.MD {:name "" :params (:to::Types.TNil {}) :result (:to::Type.TInt {})})]
    [:to::MDecls.MCons {:m m :rest rest}
      (:wat::core::match m
        [:to::MDecl.MD {:name n :params ps :result r}
          (:wat::core::if (:wat::core::= n name) m (:to::find-method-here rest name))])]))

(:wat::core::defn :to::lookup-method
  [cs <- :to::CDecls is <- :to::IDecls cls <- :wat::core::String name <- :wat::core::String] -> :to::MDecl
  (:wat::core::if (:wat::core::= cls "")
    (:to::MDecl.MD {:name "" :params (:to::Types.TNil {}) :result (:to::Type.TInt {})})
    (:wat::core::match (:to::find-class cs cls)
      [:to::CDecl.CD {:name n :super sp :iface i :methods ms}
        (:wat::core::if (:wat::core::= n "")
          ;; not a class -- it may be an INTERFACE, whose methods are all a caller may assume
          (:wat::core::match (:to::find-iface is cls)
            [:to::IDecl.ID {:name inm :methods ims} (:to::find-method-here ims name)])
          (:wat::core::match (:to::find-method-here ms name)
            [:to::MDecl.MD {:name mn :params ps :result r}
              (:wat::core::if (:wat::core::= mn "")
                (:to::lookup-method cs is sp name)
                (:to::find-method-here ms name))]))])))

(:wat::core::defn :to::check-args
  [as <- :to::Exps ps <- :to::Types env <- :to::TEnv cs <- :to::CDecls is <- :to::IDecls
   meth <- :wat::core::String] -> :to::Res
  (:wat::core::match as
    [:to::Exps.ENil {}
      (:wat::core::match ps
        [:to::Types.TNil {} (:to::Res.Ok {:ty (:to::Type.TInt {})})]
        [:to::Types.TCons {:t t :rest r}
          (:to::Res.Err {:msg (:wat::string::concat meth ": too few arguments")})])]
    [:to::Exps.ECons {:e e :rest arest}
      (:wat::core::match ps
        [:to::Types.TNil {} (:to::Res.Err {:msg (:wat::string::concat meth ": too many arguments")})]
        [:to::Types.TCons {:t want :rest prest}
          (:wat::core::match (:to::type-of e env cs is)
            [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
            [:to::Res.Ok {:ty got}
              ;; SUBSUMPTION: the argument need only be a SUBTYPE of the parameter
              (:wat::core::if (:to::subtype? cs got want)
                (:to::check-args arest prest env cs is meth)
                (:to::Res.Err {:msg (:wat::string::concat meth ": argument expects "
                                      (:to::show want) ", got " (:to::show got))}))])])]))

(:wat::core::defn :to::type-of
  [e <- :to::Exp env <- :to::TEnv cs <- :to::CDecls is <- :to::IDecls] -> :to::Res
  (:wat::core::match e
    [:to::Exp.Lit {:n n} (:to::Res.Ok {:ty (:to::Type.TInt {})})]
    [:to::Exp.Var {:name name}
      (:wat::core::match env
        [:to::TEnv.VNil {} (:to::Res.Err {:msg (:wat::string::concat "unbound " name)})]
        [:to::TEnv.VBind {:name n :ty ty :rest rest}
          (:wat::core::if (:wat::core::= n name) (:to::Res.Ok {:ty ty})
            (:to::type-of (:to::Exp.Var {:name name}) rest cs is))])]
    [:to::Exp.Diff {:a a :b b}
      (:wat::core::match (:to::type-of a env cs is)
        [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
        [:to::Res.Ok {:ty ta}
          (:wat::core::match (:to::type-of b env cs is)
            [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
            [:to::Res.Ok {:ty tb} (:to::Res.Ok {:ty (:to::Type.TInt {})})])])]
    [:to::Exp.New {:cls cls} (:to::Res.Ok {:ty (:to::Type.TClass {:name cls})})]

    ;; a send is checked against the receiver's STATIC type — the heart of the chapter
    [:to::Exp.Send {:obj obje :meth meth :args args}
      (:wat::core::match (:to::type-of obje env cs is)
        [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
        [:to::Res.Ok {:ty tr}
          (:wat::core::match tr
            [:to::Type.TClass {:name cn}
              (:wat::core::match (:to::lookup-method cs is cn meth)
                [:to::MDecl.MD {:name mn :params ps :result r}
                  (:wat::core::if (:wat::core::= mn "")
                    (:to::Res.Err {:msg (:wat::string::concat "no method " meth " on " cn)})
                    (:wat::core::match (:to::check-args args ps env cs is meth)
                      [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
                      [:to::Res.Ok {:ty t} (:to::Res.Ok {:ty r})]))])]
            [:to::Type.TInt {} (:to::Res.Err {:msg "sending to an int"})]
            [:to::Type.TBool {} (:to::Res.Err {:msg "sending to a bool"})])])]

    [:to::Exp.Apply {:ptype ptype :arg arg :result result}
      (:wat::core::match (:to::type-of arg env cs is)
        [:to::Res.Err {:msg m} (:to::Res.Err {:msg m})]
        [:to::Res.Ok {:ty got}
          (:wat::core::if (:to::subtype? cs got ptype)
            (:to::Res.Ok {:ty result})
            (:to::Res.Err {:msg (:wat::string::concat "parameter expects " (:to::show ptype)
                                  ", got " (:to::show got))}))])]))

;; does a class actually provide everything its interface promises, at compatible types?
(:wat::core::defn :to::check-impl
  [c <- :to::CDecl cs <- :to::CDecls is <- :to::IDecls] -> :to::Res
  (:wat::core::match c
    [:to::CDecl.CD {:name name :super sp :iface i :methods ms}
      (:wat::core::if (:wat::core::= i "") (:to::Res.Ok {:ty (:to::Type.TInt {})})
        (:wat::core::match (:to::find-iface is i)
          [:to::IDecl.ID {:name inm :methods ims} (:to::check-each ims name cs is)]))]))

(:wat::core::defn :to::check-each
  [ims <- :to::MDecls cls <- :wat::core::String cs <- :to::CDecls is <- :to::IDecls] -> :to::Res
  (:wat::core::match ims
    [:to::MDecls.MNil {} (:to::Res.Ok {:ty (:to::Type.TInt {})})]
    [:to::MDecls.MCons {:m m :rest rest}
      (:wat::core::match m
        [:to::MDecl.MD {:name want-n :params want-ps :result want-r}
          (:wat::core::match (:to::lookup-method cs is cls want-n)
            [:to::MDecl.MD {:name got-n :params got-ps :result got-r}
              (:wat::core::if (:wat::core::= got-n "")
                (:to::Res.Err {:msg (:wat::string::concat cls " does not implement " want-n)})
                (:wat::core::if (:to::subtype? cs got-r want-r)
                  (:to::check-each rest cls cs is)
                  (:to::Res.Err {:msg (:wat::string::concat cls "." want-n " returns "
                                        (:to::show got-r) ", interface wants " (:to::show want-r))})))])])]))
