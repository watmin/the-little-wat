;; okasaki/lib/queue.wat — Chapter 5's BatchedQueue: two lists, amortized O(1) per operation.
;;
;; front + reversed rear. `snoc` conses onto rear; `tail` pops front; when front empties, rear is
;; reversed into it. Each element is reversed exactly once, so the O(n) reverse amortizes to O(1).
;;
;; The invariant that makes the bound work: FRONT IS EMPTY ONLY IF THE WHOLE QUEUE IS. `check-f`
;; restores it after every operation, and ch05 asserts it rather than trusting it.
;;
;; THE CARRIER MATTERS, AND THAT IS F-098. This queue is a pair of lists, and the obvious way to
;; hold a pair in wat is a `defrecord`. Doing so makes every operation O(n): a record field holding
;; a USER ENUM VALUE is deep-copied on construction, so each snoc copies both lists. Holding the
;; same pair in an ENUM VARIANT shares them, and the amortized bound holds exactly -- measured at
;; 8877 ns/op flat, against a record version that reaches 163537 ns/op at n=4000 and keeps
;; climbing. Native containers are NOT affected: a PersistentVector field is O(1) either way.
;;
;; So the queue below is an enum variant. `:ok::QueueRec` is kept beside it, deliberately wrong,
;; because ch05 measures the two against each other and that comparison IS F-098's repro.

(:wat::load-file! "list.wat")

;; ─── the queue, carried in an enum variant (O(1) amortized) ───────────────────────────────────
(:wat::core::defenum :ok::Queue :wat::enum::Pure :Q [f <- :ok::List  r <- :ok::List])

(:wat::core::defn :ok::q-empty [] -> :ok::Queue.Q (:ok::Queue.Q {:f (:ok::nil) :r (:ok::nil)}))

(:wat::core::defn :ok::check-f [f <- :ok::List r <- :ok::List] -> :ok::Queue.Q
  (:wat::core::if (:ok::null? f)
    (:ok::Queue.Q {:f (:ok::rev r) :r (:ok::nil)})
    (:ok::Queue.Q {:f f :r r})))

(:wat::core::defn :ok::snoc [q <- :ok::Queue.Q x <- :wat::core::i64] -> :ok::Queue.Q
  (:wat::core::match q [:ok::Queue.Q {:f f :r r} (:ok::check-f f (:ok::cons x r))]))

(:wat::core::defn :ok::q-head [q <- :ok::Queue.Q] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match q
    [:ok::Queue.Q {:f f :r r}
      (:wat::core::match f
        [:ok::List.Nil {} :wat::core::Option.None]
        [:ok::List.Cons {:h h :t t} (:wat::core::Option.Some {:value h})])]))

(:wat::core::defn :ok::q-tail [q <- :ok::Queue.Q] -> :ok::Queue.Q
  (:wat::core::match q
    [:ok::Queue.Q {:f f :r r}
      (:wat::core::match f
        [:ok::List.Nil {} q]
        [:ok::List.Cons {:h h :t t} (:ok::check-f t r)])]))

(:wat::core::defn :ok::q-size [q <- :ok::Queue.Q] -> :wat::core::i64
  (:wat::core::match q [:ok::Queue.Q {:f f :r r} (:wat::core::+ (:ok::len f) (:ok::len r))]))

;; the invariant: front empty implies the queue is empty
(:wat::core::defn :ok::q-ok? [q <- :ok::Queue.Q] -> :wat::core::bool
  (:wat::core::match q
    [:ok::Queue.Q {:f f :r r} (:wat::core::if (:ok::null? f) (:ok::null? r) true)]))

;; ─── the SAME queue carried in a defrecord (O(n) per operation) — F-098's control ─────────────
(:wat::core::defrecord :ok::QueueRec [f <- :ok::List  r <- :ok::List])

(:wat::core::defn :ok::qr-empty [] -> :ok::QueueRec (:ok::QueueRec :f (:ok::nil) :r (:ok::nil)))

(:wat::core::defn :ok::qr-check-f [f <- :ok::List r <- :ok::List] -> :ok::QueueRec
  (:wat::core::if (:ok::null? f)
    (:ok::QueueRec :f (:ok::rev r) :r (:ok::nil))
    (:ok::QueueRec :f f :r r)))

(:wat::core::defn :ok::qr-snoc [q <- :ok::QueueRec x <- :wat::core::i64] -> :ok::QueueRec
  (:ok::qr-check-f (:ok::QueueRec/f q) (:ok::cons x (:ok::QueueRec/r q))))

(:wat::core::defn :ok::qr-tail [q <- :ok::QueueRec] -> :ok::QueueRec
  (:wat::core::match (:ok::QueueRec/f q)
    [:ok::List.Nil {} q]
    [:ok::List.Cons {:h h :t t} (:ok::qr-check-f t (:ok::QueueRec/r q))]))

(:wat::core::defn :ok::qr-size [q <- :ok::QueueRec] -> :wat::core::i64
  (:wat::core::+ (:ok::len (:ok::QueueRec/f q)) (:ok::len (:ok::QueueRec/r q))))
