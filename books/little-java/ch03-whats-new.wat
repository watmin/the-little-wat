;; A Little Java, A Few Patterns, chapter 3 (What's New?).
;; Methods that make new pizzas from old ones, each a wat function with an arm per variant.
;; Results are printed as the Java oracle's are (oracle/java/ch03-whats-new.java, run by
;; tools/java-oracle.sh), and every one must match, in order.
;;
;; Java objects have identity as well as structure (new Crust() == new Crust() is false); wat
;; values have only structure, and = compares it, as the oracle's equals does.
;;
;; Run from the repository root (it reads files by path):
;;   wat books/little-java/ch03-whats-new.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :lj::PizzaD :wat::enum::Pure
  :Crust []
  :Cheese [p <- :lj::PizzaD]
  :Olive [p <- :lj::PizzaD]
  :Anchovy [p <- :lj::PizzaD]
  :Sausage [p <- :lj::PizzaD])

;; remove the anchovies
(:wat::core::defn :lj::rem-a [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::PizzaD.Crust {})]
    [:lj::PizzaD.Cheese {:p p} (:lj::PizzaD.Cheese {:p (:lj::rem-a p)})]
    [:lj::PizzaD.Olive {:p p} (:lj::PizzaD.Olive {:p (:lj::rem-a p)})]
    [:lj::PizzaD.Anchovy {:p p} (:lj::rem-a p)]
    [:lj::PizzaD.Sausage {:p p} (:lj::PizzaD.Sausage {:p (:lj::rem-a p)})]))

;; top every anchovy with cheese
(:wat::core::defn :lj::top-a-w-c [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::PizzaD.Crust {})]
    [:lj::PizzaD.Cheese {:p p} (:lj::PizzaD.Cheese {:p (:lj::top-a-w-c p)})]
    [:lj::PizzaD.Olive {:p p} (:lj::PizzaD.Olive {:p (:lj::top-a-w-c p)})]
    [:lj::PizzaD.Anchovy {:p p} (:lj::PizzaD.Cheese {:p (:lj::PizzaD.Anchovy {:p (:lj::top-a-w-c p)})})]
    [:lj::PizzaD.Sausage {:p p} (:lj::PizzaD.Sausage {:p (:lj::top-a-w-c p)})]))

;; substitute cheese for every anchovy
(:wat::core::defn :lj::sub-a-b-c [z <- :lj::PizzaD] -> :lj::PizzaD
  (:wat::core::match z
    [:lj::PizzaD.Crust {} (:lj::PizzaD.Crust {})]
    [:lj::PizzaD.Cheese {:p p} (:lj::PizzaD.Cheese {:p (:lj::sub-a-b-c p)})]
    [:lj::PizzaD.Olive {:p p} (:lj::PizzaD.Olive {:p (:lj::sub-a-b-c p)})]
    [:lj::PizzaD.Anchovy {:p p} (:lj::PizzaD.Cheese {:p (:lj::sub-a-b-c p)})]
    [:lj::PizzaD.Sausage {:p p} (:lj::PizzaD.Sausage {:p (:lj::sub-a-b-c p)})]))

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
  (:wat::core::let [crust (:lj::PizzaD.Crust {})
                    cheese (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Cheese {:p p}))
                    olive (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Olive {:p p}))
                    anchovy (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Anchovy {:p p}))
                    sausage (:wat::core::fn [p <- :lj::PizzaD] -> :lj::PizzaD (:lj::PizzaD.Sausage {:p p}))
                    p1 (anchovy (olive (anchovy (anchovy (cheese crust)))))
                    p2 (sausage (anchovy crust))
                    show :lj::show-pizza
                    bool :lj::show-bool]
    (:lj::check-chapter "oracle/java/ch03-whats-new.expected"
                        "little-java ch03 whats-new"
                        (:wat::core::Vector :- [:wat::core::String]
                          (show p1)
                          (show (:lj::rem-a p1))
                          (show (:lj::top-a-w-c p1))
                          (show (:lj::sub-a-b-c p1))
                          (show (:lj::rem-a p2))
                          (show (:lj::top-a-w-c p2))
                          (show (:lj::sub-a-b-c p2))
                          (show (:lj::rem-a crust))
                          ;; the methods compose
                          (show (:lj::rem-a (:lj::top-a-w-c p1)))
                          (show (:lj::rem-a (:lj::sub-a-b-c p1)))
                          ;; structural equality
                          (bool (:wat::core::= (:lj::rem-a (:lj::top-a-w-c p1)) (:lj::sub-a-b-c p1)))
                          (bool (:wat::core::= (:lj::rem-a p1) (:lj::sub-a-b-c p1)))
                          (bool (:wat::core::= (:lj::rem-a p2) (sausage crust)))))))
