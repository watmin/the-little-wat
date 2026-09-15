;; books/little-typer/lib/pie.wat: wat-Pie, our own checker and evaluator for Pie, the
;; language of The Little Typer. It uses normalization by evaluation with bidirectional,
;; elaborating type checking, the published technique Pie itself is built on. Racket's Pie
;; is AGPL-3.0; it is run as the oracle (tools/pie-oracle.sh) and never read into this.
;;
;; The language so far: U, Atom, 'atoms, Nat, zero, add1, numerals, Pair and Sigma, cons,
;; car, cdr, -> and Pi, lambda, application, the, which-Nat, iter-Nat, rec-Nat, List, nil,
;; ::, rec-List, Vec, vecnil, vec::, head, tail, ind-Nat, claim, define, check-same.
;;
;; Everything is an S-expression (:wat::WatAST), as in the J-Bob port:
;; - values:   (VU) (VAtom) (VNat) (VZero) (VAdd1 v) (VQuote x)
;;             (VPi x dom clos) (VSigma x car-type clos) (VLam x clos) (VCons a d)
;;             (VList elem-type) (VNil) (VLCons e es)
;;             (VVec elem-type length) (VVecNil) (VVecCons e es) (VNeu type neutral)
;; - closures: (CLOS env x body): an environment, a variable, and a body in core form
;; - neutrals: (NVar x) (NApp neutral arg-type arg) (NCar neutral) (NCdr neutral)
;;             (NNat ELIM target base-type base step), ELIM being which-Nat, iter-Nat or rec-Nat
;;             (NRecList target elem-type base-type base step) (NHead neutral) (NTail neutral)
;;             (NIndNat target motive base step)
;; - an environment is a list of (name value); a context a list of (name kind type [value]),
;;   kind being claim, def or var.
;; Checking elaborates: synth gives (TYPE CORE) and check gives CORE. Core is the source with
;; each eliminator's base annotated by its type, (which-Nat t (the X b) s), as Pie's core is,
;; so a stuck eliminator knows its type. Evaluation runs on core.
;; Reading back gives raw terms (one binder per Pi, Sigma and lambda), compared by
;; alpha-equivalence. A separate pass resugars them for printing, the way Pie prints.
;;
;; Needs ../little-schemer/lib/ch01-toys.wat and ch04-numbers-games.wat (:ls::ast->i64).

;; ---- S-expressions

(:wat::core::typealias :pie::Es (:wat::core::Vector :- [:wat::WatAST]))
(:wat::core::typealias :pie::Names (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :pie::fail :- [T] [msg <- :wat::core::String] -> :T
  (:wat::kernel::assertion-failed! :message (:wat::string::concat "wat-Pie: " msg)))

(:wat::core::defn :pie::mk [kids <- :pie::Es] -> :wat::WatAST
  (:wat::core::with-children (:wat::core::quote (t)) kids))

(:wat::core::defn :pie::sym [name <- :wat::core::String] -> :wat::WatAST
  (:wat::core::symbol-node name))

(:wat::core::defn :pie::kids [e <- :wat::WatAST] -> :pie::Es
  (:wat::core::ast->children e))

(:wat::core::defn :pie::list? [e <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::= (:wat::core::ast-kind e) "list"))

;; A symbol's name. wat's reader turns a nested 'x into a keyword-headed quote, reads Pie's
;; :: as a keyword and nil as its own nil literal; each gets its Pie name here.
(:wat::core::defn :pie::name-of [e <- :wat::WatAST] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= (:wat::core::ast-kind e) "symbol") (:wat::core::ast-name e))
    ((:wat::core::= (:wat::core::ast-kind e) "keyword")
      (:wat::core::if (:wat::core::= (:wat::core::ast->source e) ":wat::core::quote") "quote" (:wat::core::ast->source e)))
    ((:wat::core::= (:wat::core::ast-kind e) "nil") "nil")
    (:else "")))

(:wat::core::defn :pie::head [e <- :wat::WatAST] -> :wat::core::String
  (:wat::core::if (:pie::list? e)
    (:wat::core::let [ks (:pie::kids e)]
      (:wat::core::if (:wat::core::empty? ks) "" (:pie::name-of (:wat::core::first ks))))
    ""))

(:wat::core::defn :pie::nth [xs <- :pie::Es i <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= i 0) (:wat::core::first xs) (:pie::nth (:wat::core::rest xs) (:wat::core::- i 1))))

;; The i-th argument of a form, after its head.
(:wat::core::defn :pie::arg [e <- :wat::WatAST i <- :wat::core::i64] -> :wat::WatAST
  (:pie::nth (:pie::kids e) (:wat::core::+ i 1)))

(:wat::core::defn :pie::args [e <- :wat::WatAST] -> :pie::Es
  (:wat::core::rest (:pie::kids e)))

(:wat::core::defn :pie::tag? [v <- :wat::WatAST tag <- :wat::core::String] -> :wat::core::bool
  (:wat::core::= (:pie::head v) tag))

(:wat::core::defn :pie::t0 [tag <- :wat::core::String] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym tag))))
(:wat::core::defn :pie::t1 [tag <- :wat::core::String a <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym tag) a)))
(:wat::core::defn :pie::t2 [tag <- :wat::core::String a <- :wat::WatAST b <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym tag) a b)))
(:wat::core::defn :pie::t3 [tag <- :wat::core::String a <- :wat::WatAST b <- :wat::WatAST c <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym tag) a b c)))
(:wat::core::defn :pie::t4 [tag <- :wat::core::String a <- :wat::WatAST b <- :wat::WatAST c <- :wat::WatAST d <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym tag) a b c d)))

(:wat::core::defn :pie::int-node [n <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::quasiquote ~n))

(:wat::core::defn :pie::member? [xs <- :pie::Names x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? xs)
    false
    (:wat::core::if (:wat::core::= (:wat::core::first xs) x) true (:pie::member? (:wat::core::rest xs) x))))

;; ---- environments and closures

(:wat::core::defn :pie::bind [env <- :wat::WatAST x <- :wat::core::String v <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) v)))
                                (:pie::kids env))))

(:wat::core::defn :pie::lookup [bs <- :pie::Es x <- :wat::core::String] -> (:wat::core::Option :- [:wat::WatAST])
  (:wat::core::if (:wat::core::empty? bs)
    :wat::core::Option.None
    (:wat::core::let [b (:pie::kids (:wat::core::first bs))]
      (:wat::core::if (:wat::core::= (:pie::name-of (:wat::core::first b)) x)
        (:wat::core::Option.Some {:value (:pie::nth b 1)})
        (:pie::lookup (:wat::core::rest bs) x)))))

(:wat::core::defn :pie::clos [env <- :wat::WatAST x <- :wat::core::String body <- :wat::WatAST] -> :wat::WatAST
  (:pie::t3 "CLOS" env (:pie::sym x) body))

;; Run a closure's body with its variable bound to v.
(:wat::core::defn :pie::inst [c <- :wat::WatAST v <- :wat::WatAST] -> :wat::WatAST
  (:pie::eval (:pie::bind (:pie::arg c 0) (:pie::name-of (:pie::arg c 1)) v) (:pie::arg c 2)))

;; The value (-> dom cod) for types already values: the closure returns cod whatever its
;; argument, through a private environment name.
(:wat::core::defn :pie::arrow-value [dom <- :wat::WatAST cod <- :wat::WatAST] -> :wat::WatAST
  (:pie::t3 "VPi" (:pie::sym "_") dom
            (:pie::clos (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "%cod") cod))))
                        "_" (:pie::sym "%cod"))))

;; ---- evaluation (of core)

(:wat::core::defn :pie::numeral [n <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= n 0) (:pie::t0 "VZero") (:pie::t1 "VAdd1" (:pie::numeral (:wat::core::- n 1)))))

(:wat::core::defn :pie::eval [env <- :wat::WatAST e <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [k (:wat::core::ast-kind e)]
    (:wat::core::cond
      ((:wat::core::= k "int") (:pie::numeral (:ls::ast->i64 e)))
      ((:wat::core::= k "nil") (:pie::t0 "VNil"))
      ((:wat::core::= k "symbol") (:pie::eval-var env (:wat::core::ast-name e)))
      ((:pie::list? e) (:pie::eval-form env e (:pie::head e)))
      (:else (:pie::fail (:wat::string::concat "cannot evaluate " (:wat::core::ast->source e)))))))

(:wat::core::defn :pie::eval-var [env <- :wat::WatAST name <- :wat::core::String] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= name "U") (:pie::t0 "VU"))
    ((:wat::core::= name "Atom") (:pie::t0 "VAtom"))
    ((:wat::core::= name "Nat") (:pie::t0 "VNat"))
    ((:wat::core::= name "zero") (:pie::t0 "VZero"))
    ((:wat::core::= name "vecnil") (:pie::t0 "VVecNil"))
    (:else
      (:wat::core::match (:pie::lookup (:pie::kids env) name)
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} (:pie::fail (:wat::string::concat "unbound variable " name))]))))

(:wat::core::defn :pie::eval-form [env <- :wat::WatAST e <- :wat::WatAST h <- :wat::core::String] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= h "quote") (:pie::t1 "VQuote" (:pie::arg e 0)))
    ((:wat::core::= h "add1") (:pie::t1 "VAdd1" (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "the") (:pie::eval env (:pie::arg e 1)))
    ((:wat::core::= h "Pair") (:pie::t3 "VSigma" (:pie::sym "_") (:pie::eval env (:pie::arg e 0)) (:pie::clos env "_" (:pie::arg e 1))))
    ((:wat::core::= h "->") (:pie::eval-arrow env (:pie::args e)))
    ((:wat::core::= h "Pi") (:pie::eval-binder env "VPi" "Pi" (:pie::kids (:pie::arg e 0)) (:pie::arg e 1)))
    ((:wat::core::= h "Sigma") (:pie::eval-binder env "VSigma" "Sigma" (:pie::kids (:pie::arg e 0)) (:pie::arg e 1)))
    ((:wat::core::= h "lambda") (:pie::eval-lambda env (:pie::kids (:pie::arg e 0)) (:pie::arg e 1)))
    ((:wat::core::= h "cons") (:pie::t2 "VCons" (:pie::eval env (:pie::arg e 0)) (:pie::eval env (:pie::arg e 1))))
    ((:wat::core::= h "car") (:pie::do-car (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "cdr") (:pie::do-cdr (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "ind-Nat")
      (:pie::do-ind-nat (:pie::eval env (:pie::arg e 0)) (:pie::eval env (:pie::arg e 1))
                        (:pie::eval env (:pie::arg e 2)) (:pie::eval env (:pie::arg e 3))))
    ((:wat::core::= h "Vec") (:pie::t2 "VVec" (:pie::eval env (:pie::arg e 0)) (:pie::eval env (:pie::arg e 1))))
    ((:wat::core::= h "vec::") (:pie::t2 "VVecCons" (:pie::eval env (:pie::arg e 0)) (:pie::eval env (:pie::arg e 1))))
    ((:wat::core::= h "head") (:pie::do-head (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "tail") (:pie::do-tail (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "List") (:pie::t1 "VList" (:pie::eval env (:pie::arg e 0))))
    ((:wat::core::= h "::") (:pie::t2 "VLCons" (:pie::eval env (:pie::arg e 0)) (:pie::eval env (:pie::arg e 1))))
    ((:wat::core::= h "rec-List")
      (:wat::core::let [base (:pie::arg e 1)]
        (:pie::do-rec-list (:pie::eval env (:pie::arg e 0))
                           (:pie::eval env (:pie::arg base 0))
                           (:pie::eval env (:pie::arg base 1))
                           (:pie::eval env (:pie::arg e 2)))))
    ((:pie::nat-elim? h)
      (:wat::core::let [base (:pie::arg e 1)]
        (:pie::do-nat-elim h
                           (:pie::eval env (:pie::arg e 0))
                           (:pie::eval env (:pie::arg base 0))
                           (:pie::eval env (:pie::arg base 1))
                           (:pie::eval env (:pie::arg e 2)))))
    (:else (:pie::eval-app env (:pie::eval env (:wat::core::first (:pie::kids e))) (:pie::args e)))))

;; (-> A B C) is (Pi ((_ A)) (-> B C)).
(:wat::core::defn :pie::eval-arrow [env <- :wat::WatAST as <- :pie::Es] -> :wat::WatAST
  (:wat::core::let [rest (:wat::core::rest as)
                    body (:wat::core::if (:wat::core::= (:wat::core::length rest) 1)
                           (:wat::core::first rest)
                           (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "->")) rest)))]
    (:pie::t3 "VPi" (:pie::sym "_") (:pie::eval env (:wat::core::first as)) (:pie::clos env "_" body))))

;; (Pi ((x A) (y B)) C) is (Pi ((x A)) (Pi ((y B)) C)); the same for Sigma.
(:wat::core::defn :pie::eval-binder [env <- :wat::WatAST vtag <- :wat::core::String stag <- :wat::core::String binders <- :pie::Es body <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [b (:pie::kids (:wat::core::first binders))
                    x (:pie::name-of (:wat::core::first b))
                    more (:wat::core::rest binders)
                    inner (:wat::core::if (:wat::core::empty? more)
                            body
                            (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym stag) (:pie::mk more) body)))]
    (:pie::t3 vtag (:pie::sym x) (:pie::eval env (:pie::nth b 1)) (:pie::clos env x inner))))

(:wat::core::defn :pie::eval-lambda [env <- :wat::WatAST names <- :pie::Es body <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [x (:pie::name-of (:wat::core::first names))
                    more (:wat::core::rest names)
                    inner (:wat::core::if (:wat::core::empty? more)
                            body
                            (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "lambda") (:pie::mk more) body)))]
    (:pie::t2 "VLam" (:pie::sym x) (:pie::clos env x inner))))

(:wat::core::defn :pie::eval-app [env <- :wat::WatAST f <- :wat::WatAST as <- :pie::Es] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? as)
    f
    (:pie::eval-app env (:pie::do-ap f (:pie::eval env (:wat::core::first as))) (:wat::core::rest as))))

(:wat::core::defn :pie::do-ap [f <- :wat::WatAST a <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? f "VLam") (:pie::inst (:pie::arg f 1) a))
    ((:pie::tag? f "VNeu")
      (:wat::core::let [t (:pie::arg f 0)]
        (:pie::t2 "VNeu" (:pie::inst (:pie::arg t 2) a) (:pie::t3 "NApp" (:pie::arg f 1) (:pie::arg t 1) a))))
    (:else (:pie::fail (:wat::string::concat "applying a non-function: " (:wat::core::ast->source f))))))

(:wat::core::defn :pie::do-car [p <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? p "VCons") (:pie::arg p 0))
    ((:pie::tag? p "VNeu") (:pie::t2 "VNeu" (:pie::arg (:pie::arg p 0) 1) (:pie::t1 "NCar" (:pie::arg p 1))))
    (:else (:pie::fail "car of a non-pair"))))

(:wat::core::defn :pie::do-cdr [p <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? p "VCons") (:pie::arg p 1))
    ((:pie::tag? p "VNeu")
      (:pie::t2 "VNeu" (:pie::inst (:pie::arg (:pie::arg p 0) 2) (:pie::do-car p)) (:pie::t1 "NCdr" (:pie::arg p 1))))
    (:else (:pie::fail "cdr of a non-pair"))))

;; The eliminators for Nat, each (ELIM target base step). zero gives the base; (add1 n) gives
;;   which-Nat: (step n)
;;   iter-Nat:  (step (iter-Nat n base step))
;;   rec-Nat:   (step n (rec-Nat n base step))
;; and a stuck target gives a stuck eliminator, (NNat ELIM target base-type base step).
(:wat::core::defn :pie::nat-elim? [h <- :wat::core::String] -> :wat::core::bool
  (:pie::member? (:wat::core::Vector :- [:wat::core::String] "which-Nat" "iter-Nat" "rec-Nat") h))

;; The step's type, for base type x.
(:wat::core::defn :pie::nat-step-type [elim <- :wat::core::String x <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= elim "which-Nat") (:pie::arrow-value (:pie::t0 "VNat") x))
    ((:wat::core::= elim "iter-Nat") (:pie::arrow-value x x))
    (:else (:pie::arrow-value (:pie::t0 "VNat") (:pie::arrow-value x x)))))

(:wat::core::defn :pie::do-nat-elim [elim <- :wat::core::String t <- :wat::WatAST bt <- :wat::WatAST b <- :wat::WatAST s <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? t "VZero") b)
    ((:pie::tag? t "VAdd1")
      (:wat::core::let [n (:pie::arg t 0)]
        (:wat::core::cond
          ((:wat::core::= elim "which-Nat") (:pie::do-ap s n))
          ((:wat::core::= elim "iter-Nat") (:pie::do-ap s (:pie::do-nat-elim elim n bt b s)))
          (:else (:pie::do-ap (:pie::do-ap s n) (:pie::do-nat-elim elim n bt b s))))))
    ((:pie::tag? t "VNeu")
      (:pie::t2 "VNeu" bt (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "NNat") (:pie::sym elim) (:pie::arg t 1) bt b s))))
    (:else (:pie::fail (:wat::string::concat elim " of a non-Nat")))))

;; ind-Nat: zero gives the base; (add1 n) gives (step n (ind-Nat n mot base step)). The type
;; is (mot target), so a stuck ind-Nat has type (mot target) too.
;; The step's type, (Pi ((n-1 Nat)) (-> (mot n-1) (mot (add1 n-1)))), as a value: its closure
;; reaches the motive through a private environment name.
(:wat::core::defn :pie::ind-nat-step-type [mot <- :wat::WatAST] -> :wat::WatAST
  (:pie::t3 "VPi" (:pie::sym "n-1") (:pie::t0 "VNat")
            (:pie::clos (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "%mot") mot))))
                        "n-1"
                        (:pie::t2 "->" (:pie::t1 "%mot" (:pie::sym "n-1")) (:pie::t1 "%mot" (:pie::t1 "add1" (:pie::sym "n-1")))))))

(:wat::core::defn :pie::do-ind-nat [t <- :wat::WatAST mot <- :wat::WatAST b <- :wat::WatAST s <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? t "VZero") b)
    ((:pie::tag? t "VAdd1") (:pie::do-ap (:pie::do-ap s (:pie::arg t 0)) (:pie::do-ind-nat (:pie::arg t 0) mot b s)))
    ((:pie::tag? t "VNeu") (:pie::t2 "VNeu" (:pie::do-ap mot t) (:pie::t4 "NIndNat" (:pie::arg t 1) mot b s)))
    (:else (:pie::fail "ind-Nat of a non-Nat"))))

;; head and tail of a Vec. A stuck one has type (Vec E (add1 l)); the checker saw to that.
(:wat::core::defn :pie::do-head [v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? v "VVecCons") (:pie::arg v 0))
    ((:pie::tag? v "VNeu") (:pie::t2 "VNeu" (:pie::arg (:pie::arg v 0) 0) (:pie::t1 "NHead" (:pie::arg v 1))))
    (:else (:pie::fail "head of an empty Vec"))))

(:wat::core::defn :pie::do-tail [v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? v "VVecCons") (:pie::arg v 1))
    ((:pie::tag? v "VNeu")
      (:wat::core::let [t (:pie::arg v 0)]
        (:pie::t2 "VNeu" (:pie::t2 "VVec" (:pie::arg t 0) (:pie::arg (:pie::arg t 1) 0)) (:pie::t1 "NTail" (:pie::arg v 1)))))
    (:else (:pie::fail "tail of an empty Vec"))))

;; rec-List: nil gives the base; (:: e es) gives (step e es (rec-List es base step)); a stuck
;; target, whose type (List E) gives the step's type, a stuck rec-List.
(:wat::core::defn :pie::list-step-type [et <- :wat::WatAST x <- :wat::WatAST] -> :wat::WatAST
  (:pie::arrow-value et (:pie::arrow-value (:pie::t1 "VList" et) (:pie::arrow-value x x))))

(:wat::core::defn :pie::do-rec-list [t <- :wat::WatAST bt <- :wat::WatAST b <- :wat::WatAST s <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? t "VNil") b)
    ((:pie::tag? t "VLCons")
      (:pie::do-ap (:pie::do-ap (:pie::do-ap s (:pie::arg t 0)) (:pie::arg t 1)) (:pie::do-rec-list (:pie::arg t 1) bt b s)))
    ((:pie::tag? t "VNeu")
      (:pie::t2 "VNeu" bt (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                                      (:pie::sym "NRecList") (:pie::arg t 1) (:pie::arg (:pie::arg t 0) 0) bt b s))))
    (:else (:pie::fail "rec-List of a non-list"))))

;; ---- reading back

(:wat::core::defn :pie::subscript [i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::= i 1) "₁") ((:wat::core::= i 2) "₂") ((:wat::core::= i 3) "₃")
    ((:wat::core::= i 4) "₄") ((:wat::core::= i 5) "₅") ((:wat::core::= i 6) "₆")
    ((:wat::core::= i 7) "₇") ((:wat::core::= i 8) "₈") ((:wat::core::= i 9) "₉")
    (:else (:wat::i64::to-string i))))

(:wat::core::defn :pie::fresh-n [used <- :pie::Names base <- :wat::core::String i <- :wat::core::i64] -> :wat::core::String
  (:wat::core::let [c (:wat::string::concat base (:pie::subscript i))]
    (:wat::core::if (:pie::member? used c) (:pie::fresh-n used base (:wat::core::+ i 1)) c)))

;; A name not in use: x itself, or x with a subscript, as Pie picks them.
(:wat::core::defn :pie::fresh [used <- :pie::Names x <- :wat::core::String] -> :wat::core::String
  (:wat::core::let [base (:wat::core::if (:wat::core::= x "_") "x" x)]
    (:wat::core::if (:pie::member? used base) (:pie::fresh-n used base 1) base)))

(:wat::core::defn :pie::var-value [type <- :wat::WatAST x <- :wat::core::String] -> :wat::WatAST
  (:pie::t2 "VNeu" type (:pie::t1 "NVar" (:pie::sym x))))

(:wat::core::defn :pie::rb-type [used <- :pie::Names v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? v "VU") (:pie::sym "U"))
    ((:pie::tag? v "VAtom") (:pie::sym "Atom"))
    ((:pie::tag? v "VNat") (:pie::sym "Nat"))
    ((:pie::tag? v "VList") (:pie::t1 "List" (:pie::rb-type used (:pie::arg v 0))))
    ((:pie::tag? v "VVec") (:pie::t2 "Vec" (:pie::rb-type used (:pie::arg v 0)) (:pie::rb used (:pie::t0 "VNat") (:pie::arg v 1))))
    ((:pie::tag? v "VPi") (:pie::rb-binder used v "Pi"))
    ((:pie::tag? v "VSigma") (:pie::rb-binder used v "Sigma"))
    ((:pie::tag? v "VNeu") (:pie::rb-neu used (:pie::arg v 1)))
    (:else (:pie::fail (:wat::string::concat "not a type: " (:wat::core::ast->source v))))))

(:wat::core::defn :pie::rb-binder [used <- :pie::Names v <- :wat::WatAST stag <- :wat::core::String] -> :wat::WatAST
  (:wat::core::let [x (:pie::fresh used (:pie::name-of (:pie::arg v 0)))
                    dom (:pie::arg v 1)
                    body-t (:pie::inst (:pie::arg v 2) (:pie::var-value dom x))]
    (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                (:pie::sym stag)
                (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) (:pie::rb-type used dom)))))
                (:pie::rb-type (:wat::core::conj used x) body-t)))))

;; The normal form of value v at type t: functions and pairs are eta-expanded.
(:wat::core::defn :pie::rb [used <- :pie::Names t <- :wat::WatAST v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? t "VU") (:pie::rb-type used v))
    ((:pie::tag? t "VPi")
      (:wat::core::let [y (:pie::fresh used (:wat::core::if (:pie::tag? v "VLam") (:pie::name-of (:pie::arg v 0)) (:pie::name-of (:pie::arg t 0))))
                        a (:pie::var-value (:pie::arg t 1) y)]
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym "lambda")
                    (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym y)))
                    (:pie::rb (:wat::core::conj used y) (:pie::inst (:pie::arg t 2) a) (:pie::do-ap v a))))))
    ((:pie::tag? t "VSigma")
      (:wat::core::let [a (:pie::do-car v)]
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym "cons")
                    (:pie::rb used (:pie::arg t 1) a)
                    (:pie::rb used (:pie::inst (:pie::arg t 2) a) (:pie::do-cdr v))))))
    ((:pie::tag? t "VVec") (:pie::rb-vec used t v))
    ((:pie::tag? v "VNeu") (:pie::rb-neu used (:pie::arg v 1)))
    ((:pie::tag? v "VNil") (:pie::sym "nil"))
    ((:pie::tag? v "VLCons")
      (:pie::t2 "::" (:pie::rb used (:pie::arg t 0) (:pie::arg v 0)) (:pie::rb used t (:pie::arg v 1))))
    ((:pie::tag? v "VQuote") (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "quote") (:pie::arg v 0))))
    ((:pie::tag? v "VZero") (:pie::sym "zero"))
    ((:pie::tag? v "VAdd1") (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "add1") (:pie::rb used t (:pie::arg v 0)))))
    (:else (:pie::fail (:wat::string::concat "cannot read back " (:wat::core::ast->source v))))))

;; A Vec whose length is zero reads back as vecnil, whatever it is (Pie's eta for Vec stops
;; there: a variable of length 1 stays a variable).
(:wat::core::defn :pie::rb-vec [used <- :pie::Names t <- :wat::WatAST v <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [len (:pie::arg t 1)]
    (:wat::core::cond
      ((:pie::tag? len "VZero") (:pie::sym "vecnil"))
      ((:pie::tag? v "VVecCons")
        (:pie::t2 "vec::" (:pie::rb used (:pie::arg t 0) (:pie::arg v 0))
                          (:pie::rb used (:pie::t2 "VVec" (:pie::arg t 0) (:pie::arg len 0)) (:pie::arg v 1))))
      ((:pie::tag? v "VNeu") (:pie::rb-neu used (:pie::arg v 1)))
      (:else (:pie::fail (:wat::string::concat "cannot read back Vec " (:wat::core::ast->source v)))))))

(:wat::core::defn :pie::rb-neu [used <- :pie::Names ne <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:pie::tag? ne "NIndNat")
      (:wat::core::let [mot (:pie::arg ne 1)]
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym "ind-Nat")
                    (:pie::rb-neu used (:pie::arg ne 0))
                    (:pie::rb used (:pie::arrow-value (:pie::t0 "VNat") (:pie::t0 "VU")) mot)
                    (:pie::rb used (:pie::do-ap mot (:pie::t0 "VZero")) (:pie::arg ne 2))
                    (:pie::rb used (:pie::ind-nat-step-type mot) (:pie::arg ne 3))))))
    ((:pie::tag? ne "NHead") (:pie::t1 "head" (:pie::rb-neu used (:pie::arg ne 0))))
    ((:pie::tag? ne "NTail") (:pie::t1 "tail" (:pie::rb-neu used (:pie::arg ne 0))))
    ((:pie::tag? ne "NVar") (:pie::arg ne 0))
    ((:pie::tag? ne "NApp")
      (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::rb-neu used (:pie::arg ne 0)) (:pie::rb used (:pie::arg ne 1) (:pie::arg ne 2)))))
    ((:pie::tag? ne "NCar") (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "car") (:pie::rb-neu used (:pie::arg ne 0)))))
    ((:pie::tag? ne "NCdr") (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "cdr") (:pie::rb-neu used (:pie::arg ne 0)))))
    ((:pie::tag? ne "NRecList")
      (:wat::core::let [bt (:pie::arg ne 2)]
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym "rec-List")
                    (:pie::rb-neu used (:pie::arg ne 0))
                    (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "the") (:pie::rb-type used bt) (:pie::rb used bt (:pie::arg ne 3))))
                    (:pie::rb used (:pie::list-step-type (:pie::arg ne 1) bt) (:pie::arg ne 4))))))
    ((:pie::tag? ne "NNat")
      (:wat::core::let [elim (:pie::name-of (:pie::arg ne 0))
                        bt (:pie::arg ne 2)]
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym elim)
                    (:pie::rb-neu used (:pie::arg ne 1))
                    (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "the") (:pie::rb-type used bt) (:pie::rb used bt (:pie::arg ne 3))))
                    (:pie::rb used (:pie::nat-step-type elim bt) (:pie::arg ne 4))))))
    (:else (:pie::fail (:wat::string::concat "cannot read back neutral " (:wat::core::ast->source ne))))))

;; ---- alpha-equivalence of raw read-backs (one binder per lambda, Pi, Sigma)

(:wat::core::defn :pie::index-of [xs <- :pie::Names x <- :wat::core::String i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::empty? xs)
    -1
    (:wat::core::if (:wat::core::= (:wat::core::first xs) x) i (:pie::index-of (:wat::core::rest xs) x (:wat::core::+ i 1)))))

(:wat::core::defn :pie::push [xs <- :pie::Names x <- :wat::core::String] -> :pie::Names
  (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] x) xs))

(:wat::core::defn :pie::alpha? [a <- :wat::WatAST b <- :wat::WatAST la <- :pie::Names lb <- :pie::Names] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::if (:wat::core::= (:wat::core::ast-kind a) "symbol") (:wat::core::= (:wat::core::ast-kind b) "symbol") false)
      (:wat::core::let [ia (:pie::index-of la (:wat::core::ast-name a) 0)
                        ib (:pie::index-of lb (:wat::core::ast-name b) 0)]
        (:wat::core::if (:wat::core::= ia ib)
          (:wat::core::if (:wat::core::= ia -1) (:wat::core::= (:wat::core::ast-name a) (:wat::core::ast-name b)) true)
          false)))
    ((:wat::core::if (:pie::list? a) (:pie::list? b) false)
      (:wat::core::let [ha (:pie::head a)]
        (:wat::core::cond
          ((:wat::core::not (:wat::core::= ha (:pie::head b))) false)
          ((:wat::core::= ha "lambda")
            (:pie::alpha? (:pie::arg a 1) (:pie::arg b 1)
                          (:pie::push la (:pie::name-of (:wat::core::first (:pie::kids (:pie::arg a 0)))))
                          (:pie::push lb (:pie::name-of (:wat::core::first (:pie::kids (:pie::arg b 0)))))))
          ((:wat::core::if (:wat::core::= ha "Pi") true (:wat::core::= ha "Sigma"))
            (:wat::core::let [ba (:pie::kids (:wat::core::first (:pie::kids (:pie::arg a 0))))
                              bb (:pie::kids (:wat::core::first (:pie::kids (:pie::arg b 0))))]
              (:wat::core::if (:pie::alpha? (:pie::nth ba 1) (:pie::nth bb 1) la lb)
                (:pie::alpha? (:pie::arg a 1) (:pie::arg b 1)
                              (:pie::push la (:pie::name-of (:wat::core::first ba)))
                              (:pie::push lb (:pie::name-of (:wat::core::first bb))))
                false)))
          (:else (:pie::alpha-all? (:pie::kids a) (:pie::kids b) la lb)))))
    (:else (:wat::core::= a b))))

(:wat::core::defn :pie::alpha-all? [as <- :pie::Es bs <- :pie::Es la <- :pie::Names lb <- :pie::Names] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::empty? as) (:wat::core::empty? bs))
    ((:wat::core::empty? bs) false)
    ((:pie::alpha? (:wat::core::first as) (:wat::core::first bs) la lb) (:pie::alpha-all? (:wat::core::rest as) (:wat::core::rest bs) la lb))
    (:else false)))

;; ---- resugaring for printing, as Pie prints

(:wat::core::defn :pie::free? [x <- :wat::core::String e <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::= (:wat::core::ast-kind e) "symbol") (:wat::core::= (:wat::core::ast-name e) x))
    ((:pie::list? e) (:pie::any-free? x (:pie::kids e)))
    (:else false)))

(:wat::core::defn :pie::any-free? [x <- :wat::core::String es <- :pie::Es] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? es)
    false
    (:wat::core::if (:pie::free? x (:wat::core::first es)) true (:pie::any-free? x (:wat::core::rest es)))))

(:wat::core::defn :pie::special? [h <- :wat::core::String] -> :wat::core::bool
  (:pie::member? (:wat::core::Vector :- [:wat::core::String] "lambda" "Pi" "Sigma" "->" "Pair" "cons" "car" "cdr" "add1" "quote" "the" "which-Nat" "iter-Nat" "rec-Nat" "List" "::" "rec-List" "Vec" "vec::" "head" "tail" "ind-Nat") h))

(:wat::core::defn :pie::sugar-all [es <- :pie::Es] -> :pie::Es
  (:wat::core::if (:wat::core::empty? es)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::sugar (:wat::core::first es))) (:pie::sugar-all (:wat::core::rest es)))))

(:wat::core::defn :pie::sugar [e <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= (:wat::core::ast-kind e) "symbol")
      (:wat::core::if (:wat::core::= (:wat::core::ast-name e) "zero") (:pie::int-node 0) e))
    ((:wat::core::not (:pie::list? e)) e)
    (:else
      (:wat::core::let [h (:pie::head e)]
        (:wat::core::cond
          ((:wat::core::= h "quote") e)
          ((:wat::core::= h "add1")
            (:wat::core::let [n (:pie::sugar (:pie::arg e 0))]
              (:wat::core::if (:wat::core::= (:wat::core::ast-kind n) "int")
                (:pie::int-node (:wat::core::+ 1 (:ls::ast->i64 n)))
                (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "add1") n)))))
          ((:wat::core::= h "Pi") (:pie::sugar-binder e "Pi" "->" true))
          ((:wat::core::= h "Sigma") (:pie::sugar-binder e "Sigma" "Pair" false))
          ((:wat::core::= h "lambda") (:pie::sugar-lambda e))
          (:else (:pie::flatten-app (:pie::sugar-all (:pie::kids e)))))))))

;; (Pi ((x A)) B): -> when x is not free in B (spliced into a following ->), otherwise Pi,
;; merged with a following Pi. Sigma likewise, as Pair (not spliced: Pair takes two).
(:wat::core::defn :pie::sugar-binder [e <- :wat::WatAST stag <- :wat::core::String arrow <- :wat::core::String splice? <- :wat::core::bool] -> :wat::WatAST
  (:wat::core::let [b (:pie::kids (:wat::core::first (:pie::kids (:pie::arg e 0))))
                    x (:pie::name-of (:wat::core::first b))
                    a (:pie::sugar (:pie::nth b 1))
                    body (:pie::sugar (:pie::arg e 1))]
    (:wat::core::if (:pie::free? x body)
      (:wat::core::if (:wat::core::= (:pie::head body) stag)
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym stag)
                    (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) a)))
                                                  (:pie::kids (:pie::arg body 0))))
                    (:pie::arg body 1)))
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                    (:pie::sym stag)
                    (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) a))))
                    body)))
      (:wat::core::if (:wat::core::if splice? (:wat::core::= (:pie::head body) arrow) false)
        (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::sym arrow) a) (:pie::args body)))
        (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym arrow) a body))))))

(:wat::core::defn :pie::sugar-lambda [e <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [x (:wat::core::first (:pie::kids (:pie::arg e 0)))
                    body (:pie::sugar (:pie::arg e 1))]
    (:wat::core::if (:wat::core::= (:pie::head body) "lambda")
      (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                  (:pie::sym "lambda")
                  (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] x) (:pie::kids (:pie::arg body 0))))
                  (:pie::arg body 1)))
      (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "lambda") (:pie::mk (:wat::core::Vector :- [:wat::WatAST] x)) body)))))

;; ((f a) b) prints as (f a b).
(:wat::core::defn :pie::flatten-app [ks <- :pie::Es] -> :wat::WatAST
  (:wat::core::let [r (:wat::core::first ks)]
    (:wat::core::if (:wat::core::if (:pie::list? r) (:wat::core::not (:pie::special? (:pie::head r))) false)
      (:pie::mk (:wat::core::concat (:pie::kids r) (:wat::core::rest ks)))
      (:pie::mk ks))))

;; ---- contexts

(:wat::core::defn :pie::ctx-used [es <- :pie::Es] -> :pie::Names
  (:wat::core::if (:wat::core::empty? es)
    (:wat::core::Vector :- [:wat::core::String])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] (:pie::name-of (:wat::core::first (:pie::kids (:wat::core::first es)))))
                        (:pie::ctx-used (:wat::core::rest es)))))

(:wat::core::defn :pie::used [ctx <- :wat::WatAST] -> :pie::Names
  (:pie::ctx-used (:pie::kids ctx)))

(:wat::core::defn :pie::ctx-lookup [es <- :pie::Es x <- :wat::core::String] -> (:wat::core::Option :- [:wat::WatAST])
  (:wat::core::if (:wat::core::empty? es)
    :wat::core::Option.None
    (:wat::core::if (:wat::core::= (:pie::name-of (:wat::core::first (:pie::kids (:wat::core::first es)))) x)
      (:wat::core::Option.Some {:value (:wat::core::first es)})
      (:pie::ctx-lookup (:wat::core::rest es) x))))

(:wat::core::defn :pie::extend [ctx <- :wat::WatAST entry <- :pie::Es] -> :wat::WatAST
  (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::mk entry)) (:pie::kids ctx))))

(:wat::core::defn :pie::extend-var [ctx <- :wat::WatAST x <- :wat::core::String t <- :wat::WatAST] -> :wat::WatAST
  (:pie::extend ctx (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) (:pie::sym "var") t)))

(:wat::core::defn :pie::show-type [ctx <- :wat::WatAST t <- :wat::WatAST] -> :wat::core::String
  (:wat::core::ast->source (:pie::sugar (:pie::rb-type (:pie::used ctx) t))))

;; ---- type checking, with elaboration: synth gives (TYPE CORE), check gives CORE

(:wat::core::defn :pie::syn [t <- :wat::WatAST core <- :wat::WatAST] -> :wat::WatAST
  (:pie::mk (:wat::core::Vector :- [:wat::WatAST] t core)))
(:wat::core::defn :pie::syn-type [s <- :wat::WatAST] -> :wat::WatAST (:pie::nth (:pie::kids s) 0))
(:wat::core::defn :pie::syn-core [s <- :wat::WatAST] -> :wat::WatAST (:pie::nth (:pie::kids s) 1))

(:wat::core::defn :pie::synth [ctx <- :wat::WatAST env <- :wat::WatAST e <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [k (:wat::core::ast-kind e)]
    (:wat::core::cond
      ((:wat::core::= k "int") (:pie::syn (:pie::t0 "VNat") e))
      ((:wat::core::= k "symbol") (:pie::syn (:pie::synth-var ctx (:wat::core::ast-name e)) e))
      ((:pie::list? e) (:pie::synth-form ctx env e (:pie::head e)))
      (:else (:pie::fail (:wat::string::concat "cannot determine a type for " (:wat::core::ast->source e)))))))

(:wat::core::defn :pie::synth-var [ctx <- :wat::WatAST name <- :wat::core::String] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::if (:wat::core::= name "Atom") true (:wat::core::= name "Nat")) (:pie::t0 "VU"))
    ((:wat::core::= name "zero") (:pie::t0 "VNat"))
    ((:wat::core::= name "U") (:pie::fail "U is a type, but it does not have a type"))
    ((:wat::core::= name "vecnil") (:pie::fail "cannot determine a type for vecnil; use the"))
    (:else
      (:wat::core::match (:pie::ctx-lookup (:pie::kids ctx) name)
        [:wat::core::Option.Some {:value ent}
          (:wat::core::if (:wat::core::= (:pie::name-of (:pie::nth (:pie::kids ent) 1)) "claim")
            (:pie::fail (:wat::string::concat name " is claimed but not yet defined"))
            (:pie::nth (:pie::kids ent) 2))]
        [:wat::core::Option.None {} (:pie::fail (:wat::string::concat "unknown name " name))]))))

(:wat::core::defn :pie::synth-form [ctx <- :wat::WatAST env <- :wat::WatAST e <- :wat::WatAST h <- :wat::core::String] -> :wat::WatAST
  (:wat::core::cond
    ((:wat::core::= h "quote") (:pie::syn (:pie::t0 "VAtom") e))
    ((:wat::core::= h "add1")
      (:pie::syn (:pie::t0 "VNat") (:pie::t1 "add1" (:pie::check ctx env (:pie::arg e 0) (:pie::t0 "VNat")))))
    ((:wat::core::= h "the")
      (:wat::core::let [tc (:pie::check-type ctx env (:pie::arg e 0))
                        tv (:pie::eval env tc)]
        (:pie::syn tv (:pie::t2 "the" tc (:pie::check ctx env (:pie::arg e 1) tv)))))
    ((:pie::member? (:wat::core::Vector :- [:wat::core::String] "Pair" "->" "Pi" "Sigma" "List" "Vec") h)
      (:pie::syn (:pie::t0 "VU") (:pie::type-at ctx env e true)))
    ((:wat::core::= h "car")
      (:wat::core::let [s (:pie::synth ctx env (:pie::arg e 0))
                        pt (:pie::syn-type s)]
        (:wat::core::if (:pie::tag? pt "VSigma")
          (:pie::syn (:pie::arg pt 1) (:pie::t1 "car" (:pie::syn-core s)))
          (:pie::fail "car of a non-pair"))))
    ((:wat::core::= h "cdr")
      (:wat::core::let [s (:pie::synth ctx env (:pie::arg e 0))
                        pt (:pie::syn-type s)
                        pc (:pie::syn-core s)]
        (:wat::core::if (:pie::tag? pt "VSigma")
          (:pie::syn (:pie::inst (:pie::arg pt 2) (:pie::do-car (:pie::eval env pc))) (:pie::t1 "cdr" pc))
          (:pie::fail "cdr of a non-pair"))))
    ((:wat::core::= h "ind-Nat")
      (:wat::core::let [tc (:pie::check ctx env (:pie::arg e 0) (:pie::t0 "VNat"))
                        mc (:pie::check ctx env (:pie::arg e 1) (:pie::arrow-value (:pie::t0 "VNat") (:pie::t0 "VU")))
                        mv (:pie::eval env mc)
                        bc (:pie::check ctx env (:pie::arg e 2) (:pie::do-ap mv (:pie::t0 "VZero")))
                        sc (:pie::check ctx env (:pie::arg e 3) (:pie::ind-nat-step-type mv))]
        (:pie::syn (:pie::do-ap mv (:pie::eval env tc)) (:pie::t4 "ind-Nat" tc mc bc sc))))
    ((:wat::core::if (:wat::core::= h "head") true (:wat::core::= h "tail"))
      (:wat::core::let [s (:pie::synth ctx env (:pie::arg e 0))
                        vt (:pie::syn-type s)]
        (:wat::core::if (:wat::core::if (:pie::tag? vt "VVec") (:pie::tag? (:pie::arg vt 1) "VAdd1") false)
          (:pie::syn (:wat::core::if (:wat::core::= h "head")
                       (:pie::arg vt 0)
                       (:pie::t2 "VVec" (:pie::arg vt 0) (:pie::arg (:pie::arg vt 1) 0)))
                     (:pie::t1 h (:pie::syn-core s)))
          (:pie::fail (:wat::string::concat h " needs a Vec with add1 at the top of its length, not " (:pie::show-type ctx vt))))))
    ;; :: only synthesizes, as in Pie: its head's type gives the list's.
    ((:wat::core::= h "::")
      (:wat::core::let [hs (:pie::synth ctx env (:pie::arg e 0))
                        lt (:pie::t1 "VList" (:pie::syn-type hs))]
        (:pie::syn lt (:pie::t2 "::" (:pie::syn-core hs) (:pie::check ctx env (:pie::arg e 1) lt)))))
    ((:wat::core::= h "rec-List")
      (:wat::core::let [ts (:pie::synth ctx env (:pie::arg e 0))
                        lt (:pie::syn-type ts)]
        (:wat::core::if (:pie::tag? lt "VList")
          (:wat::core::let [bs (:pie::synth ctx env (:pie::arg e 1))
                            x (:pie::syn-type bs)
                            sc (:pie::check ctx env (:pie::arg e 2) (:pie::list-step-type (:pie::arg lt 0) x))]
            (:pie::syn x (:pie::t3 "rec-List" (:pie::syn-core ts) (:pie::t2 "the" (:pie::rb-type (:pie::used ctx) x) (:pie::syn-core bs)) sc)))
          (:pie::fail (:wat::string::concat "not a List: " (:pie::show-type ctx lt))))))
    ((:pie::nat-elim? h)
      (:wat::core::let [tc (:pie::check ctx env (:pie::arg e 0) (:pie::t0 "VNat"))
                        bs (:pie::synth ctx env (:pie::arg e 1))
                        x (:pie::syn-type bs)
                        sc (:pie::check ctx env (:pie::arg e 2) (:pie::nat-step-type h x))]
        (:pie::syn x (:pie::t3 h tc (:pie::t2 "the" (:pie::rb-type (:pie::used ctx) x) (:pie::syn-core bs)) sc))))
    ((:pie::member? (:wat::core::Vector :- [:wat::core::String] "cons" "lambda" "vec::") h)
      (:pie::fail (:wat::string::concat "cannot determine a type for " (:wat::core::ast->source e) "; use the")))
    (:else
      (:wat::core::let [fs (:pie::synth ctx env (:wat::core::first (:pie::kids e)))]
        (:pie::synth-app ctx env (:pie::syn-type fs) (:wat::core::Vector :- [:wat::WatAST] (:pie::syn-core fs)) (:pie::args e))))))

;; Each argument is checked against the function type's domain; the core is (f a ...).
(:wat::core::defn :pie::synth-app [ctx <- :wat::WatAST env <- :wat::WatAST ft <- :wat::WatAST done <- :pie::Es as <- :pie::Es] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? as)
    (:pie::syn ft (:pie::mk done))
    (:wat::core::if (:pie::tag? ft "VPi")
      (:wat::core::let [ac (:pie::check ctx env (:wat::core::first as) (:pie::arg ft 1))]
        (:pie::synth-app ctx env (:pie::inst (:pie::arg ft 2) (:pie::eval env ac))
                         (:wat::core::conj done ac) (:wat::core::rest as)))
      (:pie::fail (:wat::string::concat "not a function type: " (:pie::show-type ctx ft))))))

;; A type expression, elaborated. U is a type but has none, so a type former is a U only when
;; its parts are: (Pi ((A U)) A) is a type, and not a U.
(:wat::core::defn :pie::check-type [ctx <- :wat::WatAST env <- :wat::WatAST e <- :wat::WatAST] -> :wat::WatAST
  (:pie::type-at ctx env e false))

;; u? says the type must itself be a U.
(:wat::core::defn :pie::type-at [ctx <- :wat::WatAST env <- :wat::WatAST e <- :wat::WatAST u? <- :wat::core::bool] -> :wat::WatAST
  (:wat::core::let [h (:pie::head e)
                    n (:pie::name-of e)]
    (:wat::core::cond
      ((:wat::core::if u? (:wat::core::= n "U") false) (:pie::fail "U is a type, but it does not have a type"))
      ((:pie::member? (:wat::core::Vector :- [:wat::core::String] "U" "Atom" "Nat") n) e)
      ((:wat::core::= h "List") (:pie::t1 "List" (:pie::type-at ctx env (:pie::arg e 0) u?)))
      ((:wat::core::= h "Vec")
        (:pie::t2 "Vec" (:pie::type-at ctx env (:pie::arg e 0) u?) (:pie::check ctx env (:pie::arg e 1) (:pie::t0 "VNat"))))
      ((:wat::core::if (:wat::core::= h "Pair") true (:wat::core::= h "->"))
        (:pie::mk (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::sym h)) (:pie::check-types ctx env (:pie::args e) u?))))
      ((:wat::core::if (:wat::core::= h "Pi") true (:wat::core::= h "Sigma"))
        (:pie::check-binders ctx env h (:pie::kids (:pie::arg e 0)) (:pie::arg e 1) u?))
      (:else (:pie::check ctx env e (:pie::t0 "VU"))))))

(:wat::core::defn :pie::check-types [ctx <- :wat::WatAST env <- :wat::WatAST es <- :pie::Es u? <- :wat::core::bool] -> :pie::Es
  (:wat::core::if (:wat::core::empty? es)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::type-at ctx env (:wat::core::first es) u?))
                        (:pie::check-types ctx env (:wat::core::rest es) u?))))

;; (Pi ((x A) (y B)) C) elaborates to (Pi ((x A)) (Pi ((y B)) C)).
(:wat::core::defn :pie::check-binders [ctx <- :wat::WatAST env <- :wat::WatAST stag <- :wat::core::String binders <- :pie::Es body <- :wat::WatAST u? <- :wat::core::bool] -> :wat::WatAST
  (:wat::core::let [b (:pie::kids (:wat::core::first binders))
                    x (:pie::name-of (:wat::core::first b))
                    ac (:pie::type-at ctx env (:pie::nth b 1) u?)
                    av (:pie::eval env ac)
                    ctx2 (:pie::extend-var ctx x av)
                    env2 (:pie::bind env x (:pie::var-value av x))
                    more (:wat::core::rest binders)
                    inner (:wat::core::if (:wat::core::empty? more)
                            (:pie::type-at ctx2 env2 body u?)
                            (:pie::check-binders ctx2 env2 stag more body u?))]
    (:pie::mk (:wat::core::Vector :- [:wat::WatAST]
                (:pie::sym stag)
                (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) ac))))
                inner))))

(:wat::core::defn :pie::check [ctx <- :wat::WatAST env <- :wat::WatAST e <- :wat::WatAST t <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::let [h (:pie::head e)]
    (:wat::core::cond
      ((:wat::core::if (:wat::core::= (:pie::name-of e) "nil") (:pie::tag? t "VList") false) e)
      ((:wat::core::if (:wat::core::= (:pie::name-of e) "vecnil") (:pie::tag? t "VVec") false)
        (:wat::core::if (:pie::tag? (:pie::arg t 1) "VZero")
          e
          (:pie::fail (:wat::string::concat "vecnil needs the length to be zero, not "
                                            (:wat::core::ast->source (:pie::sugar (:pie::rb (:pie::used ctx) (:pie::t0 "VNat") (:pie::arg t 1))))))))
      ((:wat::core::if (:wat::core::= h "vec::") (:pie::tag? t "VVec") false)
        (:wat::core::let [len (:pie::arg t 1)]
          (:wat::core::if (:pie::tag? len "VAdd1")
            (:pie::t2 "vec::" (:pie::check ctx env (:pie::arg e 0) (:pie::arg t 0))
                              (:pie::check ctx env (:pie::arg e 1) (:pie::t2 "VVec" (:pie::arg t 0) (:pie::arg len 0))))
            (:pie::fail (:wat::string::concat "vec:: needs add1 at the top of the length, not "
                                              (:wat::core::ast->source (:pie::sugar (:pie::rb (:pie::used ctx) (:pie::t0 "VNat") len))))))))
      ((:wat::core::if (:wat::core::= h "cons") (:pie::tag? t "VSigma") false)
        (:wat::core::let [ac (:pie::check ctx env (:pie::arg e 0) (:pie::arg t 1))]
          (:pie::t2 "cons" ac (:pie::check ctx env (:pie::arg e 1) (:pie::inst (:pie::arg t 2) (:pie::eval env ac))))))
      ((:wat::core::if (:wat::core::= h "lambda") (:pie::tag? t "VPi") false)
        (:pie::check-lambda ctx env (:pie::kids (:pie::arg e 0)) (:pie::arg e 1) t))
      (:else
        (:wat::core::let [s (:pie::synth ctx env e)]
          (:wat::core::if (:pie::alpha? (:pie::rb-type (:pie::used ctx) (:pie::syn-type s)) (:pie::rb-type (:pie::used ctx) t)
                                        (:wat::core::Vector :- [:wat::core::String]) (:wat::core::Vector :- [:wat::core::String]))
            (:pie::syn-core s)
            (:pie::fail (:wat::string::concat (:wat::core::ast->source e) " has type " (:pie::show-type ctx (:pie::syn-type s))
                                              " but should have type " (:pie::show-type ctx t)))))))))

(:wat::core::defn :pie::check-lambda [ctx <- :wat::WatAST env <- :wat::WatAST names <- :pie::Es body <- :wat::WatAST t <- :wat::WatAST] -> :wat::WatAST
  (:wat::core::if (:pie::tag? t "VPi")
    (:wat::core::let [x (:pie::name-of (:wat::core::first names))
                      dom (:pie::arg t 1)
                      xv (:pie::var-value dom x)
                      ctx2 (:pie::extend-var ctx x dom)
                      env2 (:pie::bind env x xv)
                      bt (:pie::inst (:pie::arg t 2) xv)
                      inner (:wat::core::if (:wat::core::empty? (:wat::core::rest names))
                              (:pie::check ctx2 env2 body bt)
                              (:pie::check-lambda ctx2 env2 (:wat::core::rest names) body bt))]
      (:pie::t2 "lambda" (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x))) inner))
    (:pie::fail (:wat::string::concat "a lambda should have a Pi type, not " (:pie::show-type ctx t)))))

;; ---- programs: claim, define, check-same, and expressions, whose (the TYPE VALUE) is printed

;; A type that is not a U: one that mentions U as a type among its parts, like U itself or
;; (Pi ((A U)) A). It has no type to print, so Pie prints the type by itself.
(:wat::core::defn :pie::large? [e <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::let [h (:pie::head e)]
    (:wat::core::cond
      ((:wat::core::= (:pie::name-of e) "U") true)
      ((:pie::member? (:wat::core::Vector :- [:wat::core::String] "Pair" "->" "List" "Vec") h) (:pie::any-large? (:pie::args e)))
      ((:wat::core::if (:wat::core::= h "Pi") true (:wat::core::= h "Sigma"))
        (:wat::core::if (:pie::any-large? (:pie::binder-types (:pie::kids (:pie::arg e 0)))) true (:pie::large? (:pie::arg e 1))))
      (:else false))))

(:wat::core::defn :pie::any-large? [es <- :pie::Es] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? es)
    false
    (:wat::core::if (:pie::large? (:wat::core::first es)) true (:pie::any-large? (:wat::core::rest es)))))

(:wat::core::defn :pie::binder-types [bs <- :pie::Es] -> :pie::Es
  (:wat::core::if (:wat::core::empty? bs)
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:pie::nth (:pie::kids (:wat::core::first bs)) 1))
                        (:pie::binder-types (:wat::core::rest bs)))))

(:wat::core::defstruct :pie::St
  [ctx <- :wat::WatAST
   env <- :wat::WatAST
   out <- :pie::Names])

(:wat::core::defn :pie::claimed-type [ctx <- :wat::WatAST x <- :wat::core::String] -> :wat::WatAST
  (:wat::core::match (:pie::ctx-lookup (:pie::kids ctx) x)
    [:wat::core::Option.Some {:value ent}
      (:wat::core::if (:wat::core::= (:pie::name-of (:pie::nth (:pie::kids ent) 1)) "claim")
        (:pie::nth (:pie::kids ent) 2)
        (:pie::fail (:wat::string::concat x " is already defined")))]
    [:wat::core::Option.None {} (:pie::fail (:wat::string::concat x " must be claimed before it is defined"))]))

(:wat::core::defn :pie::run-form [st <- :pie::St form <- :wat::WatAST] -> :pie::St
  (:wat::core::let [ctx (:pie::St/ctx st)
                    env (:pie::St/env st)
                    h (:pie::head form)]
    (:wat::core::cond
      ((:wat::core::= h "claim")
        (:wat::core::let [x (:pie::name-of (:pie::arg form 0))
                          tv (:pie::eval env (:pie::check-type ctx env (:pie::arg form 1)))]
          (:pie::St :ctx (:pie::extend ctx (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) (:pie::sym "claim") tv))
                    :env env :out (:pie::St/out st))))
      ((:wat::core::= h "define")
        (:wat::core::let [x (:pie::name-of (:pie::arg form 0))
                          tv (:pie::claimed-type ctx x)
                          v (:pie::eval env (:pie::check ctx env (:pie::arg form 1) tv))]
          (:pie::St :ctx (:pie::extend ctx (:wat::core::Vector :- [:wat::WatAST] (:pie::sym x) (:pie::sym "def") tv v))
                    :env (:pie::bind env x v) :out (:pie::St/out st))))
      ((:wat::core::= h "check-same")
        (:wat::core::let [tv (:pie::eval env (:pie::check-type ctx env (:pie::arg form 0)))
                          a (:pie::eval env (:pie::check ctx env (:pie::arg form 1) tv))
                          b (:pie::eval env (:pie::check ctx env (:pie::arg form 2) tv))]
          (:wat::core::if (:pie::alpha? (:pie::rb (:pie::used ctx) tv a) (:pie::rb (:pie::used ctx) tv b)
                                        (:wat::core::Vector :- [:wat::core::String]) (:wat::core::Vector :- [:wat::core::String]))
            st
            (:pie::fail (:wat::string::concat "check-same failed: " (:wat::core::ast->source (:pie::arg form 1))
                                              " and " (:wat::core::ast->source (:pie::arg form 2)))))))
      ((:pie::large? form)
        (:wat::core::let [tv (:pie::eval env (:pie::check-type ctx env form))]
          (:pie::St :ctx ctx :env env
                    :out (:wat::core::conj (:pie::St/out st) (:wat::core::ast->source (:pie::sugar (:pie::rb-type (:pie::used ctx) tv)))))))
      (:else
        (:wat::core::let [s (:pie::synth ctx env form)
                          t (:pie::syn-type s)
                          v (:pie::eval env (:pie::syn-core s))
                          used (:pie::used ctx)
                          shown (:pie::mk (:wat::core::Vector :- [:wat::WatAST] (:pie::sym "the") (:pie::sugar (:pie::rb-type used t)) (:pie::sugar (:pie::rb used t v))))]
          (:pie::St :ctx ctx :env env :out (:wat::core::conj (:pie::St/out st) (:wat::core::ast->source shown))))))))

(:wat::core::defn :pie::run-forms [st <- :pie::St forms <- :pie::Es] -> :pie::St
  (:wat::core::if (:wat::core::empty? forms)
    st
    (:pie::run-forms (:pie::run-form st (:wat::core::first forms)) (:wat::core::rest forms))))

(:wat::core::defn :pie::init [] -> :pie::St
  (:pie::St :ctx (:wat::core::quote ()) :env (:wat::core::quote ()) :out (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :pie::read-forms [text <- :wat::core::String] -> :pie::Es
  (:wat::core::match (:wat::core::read-string text)
    [:wat::core::ReadOutcome.Forms {:forms fs} (:pie::kids fs)]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:pie::fail (:wat::core::Error/message c))]))

;; A .pie file's text after its first line, #lang pie.
(:wat::core::defn :pie::file-body [path <- :wat::core::String] -> :wat::core::String
  (:wat::string::join "\n" (:wat::core::rest (:wat::string::split (:wat::io::read-file path) "\n"))))

;; Run a .pie file and give each expression's output.
(:wat::core::defn :pie::run-file [path <- :wat::core::String] -> :pie::Names
  (:pie::St/out (:pie::run-forms (:pie::init) (:pie::read-forms (:pie::file-body path)))))

(:wat::core::defn :pie::non-empty [xs <- :pie::Names] -> :pie::Names
  (:wat::core::if (:wat::core::empty? xs)
    (:wat::core::Vector :- [:wat::core::String])
    (:wat::core::let [rest (:pie::non-empty (:wat::core::rest xs))]
      (:wat::core::if (:wat::core::= (:wat::core::first xs) "") rest (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] (:wat::core::first xs)) rest)))))

(:wat::core::defn :pie::compare [got <- :pie::Names want <- :pie::Names] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? want)
    nil
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::first got) (:wat::core::first want))
      (:pie::compare (:wat::core::rest got) (:wat::core::rest want)))))

;; Run a chapter's .pie file and compare every output with Racket's Pie (the expected file).
(:wat::core::defn :pie::check-chapter [pie <- :wat::core::String expected <- :wat::core::String label <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [got (:pie::run-file pie)
                    want (:pie::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:pie::compare got want)
      (:wat::kernel::println (:wat::string::concat label ": ok")))))

;; ---- refusals: what Pie refuses, wat-Pie must refuse too
;;
;; A refusals file (tools/pie-oracle-refusals.sh) is cases separated by blank lines; each
;; case's last form must be refused and the forms before it are setup. A refusal is a
;; failed assertion somewhere inside the checker, so each refused form runs in a thread
;; (:wat::test::run-thread), whose death comes back as a value: RunResult.Failed.

(:wat::core::typealias :pie::Cases (:wat::core::Vector :- [:pie::Es]))

(:wat::core::defn :pie::cases [paras <- :pie::Names] -> :pie::Cases
  (:wat::core::if (:wat::core::empty? paras)
    (:wat::core::Vector :- [:pie::Es])
    (:wat::core::let [forms (:pie::read-forms (:wat::core::first paras))
                      more (:pie::cases (:wat::core::rest paras))]
      (:wat::core::if (:wat::core::empty? forms) more (:wat::core::concat (:wat::core::Vector :- [:pie::Es] forms) more)))))

(:wat::core::defn :pie::but-last [xs <- :pie::Es] -> :pie::Es
  (:wat::core::if (:wat::core::empty? (:wat::core::rest xs))
    (:wat::core::Vector :- [:wat::WatAST])
    (:wat::core::concat (:wat::core::Vector :- [:wat::WatAST] (:wat::core::first xs)) (:pie::but-last (:wat::core::rest xs)))))

(:wat::core::defn :pie::last [xs <- :pie::Es] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? (:wat::core::rest xs)) (:wat::core::first xs) (:pie::last (:wat::core::rest xs))))

;; Run a case's setup, then its last form in a thread; give wat-Pie's refusal message.
(:wat::core::defn :pie::refusal [case <- :pie::Es] -> :wat::core::String
  (:wat::core::let [st (:pie::run-forms (:pie::init) (:pie::but-last case))
                    form (:pie::last case)]
    (:wat::core::match (:wat::test::run-thread (:pie::run-form st form))
      [:wat::kernel::RunResult.Passed {}
        (:pie::fail (:wat::string::concat "accepted a form Pie refuses: " (:wat::core::ast->source form)))]
      [:wat::kernel::RunResult.Failed {:failure f} (:wat::kernel::Failure/message f)])))

(:wat::core::defn :pie::check-cases [cases <- :pie::Cases want <- :pie::Names] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? cases)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "  Pie " (:wat::core::first want) "; " (:pie::refusal (:wat::core::first cases))))
      (:pie::check-cases (:wat::core::rest cases) (:wat::core::rest want)))))

;; Every case of a chapter's refusals file must be refused, as Racket's Pie refuses it.
(:wat::core::defn :pie::check-refusals [pie <- :wat::core::String expected <- :wat::core::String label <- :wat::core::String] -> :wat::core::nil
  (:wat::core::let [cases (:pie::cases (:wat::string::split (:pie::file-body pie) "\n\n"))
                    want (:pie::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length cases) (:wat::core::length want))
      (:pie::check-cases cases want)
      (:wat::kernel::println (:wat::string::concat label " refusals: ok")))))
