;; The Little MLer, chapter 10 (Building on Blocks): two structures for one signature, and a
;; functor applied to each. Our own code and examples.
;;
;; Run: wat books/little-mler/ch10-building-on-blocks.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch10-building-on-blocks.wat")

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int-struct (:ml::NumberAsInt)
                    num-struct (:ml::NumberAsNum)
                    ;; structure IntArith = PON(IntStruct); structure NumArith = PON(NumStruct)
                    int-n (:ml::int-ops int-struct)
                    num-n (:ml::num-ops num-struct)
                    int-arith (:ml::pon int-n)
                    num-arith (:ml::pon num-n)
                    ;; a third structure, whose number is an opaque newtype
                    sealed-struct (:ml::NumberAsSealed)
                    sealed-n (:ml::sealed-ops sealed-struct)
                    sealed-arith (:ml::pon sealed-n)]
    (:wat::core::do
      ;; each structure through the signature directly
      (:wat::test::assert-eq (:ml::N/reveal int-struct (:ml::N/succ int-struct (:ml::N/conceal int-struct 4))) 5)
      (:wat::test::assert-eq (:ml::N/reveal num-struct (:ml::N/succ num-struct (:ml::N/conceal num-struct 4))) 5)
      (:wat::test::assert-eq (:ml::N/is-zero num-struct (:ml::N/pred num-struct (:ml::N/conceal num-struct 1))) true)
      ;; the representations differ: 3 is an int in one and One_more_than(...) in the other
      (:wat::test::assert-eq (:ml::N/conceal int-struct 3) 3)
      (:wat::test::assert-eq (:wat::core::= (:ml::N/conceal num-struct 1) (:ml::Num.OneMoreThan {:n (:ml::Num.Zero {})})) true)

      ;; the functor's plus, one definition, through both
      (:wat::test::assert-eq ((:ml::NOps/reveal int-n) ((:ml::POps/plus int-arith) ((:ml::NOps/conceal int-n) 1) ((:ml::NOps/conceal int-n) 2))) 3)
      (:wat::test::assert-eq ((:ml::NOps/reveal num-n) ((:ml::POps/plus num-arith) ((:ml::NOps/conceal num-n) 1) ((:ml::NOps/conceal num-n) 2))) 3)
      (:wat::test::assert-eq ((:ml::NOps/reveal int-n) ((:ml::POps/plus int-arith) ((:ml::NOps/conceal int-n) 10) ((:ml::NOps/conceal int-n) 32))) 42)
      (:wat::test::assert-eq ((:ml::NOps/reveal num-n) ((:ml::POps/plus num-arith) ((:ml::NOps/conceal num-n) 0) ((:ml::NOps/conceal num-n) 0))) 0)
      (:wat::test::assert-eq ((:ml::NOps/reveal num-n) ((:ml::POps/plus num-arith) ((:ml::NOps/conceal num-n) 5) ((:ml::NOps/conceal num-n) 7))) 12)

      ;; the sealed structure: the same functor, an opaque representation (its values are
      ;; compared, never printed: F-030)
      (:wat::test::assert-eq ((:ml::NOps/reveal sealed-n) ((:ml::POps/plus sealed-arith) ((:ml::NOps/conceal sealed-n) 1) ((:ml::NOps/conceal sealed-n) 2))) 3)
      (:wat::test::assert-eq (:wat::core::= (:ml::N/conceal sealed-struct 3) (:ml::N/conceal sealed-struct 3)) true)
      (:wat::test::assert-eq (:wat::core::= (:ml::N/succ sealed-struct (:ml::N/conceal sealed-struct 2)) (:ml::N/conceal sealed-struct 3)) true)

      (:wat::kernel::println "little-mler ch10 building-on-blocks: ok"))))
