;; eopl/lib/modules.wat — EOPL chapter 8: SIMPLE-MODULES, OPAQUE-TYPES, parameterized modules.
;;
;; The chapter's subject is ABSTRACTION BOUNDARIES, checked statically. A module has an INTERFACE
;; (what the outside may see) and a BODY (what is actually there). The type checker enforces the
;; gap between them, and the sharpest version of that is an OPAQUE type:
;;
;;   module ints
;;     interface [ opaque t, zero : t, succ : (t -> t), to-int : (t -> int) ]
;;     body      [ type t = int, zero = 0, succ = proc(x : t) -(x,-1), to-int = proc(x : t) x ]
;;
;; Inside the body `t` IS `int`. Outside, `t` is a name and nothing more, so `-(from ints take
;; zero, 1)` must be REJECTED even though the value underneath is an integer. A `transparent`
;; declaration is the same thing with the seal removed, and the two differ in exactly one word.
;;
;; This is the chapter closest to wat's own design (namespaces, `defsurface`), which is why
;; NEXT.md flagged it: wat has module-like namespaces and surfaces, but no way to seal a type.

(:wat::core::defenum :md::Type :wat::enum::Pure
  :TInt   []
  :TBool  []
  :TArrow [a <- :md::Type  r <- :md::Type]
  ;; `m.t` — the type named `t` inside module `m`. Opaque unless the interface says transparent.
  :TQual  [m <- :wat::core::String  t <- :wat::core::String])

;; ---- interfaces: what the outside is allowed to see ----
(:wat::core::defenum :md::Decl :wat::enum::Pure
  :ValD    [name <- :wat::core::String  ty <- :md::Type]
  :OpaqueD [name <- :wat::core::String]
  :TransD  [name <- :wat::core::String  ty <- :md::Type])

(:wat::core::defenum :md::Decls :wat::enum::Pure
  :DNil  []
  :DCons [d <- :md::Decl  rest <- :md::Decls])

;; ---- bodies: what is actually there ----
(:wat::core::defenum :md::Defn :wat::enum::Pure
  :ValDf  [name <- :wat::core::String  ty <- :md::Type  e <- :md::Exp]
  :TypeDf [name <- :wat::core::String  ty <- :md::Type])

(:wat::core::defenum :md::Defns :wat::enum::Pure
  :FNil  []
  :FCons [d <- :md::Defn  rest <- :md::Defns])

(:wat::core::defenum :md::Exp :wat::enum::Pure
  :Lit     [n <- :wat::core::i64]
  :Var     [name <- :wat::core::String]
  :Diff    [a <- :md::Exp  b <- :md::Exp]
  :IsZero  [e <- :md::Exp]
  :If      [c <- :md::Exp  t <- :md::Exp  f <- :md::Exp]
  :Let     [name <- :wat::core::String  e <- :md::Exp  body <- :md::Exp]
  :Proc    [param <- :wat::core::String  pty <- :md::Type  body <- :md::Exp]
  :Call    [rator <- :md::Exp  rand <- :md::Exp]
  ;; from m take x
  :QualVar [m <- :wat::core::String  name <- :wat::core::String])

;; ---- environments ----
(:wat::core::defenum :md::TEnv :wat::enum::Pure
  :TNil  []
  :TBind [name <- :wat::core::String  ty <- :md::Type  rest <- :md::TEnv])

;; the modules in scope, each with the interface the outside sees
(:wat::core::defenum :md::MEnv :wat::enum::Pure
  :MNil  []
  :MBind [name <- :wat::core::String  iface <- :md::Decls  rest <- :md::MEnv])

(:wat::core::defenum :md::Res :wat::enum::Pure
  :Ok  [ty <- :md::Type]
  :Err [msg <- :wat::core::String])

;; ---- looking things up ----
(:wat::core::defn :md::lookup-var [env <- :md::TEnv name <- :wat::core::String] -> :md::Res
  (:wat::core::match env
    [:md::TEnv.TNil {} (:md::Res.Err {:msg (:wat::string::concat "unbound variable " name)})]
    [:md::TEnv.TBind {:name n :ty ty :rest rest}
      (:wat::core::if (:wat::core::= n name) (:md::Res.Ok {:ty ty}) (:md::lookup-var rest name))]))

(:wat::core::defn :md::find-module [menv <- :md::MEnv name <- :wat::core::String] -> :md::Decls
  (:wat::core::match menv
    [:md::MEnv.MNil {} (:md::Decls.DNil {})]
    [:md::MEnv.MBind {:name n :iface iface :rest rest}
      (:wat::core::if (:wat::core::= n name) iface (:md::find-module rest name))]))

;; `from m take x` — and the whole point: the INTERFACE is consulted, never the body
(:wat::core::defn :md::decl-type [ds <- :md::Decls name <- :wat::core::String] -> :md::Res
  (:wat::core::match ds
    [:md::Decls.DNil {}
      (:md::Res.Err {:msg (:wat::string::concat "interface does not export " name)})]
    [:md::Decls.DCons {:d d :rest rest}
      (:wat::core::match d
        [:md::Decl.ValD {:name n :ty ty}
          (:wat::core::if (:wat::core::= n name) (:md::Res.Ok {:ty ty}) (:md::decl-type rest name))]
        [:md::Decl.OpaqueD {:name n} (:md::decl-type rest name)]
        [:md::Decl.TransD {:name n :ty ty} (:md::decl-type rest name)])]))

;; is `t` declared TRANSPARENT in this interface, and if so as what?
(:wat::core::defenum :md::Look :wat::enum::Pure
  :Transparent [ty <- :md::Type]
  :Opaque      []
  :Absent      [])

(:wat::core::defn :md::look-type [ds <- :md::Decls name <- :wat::core::String] -> :md::Look
  (:wat::core::match ds
    [:md::Decls.DNil {} (:md::Look.Absent {})]
    [:md::Decls.DCons {:d d :rest rest}
      (:wat::core::match d
        [:md::Decl.ValD {:name n :ty ty} (:md::look-type rest name)]
        [:md::Decl.OpaqueD {:name n}
          (:wat::core::if (:wat::core::= n name) (:md::Look.Opaque {}) (:md::look-type rest name))]
        [:md::Decl.TransD {:name n :ty ty}
          (:wat::core::if (:wat::core::= n name)
            (:md::Look.Transparent {:ty ty})
            (:md::look-type rest name))])]))

;; EXPAND a type as far as the interfaces allow. A transparent name unfolds; an opaque one does
;; not, and that single fact is the whole of type abstraction.
(:wat::core::defn :md::expand [ty <- :md::Type menv <- :md::MEnv] -> :md::Type
  (:wat::core::match ty
    [:md::Type.TInt {} ty]
    [:md::Type.TBool {} ty]
    [:md::Type.TArrow {:a a :r r}
      (:md::Type.TArrow {:a (:md::expand a menv) :r (:md::expand r menv)})]
    [:md::Type.TQual {:m m :t t}
      (:wat::core::match (:md::look-type (:md::find-module menv m) t)
        [:md::Look.Transparent {:ty inner} (:md::expand inner menv)]
        [:md::Look.Opaque {} ty]
        [:md::Look.Absent {} ty])]))

(:wat::core::defn :md::same? [a <- :md::Type b <- :md::Type menv <- :md::MEnv] -> :wat::core::bool
  (:md::same-expanded? (:md::expand a menv) (:md::expand b menv)))

(:wat::core::defn :md::same-expanded? [a <- :md::Type b <- :md::Type] -> :wat::core::bool
  (:wat::core::match a
    [:md::Type.TInt {} (:wat::core::match b
                         [:md::Type.TInt {} true]
                         [:md::Type.TBool {} false]
                         [:md::Type.TArrow {:a x :r y} false]
                         [:md::Type.TQual {:m m :t t} false])]
    [:md::Type.TBool {} (:wat::core::match b
                          [:md::Type.TBool {} true]
                          [:md::Type.TInt {} false]
                          [:md::Type.TArrow {:a x :r y} false]
                          [:md::Type.TQual {:m m :t t} false])]
    [:md::Type.TArrow {:a a1 :r r1}
      (:wat::core::match b
        [:md::Type.TArrow {:a a2 :r r2}
          (:wat::core::and (:md::same-expanded? a1 a2) (:md::same-expanded? r1 r2))]
        [:md::Type.TInt {} false]
        [:md::Type.TBool {} false]
        [:md::Type.TQual {:m m :t t} false])]
    ;; two opaque names are the same type only if they are the SAME name in the SAME module
    [:md::Type.TQual {:m m1 :t t1}
      (:wat::core::match b
        [:md::Type.TQual {:m m2 :t t2}
          (:wat::core::and (:wat::core::= m1 m2) (:wat::core::= t1 t2))]
        [:md::Type.TInt {} false]
        [:md::Type.TBool {} false]
        [:md::Type.TArrow {:a x :r y} false])]))

(:wat::core::defn :md::show [ty <- :md::Type] -> :wat::core::String
  (:wat::core::match ty
    [:md::Type.TInt {} "int"]
    [:md::Type.TBool {} "bool"]
    [:md::Type.TArrow {:a a :r r}
      (:wat::string::concat "(" (:md::show a) " -> " (:md::show r) ")")]
    [:md::Type.TQual {:m m :t t} (:wat::string::concat m "." t)]))

;; ---- the type checker ----
(:wat::core::defn :md::expect
  [r <- :md::Res want <- :md::Type menv <- :md::MEnv where <- :wat::core::String] -> :md::Res
  (:wat::core::match r
    [:md::Res.Err {:msg m} r]
    [:md::Res.Ok {:ty got}
      (:wat::core::if (:md::same? got want menv) r
        (:md::Res.Err {:msg (:wat::string::concat where ": expected " (:md::show want)
                              ", got " (:md::show got))}))]))

(:wat::core::defn :md::type-of
  [e <- :md::Exp env <- :md::TEnv menv <- :md::MEnv] -> :md::Res
  (:wat::core::match e
    [:md::Exp.Lit {:n n} (:md::Res.Ok {:ty (:md::Type.TInt {})})]
    [:md::Exp.Var {:name name} (:md::lookup-var env name)]

    ;; `from m take x` consults the INTERFACE. A name the interface omits is simply not there,
    ;; however plainly it sits in the body.
    [:md::Exp.QualVar {:m m :name name}
      (:wat::core::match (:md::find-module menv m)
        [:md::Decls.DNil {} (:md::Res.Err {:msg (:wat::string::concat "no such module " m)})]
        [:md::Decls.DCons {:d d :rest rest}
          (:md::decl-type (:md::find-module menv m) name)])]

    [:md::Exp.Diff {:a a :b b}
      (:wat::core::match (:md::expect (:md::type-of a env menv) (:md::Type.TInt {}) menv "diff lhs")
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty t1}
          (:wat::core::match (:md::expect (:md::type-of b env menv) (:md::Type.TInt {}) menv "diff rhs")
            [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
            [:md::Res.Ok {:ty t2} (:md::Res.Ok {:ty (:md::Type.TInt {})})])])]

    [:md::Exp.IsZero {:e inner}
      (:wat::core::match (:md::expect (:md::type-of inner env menv) (:md::Type.TInt {}) menv "zero?")
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty t} (:md::Res.Ok {:ty (:md::Type.TBool {})})])]

    [:md::Exp.If {:c c :t t :f f}
      (:wat::core::match (:md::expect (:md::type-of c env menv) (:md::Type.TBool {}) menv "if test")
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty tc}
          (:wat::core::match (:md::type-of t env menv)
            [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
            [:md::Res.Ok {:ty tt} (:md::expect (:md::type-of f env menv) tt menv "if arms")])])]

    [:md::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:md::type-of rhs env menv)
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty tr}
          (:md::type-of body (:md::TEnv.TBind {:name name :ty tr :rest env}) menv)])]

    [:md::Exp.Proc {:param param :pty pty :body body}
      (:wat::core::match (:md::type-of body (:md::TEnv.TBind {:name param :ty pty :rest env}) menv)
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty tb} (:md::Res.Ok {:ty (:md::Type.TArrow {:a pty :r tb})})])]

    [:md::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:md::type-of rator env menv)
        [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
        [:md::Res.Ok {:ty tf}
          (:wat::core::match (:md::expand tf menv)
            [:md::Type.TArrow {:a ta :r tr}
              (:wat::core::match (:md::expect (:md::type-of rand env menv) ta menv "argument")
                [:md::Res.Err {:msg m} (:md::Res.Err {:msg m})]
                [:md::Res.Ok {:ty t} (:md::Res.Ok {:ty tr})])]
            [:md::Type.TInt {} (:md::Res.Err {:msg "calling a non-procedure"})]
            [:md::Type.TBool {} (:md::Res.Err {:msg "calling a non-procedure"})]
            [:md::Type.TQual {:m m :t t}
              (:md::Res.Err {:msg (:wat::string::concat "calling an abstract value of type "
                                    (:md::show (:md::Type.TQual {:m m :t t})))})])])]))

;; ---------------------------------------------------------------------------------------------
;; SEALING: a module body is checked with its own type definitions TRANSPARENT (the implementation
;; knows that `t` is `int`); the outside then sees only the declared interface, where `opaque t`
;; hides it again. The gap between those two views is the entire chapter.

(:wat::core::defenum :md::Module :wat::enum::Pure
  :Mod [name <- :wat::core::String  iface <- :md::Decls  body <- :md::Defns])

;; the body's own view of itself: every `type t = ty` is transparent here
(:wat::core::defn :md::self-iface [ds <- :md::Defns] -> :md::Decls
  (:wat::core::match ds
    [:md::Defns.FNil {} (:md::Decls.DNil {})]
    [:md::Defns.FCons {:d d :rest rest}
      (:wat::core::match d
        [:md::Defn.TypeDf {:name n :ty ty}
          (:md::Decls.DCons {:d (:md::Decl.TransD {:name n :ty ty}) :rest (:md::self-iface rest)})]
        [:md::Defn.ValDf {:name n :ty ty :e e}
          (:md::Decls.DCons {:d (:md::Decl.ValD {:name n :ty ty}) :rest (:md::self-iface rest)})])]))

(:wat::core::defenum :md::Check :wat::enum::Pure
  :Fine [] :Bad [msg <- :wat::core::String])

;; every value definition must actually have the type its body claims, under the transparent view
(:wat::core::defn :md::check-defns
  [ds <- :md::Defns env <- :md::TEnv menv <- :md::MEnv] -> :md::Check
  (:wat::core::match ds
    [:md::Defns.FNil {} (:md::Check.Fine {})]
    [:md::Defns.FCons {:d d :rest rest}
      (:wat::core::match d
        [:md::Defn.TypeDf {:name n :ty ty} (:md::check-defns rest env menv)]
        [:md::Defn.ValDf {:name n :ty ty :e e}
          (:wat::core::match (:md::expect (:md::type-of e env menv) ty menv
                               (:wat::string::concat "definition " n))
            [:md::Res.Err {:msg m} (:md::Check.Bad {:msg m})]
            [:md::Res.Ok {:ty t}
              (:md::check-defns rest (:md::TEnv.TBind {:name n :ty ty :rest env}) menv)])])]))

;; and every name the interface PROMISES must be present in the body at a matching type
(:wat::core::defn :md::check-iface
  [iface <- :md::Decls self <- :md::Decls menv <- :md::MEnv] -> :md::Check
  (:wat::core::match iface
    [:md::Decls.DNil {} (:md::Check.Fine {})]
    [:md::Decls.DCons {:d d :rest rest}
      (:wat::core::match d
        [:md::Decl.OpaqueD {:name n}
          (:wat::core::match (:md::look-type self n)
            [:md::Look.Transparent {:ty ty} (:md::check-iface rest self menv)]
            [:md::Look.Opaque {} (:md::check-iface rest self menv)]
            [:md::Look.Absent {}
              (:md::Check.Bad {:msg (:wat::string::concat
                                      "interface declares opaque type " n " the body never defines")})])]
        [:md::Decl.TransD {:name n :ty ty} (:md::check-iface rest self menv)]
        [:md::Decl.ValD {:name n :ty ty}
          (:wat::core::match (:md::decl-type self n)
            [:md::Res.Err {:msg m}
              (:md::Check.Bad {:msg (:wat::string::concat
                                      "interface promises " n " the body never defines")})]
            [:md::Res.Ok {:ty got}
              (:wat::core::if (:md::same? got ty menv)
                (:md::check-iface rest self menv)
                (:md::Check.Bad {:msg (:wat::string::concat "interface promises " n " : "
                                        (:md::show ty) " but the body has " (:md::show got))}))])])]))

;; check a module and, if it is well typed, return the menv the OUTSIDE should see (sealed)
(:wat::core::defn :md::check-module [m <- :md::Module menv <- :md::MEnv] -> :md::Check
  (:wat::core::match m
    [:md::Module.Mod {:name name :iface iface :body body}
      (:wat::core::let [self (:md::self-iface body)
                        ;; inside the body, this module's own types are transparent
                        inner (:md::MEnv.MBind {:name name :iface self :rest menv})]
        (:wat::core::match (:md::check-defns body (:md::TEnv.TNil {}) inner)
          [:md::Check.Bad {:msg m2} (:md::Check.Bad {:msg m2})]
          [:md::Check.Fine {} (:md::check-iface iface self inner)]))]))

(:wat::core::defn :md::seal [m <- :md::Module menv <- :md::MEnv] -> :md::MEnv
  (:wat::core::match m
    [:md::Module.Mod {:name name :iface iface :body body}
      (:md::MEnv.MBind {:name name :iface iface :rest menv})]))

;; ---------------------------------------------------------------------------------------------
;; EOPL 8.4: PARAMETERIZED MODULES (ML's functors). A module-proc takes a module satisfying an
;; interface and produces one. The checking rule is the interesting part and it is the same rule
;; as for procedures, one level up: check the BODY once against the PARAMETER's interface, not
;; once per application. If it type-checks there, every argument module that satisfies the
;; interface is safe — which is exactly what a dictionary passed by hand does NOT give you
;; (see the Little MLer functor note, C-030's cost paragraph).

(:wat::core::defenum :md::MProc :wat::enum::Pure
  ;; module-proc (param : param-iface) => a module named `result-name` with `result-iface`
  :MP [param <- :wat::core::String  param-iface <- :md::Decls
       result-name <- :wat::core::String  result-iface <- :md::Decls
       body <- :md::Defns])

;; check the functor ONCE, against the parameter's interface alone
(:wat::core::defn :md::check-mproc [mp <- :md::MProc menv <- :md::MEnv] -> :md::Check
  (:wat::core::match mp
    [:md::MProc.MP {:param param :param-iface pi :result-name rn :result-iface ri :body body}
      ;; the parameter is in scope as a module with exactly its declared interface -- nothing more
      (:wat::core::let [inner (:md::MEnv.MBind {:name param :iface pi :rest menv})
                        self (:md::self-iface body)
                        inner2 (:md::MEnv.MBind {:name rn :iface self :rest inner})]
        (:wat::core::match (:md::check-defns body (:md::TEnv.TNil {}) inner2)
          [:md::Check.Bad {:msg m} (:md::Check.Bad {:msg m})]
          [:md::Check.Fine {} (:md::check-iface ri self inner2)]))]))

;; does a module satisfy an interface? (the check an APPLICATION makes)
(:wat::core::defn :md::satisfies? [m <- :md::Module want <- :md::Decls menv <- :md::MEnv] -> :md::Check
  (:wat::core::match m
    [:md::Module.Mod {:name name :iface iface :body body}
      ;; The argument module must be IN SCOPE for the comparison, or a type it exports as `m.t`
      ;; cannot be expanded and every requirement fails for the wrong reason. Only what the module
      ;; EXPORTS is bound here -- its sealed interface, never its body.
      (:md::check-iface want iface (:md::MEnv.MBind {:name name :iface iface :rest menv}))]))
