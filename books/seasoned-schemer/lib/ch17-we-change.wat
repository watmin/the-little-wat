;; The Seasoned Schemer, ch 17 (We Change, Therefore We Are!): the definitions. Counting
;; conses with a global counter N that consC bumps. The payoff is a measurement: an escaping
;; rember1* performs no conses at all when the atom is absent, while a naive one performs
;; them anyway.
;;
;; N is a true global: a keyword-named top-level def of a started Counter service
;; (FINDINGS.md, C-014). Needs lib/counter.wat, ../little-schemer/lib/ch01-toys.wat, ch04
;; (sub1, zero?, eqan?) and ch05 (eqlist?) loaded first. No main here.

(:wat::core::def :ss::N (:ss::new-counter 0))

;; consC: cons, counted.
(wat.core/defn ss/consC [x :- :wat::WatAST y :- :wat::WatAST] :- :wat::WatAST
  (wat.core/let [_n (ss/counter-add! :ss::N 1)]
    (ls/cons x y)))

;; deep-C: pizza wrapped in m lists, every wrapping a counted cons.
(wat.core/defn ss/deep-C [m :- wat.type/i64] :- :wat::WatAST
  (wat.core/if (ls/zero? m)
    'pizza
    (ss/consC (ss/deep-C (ls/sub1 m)) '())))

;; supercounter: run f on n, n-1, ... 0, then report how many conses were counted in all.
(wat.core/defn ss/supercounter-run [f :- [wat.type/i64 :-> :wat::WatAST] n :- wat.type/i64] :- wat.type/nil
  (wat.core/if (ls/zero? n)
    (wat.core/do (f n) nil)
    (wat.core/do (f n) (ss/supercounter-run f (ls/sub1 n)))))

(wat.core/defn ss/supercounter [f :- [wat.type/i64 :-> :wat::WatAST] n :- wat.type/i64] :- wat.type/i64
  (wat.core/do
    (ss/supercounter-run f n)
    (ss/counter-get :ss::N)))

;; ── rember1* with counted conses, two ways ────────────────────────────────────────

;; The escaping version (ch 14's rm, with consC): Err nil means "a is nowhere here", and it
;; skips every pending cons on its way out.
(wat.core/defn ss/rmC [a :- :wat::WatAST l :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST wat.type/nil])
  (wat.core/cond
    ((ls/null? l) (:wat::core::Result.Err {:error nil}))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eq? (ls/car l) a)
       (:wat::core::Result.Ok {:value (ls/cdr l)})
       (wat.core/let [more (:wat::core::Result/try (ss/rmC a (ls/cdr l)))]
         (:wat::core::Result.Ok {:value (ss/consC (ls/car l) more)}))))
    (:else
      (:wat::core::match (ss/rmC a (ls/car l))
        [:wat::core::Result.Ok {:value new-car}
          (:wat::core::Result.Ok {:value (ss/consC new-car (ls/cdr l))})]
        [:wat::core::Result.Err {:error _}
          (wat.core/let [more (:wat::core::Result/try (ss/rmC a (ls/cdr l)))]
            (:wat::core::Result.Ok {:value (ss/consC (ls/car l) more)}))]))))

(wat.core/defn ss/rember1*C [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (:wat::core::match (ss/rmC a l)
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error _} l]))

;; The naive version: no escape. It rebuilds the list as it goes, and uses eqlist? to notice
;; whether a sub-list changed, so it conses even when nothing is removed.
(wat.core/defn ss/R2 [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? l) '())
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eq? (ls/car l) a)
       (ls/cdr l)
       (ss/consC (ls/car l) (ss/R2 a (ls/cdr l)))))
    (:else
      (wat.core/let [av (ss/R2 a (ls/car l))]
        (wat.core/if (ls/eqlist? (ls/car l) av)
          (ss/consC (ls/car l) (ss/R2 a (ls/cdr l)))
          (ss/consC av (ls/cdr l)))))))

(wat.core/defn ss/rember1*C2 [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (ss/R2 a l))
