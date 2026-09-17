;; eopl/lib/refs.wat — EOPL chapter 4's EXPLICIT-REFS: newref, deref, setref over a store.
;;
;; EOPL's store is an array indexed by reference. wat has no positional update on either vector
;; type (F-104), so the store is a `PersistentMap` keyed by index -- the same shape F-057 forces
;; on a visited set. That is not a workaround here so much as the idiom: wat's structure-sharing
;; story is map-shaped.
;;
;; The store is THREADED rather than mutated, so the interpreter stays a pure function. ch04
;; prices that choice against the two alternatives wat offers.

(:wat::core::typealias :ref::Store (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]))

(:wat::core::defenum :ref::Exp :wat::enum::Pure
  :Lit    [n <- :wat::core::i64]
  :Var    [name <- :wat::core::String]
  :Add    [a <- :ref::Exp  b <- :ref::Exp]
  :Let    [name <- :wat::core::String  e <- :ref::Exp  body <- :ref::Exp]
  :Seq    [a <- :ref::Exp  b <- :ref::Exp]
  :NewRef [e <- :ref::Exp]
  :DeRef  [e <- :ref::Exp]
  :SetRef [r <- :ref::Exp  v <- :ref::Exp]
  :Rep    [times <- :wat::core::i64  body <- :ref::Exp])

(:wat::core::defenum :ref::Env :wat::enum::Pure
  :E0 [] :E1 [name <- :wat::core::String  v <- :wat::core::i64  rest <- :ref::Env])

(:wat::core::defn :ref::look [env <- :ref::Env name <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match env
    [:ref::Env.E0 {} 0]
    [:ref::Env.E1 {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) v (:ref::look rest name))]))

;; the answer of one evaluation: a value, the store it left behind, and the next free cell
(:wat::core::defenum :ref::Ans :wat::enum::Pure
  :A [v <- :wat::core::i64  st <- :ref::Store  next <- :wat::core::i64])

(:wat::core::defn :ref::fetch [st <- :ref::Store i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::map::get st i)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} 0]))

(:wat::core::defn :ref::eval
  [e <- :ref::Exp env <- :ref::Env st <- :ref::Store next <- :wat::core::i64] -> :ref::Ans
  (:wat::core::match e
    [:ref::Exp.Lit {:n n} (:ref::Ans.A {:v n :st st :next next})]
    [:ref::Exp.Var {:name name} (:ref::Ans.A {:v (:ref::look env name) :st st :next next})]
    [:ref::Exp.Add {:a a :b b}
      (:wat::core::match (:ref::eval a env st next)
        [:ref::Ans.A {:v va :st st1 :next n1}
          (:wat::core::match (:ref::eval b env st1 n1)
            [:ref::Ans.A {:v vb :st st2 :next n2}
              (:ref::Ans.A {:v (:wat::core::+ va vb) :st st2 :next n2})])])]
    [:ref::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:ref::eval rhs env st next)
        [:ref::Ans.A {:v vr :st st1 :next n1}
          (:ref::eval body (:ref::Env.E1 {:name name :v vr :rest env}) st1 n1)])]
    [:ref::Exp.Seq {:a a :b b}
      (:wat::core::match (:ref::eval a env st next)
        [:ref::Ans.A {:v va :st st1 :next n1} (:ref::eval b env st1 n1)])]
    ;; newref: allocate the next cell
    [:ref::Exp.NewRef {:e inner}
      (:wat::core::match (:ref::eval inner env st next)
        [:ref::Ans.A {:v v :st st1 :next n1}
          (:ref::Ans.A {:v n1 :st (:wat::map::assoc st1 n1 v) :next (:wat::core::+ n1 1)})])]
    [:ref::Exp.DeRef {:e inner}
      (:wat::core::match (:ref::eval inner env st next)
        [:ref::Ans.A {:v r :st st1 :next n1}
          (:ref::Ans.A {:v (:ref::fetch st1 r) :st st1 :next n1})])]
    [:ref::Exp.SetRef {:r r :v vexp}
      (:wat::core::match (:ref::eval r env st next)
        [:ref::Ans.A {:v rv :st st1 :next n1}
          (:wat::core::match (:ref::eval vexp env st1 n1)
            [:ref::Ans.A {:v nv :st st2 :next n2}
              (:ref::Ans.A {:v nv :st (:wat::map::assoc st2 rv nv) :next n2})])])]
    [:ref::Exp.Rep {:times times :body body}
      (:wat::core::if (:wat::core::<= times 0)
        (:ref::Ans.A {:v 0 :st st :next next})
        (:wat::core::match (:ref::eval body env st next)
          [:ref::Ans.A {:v v :st st1 :next n1}
            (:ref::eval (:ref::Exp.Rep {:times (:wat::core::- times 1) :body body}) env st1 n1)]))]))

(:wat::core::defn :ref::run [e <- :ref::Exp] -> :wat::core::i64
  (:wat::core::match (:ref::eval e (:ref::Env.E0 {})
                       (:wat::core::PersistentMap :- [:wat::core::i64 :wat::core::i64]) 0)
    [:ref::Ans.A {:v v :st st :next next} v]))
