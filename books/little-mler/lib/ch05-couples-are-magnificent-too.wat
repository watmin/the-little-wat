;; The Little MLer, chapter 5 (Couples Are Magnificent, Too): a generic pizza whose toppings
;; are couples, and functions that remove or substitute a topping. Our own code.
;;
;; ML writes rem_anchovy with a nested pattern, Topping(Anchovy, p), and a second arm for
;; every other topping. In wat, nested arms never count as covering a variant (F-028), so
;; that second arm would have to be a binder fallback: a catch-all. Instead each function
;; binds the topping and matches it in its own match, naming every fish, so a fish added
;; later is flagged.

(:wat::core::defenum :ml::Fish :wat::enum::Pure :Anchovy [] :Lox [] :Tuna [])

;; datatype 'a pizza = Bottom | Topping of ('a * ('a pizza)). Topping has two fields here,
;; the wat idiom; a single tuple field works too (probes/ml/tuple-in-variant-*.wat).
(:wat::core::defenum :ml::TPizza :- [A] :wat::enum::Pure
  :Bottom []
  :Topping [t <- A  p <- (:ml::TPizza :- [A])])

(wat.core/defn ml/bottom :- [A] [] :- (:ml::TPizza :- [A]) (:ml::TPizza.Bottom {}))
(wat.core/defn ml/topping :- [A] [t :- A p :- (:ml::TPizza :- [A])] :- (:ml::TPizza :- [A])
  (:ml::TPizza.Topping {:t t :p p}))

(wat.core/defn ml/fish [name :- :wat::WatAST] :- :ml::Fish
  (wat.core/cond
    ((wat.core/= name 'anchovy) (:ml::Fish.Anchovy {}))
    ((wat.core/= name 'lox) (:ml::Fish.Lox {}))
    ((wat.core/= name 'tuna) (:ml::Fish.Tuna {}))
    (:else (:wat::kernel::assertion-failed! :message "fish: unknown fish"))))

;; A fish pizza from a quoted list of fish, outermost first; an int pizza from a Vector.
(wat.core/defn ml/fish-pizza [names :- :wat::WatAST] :- (:ml::TPizza :- [:ml::Fish])
  (wat.core/if (wat.core/empty? names)
    (ml/bottom)
    (ml/topping (ml/fish (wat.core/first names)) (ml/fish-pizza (wat.core/rest names)))))

(wat.core/defn ml/int-pizza [xs :- (wat.type/Vector :- [wat.type/i64])] :- (:ml::TPizza :- [wat.type/i64])
  (wat.core/if (wat.core/empty? xs)
    (ml/bottom)
    (ml/topping (wat.core/first xs) (ml/int-pizza (wat.core/rest xs)))))

(wat.core/defn ml/rem-anchovy [p :- (:ml::TPizza :- [:ml::Fish])] :- (:ml::TPizza :- [:ml::Fish])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (:wat::core::match t
        [:ml::Fish.Anchovy {} (ml/rem-anchovy rest)]
        [:ml::Fish.Lox {} (ml/topping t (ml/rem-anchovy rest))]
        [:ml::Fish.Tuna {} (ml/topping t (ml/rem-anchovy rest))])]))

(wat.core/defn ml/rem-tuna [p :- (:ml::TPizza :- [:ml::Fish])] :- (:ml::TPizza :- [:ml::Fish])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (:wat::core::match t
        [:ml::Fish.Anchovy {} (ml/topping t (ml/rem-tuna rest))]
        [:ml::Fish.Lox {} (ml/topping t (ml/rem-tuna rest))]
        [:ml::Fish.Tuna {} (ml/rem-tuna rest)])]))

;; eq_fish by cases: every one of the nine pairs (ML's version has three same-same cases and
;; a catch-all).
(wat.core/defn ml/eq-fish [a :- :ml::Fish b :- :ml::Fish] :- wat.type/bool
  (:wat::core::match a
    [:ml::Fish.Anchovy {} (:wat::core::match b [:ml::Fish.Anchovy {} true] [:ml::Fish.Lox {} false] [:ml::Fish.Tuna {} false])]
    [:ml::Fish.Lox {} (:wat::core::match b [:ml::Fish.Anchovy {} false] [:ml::Fish.Lox {} true] [:ml::Fish.Tuna {} false])]
    [:ml::Fish.Tuna {} (:wat::core::match b [:ml::Fish.Anchovy {} false] [:ml::Fish.Lox {} false] [:ml::Fish.Tuna {} true])]))

;; rem_fish and rem_int are the same function but for their equality.
(wat.core/defn ml/rem-fish [x :- :ml::Fish p :- (:ml::TPizza :- [:ml::Fish])] :- (:ml::TPizza :- [:ml::Fish])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (wat.core/if (ml/eq-fish x t)
        (ml/rem-fish x rest)
        (ml/topping t (ml/rem-fish x rest)))]))

(wat.core/defn ml/rem-int [x :- wat.type/i64 p :- (:ml::TPizza :- [wat.type/i64])] :- (:ml::TPizza :- [wat.type/i64])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (wat.core/if (wat.core/= x t)
        (ml/rem-int x rest)
        (ml/topping t (ml/rem-int x rest)))]))

;; subst: replace every a by n.
(wat.core/defn ml/subst-fish [n :- :ml::Fish a :- :ml::Fish p :- (:ml::TPizza :- [:ml::Fish])] :- (:ml::TPizza :- [:ml::Fish])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (wat.core/if (ml/eq-fish a t)
        (ml/topping n (ml/subst-fish n a rest))
        (ml/topping t (ml/subst-fish n a rest)))]))

(wat.core/defn ml/subst-int [n :- wat.type/i64 a :- wat.type/i64 p :- (:ml::TPizza :- [wat.type/i64])] :- (:ml::TPizza :- [wat.type/i64])
  (:wat::core::match p
    [:ml::TPizza.Bottom {} (ml/bottom)]
    [:ml::TPizza.Topping {:t t :p rest}
      (wat.core/if (wat.core/= a t)
        (ml/topping n (ml/subst-int n a rest))
        (ml/topping t (ml/subst-int n a rest)))]))
