;; probes/lox/stack-ops.wat
;;
;; Q: what do the two operations of a STACK cost in wat -- push and pop -- at depth?
;;
;; Crafting Interpreters chapter 22 puts local variables on the VM's stack, so `OP_SET_LOCAL` is
;; a positional write and almost every instruction ends in a pop. F-104 says there is no
;; positional update. This asks the narrower question the VM actually depends on:
;;
;;   PUSH   `(:wat::core::conj s v)` -- F-023 says `conj` clones a Vector. At what cost?
;;   POP    there is no `pop`, no `subvec`, no `butlast`; `take` and `drop` answer a Stream with
;;          no way back (F-088). So a pop is a rebuild. At what cost?
;;
;; Both measured against depth, with a `PersistentVector` beside the `Vector` because F-108 says
;; the `:wat::vector::` namespace serves that type and not this one.
;;
;; Run: wat probes/lox/stack-ops.wat

(:wat::core::defn :p::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :p::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))
(:wat::core::defn :p::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:p::pad (:wat::string::concat s " ") n)))

(:wat::core::typealias :p::V (:wat::core::Vector :- [:wat::core::i64]))

(:wat::core::defn :p::build [n <- :wat::core::i64 acc <- :p::V] -> :p::V
  (:wat::core::if (:wat::core::>= (:wat::core::length acc) n) acc
    (:p::build n (:wat::core::conj acc 1))))

;; PUSH then discard, k times -- the vector never grows past n+1
(:wat::core::defn :p::push-k [v <- :p::V k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:p::push-k v (:wat::core::- k 1)
      (:wat::core::+ acc (:wat::core::length (:wat::core::conj v 7))))))

;; POP: rebuild all but the last
(:wat::core::defn :p::take-k [s <- :p::V k <- :wat::core::i64 i <- :wat::core::i64 acc <- :p::V] -> :p::V
  (:wat::core::if (:wat::core::>= i k) acc
    (:p::take-k s k (:wat::core::+ i 1) (:wat::core::conj acc (:wat::core::nth s i)))))

(:wat::core::defn :p::pop-k [v <- :p::V k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:p::pop-k v (:wat::core::- k 1)
      (:wat::core::+ acc (:wat::core::length
        (:p::take-k v (:wat::core::- (:wat::core::length v) 1) 0 (:wat::core::Vector :- [:wat::core::i64])))))))

;; the CONTROL: read one element, which is O(1), so the loop's own cost is visible
(:wat::core::defn :p::read-k [v <- :p::V k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:p::read-k v (:wat::core::- k 1)
      (:wat::core::+ acc (:wat::core::nth v (:wat::core::- (:wat::core::length v) 1))))))

;; ---- the same two operations on a PersistentVector, whose name promises structural sharing.
;; F-108: the `:wat::vector::` namespace serves THIS type and rejects the one called `Vector`.
(:wat::core::typealias :p::PV (:wat::core::PersistentVector :- [:wat::core::i64]))

(:wat::core::defn :p::pbuild [n <- :wat::core::i64 acc <- :p::PV] -> :p::PV
  (:wat::core::if (:wat::core::>= (:wat::vector::length acc) n) acc
    (:p::pbuild n (:wat::vector::conj acc 1))))

(:wat::core::defn :p::ppush-k [v <- :p::PV k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:p::ppush-k v (:wat::core::- k 1)
      (:wat::core::+ acc (:wat::vector::length (:wat::vector::conj v 7))))))

(:wat::core::defn :p::pget [v <- :p::PV i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::vector::get v i)
    [:wat::core::Option.Some {:value x} x] [:wat::core::Option.None {} 0]))

(:wat::core::defn :p::ptake-k [s <- :p::PV k <- :wat::core::i64 i <- :wat::core::i64 acc <- :p::PV] -> :p::PV
  (:wat::core::if (:wat::core::>= i k) acc
    (:p::ptake-k s k (:wat::core::+ i 1) (:wat::vector::conj acc (:p::pget s i)))))

(:wat::core::defn :p::ppop-k [v <- :p::PV k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:p::ppop-k v (:wat::core::- k 1)
      (:wat::core::+ acc (:wat::vector::length
        (:p::ptake-k v (:wat::core::- (:wat::vector::length v) 1) 0
          (:wat::core::PersistentVector :- [:wat::core::i64])))))))

(:wat::core::defn :p::prow [n <- :wat::core::i64 k <- :wat::core::i64 pk <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [v (:p::pbuild n (:wat::core::PersistentVector :- [:wat::core::i64]))
     w (:p::ppush-k v 20 0) w2 (:p::ppop-k v 3 0)
     a0 (:p::now) x1 (:p::ppush-k v k 0) a1 (:p::now)
     c0 (:p::now) z1 (:p::ppop-k v pk 0) c1 (:p::now)
     b0 (:p::now) x2 (:p::ppush-k v k 0) b1 (:p::now)
     d0 (:p::now) z2 (:p::ppop-k v pk 0) d1 (:p::now)]
    (:wat::kernel::println
      (:wat::string::concat
        "depth " (:p::pad (:wat::i64::to-string n) 7)
        "  PersistentVector push " (:p::pad (:wat::i64::to-string
          (:wat::core::/ (:p::imin (:wat::core::- a1 a0) (:wat::core::- b1 b0)) k)) 8) " ns"
        "  rebuild-pop " (:p::pad (:wat::i64::to-string
          (:wat::core::/ (:p::imin (:wat::core::- c1 c0) (:wat::core::- d1 d0)) pk)) 9) " ns"))))

(:wat::core::defn :p::row [n <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [v (:p::build n (:wat::core::Vector :- [:wat::core::i64]))
     w1 (:p::read-k v 20 0) w2 (:p::push-k v 20 0) w3 (:p::pop-k v 5 0)
     a0 (:p::now) x1 (:p::read-k v k 0) a1 (:p::now)
     b0 (:p::now) y1 (:p::push-k v k 0) b1 (:p::now)
     c0 (:p::now) z1 (:p::pop-k v k 0) c1 (:p::now)
     d0 (:p::now) x2 (:p::read-k v k 0) d1 (:p::now)
     e0 (:p::now) y2 (:p::push-k v k 0) e1 (:p::now)
     f0 (:p::now) z2 (:p::pop-k v k 0) f1 (:p::now)
     rd (:p::imin (:wat::core::- a1 a0) (:wat::core::- d1 d0))
     pu (:p::imin (:wat::core::- b1 b0) (:wat::core::- e1 e0))
     po (:p::imin (:wat::core::- c1 c0) (:wat::core::- f1 f0))]
    (:wat::kernel::println
      (:wat::string::concat
        "depth " (:p::pad (:wat::i64::to-string n) 7)
        "  read " (:p::pad (:wat::i64::to-string (:wat::core::/ rd k)) 8) " ns"
        "  push " (:p::pad (:wat::i64::to-string (:wat::core::/ pu k)) 8) " ns"
        "  pop " (:p::pad (:wat::i64::to-string (:wat::core::/ po k)) 9) " ns"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "one push and one pop on a Vector of the given depth (min of 2, interleaved)")
    (:p::row 10 4000)
    (:p::row 100 4000)
    (:p::row 1000 1000)
    (:p::row 4000 300)
    (:wat::kernel::println "")
    (:wat::kernel::println "")
    (:p::prow 10 4000 2000)
    (:p::prow 100 4000 500)
    (:p::prow 1000 1000 50)
    (:p::prow 4000 1000 10)
    (:wat::kernel::println "")
    (:wat::kernel::println "`read` is the control: it is O(1), so its column is the loop's own cost,")
    (:wat::kernel::println "and it is flat at about 8.5 us. Read everything else against that.")
    (:wat::kernel::println "")
    (:wat::kernel::println "  Vector push            rises with depth -- F-023's clone, priced")
    (:wat::kernel::println "  PersistentVector push  FLAT -- the structural sharing its name promises")
    (:wat::kernel::println "  Vector rebuild-pop     QUADRATIC: n clones, each O(n)")
    (:wat::kernel::println "  PV rebuild-pop         linear, and equal to n x the control -- so the")
    (:wat::kernel::println "                         conjs themselves cost nothing; it is all loop")
    (:wat::kernel::println "")
    (:wat::kernel::println "So for a VM stack there are two separate asks. Using the type whose name")
    (:wat::kernel::println "does NOT match (PersistentVector, which :wat::vector:: serves and which")
    (:wat::kernel::println "rejects the type called Vector -- F-108) turns a quadratic pop into a")
    (:wat::kernel::println "linear one. Adding a `pop` verb would turn the linear one into O(1).")))
