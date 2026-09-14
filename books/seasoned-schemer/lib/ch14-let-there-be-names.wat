;; The Seasoned Schemer, ch 14 (Let There Be Names): the definitions. let names an
;; intermediate value so it is computed once, and letcc (with the book's try) jumps out of
;; a search the moment it finds, or fails to find, what it wants. The escapes use
;; Result/try, as in ch 13 (FINDINGS.md, C-006, C-013).
;;
;; Needs ../little-schemer/lib/ch01-toys.wat and lib/ch04-numbers-games.wat (add1) loaded
;; first. No main here. Matches and Result constructors are keyword-spelled (F-017, F-009).

;; ── leftmost: the first atom, even when empty lists come first ────────────────────

;; Err carries the atom found, which jumps straight out. Ok nil means "no atom in this
;; part, keep looking".
(wat.core/defn ss/lm [l :- :wat::WatAST] :- (wat.type/Result :- [wat.type/nil :wat::WatAST])
  (wat.core/cond
    ((ls/null? l) (:wat::core::Result.Ok {:value nil}))
    ((ls/atom? (ls/car l)) (:wat::core::Result.Err {:error (ls/car l)}))
    (:else
      (wat.core/do
        (:wat::core::Result/try (ss/lm (ls/car l)))
        (ss/lm (ls/cdr l))))))

;; No atom anywhere gives ().
(wat.core/defn ss/leftmost [l :- :wat::WatAST] :- :wat::WatAST
  (:wat::core::match (ss/lm l)
    [:wat::core::Result.Ok {:value _} '()]
    [:wat::core::Result.Err {:error a} a]))

;; ── rember1*: remove the leftmost occurrence of a, at any depth ───────────────────
;; The book tries the removal and, if a is nowhere (the "oh" continuation), keeps l as it
;; was. Here rm answers Ok with the new list, or Err nil when a is nowhere in l.

(wat.core/defn ss/rm [a :- :wat::WatAST l :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST wat.type/nil])
  (wat.core/cond
    ((ls/null? l) (:wat::core::Result.Err {:error nil}))
    ((ls/atom? (ls/car l))
     (wat.core/if (ls/eq? (ls/car l) a)
       (:wat::core::Result.Ok {:value (ls/cdr l)})
       (wat.core/let [more (:wat::core::Result/try (ss/rm a (ls/cdr l)))]
         (:wat::core::Result.Ok {:value (ls/cons (ls/car l) more)}))))
    (:else
      (:wat::core::match (ss/rm a (ls/car l))
        [:wat::core::Result.Ok {:value new-car}
          (:wat::core::Result.Ok {:value (ls/cons new-car (ls/cdr l))})]
        [:wat::core::Result.Err {:error _}
          (wat.core/let [more (:wat::core::Result/try (ss/rm a (ls/cdr l)))]
            (:wat::core::Result.Ok {:value (ls/cons (ls/car l) more)}))]))))

(wat.core/defn ss/rember1* [a :- :wat::WatAST l :- :wat::WatAST] :- :wat::WatAST
  (:wat::core::match (ss/rm a l)
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error _} l]))

;; ── depth*: how deeply lists nest, with let naming each side once ─────────────────

(wat.core/defn ss/max [n :- wat.type/i64 m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/> n m) n m))

(wat.core/defn ss/depth* [l :- :wat::WatAST] :- wat.type/i64
  (wat.core/cond
    ((ls/null? l) 1)
    ((ls/atom? (ls/car l)) (ss/depth* (ls/cdr l)))
    (:else
      (wat.core/let [a (ls/add1 (ss/depth* (ls/car l)))
                     d (ss/depth* (ls/cdr l))]
        (ss/max a d)))))
