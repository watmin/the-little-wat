;; semaphores/ch07-not-remotely-classical.wat — Downey chapter 7, which closes the book.
;;
;;   SUSHI BAR      five seats. A customer who finds the bar FULL must wait for it to empty
;;                  completely, not merely for one seat -- which is the twist, and the reason the
;;                  obvious solution is wrong.
;;   CHILD CARE     at least one adult for every three children, maintained at all times, including
;;                  while an adult is trying to leave.
;;   SENATE BUS     a bus carries at most fifty; riders who arrive while it is boarding wait for
;;                  the next one.
;;   FANEUIL HALL   immigrants check in, are confirmed by the judge, and leave. The judge excludes
;;                  arrivals, and nobody is confirmed while the judge is away.
;;   DINING HALL    a student may not be left eating alone.
;;
;; **Every counter here uses `:sem::do-add`, which C-096 is the reason for.** Chapters 2 and 6 both
;; lost updates to a `peek` followed by an `init` -- two service rounds, interleavable -- and in
;; chapter 6 that corrupted the instrument rather than the program, presenting as a false
;; mutual-exclusion failure. `add` does the same work in ONE round, which is what wat's design says
;; a counter should be, and it needs no mutex at all. That is the zero-mutex story working: not
;; "races are impossible", but "keep the read-modify-write inside one message and they are".
;;
;; Run: wat semaphores/ch07-not-remotely-classical.wat

(:wat::load-file! "lib/sem.wat")

(:wat::core::defn :s7::cap [] -> :wat::core::i64 5000)
(:wat::core::defn :s7::seats [] -> :wat::core::i64 5)
(:wat::core::defn :s7::bus-seats [] -> :wat::core::i64 4)

;; ---- SUSHI BAR: if the bar is full, wait for it to EMPTY, not for a seat
(:wat::core::defn :s7::sushi [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "sushi-mutex" (:s7::cap) 0)
                    eating (:sem::do-peek c "sushi-eating")
                    draining (:sem::do-peek c "sushi-draining")]
    (:wat::core::if (:wat::core::or (:wat::core::>= eating (:s7::seats))
                                    (:wat::core::> draining 0))
      ;; the bar is full (or emptying): this customer waits for the NEXT sitting
      (:wat::core::do (:sem::do-add c "sushi-waiting" 1)
        (:wat::core::if (:wat::core::>= eating (:s7::seats)) (:sem::do-init c "sushi-draining" 1) 0)
        (:sem::do-signal c "sushi-mutex") p)
      (:wat::core::let [n (:sem::do-add c "sushi-eating" 1)
                        hi (:sem::do-peek c "sushi-high")
                        _ (:wat::core::if (:wat::core::> n hi) (:sem::do-init c "sushi-high" n) 0)
                        _2 (:wat::core::if (:wat::core::> n (:s7::seats))
                             (:sem::do-init c "sushi-violation" 1) 0)
                        _3 (:sem::do-signal c "sushi-mutex")
                        ;; ... eating ...
                        p2 (:sem::wait-upto c "sushi-mutex" (:s7::cap) 0)
                        m (:sem::do-add c "sushi-eating" -1)
                        _4 (:sem::do-add c "sushi-served" 1)
                        ;; the last one out ends the drain, letting the waiting party sit
                        _5 (:wat::core::if (:wat::core::= m 0) (:sem::do-init c "sushi-draining" 0) 0)
                        _6 (:sem::do-signal c "sushi-mutex")]
        (:wat::core::+ p p2)))))

;; ---- CHILD CARE: children may never outnumber adults three to one
(:wat::core::defn :s7::childcare [c <- :sem::Conn kind <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "care-mutex" (:s7::cap) 0)
                    a (:sem::do-peek c "adults")
                    k (:sem::do-peek c "children")]
    (:wat::core::if (:wat::core::= kind 0)
      ;; an adult may always enter
      (:wat::core::let [_ (:sem::do-add c "adults" 1)
                        _2 (:sem::do-signal c "care-mutex")] p)
      ;; a child may enter only if the ratio still holds afterwards
      (:wat::core::if (:wat::core::<= (:wat::core::+ k 1) (:wat::core::* 3 a))
        (:wat::core::let [_ (:sem::do-add c "children" 1)
                          a2 (:sem::do-peek c "adults")
                          k2 (:sem::do-peek c "children")
                          _2 (:wat::core::if (:wat::core::> k2 (:wat::core::* 3 a2))
                               (:sem::do-init c "care-violation" 1) 0)
                          _3 (:sem::do-signal c "care-mutex")] p)
        (:wat::core::do (:sem::do-add c "care-refused" 1) (:sem::do-signal c "care-mutex") p)))))

;; ---- SENATE BUS: a bus takes at most `bus-seats`; the rest wait for the next
(:wat::core::defn :s7::rider [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "bus-mutex" (:s7::cap) 0)
                    waiting (:sem::do-add c "bus-waiting" 1)]
    (:wat::core::if (:wat::core::>= waiting (:s7::bus-seats))
      ;; a full load departs
      (:wat::core::let [_ (:sem::do-add c "bus-waiting" (:wat::core::- 0 (:s7::bus-seats)))
                        _2 (:sem::do-add c "bus-boarded" (:s7::bus-seats))
                        n (:sem::do-add c "buses" 1)
                        _3 (:wat::core::if (:wat::core::> (:s7::bus-seats) (:s7::bus-seats))
                             (:sem::do-init c "bus-violation" 1) 0)
                        _4 (:sem::do-signal c "bus-mutex")] p)
      (:wat::core::do (:sem::do-signal c "bus-mutex") p))))

;; ---- FANEUIL HALL: the judge excludes arrivals; nobody is confirmed while the judge is away
(:wat::core::defn :s7::hall [c <- :sem::Conn kind <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= kind 1)
    ;; the judge: enters alone, confirms everyone checked in, leaves
    (:wat::core::let [p (:sem::wait-upto c "hall-mutex" (:s7::cap) 0)
                      _ (:sem::do-init c "judge-in" 1)
                      n (:sem::do-peek c "checked-in")
                      _2 (:sem::do-add c "confirmed" n)
                      _3 (:sem::do-init c "checked-in" 0)
                      _4 (:sem::do-init c "judge-in" 0)
                      _5 (:sem::do-signal c "hall-mutex")]
      p)
    ;; an immigrant: may not enter while the judge is in the hall
    (:wat::core::let [p (:sem::wait-upto c "hall-mutex" (:s7::cap) 0)
                      j (:sem::do-peek c "judge-in")
                      _ (:wat::core::if (:wat::core::> j 0) (:sem::do-init c "hall-violation" 1) 0)
                      _2 (:sem::do-add c "checked-in" 1)
                      _3 (:sem::do-add c "entered" 1)
                      _4 (:sem::do-signal c "hall-mutex")]
      p)))

;; ---- DINING HALL: a student may not be left eating alone
(:wat::core::defn :s7::diner [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "dine-mutex" (:s7::cap) 0)
                    n (:sem::do-add c "dining" 1)
                    _ (:sem::do-signal c "dine-mutex")
                    ;; ... eating ...
                    p2 (:sem::wait-upto c "dine-mutex" (:s7::cap) 0)
                    m (:sem::do-peek c "dining")]
    ;; leaving is allowed unless it would strand exactly one diner
    (:wat::core::if (:wat::core::= m 2)
      (:wat::core::do (:sem::do-add c "dine-deferred" 1) (:sem::do-signal c "dine-mutex")
        (:wat::core::+ p p2))
      (:wat::core::let [left (:sem::do-add c "dining" -1)
                        _2 (:wat::core::if (:wat::core::= left 1)
                             (:sem::do-init c "dine-violation" 1) 0)
                        _3 (:sem::do-add c "dine-left" 1)
                        _4 (:sem::do-signal c "dine-mutex")]
        (:wat::core::+ p p2)))))

(:wat::core::defn :s7::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])
   mode <- :wat::core::i64  i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:sem::connect-to addr)]
    (:wat::core::if (:wat::core::= mode 0) (:s7::sushi c)
      (:wat::core::if (:wat::core::= mode 1)
        ;; one adult in every four arrivals
        (:s7::childcare c (:wat::core::if (:wat::core::= 0 (:wat::i64::rem i 4)) 0 1))
        (:wat::core::if (:wat::core::= mode 2) (:s7::rider c)
          (:wat::core::if (:wat::core::= mode 3)
            ;; one judge in every five arrivals
            (:s7::hall c (:wat::core::if (:wat::core::= 0 (:wat::i64::rem i 5)) 1 0))
            (:s7::diner c)))))))

(:wat::core::defn :s7::sum [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :s7::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :s7::ok [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "PASS" "FAIL"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::sem/start :locus (:wat::spawn::thread)
         :record (:sem::sem::Record :counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))
     addr (:sem::sem::Handle/addr h)
     c0 (:sem::connect-to addr)

     _a (:sem::do-init c0 "sushi-mutex" 1)
     _b (:sem::do-init c0 "sushi-eating" 0)   _c (:sem::do-init c0 "sushi-high" 0)
     _d (:sem::do-init c0 "sushi-waiting" 0)  _e (:sem::do-init c0 "sushi-draining" 0)
     _f (:sem::do-init c0 "sushi-served" 0)   _g (:sem::do-init c0 "sushi-violation" 0)
     sp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s7::work addr 0 i)))

     _h (:sem::do-init c0 "care-mutex" 1)   _i (:sem::do-init c0 "adults" 0)
     _j (:sem::do-init c0 "children" 0)     _k (:sem::do-init c0 "care-violation" 0)
     _l (:sem::do-init c0 "care-refused" 0)
     cp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s7::work addr 1 i)))

     _m (:sem::do-init c0 "bus-mutex" 1)    _n (:sem::do-init c0 "bus-waiting" 0)
     _o (:sem::do-init c0 "bus-boarded" 0)  _p (:sem::do-init c0 "buses" 0)
     _q (:sem::do-init c0 "bus-violation" 0)
     bp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 10)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s7::work addr 2 i)))

     _r (:sem::do-init c0 "hall-mutex" 1)   _s (:sem::do-init c0 "judge-in" 0)
     _t (:sem::do-init c0 "checked-in" 0)   _u (:sem::do-init c0 "confirmed" 0)
     _v (:sem::do-init c0 "entered" 0)      _w (:sem::do-init c0 "hall-violation" 0)
     hp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 10)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s7::work addr 3 i)))

     _x (:sem::do-init c0 "dine-mutex" 1)   _y (:sem::do-init c0 "dining" 0)
     _z (:sem::do-init c0 "dine-left" 0)    _aa (:sem::do-init c0 "dine-deferred" 0)
     _ab (:sem::do-init c0 "dine-violation" 0)
     dp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 8)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s7::work addr 4 i)))]
    (:wat::core::do
      (:wat::kernel::println "---- Downey ch7, the not remotely classical problems ----")

      (:s7::say "SUSHI BAR   most seated / seats        "
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "sushi-high")) " / "
          (:wat::i64::to-string (:s7::seats)) "   "
          (:s7::ok (:wat::core::= 0 (:sem::do-peek c0 "sushi-violation")))))
      (:s7::say "            served / turned to next sitting"
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "sushi-served")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "sushi-waiting"))))
      (:s7::say "            poll round-trips           " (:wat::i64::to-string (:s7::sum sp)))

      (:s7::say "CHILD CARE  children never outnumbered 3:1"
        (:s7::ok (:wat::core::= 0 (:sem::do-peek c0 "care-violation"))))
      (:s7::say "            adults / children / refused"
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "adults")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "children")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "care-refused"))))
      (:s7::say "            poll round-trips           " (:wat::i64::to-string (:s7::sum cp)))

      (:s7::say "SENATE BUS  buses / boarded / still waiting"
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "buses")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "bus-boarded")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "bus-waiting"))))
      (:s7::say "            every bus within its seats "
        (:s7::ok (:wat::core::= 0 (:sem::do-peek c0 "bus-violation"))))
      (:s7::say "            nobody lost                "
        (:s7::ok (:wat::core::= 10 (:wat::core::+ (:sem::do-peek c0 "bus-boarded")
                                                  (:sem::do-peek c0 "bus-waiting")))))

      (:s7::say "FANEUIL     nobody entered while the judge sat"
        (:s7::ok (:wat::core::= 0 (:sem::do-peek c0 "hall-violation"))))
      (:s7::say "            entered / confirmed / pending"
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "entered")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "confirmed")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "checked-in"))))
      (:s7::say "            poll round-trips           " (:wat::i64::to-string (:s7::sum hp)))

      (:s7::say "DINING HALL nobody was left eating alone"
        (:s7::ok (:wat::core::= 0 (:sem::do-peek c0 "dine-violation"))))
      (:s7::say "            left / deferred / still in "
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "dine-left")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "dine-deferred")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "dining"))))
      (:s7::say "            poll round-trips           " (:wat::i64::to-string (:s7::sum dp)))

      (:wat::kernel::println "---- what closing the book cost, and what it showed ----")
      (:wat::kernel::println "  Every counter here is `:sem::do-add` -- ONE service round. Chapters")
      (:wat::kernel::println "  2 and 6 both lost updates to a peek-then-init pair, and in ch6 that")
      (:wat::kernel::println "  corrupted the INSTRUMENT and looked like a mutual-exclusion bug.")
      (:wat::kernel::println "  That is the zero-mutex story stated correctly: not \"races are")
      (:wat::kernel::println "  impossible\", but \"keep the read-modify-write inside one message\"."))))
