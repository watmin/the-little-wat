;; A Little Java, A Few Patterns, chapter 2 (Methods to Our Madness).
;; A Java method with one body per variant is a wat function with one match arm per variant. A
;; method the abstract class defines once and every variant inherits (closerToO, minus) is one
;; wat function over the whole enum: wat has no inheritance, and needs none for that.
;; Results are printed as the Java oracle's are (oracle/java/ch02-methods-to-our-madness.java,
;; run by tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch02-methods-to-our-madness.wat

(:wat::load-file! "lib/check.wat")

;; ---- points

(:wat::core::defenum :lj::PointD :wat::enum::Pure
  :CartesianPt [x <- :wat::core::i64 y <- :wat::core::i64]
  :ManhattanPt [x <- :wat::core::i64 y <- :wat::core::i64])

;; Java's (int) Math.sqrt(...): the square root, truncated. wat's conversion answers an Option.
(:wat::core::defn :lj::int-sqrt [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::f64::to-i64 (:wat::math::sqrt (:wat::i64::to-f64 n)))
    [:wat::core::Option.Some {:value k} k]
    [:wat::core::Option.None {} (:wat::kernel::assertion-failed! :message "a square root out of i64's range")]))

(:wat::core::defn :lj::distance-to-o [p <- :lj::PointD] -> :wat::core::i64
  (:wat::core::match p
    [:lj::PointD.CartesianPt {:x x :y y} (:lj::int-sqrt (:wat::core::+ (:wat::core::* x x) (:wat::core::* y y)))]
    [:lj::PointD.ManhattanPt {:x x :y y} (:wat::core::+ x y)]))

;; the fields every point has (Java moves them up into the abstract class)
(:wat::core::defn :lj::pt-x [p <- :lj::PointD] -> :wat::core::i64
  (:wat::core::match p [:lj::PointD.CartesianPt {:x x :y y} x] [:lj::PointD.ManhattanPt {:x x :y y} x]))
(:wat::core::defn :lj::pt-y [p <- :lj::PointD] -> :wat::core::i64
  (:wat::core::match p [:lj::PointD.CartesianPt {:x x :y y} y] [:lj::PointD.ManhattanPt {:x x :y y} y]))

;; defined once for every kind of point
(:wat::core::defn :lj::closer-to-o [p <- :lj::PointD q <- :lj::PointD] -> :wat::core::bool
  (:wat::core::<= (:lj::distance-to-o p) (:lj::distance-to-o q)))

(:wat::core::defn :lj::minus [p <- :lj::PointD q <- :lj::PointD] -> :lj::PointD
  (:lj::PointD.CartesianPt {:x (:wat::core::- (:lj::pt-x p) (:lj::pt-x q)) :y (:wat::core::- (:lj::pt-y p) (:lj::pt-y q))}))

(:wat::core::defn :lj::show-point [p <- :lj::PointD] -> :wat::core::String
  (:wat::core::match p
    [:lj::PointD.CartesianPt {:x x :y y} (:wat::string::concat "(CartesianPt " (:wat::i64::to-string x) " " (:wat::i64::to-string y) ")")]
    [:lj::PointD.ManhattanPt {:x x :y y} (:wat::string::concat "(ManhattanPt " (:wat::i64::to-string x) " " (:wat::i64::to-string y) ")")]))

;; ---- shish kebabs

(:wat::core::defenum :lj::ShishD :wat::enum::Pure
  :Skewer []
  :Onion [s <- :lj::ShishD]
  :Lamb [s <- :lj::ShishD]
  :Tomato [s <- :lj::ShishD])

(:wat::core::defn :lj::only-onions? [s <- :lj::ShishD] -> :wat::core::bool
  (:wat::core::match s
    [:lj::ShishD.Skewer {} true]
    [:lj::ShishD.Onion {:s rest} (:lj::only-onions? rest)]
    [:lj::ShishD.Lamb {:s rest} false]
    [:lj::ShishD.Tomato {:s rest} false]))

(:wat::core::defn :lj::vegetarian? [s <- :lj::ShishD] -> :wat::core::bool
  (:wat::core::match s
    [:lj::ShishD.Skewer {} true]
    [:lj::ShishD.Onion {:s rest} (:lj::vegetarian? rest)]
    [:lj::ShishD.Lamb {:s rest} false]
    [:lj::ShishD.Tomato {:s rest} (:lj::vegetarian? rest)]))

;; ---- kebabs, whose holder is a rod or a plate (Java's Object, narrowed to those)

(:wat::core::defenum :lj::RodD :wat::enum::Pure :Dagger [] :Sabre [])
(:wat::core::defenum :lj::PlateD :wat::enum::Pure :Gold [] :Wood [])
(:wat::core::defenum :lj::HolderThing :wat::enum::Pure
  :Rod [r <- :lj::RodD]
  :Plate [p <- :lj::PlateD])

(:wat::core::defenum :lj::KebabD :wat::enum::Pure
  :Holder [o <- :lj::HolderThing]
  :Shallot [k <- :lj::KebabD]
  :Shrimp [k <- :lj::KebabD]
  :Radish [k <- :lj::KebabD]
  :Zucchini [k <- :lj::KebabD])

(:wat::core::defn :lj::veggie? [k <- :lj::KebabD] -> :wat::core::bool
  (:wat::core::match k
    [:lj::KebabD.Holder {:o o} true]
    [:lj::KebabD.Shallot {:k rest} (:lj::veggie? rest)]
    [:lj::KebabD.Shrimp {:k rest} false]
    [:lj::KebabD.Radish {:k rest} (:lj::veggie? rest)]
    [:lj::KebabD.Zucchini {:k rest} (:lj::veggie? rest)]))

(:wat::core::defn :lj::what-holder [k <- :lj::KebabD] -> :lj::HolderThing
  (:wat::core::match k
    [:lj::KebabD.Holder {:o o} o]
    [:lj::KebabD.Shallot {:k rest} (:lj::what-holder rest)]
    [:lj::KebabD.Shrimp {:k rest} (:lj::what-holder rest)]
    [:lj::KebabD.Radish {:k rest} (:lj::what-holder rest)]
    [:lj::KebabD.Zucchini {:k rest} (:lj::what-holder rest)]))

(:wat::core::defn :lj::show-holder [h <- :lj::HolderThing] -> :wat::core::String
  (:wat::core::match h
    [:lj::HolderThing.Rod {:r r} (:wat::core::match r [:lj::RodD.Dagger {} "(Dagger)"] [:lj::RodD.Sabre {} "(Sabre)"])]
    [:lj::HolderThing.Plate {:p p} (:wat::core::match p [:lj::PlateD.Gold {} "(Gold)"] [:lj::PlateD.Wood {} "(Wood)"])]))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [cart (:wat::core::fn [x <- :wat::core::i64 y <- :wat::core::i64] -> :lj::PointD (:lj::PointD.CartesianPt {:x x :y y}))
                    manh (:wat::core::fn [x <- :wat::core::i64 y <- :wat::core::i64] -> :lj::PointD (:lj::PointD.ManhattanPt {:x x :y y}))
                    ;; a builtin verb isn't a callable value (F-038), so it is wrapped in a fn
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    bool :lj::show-bool
                    skewer (:lj::ShishD.Skewer {})
                    onion (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Onion {:s s}))
                    lamb (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Lamb {:s s}))
                    tomato (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Tomato {:s s}))
                    holder (:wat::core::fn [o <- :lj::HolderThing] -> :lj::KebabD (:lj::KebabD.Holder {:o o}))
                    dagger (:lj::HolderThing.Rod {:r (:lj::RodD.Dagger {})})
                    sabre (:lj::HolderThing.Rod {:r (:lj::RodD.Sabre {})})
                    gold (:lj::HolderThing.Plate {:p (:lj::PlateD.Gold {})})
                    wood (:lj::HolderThing.Plate {:p (:lj::PlateD.Wood {})})]
    (:lj::check-chapter "oracle/java/ch02-methods-to-our-madness.expected"
                        "little-java ch02 methods-to-our-madness"
                        (:wat::core::Vector :- [:wat::core::String]
                          (int (:lj::distance-to-o (cart 3 4)))
                          (int (:lj::distance-to-o (manh 3 4)))
                          (int (:lj::distance-to-o (cart 1 1)))
                          (int (:lj::distance-to-o (cart 12 5)))
                          (bool (:lj::closer-to-o (cart 3 4) (manh 1 5)))
                          (bool (:lj::closer-to-o (manh 1 5) (cart 3 4)))
                          (bool (:lj::closer-to-o (manh 2 2) (cart 3 3)))
                          (:lj::show-point (:lj::minus (cart 3 4) (manh 1 1)))
                          (:lj::show-point (:lj::minus (manh 10 7) (cart 4 9)))
                          (bool (:lj::only-onions? skewer))
                          (bool (:lj::only-onions? (onion (onion skewer))))
                          (bool (:lj::only-onions? (onion (lamb skewer))))
                          (bool (:lj::vegetarian? (onion (tomato skewer))))
                          (bool (:lj::vegetarian? (tomato (lamb (onion skewer)))))
                          (bool (:lj::veggie? (:lj::KebabD.Shallot {:k (:lj::KebabD.Radish {:k (holder dagger)})})))
                          (bool (:lj::veggie? (:lj::KebabD.Shallot {:k (:lj::KebabD.Shrimp {:k (holder gold)})})))
                          (:lj::show-holder (:lj::what-holder (:lj::KebabD.Shallot {:k (:lj::KebabD.Radish {:k (holder dagger)})})))
                          (:lj::show-holder (:lj::what-holder (:lj::KebabD.Zucchini {:k (:lj::KebabD.Shrimp {:k (holder wood)})})))
                          (:lj::show-holder (:lj::what-holder (holder sabre)))))))
