;; okasaki/ch05-batched-queue.wat — Chapter 5's BatchedQueue, and a test of wat underneath it.
;;
;; Two lists, front and reversed rear. Each element is reversed exactly once on its way through,
;; so the O(n) reverse amortizes to O(1) per operation. That bound rests entirely on cons being
;; O(1) -- which in wat means that constructing a `:ok::List.Cons` node must SHARE its tail, not
;; copy it.
;;
;; That is not a safe assumption here. F-033 records that taking a WatAST apart copies every
;; subtree, F-023 that `conj` clones a Vector, and F-055 that `rest` clones one, so walking a
;; Vector is quadratic. If enum construction behaved the same way, snoc would be O(n), the
;; amortized bound would collapse, and the curve below would double per doubling instead of
;; staying flat.
;;
;; So this chapter is two questions at once: is Okasaki's queue right, and does wat sustain the
;; bound it is stated under?
;;
;; Run: wat okasaki/ch05-batched-queue.wat

(:wat::load-file! "lib/queue.wat")
(:wat::load-file! "lib/curve.wat")

(:wat::core::defn :c5::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; --- correctness: FIFO against a model, and the invariant after every operation ---------------
(:wat::core::defrecord :c5::Run [q <- :ok::Queue.Q  bad <- :wat::core::i64  broke <- :wat::core::i64])

;; push 0..n-1, then pop them all, checking each pops in insertion order
(:wat::core::defn :c5::fill [n <- :wat::core::i64] -> :c5::Run
  (:wat::core::foldl
    (:wat::core::fn [r <- :c5::Run i <- :wat::core::i64] -> :c5::Run
      (:wat::core::let [q (:ok::snoc (:c5::Run/q r) i)]
        (:c5::Run :q q :bad (:c5::Run/bad r)
                  :broke (:wat::core::if (:ok::q-ok? q) (:c5::Run/broke r) (:wat::core::+ (:c5::Run/broke r) 1)))))
    (:c5::Run :q (:ok::q-empty) :bad 0 :broke 0)
    (:wat::core::range 0 n)))

(:wat::core::defn :c5::drain [n <- :wat::core::i64 r <- :c5::Run] -> :c5::Run
  (:wat::core::foldl
    (:wat::core::fn [rr <- :c5::Run i <- :wat::core::i64] -> :c5::Run
      (:wat::core::let
        [bad (:wat::core::match (:ok::q-head (:c5::Run/q rr))
               [:wat::core::Option.Some {:value v}
                 (:wat::core::if (:wat::core::= v i) (:c5::Run/bad rr) (:wat::core::+ (:c5::Run/bad rr) 1))]
               [:wat::core::Option.None {} (:wat::core::+ (:c5::Run/bad rr) 1)])
         q (:ok::q-tail (:c5::Run/q rr))]
        (:c5::Run :q q :bad bad
                  :broke (:wat::core::if (:ok::q-ok? q) (:c5::Run/broke rr) (:wat::core::+ (:c5::Run/broke rr) 1)))))
    r (:wat::core::range 0 n)))

;; --- the curve, both carriers. This comparison IS F-098's repro. ------------------------------
;; Amortized O(1) means ns/op stays FLAT as n doubles. The two implementations below are the same
;; algorithm, the same cons list, the same operations -- they differ only in what holds the pair.

(:wat::core::defn :c5::enum-row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [t0 (:curve::now)
     q  (:wat::core::foldl (:wat::core::fn [a <- :ok::Queue.Q i <- :wat::core::i64] -> :ok::Queue.Q (:ok::snoc a i))
          (:ok::q-empty) (:wat::core::range 0 n))
     d  (:wat::core::foldl (:wat::core::fn [a <- :ok::Queue.Q i <- :wat::core::i64] -> :ok::Queue.Q (:ok::q-tail a))
          q (:wat::core::range 0 n))
     ns (:wat::core::- (:curve::now) t0)]
    (:curve::row "enum-carried  " n (:wat::core::* n 2) ns)))

(:wat::core::defn :c5::rec-row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [t0 (:curve::now)
     q  (:wat::core::foldl (:wat::core::fn [a <- :ok::QueueRec i <- :wat::core::i64] -> :ok::QueueRec (:ok::qr-snoc a i))
          (:ok::qr-empty) (:wat::core::range 0 n))
     d  (:wat::core::foldl (:wat::core::fn [a <- :ok::QueueRec i <- :wat::core::i64] -> :ok::QueueRec (:ok::qr-tail a))
          q (:wat::core::range 0 n))
     ns (:wat::core::- (:curve::now) t0)]
    (:curve::row "record-carried" n (:wat::core::* n 2) ns)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n 2000
     r (:c5::fill n)
     d (:c5::drain n r)]
    (:wat::core::do
      (:c5::say "size after 2000 snoc      " (:wat::i64::to-string (:ok::q-size (:c5::Run/q r))))
      (:c5::say "FIFO order preserved      " (:wat::core::if (:wat::core::= (:c5::Run/bad d) 0) "PASS" "FAIL"))
      (:c5::say "empty after draining all  " (:wat::core::if (:wat::core::= (:ok::q-size (:c5::Run/q d)) 0) "PASS" "FAIL"))
      (:c5::say "invariant held every op   " (:wat::core::if (:wat::core::= (:c5::Run/broke d) 0) "PASS" "FAIL"))
      (:wat::kernel::println "---- amortized O(1) means FLAT. Same algorithm, different carrier (F-098) ----")
      (:c5::enum-row 500) (:c5::enum-row 1000) (:c5::enum-row 2000) (:c5::enum-row 4000)
      (:c5::rec-row 500)  (:c5::rec-row 1000)  (:c5::rec-row 2000)  (:c5::rec-row 4000))))
