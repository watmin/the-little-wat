;; okasaki/lib/heap.wat — Chapter 3's LeftistHeap. This is F-056's missing priority queue.
;;
;; F-056 records that wat has no priority queue, and no ordered collection of any kind. Okasaki's
;; leftist heap is the smallest thing that fills it: merge is O(log n), and insert and delete-min
;; are both defined in terms of merge.
;;
;; The leftist property: the rank (length of the right spine) of the left child is always >= that
;; of the right child, which is what bounds the right spine at O(log n) and therefore merge with
;; it. ch03 checks that property holds after every operation rather than trusting it.

(:wat::core::defenum :ok::Heap :wat::enum::Pure
  :E []
  :T [rank <- :wat::core::i64  x <- :wat::core::i64  a <- :ok::Heap  b <- :ok::Heap])

(:wat::core::defn :ok::h-empty [] -> :ok::Heap (:ok::Heap.E {}))

(:wat::core::defn :ok::rank [h <- :ok::Heap] -> :wat::core::i64
  (:wat::core::match h
    [:ok::Heap.E {} 0]
    [:ok::Heap.T {:rank r :x x :a a :b b} r]))

;; the smaller-ranked child goes RIGHT; that is the whole invariant
(:wat::core::defn :ok::make-t [x <- :wat::core::i64 a <- :ok::Heap b <- :ok::Heap] -> :ok::Heap
  (:wat::core::if (:wat::core::>= (:ok::rank a) (:ok::rank b))
    (:ok::Heap.T {:rank (:wat::core::+ (:ok::rank b) 1) :x x :a a :b b})
    (:ok::Heap.T {:rank (:wat::core::+ (:ok::rank a) 1) :x x :a b :b a})))

(:wat::core::defn :ok::merge [h1 <- :ok::Heap h2 <- :ok::Heap] -> :ok::Heap
  (:wat::core::match h1
    [:ok::Heap.E {} h2]
    [:ok::Heap.T {:rank r1 :x x :a a1 :b b1}
      (:wat::core::match h2
        [:ok::Heap.E {} h1]
        [:ok::Heap.T {:rank r2 :x y :a a2 :b b2}
          (:wat::core::if (:wat::core::<= x y)
            (:ok::make-t x a1 (:ok::merge b1 h2))
            (:ok::make-t y a2 (:ok::merge h1 b2)))])]))

(:wat::core::defn :ok::h-insert [h <- :ok::Heap x <- :wat::core::i64] -> :ok::Heap
  (:ok::merge (:ok::Heap.T {:rank 1 :x x :a (:ok::h-empty) :b (:ok::h-empty)}) h))

(:wat::core::defn :ok::find-min [h <- :ok::Heap] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match h
    [:ok::Heap.E {} :wat::core::Option.None]
    [:ok::Heap.T {:rank r :x x :a a :b b} (:wat::core::Option.Some {:value x})]))

(:wat::core::defn :ok::delete-min [h <- :ok::Heap] -> :ok::Heap
  (:wat::core::match h
    [:ok::Heap.E {} h]
    [:ok::Heap.T {:rank r :x x :a a :b b} (:ok::merge a b)]))

(:wat::core::defn :ok::h-size [h <- :ok::Heap] -> :wat::core::i64
  (:wat::core::match h
    [:ok::Heap.E {} 0]
    [:ok::Heap.T {:rank r :x x :a a :b b}
      (:wat::core::+ 1 (:wat::core::+ (:ok::h-size a) (:ok::h-size b)))]))

;; --- the invariants, checked rather than trusted -----------------------------------------------
;; leftist: rank(left) >= rank(right) at every node, and the stored rank is right-spine + 1.
(:wat::core::defn :ok::leftist? [h <- :ok::Heap] -> :wat::core::bool
  (:wat::core::match h
    [:ok::Heap.E {} true]
    [:ok::Heap.T {:rank r :x x :a a :b b}
      (:wat::core::if (:wat::core::< (:ok::rank a) (:ok::rank b)) false
        (:wat::core::if (:wat::core::not (:wat::core::= r (:wat::core::+ (:ok::rank b) 1))) false
          (:wat::core::if (:ok::leftist? a) (:ok::leftist? b) false)))]))

;; heap order: every node <= both children
(:wat::core::defn :ok::ordered? [h <- :ok::Heap] -> :wat::core::bool
  (:wat::core::match h
    [:ok::Heap.E {} true]
    [:ok::Heap.T {:rank r :x x :a a :b b}
      (:wat::core::if (:ok::gte? a x)
        (:wat::core::if (:ok::gte? b x)
          (:wat::core::if (:ok::ordered? a) (:ok::ordered? b) false) false) false)]))

(:wat::core::defn :ok::gte? [h <- :ok::Heap x <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::match h
    [:ok::Heap.E {} true]
    [:ok::Heap.T {:rank r :x y :a a :b b} (:wat::core::>= y x)]))
