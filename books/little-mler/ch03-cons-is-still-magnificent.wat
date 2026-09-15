;; The Little MLer, chapter 3 (Cons Is Still Magnificent): remove_anchovy,
;; top_anchovy_with_cheese and subst_anchovy_by_cheese, which rebuild a pizza topping by
;; topping. Our own code and examples. Pizzas compare by structure.
;;
;; Run: wat books/little-mler/ch03-cons-is-still-magnificent.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch03-cons-is-still-magnificent.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; remove_anchovy
    (wat.test/assert-eq (wat.core/= (ml/remove-anchovy (ml/pizza '(anchovy onion anchovy anchovy cheese)))
                                    (ml/pizza '(onion cheese)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/remove-anchovy (ml/pizza '(sausage onion))) (ml/pizza '(sausage onion))) true)
    (wat.test/assert-eq (wat.core/= (ml/remove-anchovy (ml/crust)) (ml/crust)) true)

    ;; top_anchovy_with_cheese
    (wat.test/assert-eq (wat.core/= (ml/top-anchovy-with-cheese (ml/pizza '(onion anchovy cheese anchovy)))
                                    (ml/pizza '(onion cheese anchovy cheese cheese anchovy)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/top-anchovy-with-cheese (ml/pizza '(sausage cheese))) (ml/pizza '(sausage cheese)))
                        true)

    ;; subst_anchovy_by_cheese, directly and as the composition; the two agree
    (wat.test/assert-eq (wat.core/= (ml/subst-anchovy-by-cheese (ml/pizza '(onion anchovy cheese anchovy)))
                                    (ml/pizza '(onion cheese cheese cheese)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst-anchovy-by-cheese-composed (ml/pizza '(onion anchovy cheese anchovy)))
                                    (ml/pizza '(onion cheese cheese cheese)))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst-anchovy-by-cheese (ml/pizza '(anchovy sausage anchovy anchovy)))
                                    (ml/subst-anchovy-by-cheese-composed (ml/pizza '(anchovy sausage anchovy anchovy))))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst-anchovy-by-cheese (ml/pizza '(anchovy sausage anchovy anchovy)))
                                    (ml/pizza '(cheese sausage cheese cheese)))
                        true)

    (wat.kernel/println "little-mler ch03 cons-is-still-magnificent: ok")))
