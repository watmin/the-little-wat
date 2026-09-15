;; The Little MLer, chapter 9 (Oh No!): raising and handling exceptions, as Results.
;; where_is, list_item, find and path. Our own code and examples.
;;
;; Run: wat books/little-mler/ch09-oh-no.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch09-oh-no.wat")

;; (Ix 5) (Ix 4) Bacon (Ix 2) (Ix 7): find(1) goes 1 -> 5 -> 7 (out of range) -> 3 (Bacon).
(wat.core/defn mlx/t [] :- :ml::Boxes
  (ml/boxes [(ml/ix 5) (ml/ix 4) (ml/bacon) (ml/ix 2) (ml/ix 7)]))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; where_is, and its handler
    (wat.test/assert-eq (ml/where-is-handled (ml/boxes [(ml/ix 5) (ml/ix 13) (ml/bacon) (ml/ix 8)])) 3)
    (wat.test/assert-eq (ml/where-is-handled (ml/boxes [(ml/bacon) (ml/ix 8)])) 1)
    ;; no bacon: the raise abandons the two pending (1 + ...), so the answer is the 0 it
    ;; carried, not 2
    (wat.test/assert-eq (ml/where-is-handled (ml/boxes [(ml/ix 5) (ml/ix 13)])) 0)
    (wat.test/assert-eq (:wat::core::match (ml/where-is (ml/boxes [(ml/ix 5)]))
                          [:wat::core::Result.Ok {:value _v} false]
                          [:wat::core::Result.Err {:error _e} true])
                        true)

    ;; list_item
    (wat.test/assert-eq (wat.core/= (ml/list-item 1 (mlx/t)) (:wat::core::Result.Ok {:value (ml/ix 5)})) true)
    (wat.test/assert-eq (wat.core/= (ml/list-item 3 (mlx/t)) (:wat::core::Result.Ok {:value (ml/bacon)})) true)
    (wat.test/assert-eq (:wat::core::match (ml/list-item 6 (mlx/t))
                          [:wat::core::Result.Ok {:value _b} false]
                          [:wat::core::Result.Err {:error _e} true])
                        true)

    ;; find and path
    (wat.test/assert-eq (ml/find 1 (mlx/t)) 3)
    (wat.test/assert-eq (ml/find 5 (mlx/t)) 3)
    (wat.test/assert-eq (ml/find 3 (mlx/t)) 3)
    (wat.test/assert-eq (ml/path 1 (mlx/t)) [1 5 7 3])
    (wat.test/assert-eq (ml/path 3 (mlx/t)) [3])

    (wat.kernel/println "little-mler ch09 oh-no: ok")))
