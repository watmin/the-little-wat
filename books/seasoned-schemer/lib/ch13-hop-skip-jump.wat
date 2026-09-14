;; The Seasoned Schemer, ch 13 (Hop, Skip, and Jump): the definitions. letcc names "the
;; rest of the computation" so a function can jump out of it: hop out with an answer, or
;; skip everything done so far and start again. In wat, Result/try gives the same escape
;; (FINDINGS.md, C-006). An Err returns from its function at once, and every pending
;; Result/try frame passes it straight up, skipping its own work.
;;
;; Needs ../little-schemer/lib/ch01-toys.wat and the Little Schemer ch02, ch03 and ch07
;; libs (ls/intersect) loaded first. No main here.
;; Result is built with the keyword constructors: wat.type/Result as a constructor fails
;; at runtime (F-009). match is keyword-spelled too, because wat.core/match misreads its
;; arms as vector literals (F-017).

;; ── intersectall: hop out with () as soon as any set is empty ─────────────────────

;; Ok carries a partial intersection. Err carries the final answer, (), found early.
(wat.core/defn ss/intersectall-r [lset :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/cond
    ((ls/null? (ls/car lset)) (:wat::core::Result.Err {:error '()}))
    ((ls/null? (ls/cdr lset)) (:wat::core::Result.Ok {:value (ls/car lset)}))
    (:else
      (wat.core/let [rest (:wat::core::Result/try (ss/intersectall-r (ls/cdr lset)))]
        (:wat::core::Result.Ok {:value (ls/intersect (ls/car lset) rest)})))))

;; the letcc point: either answer is the answer
(wat.core/defn ss/intersectall [lset :- :wat::WatAST] :- :wat::WatAST
  (wat.core/if (ls/null? lset)
    '()
    (:wat::core::match (ss/intersectall-r lset)
      [:wat::core::Result.Ok {:value v} v]
      [:wat::core::Result.Err {:error e} e])))

;; ── rember-beyond-first: keep only what comes before the first a ──────────────────

(wat.core/defn ss/rember-beyond-first [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
  (wat.core/cond
    ((ls/null? lat) '())
    ((ls/eq? (ls/car lat) a) '())
    (:else (ls/cons (ls/car lat) (ss/rember-beyond-first a (ls/cdr lat))))))

;; ── rember-upto-last: keep only what comes after the last a ───────────────────────
;; The book's skip continuation throws away every cons pending so far and restarts from
;; the atom after the a. Here, finding an a returns Err carrying the answer for the rest
;; of the list. Every pending (cons …) frame above it is waiting in a Result/try, so the
;; Err passes through them all, and their conses never happen.

(wat.core/defn ss/rember-upto-last-r [a :- :wat::WatAST lat :- :wat::WatAST]
  :- (wat.type/Result :- [:wat::WatAST :wat::WatAST])
  (wat.core/cond
    ((ls/null? lat) (:wat::core::Result.Ok {:value '()}))
    ((ls/eq? (ls/car lat) a)
     (:wat::core::Result.Err {:error (ss/rember-upto-last a (ls/cdr lat))}))
    (:else
      (wat.core/let [more (:wat::core::Result/try (ss/rember-upto-last-r a (ls/cdr lat)))]
        (:wat::core::Result.Ok {:value (ls/cons (ls/car lat) more)})))))

(wat.core/defn ss/rember-upto-last [a :- :wat::WatAST lat :- :wat::WatAST] :- :wat::WatAST
  (:wat::core::match (ss/rember-upto-last-r a lat)
    [:wat::core::Result.Ok {:value v} v]
    [:wat::core::Result.Err {:error e} e]))
