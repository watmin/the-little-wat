;; okasaki/ch06-bankers-queue.wat — does a memoized suspension actually buy back persistence?
;;
;; Chapter 5's BatchedQueue is amortized O(1) only while each version is used ONCE. Reuse one
;; version k times and it pays the O(n) rotation k times: measured at 7x/23x/46x/86x for
;; k = 10/25/50/100 (F-100). Chapter 6's BankersQueue suspends the rotation so it is forced at
;; most once, however many futures branch off that value.
;;
;; Both queues are driven identically below: take ONE pre-rotation value and do `tail` then `head`
;; on it k times -- k different futures from one past, each needing the rotation's result.
;;
;;   eager (ch5)    pays the O(n) rotation on every one of the k uses
;;   banker's (ch6) pays it once; the other k-1 read the memo
;;
;; The suspension is a stand-in built on an LRU (P-027) and costs 2x a function call per force, so
;; the banker's queue carries a constant-factor tax that a real `Susp<T>` would not. The point of
;; the table is the SHAPE -- flat versus growing with k -- not the absolute numbers.
;;
;; Run: wat okasaki/ch06-bankers-queue.wat

(:wat::load-file! "lib/bankers.wat")
(:wat::load-file! "lib/queue.wat")

(:wat::core::defn :c6::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c6::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :c6::n [] -> :wat::core::i64 800)

;; --- correctness: the banker's queue must be FIFO, and agree with the eager one ---------------
(:wat::core::defn :c6::fill-bq [n <- :wat::core::i64] -> :ok::BQ.Q
  (:wat::core::foldl (:wat::core::fn [a <- :ok::BQ.Q i <- :wat::core::i64] -> :ok::BQ.Q (:ok::bq-snoc a i))
    (:ok::bq-empty) (:wat::core::range 0 n)))

(:wat::core::defenum :c6::Acc :wat::enum::Impure :A [q <- :ok::BQ.Q  bad <- :wat::core::i64])

(:wat::core::defn :c6::check-fifo [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [a <- :c6::Acc.A i <- :wat::core::i64] -> :c6::Acc.A
        (:wat::core::match a
          [:c6::Acc.A {:q q :bad bad}
            (:c6::Acc.A {:q (:ok::bq-tail q)
                         :bad (:wat::core::if (:wat::core::= (:ok::bq-head q) i) bad (:wat::core::+ bad 1))})]))
      (:c6::Acc.A {:q (:c6::fill-bq n) :bad 0})
      (:wat::core::range 0 n))
    [:c6::Acc.A {:q q :bad bad} bad]))

;; --- the persistence comparison ---------------------------------------------------------------
;; one value, k futures: tail-then-head each time, so every use needs the rotation's result
(:wat::core::defn :c6::persist-bq [q <- :ok::BQ.Q k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::+ a (:ok::bq-head (:ok::bq-tail q))))
    0 (:wat::core::range 0 k)))

(:wat::core::defn :c6::persist-eager [q <- :ok::Queue.Q k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::foldl
    (:wat::core::fn [a <- :wat::core::i64 i <- :wat::core::i64] -> :wat::core::i64
      (:wat::core::+ a (:wat::core::match (:ok::q-head (:ok::q-tail q))
                         [:wat::core::Option.Some {:value v} v]
                         [:wat::core::Option.None {} 0])))
    0 (:wat::core::range 0 k)))

(:wat::core::defn :c6::row [k <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [n (:c6::n)
     eq (:wat::core::foldl (:wat::core::fn [a <- :ok::Queue.Q i <- :wat::core::i64] -> :ok::Queue.Q (:ok::snoc a i))
          (:ok::q-empty) (:wat::core::range 0 n))
     bq (:c6::fill-bq n)
     t1 (:c6::now) _1 (:c6::persist-eager eq k) e1 (:wat::core::- (:c6::now) t1)
     t2 (:c6::now) _2 (:c6::persist-bq bq k)    e2 (:wat::core::- (:c6::now) t2)]
    (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
      "  k=" (:wat::i64::to-string k)
      "   eager(ch5)=" (:wat::i64::to-string (:wat::core::/ e1 k))
      "   bankers(ch6)=" (:wat::i64::to-string (:wat::core::/ e2 k)) " ns/use")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:c6::say "FIFO order over 800, banker's queue"
      (:wat::core::if (:wat::core::= (:c6::check-fifo (:c6::n)) 0) "PASS" "FAIL"))
    (:wat::kernel::println "---- one value, k futures, each needing the rotation (n=800) ----")
    (:c6::row 10) (:c6::row 25) (:c6::row 50) (:c6::row 100)))
