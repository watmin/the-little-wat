;; okasaki/lib/bankers.wat — Chapter 6's BankersQueue: the amortized bound that survives PERSISTENCE.
;;
;; Chapter 5's BatchedQueue is amortized O(1) only while each version is used ONCE. Reuse a single
;; version k times and it pays the O(n) rotation k times over -- measured at 7x/23x/46x/86x for
;; k = 10/25/50/100 (F-100). The banker's queue fixes that by suspending the rotation, so it is
;; forced at most once no matter how many futures branch off that value.
;;
;; THE CARRIER THREADS A NEEDLE, and both constraints are findings in this ledger:
;;   F-098            a defrecord/defstruct field holding a USER ENUM is deep-copied, so holding
;;                    the rear list in a record would make every snoc O(n).
;;   containment rule a PURE enum cannot hold a live handle, and the suspension is one.
;; So the carrier is an IMPURE enum -- the only shape that both shares its payload and may hold a
;; suspension. Neither constraint is documented; both were measured here.
;;
;; The suspension is okasaki/lib/susp.wat, which is a stand-in built on an LRU (P-027).

(:wat::load-file! "list.wat")
(:wat::load-file! "susp.wat")

(:wat::core::typealias :ok::LSusp (:ok::Susp :- [:ok::List]))

(:wat::core::defenum :ok::BQ :wat::enum::Impure
  :Q [lenf <- :wat::core::i64  f <- :ok::LSusp  lenr <- :wat::core::i64  r <- :ok::List])

(:wat::core::defn :ok::bq-empty [] -> :ok::BQ.Q
  (:ok::BQ.Q {:lenf 0 :f (:ok::delay (:wat::core::fn [] -> :ok::List (:ok::nil))) :lenr 0 :r (:ok::nil)}))

;; the invariant: lenr <= lenf. When it breaks, suspend front ++ reverse rear.
(:wat::core::defn :ok::bq-check
  [lenf <- :wat::core::i64 f <- :ok::LSusp lenr <- :wat::core::i64 r <- :ok::List] -> :ok::BQ.Q
  (:wat::core::if (:wat::core::<= lenr lenf)
    (:ok::BQ.Q {:lenf lenf :f f :lenr lenr :r r})
    (:ok::BQ.Q {:lenf (:wat::core::+ lenf lenr)
                :f (:ok::delay (:wat::core::fn [] -> :ok::List (:ok::append (:ok::force f) (:ok::rev r))))
                :lenr 0 :r (:ok::nil)})))

(:wat::core::defn :ok::bq-snoc [q <- :ok::BQ.Q x <- :wat::core::i64] -> :ok::BQ.Q
  (:wat::core::match q
    [:ok::BQ.Q {:lenf lenf :f f :lenr lenr :r r}
      (:ok::bq-check lenf f (:wat::core::+ lenr 1) (:ok::cons x r))]))

(:wat::core::defn :ok::bq-head [q <- :ok::BQ.Q] -> :wat::core::i64
  (:wat::core::match q
    [:ok::BQ.Q {:lenf lenf :f f :lenr lenr :r r} (:ok::head-or (:ok::force f) -1)]))

(:wat::core::defn :ok::bq-tail [q <- :ok::BQ.Q] -> :ok::BQ.Q
  (:wat::core::match q
    [:ok::BQ.Q {:lenf lenf :f f :lenr lenr :r r}
      (:ok::bq-check (:wat::core::- lenf 1)
        (:ok::delay (:wat::core::fn [] -> :ok::List (:ok::rest (:ok::force f))))
        lenr r)]))

(:wat::core::defn :ok::bq-size [q <- :ok::BQ.Q] -> :wat::core::i64
  (:wat::core::match q
    [:ok::BQ.Q {:lenf lenf :f f :lenr lenr :r r} (:wat::core::+ lenf lenr)]))
