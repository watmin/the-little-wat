;; okasaki/lib/deque.wat — Chapter 8's BankersDeque: LAZY REBUILDING, and both ends at once.
;;
;; Chapters 5-7 all have a cheap end and an expensive one: the rotation only ever moves rear into
;; front. A deque has no cheap end, so the technique generalises: keep the two halves within a
;; constant factor c of each other, and when one outgrows the other, REBALANCE by splitting it and
;; reversing the remainder onto the other side. Laziness makes that split incremental instead of a
;; stop-the-world rebuild -- which is what Okasaki means by "lazy rebuilding".
;;
;; The invariant, with c = 3:   lenf <= c*lenr + 1   and   lenr <= c*lenf + 1
;; It is checked after every operation in ch08, not assumed.
;;
;; Carrier: an Impure enum, for the fourth time -- it must hold suspensions (containment rule) and
;; must share its payload (F-098). SKELETON FOR P-027: every cell of both halves is an LRU.

(:wat::load-file! "llist.wat")

(:wat::core::defn :ok::dq-c [] -> :wat::core::i64 3)

(:wat::core::defenum :ok::DQ :wat::enum::Impure
  :D [lenf <- :wat::core::i64  f <- (:ok::Susp :- [:ok::LCell])
      lenr <- :wat::core::i64  r <- (:ok::Susp :- [:ok::LCell])])

(:wat::core::defn :ok::dq-empty [] -> :ok::DQ.D
  (:ok::DQ.D {:lenf 0 :f (:ok::lnil) :lenr 0 :r (:ok::lnil)}))

;; the rebalance: split the long side, reverse its remainder onto the short side
(:wat::core::defn :ok::dq-check
  [lenf <- :wat::core::i64 f <- (:ok::Susp :- [:ok::LCell])
   lenr <- :wat::core::i64 r <- (:ok::Susp :- [:ok::LCell])] -> :ok::DQ.D
  (:wat::core::let [c (:ok::dq-c) total (:wat::core::+ lenf lenr)]
    (:wat::core::if (:wat::core::> lenf (:wat::core::+ (:wat::core::* c lenr) 1))
      (:wat::core::let [i (:wat::core::/ total 2)
                        j (:wat::core::- total i)]
        (:ok::DQ.D {:lenf i :f (:ok::ltake f i)
                    :lenr j :r (:ok::lappend r (:ok::lrev (:ok::ldrop f i)))}))
      (:wat::core::if (:wat::core::> lenr (:wat::core::+ (:wat::core::* c lenf) 1))
        (:wat::core::let [j (:wat::core::/ total 2)
                          i (:wat::core::- total j)]
          (:ok::DQ.D {:lenf i :f (:ok::lappend f (:ok::lrev (:ok::ldrop r j)))
                      :lenr j :r (:ok::ltake r j)}))
        (:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r})))))

(:wat::core::defn :ok::dq-cons [q <- :ok::DQ.D x <- :wat::core::i64] -> :ok::DQ.D
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:ok::dq-check (:wat::core::+ lenf 1) (:ok::lcons x f) lenr r)]))

(:wat::core::defn :ok::dq-snoc [q <- :ok::DQ.D x <- :wat::core::i64] -> :ok::DQ.D
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:ok::dq-check lenf f (:wat::core::+ lenr 1) (:ok::lcons x r))]))

;; head/last must cover the one-element case, where that element may be on either side
(:wat::core::defn :ok::dq-head [q <- :ok::DQ.D] -> :wat::core::i64
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:wat::core::if (:wat::core::= lenf 0) (:ok::lhead r) (:ok::lhead f))]))

(:wat::core::defn :ok::dq-last [q <- :ok::DQ.D] -> :wat::core::i64
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:wat::core::if (:wat::core::= lenr 0) (:ok::lhead f) (:ok::lhead r))]))

(:wat::core::defn :ok::dq-tail [q <- :ok::DQ.D] -> :ok::DQ.D
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:wat::core::if (:wat::core::= lenf 0)
        (:ok::dq-empty)
        (:ok::dq-check (:wat::core::- lenf 1) (:ok::ltail f) lenr r))]))

(:wat::core::defn :ok::dq-init [q <- :ok::DQ.D] -> :ok::DQ.D
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:wat::core::if (:wat::core::= lenr 0)
        (:ok::dq-empty)
        (:ok::dq-check lenf f (:wat::core::- lenr 1) (:ok::ltail r)))]))

(:wat::core::defn :ok::dq-size [q <- :ok::DQ.D] -> :wat::core::i64
  (:wat::core::match q [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r} (:wat::core::+ lenf lenr)]))

;; the balance invariant, checked rather than trusted
(:wat::core::defn :ok::dq-balanced? [q <- :ok::DQ.D] -> :wat::core::bool
  (:wat::core::match q
    [:ok::DQ.D {:lenf lenf :f f :lenr lenr :r r}
      (:wat::core::let [c (:ok::dq-c)]
        (:wat::core::if (:wat::core::> lenf (:wat::core::+ (:wat::core::* c lenr) 1)) false
          (:wat::core::not (:wat::core::> lenr (:wat::core::+ (:wat::core::* c lenf) 1)))))]))
