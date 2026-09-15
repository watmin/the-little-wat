;; The Little MLer, chapter 2 (Matchmaker, Matchmaker): functions defined by cases over a
;; datatype, one arm per constructor, and a generic datatype whose bottom can be anything.
;; Our own code. Every match names every variant: no `_` (the builder's doctrine, F-025).

;; datatype shish_kebab = Skewer | Onion of shish_kebab | Lamb of shish_kebab
;;                      | Tomato of shish_kebab
(:wat::core::defenum :ml::ShishKebab :wat::enum::Pure
  :Skewer []
  :Onion  [k <- :ml::ShishKebab]
  :Lamb   [k <- :ml::ShishKebab]
  :Tomato [k <- :ml::ShishKebab])

;; A kebab from a quoted list of toppings, outermost first: '(onion lamb) is
;; Onion(Lamb(Skewer)).
(wat.core/defn ml/kebab [toppings :- :wat::WatAST] :- :ml::ShishKebab
  (wat.core/if (wat.core/empty? toppings)
    (:ml::ShishKebab.Skewer {})
    (wat.core/let [t (wat.core/first toppings)
                   k (ml/kebab (wat.core/rest toppings))]
      (wat.core/cond
        ((wat.core/= t 'onion) (:ml::ShishKebab.Onion {:k k}))
        ((wat.core/= t 'lamb) (:ml::ShishKebab.Lamb {:k k}))
        ((wat.core/= t 'tomato) (:ml::ShishKebab.Tomato {:k k}))
        (:else (:wat::kernel::assertion-failed! :message "kebab: unknown topping"))))))

(wat.core/defn ml/only-onions [k :- :ml::ShishKebab] :- wat.type/bool
  (:wat::core::match k
    [:ml::ShishKebab.Skewer {} true]
    [:ml::ShishKebab.Onion {:k x} (ml/only-onions x)]
    [:ml::ShishKebab.Lamb {:k _x} false]
    [:ml::ShishKebab.Tomato {:k _x} false]))

(wat.core/defn ml/is-vegetarian [k :- :ml::ShishKebab] :- wat.type/bool
  (:wat::core::match k
    [:ml::ShishKebab.Skewer {} true]
    [:ml::ShishKebab.Onion {:k x} (ml/is-vegetarian x)]
    [:ml::ShishKebab.Lamb {:k _x} false]
    [:ml::ShishKebab.Tomato {:k x} (ml/is-vegetarian x)]))

;; datatype 'a shish = Bottom of 'a | Onion of 'a shish | Lamb of 'a shish
;;                   | Tomato of 'a shish
(:wat::core::defenum :ml::Shish :- [A] :wat::enum::Pure
  :Bottom [v <- A]
  :Onion  [s <- (:ml::Shish :- [A])]
  :Lamb   [s <- (:ml::Shish :- [A])]
  :Tomato [s <- (:ml::Shish :- [A])])

;; datatype rod = Dagger | Fork | Sword;  datatype plate = Gold_plate | Silver_plate | Brass_plate
(:wat::core::defenum :ml::Rod :wat::enum::Pure :Dagger [] :Fork [] :Sword [])
(:wat::core::defenum :ml::Plate :wat::enum::Pure :GoldPlate [] :SilverPlate [] :BrassPlate [])

(wat.core/defn ml/dagger [] :- :ml::Rod (:ml::Rod.Dagger {}))
(wat.core/defn ml/sword [] :- :ml::Rod (:ml::Rod.Sword {}))
(wat.core/defn ml/gold-plate [] :- :ml::Plate (:ml::Plate.GoldPlate {}))

;; A shish from a quoted list of toppings and a bottom.
(wat.core/defn ml/shish :- [A] [toppings :- :wat::WatAST bottom :- A] :- (:ml::Shish :- [A])
  (wat.core/if (wat.core/empty? toppings)
    (:ml::Shish.Bottom {:v bottom})
    (wat.core/let [t (wat.core/first toppings)
                   s (ml/shish (wat.core/rest toppings) bottom)]
      (wat.core/cond
        ((wat.core/= t 'onion) (:ml::Shish.Onion {:s s}))
        ((wat.core/= t 'lamb) (:ml::Shish.Lamb {:s s}))
        ((wat.core/= t 'tomato) (:ml::Shish.Tomato {:s s}))
        (:else (:wat::kernel::assertion-failed! :message "shish: unknown topping"))))))

(wat.core/defn ml/is-veggie :- [A] [s :- (:ml::Shish :- [A])] :- wat.type/bool
  (:wat::core::match s
    [:ml::Shish.Bottom {:v _v} true]
    [:ml::Shish.Onion {:s x} (ml/is-veggie x)]
    [:ml::Shish.Lamb {:s _x} false]
    [:ml::Shish.Tomato {:s x} (ml/is-veggie x)]))

(wat.core/defn ml/what-bottom :- [A] [s :- (:ml::Shish :- [A])] :- A
  (:wat::core::match s
    [:ml::Shish.Bottom {:v v} v]
    [:ml::Shish.Onion {:s x} (ml/what-bottom x)]
    [:ml::Shish.Lamb {:s x} (ml/what-bottom x)]
    [:ml::Shish.Tomato {:s x} (ml/what-bottom x)]))
