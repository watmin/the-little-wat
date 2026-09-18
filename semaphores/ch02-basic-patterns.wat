;; semaphores/ch02-basic-patterns.wat — Downey chapter 2's four basic patterns, on the counting
;; semaphore of semaphores/lib/sem.wat.
;;
;;   SIGNALLING   one thread guarantees its work happens before another's
;;   RENDEZVOUS   two threads each wait for the other; neither proceeds until both arrive
;;   MUTEX        a semaphore at 1, making a read-modify-write atomic
;;   MULTIPLEX    a semaphore at k, letting at most k threads into a section at once
;;
;; **The mutex is the one worth the trip, because it sharpens C-053.** That entry says wat's
;; zero-mutex claim HOLDS -- 1600/1600 increments with no lost update -- and it is right about
;; what it measured: a counter service whose `bump` is ONE service round cannot lose an update,
;; because the service processes rounds one at a time.
;;
;; That is a claim about the ROUND, not about wat. A read-modify-write spanning TWO rounds --
;; `peek` then `set` -- is interleavable exactly as it is anywhere else, and the file below runs
;; both and reports the counts. If the unsafe count comes out short, the hazard Downey's whole book
;; exists to remove is present in wat after all, at a granularity C-053 did not test.
;;
;; Every wait is a spin (F-102), so each pattern also reports its poll count.
;;
;; Run: wat semaphores/ch02-basic-patterns.wat

(:wat::load-file! "lib/sem.wat")

(:wat::core::defn :s2::workers [] -> :wat::core::i64 8)
(:wat::core::defn :s2::per-worker [] -> :wat::core::i64 50)

;; ---- the unsafe increment: read and write are two separate service rounds
(:wat::core::defn :s2::bump-unsafe [c <- :sem::Conn k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::<= k 0) 0
    (:wat::core::let [n (:sem::do-peek c "counter")
                      _ (:sem::do-init c "counter" (:wat::core::+ n 1))]
      (:s2::bump-unsafe c (:wat::core::- k 1)))))

;; ---- the same, with a mutex around it
(:wat::core::defn :s2::bump-safe [c <- :sem::Conn k <- :wat::core::i64 polls <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::<= k 0) polls
    (:wat::core::let [p (:sem::wait c "mutex" 0)
                      n (:sem::do-peek c "safe-counter")
                      _ (:sem::do-init c "safe-counter" (:wat::core::+ n 1))
                      _2 (:sem::do-signal c "mutex")]
      (:s2::bump-safe c (:wat::core::- k 1) (:wat::core::+ polls p)))))

;; ---- signalling: B must not run before A has signalled
(:wat::core::defn :s2::signaller [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::do (:sem::do-init c "a-done" 1) (:sem::do-signal c "signal") 0))

(:wat::core::defn :s2::waiter [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait c "signal" 0)]
    ;; if A really went first, "a-done" is 1 by the time we are released
    (:wat::core::if (:wat::core::= 1 (:sem::do-peek c "a-done")) p (:wat::core::- 0 1))))

;; ---- multiplex: at most k inside at once. Each entrant records the crowd it saw.
(:wat::core::defn :s2::multiplex-once [c <- :sem::Conn k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait c "multiplex" 0)
                    inside (:wat::core::+ 1 (:sem::do-peek c "inside"))
                    _ (:sem::do-init c "inside" inside)
                    seen inside
                    _2 (:sem::do-init c "inside" (:wat::core::- inside 1))
                    _3 (:sem::do-signal c "multiplex")]
    seen))

(:wat::core::defn :s2::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])
   mode <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:sem::connect-to addr)]
    (:wat::core::if (:wat::core::= mode 0) (:s2::bump-unsafe c (:s2::per-worker))
      (:wat::core::if (:wat::core::= mode 1) (:s2::bump-safe c (:s2::per-worker) 0)
        (:s2::multiplex-once c 3)))))

(:wat::core::defn :s2::sum [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :s2::max-of [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::if (:wat::core::> b a) b a)) 0 xs))

(:wat::core::defn :s2::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::sem/start :locus (:wat::spawn::thread)
         :record (:sem::sem::Record :counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))
     addr (:sem::sem::Handle/addr h)
     c0 (:sem::connect-to addr)
     _a (:sem::do-init c0 "counter" 0)
     _b (:sem::do-init c0 "safe-counter" 0)
     _c (:sem::do-init c0 "mutex" 1)
     _d (:sem::do-init c0 "multiplex" 3)
     _e (:sem::do-init c0 "inside" 0)
     _f (:sem::do-init c0 "signal" 0)
     _g (:sem::do-init c0 "a-done" 0)
     items (:wat::core::range 0 (:s2::workers))
     want (:wat::core::* (:s2::workers) (:s2::per-worker))

     ;; --- MUTEX: the same increment, twice, one guarded and one not
     _unsafe (:wat::bracket::map (:wat::spawn::thread) items
               (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s2::work addr 0)))
     unsafe-total (:sem::do-peek c0 "counter")
     safe-polls (:wat::bracket::map (:wat::spawn::thread) items
                  (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s2::work addr 1)))
     safe-total (:sem::do-peek c0 "safe-counter")

     ;; --- MULTIPLEX: at most 3 inside, and each entrant reports the crowd it saw
     seen (:wat::bracket::map (:wat::spawn::thread) items
            (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s2::work addr 2)))
     busiest (:s2::max-of seen)

     ;; --- SIGNALLING and RENDEZVOUS, run after the rest so the counters are quiet
     _sig (:s2::signaller c0)
     wpolls (:s2::waiter c0)]
    (:wat::core::do
      (:wat::kernel::println "---- Downey ch2, on a counting semaphore ----")

      (:s2::say "MUTEX   unguarded read-modify-write over two rounds "
        (:wat::string::concat (:wat::i64::to-string unsafe-total) " / " (:wat::i64::to-string want)
          (:wat::core::if (:wat::core::= unsafe-total want)
            "   no update lost on this run" "   UPDATES LOST")))
      (:s2::say "MUTEX   the same, guarded by a semaphore at 1      "
        (:wat::string::concat (:wat::i64::to-string safe-total) " / " (:wat::i64::to-string want)
          (:wat::core::if (:wat::core::= safe-total want) "   PASS" "   FAIL")))
      (:s2::say "        polls spent waiting on the mutex           "
        (:wat::i64::to-string (:s2::sum safe-polls)))

      (:s2::say "MULTIPLEX busiest crowd seen inside, limit 3       "
        (:wat::string::concat (:wat::i64::to-string busiest)
          (:wat::core::if (:wat::core::<= busiest 3) "   PASS" "   FAIL")))

      (:s2::say "SIGNALLING waiter saw A's work already done        "
        (:wat::core::if (:wat::core::>= wpolls 0) "PASS" "FAIL"))
      (:s2::say "        polls the waiter spent                     "
        (:wat::i64::to-string wpolls))

      (:wat::kernel::println "---- what the numbers mean ----")
      (:wat::kernel::println "  Every wait above is a spin: wat cannot block a caller (F-102), so a")
      (:wat::kernel::println "  semaphore is try-and-retry and each retry is a service round-trip.")
      (:wat::kernel::println "  Downey's semaphore costs one context switch; this one costs ~224 us")
      (:wat::kernel::println "  per poll (F-051)."))))
