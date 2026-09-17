;; PAIP chapter 8 (symbolic mathematics: a simplification program), in wat.
;;
;; A simplifier driven by a TABLE OF REWRITE RULES rather than by hand-written cases, applied to a
;; fixed point. The contrast worth drawing is with SICP §2.3 (C-078), which this repository already
;; has: there, differentiation is a procedure with one clause per operator, and the compiler checks
;; that every operator is handled. Here the rules are DATA -- `(+ ?x 0) => ?x` is a pair of
;; patterns -- and adding an identity means adding a row rather than editing a function.
;;
;; The two answers agree and are spelled differently, which is the nicest possible illustration of
;; the difference. On `d(x·y · (x+3))/dx`:
;;
;;     SICP §2.3, hand-coded    (+ (* x y) (* y (+ x 3)))
;;     PAIP ch8, rule-driven    (+ (* x y) (* (+ x 3) y))
;;
;; Same expression, different factor order, because the rule's right-hand side fixes the order and
;; the hand-written constructor fixed a different one. Neither is wrong; the table just does not
;; know it should prefer one.
;;
;; **What the rule table costs in a typed language, and it is the finding here:** two of the rules
;; SICP expresses directly cannot be written as patterns at all. `d(c)/dx = 0` needs "?c is a
;; NUMBER", and `d(y)/dx = 0` needs "?y is a symbol OTHER THAN ?x" -- both are side conditions, not
;; shapes, so both live outside the table as ordinary functions. PAIP hits this too and handles it
;; the same way. The table is open to new rows and closed to new KINDS of question, which is the
;; same trade C-078 recorded for SICP §2.5's dispatch table from the other direction.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch08-symbolic-math.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch08-symbolic-math.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :paip::Ex :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Sym  [name <- :wat::core::String]
  :PVar [name <- :wat::core::String]
  :App  [op <- :wat::core::String  args <- (:wat::core::Vector :- [:paip::Ex])])

(:wat::core::typealias :paip::Exs (:wat::core::Vector :- [:paip::Ex]))

(:wat::core::defenum :paip::EB :wat::enum::Pure
  :BNil  []
  :BCons [name <- :wat::core::String  v <- :paip::Ex  rest <- :paip::EB])

(:wat::core::defenum :paip::EM :wat::enum::Pure
  :Ok   [b <- :paip::EB]
  :Fail [])

;; ---- structural equality and printing
(:wat::core::defn :paip::show [e <- :paip::Ex] -> :wat::core::String
  (:wat::core::match e
    [:paip::Ex.Num {:n n} (:wat::i64::to-string n)]
    [:paip::Ex.Sym {:name n} n]
    [:paip::Ex.PVar {:name n} (:wat::string::concat "?" n)]
    [:paip::Ex.App {:op op :args args}
      (:wat::string::concat "(" op " "
        (:wat::string::join " " (:wat::core::mapv :paip::show args)) ")")]))

(:wat::core::defn :paip::eq? [a <- :paip::Ex b <- :paip::Ex] -> :wat::core::bool
  (:wat::core::= (:paip::show a) (:paip::show b)))

(:wat::core::defn :paip::lookup [name <- :wat::core::String b <- :paip::EB] -> (:wat::core::Option :- [:paip::Ex])
  (:wat::core::match b
    [:paip::EB.BNil {} (:wat::core::Option.None {})]
    [:paip::EB.BCons {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) (:wat::core::Option.Some {:value v}) (:paip::lookup name rest))]))

;; ---- matching a rule's left-hand side against an expression
(:wat::core::defn :paip::pat-match [p <- :paip::Ex e <- :paip::Ex b <- :paip::EB] -> :paip::EM
  (:wat::core::match p
    [:paip::Ex.PVar {:name n}
      (:wat::core::match (:paip::lookup n b)
        [:wat::core::Option.Some {:value old}
          (:wat::core::if (:paip::eq? old e) (:paip::EM.Ok {:b b}) (:paip::EM.Fail {}))]
        [:wat::core::Option.None {} (:paip::EM.Ok {:b (:paip::EB.BCons {:name n :v e :rest b})})])]
    [:paip::Ex.Num {:n n}
      (:wat::core::if (:paip::eq? p e) (:paip::EM.Ok {:b b}) (:paip::EM.Fail {}))]
    [:paip::Ex.Sym {:name n}
      (:wat::core::if (:paip::eq? p e) (:paip::EM.Ok {:b b}) (:paip::EM.Fail {}))]
    [:paip::Ex.App {:op pop :args pargs}
      (:wat::core::match e
        [:paip::Ex.App {:op eop :args eargs}
          (:wat::core::if (:wat::core::or (:wat::core::not (:wat::core::= pop eop))
                            (:wat::core::not (:wat::core::= (:wat::core::length pargs) (:wat::core::length eargs))))
            (:paip::EM.Fail {})
            (:paip::match-args pargs eargs 0 b))]
        [:paip::Ex.Num {:n n} (:paip::EM.Fail {})]
        [:paip::Ex.Sym {:name n} (:paip::EM.Fail {})]
        [:paip::Ex.PVar {:name n} (:paip::EM.Fail {})])]))

(:wat::core::defn :paip::match-args [ps <- :paip::Exs es <- :paip::Exs i <- :wat::core::i64 b <- :paip::EB] -> :paip::EM
  (:wat::core::if (:wat::core::>= i (:wat::core::length ps)) (:paip::EM.Ok {:b b})
    (:wat::core::match (:paip::pat-match (:wat::core::nth ps i) (:wat::core::nth es i) b)
      [:paip::EM.Fail {} (:paip::EM.Fail {})]
      [:paip::EM.Ok {:b b2} (:paip::match-args ps es (:wat::core::+ i 1) b2)])))

(:wat::core::defn :paip::subst [b <- :paip::EB x <- :paip::Ex] -> :paip::Ex
  (:wat::core::match x
    [:paip::Ex.PVar {:name n}
      (:wat::core::match (:paip::lookup n b)
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} x])]
    [:paip::Ex.Num {:n n} x]
    [:paip::Ex.Sym {:name n} x]
    [:paip::Ex.App {:op op :args args}
      (:paip::Ex.App {:op op :args (:wat::core::mapv (:wat::core::fn [a <- :paip::Ex] -> :paip::Ex
                                                       (:paip::subst b a)) args)})]))

;; ---- the rule table
(:wat::core::defstruct :paip::RRule [lhs <- :paip::Ex  rhs <- :paip::Ex])

(:wat::core::defn :paip::pv [n <- :wat::core::String] -> :paip::Ex (:paip::Ex.PVar {:name n}))
(:wat::core::defn :paip::sy [n <- :wat::core::String] -> :paip::Ex (:paip::Ex.Sym {:name n}))
(:wat::core::defn :paip::nu [n <- :wat::core::i64] -> :paip::Ex (:paip::Ex.Num {:n n}))
(:wat::core::defn :paip::ap2 [op <- :wat::core::String a <- :paip::Ex b <- :paip::Ex] -> :paip::Ex
  (:paip::Ex.App {:op op :args (:wat::core::Vector :- [:paip::Ex] a b)}))

(:wat::core::defn :paip::rules [] -> (:wat::core::Vector :- [:paip::RRule])
  (:wat::core::let [x (:paip::pv "x") u (:paip::pv "u") v (:paip::pv "v") z (:paip::pv "z")]
    (:wat::core::Vector :- [:paip::RRule]
      (:paip::RRule :lhs (:paip::ap2 "+" x (:paip::nu 0)) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "+" (:paip::nu 0) x) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "*" x (:paip::nu 1)) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "*" (:paip::nu 1) x) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "*" x (:paip::nu 0)) :rhs (:paip::nu 0))
      (:paip::RRule :lhs (:paip::ap2 "*" (:paip::nu 0) x) :rhs (:paip::nu 0))
      (:paip::RRule :lhs (:paip::ap2 "-" x (:paip::nu 0)) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "-" x x) :rhs (:paip::nu 0))
      (:paip::RRule :lhs (:paip::ap2 "/" x (:paip::nu 1)) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "/" x x) :rhs (:paip::nu 1))
      (:paip::RRule :lhs (:paip::ap2 "^" x (:paip::nu 1)) :rhs x)
      (:paip::RRule :lhs (:paip::ap2 "^" x (:paip::nu 0)) :rhs (:paip::nu 1))
      (:paip::RRule :lhs (:paip::ap2 "d" x x) :rhs (:paip::nu 1))
      (:paip::RRule :lhs (:paip::ap2 "d" (:paip::ap2 "+" u v) z)
                    :rhs (:paip::ap2 "+" (:paip::ap2 "d" u z) (:paip::ap2 "d" v z)))
      (:paip::RRule :lhs (:paip::ap2 "d" (:paip::ap2 "-" u v) z)
                    :rhs (:paip::ap2 "-" (:paip::ap2 "d" u z) (:paip::ap2 "d" v z)))
      (:paip::RRule :lhs (:paip::ap2 "d" (:paip::ap2 "*" u v) z)
                    :rhs (:paip::ap2 "+" (:paip::ap2 "*" u (:paip::ap2 "d" v z))
                                         (:paip::ap2 "*" v (:paip::ap2 "d" u z)))))))

;; ---- the two rules that are NOT patterns: they ask about a term's KIND, not its shape
(:wat::core::defn :paip::num? [e <- :paip::Ex] -> :wat::core::bool
  (:wat::core::match e
    [:paip::Ex.Num {:n n} true]
    [:paip::Ex.Sym {:name n} false]
    [:paip::Ex.PVar {:name n} false]
    [:paip::Ex.App {:op op :args args} false]))

(:wat::core::defn :paip::sym? [e <- :paip::Ex] -> :wat::core::bool
  (:wat::core::match e
    [:paip::Ex.Sym {:name n} true]
    [:paip::Ex.Num {:n n} false]
    [:paip::Ex.PVar {:name n} false]
    [:paip::Ex.App {:op op :args args} false]))

(:wat::core::defn :paip::side-conditions [e <- :paip::Ex] -> (:wat::core::Option :- [:paip::Ex])
  (:wat::core::match e
    [:paip::Ex.App {:op op :args args}
      (:wat::core::if (:wat::core::and (:wat::core::= op "d") (:wat::core::= (:wat::core::length args) 2))
        (:wat::core::let [a (:wat::core::nth args 0) b (:wat::core::nth args 1)]
          ;; d(c)/dx = 0 for a literal, and d(y)/dx = 0 for a DIFFERENT symbol
          (:wat::core::if (:paip::num? a) (:wat::core::Option.Some {:value (:paip::nu 0)})
            (:wat::core::if (:wat::core::and (:paip::sym? a) (:wat::core::not (:paip::eq? a b)))
              (:wat::core::Option.Some {:value (:paip::nu 0)})
              (:wat::core::Option.None {}))))
        (:wat::core::Option.None {}))]
    [:paip::Ex.Num {:n n} (:wat::core::Option.None {})]
    [:paip::Ex.Sym {:name n} (:wat::core::Option.None {})]
    [:paip::Ex.PVar {:name n} (:wat::core::Option.None {})]))

(:wat::core::defn :paip::apply-rules-from [e <- :paip::Ex i <- :wat::core::i64] -> :paip::Ex
  (:wat::core::let [rs (:paip::rules)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length rs)) e
      (:wat::core::let [r (:wat::core::nth rs i)]
        (:wat::core::match (:paip::pat-match (:paip::RRule/lhs r) e (:paip::EB.BNil {}))
          [:paip::EM.Fail {} (:paip::apply-rules-from e (:wat::core::+ i 1))]
          [:paip::EM.Ok {:b b} (:paip::subst b (:paip::RRule/rhs r))])))))

(:wat::core::defn :paip::apply-rules [e <- :paip::Ex] -> :paip::Ex
  (:wat::core::match (:paip::side-conditions e)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {} (:paip::apply-rules-from e 0)]))

;; fold arithmetic on literal numbers, so (+ 2 3) becomes 5
(:wat::core::defn :paip::fold [e <- :paip::Ex] -> :paip::Ex
  (:wat::core::match e
    [:paip::Ex.App {:op op :args args}
      (:wat::core::if (:wat::core::not (:wat::core::= (:wat::core::length args) 2)) e
        (:wat::core::let [a (:wat::core::nth args 0) b (:wat::core::nth args 1)]
          (:wat::core::if (:wat::core::not (:wat::core::and (:paip::num? a) (:paip::num? b))) e
            (:wat::core::let [x (:paip::num-of a) y (:paip::num-of b)]
              (:wat::core::if (:wat::core::= op "+") (:paip::nu (:wat::core::+ x y))
                (:wat::core::if (:wat::core::= op "-") (:paip::nu (:wat::core::- x y))
                  (:wat::core::if (:wat::core::= op "*") (:paip::nu (:wat::core::* x y)) e)))))))]
    [:paip::Ex.Num {:n n} e]
    [:paip::Ex.Sym {:name n} e]
    [:paip::Ex.PVar {:name n} e]))

(:wat::core::defn :paip::num-of [e <- :paip::Ex] -> :wat::core::i64
  (:wat::core::match e
    [:paip::Ex.Num {:n n} n]
    [:paip::Ex.Sym {:name n} 0]
    [:paip::Ex.PVar {:name n} 0]
    [:paip::Ex.App {:op op :args args} 0]))

;; simplify the arguments first, then the whole -- and repeat until nothing changes
(:wat::core::defn :paip::simplify-once [e <- :paip::Ex] -> :paip::Ex
  (:wat::core::match e
    [:paip::Ex.App {:op op :args args}
      (:paip::fold (:paip::apply-rules
        (:paip::Ex.App {:op op :args (:wat::core::mapv :paip::simplify-once args)})))]
    [:paip::Ex.Num {:n n} e]
    [:paip::Ex.Sym {:name n} e]
    [:paip::Ex.PVar {:name n} e]))

(:wat::core::defn :paip::simplify [e <- :paip::Ex] -> :paip::Ex
  (:wat::core::let [s (:paip::simplify-once e)]
    (:wat::core::if (:paip::eq? s e) e (:paip::simplify s))))

(:wat::core::defn :paip::ss [e <- :paip::Ex] -> :wat::core::String (:paip::show (:paip::simplify e)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [x (:paip::sy "x") y (:paip::sy "y")]
    (:paip::check-chapter "oracle/paip/ch08-symbolic-math.expected"
                          "paip ch08 symbolic math"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::ss (:paip::ap2 "+" x (:paip::nu 0)))
                            (:paip::ss (:paip::ap2 "*" x (:paip::nu 1)))
                            (:paip::ss (:paip::ap2 "*" x (:paip::nu 0)))
                            (:paip::ss (:paip::ap2 "-" x x))
                            (:paip::ss (:paip::ap2 "/" x x))
                            (:paip::ss (:paip::ap2 "^" x (:paip::nu 1)))
                            (:paip::ss (:paip::ap2 "+" (:paip::ap2 "*" x (:paip::nu 0))
                                                       (:paip::ap2 "*" (:paip::nu 1) y)))
                            (:paip::ss (:paip::ap2 "+" (:paip::nu 2) (:paip::nu 3)))
                            (:paip::ss (:paip::ap2 "*" (:paip::ap2 "+" (:paip::nu 2) (:paip::nu 3))
                                                       (:paip::ap2 "^" x (:paip::nu 0))))
                            (:paip::ss (:paip::ap2 "+" (:paip::ap2 "*" (:paip::nu 1) x)
                                                       (:paip::ap2 "*" (:paip::nu 0) y)))
                            (:paip::ss (:paip::ap2 "d" x x))
                            (:paip::ss (:paip::ap2 "d" (:paip::nu 5) x))
                            (:paip::ss (:paip::ap2 "d" y x))
                            (:paip::ss (:paip::ap2 "d" (:paip::ap2 "+" x (:paip::nu 5)) x))
                            (:paip::ss (:paip::ap2 "d" (:paip::ap2 "*" x y) x))
                            (:paip::ss (:paip::ap2 "d" (:paip::ap2 "*" x x) x))
                            (:paip::ss (:paip::ap2 "d" (:paip::ap2 "+" (:paip::ap2 "*" x y) (:paip::nu 3)) x))
                            ;; the same expression SICP §2.3 differentiates by hand (C-078)
                            (:paip::ss (:paip::ap2 "d" (:paip::ap2 "*" (:paip::ap2 "*" x y)
                                                                       (:paip::ap2 "+" x (:paip::nu 3))) x))))))
