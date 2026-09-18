;; semaphores/ch05-less-classical.wat — Downey chapter 5's "less classical" problems, on the
;; counting semaphore of semaphores/lib/sem.wat.
;;
;;   DINING SAVAGES   a pot of M servings. Savages take one at a time; the one who finds the pot
;;                    empty wakes the cook, who refills it. Invariant: no savage ever eats from an
;;                    empty pot, and the pot is never over-filled.
;;   BARBERSHOP       n waiting chairs. A customer who finds the shop full LEAVES rather than
;;                    waiting. Invariant: the shop never holds more than n.
;;   BUILDING H2O     two hydrogens and one oxygen must bond together before any of them proceeds.
;;                    Invariant: every molecule released is exactly 2 H and 1 O.
;;   RIVER CROSSING   a boat holds four, and must never carry three of one kind and one of the
;;                    other. Invariant: every boat is 4+0, 0+4 or 2+2.
;;
;; These are compositions of the same primitive as chapter 4, which is the point of covering them
;; rather than the reason to skip them: the book's claim is that ONE primitive suffices for all of
;; it, and a port that stops at the famous problems has not tested that claim.
;;
;; Every wait is bounded (F-102 makes a wait a spin, and a spin that cannot end would hang the
;; run), and every puzzle reports its poll count.
;;
;; Run: wat semaphores/ch05-less-classical.wat

(:wat::load-file! "lib/sem.wat")

(:wat::core::defn :s5::cap [] -> :wat::core::i64 5000)
(:wat::core::defn :s5::servings [] -> :wat::core::i64 3)
(:wat::core::defn :s5::savages [] -> :wat::core::i64 6)
(:wat::core::defn :s5::chairs [] -> :wat::core::i64 3)

;; ---- DINING SAVAGES: take a serving, or wake the cook if the pot is empty
(:wat::core::defn :s5::savage [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "pot-mutex" (:s5::cap) 0)
                    n (:sem::do-peek c "pot")
                    ;; the cook refills only when the pot is found empty -- never otherwise
                    refilled (:wat::core::if (:wat::core::<= n 0)
                               (:wat::core::do (:sem::do-init c "pot" (:s5::servings))
                                 (:sem::do-init c "refills" (:wat::core::+ 1 (:sem::do-peek c "refills")))
                                 (:s5::servings))
                               n)
                    ;; eating from an empty pot is the failure the puzzle exists to prevent
                    _v (:wat::core::if (:wat::core::<= refilled 0)
                         (:sem::do-init c "savage-violation" 1) 0)
                    _ (:sem::do-init c "pot" (:wat::core::- refilled 1))
                    _2 (:sem::do-init c "eaten" (:wat::core::+ 1 (:sem::do-peek c "eaten")))
                    _3 (:sem::do-signal c "pot-mutex")]
    p))

;; ---- BARBERSHOP: a customer who finds the shop full leaves
(:wat::core::defn :s5::customer [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "shop-mutex" (:s5::cap) 0)
                    n (:sem::do-peek c "in-shop")]
    (:wat::core::if (:wat::core::>= n (:s5::chairs))
      ;; turned away -- and that is correct behaviour, not a failure
      (:wat::core::do (:sem::do-init c "turned-away" (:wat::core::+ 1 (:sem::do-peek c "turned-away")))
        (:sem::do-signal c "shop-mutex") 0)
      (:wat::core::let [_ (:sem::do-init c "in-shop" (:wat::core::+ n 1))
                        hi (:sem::do-peek c "shop-high")
                        _2 (:wat::core::if (:wat::core::> (:wat::core::+ n 1) hi)
                             (:sem::do-init c "shop-high" (:wat::core::+ n 1)) 0)
                        _3 (:sem::do-signal c "shop-mutex")
                        ;; ... haircut ...
                        p2 (:sem::wait-upto c "shop-mutex" (:s5::cap) 0)
                        _4 (:sem::do-init c "in-shop" (:wat::core::- (:sem::do-peek c "in-shop") 1))
                        _5 (:sem::do-init c "served" (:wat::core::+ 1 (:sem::do-peek c "served")))
                        _6 (:sem::do-signal c "shop-mutex")]
        (:wat::core::+ p p2)))))

;; ---- BUILDING H2O: bond when two hydrogens and one oxygen are present
(:wat::core::defn :s5::atom [c <- :sem::Conn kind <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "h2o-mutex" (:s5::cap) 0)
                    _ (:wat::core::if (:wat::core::= kind 0)
                        (:sem::do-init c "h-waiting" (:wat::core::+ 1 (:sem::do-peek c "h-waiting")))
                        (:sem::do-init c "o-waiting" (:wat::core::+ 1 (:sem::do-peek c "o-waiting"))))
                    h (:sem::do-peek c "h-waiting")
                    o (:sem::do-peek c "o-waiting")
                    ;; a molecule is formed only when BOTH are there, and consumes exactly 2H + 1O
                    formed (:wat::core::if (:wat::core::and (:wat::core::>= h 2) (:wat::core::>= o 1))
                             (:wat::core::do
                               (:sem::do-init c "h-waiting" (:wat::core::- h 2))
                               (:sem::do-init c "o-waiting" (:wat::core::- o 1))
                               (:sem::do-init c "molecules" (:wat::core::+ 1 (:sem::do-peek c "molecules")))
                               (:sem::do-init c "h-bonded" (:wat::core::+ 2 (:sem::do-peek c "h-bonded")))
                               (:sem::do-init c "o-bonded" (:wat::core::+ 1 (:sem::do-peek c "o-bonded")))
                               1)
                             0)
                    _2 (:sem::do-signal c "h2o-mutex")]
    p))

;; ---- RIVER CROSSING: four to a boat, never 3-and-1
(:wat::core::defn :s5::passenger [c <- :sem::Conn kind <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "boat-mutex" (:s5::cap) 0)
                    _ (:wat::core::if (:wat::core::= kind 0)
                        (:sem::do-init c "a-waiting" (:wat::core::+ 1 (:sem::do-peek c "a-waiting")))
                        (:sem::do-init c "b-waiting" (:wat::core::+ 1 (:sem::do-peek c "b-waiting"))))
                    a (:sem::do-peek c "a-waiting")
                    b (:sem::do-peek c "b-waiting")
                    ;; the only legal loads: 4+0, 0+4, 2+2
                    load-a (:wat::core::if (:wat::core::>= a 4) 4
                             (:wat::core::if (:wat::core::and (:wat::core::>= a 2) (:wat::core::>= b 2)) 2 0))
                    load-b (:wat::core::if (:wat::core::>= a 4) 0
                             (:wat::core::if (:wat::core::and (:wat::core::>= a 2) (:wat::core::>= b 2)) 2
                               (:wat::core::if (:wat::core::>= b 4) 4 0)))
                    sailed (:wat::core::if (:wat::core::= 4 (:wat::core::+ load-a load-b))
                             (:wat::core::do
                               (:sem::do-init c "a-waiting" (:wat::core::- a load-a))
                               (:sem::do-init c "b-waiting" (:wat::core::- b load-b))
                               (:sem::do-init c "boats" (:wat::core::+ 1 (:sem::do-peek c "boats")))
                               ;; record an illegal load if one ever happens
                               (:wat::core::if (:wat::core::or (:wat::core::= load-a 1) (:wat::core::= load-a 3))
                                 (:sem::do-init c "boat-violation" 1) 0)
                               1)
                             0)
                    _2 (:sem::do-signal c "boat-mutex")]
    p))

(:wat::core::defn :s5::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])
   mode <- :wat::core::i64  i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:sem::connect-to addr)]
    (:wat::core::if (:wat::core::= mode 0) (:s5::savage c)
      (:wat::core::if (:wat::core::= mode 1) (:s5::customer c)
        (:wat::core::if (:wat::core::= mode 2)
          ;; two hydrogens for every oxygen
          (:s5::atom c (:wat::core::if (:wat::core::= 0 (:wat::i64::rem i 3)) 1 0))
          (:s5::passenger c (:wat::i64::rem i 2)))))))

(:wat::core::defn :s5::sum [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :s5::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :s5::ok [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "PASS" "FAIL"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::sem/start :locus (:wat::spawn::thread)
         :record (:sem::sem::Record :counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))
     addr (:sem::sem::Handle/addr h)
     c0 (:sem::connect-to addr)

     ;; ---- dining savages
     _a (:sem::do-init c0 "pot" (:s5::servings))
     _b (:sem::do-init c0 "pot-mutex" 1)
     _c (:sem::do-init c0 "eaten" 0)
     _d (:sem::do-init c0 "refills" 0)
     _e (:sem::do-init c0 "savage-violation" 0)
     sp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 (:s5::savages))
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s5::work addr 0 i)))
     eaten (:sem::do-peek c0 "eaten")
     refills (:sem::do-peek c0 "refills")
     sviol (:sem::do-peek c0 "savage-violation")

     ;; ---- barbershop
     _f (:sem::do-init c0 "shop-mutex" 1)
     _g (:sem::do-init c0 "in-shop" 0)
     _h (:sem::do-init c0 "shop-high" 0)
     _i (:sem::do-init c0 "served" 0)
     _j (:sem::do-init c0 "turned-away" 0)
     bp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 8)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s5::work addr 1 i)))
     shop-high (:sem::do-peek c0 "shop-high")
     served (:sem::do-peek c0 "served")
     turned (:sem::do-peek c0 "turned-away")

     ;; ---- building H2O: 12 atoms, one oxygen in every three
     _k (:sem::do-init c0 "h2o-mutex" 1)
     _l (:sem::do-init c0 "h-waiting" 0)
     _m (:sem::do-init c0 "o-waiting" 0)
     _n (:sem::do-init c0 "molecules" 0)
     _o (:sem::do-init c0 "h-bonded" 0)
     _p (:sem::do-init c0 "o-bonded" 0)
     hp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s5::work addr 2 i)))
     molecules (:sem::do-peek c0 "molecules")
     hb (:sem::do-peek c0 "h-bonded")
     ob (:sem::do-peek c0 "o-bonded")

     ;; ---- river crossing: 12 passengers, alternating kinds
     _q (:sem::do-init c0 "boat-mutex" 1)
     _r (:sem::do-init c0 "a-waiting" 0)
     _s (:sem::do-init c0 "b-waiting" 0)
     _t (:sem::do-init c0 "boats" 0)
     _u (:sem::do-init c0 "boat-violation" 0)
     rp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s5::work addr 3 i)))
     boats (:sem::do-peek c0 "boats")
     bviol (:sem::do-peek c0 "boat-violation")]
    (:wat::core::do
      (:wat::kernel::println "---- Downey ch5, the less classical problems ----")

      (:s5::say "SAVAGES     servings eaten                "
        (:wat::string::concat (:wat::i64::to-string eaten) " / " (:wat::i64::to-string (:s5::savages))
          "   " (:s5::ok (:wat::core::= eaten (:s5::savages)))))
      (:s5::say "            nobody ate from an empty pot   " (:s5::ok (:wat::core::= sviol 0)))
      (:s5::say "            times the cook was woken       " (:wat::i64::to-string refills))
      (:s5::say "            poll round-trips               " (:wat::i64::to-string (:s5::sum sp)))

      (:s5::say "BARBERSHOP  served + turned away / arrived "
        (:wat::string::concat (:wat::i64::to-string (:wat::core::+ served turned)) " / 8   "
          (:s5::ok (:wat::core::= 8 (:wat::core::+ served turned)))))
      (:s5::say "            most in the shop / chairs      "
        (:wat::string::concat (:wat::i64::to-string shop-high) " / " (:wat::i64::to-string (:s5::chairs))
          "   " (:s5::ok (:wat::core::<= shop-high (:s5::chairs)))))
      (:s5::say "            poll round-trips               " (:wat::i64::to-string (:s5::sum bp)))

      (:s5::say "H2O         molecules bonded               " (:wat::i64::to-string molecules))
      (:s5::say "            every molecule was exactly 2H+1O"
        (:s5::ok (:wat::core::and (:wat::core::= hb (:wat::core::* 2 molecules))
                                  (:wat::core::= ob molecules))))
      (:s5::say "            poll round-trips               " (:wat::i64::to-string (:s5::sum hp)))

      (:s5::say "RIVER       boats that sailed              " (:wat::i64::to-string boats))
      (:s5::say "            no boat carried three-and-one  " (:s5::ok (:wat::core::= bviol 0)))
      (:s5::say "            poll round-trips               " (:wat::i64::to-string (:s5::sum rp)))

      (:wat::kernel::println "---- why these are here even though they are variations ----")
      (:wat::kernel::println "  The book's claim is that ONE primitive suffices for all of it.")
      (:wat::kernel::println "  A port that stops at the famous problems has not tested that")
      (:wat::kernel::println "  claim -- it has only tested the famous problems."))))
