;; A Little Java, A Few Patterns, chapter 1 (Modern Toys).
;; The chapter's datatypes in wat: where Java has an abstract class per type and a concrete class
;; per variant, wat has an enum per type and a variant per class. Each value prints as the same
;; S-expression the Java oracle's toString gives (oracle/java/ch01-modern-toys.java, run by
;; tools/java-oracle.sh), and every result must match, in order.
;;
;; Java's Base holds any Object at all. wat bans :Any, so a layer's base is a Thing: a sum of
;; the kinds of value a base is given here (the toys so far, a number, a boolean).
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch01-modern-toys.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :lj::SeasoningD :wat::enum::Pure
  :Salt [] :Pepper [] :Thyme [] :Sage [])

(:wat::core::defenum :lj::PointD :wat::enum::Pure
  :CartesianPt [x <- :wat::core::i64 y <- :wat::core::i64]
  :ManhattanPt [x <- :wat::core::i64 y <- :wat::core::i64])

(:wat::core::defenum :lj::NumD :wat::enum::Pure
  :Zero []
  :OneMoreThan [predecessor <- :lj::NumD])

;; What a Base may hold: Java's Object, narrowed to what this chapter gives it.
(:wat::core::defenum :lj::Thing :wat::enum::Pure
  :Seasoning [s <- :lj::SeasoningD]
  :Point [p <- :lj::PointD]
  :Num [n <- :lj::NumD]
  :Int [i <- :wat::core::i64]
  :Bool [b <- :wat::core::bool])

(:wat::core::defenum :lj::LayerD :wat::enum::Pure
  :Base [o <- :lj::Thing]
  :Slice [l <- :lj::LayerD])

;; ---- printing, as the Java toStrings do

(:wat::core::defn :lj::show-seasoning [s <- :lj::SeasoningD] -> :wat::core::String
  (:wat::core::match s
    [:lj::SeasoningD.Salt {} "(Salt)"]
    [:lj::SeasoningD.Pepper {} "(Pepper)"]
    [:lj::SeasoningD.Thyme {} "(Thyme)"]
    [:lj::SeasoningD.Sage {} "(Sage)"]))

(:wat::core::defn :lj::show-point [p <- :lj::PointD] -> :wat::core::String
  (:wat::core::match p
    [:lj::PointD.CartesianPt {:x x :y y} (:wat::string::concat "(CartesianPt " (:wat::i64::to-string x) " " (:wat::i64::to-string y) ")")]
    [:lj::PointD.ManhattanPt {:x x :y y} (:wat::string::concat "(ManhattanPt " (:wat::i64::to-string x) " " (:wat::i64::to-string y) ")")]))

(:wat::core::defn :lj::show-num [n <- :lj::NumD] -> :wat::core::String
  (:wat::core::match n
    [:lj::NumD.Zero {} "(Zero)"]
    [:lj::NumD.OneMoreThan {:predecessor p} (:wat::string::concat "(OneMoreThan " (:lj::show-num p) ")")]))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :lj::show-thing [t <- :lj::Thing] -> :wat::core::String
  (:wat::core::match t
    [:lj::Thing.Seasoning {:s s} (:lj::show-seasoning s)]
    [:lj::Thing.Point {:p p} (:lj::show-point p)]
    [:lj::Thing.Num {:n n} (:lj::show-num n)]
    [:lj::Thing.Int {:i i} (:wat::i64::to-string i)]
    [:lj::Thing.Bool {:b b} (:lj::show-bool b)]))

(:wat::core::defn :lj::show-layer [l <- :lj::LayerD] -> :wat::core::String
  (:wat::core::match l
    [:lj::LayerD.Base {:o o} (:wat::string::concat "(Base " (:lj::show-thing o) ")")]
    [:lj::LayerD.Slice {:l inner} (:wat::string::concat "(Slice " (:lj::show-layer inner) ")")]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [zero (:lj::NumD.Zero {})
                    one-more (:wat::core::fn [n <- :lj::NumD] -> :lj::NumD (:lj::NumD.OneMoreThan {:predecessor n}))]
    (:lj::check-chapter "oracle/java/ch01-modern-toys.expected"
                        "little-java ch01 modern-toys"
                        (:wat::core::Vector :- [:wat::core::String]
                          (:lj::show-seasoning (:lj::SeasoningD.Salt {}))
                          (:lj::show-seasoning (:lj::SeasoningD.Pepper {}))
                          (:lj::show-seasoning (:lj::SeasoningD.Thyme {}))
                          (:lj::show-seasoning (:lj::SeasoningD.Sage {}))
                          (:lj::show-point (:lj::PointD.CartesianPt {:x 2 :y 3}))
                          (:lj::show-point (:lj::PointD.ManhattanPt {:x 2 :y 3}))
                          (:lj::show-point (:lj::PointD.CartesianPt {:x -1 :y 0}))
                          (:lj::show-num zero)
                          (:lj::show-num (one-more zero))
                          (:lj::show-num (one-more (one-more (one-more zero))))
                          (:lj::show-layer (:lj::LayerD.Base {:o (:lj::Thing.Num {:n zero})}))
                          (:lj::show-layer (:lj::LayerD.Base {:o (:lj::Thing.Seasoning {:s (:lj::SeasoningD.Salt {})})}))
                          (:lj::show-layer (:lj::LayerD.Base {:o (:lj::Thing.Int {:i 5})}))
                          (:lj::show-layer (:lj::LayerD.Base {:o (:lj::Thing.Bool {:b true})}))
                          (:lj::show-layer (:lj::LayerD.Slice {:l (:lj::LayerD.Base {:o (:lj::Thing.Point {:p (:lj::PointD.CartesianPt {:x 1 :y 2})})})}))
                          (:lj::show-layer (:lj::LayerD.Slice {:l (:lj::LayerD.Slice {:l (:lj::LayerD.Base {:o (:lj::Thing.Num {:n (one-more zero)})})})}))
                          ;; every value of a variant is a value of its type: in wat the checker says so,
                          ;; and a Salt is never a NumD, so neither question needs asking at runtime
                          (:lj::show-bool true)
                          (:lj::show-bool false)))))
