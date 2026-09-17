;; eopl/lib/classes.wat — EOPL chapter 9: the CLASSES language.
;;
;; Objects are a class name plus a BASE INDEX into the store; the class knows its field names in
;; order, inherited fields first, so field `k` of an object lives at `base + k`. That is
;; MUTABLE-PAIRS (C-069) generalised from two cells to n, and it is why the store threading from
;; chapter 4 had to exist before this chapter could.
;;
;; The two things that make this OO rather than records with functions:
;;   - method lookup walks UP the class chain from the object's OWN class, so a subclass override
;;     is found first even when the call is made inside a superclass method (dynamic dispatch);
;;   - `super m(...)` starts the walk above the class whose method is CURRENTLY RUNNING, which is
;;     a different starting point from `self`, and the two differ exactly when a method is
;;     overridden.
;; So the evaluator carries both `self` and `curclass`. Losing either collapses one of the two.

(:wat::core::typealias :oo::Store (:wat::core::PersistentMap :- [:wat::core::i64 :oo::Val]))

(:wat::core::defenum :oo::Val :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Bool [b <- :wat::core::bool]
  :Obj  [cls <- :wat::core::String  base <- :wat::core::i64]
  :Nil  [])

(:wat::core::defenum :oo::Exp :wat::enum::Pure
  :Lit      [n <- :wat::core::i64]
  :Var      [name <- :wat::core::String]
  :Diff     [a <- :oo::Exp  b <- :oo::Exp]
  :IsZero   [e <- :oo::Exp]
  :If       [c <- :oo::Exp  t <- :oo::Exp  f <- :oo::Exp]
  :Let      [name <- :wat::core::String  e <- :oo::Exp  body <- :oo::Exp]
  :Seq      [a <- :oo::Exp  b <- :oo::Exp]
  :Self     []
  :Field    [name <- :wat::core::String]
  :SetField [name <- :wat::core::String  e <- :oo::Exp]
  :New      [cls <- :wat::core::String  args <- :oo::Args]
  :Send     [obj <- :oo::Exp  meth <- :wat::core::String  args <- :oo::Args]
  :Super    [meth <- :wat::core::String  args <- :oo::Args])

(:wat::core::defenum :oo::Args :wat::enum::Pure
  :ANil [] :ACons [e <- :oo::Exp  rest <- :oo::Args])

(:wat::core::defenum :oo::Names :wat::enum::Pure
  :NNil [] :NCons [n <- :wat::core::String  rest <- :oo::Names])

(:wat::core::defenum :oo::Method :wat::enum::Pure
  :M [name <- :wat::core::String  params <- :oo::Names  body <- :oo::Exp])

(:wat::core::defenum :oo::Methods :wat::enum::Pure
  :MNil [] :MCons [m <- :oo::Method  rest <- :oo::Methods])

;; `fields` is the FULL list, inherited first — so a subclass's own fields sit after its parent's
;; and an inherited method's field index stays valid in a subclass instance.
(:wat::core::defenum :oo::Class :wat::enum::Pure
  :C [name <- :wat::core::String  super <- :wat::core::String
      fields <- :oo::Names  methods <- :oo::Methods])

(:wat::core::defenum :oo::Classes :wat::enum::Pure
  :CNil [] :CCons [c <- :oo::Class  rest <- :oo::Classes])

(:wat::core::defenum :oo::Env :wat::enum::Pure
  :ENil [] :EBind [name <- :wat::core::String  v <- :oo::Val  rest <- :oo::Env])

(:wat::core::defenum :oo::Ans :wat::enum::Pure
  :A [v <- :oo::Val  st <- :oo::Store  next <- :wat::core::i64])

(:wat::core::defenum :oo::Vals :wat::enum::Pure
  :VNil [] :VCons [v <- :oo::Val  rest <- :oo::Vals])

;; ---- lookups ----
(:wat::core::defn :oo::find-class [cs <- :oo::Classes name <- :wat::core::String] -> :oo::Class
  (:wat::core::match cs
    [:oo::Classes.CNil {}
      (:oo::Class.C {:name "" :super "" :fields (:oo::Names.NNil {}) :methods (:oo::Methods.MNil {})})]
    [:oo::Classes.CCons {:c c :rest rest}
      (:wat::core::match c
        [:oo::Class.C {:name n :super sp :fields fs :methods ms}
          (:wat::core::if (:wat::core::= n name) c (:oo::find-class rest name))])]))

(:wat::core::defn :oo::index-of [ns <- :oo::Names name <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match ns
    [:oo::Names.NNil {} -1]
    [:oo::Names.NCons {:n n :rest rest}
      (:wat::core::if (:wat::core::= n name) i (:oo::index-of rest name (:wat::core::+ i 1)))]))

(:wat::core::defn :oo::count-names [ns <- :oo::Names] -> :wat::core::i64
  (:wat::core::match ns
    [:oo::Names.NNil {} 0]
    [:oo::Names.NCons {:n n :rest rest} (:wat::core::+ 1 (:oo::count-names rest))]))

(:wat::core::defn :oo::find-method-here [ms <- :oo::Methods name <- :wat::core::String] -> :oo::Method
  (:wat::core::match ms
    [:oo::Methods.MNil {} (:oo::Method.M {:name "" :params (:oo::Names.NNil {}) :body (:oo::Exp.Lit {:n 0})})]
    [:oo::Methods.MCons {:m m :rest rest}
      (:wat::core::match m
        [:oo::Method.M {:name n :params ps :body b}
          (:wat::core::if (:wat::core::= n name) m (:oo::find-method-here rest name))])]))

(:wat::core::defenum :oo::Found :wat::enum::Pure
  :Hit  [m <- :oo::Method  owner <- :wat::core::String]
  :Miss [])

;; walk UP the chain — this is dynamic dispatch, and where the walk STARTS is the whole difference
;; between a `send` (start at the object's own class) and a `super` (start above the running one).
(:wat::core::defn :oo::lookup-method
  [cs <- :oo::Classes cls <- :wat::core::String name <- :wat::core::String] -> :oo::Found
  (:wat::core::if (:wat::core::= cls "") (:oo::Found.Miss {})
    (:wat::core::match (:oo::find-class cs cls)
      [:oo::Class.C {:name n :super sp :fields fs :methods ms}
        (:wat::core::if (:wat::core::= n "")
          (:oo::Found.Miss {})
          (:wat::core::match (:oo::find-method-here ms name)
            [:oo::Method.M {:name mn :params ps :body b}
              (:wat::core::if (:wat::core::= mn "")
                (:oo::lookup-method cs sp name)
                (:oo::Found.Hit {:m (:oo::find-method-here ms name) :owner n}))]))])))

(:wat::core::defn :oo::look-env [env <- :oo::Env name <- :wat::core::String] -> :oo::Val
  (:wat::core::match env
    [:oo::Env.ENil {} (:oo::Val.Nil {})]
    [:oo::Env.EBind {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:oo::look-env rest name))]))

(:wat::core::defn :oo::fetch [st <- :oo::Store i <- :wat::core::i64] -> :oo::Val
  (:wat::core::match (:wat::map::get st i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} (:oo::Val.Nil {})]))

(:wat::core::defn :oo::num-of [v <- :oo::Val] -> :wat::core::i64
  (:wat::core::match v
    [:oo::Val.Num {:n n} n]
    [:oo::Val.Bool {:b b} 0]
    [:oo::Val.Obj {:cls c :base b} 0]
    [:oo::Val.Nil {} 0]))

(:wat::core::defn :oo::truthy? [v <- :oo::Val] -> :wat::core::bool
  (:wat::core::match v
    [:oo::Val.Bool {:b b} b]
    [:oo::Val.Num {:n n} (:wat::core::not (:wat::core::= n 0))]
    [:oo::Val.Obj {:cls c :base b} true]
    [:oo::Val.Nil {} false]))

(:wat::core::defn :oo::class-of [v <- :oo::Val] -> :wat::core::String
  (:wat::core::match v
    [:oo::Val.Obj {:cls c :base b} c]
    [:oo::Val.Num {:n n} ""]
    [:oo::Val.Bool {:b b} ""]
    [:oo::Val.Nil {} ""]))

(:wat::core::defn :oo::base-of [v <- :oo::Val] -> :wat::core::i64
  (:wat::core::match v
    [:oo::Val.Obj {:cls c :base b} b]
    [:oo::Val.Num {:n n} -1]
    [:oo::Val.Bool {:b b} -1]
    [:oo::Val.Nil {} -1]))

;; ---- the evaluator ----
;; `self` and `curclass` are carried separately on purpose: `send` dispatches from the OBJECT's
;; class and `super` from above the RUNNING method's class. Collapse them and one of the two
;; breaks — which the chapter file demonstrates rather than asserts.

(:wat::core::defenum :oo::AnsL :wat::enum::Pure
  :AL [vs <- :oo::Vals  st <- :oo::Store  next <- :wat::core::i64])

(:wat::core::defn :oo::eval-args
  [as <- :oo::Args env <- :oo::Env self <- :oo::Val curclass <- :wat::core::String
   cs <- :oo::Classes st <- :oo::Store next <- :wat::core::i64] -> :oo::AnsL
  (:wat::core::match as
    [:oo::Args.ANil {} (:oo::AnsL.AL {:vs (:oo::Vals.VNil {}) :st st :next next})]
    [:oo::Args.ACons {:e e :rest rest}
      (:wat::core::match (:oo::eval e env self curclass cs st next)
        [:oo::Ans.A {:v v :st s1 :next n1}
          (:wat::core::match (:oo::eval-args rest env self curclass cs s1 n1)
            [:oo::AnsL.AL {:vs vs :st s2 :next n2}
              (:oo::AnsL.AL {:vs (:oo::Vals.VCons {:v v :rest vs}) :st s2 :next n2})])])]))

(:wat::core::defn :oo::bind-params
  [ps <- :oo::Names vs <- :oo::Vals env <- :oo::Env] -> :oo::Env
  (:wat::core::match ps
    [:oo::Names.NNil {} env]
    [:oo::Names.NCons {:n n :rest prest}
      (:wat::core::match vs
        [:oo::Vals.VNil {} env]
        [:oo::Vals.VCons {:v v :rest vrest}
          (:oo::bind-params prest vrest (:oo::Env.EBind {:name n :v v :rest env}))])]))

;; write a run of field values into the store, one cell each, starting at `base`
(:wat::core::defn :oo::init-fields
  [st <- :oo::Store base <- :wat::core::i64 k <- :wat::core::i64 n <- :wat::core::i64] -> :oo::Store
  (:wat::core::if (:wat::core::>= k n) st
    (:oo::init-fields (:wat::map::assoc st (:wat::core::+ base k) (:oo::Val.Nil {}))
      base (:wat::core::+ k 1) n)))

(:wat::core::defn :oo::apply-method
  [m <- :oo::Method owner <- :wat::core::String self <- :oo::Val vs <- :oo::Vals
   cs <- :oo::Classes st <- :oo::Store next <- :wat::core::i64] -> :oo::Ans
  (:wat::core::match m
    [:oo::Method.M {:name mn :params ps :body body}
      ;; the method runs with curclass = the class that OWNS it, not the object's class
      (:oo::eval body (:oo::bind-params ps vs (:oo::Env.ENil {})) self owner cs st next)]))

(:wat::core::defn :oo::eval
  [e <- :oo::Exp env <- :oo::Env self <- :oo::Val curclass <- :wat::core::String
   cs <- :oo::Classes st <- :oo::Store next <- :wat::core::i64] -> :oo::Ans
  (:wat::core::match e
    [:oo::Exp.Lit {:n n} (:oo::Ans.A {:v (:oo::Val.Num {:n n}) :st st :next next})]
    [:oo::Exp.Var {:name name} (:oo::Ans.A {:v (:oo::look-env env name) :st st :next next})]
    [:oo::Exp.Self {} (:oo::Ans.A {:v self :st st :next next})]

    [:oo::Exp.Diff {:a a :b b}
      (:wat::core::match (:oo::eval a env self curclass cs st next)
        [:oo::Ans.A {:v va :st s1 :next n1}
          (:wat::core::match (:oo::eval b env self curclass cs s1 n1)
            [:oo::Ans.A {:v vb :st s2 :next n2}
              (:oo::Ans.A {:v (:oo::Val.Num {:n (:wat::core::- (:oo::num-of va) (:oo::num-of vb))})
                           :st s2 :next n2})])])]

    [:oo::Exp.IsZero {:e inner}
      (:wat::core::match (:oo::eval inner env self curclass cs st next)
        [:oo::Ans.A {:v v :st s1 :next n1}
          (:oo::Ans.A {:v (:oo::Val.Bool {:b (:wat::core::= 0 (:oo::num-of v))}) :st s1 :next n1})])]

    [:oo::Exp.If {:c c :t t :f f}
      (:wat::core::match (:oo::eval c env self curclass cs st next)
        [:oo::Ans.A {:v vc :st s1 :next n1}
          (:wat::core::if (:oo::truthy? vc)
            (:oo::eval t env self curclass cs s1 n1)
            (:oo::eval f env self curclass cs s1 n1))])]

    [:oo::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:oo::eval rhs env self curclass cs st next)
        [:oo::Ans.A {:v vr :st s1 :next n1}
          (:oo::eval body (:oo::Env.EBind {:name name :v vr :rest env}) self curclass cs s1 n1)])]

    [:oo::Exp.Seq {:a a :b b}
      (:wat::core::match (:oo::eval a env self curclass cs st next)
        [:oo::Ans.A {:v va :st s1 :next n1} (:oo::eval b env self curclass cs s1 n1)])]

    ;; a field reference resolves through SELF's class, so an inherited method reading `count`
    ;; reads the subclass instance's cell
    [:oo::Exp.Field {:name name}
      (:wat::core::match (:oo::find-class cs (:oo::class-of self))
        [:oo::Class.C {:name cn :super sp :fields fs :methods ms}
          (:oo::Ans.A {:v (:oo::fetch st (:wat::core::+ (:oo::base-of self)
                                           (:oo::index-of fs name 0)))
                       :st st :next next})])]

    [:oo::Exp.SetField {:name name :e rhs}
      (:wat::core::match (:oo::eval rhs env self curclass cs st next)
        [:oo::Ans.A {:v v :st s1 :next n1}
          (:wat::core::match (:oo::find-class cs (:oo::class-of self))
            [:oo::Class.C {:name cn :super sp :fields fs :methods ms}
              (:oo::Ans.A {:v v
                           :st (:wat::map::assoc s1
                                 (:wat::core::+ (:oo::base-of self) (:oo::index-of fs name 0)) v)
                           :next n1})])])]

    ;; new: allocate one cell per field (inherited included), then run `initialize`
    [:oo::Exp.New {:cls cls :args args}
      (:wat::core::match (:oo::eval-args args env self curclass cs st next)
        [:oo::AnsL.AL {:vs vs :st s1 :next n1}
          (:wat::core::match (:oo::find-class cs cls)
            [:oo::Class.C {:name cn :super sp :fields fs :methods ms}
              (:wat::core::let [nf (:oo::count-names fs)
                                obj (:oo::Val.Obj {:cls cls :base n1})
                                s2 (:oo::init-fields s1 n1 0 nf)
                                n2 (:wat::core::+ n1 nf)]
                (:wat::core::match (:oo::lookup-method cs cls "initialize")
                  [:oo::Found.Miss {} (:oo::Ans.A {:v obj :st s2 :next n2})]
                  [:oo::Found.Hit {:m m :owner owner}
                    (:wat::core::match (:oo::apply-method m owner obj vs cs s2 n2)
                      [:oo::Ans.A {:v iv :st s3 :next n3}
                        (:oo::Ans.A {:v obj :st s3 :next n3})])]))])])]

    ;; send: dispatch from the OBJECT's class — the override wins even from inside a parent method
    [:oo::Exp.Send {:obj obje :meth meth :args args}
      (:wat::core::match (:oo::eval obje env self curclass cs st next)
        [:oo::Ans.A {:v ov :st s1 :next n1}
          (:wat::core::match (:oo::eval-args args env self curclass cs s1 n1)
            [:oo::AnsL.AL {:vs vs :st s2 :next n2}
              (:wat::core::match (:oo::lookup-method cs (:oo::class-of ov) meth)
                [:oo::Found.Miss {} (:oo::Ans.A {:v (:oo::Val.Nil {}) :st s2 :next n2})]
                [:oo::Found.Hit {:m m :owner owner} (:oo::apply-method m owner ov vs cs s2 n2)])])])]

    ;; super: dispatch from ABOVE the class whose method is running — a different starting point
    [:oo::Exp.Super {:meth meth :args args}
      (:wat::core::match (:oo::eval-args args env self curclass cs st next)
        [:oo::AnsL.AL {:vs vs :st s1 :next n1}
          (:wat::core::match (:oo::find-class cs curclass)
            [:oo::Class.C {:name cn :super sp :fields fs :methods ms}
              (:wat::core::match (:oo::lookup-method cs sp meth)
                [:oo::Found.Miss {} (:oo::Ans.A {:v (:oo::Val.Nil {}) :st s1 :next n1})]
                [:oo::Found.Hit {:m m :owner owner}
                  (:oo::apply-method m owner self vs cs s1 n1)])])])]))

(:wat::core::defn :oo::run [e <- :oo::Exp cs <- :oo::Classes] -> :wat::core::i64
  (:wat::core::match (:oo::eval e (:oo::Env.ENil {}) (:oo::Val.Nil {}) "" cs
                       (:wat::core::PersistentMap :- [:wat::core::i64 :oo::Val]) 0)
    [:oo::Ans.A {:v v :st st :next next} (:oo::num-of v)]))
