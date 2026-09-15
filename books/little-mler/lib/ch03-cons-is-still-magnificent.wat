;; The Little MLer, chapter 3 (Cons Is Still Magnificent): functions that rebuild a datatype
;; value, constructor by constructor. Our own code. Every match names every variant.

;; datatype pizza = Crust | Cheese of pizza | Onion of pizza | Anchovy of pizza
;;                | Sausage of pizza
(:wat::core::defenum :ml::Pizza :wat::enum::Pure
  :Crust   []
  :Cheese  [p <- :ml::Pizza]
  :Onion   [p <- :ml::Pizza]
  :Anchovy [p <- :ml::Pizza]
  :Sausage [p <- :ml::Pizza])

(wat.core/defn ml/crust [] :- :ml::Pizza (:ml::Pizza.Crust {}))
(wat.core/defn ml/cheese [p :- :ml::Pizza] :- :ml::Pizza (:ml::Pizza.Cheese {:p p}))
(wat.core/defn ml/onion [p :- :ml::Pizza] :- :ml::Pizza (:ml::Pizza.Onion {:p p}))
(wat.core/defn ml/anchovy [p :- :ml::Pizza] :- :ml::Pizza (:ml::Pizza.Anchovy {:p p}))
(wat.core/defn ml/sausage [p :- :ml::Pizza] :- :ml::Pizza (:ml::Pizza.Sausage {:p p}))

;; A pizza from a quoted list of toppings, outermost first, on a crust.
(wat.core/defn ml/pizza [toppings :- :wat::WatAST] :- :ml::Pizza
  (wat.core/if (wat.core/empty? toppings)
    (ml/crust)
    (wat.core/let [t (wat.core/first toppings)
                   p (ml/pizza (wat.core/rest toppings))]
      (wat.core/cond
        ((wat.core/= t 'cheese) (ml/cheese p))
        ((wat.core/= t 'onion) (ml/onion p))
        ((wat.core/= t 'anchovy) (ml/anchovy p))
        ((wat.core/= t 'sausage) (ml/sausage p))
        (:else (:wat::kernel::assertion-failed! :message "pizza: unknown topping"))))))

(wat.core/defn ml/remove-anchovy [p :- :ml::Pizza] :- :ml::Pizza
  (:wat::core::match p
    [:ml::Pizza.Crust {} (ml/crust)]
    [:ml::Pizza.Cheese {:p x} (ml/cheese (ml/remove-anchovy x))]
    [:ml::Pizza.Onion {:p x} (ml/onion (ml/remove-anchovy x))]
    [:ml::Pizza.Anchovy {:p x} (ml/remove-anchovy x)]
    [:ml::Pizza.Sausage {:p x} (ml/sausage (ml/remove-anchovy x))]))

;; Cover every anchovy with cheese.
(wat.core/defn ml/top-anchovy-with-cheese [p :- :ml::Pizza] :- :ml::Pizza
  (:wat::core::match p
    [:ml::Pizza.Crust {} (ml/crust)]
    [:ml::Pizza.Cheese {:p x} (ml/cheese (ml/top-anchovy-with-cheese x))]
    [:ml::Pizza.Onion {:p x} (ml/onion (ml/top-anchovy-with-cheese x))]
    [:ml::Pizza.Anchovy {:p x} (ml/cheese (ml/anchovy (ml/top-anchovy-with-cheese x)))]
    [:ml::Pizza.Sausage {:p x} (ml/sausage (ml/top-anchovy-with-cheese x))]))

;; Replace every anchovy by cheese: first as a composition of the two above ...
(wat.core/defn ml/subst-anchovy-by-cheese-composed [p :- :ml::Pizza] :- :ml::Pizza
  (ml/remove-anchovy (ml/top-anchovy-with-cheese p)))

;; ... then directly.
(wat.core/defn ml/subst-anchovy-by-cheese [p :- :ml::Pizza] :- :ml::Pizza
  (:wat::core::match p
    [:ml::Pizza.Crust {} (ml/crust)]
    [:ml::Pizza.Cheese {:p x} (ml/cheese (ml/subst-anchovy-by-cheese x))]
    [:ml::Pizza.Onion {:p x} (ml/onion (ml/subst-anchovy-by-cheese x))]
    [:ml::Pizza.Anchovy {:p x} (ml/cheese (ml/subst-anchovy-by-cheese x))]
    [:ml::Pizza.Sausage {:p x} (ml/sausage (ml/subst-anchovy-by-cheese x))]))
