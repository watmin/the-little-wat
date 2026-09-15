;; The Little MLer, chapter 2 (Matchmaker, Matchmaker): only_onions, is_vegetarian, and a
;; generic shish whose bottom is a rod, a plate or an int. Our own code and examples.
;;
;; Run: wat books/little-mler/ch02-matchmaker.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch02-matchmaker.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; the kebab builder
    (wat.test/assert-eq (wat.core/= (ml/kebab '(onion lamb))
                                    (:ml::ShishKebab.Onion {:k (:ml::ShishKebab.Lamb {:k (:ml::ShishKebab.Skewer {})})}))
                        true)

    ;; only_onions
    (wat.test/assert-eq (ml/only-onions (ml/kebab '(onion onion))) true)
    (wat.test/assert-eq (ml/only-onions (ml/kebab '(onion lamb))) false)
    (wat.test/assert-eq (ml/only-onions (ml/kebab '(onion tomato onion))) false)
    (wat.test/assert-eq (ml/only-onions (ml/kebab '())) true)

    ;; is_vegetarian: onions and tomatoes, no lamb
    (wat.test/assert-eq (ml/is-vegetarian (ml/kebab '(onion tomato onion))) true)
    (wat.test/assert-eq (ml/is-vegetarian (ml/kebab '(onion lamb tomato))) false)
    (wat.test/assert-eq (ml/is-vegetarian (ml/kebab '())) true)

    ;; a generic shish: the same functions over any bottom
    (wat.test/assert-eq (ml/is-veggie (ml/shish '(onion tomato) (ml/dagger))) true)
    (wat.test/assert-eq (ml/is-veggie (ml/shish '(tomato lamb) (ml/gold-plate))) false)
    (wat.test/assert-eq (ml/is-veggie (ml/shish '(onion) 52)) true)
    (wat.test/assert-eq (ml/what-bottom (ml/shish '(onion tomato) (ml/dagger))) (ml/dagger))
    (wat.test/assert-eq (ml/what-bottom (ml/shish '(lamb lamb onion) (ml/gold-plate))) (ml/gold-plate))
    (wat.test/assert-eq (ml/what-bottom (ml/shish '(tomato) 52)) 52)
    (wat.test/assert-eq (ml/what-bottom (ml/shish '() (ml/sword))) (ml/sword))

    (wat.kernel/println "little-mler ch02 matchmaker: ok")))
