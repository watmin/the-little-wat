;; The Little MLer, chapter 5 (Couples Are Magnificent, Too): a pizza of fish or of ints,
;; built from couples, with rem_anchovy, rem_tuna, eq_fish, rem_fish, rem_int, subst_fish and
;; subst_int. Our own code and examples. Pizzas compare by structure.
;;
;; Run: wat books/little-mler/ch05-couples-are-magnificent-too.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch05-couples-are-magnificent-too.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; the builders
    (wat.test/assert-eq (wat.core/= (ml/fish-pizza '(anchovy lox))
                                    (ml/topping (ml/fish 'anchovy) (ml/topping (ml/fish 'lox) (ml/bottom))))
                        true)

    ;; rem_anchovy and rem_tuna
    (wat.test/assert-eq (wat.core/= (ml/rem-anchovy (ml/fish-pizza '(anchovy lox anchovy tuna))) (ml/fish-pizza '(lox tuna)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-tuna (ml/fish-pizza '(anchovy tuna lox tuna))) (ml/fish-pizza '(anchovy lox)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-anchovy (ml/fish-pizza '())) (ml/fish-pizza '())) true)

    ;; eq_fish by cases agrees with value equality
    (wat.test/assert-eq (ml/eq-fish (ml/fish 'anchovy) (ml/fish 'anchovy)) true)
    (wat.test/assert-eq (ml/eq-fish (ml/fish 'lox) (ml/fish 'tuna)) false)
    (wat.test/assert-eq (ml/eq-fish (ml/fish 'tuna) (ml/fish 'tuna)) (wat.core/= (ml/fish 'tuna) (ml/fish 'tuna)))
    (wat.test/assert-eq (ml/eq-fish (ml/fish 'tuna) (ml/fish 'anchovy)) (wat.core/= (ml/fish 'tuna) (ml/fish 'anchovy)))

    ;; rem_fish removes any one kind of fish; rem_int the same over ints
    (wat.test/assert-eq (wat.core/= (ml/rem-fish (ml/fish 'anchovy) (ml/fish-pizza '(anchovy lox anchovy tuna)))
                                    (ml/fish-pizza '(lox tuna)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-fish (ml/fish 'lox) (ml/fish-pizza '(lox lox tuna))) (ml/fish-pizza '(tuna)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/rem-int 3 (ml/int-pizza [3 2 3 2 1])) (ml/int-pizza [2 2 1])) true)
    (wat.test/assert-eq (wat.core/= (ml/rem-int 9 (ml/int-pizza [3 2])) (ml/int-pizza [3 2])) true)

    ;; subst_fish and subst_int
    (wat.test/assert-eq (wat.core/= (ml/subst-fish (ml/fish 'lox) (ml/fish 'anchovy) (ml/fish-pizza '(anchovy tuna anchovy)))
                                    (ml/fish-pizza '(lox tuna lox)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst-int 5 3 (ml/int-pizza [3 2 3])) (ml/int-pizza [5 2 5])) true)

    (wat.kernel/println "little-mler ch05 couples-are-magnificent-too: ok")))
