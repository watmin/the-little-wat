;; koans/idiom/11-lazy-sequences.wat: the lazy-sequence koans that don't port literally
;; (koans/literal/11-lazy-sequences.tsv), each said the way wat says it, or marked as having no
;; wat route. Keyword spelling throughout, so the checker sees every call (F-014). Markers as in
;; koans/idiom/01-equalities.wat.
;;
;; range always takes its start; take and drop take the collection first and answer a lazy
;; Stream, which into makes a Vector. There is no iterate or repeat (P-001), so iterate is
;; written here, eagerly, for the first n. It is written once per element type: written once,
;; generic over T, it passes the checker and dies at runtime, because (:wat::core::Vector :- [T])
;; can't be built from a function's own type variable (F-009;
;; probes/koans/generic-vector-constructor.wat).
;;
;; Run from the repository root: wat koans/idiom/11-lazy-sequences.wat

(:wat::core::defn :koan::iterate-ints [f <- [:wat::core::i64 :-> :wat::core::i64] x <- :wat::core::i64 n <- :wat::core::i64] -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:wat::core::= n 0)
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] x) (:koan::iterate-ints f (f x) (:wat::core::- n 1)))))

(:wat::core::defn :koan::iterate-strings [f <- [:wat::core::String :-> :wat::core::String] x <- :wat::core::String n <- :wat::core::i64] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::if (:wat::core::= n 0)
    (:wat::core::Vector :- [:wat::core::String])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] x) (:koan::iterate-strings f (f x) (:wat::core::- n 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::range 2 5)) [2 3 4]) ; row 1
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::range 0 3)) [0 1 2]) ; row 2
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::take (:wat::core::range 0 50) 4)) [0 1 2 3]) ; row 3
    (:wat::test::assert-eq (:wat::core::into (:wat::core::Vector :- [:wat::core::i64]) (:wat::core::drop (:wat::core::range 0 50) 47)) [47 48 49]) ; row 4
    (:wat::test::assert-eq (:koan::iterate-ints (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x 3)) 1 5) [1 3 9 27 81]) ; row 5
    ;; no repeat: map a constant over a range
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::keyword :z) (:wat::core::range 0 3)) [:z :z :z]) ; row 6
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::String "hi") (:wat::core::range 0 5))
                           (:koan::iterate-strings (:wat::core::fn [s <- :wat::core::String] -> :wat::core::String s) "hi" 5)) ; row 7
    (:wat::kernel::println "koans idiom 11-lazy-sequences: ok")))
