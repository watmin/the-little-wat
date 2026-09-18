;; probes/lox/stack-mix.wat
;;
;; Q: at the depths a VM stack ACTUALLY reaches, does the type matter?
;;
;; F-116 measured push and pop against depth and found a Vector's rebuild-pop quadratic and a
;; PersistentVector's linear -- 121 ms against 34 ms for one pop at depth 4000. That is a real
;; difference, and Crafting Interpreters chapter 30's lesson is that a real difference at the
;; wrong scale is not an optimisation. A Lox stack holds one frame's locals plus a couple of
;; temporaries; it reaches tens, not thousands.
;;
;; So this runs the operation MIX a byte-code VM actually performs -- push, read, pop, and a
;; positional store -- at the depths it actually reaches, on both types.
;;
;; Run: wat probes/lox/stack-mix.wat

(:wat::core::defn :p::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :p::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))
(:wat::core::defn :p::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:p::pad (:wat::string::concat s " ") n)))

(:wat::core::typealias :p::V (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :p::PV (:wat::core::PersistentVector :- [:wat::core::i64]))

(:wat::core::defn :p::build [n <- :wat::core::i64 acc <- :p::V] -> :p::V
  (:wat::core::if (:wat::core::>= (:wat::core::length acc) n) acc
    (:p::build n (:wat::core::conj acc 1))))

(:wat::core::defn :p::pbuild [n <- :wat::core::i64 acc <- :p::PV] -> :p::PV
  (:wat::core::if (:wat::core::>= (:wat::vector::length acc) n) acc
    (:p::pbuild n (:wat::vector::conj acc 1))))

;; ---- Vector: one instruction's worth of stack work
(:wat::core::defn :p::take-k [s <- :p::V k <- :wat::core::i64 i <- :wat::core::i64 acc <- :p::V] -> :p::V
  (:wat::core::if (:wat::core::>= i k) acc
    (:p::take-k s k (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :p::set-at [s <- :p::V i <- :wat::core::i64 v <- :wat::core::i64
                              j <- :wat::core::i64 acc <- :p::V] -> :p::V
  (:wat::core::if (:wat::core::>= j (:wat::core::length s)) acc
    (:p::set-at s i v (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= j i) v (:wat::core::nth s j))))))

;; the mix a binary operator performs: read two, pop two, push one. Then a SET_LOCAL.
(:wat::core::defn :p::mix-v [s <- :p::V k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:wat::core::let [n (:wat::core::length s)
                      a (:wat::core::nth s (:wat::core::- n 1))
                      b (:wat::core::nth s (:wat::core::- n 2))
                      popped (:p::take-k s (:wat::core::- n 2) 0 (:wat::core::Vector :- [:wat::core::i64]))
                      pushed (:wat::core::conj popped (:wat::core::+ a b))
                      stored (:p::set-at pushed 0 a 0 (:wat::core::Vector :- [:wat::core::i64]))]
      (:p::mix-v s (:wat::core::- k 1) (:wat::core::+ acc (:wat::core::length stored))))))

;; ---- PersistentVector: the same mix
(:wat::core::defn :p::pget [v <- :p::PV i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::vector::get v i)
    [:wat::core::Option.Some {:value x} x] [:wat::core::Option.None {} 0]))

(:wat::core::defn :p::ptake-k [s <- :p::PV k <- :wat::core::i64 i <- :wat::core::i64 acc <- :p::PV] -> :p::PV
  (:wat::core::if (:wat::core::>= i k) acc
    (:p::ptake-k s k (:wat::core::+ i 1) (:wat::vector::conj acc (:p::pget s i)))))

(:wat::core::defn :p::pset-at [s <- :p::PV i <- :wat::core::i64 v <- :wat::core::i64
                               j <- :wat::core::i64 acc <- :p::PV] -> :p::PV
  (:wat::core::if (:wat::core::>= j (:wat::vector::length s)) acc
    (:p::pset-at s i v (:wat::core::+ j 1)
      (:wat::vector::conj acc (:wat::core::if (:wat::core::= j i) v (:p::pget s j))))))

(:wat::core::defn :p::mix-p [s <- :p::PV k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:wat::core::let [n (:wat::vector::length s)
                      a (:p::pget s (:wat::core::- n 1))
                      b (:p::pget s (:wat::core::- n 2))
                      popped (:p::ptake-k s (:wat::core::- n 2) 0 (:wat::core::PersistentVector :- [:wat::core::i64]))
                      pushed (:wat::vector::conj popped (:wat::core::+ a b))
                      stored (:p::pset-at pushed 0 a 0 (:wat::core::PersistentVector :- [:wat::core::i64]))]
      (:p::mix-p s (:wat::core::- k 1) (:wat::core::+ acc (:wat::vector::length stored))))))

(:wat::core::defn :p::row [n <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [v (:p::build n (:wat::core::Vector :- [:wat::core::i64]))
     pv (:p::pbuild n (:wat::core::PersistentVector :- [:wat::core::i64]))
     w1 (:p::mix-v v 20 0) w2 (:p::mix-p pv 20 0)
     a0 (:p::now) x1 (:p::mix-p pv k 0) a1 (:p::now)
     b0 (:p::now) y1 (:p::mix-v v k 0) b1 (:p::now)
     c0 (:p::now) x2 (:p::mix-p pv k 0) c1 (:p::now)
     d0 (:p::now) y2 (:p::mix-v v k 0) d1 (:p::now)
     tp (:p::imin (:wat::core::- a1 a0) (:wat::core::- c1 c0))
     tv (:p::imin (:wat::core::- b1 b0) (:wat::core::- d1 d0))]
    (:wat::kernel::println
      (:wat::string::concat
        "depth " (:p::pad (:wat::i64::to-string n) 6)
        "  Vector " (:p::pad (:wat::i64::to-string (:wat::core::/ tv k)) 9) " ns/op"
        "  PersistentVector " (:p::pad (:wat::i64::to-string (:wat::core::/ tp k)) 9) " ns/op"
        "  Vector is " (:wat::i64::to-string (:wat::core::/ (:wat::core::* tv 100) tp)) "%"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "one binary operator's stack work (2 reads, a pop of 2, a push, a store)")
    (:wat::kernel::println "min of 2, arms interleaved")
    (:p::row 4 2000)
    (:p::row 8 2000)
    (:p::row 16 2000)
    (:p::row 32 1000)
    (:p::row 128 400)
    (:p::row 512 100)
    (:wat::kernel::println "")
    (:wat::kernel::println "The first four rows are the depths a Lox stack actually reaches.")))
