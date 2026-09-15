;; A Little Java, A Few Patterns, chapter 4 (Come to Our Carousel).
;; The chapter moves each method out of the variants into a visitor: an object with a method
;; per variant, which every variant's method just asks. In wat a visitor is a generic struct
;; holding a function per variant (ShishV, PizzaV), and accept is the one match that picks the
;; visitor's function for the variant at hand; each method is accept with its visitor.
;; Results are printed as the Java oracle's are (oracle/java/ch04-come-to-our-carousel.java,
;; run by tools/java-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch04-come-to-our-carousel.wat

(:wat::load-file! "lib/check.wat")

;; ---- shish kebabs and their visitors

(:wat::core::defenum :lj::ShishD :wat::enum::Pure
  :Skewer []
  :Onion [s <- :lj::ShishD]
  :Lamb [s <- :lj::ShishD]
  :Tomato [s <- :lj::ShishD])

(:wat::core::defstruct :lj::ShishV :- [R]
  [for-skewer <- [:-> R]
   for-onion <- [:lj::ShishD :-> R]
   for-lamb <- [:lj::ShishD :-> R]
   for-tomato <- [:lj::ShishD :-> R]])

(:wat::core::defn :lj::shish-accept :- [R] [s <- :lj::ShishD v <- (:lj::ShishV :- [R])] -> R
  (:wat::core::match s
    [:lj::ShishD.Skewer {} ((:lj::ShishV/for-skewer v))]
    [:lj::ShishD.Onion {:s rest} ((:lj::ShishV/for-onion v) rest)]
    [:lj::ShishD.Lamb {:s rest} ((:lj::ShishV/for-lamb v) rest)]
    [:lj::ShishD.Tomato {:s rest} ((:lj::ShishV/for-tomato v) rest)]))

(:wat::core::defn :lj::only-onions-v [] -> (:lj::ShishV :- [:wat::core::bool])
  (:lj::ShishV :for-skewer (:wat::core::fn [] -> :wat::core::bool true)
               :for-onion (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool (:lj::only-onions? s))
               :for-lamb (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool false)
               :for-tomato (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool false)))

(:wat::core::defn :lj::is-vegetarian-v [] -> (:lj::ShishV :- [:wat::core::bool])
  (:lj::ShishV :for-skewer (:wat::core::fn [] -> :wat::core::bool true)
               :for-onion (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool (:lj::vegetarian? s))
               :for-lamb (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool false)
               :for-tomato (:wat::core::fn [s <- :lj::ShishD] -> :wat::core::bool (:lj::vegetarian? s))))

(:wat::core::defn :lj::only-onions? [s <- :lj::ShishD] -> :wat::core::bool
  (:lj::shish-accept s (:lj::only-onions-v)))
(:wat::core::defn :lj::vegetarian? [s <- :lj::ShishD] -> :wat::core::bool
  (:lj::shish-accept s (:lj::is-vegetarian-v)))

;; ---- pizzas and their visitors

(:wat::core::defenum :lj::PizzaD :wat::enum::Pure
  :Crust []
  :Cheese [p <- :lj::PizzaD]
  :Olive [p <- :lj::PizzaD]
  :Anchovy [p <- :lj::PizzaD]
  :Sausage [p <- :lj::PizzaD])

(:wat::core::defstruct :lj::PizzaV :- [R]
  [for-crust <- [:-> R]
   for-cheese <- [:lj::PizzaD :-> R]
   for-olive <- [:lj::PizzaD :-> R]
   for-anchovy <- [:lj::PizzaD :-> R]
   for-sausage <- [:lj::PizzaD :-> R]])

(:wat::core::defn :lj::pizza-accept :- [R] [z <- :lj::PizzaD v <- (:lj::PizzaV :- [R])] -> R
  (:wat::core::match z
    [:lj::PizzaD.Crust {} ((:lj::PizzaV/for-crust v))]
    [:lj::PizzaD.Cheese {:p p} ((:lj::PizzaV/for-cheese v) p)]
    [:lj::PizzaD.Olive {:p p} ((:lj::PizzaV/for-olive v) p)]
    [:lj::PizzaD.Anchovy {:p p} ((:lj::PizzaV/for-anchovy v) p)]
    [:lj::PizzaD.Sausage {:p p} ((:lj::PizzaV/for-sausage v) p)]))

(:wat::core::defn :lj::crust [] -> :lj::PizzaD (:lj::PizzaD.Crust {}))
(:wat::core::defn :lj::cheese [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Cheese {:p p}))
(:wat::core::defn :lj::olive [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Olive {:p p}))
(:wat::core::defn :lj::anchovy [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Anchovy {:p p}))
(:wat::core::defn :lj::sausage [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Sausage {:p p}))

(:wat::core::defn :lj::rem-a-v [] -> (:lj::PizzaV :- [:lj::PizzaD])
  (:lj::PizzaV :for-crust :lj::crust
               :for-cheese (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::rem-a p)))
               :for-olive (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::rem-a p)))
               :for-anchovy (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::rem-a p))
               :for-sausage (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::rem-a p)))))

(:wat::core::defn :lj::top-a-w-c-v [] -> (:lj::PizzaV :- [:lj::PizzaD])
  (:lj::PizzaV :for-crust :lj::crust
               :for-cheese (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::top-a-w-c p)))
               :for-olive (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::top-a-w-c p)))
               :for-anchovy (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::anchovy (:lj::top-a-w-c p))))
               :for-sausage (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::top-a-w-c p)))))

(:wat::core::defn :lj::sub-a-b-c-v [] -> (:lj::PizzaV :- [:lj::PizzaD])
  (:lj::PizzaV :for-crust :lj::crust
               :for-cheese (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::sub-a-b-c p)))
               :for-olive (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::sub-a-b-c p)))
               :for-anchovy (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::sub-a-b-c p)))
               :for-sausage (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::sub-a-b-c p)))))

(:wat::core::defn :lj::rem-a [z <- :lj::PizzaD] -> :lj::PizzaD (:lj::pizza-accept z (:lj::rem-a-v)))
(:wat::core::defn :lj::top-a-w-c [z <- :lj::PizzaD] -> :lj::PizzaD (:lj::pizza-accept z (:lj::top-a-w-c-v)))
(:wat::core::defn :lj::sub-a-b-c [z <- :lj::PizzaD] -> :lj::PizzaD (:lj::pizza-accept z (:lj::sub-a-b-c-v)))

(:wat::core::defn :lj::show-pizza [z <- :lj::PizzaD] -> :wat::core::String
  (:wat::core::match z
    [:lj::PizzaD.Crust {} "(Crust)"]
    [:lj::PizzaD.Cheese {:p p} (:wat::string::concat "(Cheese " (:lj::show-pizza p) ")")]
    [:lj::PizzaD.Olive {:p p} (:wat::string::concat "(Olive " (:lj::show-pizza p) ")")]
    [:lj::PizzaD.Anchovy {:p p} (:wat::string::concat "(Anchovy " (:lj::show-pizza p) ")")]
    [:lj::PizzaD.Sausage {:p p} (:wat::string::concat "(Sausage " (:lj::show-pizza p) ")")]))

(:wat::core::defn :lj::show-bool [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "true" "false"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [skewer (:lj::ShishD.Skewer {})
                    onion (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Onion {:s s}))
                    lamb (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Lamb {:s s}))
                    tomato (:wat::core::fn [s <- :lj::ShishD] -> :lj::ShishD (:lj::ShishD.Tomato {:s s}))
                    p1 (:lj::anchovy (:lj::olive (:lj::anchovy (:lj::anchovy (:lj::cheese (:lj::crust))))))
                    bool :lj::show-bool
                    show :lj::show-pizza]
    (:lj::check-chapter "oracle/java/ch04-come-to-our-carousel.expected"
                        "little-java ch04 come-to-our-carousel"
                        (:wat::core::Vector :- [:wat::core::String]
                          ;; the same answers as chapters 2 and 3: only where the code lives has changed
                          (bool (:lj::only-onions? (onion (onion skewer))))
                          (bool (:lj::only-onions? (onion (lamb skewer))))
                          (bool (:lj::vegetarian? (onion (tomato skewer))))
                          (bool (:lj::vegetarian? (tomato (lamb (onion skewer)))))
                          (show (:lj::rem-a p1))
                          (show (:lj::top-a-w-c p1))
                          (show (:lj::sub-a-b-c p1))
                          (show (:lj::top-a-w-c (:lj::sausage (:lj::anchovy (:lj::crust)))))
                          (show (:lj::rem-a (:lj::top-a-w-c p1)))))))
