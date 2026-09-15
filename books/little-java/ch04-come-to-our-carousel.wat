;; A Little Java, A Few Patterns, chapter 4 (Come to Our Carousel).
;; The chapter moves each method out of the variants into a visitor class (OnlyOnionsV,
;; RemAV, ...) with a method per variant; every variant's method just asks its visitor. There
;; is no interface yet, only concrete classes whose instances hold nothing, so here each
;; visitor's methods are plain functions in the visitor's own namespace
;; (:lj::only-onions-v::for-onion), and each variant's method asks them, as in Java. (Visitors
;; that implement an interface come in chapter 6, as a surface.)
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

;; OnlyOnionsV
(:wat::core::defn :lj::only-onions-v::for-skewer [] -> :wat::core::bool true)
(:wat::core::defn :lj::only-onions-v::for-onion [s <- :lj::ShishD] -> :wat::core::bool (:lj::only-onions? s))
(:wat::core::defn :lj::only-onions-v::for-lamb [s <- :lj::ShishD] -> :wat::core::bool false)
(:wat::core::defn :lj::only-onions-v::for-tomato [s <- :lj::ShishD] -> :wat::core::bool false)

;; IsVegetarianV
(:wat::core::defn :lj::is-vegetarian-v::for-skewer [] -> :wat::core::bool true)
(:wat::core::defn :lj::is-vegetarian-v::for-onion [s <- :lj::ShishD] -> :wat::core::bool (:lj::vegetarian? s))
(:wat::core::defn :lj::is-vegetarian-v::for-lamb [s <- :lj::ShishD] -> :wat::core::bool false)
(:wat::core::defn :lj::is-vegetarian-v::for-tomato [s <- :lj::ShishD] -> :wat::core::bool (:lj::vegetarian? s))

;; each variant's method asks its visitor
(:wat::core::defn :lj::only-onions? [s <- :lj::ShishD] -> :wat::core::bool
  (:wat::core::match s
    [:lj::ShishD.Skewer {} (:lj::only-onions-v::for-skewer)]
    [:lj::ShishD.Onion {:s rest} (:lj::only-onions-v::for-onion rest)]
    [:lj::ShishD.Lamb {:s rest} (:lj::only-onions-v::for-lamb rest)]
    [:lj::ShishD.Tomato {:s rest} (:lj::only-onions-v::for-tomato rest)]))

(:wat::core::defn :lj::vegetarian? [s <- :lj::ShishD] -> :wat::core::bool
  (:wat::core::match s
    [:lj::ShishD.Skewer {} (:lj::is-vegetarian-v::for-skewer)]
    [:lj::ShishD.Onion {:s rest} (:lj::is-vegetarian-v::for-onion rest)]
    [:lj::ShishD.Lamb {:s rest} (:lj::is-vegetarian-v::for-lamb rest)]
    [:lj::ShishD.Tomato {:s rest} (:lj::is-vegetarian-v::for-tomato rest)]))

;; ---- pizzas and their visitors

(:wat::core::defenum :lj::PizzaD :wat::enum::Pure
  :Crust []
  :Cheese [p <- :lj::PizzaD]
  :Olive [p <- :lj::PizzaD]
  :Anchovy [p <- :lj::PizzaD]
  :Sausage [p <- :lj::PizzaD])

(:wat::core::defn :lj::crust [] -> :lj::PizzaD (:lj::PizzaD.Crust {}))
(:wat::core::defn :lj::cheese [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Cheese {:p p}))
(:wat::core::defn :lj::olive [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Olive {:p p}))
(:wat::core::defn :lj::anchovy [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Anchovy {:p p}))
(:wat::core::defn :lj::sausage [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Sausage {:p p}))

;; RemAV
(:wat::core::defn :lj::rem-a-v::for-crust [] -> :lj::PizzaD (:lj::crust))
(:wat::core::defn :lj::rem-a-v::for-cheese [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::rem-a p)))
(:wat::core::defn :lj::rem-a-v::for-olive [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::rem-a p)))
(:wat::core::defn :lj::rem-a-v::for-anchovy [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::rem-a p))
(:wat::core::defn :lj::rem-a-v::for-sausage [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::rem-a p)))

;; TopAwCV
(:wat::core::defn :lj::top-a-w-c-v::for-crust [] -> :lj::PizzaD (:lj::crust))
(:wat::core::defn :lj::top-a-w-c-v::for-cheese [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::top-a-w-c p)))
(:wat::core::defn :lj::top-a-w-c-v::for-olive [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::top-a-w-c p)))
(:wat::core::defn :lj::top-a-w-c-v::for-anchovy [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::anchovy (:lj::top-a-w-c p))))
(:wat::core::defn :lj::top-a-w-c-v::for-sausage [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::top-a-w-c p)))

;; SubAbCV
(:wat::core::defn :lj::sub-a-b-c-v::for-crust [] -> :lj::PizzaD (:lj::crust))
(:wat::core::defn :lj::sub-a-b-c-v::for-cheese [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::sub-a-b-c p)))
(:wat::core::defn :lj::sub-a-b-c-v::for-olive [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::olive (:lj::sub-a-b-c p)))
(:wat::core::defn :lj::sub-a-b-c-v::for-anchovy [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::cheese (:lj::sub-a-b-c p)))
(:wat::core::defn :lj::sub-a-b-c-v::for-sausage [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::sausage (:lj::sub-a-b-c p)))

;; each variant's method asks its visitor
(:wat::core::defn :lj::rem-a [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::rem-a-v::for-crust)]
    [:lj::PizzaD.Cheese {:p p} (:lj::rem-a-v::for-cheese p)]
    [:lj::PizzaD.Olive {:p p} (:lj::rem-a-v::for-olive p)]
    [:lj::PizzaD.Anchovy {:p p} (:lj::rem-a-v::for-anchovy p)]
    [:lj::PizzaD.Sausage {:p p} (:lj::rem-a-v::for-sausage p)]))

(:wat::core::defn :lj::top-a-w-c [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::top-a-w-c-v::for-crust)]
    [:lj::PizzaD.Cheese {:p p} (:lj::top-a-w-c-v::for-cheese p)]
    [:lj::PizzaD.Olive {:p p} (:lj::top-a-w-c-v::for-olive p)]
    [:lj::PizzaD.Anchovy {:p p} (:lj::top-a-w-c-v::for-anchovy p)]
    [:lj::PizzaD.Sausage {:p p} (:lj::top-a-w-c-v::for-sausage p)]))

(:wat::core::defn :lj::sub-a-b-c [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::sub-a-b-c-v::for-crust)]
    [:lj::PizzaD.Cheese {:p p} (:lj::sub-a-b-c-v::for-cheese p)]
    [:lj::PizzaD.Olive {:p p} (:lj::sub-a-b-c-v::for-olive p)]
    [:lj::PizzaD.Anchovy {:p p} (:lj::sub-a-b-c-v::for-anchovy p)]
    [:lj::PizzaD.Sausage {:p p} (:lj::sub-a-b-c-v::for-sausage p)]))

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
