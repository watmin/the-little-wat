;; excursus 008 M2: the region release / free-list collision the M1 crawl named before M2 was
;; drawn, and the retired STOP-2 for this strike. `user/build70x8` builds a 560-byte String
;; (well past `:c::small-max`, into the LARGE table) that is NOT the youngest allocation by the
;; time it is consumed -- it is the first argument of the outer `concat`, and `i64/to-string`'s
;; own small allocation happens in between. Called twice, inside `user/main`'s own first (non
;; -final) statement:
;;
;;   - with the region release in place (pre-M2-4): the first statement's own `pop r15` rewinds
;;     the bump pointer back below the 560-byte block the OUTER concat's source drop had just
;;     pushed onto its free-list class -- one block, two owners -- and the second statement's
;;     allocations (inside the SAME `user/main`, the second `println`) corrupt it before it is
;;     read. Native printed `"561"` then `"2"`; the interpreter printed `"561"` both times.
;;   - `WAT_DROP_CHECK=1` on the SAME (pre-M2-4) native build agreed with the interpreter both
;;     times -- the STOP-2 signature ("the plain build diverges where the check build agrees: a
;;     live block reused") that pointed at a reclaim-ordering collision, not a counting defect.
;;
;; M2-4 (retiring the region release) is the fix: the count is the only reclamation discipline,
;; so there is no rewind left to collide with the free list it just populated.
(wat.core/defn user/build70x8 [] :- wat.type/String
  (wat.core/let [base "0123456789012345678901234567890123456789012345678901234567890123456789"]
    (wat.string/concat base base base base base base base base)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.i64/to-string (wat.string/length
      (wat.string/concat (user/build70x8) (wat.i64/to-string 5)))))
    (wat.kernel/println (wat.i64/to-string (wat.string/length
      (wat.string/concat (user/build70x8) (wat.i64/to-string 5)))))))
