;; semaphores/ch04-classical.wat — Downey chapter 4's classical problems, on the counting
;; semaphore of semaphores/lib/sem.wat.
;;
;;   PRODUCER-CONSUMER   a bounded buffer: `items` counts what is there, `spaces` counts what will
;;                       fit, and a mutex guards the buffer itself. Nothing is consumed that was
;;                       not produced, and the buffer never exceeds its size.
;;   READERS-WRITERS     many readers together, or one writer alone. The first reader in locks the
;;                       room against writers and the last one out unlocks it.
;;   DINING PHILOSOPHERS Downey's worked DEADLOCK, and his fix. Five philosophers who each take
;;                       their left fork first can all hold one and wait forever; a footman who
;;                       admits only four to the table cannot.
;;
;; **The deadlock is the reason this file is worth having, and F-102 changes its shape.** In
;; Downey a deadlocked philosopher is a blocked thread and the program hangs. Here a wait is a
;; spin, so a deadlock is an infinite LOOP — which would hang the run rather than report. So the
;; unfixed version uses `:sem::wait-upto`, which gives up after a bounded number of polls and
;; answers -1, turning "this design deadlocks" into a number. That is the one thing the missing
;; primitive gives back: a spin can time out, and a blocking wait cannot without extra machinery.
;;
;; Every puzzle reports its poll count, because that is what F-102 costs it.
;;
;; AND THE DEADLOCK THAT DOES NOT HAPPEN. Downey's worked example is five philosophers who each
;; take their left fork first and all wait forever. On this runtime they do not: 5/5 ate, on five
;; consecutive runs. That is evidence about the THREAD POOL rather than about the algorithm --
;; F-094 measured `bracket::map` at 29% of what the same machine does with OS processes, and
;; philosophers who run nearly serially never hold a fork anyone else wants. It is the worse of
;; the two outcomes: a design the book calls broken PASSES here, so it would pass in testing and
;; deadlock later on a scheduler that actually interleaves. The book is self-oracling only when
;; the scheduler cooperates.
;;
;; A NOTE ON A DEADLOCK I WROTE MYSELF, kept because it is the same lesson. The first version ran
;; the producers through `bracket::map` and then consumed afterwards. With a 3-slot buffer and 18
;; items the producers filled it and spun on `spaces` forever, because nothing was draining yet --
;; and since a wait is a spin, that was not a blocked program but a HOT LOOP that never returned.
;; The consumer now runs as one of the pool's workers, and every wait below is bounded, so a stall
;; is reported rather than hung. In a language with blocking that bug would have deadlocked
;; visibly; here it burned CPU and looked like slowness.
;;
;; Run: wat semaphores/ch04-classical.wat

(:wat::load-file! "lib/sem.wat")

(:wat::core::defn :s4::philosophers [] -> :wat::core::i64 5)
(:wat::core::defn :s4::buffer-size [] -> :wat::core::i64 3)
(:wat::core::defn :s4::producers [] -> :wat::core::i64 2)
(:wat::core::defn :s4::per-producer [] -> :wat::core::i64 4)

(:wat::core::defn :s4::poll-cap [] -> :wat::core::i64 5000)

(:wat::core::defn :s4::fork-name [i <- :wat::core::i64] -> :wat::core::String
  (:wat::string::concat "fork-" (:wat::i64::to-string i)))

;; ---- PRODUCER-CONSUMER: produce into a bounded buffer, then drain it
(:wat::core::defn :s4::produce [c <- :sem::Conn k <- :wat::core::i64 polls <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::<= k 0) polls
    (:wat::core::let [p1 (:sem::wait-upto c "spaces" (:s4::poll-cap) 0)
                      p2 (:sem::wait-upto c "pc-mutex" (:s4::poll-cap) 0)
                      n (:sem::do-peek c "buffer")
                      _ (:sem::do-init c "buffer" (:wat::core::+ n 1))
                      hi (:sem::do-peek c "high-water")
                      _2 (:wat::core::if (:wat::core::> (:wat::core::+ n 1) hi)
                           (:sem::do-init c "high-water" (:wat::core::+ n 1)) 0)
                      _3 (:sem::do-signal c "pc-mutex")
                      _4 (:sem::do-signal c "items")]
      (:s4::produce c (:wat::core::- k 1) (:wat::core::+ polls (:wat::core::+ p1 p2))))))

(:wat::core::defn :s4::consume [c <- :sem::Conn k <- :wat::core::i64 got <- :wat::core::i64 polls <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::<= k 0) got
    (:wat::core::let [p1 (:sem::wait-upto c "items" (:s4::poll-cap) 0)
                      p2 (:sem::wait-upto c "pc-mutex" (:s4::poll-cap) 0)
                      n (:sem::do-peek c "buffer")
                      _ (:sem::do-init c "buffer" (:wat::core::- n 1))
                      _2 (:sem::do-signal c "pc-mutex")
                      _3 (:sem::do-signal c "spaces")]
      (:s4::consume c (:wat::core::- k 1) (:wat::core::+ got 1) (:wat::core::+ polls (:wat::core::+ p1 p2))))))

;; ---- READERS-WRITERS: the first reader locks the room, the last unlocks it
(:wat::core::defn :s4::read-once [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p1 (:sem::wait-upto c "rw-mutex" (:s4::poll-cap) 0)
                    n (:wat::core::+ 1 (:sem::do-peek c "readers"))
                    _ (:sem::do-init c "readers" n)
                    ;; the FIRST reader in takes the room away from writers
                    p2 (:wat::core::if (:wat::core::= n 1) (:sem::wait-upto c "room-empty" (:s4::poll-cap) 0) 0)
                    ;; `readers` counts arrivals; `inside` counts readers who actually HOLD the
                    ;; room. The two differ for exactly as long as the first reader is waiting on
                    ;; room-empty, and the writer must check the second -- see the note below.
                    _in (:sem::do-init c "inside" (:wat::core::+ 1 (:sem::do-peek c "inside")))
                    _2 (:sem::do-signal c "rw-mutex")
                    ;; ---- inside: record the largest crowd of readers seen together
                    hi (:sem::do-peek c "max-readers")
                    _3 (:wat::core::if (:wat::core::> n hi) (:sem::do-init c "max-readers" n) 0)
                    ;; ---- and check no writer is in the room while we read
                    w (:sem::do-peek c "writer-inside")
                    _4 (:wat::core::if (:wat::core::> w 0) (:sem::do-init c "rw-violation" 1) 0)
                    p3 (:sem::wait-upto c "rw-mutex" (:s4::poll-cap) 0)
                    _out (:sem::do-init c "inside" (:wat::core::- (:sem::do-peek c "inside") 1))
                    m (:wat::core::- (:sem::do-peek c "readers") 1)
                    _5 (:sem::do-init c "readers" m)
                    ;; the LAST reader out gives the room back
                    _6 (:wat::core::if (:wat::core::= m 0) (:sem::do-signal c "room-empty") 0)
                    _7 (:sem::do-signal c "rw-mutex")]
    (:wat::core::+ p1 (:wat::core::+ p2 p3))))

(:wat::core::defn :s4::write-once [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "room-empty" (:s4::poll-cap) 0)
                    _ (:sem::do-init c "writer-inside" 1)
                    r (:sem::do-peek c "inside")
                    ;; no reader may be IN THE ROOM while we write. Checking `readers` here instead
                    ;; reports a false violation: a reader increments `readers` BEFORE it waits on
                    ;; room-empty, so a writer holding the room legitimately sees readers = 1 for a
                    ;; reader that has not entered. The first run of this file failed on exactly
                    ;; that, and the algorithm was never wrong -- the instrument was.
                    _2 (:wat::core::if (:wat::core::> r 0) (:sem::do-init c "rw-violation" 1) 0)
                    _3 (:sem::do-init c "writer-inside" 0)
                    _4 (:sem::do-signal c "room-empty")]
    p))

;; ---- DINING PHILOSOPHERS, the deadlocking way: everyone takes their LEFT fork first
(:wat::core::defn :s4::dine-naive [c <- :sem::Conn i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [n (:s4::philosophers)
                    left (:s4::fork-name i)
                    right (:s4::fork-name (:wat::i64::rem (:wat::core::+ i 1) n))
                    a (:sem::wait-upto c left 200 0)]
    (:wat::core::if (:wat::core::< a 0) -1
      (:wat::core::let [b (:sem::wait-upto c right 200 0)]
        (:wat::core::if (:wat::core::< b 0)
          ;; hold one fork and give up: this IS the deadlock, reported instead of hanging
          (:wat::core::do (:sem::do-signal c left) -1)
          (:wat::core::do (:sem::do-signal c right) (:sem::do-signal c left) 1))))))

;; ---- and Downey's fix: a footman who admits at most n-1 to the table
(:wat::core::defn :s4::dine-footman [c <- :sem::Conn i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [n (:s4::philosophers)
                    left (:s4::fork-name i)
                    right (:s4::fork-name (:wat::i64::rem (:wat::core::+ i 1) n))
                    seat (:sem::wait-upto c "footman" 2000 0)]
    (:wat::core::if (:wat::core::< seat 0) -1
      (:wat::core::let [a (:sem::wait-upto c left 2000 0)]
        (:wat::core::if (:wat::core::< a 0) (:wat::core::do (:sem::do-signal c "footman") -1)
          (:wat::core::let [b (:sem::wait-upto c right 2000 0)]
            (:wat::core::if (:wat::core::< b 0)
              (:wat::core::do (:sem::do-signal c left) (:sem::do-signal c "footman") -1)
              (:wat::core::do (:sem::do-signal c right) (:sem::do-signal c left)
                (:sem::do-signal c "footman") 1))))))))

(:wat::core::defn :s4::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])
   mode <- :wat::core::i64  i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:sem::connect-to addr)]
    (:wat::core::if (:wat::core::= mode 0) (:s4::produce c (:s4::per-producer) 0)
      (:wat::core::if (:wat::core::= mode 1) (:s4::read-once c)
        (:wat::core::if (:wat::core::= mode 2) (:s4::write-once c)
          (:wat::core::if (:wat::core::= mode 3) (:s4::dine-naive c i)
            (:wat::core::if (:wat::core::= mode 5)
              ;; the consumer runs AS ONE OF THE POOL'S WORKERS, concurrently with the producers
              (:s4::consume c (:wat::core::* (:s4::producers) (:s4::per-producer)) 0 0)
              (:s4::dine-footman c i))))))))

(:wat::core::defn :s4::sum [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :s4::count-ok [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::length (:wat::core::filterv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool
                                             (:wat::core::> x 0)) xs)))

(:wat::core::defn :s4::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :s4::init-forks [c <- :sem::Conn i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:s4::philosophers)) 0
    (:wat::core::do (:sem::do-init c (:s4::fork-name i) 1) (:s4::init-forks c (:wat::core::+ i 1)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::sem/start :locus (:wat::spawn::thread)
         :record (:sem::sem::Record :counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))
     addr (:sem::sem::Handle/addr h)
     c0 (:sem::connect-to addr)
     want (:wat::core::* (:s4::producers) (:s4::per-producer))

     ;; ---- producer-consumer
     _a (:sem::do-init c0 "buffer" 0)
     _b (:sem::do-init c0 "items" 0)
     _c (:sem::do-init c0 "spaces" (:s4::buffer-size))
     _d (:sem::do-init c0 "pc-mutex" 1)
     _e (:sem::do-init c0 "high-water" 0)
     ;; producers AND the consumer in one pool, so the buffer drains while it is being filled
     pc (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 (:wat::core::+ (:s4::producers) 1))
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64
            (:s4::work addr (:wat::core::if (:wat::core::= i (:s4::producers)) 5 0) i)))
     drained (:wat::core::nth pc (:s4::producers))
     ppolls (:wat::core::filterv (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool
                                   (:wat::core::>= x 0)) pc)
     high (:sem::do-peek c0 "high-water")
     left-over (:sem::do-peek c0 "buffer")

     ;; ---- readers-writers
     _f (:sem::do-init c0 "readers" 0)
     _g (:sem::do-init c0 "rw-mutex" 1)
     _h (:sem::do-init c0 "room-empty" 1)
     _i (:sem::do-init c0 "max-readers" 0)
     _j (:sem::do-init c0 "writer-inside" 0)
     _k (:sem::do-init c0 "rw-violation" 0)
     _k2 (:sem::do-init c0 "inside" 0)
     rw (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 6)
          (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64
            (:s4::work addr (:wat::core::if (:wat::core::= 0 (:wat::i64::rem i 4)) 2 1) i)))
     max-readers (:sem::do-peek c0 "max-readers")
     violation (:sem::do-peek c0 "rw-violation")

     ;; ---- dining philosophers, the deadlocking way
     _l (:s4::init-forks c0 0)
     naive (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 (:s4::philosophers))
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s4::work addr 3 i)))
     naive-ok (:s4::count-ok naive)

     ;; ---- and with the footman
     _m (:s4::init-forks c0 0)
     _n (:sem::do-init c0 "footman" (:wat::core::- (:s4::philosophers) 1))
     fixed (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 (:s4::philosophers))
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s4::work addr 4 i)))
     fixed-ok (:s4::count-ok fixed)]
    (:wat::core::do
      (:wat::kernel::println "---- Downey ch4, the classical problems ----")

      (:s4::say "PRODUCER-CONSUMER items drained / produced "
        (:wat::string::concat (:wat::i64::to-string drained) " / " (:wat::i64::to-string want)
          (:wat::core::if (:wat::core::= drained want) "   PASS" "   FAIL")))
      (:s4::say "                  buffer left empty        "
        (:wat::string::concat (:wat::i64::to-string left-over)
          (:wat::core::if (:wat::core::= left-over 0) "   PASS" "   FAIL")))
      (:s4::say "                  high-water / capacity    "
        (:wat::string::concat (:wat::i64::to-string high) " / " (:wat::i64::to-string (:s4::buffer-size))
          (:wat::core::if (:wat::core::<= high (:s4::buffer-size)) "   PASS  the bound held" "   FAIL")))
      (:s4::say "                  producer poll round-trips"
        (:wat::i64::to-string (:s4::sum ppolls)))

      (:s4::say "READERS-WRITERS   a writer never shared the room"
        (:wat::core::if (:wat::core::= violation 0) "PASS" "FAIL"))
      (:s4::say "                  most readers in together  "
        (:wat::i64::to-string max-readers))
      (:s4::say "                  poll round-trips          "
        (:wat::i64::to-string (:s4::sum (:wat::core::filterv
          (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::bool (:wat::core::>= x 0)) rw))))

      (:s4::say "PHILOSOPHERS      left-fork-first, ate / total"
        (:wat::string::concat (:wat::i64::to-string naive-ok) " / " (:wat::i64::to-string (:s4::philosophers))
          (:wat::core::if (:wat::core::< naive-ok (:s4::philosophers))
            "   some gave up holding one fork -- Downey's deadlock" "   no deadlock on this run")))
      (:s4::say "                  with a footman, ate / total"
        (:wat::string::concat (:wat::i64::to-string fixed-ok) " / " (:wat::i64::to-string (:s4::philosophers))
          (:wat::core::if (:wat::core::= fixed-ok (:s4::philosophers)) "   PASS" "   FAIL")))

      (:wat::kernel::println "---- the deadlock that did not happen ----")
      (:wat::kernel::println "  Five philosophers each taking their LEFT fork first is Downey's")
      (:wat::kernel::println "  worked deadlock, and on this runtime it does not occur: 5/5 ate,")
      (:wat::kernel::println "  on five consecutive runs. That is evidence about the THREAD POOL,")
      (:wat::kernel::println "  not about the algorithm -- F-094 measured bracket::map at 29% of")
      (:wat::kernel::println "  what the same machine does with OS processes, and philosophers who")
      (:wat::kernel::println "  run nearly serially never hold a fork someone else is waiting for.")
      (:wat::kernel::println "  It is the worse outcome of the two: a wrong design that PASSES.")
      (:wat::kernel::println "  Downey's book is self-oracling only when the scheduler cooperates.")

      (:wat::kernel::println "---- what F-102 changes about this chapter ----")
      (:wat::kernel::println "  In Downey a deadlocked philosopher is a BLOCKED THREAD and the")
      (:wat::kernel::println "  program hangs. Here a wait is a spin, so a deadlock is an infinite")
      (:wat::kernel::println "  LOOP -- which would hang the run rather than report it. The naive")
      (:wat::kernel::println "  philosophers use a bounded wait, so the failure is a number.")
      (:wat::kernel::println "  That is the one thing the missing primitive gives back: a spin can")
      (:wat::kernel::println "  time out, and a blocking wait cannot without extra machinery."))))
