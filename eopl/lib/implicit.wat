;; eopl/lib/implicit.wat — EOPL chapter 4's IMPLICIT-REFS and CALL-BY-REFERENCE.
;;
;; EXPLICIT-REFS (lib/refs.wat) makes the programmer say `newref`/`deref`/`setref`. IMPLICIT-REFS
;; moves that below the surface: EVERY variable is bound to a reference, a bare `x` dereferences
;; automatically, and `set x = e` assigns through it. The language looks like an ordinary
;; imperative one and the store is still threaded, so the interpreter stays pure.
;;
;; CALL-BY-REFERENCE is then a two-line change rather than a new language, which is EOPL's point:
;; when the argument is already a variable, pass its REFERENCE instead of allocating a fresh cell,
;; and the callee's assignments are visible to the caller. `:imp::Strategy` selects between them so
;; both can be run over the same program and compared.
;;
;; The store is a PersistentMap keyed by cell index (F-104: no positional update on a vector).

(:wat::core::typealias :imp::Store (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defenum :imp::Exp :wat::enum::Pure
  :Lit   [n <- :wat::core::i64]
  :Var   [name <- :wat::core::String]
  :Add   [a <- :imp::Exp  b <- :imp::Exp]
  :Seq   [a <- :imp::Exp  b <- :imp::Exp]
  :Let   [name <- :wat::core::String  e <- :imp::Exp  body <- :imp::Exp]
  :Set   [name <- :wat::core::String  e <- :imp::Exp]
  :Proc  [param <- :wat::core::String  body <- :imp::Exp]
  :Call  [rator <- :imp::Exp  rand <- :imp::Exp])

;; an environment binds a name to a REFERENCE, never to a value
(:wat::core::defenum :imp::Env :wat::enum::Pure
  :E0 []
  :E1 [name <- :wat::core::String  ref <- :wat::core::i64  rest <- :imp::Env])

(:wat::core::defenum :imp::Strategy :wat::enum::Pure
  :ByValue [] :ByReference [])

;; a closure is a value in the store, so values are tagged: a number, or a procedure
(:wat::core::defenum :imp::Val :wat::enum::Pure
  :VNum [n <- :wat::core::i64]
  :VClo [param <- :wat::core::String  body <- :imp::Exp  env <- :imp::Env])

;; the store holds i64 cells; procedures live in a side table keyed the same way, which keeps the
;; store monomorphic and is enough for the programs this chapter needs
(:wat::core::defenum :imp::Ans :wat::enum::Pure
  :A [v <- :imp::Val  st <- :imp::Store  next <- :wat::core::i64])

(:wat::core::defn :imp::find-ref [env <- :imp::Env name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match env
    [:imp::Env.E0 {} -1]
    [:imp::Env.E1 {:name n :ref r :rest rest}
      (:wat::core::if (:wat::core::= n name) r (:imp::find-ref rest name))]))

(:wat::core::defn :imp::fetch [st <- :imp::Store i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get st i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :imp::num [v <- :imp::Val] -> :wat::core::i64
  (:wat::core::match v
    [:imp::Val.VNum {:n n} n]
    [:imp::Val.VClo {:param p :body b :env e} 0]))

;; is this expression a bare variable? that is the whole of the call-by-reference decision
(:wat::core::defn :imp::var-name [e <- :imp::Exp] -> :wat::core::String
  (:wat::core::match e
    [:imp::Exp.Var {:name name} name]
    [:imp::Exp.Lit {:n n} ""] [:imp::Exp.Add {:a a :b b} ""] [:imp::Exp.Seq {:a a :b b} ""]
    [:imp::Exp.Let {:name n :e x :body y} ""] [:imp::Exp.Set {:name n :e x} ""]
    [:imp::Exp.Proc {:param p :body b} ""] [:imp::Exp.Call {:rator r :rand d} ""]))

(:wat::core::defn :imp::eval
  [e <- :imp::Exp env <- :imp::Env st <- :imp::Store next <- :wat::core::i64
   sty <- :imp::Strategy] -> :imp::Ans
  (:wat::core::match e
    [:imp::Exp.Lit {:n n} (:imp::Ans.A {:v (:imp::Val.VNum {:n n}) :st st :next next})]
    ;; A BARE VARIABLE DEREFERENCES -- that is what "implicit" means
    [:imp::Exp.Var {:name name}
      (:imp::Ans.A {:v (:imp::Val.VNum {:n (:imp::fetch st (:imp::find-ref env name))})
                    :st st :next next})]
    [:imp::Exp.Add {:a a :b b}
      (:wat::core::match (:imp::eval a env st next sty)
        [:imp::Ans.A {:v va :st st1 :next n1}
          (:wat::core::match (:imp::eval b env st1 n1 sty)
            [:imp::Ans.A {:v vb :st st2 :next n2}
              (:imp::Ans.A {:v (:imp::Val.VNum {:n (:wat::core::+ (:imp::num va) (:imp::num vb))})
                            :st st2 :next n2})])])]
    [:imp::Exp.Seq {:a a :b b}
      (:wat::core::match (:imp::eval a env st next sty)
        [:imp::Ans.A {:v va :st st1 :next n1} (:imp::eval b env st1 n1 sty)])]
    ;; let allocates a fresh cell and binds the NAME TO THE CELL
    [:imp::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:imp::eval rhs env st next sty)
        [:imp::Ans.A {:v vr :st st1 :next n1}
          (:imp::eval body (:imp::Env.E1 {:name name :ref n1 :rest env})
            (:wat::map::assoc st1 n1 (:imp::num vr)) (:wat::core::+ n1 1) sty)])]
    ;; set assigns THROUGH the reference the name is bound to
    [:imp::Exp.Set {:name name :e rhs}
      (:wat::core::match (:imp::eval rhs env st next sty)
        [:imp::Ans.A {:v vr :st st1 :next n1}
          (:imp::Ans.A {:v vr :st (:wat::map::assoc st1 (:imp::find-ref env name) (:imp::num vr))
                        :next n1})])]
    [:imp::Exp.Proc {:param param :body body}
      (:imp::Ans.A {:v (:imp::Val.VClo {:param param :body body :env env}) :st st :next next})]
    [:imp::Exp.Call {:rator rator :rand rand}
      (:wat::core::match (:imp::eval rator env st next sty)
        [:imp::Ans.A {:v vf :st st1 :next n1}
          (:wat::core::match vf
            [:imp::Val.VClo {:param param :body body :env cenv}
              (:wat::core::let [vn (:imp::var-name rand)]
                ;; THE TWO-LINE DIFFERENCE. By reference, a bare variable argument passes its own
                ;; cell, so the callee's `set` is visible to the caller. By value, a fresh cell is
                ;; allocated and the caller is insulated.
                (:wat::core::if
                  (:wat::core::if (:wat::core::= (:wat::core::match sty
                                                   [:imp::Strategy.ByReference {} 1]
                                                   [:imp::Strategy.ByValue {} 0]) 1)
                    (:wat::core::not (:wat::core::= vn "")) false)
                  (:imp::eval body (:imp::Env.E1 {:name param :ref (:imp::find-ref env vn) :rest cenv})
                    st1 n1 sty)
                  (:wat::core::match (:imp::eval rand env st1 n1 sty)
                    [:imp::Ans.A {:v va :st st2 :next n2}
                      (:imp::eval body (:imp::Env.E1 {:name param :ref n2 :rest cenv})
                        (:wat::map::assoc st2 n2 (:imp::num va)) (:wat::core::+ n2 1) sty)])))]
            [:imp::Val.VNum {:n n} (:imp::Ans.A {:v (:imp::Val.VNum {:n -998}) :st st1 :next n1})])])]))

(:wat::core::defn :imp::run [e <- :imp::Exp sty <- :imp::Strategy] -> :wat::core::i64
  (:wat::core::match (:imp::eval e (:imp::Env.E0 {})
                       (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0 sty)
    [:imp::Ans.A {:v v :st st :next next} (:imp::num v)]))
