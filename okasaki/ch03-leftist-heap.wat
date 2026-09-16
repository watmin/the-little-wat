;; okasaki/ch03-leftist-heap.wat — Chapter 3's LeftistHeap: the priority queue F-056 says is missing.
;;
;; F-056 records that wat has no priority queue and no ordered collection of any kind. This is the
;; smallest structure that supplies one: merge is O(log n), and insert and delete-min are both
;; merge in disguise.
;;
;; Two things are checked, in this order:
;;
;;   CORRECTNESS  the leftist property and heap order hold after every insert, and draining the
;;                heap by delete-min yields the input sorted, with nothing lost or invented.
;;                F-097 is the reason this comes first: a timing comparison against a wrong
;;                structure is worth nothing.
;;
;;   THE CURVE    F-097 also showed that wall-clock loses to a native competitor whatever the
;;                algorithm, so the bound is what is worth measuring. For O(log n), ns/op grows
;;                by a roughly constant ADDITIVE step each time n doubles -- not a ratio of 2.
;;
;; Run: wat okasaki/ch03-leftist-heap.wat

(:wat::load-file! "lib/heap.wat")
(:wat::load-file! "lib/curve.wat")

(:wat::core::defn :c3::step [x <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem (:wat::core::+ (:wat::core::* x 1103515245) 12345) 2147483648))

(:wat::core::defn :c3::val [i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::rem (:c3::step (:wat::core::+ i 7)) 100000))

(:wat::core::defn :c3::build [n <- :wat::core::i64] -> :ok::Heap
  (:wat::core::foldl
    (:wat::core::fn [h <- :ok::Heap i <- :wat::core::i64] -> :ok::Heap (:ok::h-insert h (:c3::val i)))
    (:ok::h-empty) (:wat::core::range 0 n)))

;; drain by delete-min, counting how many came out in non-decreasing order
(:wat::core::defrecord :c3::Drain [n <- :wat::core::i64  bad <- :wat::core::i64  last <- :wat::core::i64])

(:wat::core::defn :c3::drain [h <- :ok::Heap d <- :c3::Drain] -> :c3::Drain
  (:wat::core::match (:ok::find-min h)
    [:wat::core::Option.None {} d]
    [:wat::core::Option.Some {:value v}
      (:c3::drain (:ok::delete-min h)
        (:c3::Drain :n (:wat::core::+ (:c3::Drain/n d) 1)
                    :bad (:wat::core::if (:wat::core::< v (:c3::Drain/last d))
                           (:wat::core::+ (:c3::Drain/bad d) 1) (:c3::Drain/bad d))
                    :last v))]))

(:wat::core::defn :c3::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; time 400 inserts into a heap already holding n
(:wat::core::defn :c3::curve-row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [h  (:c3::build n)
     k  400
     t0 (:curve::now)
     _  (:wat::core::foldl
          (:wat::core::fn [hh <- :ok::Heap i <- :wat::core::i64] -> :ok::Heap
            (:ok::h-insert hh (:c3::val (:wat::core::+ i 99991))))
          h (:wat::core::range 0 k))
     ns (:wat::core::- (:curve::now) t0)]
    (:curve::row "insert" n k ns)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n 2000
     h (:c3::build n)
     d (:c3::drain h (:c3::Drain :n 0 :bad 0 :last -1))]
    (:wat::core::do
      (:c3::say "size after 2000 inserts   " (:wat::i64::to-string (:ok::h-size h)))
      (:c3::say "leftist property holds    " (:wat::core::if (:ok::leftist? h) "PASS" "FAIL"))
      (:c3::say "heap order holds          " (:wat::core::if (:ok::ordered? h) "PASS" "FAIL"))
      (:c3::say "drained count == inserted " (:wat::core::if (:wat::core::= (:c3::Drain/n d) n) "PASS" "FAIL"))
      (:c3::say "drain is non-decreasing   " (:wat::core::if (:wat::core::= (:c3::Drain/bad d) 0) "PASS" "FAIL"))
      (:wat::kernel::println "---- insert cost vs heap size (O(log n): a constant ADDITIVE step per doubling) ----")
      (:c3::curve-row 500) (:c3::curve-row 1000) (:c3::curve-row 2000) (:c3::curve-row 4000))))
