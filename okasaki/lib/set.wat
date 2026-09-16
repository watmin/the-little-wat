;; okasaki/lib/set.wat — Chapter 2's UnbalancedSet: a persistent set as a binary search tree.
;;
;; wat ships PersistentVector and PersistentMap, which share structure, and NO persistent set
;; (F-057). The documented workaround is a PersistentMap to `true`, which is what aoc/day05-paths
;; had to do for its visited set. This is the structure that is missing, in 40 lines.
;;
;; Okasaki's insert is the one worth writing carefully: on a hit it returns the ORIGINAL tree
;; rather than rebuilding a spine of identical nodes, which is where the sharing comes from.

(:wat::core::defenum :ok::Set :wat::enum::Pure
  :Leaf []
  :Node [l <- :ok::Set  v <- :wat::core::i64  r <- :ok::Set])

(:wat::core::defn :ok::empty [] -> :ok::Set (:ok::Set.Leaf {}))

(:wat::core::defn :ok::member? [s <- :ok::Set x <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::match s
    [:ok::Set.Leaf {} false]
    [:ok::Set.Node {:l l :v v :r r}
      (:wat::core::if (:wat::core::< x v) (:ok::member? l x)
        (:wat::core::if (:wat::core::< v x) (:ok::member? r x) true))]))

(:wat::core::defn :ok::insert [s <- :ok::Set x <- :wat::core::i64] -> :ok::Set
  (:wat::core::match s
    [:ok::Set.Leaf {} (:ok::Set.Node {:l (:ok::Set.Leaf {}) :v x :r (:ok::Set.Leaf {})})]
    [:ok::Set.Node {:l l :v v :r r}
      (:wat::core::if (:wat::core::< x v)
        (:ok::Set.Node {:l (:ok::insert l x) :v v :r r})
        (:wat::core::if (:wat::core::< v x)
          (:ok::Set.Node {:l l :v v :r (:ok::insert r x)})
          ;; already present: return the ORIGINAL node, sharing everything
          s))]))

(:wat::core::defn :ok::size [s <- :ok::Set] -> :wat::core::i64
  (:wat::core::match s
    [:ok::Set.Leaf {} 0]
    [:ok::Set.Node {:l l :v v :r r} (:wat::core::+ 1 (:wat::core::+ (:ok::size l) (:ok::size r)))]))

(:wat::core::defn :ok::depth [s <- :ok::Set] -> :wat::core::i64
  (:wat::core::match s
    [:ok::Set.Leaf {} 0]
    [:ok::Set.Node {:l l :v v :r r}
      (:wat::core::let [a (:ok::depth l) b (:ok::depth r)]
        (:wat::core::+ 1 (:wat::core::if (:wat::core::> a b) a b)))]))

;; in-order walk, so the set can be compared against a model
(:wat::core::defn :ok::into [s <- :ok::Set acc <- (:wat::core::PersistentVector :- [:wat::core::i64])]
  -> (:wat::core::PersistentVector :- [:wat::core::i64])
  (:wat::core::match s
    [:ok::Set.Leaf {} acc]
    [:ok::Set.Node {:l l :v v :r r} (:ok::into r (:wat::vector::conj (:ok::into l acc) v))]))

(:wat::core::defn :ok::to-vector [s <- :ok::Set] -> (:wat::core::PersistentVector :- [:wat::core::i64])
  (:ok::into s (:wat::core::PersistentVector :- [:wat::core::i64])))
