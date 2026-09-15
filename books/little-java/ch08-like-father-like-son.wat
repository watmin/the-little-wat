;; A Little Java, A Few Patterns, chapter 8 (Like Father, Like Son).
;; An evaluator visitor for expressions: Java's IntEvalV (the father) owns the traversal
;; (forPlus, forDiff, forProd, forConst) and leaves the arithmetic to methods plus, diff and
;; prod; SetEvalV (the son) extends it, overrides only those three, and so evaluates the same
;; kind of expression over sets.
;;
;; In wat the visitor interface is a surface, (ExprVisitorI :- [C]), and each evaluator is a
;; struct that extend-types it. There is no inheritance, and a surface can't give a feature a
;; default body (defsurface takes only :nature, :messages and :features), so the son restates
;; the father's whole traversal, all four features, where Java's son writes three one-line
;; overrides and inherits the rest. Expressions are generic over their constants,
;; (ExprD :- [C]); accept is written once per constant type (F-029).
;; Results are printed as the Java oracle's are (oracle/java/ch08-like-father-like-son.java,
;; run by tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch08-like-father-like-son.wat

(:wat::load-file! "lib/check.wat")

;; ---- sets of integers

(:wat::core::defenum :lj::SetD :wat::enum::Pure
  :Empty []
  :Add [i <- :wat::core::i64  s <- :lj::SetD])

(:wat::core::defn :lj::empty [] -> :lj::SetD (:lj::SetD.Empty {}))

(:wat::core::defn :lj::mem? [s <- :lj::SetD n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::match s
    [:lj::SetD.Empty {} false]
    [:lj::SetD.Add {:i i :s rest} (:wat::core::if (:wat::core::= i n) true (:lj::mem? rest n))]))

;; add i, unless it is there already
(:wat::core::defn :lj::add [s <- :lj::SetD i <- :wat::core::i64] -> :lj::SetD
  (:wat::core::if (:lj::mem? s i) s (:lj::SetD.Add {:i i :s s})))

;; union, difference, intersection, as the oracle's SetD computes them
(:wat::core::defn :lj::set-plus [s <- :lj::SetD t <- :lj::SetD] -> :lj::SetD
  (:wat::core::match s
    [:lj::SetD.Empty {} t]
    [:lj::SetD.Add {:i i :s rest} (:lj::set-plus rest (:lj::add t i))]))

(:wat::core::defn :lj::set-diff [s <- :lj::SetD t <- :lj::SetD] -> :lj::SetD
  (:wat::core::match s
    [:lj::SetD.Empty {} (:lj::empty)]
    [:lj::SetD.Add {:i i :s rest} (:wat::core::if (:lj::mem? t i) (:lj::set-diff rest t) (:lj::add (:lj::set-diff rest t) i))]))

(:wat::core::defn :lj::set-prod [s <- :lj::SetD t <- :lj::SetD] -> :lj::SetD
  (:wat::core::match s
    [:lj::SetD.Empty {} (:lj::empty)]
    [:lj::SetD.Add {:i i :s rest} (:wat::core::if (:lj::mem? t i) (:lj::add (:lj::set-prod rest t) i) (:lj::set-prod rest t))]))

(:wat::core::defn :lj::show-set [s <- :lj::SetD] -> :wat::core::String
  (:wat::core::match s
    [:lj::SetD.Empty {} "(Empty)"]
    [:lj::SetD.Add {:i i :s rest} (:wat::string::concat "(Add " (:wat::i64::to-string i) " " (:lj::show-set rest) ")")]))

;; ---- expressions, generic over their constants

(:wat::core::defenum :lj::ExprD :- [C] :wat::enum::Pure
  :Plus [l <- (:lj::ExprD :- [C])  r <- (:lj::ExprD :- [C])]
  :Diff [l <- (:lj::ExprD :- [C])  r <- (:lj::ExprD :- [C])]
  :Prod [l <- (:lj::ExprD :- [C])  r <- (:lj::ExprD :- [C])]
  :Const [c <- C])

(:wat::core::defn :lj::plus :- [C] [l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> (:lj::ExprD :- [C]) (:lj::ExprD.Plus {:l l :r r}))
(:wat::core::defn :lj::diff :- [C] [l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> (:lj::ExprD :- [C]) (:lj::ExprD.Diff {:l l :r r}))
(:wat::core::defn :lj::prod :- [C] [l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> (:lj::ExprD :- [C]) (:lj::ExprD.Prod {:l l :r r}))
(:wat::core::defn :lj::const :- [C] [c <- C] -> (:lj::ExprD :- [C]) (:lj::ExprD.Const {:c c}))

;; the protocol
(:wat::core::defsurface :lj::ExprVisitorI :- [C] :nature :wat::core::Struct
  :features [(for-plus [self <- (:lj::ExprVisitorI :- [C]) l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> C)
             (for-diff [self <- (:lj::ExprVisitorI :- [C]) l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> C)
             (for-prod [self <- (:lj::ExprVisitorI :- [C]) l <- (:lj::ExprD :- [C]) r <- (:lj::ExprD :- [C])] -> C)
             (for-const [self <- (:lj::ExprVisitorI :- [C]) c <- C] -> C)])

;; one accept per constant type (F-029)
(:wat::core::defn :lj::accept-int [e <- (:lj::ExprD :- [:wat::core::i64]) ask <- (:lj::ExprVisitorI :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::match e
    [:lj::ExprD.Plus {:l l :r r} (:lj::ExprVisitorI/for-plus ask l r)]
    [:lj::ExprD.Diff {:l l :r r} (:lj::ExprVisitorI/for-diff ask l r)]
    [:lj::ExprD.Prod {:l l :r r} (:lj::ExprVisitorI/for-prod ask l r)]
    [:lj::ExprD.Const {:c c} (:lj::ExprVisitorI/for-const ask c)]))

(:wat::core::defn :lj::accept-set [e <- (:lj::ExprD :- [:lj::SetD]) ask <- (:lj::ExprVisitorI :- [:lj::SetD])] -> :lj::SetD
  (:wat::core::match e
    [:lj::ExprD.Plus {:l l :r r} (:lj::ExprVisitorI/for-plus ask l r)]
    [:lj::ExprD.Diff {:l l :r r} (:lj::ExprVisitorI/for-diff ask l r)]
    [:lj::ExprD.Prod {:l l :r r} (:lj::ExprVisitorI/for-prod ask l r)]
    [:lj::ExprD.Const {:c c} (:lj::ExprVisitorI/for-const ask c)]))

;; the father: the traversal, and integer arithmetic
(:wat::core::defstruct :lj::IntEvalV [])
(:wat::core::extend-type :lj::IntEvalV (:lj::ExprVisitorI :- [:wat::core::i64])
  (for-plus [self l r] -> :wat::core::i64 (:wat::core::+ (:lj::accept-int l self) (:lj::accept-int r self)))
  (for-diff [self l r] -> :wat::core::i64 (:wat::core::- (:lj::accept-int l self) (:lj::accept-int r self)))
  (for-prod [self l r] -> :wat::core::i64 (:wat::core::* (:lj::accept-int l self) (:lj::accept-int r self)))
  (for-const [self c] -> :wat::core::i64 c))

;; the son: Java's SetEvalV overrides plus, diff and prod and inherits the rest; here every
;; feature is written again, the traversal and for-const included
(:wat::core::defstruct :lj::SetEvalV [])
(:wat::core::extend-type :lj::SetEvalV (:lj::ExprVisitorI :- [:lj::SetD])
  (for-plus [self l r] -> :lj::SetD (:lj::set-plus (:lj::accept-set l self) (:lj::accept-set r self)))
  (for-diff [self l r] -> :lj::SetD (:lj::set-diff (:lj::accept-set l self) (:lj::accept-set r self)))
  (for-prod [self l r] -> :lj::SetD (:lj::set-prod (:lj::accept-set l self) (:lj::accept-set r self)))
  (for-const [self c] -> :lj::SetD c))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [s123 (:lj::add (:lj::add (:lj::add (:lj::empty) 3) 2) 1)
                    s24 (:lj::add (:lj::add (:lj::empty) 4) 2)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    set :lj::show-set]
    (:lj::check-chapter "oracle/java/ch08-like-father-like-son.expected"
                        "little-java ch08 like-father-like-son"
                        (:wat::core::Vector :- [:wat::core::String]
                          (set s123)
                          (set (:lj::add s123 2))
                          (:lj::show-bool (:lj::mem? s123 2))
                          (:lj::show-bool (:lj::mem? s123 5))
                          (set (:lj::set-plus s123 s24))
                          (set (:lj::set-diff s123 s24))
                          (set (:lj::set-prod s123 s24))
                          (int (:lj::accept-int (:lj::plus (:lj::const 7) (:lj::prod (:lj::const 4) (:lj::const 5))) (:lj::IntEvalV)))
                          (int (:lj::accept-int (:lj::diff (:lj::const 10) (:lj::plus (:lj::const 2) (:lj::const 3))) (:lj::IntEvalV)))
                          (set (:lj::accept-set (:lj::plus (:lj::const s123) (:lj::const s24)) (:lj::SetEvalV)))
                          (set (:lj::accept-set (:lj::diff (:lj::const s123) (:lj::prod (:lj::const s24) (:lj::const (:lj::add (:lj::empty) 2)))) (:lj::SetEvalV)))
                          (set (:lj::accept-set (:lj::prod (:lj::plus (:lj::const s24) (:lj::const (:lj::add (:lj::empty) 9))) (:lj::const s123)) (:lj::SetEvalV)))))))
