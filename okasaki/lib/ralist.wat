;; okasaki/lib/ralist.wat — Chapter 9's BinaryRandomAccessList: the structure IS a binary number.
;;
;; A different technique from everything before it, and notably one that needs NO laziness: the
;; list is a sequence of digits, each Zero or One-carrying-a-complete-binary-tree of size 2^i, and
;; `cons` is exactly binary increment with carry. Nothing here touches lib/susp.wat, so chapter 9
;; is free of the P-027 stand-in and its numbers mean what they say.
;;
;; The payoff is indexing: `lookup i` walks the digits to find the right tree (O(log n)) and then
;; descends it (O(log n)), where a cons list would be O(n). ch09 measures that curve.
;;
;; Every type here is a PURE enum -- no suspensions, so no live handles, so none of the Impure
;; carrier awkwardness that chapters 6-8 needed.

(:wat::core::defenum :ok::RT :wat::enum::Pure
  :L [v <- :wat::core::i64]
  :N [w <- :wat::core::i64  l <- :ok::RT  r <- :ok::RT])

(:wat::core::defenum :ok::Digit :wat::enum::Pure
  :Zero []
  :One [t <- :ok::RT])

(:wat::core::defenum :ok::RList :wat::enum::Pure
  :DNil []
  :DCons [d <- :ok::Digit  rest <- :ok::RList])

;; the pair unconsTree returns — a Pure enum rather than a record, per F-098
(:wat::core::defenum :ok::TPair :wat::enum::Pure
  :P [t <- :ok::RT  rest <- :ok::RList])

(:wat::core::defn :ok::ra-empty [] -> :ok::RList (:ok::RList.DNil {}))

(:wat::core::defn :ok::rt-size [t <- :ok::RT] -> :wat::core::i64
  (:wat::core::match t
    [:ok::RT.L {:v v} 1]
    [:ok::RT.N {:w w :l l :r r} w]))

(:wat::core::defn :ok::rt-link [a <- :ok::RT b <- :ok::RT] -> :ok::RT
  (:ok::RT.N {:w (:wat::core::+ (:ok::rt-size a) (:ok::rt-size b)) :l a :r b}))

;; consTree — binary increment: a One digit carries, a Zero absorbs
(:wat::core::defn :ok::cons-tree [t <- :ok::RT ts <- :ok::RList] -> :ok::RList
  (:wat::core::match ts
    [:ok::RList.DNil {} (:ok::RList.DCons {:d (:ok::Digit.One {:t t}) :rest (:ok::RList.DNil {})})]
    [:ok::RList.DCons {:d d :rest rest}
      (:wat::core::match d
        [:ok::Digit.Zero {} (:ok::RList.DCons {:d (:ok::Digit.One {:t t}) :rest rest})]
        [:ok::Digit.One {:t t2}
          (:ok::RList.DCons {:d (:ok::Digit.Zero {}) :rest (:ok::cons-tree (:ok::rt-link t t2) rest)})])]))

;; unconsTree — binary decrement: borrow down the digits, then split the tree
(:wat::core::defn :ok::uncons-tree [ts <- :ok::RList] -> :ok::TPair
  (:wat::core::match ts
    [:ok::RList.DNil {} (:ok::TPair.P {:t (:ok::RT.L {:v -1}) :rest (:ok::RList.DNil {})})]
    [:ok::RList.DCons {:d d :rest rest}
      (:wat::core::match d
        [:ok::Digit.One {:t t}
          (:wat::core::match rest
            [:ok::RList.DNil {} (:ok::TPair.P {:t t :rest (:ok::RList.DNil {})})]
            [:ok::RList.DCons {:d d2 :rest r2}
              (:ok::TPair.P {:t t :rest (:ok::RList.DCons {:d (:ok::Digit.Zero {}) :rest rest})})])]
        [:ok::Digit.Zero {}
          (:wat::core::match (:ok::uncons-tree rest)
            [:ok::TPair.P {:t bt :rest ts2}
              (:wat::core::match bt
                [:ok::RT.N {:w w :l l :r r}
                  (:ok::TPair.P {:t l :rest (:ok::RList.DCons {:d (:ok::Digit.One {:t r}) :rest ts2})})]
                [:ok::RT.L {:v v} (:ok::TPair.P {:t bt :rest ts2})])])])]))

(:wat::core::defn :ok::ra-cons [ts <- :ok::RList x <- :wat::core::i64] -> :ok::RList
  (:ok::cons-tree (:ok::RT.L {:v x}) ts))

(:wat::core::defn :ok::ra-head [ts <- :ok::RList] -> :wat::core::i64
  (:wat::core::match (:ok::uncons-tree ts)
    [:ok::TPair.P {:t t :rest rest}
      (:wat::core::match t [:ok::RT.L {:v v} v] [:ok::RT.N {:w w :l l :r r} -1])]))

(:wat::core::defn :ok::ra-tail [ts <- :ok::RList] -> :ok::RList
  (:wat::core::match (:ok::uncons-tree ts) [:ok::TPair.P {:t t :rest rest} rest]))

;; lookup — the point of the structure: O(log n) instead of O(n)
(:wat::core::defn :ok::lookup-tree [i <- :wat::core::i64 t <- :ok::RT] -> :wat::core::i64
  (:wat::core::match t
    [:ok::RT.L {:v v} v]
    [:ok::RT.N {:w w :l l :r r}
      (:wat::core::let [half (:wat::core::/ w 2)]
        (:wat::core::if (:wat::core::< i half)
          (:ok::lookup-tree i l)
          (:ok::lookup-tree (:wat::core::- i half) r)))]))

(:wat::core::defn :ok::ra-lookup [ts <- :ok::RList i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match ts
    [:ok::RList.DNil {} -1]
    [:ok::RList.DCons {:d d :rest rest}
      (:wat::core::match d
        [:ok::Digit.Zero {} (:ok::ra-lookup rest i)]
        [:ok::Digit.One {:t t}
          (:wat::core::if (:wat::core::< i (:ok::rt-size t))
            (:ok::lookup-tree i t)
            (:ok::ra-lookup rest (:wat::core::- i (:ok::rt-size t))))])]))

(:wat::core::defn :ok::ra-size [ts <- :ok::RList] -> :wat::core::i64
  (:wat::core::match ts
    [:ok::RList.DNil {} 0]
    [:ok::RList.DCons {:d d :rest rest}
      (:wat::core::+ (:wat::core::match d
                       [:ok::Digit.Zero {} 0]
                       [:ok::Digit.One {:t t} (:ok::rt-size t)])
                     (:ok::ra-size rest))]))
