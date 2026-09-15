;; The Little MLer, chapter 4 (Look to the Stars): tuples of datatype values, add_a_steak,
;; eq_main and has_steak. Our own code and examples.
;;
;; Run: wat books/little-mler/ch04-look-to-the-stars.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch04-look-to-the-stars.wat")

;; Is (Shrimp, Steak) a meza * main? Yes: a keyword-headed body under the declared type,
;; checked at startup. (A Tuple's element types widen to their enums; a Vector's do not,
;; F-019.)
(:wat::core::defn :mlx::steak-plate [] -> (:wat::core::Tuple :- [:ml::Meza :ml::Main])
  (:wat::core::Tuple (:ml::Meza.Shrimp {}) (:ml::Main.Steak {})))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; add_a_steak pairs any meza with a steak; tuples compare by structure
    (wat.test/assert-eq (wat.core/= (ml/add-a-steak (ml/shrimp)) (:wat::core::Tuple (ml/shrimp) (ml/steak))) true)
    (wat.test/assert-eq (wat.core/second (ml/add-a-steak (ml/hummus))) (ml/steak))
    (wat.test/assert-eq (wat.core/first (ml/add-a-steak (ml/calamari))) (ml/calamari))
    ;; the checked claim above is the value add_a_steak builds
    (wat.test/assert-eq (wat.core/= (:mlx::steak-plate) (ml/add-a-steak (ml/shrimp))) true)

    ;; eq_main, both ways, on the same pairs
    (wat.test/assert-eq (ml/eq-main (:wat::core::Tuple (ml/steak) (ml/steak))) true)
    (wat.test/assert-eq (ml/eq-main (:wat::core::Tuple (ml/steak) (ml/chicken))) false)
    (wat.test/assert-eq (ml/eq-main-by-cases (:wat::core::Tuple (ml/steak) (ml/steak))) true)
    (wat.test/assert-eq (ml/eq-main-by-cases (:wat::core::Tuple (ml/steak) (ml/chicken))) false)
    (wat.test/assert-eq (ml/eq-main-by-cases (:wat::core::Tuple (ml/eggplant) (ml/eggplant))) true)
    (wat.test/assert-eq (ml/eq-main-by-cases (:wat::core::Tuple (ml/ravioli) (ml/eggplant))) false)

    ;; has_steak looks only at the middle of the triple
    (wat.test/assert-eq (ml/has-steak (:wat::core::Tuple (ml/shrimp) (ml/steak) (ml/sundae))) true)
    (wat.test/assert-eq (ml/has-steak (:wat::core::Tuple (ml/hummus) (ml/ravioli) (ml/torte))) false)
    (wat.test/assert-eq (ml/has-steak (:wat::core::Tuple (ml/calamari) (ml/chicken) (ml/sundae))) false)

    (wat.kernel/println "little-mler ch04 look-to-the-stars: ok")))
