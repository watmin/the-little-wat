;; eopl/lib/mutpairs.wat — EOPL chapter 4's MUTABLE-PAIRS.
;;
;; A pair is TWO ADJACENT STORE CELLS, so `newpair` allocates n and n+1 and the pair value is just
;; n. `left`/`right` fetch; `setleft`/`setright` assign. Nothing new is needed in the store, which
;; is EOPL's point: mutable aggregates fall out of a store that already exists.
;;
;; Store is a PersistentMap keyed by cell index (F-104: no positional update on a vector).

(:wat::core::typealias :mp::Store (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defenum :mp::Exp :wat::enum::Pure
  :Lit      [n <- :wat::core::i64]
  :Var      [name <- :wat::core::String]
  :Add      [a <- :mp::Exp  b <- :mp::Exp]
  :Seq      [a <- :mp::Exp  b <- :mp::Exp]
  :Let      [name <- :wat::core::String  e <- :mp::Exp  body <- :mp::Exp]
  :NewPair  [l <- :mp::Exp  r <- :mp::Exp]
  :Left     [p <- :mp::Exp]
  :Right    [p <- :mp::Exp]
  :SetLeft  [p <- :mp::Exp  v <- :mp::Exp]
  :SetRight [p <- :mp::Exp  v <- :mp::Exp])

(:wat::core::defenum :mp::Env :wat::enum::Pure
  :E0 [] :E1 [name <- :wat::core::String  v <- :wat::core::i64  rest <- :mp::Env])

(:wat::core::defn :mp::look [env <- :mp::Env name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match env
    [:mp::Env.E0 {} 0]
    [:mp::Env.E1 {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:mp::look rest name))]))

(:wat::core::defenum :mp::Ans :wat::enum::Pure
  :A [v <- :wat::core::i64  st <- :mp::Store  next <- :wat::core::i64])

(:wat::core::defn :mp::fetch [st <- :mp::Store i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get st i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :mp::eval
  [e <- :mp::Exp env <- :mp::Env st <- :mp::Store next <- :wat::core::i64] -> :mp::Ans
  (:wat::core::match e
    [:mp::Exp.Lit {:n n} (:mp::Ans.A {:v n :st st :next next})]
    [:mp::Exp.Var {:name name} (:mp::Ans.A {:v (:mp::look env name) :st st :next next})]
    [:mp::Exp.Add {:a a :b b}
      (:wat::core::match (:mp::eval a env st next)
        [:mp::Ans.A {:v va :st s1 :next n1}
          (:wat::core::match (:mp::eval b env s1 n1)
            [:mp::Ans.A {:v vb :st s2 :next n2}
              (:mp::Ans.A {:v (:wat::core::+ va vb) :st s2 :next n2})])])]
    [:mp::Exp.Seq {:a a :b b}
      (:wat::core::match (:mp::eval a env st next)
        [:mp::Ans.A {:v va :st s1 :next n1} (:mp::eval b env s1 n1)])]
    [:mp::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:mp::eval rhs env st next)
        [:mp::Ans.A {:v vr :st s1 :next n1}
          (:mp::eval body (:mp::Env.E1 {:name name :v vr :rest env}) s1 n1)])]
    ;; TWO ADJACENT CELLS, and the pair's value is the first index
    [:mp::Exp.NewPair {:l l :r r}
      (:wat::core::match (:mp::eval l env st next)
        [:mp::Ans.A {:v vl :st s1 :next n1}
          (:wat::core::match (:mp::eval r env s1 n1)
            [:mp::Ans.A {:v vr :st s2 :next n2}
              (:mp::Ans.A {:v n2
                           :st (:wat::map::assoc (:wat::map::assoc s2 n2 vl) (:wat::core::+ n2 1) vr)
                           :next (:wat::core::+ n2 2)})])])]
    [:mp::Exp.Left {:p p}
      (:wat::core::match (:mp::eval p env st next)
        [:mp::Ans.A {:v pv :st s1 :next n1} (:mp::Ans.A {:v (:mp::fetch s1 pv) :st s1 :next n1})])]
    [:mp::Exp.Right {:p p}
      (:wat::core::match (:mp::eval p env st next)
        [:mp::Ans.A {:v pv :st s1 :next n1}
          (:mp::Ans.A {:v (:mp::fetch s1 (:wat::core::+ pv 1)) :st s1 :next n1})])]
    [:mp::Exp.SetLeft {:p p :v vexp}
      (:wat::core::match (:mp::eval p env st next)
        [:mp::Ans.A {:v pv :st s1 :next n1}
          (:wat::core::match (:mp::eval vexp env s1 n1)
            [:mp::Ans.A {:v nv :st s2 :next n2}
              (:mp::Ans.A {:v nv :st (:wat::map::assoc s2 pv nv) :next n2})])])]
    [:mp::Exp.SetRight {:p p :v vexp}
      (:wat::core::match (:mp::eval p env st next)
        [:mp::Ans.A {:v pv :st s1 :next n1}
          (:wat::core::match (:mp::eval vexp env s1 n1)
            [:mp::Ans.A {:v nv :st s2 :next n2}
              (:mp::Ans.A {:v nv
                           :st (:wat::map::assoc s2 (:wat::core::+ pv 1) nv)
                           :next n2})])])]))

(:wat::core::defn :mp::run [e <- :mp::Exp] -> :wat::core::i64
  (:wat::core::match (:mp::eval e (:mp::Env.E0 {})
                       (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0)
    [:mp::Ans.A {:v v :st st :next next} v]))
