;; A Little Java, A Few Patterns, chapter 5 (Objects Are People, Too).
;; Java's pies hold any Object in each layer (fish in one pie, integers in another); in wat a
;; pie is generic, (PieD :- [T]), and one pie holds one type. The visitors' methods take extra
;; arguments (what to remove, what to put in its place), and compare with equals; here = does.
;; Printing a pie needs its layers' printer passed in: Java's toString dispatches on Object,
;; and wat has no ambient protocol for that.
;; Results are printed as the Java oracle's are (oracle/java/ch05-objects-are-people-too.java,
;; run by tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch05-objects-are-people-too.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :lj::FishD :wat::enum::Pure :Anchovy [] :Salmon [] :Tuna [])

;; A variant constructor keeps its narrowed type (F-019): (:lj::FishD.Anchovy {}) is a
;; FishD.Anchovy, so a pie of an anchovy and a tuna won't unify, and (= anchovy tuna) is refused
;; outright (probes/java/variant-equality*.wat). These helpers' declared type widens them.
(:wat::core::defn :lj::anchovy [] -> :lj::FishD (:lj::FishD.Anchovy {}))
(:wat::core::defn :lj::salmon [] -> :lj::FishD (:lj::FishD.Salmon {}))
(:wat::core::defn :lj::tuna [] -> :lj::FishD (:lj::FishD.Tuna {}))

(:wat::core::defenum :lj::PieD :- [T] :wat::enum::Pure
  :Bot []
  :Top [t <- T  r <- (:lj::PieD :- [T])])

(:wat::core::defn :lj::bot :- [T] [] -> (:lj::PieD :- [T]) (:lj::PieD.Bot {}))
(:wat::core::defn :lj::top :- [T] [t <- T r <- (:lj::PieD :- [T])] -> (:lj::PieD :- [T]) (:lj::PieD.Top {:t t :r r}))

;; ---- the visitors: a function per variant, taking the method's extra arguments

(:wat::core::defstruct :lj::RemV :- [T]
  [for-bot <- [T :-> (:lj::PieD :- [T])]
   for-top <- [T (:lj::PieD :- [T]) T :-> (:lj::PieD :- [T])]])

(:wat::core::defstruct :lj::SubstV :- [T]
  [for-bot <- [T T :-> (:lj::PieD :- [T])]
   for-top <- [T (:lj::PieD :- [T]) T T :-> (:lj::PieD :- [T])]])

(:wat::core::defn :lj::rem-v :- [T] [] -> (:lj::RemV :- [T])
  (:lj::RemV :for-bot (:wat::core::fn [o <- T] -> (:lj::PieD :- [T]) (:lj::bot))
             :for-top (:wat::core::fn [t <- T r <- (:lj::PieD :- [T]) o <- T] -> (:lj::PieD :- [T])
                        (:wat::core::if (:wat::core::= o t) (:lj::rem r o) (:lj::top t (:lj::rem r o))))))

(:wat::core::defn :lj::subst-v :- [T] [] -> (:lj::SubstV :- [T])
  (:lj::SubstV :for-bot (:wat::core::fn [n <- T o <- T] -> (:lj::PieD :- [T]) (:lj::bot))
               :for-top (:wat::core::fn [t <- T r <- (:lj::PieD :- [T]) n <- T o <- T] -> (:lj::PieD :- [T])
                          (:wat::core::if (:wat::core::= o t) (:lj::top n (:lj::subst r n o)) (:lj::top t (:lj::subst r n o))))))

(:wat::core::defn :lj::rem :- [T] [p <- (:lj::PieD :- [T]) o <- T] -> (:lj::PieD :- [T])
  (:wat::core::match p
    [:lj::PieD.Bot {} ((:lj::RemV/for-bot (:lj::rem-v)) o)]
    [:lj::PieD.Top {:t t :r r} ((:lj::RemV/for-top (:lj::rem-v)) t r o)]))

(:wat::core::defn :lj::subst :- [T] [p <- (:lj::PieD :- [T]) n <- T o <- T] -> (:lj::PieD :- [T])
  (:wat::core::match p
    [:lj::PieD.Bot {} ((:lj::SubstV/for-bot (:lj::subst-v)) n o)]
    [:lj::PieD.Top {:t t :r r} ((:lj::SubstV/for-top (:lj::subst-v)) t r n o)]))

;; ---- printing

(:wat::core::defn :lj::show-fish [f <- :lj::FishD] -> :wat::core::String
  (:wat::core::match f
    [:lj::FishD.Anchovy {} "(Anchovy)"]
    [:lj::FishD.Salmon {} "(Salmon)"]
    [:lj::FishD.Tuna {} "(Tuna)"]))

(:wat::core::defn :lj::show-int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :lj::show-pie :- [T] [show-t <- [T :-> :wat::core::String] p <- (:lj::PieD :- [T])] -> :wat::core::String
  (:wat::core::match p
    [:lj::PieD.Bot {} "(Bot)"]
    [:lj::PieD.Top {:t t :r r} (:wat::string::concat "(Top " (show-t t) " " (:lj::show-pie show-t r) ")")]))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [anchovy (:lj::anchovy)
                    salmon (:lj::salmon)
                    tuna (:lj::tuna)
                    fish-pie (:lj::top anchovy (:lj::top tuna (:lj::top anchovy (:lj::bot))))
                    num-pie (:lj::top 3 (:lj::top 2 (:lj::top 3 (:lj::bot))))
                    fish (:wat::core::fn [p <- (:lj::PieD :- [:lj::FishD])] -> :wat::core::String (:lj::show-pie :lj::show-fish p))
                    nums (:wat::core::fn [p <- (:lj::PieD :- [:wat::core::i64])] -> :wat::core::String (:lj::show-pie :lj::show-int p))]
    (:lj::check-chapter "oracle/java/ch05-objects-are-people-too.expected"
                        "little-java ch05 objects-are-people-too"
                        (:wat::core::Vector :- [:wat::core::String]
                          (:lj::show-bool (:wat::core::= anchovy (:lj::anchovy)))
                          (:lj::show-bool (:wat::core::= anchovy tuna))
                          (fish fish-pie)
                          (fish (:lj::rem fish-pie anchovy))
                          (fish (:lj::rem fish-pie tuna))
                          (fish (:lj::rem fish-pie salmon))
                          (fish (:lj::subst fish-pie salmon anchovy))
                          (fish (:lj::subst fish-pie tuna tuna))
                          (nums num-pie)
                          (nums (:lj::rem num-pie 3))
                          (nums (:lj::rem num-pie 2))
                          (nums (:lj::subst num-pie 5 3))
                          (nums (:lj::rem (:lj::subst num-pie 5 3) 5))
                          (nums (:lj::rem (:lj::bot) 7))))))
