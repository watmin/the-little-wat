;; The Little MLer, chapter 4 (Look to the Stars): tuples, the `*` in a type like
;; meza * main, and functions over them. Our own code. Every match names every variant.
;;
;; A match arm cannot destructure a tuple (F-027), and the Clojure-spelled let cannot either
;; (F-024). So a tuple is taken apart with the keyword let, [[a b] t], and matched one
;; position at a time.

(:wat::core::defenum :ml::Meza :wat::enum::Pure :Shrimp [] :Calamari [] :Escargots [] :Hummus [])
(:wat::core::defenum :ml::Main :wat::enum::Pure :Steak [] :Ravioli [] :Chicken [] :Eggplant [])
(:wat::core::defenum :ml::Salad :wat::enum::Pure :Green [] :Cranberry [] :SantaFe [] :Caesar [])
(:wat::core::defenum :ml::Dessert :wat::enum::Pure :Sundae [] :Mousse [] :Torte [])

(wat.core/defn ml/shrimp [] :- :ml::Meza (:ml::Meza.Shrimp {}))
(wat.core/defn ml/calamari [] :- :ml::Meza (:ml::Meza.Calamari {}))
(wat.core/defn ml/hummus [] :- :ml::Meza (:ml::Meza.Hummus {}))
(wat.core/defn ml/steak [] :- :ml::Main (:ml::Main.Steak {}))
(wat.core/defn ml/ravioli [] :- :ml::Main (:ml::Main.Ravioli {}))
(wat.core/defn ml/chicken [] :- :ml::Main (:ml::Main.Chicken {}))
(wat.core/defn ml/eggplant [] :- :ml::Main (:ml::Main.Eggplant {}))
(wat.core/defn ml/sundae [] :- :ml::Dessert (:ml::Dessert.Sundae {}))
(wat.core/defn ml/torte [] :- :ml::Dessert (:ml::Dessert.Torte {}))

;; add_a_steak : meza -> meza * main
(wat.core/defn ml/add-a-steak [m :- :ml::Meza] :- (wat.type/Tuple :- [:ml::Meza :ml::Main])
  (:wat::core::Tuple m (ml/steak)))

;; eq_main : main * main -> bool. ML writes it with four same-same cases and a catch-all
;; (a_main, another_main) => false. With no catch-all, it is value equality ...
(wat.core/defn ml/eq-main [p :- (wat.type/Tuple :- [:ml::Main :ml::Main])] :- wat.type/bool
  (wat.core/= (wat.core/first p) (wat.core/second p)))

;; ... or, by cases, every one of the 16 combinations (F-027).
(wat.core/defn ml/eq-main-by-cases [p :- (wat.type/Tuple :- [:ml::Main :ml::Main])] :- wat.type/bool
  (:wat::core::let [[a b] p]
    (:wat::core::match a
      [:ml::Main.Steak {}
        (:wat::core::match b [:ml::Main.Steak {} true] [:ml::Main.Ravioli {} false] [:ml::Main.Chicken {} false] [:ml::Main.Eggplant {} false])]
      [:ml::Main.Ravioli {}
        (:wat::core::match b [:ml::Main.Steak {} false] [:ml::Main.Ravioli {} true] [:ml::Main.Chicken {} false] [:ml::Main.Eggplant {} false])]
      [:ml::Main.Chicken {}
        (:wat::core::match b [:ml::Main.Steak {} false] [:ml::Main.Ravioli {} false] [:ml::Main.Chicken {} true] [:ml::Main.Eggplant {} false])]
      [:ml::Main.Eggplant {}
        (:wat::core::match b [:ml::Main.Steak {} false] [:ml::Main.Ravioli {} false] [:ml::Main.Chicken {} false] [:ml::Main.Eggplant {} true])])))

;; has_steak : meza * main * dessert -> bool
(wat.core/defn ml/has-steak [t :- (wat.type/Tuple :- [:ml::Meza :ml::Main :ml::Dessert])] :- wat.type/bool
  (:wat::core::let [[_a m _d] t]
    (:wat::core::match m
      [:ml::Main.Steak {} true]
      [:ml::Main.Ravioli {} false]
      [:ml::Main.Chicken {} false]
      [:ml::Main.Eggplant {} false])))
