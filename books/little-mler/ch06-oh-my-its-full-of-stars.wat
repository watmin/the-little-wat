;; The Little MLer, chapter 6 (Oh My, It's Full of Stars!): fruit trees (flat_only,
;; split_only, contains_fruit, height, subst_in_tree, occurs), then S-expressions of fruit
;; over two mutually recursive datatypes. Our own code and examples. Values compare by
;; structure.
;;
;; Run: wat books/little-mler/ch06-oh-my-its-full-of-stars.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch06-oh-my-its-full-of-stars.wat")

;; Split(Split(Bud, Flat(Lemon, Bud)), Flat(Fig, Split(Bud, Bud)))
(wat.core/defn mlx/mixed [] :- :ml::Tree
  (ml/split (ml/split (ml/bud) (ml/flat (ml/fruit 'lemon) (ml/bud)))
            (ml/flat (ml/fruit 'fig) (ml/split (ml/bud) (ml/bud)))))

;; Split(Split(Flat(Fig, Bud), Flat(Fig, Bud)), Flat(Fig, Flat(Lemon, Flat(Apple, Bud))))
(wat.core/defn mlx/figs [] :- :ml::Tree
  (ml/split (ml/split (ml/flat (ml/fruit 'fig) (ml/bud)) (ml/flat (ml/fruit 'fig) (ml/bud)))
            (ml/flat (ml/fruit 'fig) (ml/flat (ml/fruit 'lemon) (ml/flat (ml/fruit 'apple) (ml/bud))))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; flat_only, split_only, contains_fruit
    (wat.test/assert-eq (ml/flat-only (ml/flat (ml/fruit 'apple) (ml/flat (ml/fruit 'peach) (ml/bud)))) true)
    (wat.test/assert-eq (ml/flat-only (ml/split (ml/bud) (ml/bud))) false)
    (wat.test/assert-eq (ml/flat-only (ml/bud)) true)
    (wat.test/assert-eq (ml/split-only (ml/split (ml/split (ml/bud) (ml/bud)) (ml/bud))) true)
    (wat.test/assert-eq (ml/split-only (mlx/mixed)) false)
    (wat.test/assert-eq (ml/contains-fruit (ml/split (ml/split (ml/bud) (ml/bud)) (ml/bud))) false)
    (wat.test/assert-eq (ml/contains-fruit (mlx/mixed)) true)

    ;; height
    (wat.test/assert-eq (ml/height (ml/bud)) 0)
    (wat.test/assert-eq (ml/height (ml/flat (ml/fruit 'apple) (ml/flat (ml/fruit 'peach) (ml/bud)))) 2)
    (wat.test/assert-eq (ml/height (mlx/mixed)) 3)

    ;; subst_in_tree and occurs
    (wat.test/assert-eq (wat.core/= (ml/subst-in-tree (ml/fruit 'apple) (ml/fruit 'fig) (mlx/figs))
                                    (ml/split (ml/split (ml/flat (ml/fruit 'apple) (ml/bud)) (ml/flat (ml/fruit 'apple) (ml/bud)))
                                              (ml/flat (ml/fruit 'apple) (ml/flat (ml/fruit 'lemon) (ml/flat (ml/fruit 'apple) (ml/bud))))))
                        true)
    (wat.test/assert-eq (ml/occurs (ml/fruit 'fig) (mlx/figs)) 3)
    (wat.test/assert-eq (ml/occurs (ml/fruit 'apple) (mlx/figs)) 1)
    (wat.test/assert-eq (ml/occurs (ml/fruit 'pear) (mlx/figs)) 0)

    ;; S-expressions of fruit
    (wat.test/assert-eq (ml/occurs-in-slist (ml/fruit 'fig) (ml/fruit-slist '(fig (apple fig) peach))) 2)
    (wat.test/assert-eq (ml/occurs-in-slist (ml/fruit 'apple) (ml/fruit-slist '(fig ((apple)) (apple)))) 2)
    (wat.test/assert-eq (wat.core/= (ml/subst-in-slist (ml/fruit 'apple) (ml/fruit 'fig) (ml/fruit-slist '(fig (apple fig) peach)))
                                    (ml/fruit-slist '(apple (apple apple) peach)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-from-slist (ml/fruit 'fig) (ml/fruit-slist '(fig (apple fig) peach)))
                                    (ml/fruit-slist '((apple) peach)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-from-slist (ml/fruit 'fig) (ml/fruit-slist '((fig) fig)))
                                    (ml/fruit-slist '(())))
                        true)

    (wat.kernel/println "little-mler ch06 oh-my-its-full-of-stars: ok")))
