;; eopl/ch09-typed-oo.wat — EOPL chapter 9.4-9.5: TYPED-OO, and the first type rule in this
;; repository that is not an equality.
;;
;; CLASSES (ch09-classes.wat) runs the program; this checks it. The new idea is SUBSUMPTION: a c2
;; may be used where a c1 is wanted. Everything interesting follows from that being a ONE-WAY
;; relation, and from a `send` being checked against the receiver's STATIC type.
;;
;; Classes:  c1 (m1 : -> int, m2 : -> int)
;;           c2 extends c1, implements `summable` (m1 : -> int, m3 : -> int)
;; Interface: summable (m1 : -> int)

(:wat::load-file! "lib/typedoo.wat")

(:wat::core::defn :t9::say [label <- :wat::core::String r <- :to::Res] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  "
      (:wat::core::match r
        [:to::Res.Ok {:ty ty} (:wat::string::concat "ACCEPTED : " (:to::show ty))]
        [:to::Res.Err {:msg m} (:wat::string::concat "REJECTED : " m)]))))

(:wat::core::defn :t9::m0 [name <- :wat::core::String] -> :to::MDecl
  (:to::MDecl.MD {:name name :params (:to::Types.TNil {}) :result (:to::Type.TInt {})}))

(:wat::core::defn :t9::ifaces [] -> :to::IDecls
  (:to::IDecls.ICons
    {:i (:to::IDecl.ID {:name "summable"
                        :methods (:to::MDecls.MCons {:m (:t9::m0 "m1")
                                                     :rest (:to::MDecls.MNil {})})})
     :rest (:to::IDecls.INil {})}))

(:wat::core::defn :t9::classes [] -> :to::CDecls
  (:to::CDecls.CCons
    {:c (:to::CDecl.CD {:name "c1" :super "" :iface ""
                        :methods (:to::MDecls.MCons
                                   {:m (:t9::m0 "m1")
                                    :rest (:to::MDecls.MCons {:m (:t9::m0 "m2")
                                                              :rest (:to::MDecls.MNil {})})})})
     :rest (:to::CDecls.CCons
             {:c (:to::CDecl.CD {:name "c2" :super "c1" :iface "summable"
                                 :methods (:to::MDecls.MCons
                                            {:m (:t9::m0 "m1")
                                             :rest (:to::MDecls.MCons {:m (:t9::m0 "m3")
                                                                       :rest (:to::MDecls.MNil {})})})})
              :rest (:to::CDecls.CNil {})})}))

(:wat::core::defn :t9::check [e <- :to::Exp] -> :to::Res
  (:to::type-of e (:to::TEnv.VNil {}) (:t9::classes) (:t9::ifaces)))

(:wat::core::defn :t9::cls [n <- :wat::core::String] -> :to::Type (:to::Type.TClass {:name n}))

;; pass `new <cls>` to a one-argument function whose parameter is declared `<want>`
(:wat::core::defn :t9::pass [cls <- :wat::core::String want <- :wat::core::String] -> :to::Res
  (:t9::check (:to::Exp.Apply {:ptype (:t9::cls want)
                               :arg (:to::Exp.New {:cls cls})
                               :result (:to::Type.TInt {})})))

(:wat::core::defn :t9::send-to [cls <- :wat::core::String meth <- :wat::core::String] -> :to::Res
  (:t9::check (:to::Exp.Send {:obj (:to::Exp.New {:cls cls}) :meth meth
                              :args (:to::Exps.ENil {})})))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- EOPL ch9.4: SUBSUMPTION is one-way ----")
    (:t9::say "c2 where c1 is wanted       " (:t9::pass "c2" "c1"))
    (:t9::say "c1 where c2 is wanted       " (:t9::pass "c1" "c2"))
    (:t9::say "c1 where c1 is wanted       " (:t9::pass "c1" "c1"))

    (:wat::kernel::println "---- an interface is a supertype too ----")
    (:t9::say "c2 where summable is wanted " (:t9::pass "c2" "summable"))
    (:t9::say "c1 where summable is wanted " (:t9::pass "c1" "summable"))
    (:t9::say "c2 implements what it claims"
      (:to::check-impl (:to::find-class (:t9::classes) "c2") (:t9::classes) (:t9::ifaces)))

    (:wat::kernel::println "---- a send is checked against the receiver's STATIC type ----")
    (:t9::say "c2.m3  (declared on c2)     " (:t9::send-to "c2" "m3"))
    (:t9::say "c2.m2  (inherited from c1)  " (:t9::send-to "c2" "m2"))
    ;; the row that matters: c1 has no m3. At RUN TIME a c1 never does either -- but the point is
    ;; that the checker uses the declared type and not the value, which is why this is sound.
    (:t9::say "c1.m3  (only c2 has m3)     " (:t9::send-to "c1" "m3"))

    (:wat::kernel::println "---- and through the interface, only the interface's methods exist ----")
    ;; a summable-typed receiver may be a c2 at run time, and m3 would work. The checker still
    ;; refuses: `summable` promises m1 and nothing else. This is C-071's opaque type again --
    ;; the DECLARED view, not the actual one.
    (:t9::say "summable.m1                 "
      (:t9::check (:to::Exp.Send {:obj (:to::Exp.Apply {:ptype (:t9::cls "summable")
                                                        :arg (:to::Exp.New {:cls "c2"})
                                                        :result (:t9::cls "summable")})
                                  :meth "m1" :args (:to::Exps.ENil {})})))
    (:t9::say "summable.m3                 "
      (:t9::check (:to::Exp.Send {:obj (:to::Exp.Apply {:ptype (:t9::cls "summable")
                                                        :arg (:to::Exp.New {:cls "c2"})
                                                        :result (:t9::cls "summable")})
                                  :meth "m3" :args (:to::Exps.ENil {})})))))
