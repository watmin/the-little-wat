;; The Little MLer, chapter 8 (Bows and Arrows): subst over any equality, subst_pred with a
;; range predicate, curried in_range_c and subst_c, and three ways to combine lists. Our own
;; code and examples. Lists compare by structure.
;;
;; Run: wat books/little-mler/ch08-bows-and-arrows.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch08-bows-and-arrows.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; subst_int, subst_orapl, and subst with the equality passed in
    (wat.test/assert-eq (wat.core/= (ml/subst-int 11 15 (ml/from-vec [15 6 15 17 15 8])) (ml/from-vec [11 6 11 17 11 8])) true)
    (wat.test/assert-eq (wat.core/= (ml/subst-orapl (ml/apple) (ml/orange) (ml/from-vec [(ml/orange) (ml/apple) (ml/orange)]))
                                    (ml/from-vec [(ml/apple) (ml/apple) (ml/apple)]))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst ml/eq-orapl (ml/apple) (ml/orange) (ml/from-vec [(ml/orange) (ml/apple) (ml/orange)]))
                                    (ml/from-vec [(ml/apple) (ml/apple) (ml/apple)]))
                        true)
    (wat.test/assert-eq (wat.core/= (ml/subst (wat.core/fn [x :- wat.type/i64 y :- wat.type/i64] :- wat.type/bool (wat.core/= x y))
                                              11 15 (ml/from-vec [15 6 15 17 15 8]))
                                    (ml/from-vec [11 6 11 17 11 8]))
                        true)

    ;; in_range and subst_pred: 17 and 6 and 8 are outside (11, 16)
    (wat.test/assert-eq (ml/in-range 11 16 15) true)
    (wat.test/assert-eq (ml/in-range 11 16 16) false)
    (wat.test/assert-eq (wat.core/= (ml/subst-pred (ml/in-range-c 11 16) 22 (ml/from-vec [15 6 15 17 15 8]))
                                    (ml/from-vec [22 6 22 17 22 8]))
                        true)
    (wat.test/assert-eq (wat.core/= ((ml/subst-c (ml/in-range-c 11 16)) 22 (ml/from-vec [15 6 15 17 15 8]))
                                    (ml/from-vec [22 6 22 17 22 8]))
                        true)

    ;; combine, combine_c, prefixer_123, combine_s: all append
    (wat.test/assert-eq (wat.core/= (ml/combine (ml/from-vec [1 2 3]) (ml/from-vec [12 11 5 7])) (ml/from-vec [1 2 3 12 11 5 7])) true)
    (wat.test/assert-eq (wat.core/= ((ml/combine-c (ml/from-vec [1 2 3])) (ml/from-vec [12 11 5 7])) (ml/from-vec [1 2 3 12 11 5 7])) true)
    (wat.test/assert-eq (wat.core/= ((ml/prefixer-123) (ml/from-vec [4])) (ml/from-vec [1 2 3 4])) true)
    (wat.test/assert-eq (wat.core/= ((ml/combine-s (ml/from-vec [1 2 3])) (ml/from-vec [12 11 5 7])) (ml/from-vec [1 2 3 12 11 5 7])) true)
    (wat.test/assert-eq (wat.core/= ((ml/combine-s (ml/from-vec [])) (ml/from-vec [4])) (ml/from-vec [4])) true)

    (wat.kernel/println "little-mler ch08 bows-and-arrows: ok")))
