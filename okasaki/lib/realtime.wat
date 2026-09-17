;; okasaki/lib/realtime.wat — Chapter 7's RealTimeQueue: WORST-CASE O(1), not amortized.
;;
;; Chapter 6 pays the rotation once, but it pays it ALL AT ONCE on whichever operation happens to
;; force it. Chapter 7 removes that spike: a third field, the SCHEDULE, is forced one cell per
;; operation, so the rotation is spread across the operations that caused it and no single call
;; is slow. The invariant is |schedule| = |front| - |rear|.
;;
;; SKELETON FOR P-027 (see lib/llist.wat): the lazy lists here are one LRU per cons cell. That is
;; the wrong cost model and the reason ch7's absolute numbers are not worth quoting -- the SHAPE
;; (a bounded worst case vs a spike) is what this measures.
;;
;; Carrier: an Impure enum, for the third time -- it must hold suspensions (so not a Pure enum,
;; containment rule) and must share its payload (so not a record, F-098).

(:wat::load-file! "llist.wat")
(:wat::load-file! "list.wat")

(:wat::core::typealias :ok::LL (:ok::Susp :- [:ok::LCell]))

(:wat::core::defenum :ok::RTQ :wat::enum::Impure
  :Q [f <- :ok::LL  r <- :ok::List  s <- :ok::LL])

(:wat::core::defn :ok::rtq-empty [] -> :ok::RTQ.Q
  (:ok::RTQ.Q {:f (:ok::lnil) :r (:ok::nil) :s (:ok::lnil)}))

;; rotate (f, y::ys, s) — one cell at a time, each tail suspended
(:wat::core::defn :ok::rotate [f <- :ok::LL r <- :ok::List s <- :ok::LL] -> :ok::LL
  (:wat::core::let [y (:ok::head-or r -1)
                    ys (:ok::rest r)]
    (:wat::core::match (:ok::force f)
      [:ok::LCell.CNil {} (:ok::lcons y s)]
      [:ok::LCell.CCons {:h x :t f2}
        (:ok::lcons x
          (:ok::delay (:wat::core::fn [] -> :ok::LCell
            (:ok::force (:ok::rotate f2 ys (:ok::lcons y s))))))])))

;; exec — force exactly ONE schedule cell per operation; when the schedule empties, rotate
(:wat::core::defn :ok::exec [f <- :ok::LL r <- :ok::List s <- :ok::LL] -> :ok::RTQ.Q
  (:wat::core::match (:ok::force s)
    [:ok::LCell.CCons {:h x :t s2} (:ok::RTQ.Q {:f f :r r :s s2})]
    [:ok::LCell.CNil {}
      (:wat::core::let [f2 (:ok::rotate f r (:ok::lnil))]
        (:ok::RTQ.Q {:f f2 :r (:ok::nil) :s f2}))]))

(:wat::core::defn :ok::rtq-snoc [q <- :ok::RTQ.Q x <- :wat::core::i64] -> :ok::RTQ.Q
  (:wat::core::match q
    [:ok::RTQ.Q {:f f :r r :s s} (:ok::exec f (:ok::cons x r) s)]))

(:wat::core::defn :ok::rtq-head [q <- :ok::RTQ.Q] -> :wat::core::i64
  (:wat::core::match q [:ok::RTQ.Q {:f f :r r :s s} (:ok::lhead f)]))

(:wat::core::defn :ok::rtq-tail [q <- :ok::RTQ.Q] -> :ok::RTQ.Q
  (:wat::core::match q
    [:ok::RTQ.Q {:f f :r r :s s} (:ok::exec (:ok::ltail f) r s)]))

(:wat::core::defn :ok::rtq-empty? [q <- :ok::RTQ.Q] -> :wat::core::bool
  (:wat::core::match q [:ok::RTQ.Q {:f f :r r :s s} (:ok::lnull? f)]))
