;; SICP §4.4 (logic programming), in wat.
;;
;; A database of facts, patterns containing variables, and UNIFICATION. The section's point is
;; that a query computes in a different direction from a procedure: one fact shape,
;; `(job ?person ?title)`, answers "who is a computer programmer" and "what does Ben do" depending
;; only on where the variable is. Both are checked below, against the same facts.
;;
;; This repository has reached unification twice before, from different directions -- PAIP ch11
;; (C-035's neighbourhood) builds it for Prolog, and EOPL ch7 (C-063) builds it for TYPE
;; inference, where the occurs check is what stops the checker looping. Here it is the query
;; engine, and the third use is worth having because the DATA is different: types are trees of
;; type constructors, Prolog terms are trees of functors, and these are trees of plain symbols.
;; The algorithm is the same one all three times, which is the section's real claim.
;;
;; A term is a four-variant enum, which is how the heterogeneity SICP gets from untyped lists is
;; paid for here (C-004, C-077): a fact like `(job (Bitdiddle Ben) (computer wizard))` is a List of
;; Lists of Syms, and a pattern is the same shape with Vars in it.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch44-logic-programming.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch44-logic-programming.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :sicp::Term :wat::enum::Pure
  :Sym  [name <- :wat::core::String]
  :Num  [n <- :wat::core::i64]
  :Var  [name <- :wat::core::String]
  :List [xs <- :sicp::Terms])

(:wat::core::defenum :sicp::Terms :wat::enum::Pure
  :TNil  []
  :TCons [t <- :sicp::Term  rest <- :sicp::Terms])

;; a frame is a list of bindings; `Fail` is a distinct outcome, not an absent frame
(:wat::core::defenum :sicp::Frame :wat::enum::Pure
  :FNil  []
  :FBind [name <- :wat::core::String  v <- :sicp::Term  rest <- :sicp::Frame])

(:wat::core::defenum :sicp::UF :wat::enum::Pure
  :Ok   [frame <- :sicp::Frame]
  :Fail [])

(:wat::core::defn :sicp::binding-of [name <- :wat::core::String f <- :sicp::Frame] -> (:wat::core::Option :- [:sicp::Term])
  (:wat::core::match f
    [:sicp::Frame.FNil {} (:wat::core::Option.None {})]
    [:sicp::Frame.FBind {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) (:wat::core::Option.Some {:value v})
        (:sicp::binding-of name rest))]))

;; follow a variable through the frame until it reaches something that is not a bound variable
(:wat::core::defn :sicp::lookup-val [t <- :sicp::Term f <- :sicp::Frame] -> :sicp::Term
  (:wat::core::match t
    [:sicp::Term.Var {:name name}
      (:wat::core::match (:sicp::binding-of name f)
        [:wat::core::Option.Some {:value v} (:sicp::lookup-val v f)]
        [:wat::core::Option.None {} t])]
    [:sicp::Term.Sym {:name name} t]
    [:sicp::Term.Num {:n n} t]
    [:sicp::Term.List {:xs xs} t]))

(:wat::core::defn :sicp::term=? [a <- :sicp::Term b <- :sicp::Term] -> :wat::core::bool
  (:wat::core::match a
    [:sicp::Term.Sym {:name an}
      (:wat::core::match b
        [:sicp::Term.Sym {:name bn} (:wat::core::= an bn)]
        [:sicp::Term.Num {:n bn} false]
        [:sicp::Term.Var {:name bn} false]
        [:sicp::Term.List {:xs bx} false])]
    [:sicp::Term.Num {:n an}
      (:wat::core::match b
        [:sicp::Term.Num {:n bn} (:wat::core::= an bn)]
        [:sicp::Term.Sym {:name bn} false]
        [:sicp::Term.Var {:name bn} false]
        [:sicp::Term.List {:xs bx} false])]
    [:sicp::Term.Var {:name an}
      (:wat::core::match b
        [:sicp::Term.Var {:name bn} (:wat::core::= an bn)]
        [:sicp::Term.Sym {:name bn} false]
        [:sicp::Term.Num {:n bn} false]
        [:sicp::Term.List {:xs bx} false])]
    [:sicp::Term.List {:xs ax}
      (:wat::core::match b
        [:sicp::Term.List {:xs bx} (:sicp::terms=? ax bx)]
        [:sicp::Term.Sym {:name bn} false]
        [:sicp::Term.Num {:n bn} false]
        [:sicp::Term.Var {:name bn} false])]))

(:wat::core::defn :sicp::terms=? [a <- :sicp::Terms b <- :sicp::Terms] -> :wat::core::bool
  (:wat::core::match a
    [:sicp::Terms.TNil {}
      (:wat::core::match b
        [:sicp::Terms.TNil {} true]
        [:sicp::Terms.TCons {:t t :rest r} false])]
    [:sicp::Terms.TCons {:t at :rest ar}
      (:wat::core::match b
        [:sicp::Terms.TCons {:t bt :rest br}
          (:wat::core::and (:sicp::term=? at bt) (:sicp::terms=? ar br))]
        [:sicp::Terms.TNil {} false])]))

(:wat::core::defn :sicp::var-name [t <- :sicp::Term] -> :wat::core::String
  (:wat::core::match t
    [:sicp::Term.Var {:name name} name]
    [:sicp::Term.Sym {:name name} ""]
    [:sicp::Term.Num {:n n} ""]
    [:sicp::Term.List {:xs xs} ""]))

(:wat::core::defn :sicp::var? [t <- :sicp::Term] -> :wat::core::bool
  (:wat::core::match t
    [:sicp::Term.Var {:name name} true]
    [:sicp::Term.Sym {:name name} false]
    [:sicp::Term.Num {:n n} false]
    [:sicp::Term.List {:xs xs} false]))

;; ---- unification
(:wat::core::defn :sicp::unify [p <- :sicp::Term d <- :sicp::Term uf <- :sicp::UF] -> :sicp::UF
  (:wat::core::match uf
    [:sicp::UF.Fail {} uf]
    [:sicp::UF.Ok {:frame f}
      (:wat::core::if (:sicp::term=? p d) uf
        (:wat::core::if (:sicp::var? p) (:sicp::unify-var p d f)
          (:wat::core::if (:sicp::var? d) (:sicp::unify-var d p f)
            (:wat::core::match p
              [:sicp::Term.List {:xs px}
                (:wat::core::match d
                  [:sicp::Term.List {:xs dx} (:sicp::unify-list px dx uf)]
                  [:sicp::Term.Sym {:name n} (:sicp::UF.Fail {})]
                  [:sicp::Term.Num {:n n} (:sicp::UF.Fail {})]
                  [:sicp::Term.Var {:name n} (:sicp::UF.Fail {})])]
              [:sicp::Term.Sym {:name n} (:sicp::UF.Fail {})]
              [:sicp::Term.Num {:n n} (:sicp::UF.Fail {})]
              [:sicp::Term.Var {:name n} (:sicp::UF.Fail {})]))))]))

(:wat::core::defn :sicp::unify-list [p <- :sicp::Terms d <- :sicp::Terms uf <- :sicp::UF] -> :sicp::UF
  (:wat::core::match p
    [:sicp::Terms.TNil {}
      (:wat::core::match d
        [:sicp::Terms.TNil {} uf]
        [:sicp::Terms.TCons {:t t :rest r} (:sicp::UF.Fail {})])]
    [:sicp::Terms.TCons {:t pt :rest pr}
      (:wat::core::match d
        [:sicp::Terms.TCons {:t dt :rest dr} (:sicp::unify-list pr dr (:sicp::unify pt dt uf))]
        [:sicp::Terms.TNil {} (:sicp::UF.Fail {})])]))

(:wat::core::defn :sicp::unify-var [v <- :sicp::Term val <- :sicp::Term f <- :sicp::Frame] -> :sicp::UF
  (:wat::core::match (:sicp::binding-of (:sicp::var-name v) f)
    [:wat::core::Option.Some {:value bound} (:sicp::unify bound val (:sicp::UF.Ok {:frame f}))]
    [:wat::core::Option.None {}
      (:wat::core::if (:sicp::var? val)
        (:wat::core::match (:sicp::binding-of (:sicp::var-name val) f)
          [:wat::core::Option.Some {:value b2} (:sicp::unify v b2 (:sicp::UF.Ok {:frame f}))]
          [:wat::core::Option.None {}
            (:sicp::UF.Ok {:frame (:sicp::Frame.FBind {:name (:sicp::var-name v) :v val :rest f})})])
        (:sicp::UF.Ok {:frame (:sicp::Frame.FBind {:name (:sicp::var-name v) :v val :rest f})}))]))

;; ---- the database
(:wat::core::defn :sicp::s [n <- :wat::core::String] -> :sicp::Term (:sicp::Term.Sym {:name n}))
(:wat::core::defn :sicp::vr [n <- :wat::core::String] -> :sicp::Term (:sicp::Term.Var {:name n}))

(:wat::core::defn :sicp::lst [xs <- (:wat::core::Vector :- [:sicp::Term])] -> :sicp::Term
  (:sicp::Term.List {:xs (:sicp::to-terms xs 0)}))

(:wat::core::defn :sicp::to-terms [xs <- (:wat::core::Vector :- [:sicp::Term]) i <- :wat::core::i64] -> :sicp::Terms
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) (:sicp::Terms.TNil {})
    (:sicp::Terms.TCons {:t (:wat::core::nth xs i) :rest (:sicp::to-terms xs (:wat::core::+ i 1))})))

(:wat::core::defn :sicp::name2 [a <- :wat::core::String b <- :wat::core::String] -> :sicp::Term
  (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s a) (:sicp::s b))))

(:wat::core::defn :sicp::name3 [a <- :wat::core::String b <- :wat::core::String c <- :wat::core::String] -> :sicp::Term
  (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s a) (:sicp::s b) (:sicp::s c))))

(:wat::core::defn :sicp::fact3 [p <- :wat::core::String a <- :sicp::Term b <- :sicp::Term] -> :sicp::Term
  (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s p) a b)))

(:wat::core::defn :sicp::facts [] -> (:wat::core::Vector :- [:sicp::Term])
  (:wat::core::Vector :- [:sicp::Term]
    (:sicp::fact3 "job" (:sicp::name2 "Bitdiddle" "Ben") (:sicp::name2 "computer" "wizard"))
    (:sicp::fact3 "job" (:sicp::name3 "Hacker" "Alyssa" "P") (:sicp::name2 "computer" "programmer"))
    (:sicp::fact3 "job" (:sicp::name3 "Fect" "Cy" "D") (:sicp::name2 "computer" "programmer"))
    (:sicp::fact3 "job" (:sicp::name3 "Tweakit" "Lem" "E") (:sicp::name2 "computer" "technician"))
    (:sicp::fact3 "job" (:sicp::name2 "Reasoner" "Louis") (:sicp::name3 "computer" "programmer" "trainee"))
    (:sicp::fact3 "salary" (:sicp::name2 "Bitdiddle" "Ben") (:sicp::Term.Num {:n 60000}))
    (:sicp::fact3 "salary" (:sicp::name3 "Hacker" "Alyssa" "P") (:sicp::Term.Num {:n 40000}))
    (:sicp::fact3 "salary" (:sicp::name3 "Fect" "Cy" "D") (:sicp::Term.Num {:n 35000}))
    (:sicp::fact3 "supervisor" (:sicp::name3 "Hacker" "Alyssa" "P") (:sicp::name2 "Bitdiddle" "Ben"))
    (:sicp::fact3 "supervisor" (:sicp::name3 "Fect" "Cy" "D") (:sicp::name2 "Bitdiddle" "Ben"))
    (:sicp::fact3 "supervisor" (:sicp::name3 "Tweakit" "Lem" "E") (:sicp::name2 "Bitdiddle" "Ben"))))

;; every frame in which the pattern matches some fact
(:wat::core::defn :sicp::match-pattern
  [pattern <- :sicp::Term i <- :wat::core::i64 acc <- (:wat::core::Vector :- [:sicp::Frame])]
  -> (:wat::core::Vector :- [:sicp::Frame])
  (:wat::core::let [fs (:sicp::facts)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length fs)) acc
      (:wat::core::match (:sicp::unify pattern (:wat::core::nth fs i) (:sicp::UF.Ok {:frame (:sicp::Frame.FNil {})}))
        [:sicp::UF.Ok {:frame f} (:sicp::match-pattern pattern (:wat::core::+ i 1) (:wat::core::conj acc f))]
        [:sicp::UF.Fail {} (:sicp::match-pattern pattern (:wat::core::+ i 1) acc)]))))

(:wat::core::defn :sicp::query [pattern <- :sicp::Term] -> (:wat::core::Vector :- [:sicp::Frame])
  (:sicp::match-pattern pattern 0 (:wat::core::Vector :- [:sicp::Frame])))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::show-term [t <- :sicp::Term] -> :wat::core::String
  (:wat::core::match t
    [:sicp::Term.Sym {:name n} n]
    [:sicp::Term.Num {:n n} (:wat::i64::to-string n)]
    [:sicp::Term.Var {:name n} n]
    [:sicp::Term.List {:xs xs} (:wat::string::concat "(" (:sicp::show-terms xs) ")")]))

(:wat::core::defn :sicp::show-terms [ts <- :sicp::Terms] -> :wat::core::String
  (:wat::core::match ts
    [:sicp::Terms.TNil {} ""]
    [:sicp::Terms.TCons {:t t :rest rest}
      (:wat::core::match rest
        [:sicp::Terms.TNil {} (:sicp::show-term t)]
        [:sicp::Terms.TCons {:t t2 :rest r2}
          (:wat::string::concat (:sicp::show-term t) " " (:sicp::show-terms rest))])]))

(:wat::core::defn :sicp::values-of [v <- :wat::core::String frames <- (:wat::core::Vector :- [:sicp::Frame])] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " "
      (:wat::core::mapv (:wat::core::fn [f <- :sicp::Frame] -> :wat::core::String
                          (:sicp::show-term (:sicp::lookup-val (:sicp::vr v) f))) frames)) ")"))

(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::failed? [uf <- :sicp::UF] -> :wat::core::bool
  (:wat::core::match uf
    [:sicp::UF.Fail {} true]
    [:sicp::UF.Ok {:frame f} false]))

(:wat::core::defn :sicp::frame-of [uf <- :sicp::UF] -> :sicp::Frame
  (:wat::core::match uf
    [:sicp::UF.Ok {:frame f} f]
    [:sicp::UF.Fail {} (:sicp::Frame.FNil {})]))

(:wat::core::defn :sicp::empty-uf [] -> :sicp::UF (:sicp::UF.Ok {:frame (:sicp::Frame.FNil {})}))

;; the first word of a person's job title, read back out of the first answering frame
(:wat::core::defn :sicp::division-of [person <- :sicp::Term] -> :wat::core::String
  (:wat::core::let [r (:sicp::query (:sicp::fact3 "job" person (:sicp::vr "?title")))]
    (:wat::core::if (:wat::core::empty? r) "none"
      (:wat::core::match (:sicp::lookup-val (:sicp::vr "?title") (:wat::core::nth r 0))
        [:sicp::Term.List {:xs xs}
          (:wat::core::match xs
            [:sicp::Terms.TCons {:t t :rest rest} (:sicp::show-term t)]
            [:sicp::Terms.TNil {} "none"])]
        [:sicp::Term.Sym {:name n} n]
        [:sicp::Term.Num {:n n} "none"]
        [:sicp::Term.Var {:name n} "none"]))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    ben (:sicp::name2 "Bitdiddle" "Ben")
                    alyssa (:sicp::name3 "Hacker" "Alyssa" "P")
                    cy (:sicp::name3 "Fect" "Cy" "D")
                    louis (:sicp::name2 "Reasoner" "Louis")
                    ;; (?x ?y) against (1 2)
                    xy (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::vr "?x") (:sicp::vr "?y")))
                    one2 (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::Term.Num {:n 1}) (:sicp::Term.Num {:n 2})))
                    xx (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::vr "?x") (:sicp::vr "?x")))
                    one1 (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::Term.Num {:n 1}) (:sicp::Term.Num {:n 1})))
                    fx (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s "f") (:sicp::vr "?x")))
                    fgy (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s "f")
                          (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s "g") (:sicp::vr "?y")))))
                    gx (:sicp::lst (:wat::core::Vector :- [:sicp::Term] (:sicp::s "g") (:sicp::vr "?x")))]
    (:sicp::check-chapter "oracle/sicp/ch44-logic-programming.expected"
                          "sicp ch44 logic programming"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:wat::core::length (:sicp::facts)))
                            (int (:wat::core::length (:sicp::query (:sicp::fact3 "job" (:sicp::vr "?person") (:sicp::vr "?title")))))
                            ;; ask WHO
                            (:sicp::values-of "?person"
                              (:sicp::query (:sicp::fact3 "job" (:sicp::vr "?person") (:sicp::name2 "computer" "programmer"))))
                            ;; ask WHAT, from the same fact shape
                            (:sicp::values-of "?title" (:sicp::query (:sicp::fact3 "job" ben (:sicp::vr "?title"))))
                            ;; every job whose title starts with `computer` -- five of five
                            (int (:wat::core::length (:sicp::query (:sicp::fact3 "job" (:sicp::vr "?p") (:sicp::vr "?t")))))
                            (:sicp::values-of "?who" (:sicp::query (:sicp::fact3 "supervisor" (:sicp::vr "?who") ben)))
                            (:sicp::values-of "?amount" (:sicp::query (:sicp::fact3 "salary" alyssa (:sicp::vr "?amount"))))
                            (:sicp::values-of "?title" (:sicp::query (:sicp::fact3 "job" (:sicp::name2 "Nobody" "Here") (:sicp::vr "?title"))))
                            ;; unification proper
                            (:sicp::show-term (:sicp::lookup-val (:sicp::vr "?x") (:sicp::frame-of (:sicp::unify xy one2 (:sicp::empty-uf)))))
                            (:sicp::show-term (:sicp::lookup-val (:sicp::vr "?y") (:sicp::frame-of (:sicp::unify xy one2 (:sicp::empty-uf)))))
                            (:sicp::b (:sicp::failed? (:sicp::unify xx one1 (:sicp::empty-uf))))
                            (:sicp::b (:sicp::failed? (:sicp::unify xx one2 (:sicp::empty-uf))))
                            (:sicp::show-term (:sicp::lookup-val (:sicp::vr "?x") (:sicp::frame-of (:sicp::unify fx fgy (:sicp::empty-uf)))))
                            (:sicp::b (:sicp::failed? (:sicp::unify fx gx (:sicp::empty-uf))))
                            (:sicp::division-of ben)
                            (:sicp::division-of louis)
                            (:sicp::b (:wat::core::= (:sicp::division-of ben) (:sicp::division-of cy)))))))
