;; A Little Java, A Few Patterns, chapter 7 (Oh My!).
;; Trees of fruit, and visitors whose answers are of different types: a boolean, an int, a
;; tree. Java's one visitor interface answers Object, so there is one accept, and every use
;; casts its answer back: the "oh my". In wat the interface is a surface over the answer type,
;; (TreeVisitorI :- [R]), and each visitor is a struct extending it at its own R; no casts.
;;
;; But wat can't write the one accept either: a function generic over the surface refuses a
;; struct that extends it at a concrete R (F-029; probes/java/visitor-surface-generic.wat). So
;; there is an accept per answer type (accept-bool, accept-int, accept-tree), with identical
;; bodies: the shape of the book's Java before this chapter, one visitor interface per result
;; type, which the chapter sets out to remove.
;; Results are printed as the Java oracle's are (oracle/java/ch07-oh-my.java, run by
;; tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch07-oh-my.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :lj::FruitD :wat::enum::Pure :Peach [] :Apple [] :Pear [] :Fig [])

;; widened constructors (a bare variant keeps its narrowed type, F-019)
(:wat::core::defn :lj::peach [] -> :lj::FruitD (:lj::FruitD.Peach {}))
(:wat::core::defn :lj::apple [] -> :lj::FruitD (:lj::FruitD.Apple {}))
(:wat::core::defn :lj::pear [] -> :lj::FruitD (:lj::FruitD.Pear {}))
(:wat::core::defn :lj::fig [] -> :lj::FruitD (:lj::FruitD.Fig {}))

(:wat::core::defenum :lj::TreeD :wat::enum::Pure
  :Bud []
  :Flat [f <- :lj::FruitD  t <- :lj::TreeD]
  :Split [l <- :lj::TreeD  r <- :lj::TreeD])

(:wat::core::defn :lj::bud [] -> :lj::TreeD (:lj::TreeD.Bud {}))
(:wat::core::defn :lj::flat [f <- :lj::FruitD t <- :lj::TreeD] -> :lj::TreeD (:lj::TreeD.Flat {:f f :t t}))
(:wat::core::defn :lj::split [l <- :lj::TreeD r <- :lj::TreeD] -> :lj::TreeD (:lj::TreeD.Split {:l l :r r}))

;; the protocol, over the answer type
(:wat::core::defsurface :lj::TreeVisitorI :- [R] :nature :wat::core::Struct
  :features [(for-bud [self <- (:lj::TreeVisitorI :- [R])] -> R)
             (for-flat [self <- (:lj::TreeVisitorI :- [R]) f <- :lj::FruitD t <- :lj::TreeD] -> R)
             (for-split [self <- (:lj::TreeVisitorI :- [R]) l <- :lj::TreeD r <- :lj::TreeD] -> R)])

;; one accept per answer type (F-029)
(:wat::core::defn :lj::accept-bool [t <- :lj::TreeD ask <- (:lj::TreeVisitorI :- [:wat::core::bool])] -> :wat::core::bool
  (:wat::core::match t
    [:lj::TreeD.Bud {} (:lj::TreeVisitorI/for-bud ask)]
    [:lj::TreeD.Flat {:f f :t rest} (:lj::TreeVisitorI/for-flat ask f rest)]
    [:lj::TreeD.Split {:l l :r r} (:lj::TreeVisitorI/for-split ask l r)]))

(:wat::core::defn :lj::accept-int [t <- :lj::TreeD ask <- (:lj::TreeVisitorI :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::match t
    [:lj::TreeD.Bud {} (:lj::TreeVisitorI/for-bud ask)]
    [:lj::TreeD.Flat {:f f :t rest} (:lj::TreeVisitorI/for-flat ask f rest)]
    [:lj::TreeD.Split {:l l :r r} (:lj::TreeVisitorI/for-split ask l r)]))

(:wat::core::defn :lj::accept-tree [t <- :lj::TreeD ask <- (:lj::TreeVisitorI :- [:lj::TreeD])] -> :lj::TreeD
  (:wat::core::match t
    [:lj::TreeD.Bud {} (:lj::TreeVisitorI/for-bud ask)]
    [:lj::TreeD.Flat {:f f :t rest} (:lj::TreeVisitorI/for-flat ask f rest)]
    [:lj::TreeD.Split {:l l :r r} (:lj::TreeVisitorI/for-split ask l r)]))

;; ---- the visitors

(:wat::core::defstruct :lj::IsFlatV [])
(:wat::core::extend-type :lj::IsFlatV (:lj::TreeVisitorI :- [:wat::core::bool])
  (for-bud [self] -> :wat::core::bool true)
  (for-flat [self f t] -> :wat::core::bool (:lj::accept-bool t self))
  (for-split [self l r] -> :wat::core::bool false))

(:wat::core::defstruct :lj::IsSplitV [])
(:wat::core::extend-type :lj::IsSplitV (:lj::TreeVisitorI :- [:wat::core::bool])
  (for-bud [self] -> :wat::core::bool true)
  (for-flat [self f t] -> :wat::core::bool false)
  (for-split [self l r] -> :wat::core::bool
    (:wat::core::if (:lj::accept-bool l self) (:lj::accept-bool r self) false)))

(:wat::core::defstruct :lj::HasFruitV [])
(:wat::core::extend-type :lj::HasFruitV (:lj::TreeVisitorI :- [:wat::core::bool])
  (for-bud [self] -> :wat::core::bool false)
  (for-flat [self f t] -> :wat::core::bool true)
  (for-split [self l r] -> :wat::core::bool
    (:wat::core::if (:lj::accept-bool l self) true (:lj::accept-bool r self))))

(:wat::core::defstruct :lj::HeightV [])
(:wat::core::extend-type :lj::HeightV (:lj::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0)
  (for-flat [self f t] -> :wat::core::i64 (:wat::core::+ 1 (:lj::accept-int t self)))
  (for-split [self l r] -> :wat::core::i64
    (:wat::core::let [hl (:lj::accept-int l self)
                      hr (:lj::accept-int r self)]
      (:wat::core::+ 1 (:wat::core::if (:wat::core::> hl hr) hl hr)))))

(:wat::core::defstruct :lj::OccursV [a <- :lj::FruitD])
(:wat::core::extend-type :lj::OccursV (:lj::TreeVisitorI :- [:wat::core::i64])
  (for-bud [self] -> :wat::core::i64 0)
  (for-flat [self f t] -> :wat::core::i64
    (:wat::core::let [rest (:lj::accept-int t self)]
      (:wat::core::if (:wat::core::= (:lj::OccursV/a self) f) (:wat::core::+ 1 rest) rest)))
  (for-split [self l r] -> :wat::core::i64 (:wat::core::+ (:lj::accept-int l self) (:lj::accept-int r self))))

(:wat::core::defstruct :lj::SubstV [n <- :lj::FruitD  o <- :lj::FruitD])
(:wat::core::extend-type :lj::SubstV (:lj::TreeVisitorI :- [:lj::TreeD])
  (for-bud [self] -> :lj::TreeD (:lj::bud))
  (for-flat [self f t] -> :lj::TreeD
    (:lj::flat (:wat::core::if (:wat::core::= (:lj::SubstV/o self) f) (:lj::SubstV/n self) f) (:lj::accept-tree t self)))
  (for-split [self l r] -> :lj::TreeD (:lj::split (:lj::accept-tree l self) (:lj::accept-tree r self))))

;; ---- printing

(:wat::core::defn :lj::show-fruit [f <- :lj::FruitD] -> :wat::core::String
  (:wat::core::match f
    [:lj::FruitD.Peach {} "(Peach)"]
    [:lj::FruitD.Apple {} "(Apple)"]
    [:lj::FruitD.Pear {} "(Pear)"]
    [:lj::FruitD.Fig {} "(Fig)"]))

(:wat::core::defn :lj::show-tree [t <- :lj::TreeD] -> :wat::core::String
  (:wat::core::match t
    [:lj::TreeD.Bud {} "(Bud)"]
    [:lj::TreeD.Flat {:f f :t rest} (:wat::string::concat "(Flat " (:lj::show-fruit f) " " (:lj::show-tree rest) ")")]
    [:lj::TreeD.Split {:l l :r r} (:wat::string::concat "(Split " (:lj::show-tree l) " " (:lj::show-tree r) ")")]))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [flat (:lj::flat (:lj::apple) (:lj::flat (:lj::peach) (:lj::bud)))
                    split (:lj::split (:lj::split (:lj::bud) (:lj::bud)) (:lj::split (:lj::bud) (:lj::split (:lj::bud) (:lj::bud))))
                    mixed (:lj::split (:lj::flat (:lj::fig) (:lj::flat (:lj::apple) (:lj::bud)))
                                      (:lj::split (:lj::flat (:lj::fig) (:lj::bud)) (:lj::bud)))
                    bool :lj::show-bool
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:lj::check-chapter "oracle/java/ch07-oh-my.expected"
                        "little-java ch07 oh-my"
                        (:wat::core::Vector :- [:wat::core::String]
                          (bool (:lj::accept-bool flat (:lj::IsFlatV)))
                          (bool (:lj::accept-bool split (:lj::IsFlatV)))
                          (bool (:lj::accept-bool split (:lj::IsSplitV)))
                          (bool (:lj::accept-bool mixed (:lj::IsSplitV)))
                          (bool (:lj::accept-bool split (:lj::HasFruitV)))
                          (bool (:lj::accept-bool mixed (:lj::HasFruitV)))
                          (int (:lj::accept-int flat (:lj::HeightV)))
                          (int (:lj::accept-int split (:lj::HeightV)))
                          (int (:lj::accept-int mixed (:lj::HeightV)))
                          (int (:lj::accept-int mixed (:lj::OccursV :a (:lj::fig))))
                          (int (:lj::accept-int mixed (:lj::OccursV :a (:lj::pear))))
                          (:lj::show-tree (:lj::accept-tree mixed (:lj::SubstV :n (:lj::pear) :o (:lj::fig))))
                          (int (:lj::accept-int (:lj::accept-tree mixed (:lj::SubstV :n (:lj::pear) :o (:lj::fig))) (:lj::OccursV :a (:lj::pear))))))))
