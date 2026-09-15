;; The Little MLer, chapter 1 (Building Blocks): datatypes and their values. Our own code.
;;
;; ML's datatypes are wat enums. Constructors are wrapped in Clojure-spelled fns whose
;; declared return widens the variant to its enum (F-019, F-020), so values can go into
;; collections. Matches name every variant: no `_` (the builder's doctrine; F-025).

;; datatype seasoning = Salt | Pepper
(:wat::core::defenum :ml::Seasoning :wat::enum::Pure
  :Salt []
  :Pepper [])

;; datatype num = Zero | One_more_than of num
(:wat::core::defenum :ml::Num :wat::enum::Pure
  :Zero []
  :OneMoreThan [n <- :ml::Num])

;; datatype 'a open_faced_sandwich = Bread of 'a | Slice of 'a open_faced_sandwich
(:wat::core::defenum :ml::Sandwich :- [A] :wat::enum::Pure
  :Bread [v <- A]
  :Slice [s <- (:ml::Sandwich :- [A])])

(wat.core/defn ml/salt [] :- :ml::Seasoning (:ml::Seasoning.Salt {}))
(wat.core/defn ml/pepper [] :- :ml::Seasoning (:ml::Seasoning.Pepper {}))
(wat.core/defn ml/zero [] :- :ml::Num (:ml::Num.Zero {}))
(wat.core/defn ml/one-more-than [n :- :ml::Num] :- :ml::Num (:ml::Num.OneMoreThan {:n n}))
(wat.core/defn ml/bread :- [A] [v :- A] :- (:ml::Sandwich :- [A]) (:ml::Sandwich.Bread {:v v}))
(wat.core/defn ml/slice :- [A] [s :- (:ml::Sandwich :- [A])] :- (:ml::Sandwich :- [A]) (:ml::Sandwich.Slice {:s s}))

;; Observers, so a chapter program can check the values it builds.
(wat.core/defn ml/num->i64 [n :- :ml::Num] :- wat.type/i64
  (:wat::core::match n
    [:ml::Num.Zero {} 0]
    [:ml::Num.OneMoreThan {:n m} (wat.core/+ 1 (ml/num->i64 m))]))

(wat.core/defn ml/i64->num [k :- wat.type/i64] :- :ml::Num
  (wat.core/if (wat.core/= k 0)
    (ml/zero)
    (ml/one-more-than (ml/i64->num (wat.core/- k 1)))))

;; The filling at the bottom of a sandwich, and how many slices sit on it.
(wat.core/defn ml/filling :- [A] [s :- (:ml::Sandwich :- [A])] :- A
  (:wat::core::match s
    [:ml::Sandwich.Bread {:v v} v]
    [:ml::Sandwich.Slice {:s t} (ml/filling t)]))

(wat.core/defn ml/slices :- [A] [s :- (:ml::Sandwich :- [A])] :- wat.type/i64
  (:wat::core::match s
    [:ml::Sandwich.Bread {:v _v} 0]
    [:ml::Sandwich.Slice {:s t} (wat.core/+ 1 (ml/slices t))]))
