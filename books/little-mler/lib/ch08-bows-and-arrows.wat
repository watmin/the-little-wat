;; The Little MLer, chapter 8 (Bows and Arrows): equality and predicates as parameters, then
;; curried functions and functions built from closures. Our own code.

;; datatype 'a list = Empty | Cons of 'a * 'a list
(:wat::core::defenum :ml::List :- [A] :wat::enum::Pure
  :Empty []
  :Cons  [e <- A  t <- (:ml::List :- [A])])

(wat.core/defn ml/empty :- [A] [] :- (:ml::List :- [A]) (:ml::List.Empty {}))
(wat.core/defn ml/cons :- [A] [e :- A t :- (:ml::List :- [A])] :- (:ml::List :- [A]) (:ml::List.Cons {:e e :t t}))

;; A list from a Vector, first element first.
(wat.core/defn ml/from-vec :- [A] [xs :- (wat.type/Vector :- [A])] :- (:ml::List :- [A])
  (wat.core/if (wat.core/empty? xs)
    (ml/empty)
    (ml/cons (wat.core/first xs) (ml/from-vec (wat.core/rest xs)))))

;; datatype orapl = Orange | Apple
(:wat::core::defenum :ml::Orapl :wat::enum::Pure :Orange [] :Apple [])
(wat.core/defn ml/orange [] :- :ml::Orapl (:ml::Orapl.Orange {}))
(wat.core/defn ml/apple [] :- :ml::Orapl (:ml::Orapl.Apple {}))

;; eq_orapl by cases: all four pairs (ML's has two same-same cases and a catch-all).
(wat.core/defn ml/eq-orapl [a :- :ml::Orapl b :- :ml::Orapl] :- wat.type/bool
  (:wat::core::match a
    [:ml::Orapl.Orange {} (:wat::core::match b [:ml::Orapl.Orange {} true] [:ml::Orapl.Apple {} false])]
    [:ml::Orapl.Apple {} (:wat::core::match b [:ml::Orapl.Orange {} false] [:ml::Orapl.Apple {} true])]))

;; subst_int and subst_orapl differ only in their equality ...
(wat.core/defn ml/subst-int [n :- wat.type/i64 a :- wat.type/i64 l :- (:ml::List :- [wat.type/i64])] :- (:ml::List :- [wat.type/i64])
  (:wat::core::match l
    [:ml::List.Empty {} (ml/empty)]
    [:ml::List.Cons {:e e :t t}
      (wat.core/if (wat.core/= a e) (ml/cons n (ml/subst-int n a t)) (ml/cons e (ml/subst-int n a t)))]))

(wat.core/defn ml/subst-orapl [n :- :ml::Orapl a :- :ml::Orapl l :- (:ml::List :- [:ml::Orapl])] :- (:ml::List :- [:ml::Orapl])
  (:wat::core::match l
    [:ml::List.Empty {} (ml/empty)]
    [:ml::List.Cons {:e e :t t}
      (wat.core/if (ml/eq-orapl a e) (ml/cons n (ml/subst-orapl n a t)) (ml/cons e (ml/subst-orapl n a t)))]))

;; ... so subst takes the equality as an argument.
(wat.core/defn ml/subst :- [A] [rel :- [A A :-> wat.type/bool] n :- A a :- A l :- (:ml::List :- [A])] :- (:ml::List :- [A])
  (:wat::core::match l
    [:ml::List.Empty {} (ml/empty)]
    [:ml::List.Cons {:e e :t t}
      (wat.core/if (rel a e) (ml/cons n (ml/subst rel n a t)) (ml/cons e (ml/subst rel n a t)))]))

(wat.core/defn ml/less-than [a :- wat.type/i64 b :- wat.type/i64] :- wat.type/bool (wat.core/> b a))

(wat.core/defn ml/in-range [small :- wat.type/i64 large :- wat.type/i64 x :- wat.type/i64] :- wat.type/bool
  (wat.core/and (ml/less-than small x) (ml/less-than x large)))

;; subst_pred: replace every element the predicate accepts.
(wat.core/defn ml/subst-pred :- [A] [pred :- [A :-> wat.type/bool] n :- A l :- (:ml::List :- [A])] :- (:ml::List :- [A])
  (:wat::core::match l
    [:ml::List.Empty {} (ml/empty)]
    [:ml::List.Cons {:e e :t t}
      (wat.core/if (pred e) (ml/cons n (ml/subst-pred pred n t)) (ml/cons e (ml/subst-pred pred n t)))]))

;; Curried: in_range_c(small, large) is a predicate.
(wat.core/defn ml/in-range-c [small :- wat.type/i64 large :- wat.type/i64] :- [wat.type/i64 :-> wat.type/bool]
  (wat.core/fn [x :- wat.type/i64] :- wat.type/bool (ml/in-range small large x)))

;; Curried: subst_c(pred) is a function of n and the list.
(wat.core/defn ml/subst-c :- [A] [pred :- [A :-> wat.type/bool]] :- [A (:ml::List :- [A]) :-> (:ml::List :- [A])]
  (wat.core/fn [n :- A l :- (:ml::List :- [A])] :- (:ml::List :- [A])
    (:wat::core::match l
      [:ml::List.Empty {} (ml/empty)]
      [:ml::List.Cons {:e e :t t}
        (wat.core/if (pred e) (ml/cons n ((ml/subst-c pred) n t)) (ml/cons e ((ml/subst-c pred) n t)))])))

;; combine: append; combine_c: curried; prefixer_123: combine_c of (1 2 3).
(wat.core/defn ml/combine :- [A] [l1 :- (:ml::List :- [A]) l2 :- (:ml::List :- [A])] :- (:ml::List :- [A])
  (:wat::core::match l1
    [:ml::List.Empty {} l2]
    [:ml::List.Cons {:e e :t t} (ml/cons e (ml/combine t l2))]))

(wat.core/defn ml/combine-c :- [A] [l1 :- (:ml::List :- [A])] :- [(:ml::List :- [A]) :-> (:ml::List :- [A])]
  (wat.core/fn [l2 :- (:ml::List :- [A])] :- (:ml::List :- [A]) (ml/combine l1 l2)))

(wat.core/defn ml/prefixer-123 [] :- [(:ml::List :- [wat.type/i64]) :-> (:ml::List :- [wat.type/i64])]
  (ml/combine-c (ml/from-vec [1 2 3])))

;; combine_s stages the work: it walks l1 once, building a function that conses its
;; elements onto whatever l2 it is given later.
(wat.core/defn ml/base :- [A] [l2 :- (:ml::List :- [A])] :- (:ml::List :- [A]) l2)

(wat.core/defn ml/make-cons :- [A] [a :- A f :- [(:ml::List :- [A]) :-> (:ml::List :- [A])]]
  :- [(:ml::List :- [A]) :-> (:ml::List :- [A])]
  (wat.core/fn [l2 :- (:ml::List :- [A])] :- (:ml::List :- [A]) (ml/cons a (f l2))))

(wat.core/defn ml/combine-s :- [A] [l1 :- (:ml::List :- [A])] :- [(:ml::List :- [A]) :-> (:ml::List :- [A])]
  (:wat::core::match l1
    [:ml::List.Empty {} ml/base]
    [:ml::List.Cons {:e e :t t} (ml/make-cons e (ml/combine-s t))]))
