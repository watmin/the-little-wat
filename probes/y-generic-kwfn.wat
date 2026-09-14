;; y-generic-kwfn.wat: the same generic Y over a generic self-referential struct as
;; y-generic.wat, but the two lambdas passed to Y are KEYWORD-spelled fns. That sidesteps
;; F-010, so the real question gets answered: does a struct that is generic AND refers to
;; itself work?
;; Expected: 3 (length of '(pear plum fig) via Y), then 120 (5! via the same Y).

(:wat::core::defstruct :u::Knot :- [A B]
  [unroll <- [(:u::Knot :- [A B]) :-> [A :-> B]]])

(wat.core/defn u/Y :- [A B]
  [le :- [[A :-> B] :-> [A :-> B]]]
  :- [A :-> B]
  (wat.core/let
    [g (wat.core/fn [k :- (:u::Knot :- [A B])] :- [A :-> B]
         (le (wat.core/fn [x :- A] :- B
               (wat.core/let [u (:u::Knot/unroll k)
                              h (u k)]
                 (h x)))))
     knot (:u::Knot :unroll g)]
    (g knot)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let
    [len  (u/Y (:wat::core::fn [self <- [:wat::WatAST :-> :wat::core::i64]] -> [:wat::WatAST :-> :wat::core::i64]
                 (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::i64
                   (:wat::core::if (:wat::core::empty? l) 0 (:wat::core::+ 1 (self (:wat::core::rest l)))))))
     fact (u/Y (:wat::core::fn [self <- [:wat::core::i64 :-> :wat::core::i64]] -> [:wat::core::i64 :-> :wat::core::i64]
                 (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::i64
                   (:wat::core::if (:wat::core::= n 0) 1 (:wat::core::* n (self (:wat::core::- n 1)))))))]
    (wat.core/do
      (wat.kernel/println (len (wat.core/quote (pear plum fig))))
      (wat.kernel/println (fact 5)))))
