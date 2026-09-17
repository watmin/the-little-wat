;; eopl/lib/cps6.wat — EOPL chapter 6: the CPS TRANSFORMATION, source to source.
;;
;; Chapter 5 changed the MACHINE (a defunctionalized continuation driven from a loop). Chapter 6
;; changes the PROGRAM instead, and leaves the machine alone: `cps-of-exp` rewrites a LETREC term
;; into another LETREC term in which EVERY CALL IS A TAIL CALL.
;;
;; That claim is directly testable in wat, and the test composes two things this repository
;; already established:
;;   F-099  a non-tail recursion segfaults past ~110000 host frames, empty stderr;
;;   C-061  wat's TCO is preserved THROUGH the direct interpreter — an interpreted tail call
;;          lands in tail position inside `value-of`, so the host collapses that frame too.
;; Together they predict: the SAME direct interpreter should die on a deep non-tail program and
;; survive its CPS transform. eopl/ch06-cps-transform.wat runs exactly that.
;;
;; The continuation is passed by CURRYING, because LETREC's procedures take one argument:
;; a transformed `proc(x) body` becomes `proc(x) proc(k) body'`, and a call becomes `((f a) k)`.
;;
;; Fresh names are threaded through a counter rather than mutated, so `cps-of` answers a pair.

(:wat::core::defenum :c6::Out :wat::enum::Pure
  :E [e <- :eopl::Exp  n <- :wat::core::i64])

(:wat::core::defn :c6::fresh [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "k%" (:wat::i64::to-string n)))

(:wat::core::defn :c6::v% [n <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "v%" (:wat::i64::to-string n)))

;; apply a continuation EXPRESSION to a simple value expression: always a tail call
(:wat::core::defn :c6::app-k [k <- :eopl::Exp v <- :eopl::Exp] -> :eopl::Exp
  (:eopl::Exp.Call {:rator k :rand v}))

;; cps-of : Exp -> (continuation Exp) -> counter -> Out
(:wat::core::defn :c6::cps-of
  [e <- :eopl::Exp k <- :eopl::Exp n <- :wat::core::i64] -> :c6::Out
  (:wat::core::match e

    ;; ---- simple expressions: hand them straight to the continuation ----
    [:eopl::Exp.Const {:n c} (:c6::Out.E {:e (:c6::app-k k (:eopl::Exp.Const {:n c})) :n n})]
    [:eopl::Exp.Var {:name name} (:c6::Out.E {:e (:c6::app-k k (:eopl::Exp.Var {:name name})) :n n})]

    ;; ---- proc: proc(x) body  ==>  proc(x) proc(k) body'  (currying carries the continuation) ----
    [:eopl::Exp.Proc {:param p :body body}
      (:wat::core::match (:c6::cps-of body (:eopl::Exp.Var {:name (:c6::fresh n)})
                           (:wat::core::+ n 1))
        [:c6::Out.E {:e body2 :n n2}
          (:c6::Out.E
            {:e (:c6::app-k k
                  (:eopl::Exp.Proc {:param p
                                    :body (:eopl::Exp.Proc {:param (:c6::fresh n) :body body2})}))
             :n n2})])]

    ;; ---- diff: evaluate a, then b, then hand the difference on ----
    [:eopl::Exp.Diff {:a a :b b}
      (:wat::core::let [va (:c6::v% n)
                        vb (:c6::v% (:wat::core::+ n 1))]
        (:wat::core::match (:c6::cps-of b
                             (:eopl::Exp.Proc
                               {:param vb
                                :body (:c6::app-k k (:eopl::Exp.Diff {:a (:eopl::Exp.Var {:name va})
                                                                      :b (:eopl::Exp.Var {:name vb})}))})
                             (:wat::core::+ n 2))
          [:c6::Out.E {:e bpart :n n2}
            (:c6::cps-of a (:eopl::Exp.Proc {:param va :body bpart}) n2)]))]

    [:eopl::Exp.IsZero {:e inner}
      (:wat::core::let [va (:c6::v% n)]
        (:c6::cps-of inner
          (:eopl::Exp.Proc {:param va
                            :body (:c6::app-k k (:eopl::Exp.IsZero {:e (:eopl::Exp.Var {:name va})}))})
          (:wat::core::+ n 1)))]

    ;; ---- if: the continuation is DUPLICATED into both arms. That is the code blow-up EOPL
    ;;      warns about, and the reason a real compiler binds k to a name first.
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::let [vc (:c6::v% n)]
        (:wat::core::match (:c6::cps-of t k (:wat::core::+ n 1))
          [:c6::Out.E {:e t2 :n n2}
            (:wat::core::match (:c6::cps-of f k n2)
              [:c6::Out.E {:e f2 :n n3}
                (:c6::cps-of c
                  (:eopl::Exp.Proc {:param vc
                                    :body (:eopl::Exp.If {:c (:eopl::Exp.Var {:name vc})
                                                          :t t2 :f f2})})
                  n3)])]))]

    ;; ---- let: a let is a continuation whose parameter is the bound name ----
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::match (:c6::cps-of body k n)
        [:c6::Out.E {:e body2 :n n2}
          (:c6::cps-of rhs (:eopl::Exp.Proc {:param name :body body2}) n2)])]

    ;; ---- call: evaluate rator, then rand, then ((f a) k) — a TAIL call, which is the point ----
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::let [vf (:c6::v% n)
                        va (:c6::v% (:wat::core::+ n 1))]
        (:wat::core::match (:c6::cps-of rand
                             (:eopl::Exp.Proc
                               {:param va
                                :body (:eopl::Exp.Call
                                        {:rator (:eopl::Exp.Call {:rator (:eopl::Exp.Var {:name vf})
                                                                  :rand (:eopl::Exp.Var {:name va})})
                                         :rand k})})
                             (:wat::core::+ n 2))
          [:c6::Out.E {:e randpart :n n2}
            (:c6::cps-of rator (:eopl::Exp.Proc {:param vf :body randpart}) n2)]))]

    ;; ---- letrec: the bound procedure is curried the same way as Proc ----
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::match (:c6::cps-of fbody (:eopl::Exp.Var {:name (:c6::fresh n)})
                           (:wat::core::+ n 1))
        [:c6::Out.E {:e fbody2 :n n2}
          (:wat::core::match (:c6::cps-of body k n2)
            [:c6::Out.E {:e body2 :n n3}
              (:c6::Out.E
                {:e (:eopl::Exp.Letrec
                      {:fname fname :param param
                       :fbody (:eopl::Exp.Proc {:param (:c6::fresh n) :body fbody2})
                       :body body2})
                 :n n3})])])]))

;; the top-level continuation is the identity: proc(v) v
(:wat::core::defn :c6::cps-of-program [e <- :eopl::Exp] -> :eopl::Exp
  (:wat::core::match (:c6::cps-of e
                       (:eopl::Exp.Proc {:param "%halt" :body (:eopl::Exp.Var {:name "%halt"})})
                       0)
    [:c6::Out.E {:e out :n n} out]))

;; ---- how many calls in a term are NOT in tail position? the transform's whole claim is: zero ----
(:wat::core::defn :c6::nontail [e <- :eopl::Exp] -> :wat::core::i64
  (:wat::core::match e
    [:eopl::Exp.Const {:n c} 0]
    [:eopl::Exp.Var {:name name} 0]
    [:eopl::Exp.Proc {:param p :body body} (:c6::nontail body)]
    ;; an operand position is NOT tail: any Call nested in one is a non-tail call
    [:eopl::Exp.Diff {:a a :b b} (:wat::core::+ (:c6::calls a) (:c6::calls b))]
    [:eopl::Exp.IsZero {:e inner} (:c6::calls inner)]
    ;; a conditional's test is not tail; its arms are
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::+ (:c6::calls c) (:wat::core::+ (:c6::nontail t) (:c6::nontail f)))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::+ (:c6::calls rhs) (:c6::nontail body))]
    ;; rator and rand are not tail; the call itself is
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::+ (:c6::calls rator) (:c6::calls rand))]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::+ (:c6::nontail fbody) (:c6::nontail body))]))

;; every Call anywhere inside a non-tail context counts
(:wat::core::defn :c6::calls [e <- :eopl::Exp] -> :wat::core::i64
  (:wat::core::match e
    [:eopl::Exp.Const {:n c} 0]
    [:eopl::Exp.Var {:name name} 0]
    [:eopl::Exp.Proc {:param p :body body} (:c6::nontail body)]
    [:eopl::Exp.Diff {:a a :b b} (:wat::core::+ (:c6::calls a) (:c6::calls b))]
    [:eopl::Exp.IsZero {:e inner} (:c6::calls inner)]
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::+ (:c6::calls c) (:wat::core::+ (:c6::calls t) (:c6::calls f)))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::+ (:c6::calls rhs) (:c6::calls body))]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::+ 1 (:wat::core::+ (:c6::calls rator) (:c6::calls rand)))]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::+ (:c6::nontail fbody) (:c6::calls body))]))

(:wat::core::defn :c6::size [e <- :eopl::Exp] -> :wat::core::i64
  (:wat::core::match e
    [:eopl::Exp.Const {:n c} 1]
    [:eopl::Exp.Var {:name name} 1]
    [:eopl::Exp.Proc {:param p :body body} (:wat::core::+ 1 (:c6::size body))]
    [:eopl::Exp.Diff {:a a :b b} (:wat::core::+ 1 (:wat::core::+ (:c6::size a) (:c6::size b)))]
    [:eopl::Exp.IsZero {:e inner} (:wat::core::+ 1 (:c6::size inner))]
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::+ 1 (:wat::core::+ (:c6::size c) (:wat::core::+ (:c6::size t) (:c6::size f))))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::+ 1 (:wat::core::+ (:c6::size rhs) (:c6::size body)))]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::+ 1 (:wat::core::+ (:c6::size rator) (:c6::size rand)))]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::+ 1 (:wat::core::+ (:c6::size fbody) (:c6::size body)))]))

;; ---------------------------------------------------------------------------------------------
;; Why `nontail` on the OUTPUT is not zero, and what the real theorem is.
;;
;; EOPL's CPS target has MULTI-ARGUMENT procedures, so a transformed call is `(f a k)` — one call
;; in tail position, and "every call is a tail call" is literally true. LETREC's procedures take
;; ONE argument, so the continuation must be CURRIED: `((f a) k)`. The inner `(f a)` sits in the
;; operator position of the outer call, so `nontail` counts it, once per call site.
;;
;; A first attempt to rescue the claim counted "non-tail calls with a non-simple operator or
;; operand" and reported 6 rather than 0 — because that metric ignores tail position entirely and
;; flags the curried spine itself. It measured the wrong thing and is not kept.
;;
;; The property that actually holds, and the one the depth ceiling follows, is a GRAMMAR:
;;
;;   SimpleExp ::= Const | Var | proc(x) TfExp | -(SimpleExp, SimpleExp) | zero?(SimpleExp)
;;   TfExp     ::= (SimpleExp SimpleExp)            -- apply a continuation
;;               | ((SimpleExp SimpleExp) SimpleExp) -- curried: apply a proc, then its continuation
;;               | if SimpleExp then TfExp else TfExp
;;               | letrec f(x) = SimpleExp in TfExp
;;
;; Every operator and every operand is SIMPLE — evaluating one can never re-enter the program —
;; so the only nested call is the curried spine, whose inner application returns a closure
;; immediately. `violations` counts the places the output departs from that grammar. It is 0 on
;; the transform's output and non-zero on the source, which is the checkable form of the claim.

;; EOPL's SimpleExp: an expression whose evaluation can neither diverge nor call a procedure.
;; That includes PRIMITIVE APPLICATIONS over simple operands -- `-(x,y)` and `zero?(x)` are simple
;; -- which a first version of this predicate got wrong, reporting the transform's own output as
;; ungrammatical. `proc` is simple because building a closure evaluates nothing.
(:wat::core::defn :c6::simple? [e <- :eopl::Exp] -> :wat::core::bool
  (:wat::core::match e
    [:eopl::Exp.Const {:n c} true]
    [:eopl::Exp.Var {:name name} true]
    [:eopl::Exp.Proc {:param p :body body} true]
    [:eopl::Exp.Diff {:a a :b b} (:wat::core::and (:c6::simple? a) (:c6::simple? b))]
    [:eopl::Exp.IsZero {:e inner} (:c6::simple? inner)]
    [:eopl::Exp.If {:c c :t t :f f} false]
    [:eopl::Exp.Let {:name name :e rhs :body body} false]
    [:eopl::Exp.Call {:rator rator :rand rand} false]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body} false]))

;; an operator may be simple, or the curried spine `(SimpleExp SimpleExp)` — nothing else
(:wat::core::defn :c6::ok-rator? [e <- :eopl::Exp] -> :wat::core::bool
  (:wat::core::match e
    [:eopl::Exp.Call {:rator r :rand d}
      (:wat::core::and (:c6::simple? r) (:c6::simple? d))]
    [:eopl::Exp.Const {:n c} true]
    [:eopl::Exp.Var {:name name} true]
    [:eopl::Exp.Proc {:param p :body body} true]
    [:eopl::Exp.Diff {:a a :b b} false]
    [:eopl::Exp.IsZero {:e inner} false]
    [:eopl::Exp.If {:c c :t t :f f} false]
    [:eopl::Exp.Let {:name name :e rhs :body body} false]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body} false]))

(:wat::core::defn :c6::bad [ok <- :wat::core::bool] -> :wat::core::i64
  (:wat::core::if ok 0 1))

;; how many places does this term depart from the CPS grammar above?
(:wat::core::defn :c6::violations [e <- :eopl::Exp] -> :wat::core::i64
  (:wat::core::match e
    [:eopl::Exp.Const {:n c} 0]
    [:eopl::Exp.Var {:name name} 0]
    [:eopl::Exp.Proc {:param p :body body} (:c6::violations body)]
    [:eopl::Exp.Diff {:a a :b b}
      (:wat::core::+ (:wat::core::+ (:c6::bad (:c6::simple? a)) (:c6::bad (:c6::simple? b)))
        (:wat::core::+ (:c6::violations a) (:c6::violations b)))]
    [:eopl::Exp.IsZero {:e inner}
      (:wat::core::+ (:c6::bad (:c6::simple? inner)) (:c6::violations inner))]
    [:eopl::Exp.If {:c c :t t :f f}
      (:wat::core::+ (:c6::bad (:c6::simple? c))
        (:wat::core::+ (:c6::violations c)
          (:wat::core::+ (:c6::violations t) (:c6::violations f))))]
    [:eopl::Exp.Let {:name name :e rhs :body body}
      (:wat::core::+ (:c6::bad (:c6::simple? rhs))
        (:wat::core::+ (:c6::violations rhs) (:c6::violations body)))]
    [:eopl::Exp.Call {:rator rator :rand rand}
      (:wat::core::+ (:wat::core::+ (:c6::bad (:c6::simple? rand)) (:c6::bad (:c6::ok-rator? rator)))
        (:wat::core::+ (:c6::violations rator) (:c6::violations rand)))]
    [:eopl::Exp.Letrec {:fname fname :param param :fbody fbody :body body}
      (:wat::core::+ (:c6::violations fbody) (:c6::violations body))]))
