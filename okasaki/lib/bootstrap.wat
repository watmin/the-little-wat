;; okasaki/lib/bootstrap.wat — Chapter 10's BootstrappedQueue: structural decomposition.
;;
;; The queue's middle is itself A QUEUE OF LISTS, so the datatype is
;;     Queue<A> = E | Q of int * List<A> * Queue<List<A>> * int * List<A>
;; and the recursive occurrence is at a DIFFERENT type instance. That is POLYMORPHIC RECURSION,
;; which many type systems refuse outright and most of the rest need explicit annotation for.
;;
;; wat takes it (C-059). Every type here is a Pure enum -- no laziness in this chapter, so no
;; P-027 stand-in and no Impure carriers.

(:wat::core::defenum :ok::GList :- [A] :wat::enum::Pure
  :GNil []
  :GCons [h <- :A  t <- (:ok::GList :- [A])])

(:wat::core::defn :ok::gnil :- [A] [] -> (:ok::GList :- [A]) (:ok::GList.GNil :- [A] {}))

(:wat::core::defn :ok::gcons :- [A] [x <- :A t <- (:ok::GList :- [A])] -> (:ok::GList :- [A])
  (:ok::GList.GCons :- [A] {:h x :t t}))

(:wat::core::defn :ok::gnull? :- [A] [l <- (:ok::GList :- [A])] -> :wat::core::bool
  (:wat::core::match l [:ok::GList.GNil {} true] [:ok::GList.GCons {:h h :t t} false]))

(:wat::core::defn :ok::grev-onto :- [A] [l <- (:ok::GList :- [A]) acc <- (:ok::GList :- [A])]
  -> (:ok::GList :- [A])
  (:wat::core::match l
    [:ok::GList.GNil {} acc]
    [:ok::GList.GCons {:h h :t t} (:ok::grev-onto t (:ok::gcons h acc))]))

(:wat::core::defn :ok::grev :- [A] [l <- (:ok::GList :- [A])] -> (:ok::GList :- [A])
  (:ok::grev-onto l (:ok::gnil)))

;; ─── the bootstrapped queue ───────────────────────────────────────────────────────────────────
;; THE POLYMORPHIC RECURSION IS HERE: `m` is a queue of LISTS of A, not a queue of A.
(:wat::core::defenum :ok::BSQ :- [A] :wat::enum::Pure
  :E []
  :Q [lenfm <- :wat::core::i64
      f     <- (:ok::GList :- [A])
      m     <- (:ok::BSQ :- [(:ok::GList :- [A])])
      lenr  <- :wat::core::i64
      r     <- (:ok::GList :- [A])])

(:wat::core::defn :ok::bsq-empty :- [A] [] -> (:ok::BSQ :- [A]) (:ok::BSQ.E :- [A] {}))

(:wat::core::defn :ok::bsq-null? :- [A] [q <- (:ok::BSQ :- [A])] -> :wat::core::bool
  (:wat::core::match q
    [:ok::BSQ.E {} true]
    [:ok::BSQ.Q {:lenfm lenfm :f f :m m :lenr lenr :r r} false]))

(:wat::core::defn :ok::bsq-head :- [A] [q <- (:ok::BSQ :- [A]) d <- :A] -> :A
  (:wat::core::match q
    [:ok::BSQ.E {} d]
    [:ok::BSQ.Q {:lenfm lenfm :f f :m m :lenr lenr :r r}
      (:wat::core::match f [:ok::GList.GNil {} d] [:ok::GList.GCons {:h h :t t} h])]))

;; checkF — when the front empties, refill it from the middle queue's head list
(:wat::core::defn :ok::bsq-checkf :- [A]
  [lenfm <- :wat::core::i64 f <- (:ok::GList :- [A])
   m <- (:ok::BSQ :- [(:ok::GList :- [A])]) lenr <- :wat::core::i64 r <- (:ok::GList :- [A])]
  -> (:ok::BSQ :- [A])
  (:wat::core::if (:ok::gnull? f)
    (:wat::core::if (:ok::bsq-null? m)
      (:ok::BSQ.E :- [A] {})
      (:ok::BSQ.Q :- [A] {:lenfm lenfm
                          :f (:ok::bsq-head m (:ok::gnil))
                          :m (:ok::bsq-tail m)
                          :lenr lenr :r r}))
    (:ok::BSQ.Q :- [A] {:lenfm lenfm :f f :m m :lenr lenr :r r})))

;; checkQ — when the rear outgrows front+middle, push the reversed rear into the middle queue
(:wat::core::defn :ok::bsq-checkq :- [A]
  [lenfm <- :wat::core::i64 f <- (:ok::GList :- [A])
   m <- (:ok::BSQ :- [(:ok::GList :- [A])]) lenr <- :wat::core::i64 r <- (:ok::GList :- [A])]
  -> (:ok::BSQ :- [A])
  (:wat::core::if (:wat::core::<= lenr lenfm)
    (:ok::bsq-checkf lenfm f m lenr r)
    (:ok::bsq-checkf (:wat::core::+ lenfm lenr) f
      (:ok::bsq-snoc m (:ok::grev r)) 0 (:ok::gnil))))

(:wat::core::defn :ok::bsq-snoc :- [A] [q <- (:ok::BSQ :- [A]) x <- :A] -> (:ok::BSQ :- [A])
  (:wat::core::match q
    [:ok::BSQ.E {}
      (:ok::BSQ.Q :- [A] {:lenfm 1 :f (:ok::gcons x (:ok::gnil))
                          :m (:ok::bsq-empty) :lenr 0 :r (:ok::gnil)})]
    [:ok::BSQ.Q {:lenfm lenfm :f f :m m :lenr lenr :r r}
      (:ok::bsq-checkq lenfm f m (:wat::core::+ lenr 1) (:ok::gcons x r))]))

(:wat::core::defn :ok::bsq-tail :- [A] [q <- (:ok::BSQ :- [A])] -> (:ok::BSQ :- [A])
  (:wat::core::match q
    [:ok::BSQ.E {} q]
    [:ok::BSQ.Q {:lenfm lenfm :f f :m m :lenr lenr :r r}
      (:wat::core::match f
        [:ok::GList.GNil {} (:ok::BSQ.E :- [A] {})]
        [:ok::GList.GCons {:h h :t t}
          (:ok::bsq-checkq (:wat::core::- lenfm 1) t m lenr r)])]))
