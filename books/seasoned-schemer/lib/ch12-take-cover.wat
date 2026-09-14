;; The Seasoned Schemer, ch 12 (Take Cover): the definitions. The book uses letrec to hide a
;; recursive helper inside a function, where it can see arguments that never change instead
;; of passing them on every call. wat has no letrec or letfn (FINDINGS.md, R-001), but
;; letrec is Y: each helper below is a lambda closed over the unchanging argument, and
;; ls/Y (Little Schemer ch 9, generic per C-010) ties its recursion.
;;
;; Needs the Little Schemer libs ch01 through ch09 (for ls/Y) loaded first. No main here.
;; Lambdas that take a function are keyword-spelled (F-010).

;; ── the canonical wat route, for contrast: a top-level helper that is passed a ─────

(wat.core/defn ss/mr [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) (ls/empty-list))
    ((ls/eq? (ls/car lat) a) (ss/mr a (ls/cdr lat)))
    (:else (ls/cons (ls/car lat) (ss/mr a (ls/cdr lat))))))

(wat.core/defn ss/multirember-top [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
  (ss/mr a lat))

;; ── the letrec shape, via Y: the helper closes over a ──────────────────────────────

(wat.core/defn ss/multirember [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
  ((ls/Y (:wat::core::fn [mr <- [:wat::WatAST :-> :wat::WatAST]] -> [:wat::WatAST :-> :wat::WatAST]
           (:wat::core::fn [l <- :wat::WatAST] -> :wat::WatAST
             (:wat::core::cond
               ((ls/null? l) (ls/empty-list))
               ((ls/eq? (ls/car l) a) (mr (ls/cdr l)))
               (:else (ls/cons (ls/car l) (mr (ls/cdr l))))))))
   lat))

(wat.core/defn ss/member? [a :- :wat::WatAST lat :- :wat::WatAST] :- wat.type/bool
  ((ls/Y (:wat::core::fn [yes? <- [:wat::WatAST :-> :wat::core::bool]] -> [:wat::WatAST :-> :wat::core::bool]
           (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::bool
             (:wat::core::cond
               ((ls/null? l) false)
               ((ls/eq? (ls/car l) a) true)
               (:else (yes? (ls/cdr l)))))))
   lat))

;; union: two hidden helpers. U walks set1; M, a member? closed over set2's walk, is Y'd
;; separately. The book hides member? inside union for the same reason.
(wat.core/defn ss/union [set1 :- :wat::WatAST set2 :- :wat::WatAST] :- :wat::WatAST
  ((ls/Y (:wat::core::fn [U <- [:wat::WatAST :-> :wat::WatAST]] -> [:wat::WatAST :-> :wat::WatAST]
           (:wat::core::fn [s <- :wat::WatAST] -> :wat::WatAST
             (:wat::core::cond
               ((ls/null? s) set2)
               ((ss/member? (ls/car s) set2) (U (ls/cdr s)))
               (:else (ls/cons (ls/car s) (U (ls/cdr s))))))))
   set1))

;; two-in-a-row?: the helper takes TWO arguments (preceding, lat), so it is curried. Y's
;; result type B is then itself a function type [lat :-> bool].
(wat.core/defn ss/two-in-a-row? [lat :- :wat::WatAST] :- wat.type/bool
  (wat.core/if (ls/null? lat)
    false
    (((ls/Y (:wat::core::fn [W <- [:wat::WatAST :-> [:wat::WatAST :-> :wat::core::bool]]]
              -> [:wat::WatAST :-> [:wat::WatAST :-> :wat::core::bool]]
              (:wat::core::fn [preceding <- :wat::WatAST] -> [:wat::WatAST :-> :wat::core::bool]
                (:wat::core::fn [l <- :wat::WatAST] -> :wat::core::bool
                  (:wat::core::if (ls/null? l)
                    false
                    (:wat::core::or (ls/eq? (ls/car l) preceding)
                                    ((W (ls/car l)) (ls/cdr l))))))))
      (ls/car lat))
     (ls/cdr lat))))

;; sum-of-prefixes: curried the same way, over (sonssf, tup).
(wat.core/defn ss/sum-of-prefixes [tup :- (wat.type/Vector :- [wat.type/i64])]
  :- (wat.type/Vector :- [wat.type/i64])
  (((ls/Y (:wat::core::fn [S <- [:wat::core::i64 :-> [(:wat::core::Vector :- [:wat::core::i64])
                                                        :-> (:wat::core::Vector :- [:wat::core::i64])]]]
            -> [:wat::core::i64 :-> [(:wat::core::Vector :- [:wat::core::i64])
                                     :-> (:wat::core::Vector :- [:wat::core::i64])]]
            (:wat::core::fn [sonssf <- :wat::core::i64]
              -> [(:wat::core::Vector :- [:wat::core::i64]) :-> (:wat::core::Vector :- [:wat::core::i64])]
              (:wat::core::fn [t <- (:wat::core::Vector :- [:wat::core::i64])]
                -> (:wat::core::Vector :- [:wat::core::i64])
                (:wat::core::if (:wat::core::empty? t)
                  []
                  (:wat::core::let [s (:wat::core::+ sonssf (:wat::core::first t))]
                    (:wat::core::concat [s] ((S s) (:wat::core::rest t)))))))))
    0)
   tup))
