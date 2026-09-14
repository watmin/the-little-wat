;; The Seasoned Schemer, ch 19 (Absconding with the Jewels): the definitions. The book saves
;; continuations with letcc and re-enters them later: to rebuild a pizza around a new filling
;; (toppings), and to pull the leaves of a list one at a time (get-first, get-next).
;;
;; wat has no first-class continuations (FINDINGS.md, R-003). Two routes cover the uses:
;;   - continuation-passing style: the rest of a computation is an ordinary function, which
;;     can be returned and reused. Unlike a real continuation, though, it RETURNS to its caller.
;;   - lazy streams: a generator is a stream that computes each leaf when asked.
;;
;; Needs lib/counter.wat, ../little-schemer/lib/ch01-toys.wat and
;; ../little-schemer/lib/ch04-numbers-games.wat (zero?, sub1) loaded first. No main here.

;; ── a continuation, captured as a function ────────────────────────────────────────

;; deep-k: the book's deepB reaches its bottom and saves "the rest of the computation" as
;; toppings. Here, reaching the bottom RETURNS that rest, k, which wraps whatever it is
;; given in m lists.
(wat.core/defn ss/deep-k [m :- wat.type/i64 k :- [:wat::WatAST :-> :wat::WatAST]]
  :- [:wat::WatAST :-> :wat::WatAST]
  (wat.core/if (ls/zero? m)
    k
    (ss/deep-k (ls/sub1 m)
               (wat.core/fn [x :- :wat::WatAST] :- :wat::WatAST
                 (k (ls/cons x '()))))))

(wat.core/defn ss/toppings [m :- wat.type/i64] :- [:wat::WatAST :-> :wat::WatAST]
  (ss/deep-k m (wat.core/fn [x :- :wat::WatAST] :- :wat::WatAST x)))

;; ── a generator, as a lazy stream of leaves ───────────────────────────────────────
;; ss/visits counts leaf work: it rises by one each time a leaf is actually produced, which
;; only happens when a consumer asks for it.

(:wat::core::def :ss::visits (:ss::new-counter 0))

;; leaves-then: the leaves of l, then the stream more.
(wat.core/defn ss/leaves-then [l :- :wat::WatAST more :- (:wat::stream::Stream :- [:wat::WatAST])]
  :- (:wat::stream::Stream :- [:wat::WatAST])
  (wat.core/cond
    ((ls/null? l) more)
    ((ls/atom? (ls/car l))
     (:wat::stream::lazy
       (wat.core/let [_v (ss/counter-add! :ss::visits 1)]
         (:wat::stream::cons (ls/car l) (ss/leaves-then (ls/cdr l) more)))))
    (:else
     (ss/leaves-then (ls/car l)
                     (:wat::stream::lazy (ss/leaves-then (ls/cdr l) more))))))

(wat.core/defn ss/leaves [l :- :wat::WatAST] :- (:wat::stream::Stream :- [:wat::WatAST])
  (ss/leaves-then l (:wat::stream::empty)))

;; get-first: the first leaf, or () when there is none.
(wat.core/defn ss/get-first [l :- :wat::WatAST] :- :wat::WatAST
  (:wat::core::match (:wat::stream::next (ss/leaves l))
    [:wat::stream::NextOutcome.Item {:value v :rest _r} v]
    [:wat::stream::NextOutcome.Exhausted {} '()]))

;; two-in-a-row*?: do two equal leaves ever come one after the other, at any depth?
(wat.core/defn ss/two-in-a-row-s? [prev :- :wat::WatAST s :- (:wat::stream::Stream :- [:wat::WatAST])]
  :- wat.type/bool
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Item {:value v :rest r}
      (wat.core/or (ls/eq? v prev) (ss/two-in-a-row-s? v r))]
    [:wat::stream::NextOutcome.Exhausted {} false]))

(wat.core/defn ss/two-in-a-row*? [l :- :wat::WatAST] :- wat.type/bool
  (:wat::core::match (:wat::stream::next (ss/leaves l))
    [:wat::stream::NextOutcome.Item {:value v :rest r} (ss/two-in-a-row-s? v r)]
    [:wat::stream::NextOutcome.Exhausted {} false]))
