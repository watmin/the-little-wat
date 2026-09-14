;; The Seasoned Schemer, ch 18 (We Change, Therefore We Are the Same!): the definitions.
;; Lists whose tails can be changed in place, so two lists can share structure, and a list
;; can even point back into itself. Memory is an Arena (lib/arena.wat): a node is an integer
;; id, -1 is the empty list, and every function takes the arena, because memory is explicit.
;;
;; Needs lib/arena.wat loaded first. No main here.

;; lots: m eggs, as fresh nodes
(wat.core/defn ss/lots [a :- :ss::ArenaRef m :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= m 0)
    -1
    (ss/kons! a 'egg (ss/lots a (wat.core/- m 1)))))

(wat.core/defn ss/lenkth [a :- :ss::ArenaRef l :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= l -1)
    0
    (wat.core/+ 1 (ss/lenkth a (ss/kdr a l)))))

(wat.core/defn ss/last-kons [a :- :ss::ArenaRef l :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= (ss/kdr a l) -1)
    l
    (ss/last-kons a (ss/kdr a l))))

;; add-at-end: a COPY of l with one more egg; l itself is untouched.
(wat.core/defn ss/add-at-end [a :- :ss::ArenaRef l :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= (ss/kdr a l) -1)
    (ss/kons! a (ss/kar a l) (ss/kons! a 'egg -1))
    (ss/kons! a (ss/kar a l) (ss/add-at-end a (ss/kdr a l)))))

;; add-at-end-too: changes l itself, pointing its last node at a new egg. Answers l.
(wat.core/defn ss/add-at-end-too [a :- :ss::ArenaRef l :- wat.type/i64] :- wat.type/i64
  (wat.core/let [_set (ss/set-kdr! a (ss/last-kons a l) (ss/kons! a 'egg -1))]
    l))

;; same?: are c1 and c2 the SAME node? The book finds out by mutation: point each at a
;; different sentinel, and see whether the second write also changed the first. Then put
;; both back. (-2 and -3 are never node ids.)
(wat.core/defn ss/same? [a :- :ss::ArenaRef c1 :- wat.type/i64 c2 :- wat.type/i64] :- wat.type/bool
  (wat.core/let [t1 (ss/kdr a c1)
                 t2 (ss/kdr a c2)
                 _a (ss/set-kdr! a c1 -2)
                 _b (ss/set-kdr! a c2 -3)
                 v  (wat.core/= (ss/kdr a c1) (ss/kdr a c2))
                 _c (ss/set-kdr! a c1 t1)
                 _d (ss/set-kdr! a c2 t2)]
    v))

;; ── finite-lenkth: the length, or -1 when the list runs in a circle ───────────────
;; Tortoise and hare: sl steps one node, qk two. If they ever meet, the list is circular,
;; and the search escapes at once with Err (the book's letcc). Checks for () come before
;; same?, because the arena has no node -1 to mutate.

(wat.core/defn ss/sl [a :- :ss::ArenaRef x :- wat.type/i64] :- wat.type/i64
  (ss/kdr a x))

(wat.core/defn ss/qk [a :- :ss::ArenaRef x :- wat.type/i64] :- wat.type/i64
  (ss/kdr a (ss/kdr a x)))

(wat.core/defn ss/C-len [a :- :ss::ArenaRef p :- wat.type/i64 q :- wat.type/i64]
  :- (wat.type/Result :- [wat.type/i64 wat.type/nil])
  (wat.core/cond
    ((wat.core/= q -1) (:wat::core::Result.Ok {:value 0}))
    ((ss/same? a p q) (:wat::core::Result.Err {:error nil}))
    ((wat.core/= (ss/kdr a q) -1) (:wat::core::Result.Ok {:value 1}))
    (:else
      (wat.core/let [n (:wat::core::Result/try (ss/C-len a (ss/sl a p) (ss/qk a q)))]
        (:wat::core::Result.Ok {:value (wat.core/+ n 2)})))))

;; The book answers #f for a circular list; here that is -1.
(wat.core/defn ss/finite-lenkth [a :- :ss::ArenaRef p :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/= p -1)
    0
    (:wat::core::match (ss/C-len a p (ss/kdr a p))
      [:wat::core::Result.Ok {:value n} (wat.core/+ n 1)]
      [:wat::core::Result.Err {:error _} -1])))
