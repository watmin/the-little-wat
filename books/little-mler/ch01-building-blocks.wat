;; The Little MLer, chapter 1 (Building Blocks): values of datatypes, and their types. Our
;; own code and examples.
;;
;; The chapter's questions are mostly "is this value of that type?". A yes is written as a
;; zero-argument defn whose declared return is the type, with a KEYWORD-headed constructor
;; body, and the claim is checked when the program starts. (A symbol-headed body would make
;; the claim vacuous: such calls infer as a fresh type, F-014.) A no is a probe that must be
;; refused: probes/ml/type-claim-refused.wat.
;;
;; Run: wat books/little-mler/ch01-building-blocks.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-building-blocks.wat")

;; Is One_more_than(One_more_than(Zero)) a num? Yes.
(:wat::core::defn :mlx::two [] -> :ml::Num
  (:ml::Num.OneMoreThan {:n (:ml::Num.OneMoreThan {:n (:ml::Num.Zero {})})}))

;; Is Bread(Pepper) a seasoning open_faced_sandwich? Yes.
(:wat::core::defn :mlx::pepper-sandwich [] -> (:ml::Sandwich :- [:ml::Seasoning])
  (:ml::Sandwich.Bread {:v (:ml::Seasoning.Pepper {})}))

;; Is Slice(Slice(Bread(0))) an int open_faced_sandwich? Yes.
(:wat::core::defn :mlx::int-club [] -> (:ml::Sandwich :- [:wat::core::i64])
  (:ml::Sandwich.Slice {:s (:ml::Sandwich.Slice {:s (:ml::Sandwich.Bread {:v 0})})}))

;; Is Bread(One_more_than(Zero)) a num open_faced_sandwich? Yes: the filling may be any type.
(:wat::core::defn :mlx::num-sandwich [] -> (:ml::Sandwich :- [:ml::Num])
  (:ml::Sandwich.Bread {:v (:ml::Num.OneMoreThan {:n (:ml::Num.Zero {})})}))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; nums
    (wat.test/assert-eq (ml/num->i64 (:mlx::two)) 2)
    (wat.test/assert-eq (ml/num->i64 (ml/zero)) 0)
    (wat.test/assert-eq (ml/num->i64 (ml/i64->num 5)) 5)
    ;; values of a datatype compare by structure
    (wat.test/assert-eq (wat.core/= (ml/i64->num 2) (:mlx::two)) true)
    (wat.test/assert-eq (wat.core/= (ml/i64->num 3) (:mlx::two)) false)
    (wat.test/assert-eq (wat.core/= (ml/salt) (ml/pepper)) false)
    (wat.test/assert-eq (wat.core/= (ml/salt) (ml/salt)) true)

    ;; sandwiches of any filling
    (wat.test/assert-eq (ml/filling (:mlx::pepper-sandwich)) (ml/pepper))
    (wat.test/assert-eq (ml/filling (:mlx::int-club)) 0)
    (wat.test/assert-eq (ml/slices (:mlx::int-club)) 2)
    (wat.test/assert-eq (ml/num->i64 (ml/filling (:mlx::num-sandwich))) 1)
    (wat.test/assert-eq (ml/filling (ml/slice (ml/bread true))) true)
    (wat.test/assert-eq (ml/slices (ml/slice (ml/slice (ml/slice (ml/bread "rye"))))) 3)

    (wat.kernel/println "little-mler ch01 building-blocks: ok")))
