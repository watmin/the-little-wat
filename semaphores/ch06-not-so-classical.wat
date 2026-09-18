;; semaphores/ch06-not-so-classical.wat — Downey chapter 6's "not-so-classical" problems.
;;
;;   SEARCH-INSERT-DELETE  searchers run together; inserters exclude each other but not searchers;
;;                         a deleter excludes everyone. Three categories, three different rules.
;;   UNISEX BATHROOM       men and women never inside together, and never more than three at once.
;;   BABOON CROSSING       a rope crossed one way at a time, at most five on it.
;;   MODUS HALL            the same shape with two named groups, kept separate — included because
;;                         the book includes it, and because "the same shape" is a claim worth
;;                         checking rather than asserting.
;;
;; Chapter 6 is where the book stops introducing primitives and starts combining them, so these
;; are all compositions of the counting semaphore in lib/sem.wat. That redundancy IS the coverage
;; argument: the book's thesis is that one primitive suffices, and only running all of them tests
;; it.
;;
;; Run: wat semaphores/ch06-not-so-classical.wat

(:wat::load-file! "lib/sem.wat")

(:wat::core::defn :s6::cap [] -> :wat::core::i64 5000)

;; ---- SEARCH-INSERT-DELETE
;;
;; Two wrong versions preceded this one, and both are worth recording because they failed in
;; different ways and the check caught both.
;;
;;   FIRST: every searcher took `no-deleter` and released it immediately, so a deleter could enter
;;   while a searcher was inside. The fix is Downey's LIGHTSWITCH -- the first of a group through
;;   the door locks, the last one out unlocks -- the same shape readers-writers uses in ch4.
;;
;;   SECOND: with the lightswitch, but searchers and inserters sharing ONE semaphore. They then
;;   exclude EACH OTHER, which the puzzle does not ask for, and the loser spun until `wait-upto`
;;   gave up and -- because the return was ignored -- walked into the critical section anyway.
;;   Downey uses TWO semaphores, `noSearcher` and `noInserter`, one lightswitch each, and the
;;   deleter takes both. Searchers and inserters never contend.
;;
;; The second bug is the one worth carrying out of this file: **a bounded wait that is not checked
;; is worse than no wait at all.** `wait-upto` answers -1 when it gives up, and ignoring that turns
;; a timeout into a silent mutual-exclusion violation. A blocking `wait` cannot be misused this way
;; because it has no failure to ignore -- so the workaround F-102 forces carries a hazard the
;; primitive it replaces does not have.
(:wat::core::defn :s6::switch-lock
  [c <- :sem::Conn tag <- :wat::core::String sem <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [mx (:wat::string::concat tag "-switch-mutex")
                    cnt (:wat::string::concat tag "-switch-count")
                    p (:sem::wait-upto c mx (:s6::cap) 0)
                    n (:wat::core::+ 1 (:sem::do-peek c cnt))
                    _ (:sem::do-init c cnt n)
                    p2 (:wat::core::if (:wat::core::= n 1) (:sem::wait-upto c sem (:s6::cap) 0) 0)
                    ;; a wait that GAVE UP must be reported, not walked past
                    _g (:wat::core::if (:wat::core::< p2 0) (:sem::do-init c "sid-gaveup" 1) 0)
                    _2 (:sem::do-signal c mx)]
    (:wat::core::+ p (:wat::core::if (:wat::core::< p2 0) 0 p2))))

(:wat::core::defn :s6::switch-unlock
  [c <- :sem::Conn tag <- :wat::core::String sem <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [mx (:wat::string::concat tag "-switch-mutex")
                    cnt (:wat::string::concat tag "-switch-count")
                    p (:sem::wait-upto c mx (:s6::cap) 0)
                    n (:wat::core::- (:sem::do-peek c cnt) 1)
                    _ (:sem::do-init c cnt n)
                    _2 (:wat::core::if (:wat::core::= n 0) (:sem::do-signal c sem) 0)
                    _3 (:sem::do-signal c mx)]
    p))

;; searchers run together, excluded only by a deleter
;; NOTE. The `searchers` counter is bumped UNDER `sid-mutex`, and the first version of this file
;; was not. That version failed consistently -- the deleter saw 1 or 2 searchers while holding
;; `no-searcher`, which looks exactly like a mutual-exclusion bug and is not one. `peek` then
;; `init` is a read-modify-write across TWO service rounds, so a lost DECREMENT leaves the counter
;; permanently above zero and every later deleter sees a searcher who has gone home.
;;
;; That is **C-094 in the wild, in my own instrument.** The thing C-094 measured deliberately --
;; a service round is atomic, a program is not -- reappeared here by accident, in the harness
;; rather than in the code under test, and presented as a false violation of the property being
;; tested. It is the best argument in this repository for why that finding matters: the hazard is
;; invisible until something counts, and what it corrupts first is the counting.
(:wat::core::defn :s6::searcher [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:s6::switch-lock c "search" "no-searcher")
                    pm (:sem::wait-upto c "sid-mutex" (:s6::cap) 0)
                    _ (:sem::do-init c "searchers" (:wat::core::+ 1 (:sem::do-peek c "searchers")))
                    _m (:sem::do-signal c "sid-mutex")
                    d (:sem::do-peek c "deleter-in")
                    _2 (:wat::core::if (:wat::core::> d 0) (:sem::do-init c "v-search-saw-del" 1) 0)
                    pm2 (:sem::wait-upto c "sid-mutex" (:s6::cap) 0)
                    _3 (:sem::do-init c "searchers" (:wat::core::- (:sem::do-peek c "searchers") 1))
                    _m2 (:sem::do-signal c "sid-mutex")
                    p2 (:s6::switch-unlock c "search" "no-searcher")]
    (:wat::core::+ p (:wat::core::+ pm (:wat::core::+ pm2 p2)))))

;; inserters exclude each other, and a deleter, but never a searcher
(:wat::core::defn :s6::inserter [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:s6::switch-lock c "insert" "no-inserter")
                    p2 (:sem::wait-upto c "insert-mutex" (:s6::cap) 0)
                    ;; safe without sid-mutex: this whole block is inside `insert-mutex`
                    n (:wat::core::+ 1 (:sem::do-peek c "inserters"))
                    _ (:sem::do-init c "inserters" n)
                    _2 (:wat::core::if (:wat::core::> n 1) (:sem::do-init c "v-two-inserters" 1) 0)
                    d (:sem::do-peek c "deleter-in")
                    _3 (:wat::core::if (:wat::core::> d 0) (:sem::do-init c "v-insert-saw-del" 1) 0)
                    _4 (:sem::do-init c "inserters" (:wat::core::- (:sem::do-peek c "inserters") 1))
                    _5 (:sem::do-signal c "insert-mutex")
                    p3 (:s6::switch-unlock c "insert" "no-inserter")]
    (:wat::core::+ p (:wat::core::+ p2 p3))))

;; a deleter takes BOTH, so it excludes everyone
(:wat::core::defn :s6::deleter [c <- :sem::Conn] -> :wat::core::i64
  (:wat::core::let [p (:sem::wait-upto c "no-searcher" (:s6::cap) 0)
                    p2 (:sem::wait-upto c "no-inserter" (:s6::cap) 0)
                    _g (:wat::core::if (:wat::core::or (:wat::core::< p 0) (:wat::core::< p2 0))
                         (:sem::do-init c "sid-gaveup" 1) 0)
                    _ (:sem::do-init c "deleter-in" 1)
                    sc (:sem::do-peek c "searchers")
                    ic (:sem::do-peek c "inserters")
                    _2 (:wat::core::if (:wat::core::> (:wat::core::+ sc ic) 0)
                         (:wat::core::do (:sem::do-init c "v-del-saw-others" 1)
                           (:sem::do-init c "v-del-saw-s" sc) (:sem::do-init c "v-del-saw-i" ic)) 0)
                    _3 (:sem::do-init c "deleter-in" 0)
                    _4 (:sem::do-signal c "no-inserter")
                    _5 (:sem::do-signal c "no-searcher")]
    (:wat::core::+ (:wat::core::if (:wat::core::< p 0) 0 p)
                   (:wat::core::if (:wat::core::< p2 0) 0 p2))))

;; ---- a two-group exclusion, used by the bathroom, the rope and the hall
;; kind 0 and kind 1 may never be inside together, and at most `limit` may be inside at once.
(:wat::core::defn :s6::enter-group
  [c <- :sem::Conn tag <- :wat::core::String kind <- :wat::core::i64 limit <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [mx (:wat::string::concat tag "-mutex")
                    inside (:wat::string::concat tag "-inside")
                    who (:wat::string::concat tag "-kind")
                    hi (:wat::string::concat tag "-high")
                    bad (:wat::string::concat tag "-violation")
                    p (:sem::wait-upto c mx (:s6::cap) 0)
                    n (:sem::do-peek c inside)
                    cur (:sem::do-peek c who)]
    ;; admitted only if the room is empty, or already holds our own kind and has space
    (:wat::core::if (:wat::core::or (:wat::core::= n 0)
                      (:wat::core::and (:wat::core::= cur kind) (:wat::core::< n limit)))
      (:wat::core::let [_ (:sem::do-init c inside (:wat::core::+ n 1))
                        _2 (:sem::do-init c who kind)
                        h (:sem::do-peek c hi)
                        _3 (:wat::core::if (:wat::core::> (:wat::core::+ n 1) h)
                             (:sem::do-init c hi (:wat::core::+ n 1)) 0)
                        ;; two kinds inside at once, or more than the limit, are the failures
                        _4 (:wat::core::if (:wat::core::> (:wat::core::+ n 1) limit)
                             (:sem::do-init c bad 1) 0)
                        _5 (:sem::do-signal c mx)
                        ;; ... inside ...
                        p2 (:sem::wait-upto c mx (:s6::cap) 0)
                        _6 (:wat::core::if (:wat::core::not (:wat::core::= (:sem::do-peek c who) kind))
                             (:sem::do-init c bad 1) 0)
                        _7 (:sem::do-init c inside (:wat::core::- (:sem::do-peek c inside) 1))
                        _8 (:sem::do-init c (:wat::string::concat tag "-through")
                             (:wat::core::+ 1 (:sem::do-peek c (:wat::string::concat tag "-through"))))
                        _9 (:sem::do-signal c mx)]
        (:wat::core::+ p p2))
      ;; turned away this time; the book allows a retry, and the count is what matters
      (:wat::core::do (:sem::do-init c (:wat::string::concat tag "-refused")
                        (:wat::core::+ 1 (:sem::do-peek c (:wat::string::concat tag "-refused"))))
        (:sem::do-signal c mx) p))))

(:wat::core::defn :s6::work :- [T]
  [addr <- (:wat::kernel::Address :- [(:sem::Sem::Op :- []) (:sem::Sem::Reply :- []) :T])
   mode <- :wat::core::i64  i <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [c (:sem::connect-to addr)]
    (:wat::core::if (:wat::core::= mode 0)
      ;; a mix: two searchers, one inserter, one deleter in every four
      (:wat::core::let [r (:wat::i64::rem i 4)]
        (:wat::core::if (:wat::core::< r 2) (:s6::searcher c)
          (:wat::core::if (:wat::core::= r 2) (:s6::inserter c) (:s6::deleter c))))
      (:wat::core::if (:wat::core::= mode 1) (:s6::enter-group c "bath" (:wat::i64::rem i 2) 3)
        (:wat::core::if (:wat::core::= mode 2) (:s6::enter-group c "rope" (:wat::i64::rem i 2) 5)
          (:s6::enter-group c "hall" (:wat::i64::rem i 2) 4))))))

(:wat::core::defn :s6::sum [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                       (:wat::core::+ a b)) 0 xs))

(:wat::core::defn :s6::say [label <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " v)))

(:wat::core::defn :s6::ok [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "PASS" "FAIL"))

(:wat::core::defn :s6::init-group [c <- :sem::Conn tag <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:sem::do-init c (:wat::string::concat tag "-mutex") 1)
    (:sem::do-init c (:wat::string::concat tag "-inside") 0)
    (:sem::do-init c (:wat::string::concat tag "-kind") 0)
    (:sem::do-init c (:wat::string::concat tag "-high") 0)
    (:sem::do-init c (:wat::string::concat tag "-violation") 0)
    (:sem::do-init c (:wat::string::concat tag "-through") 0)
    (:sem::do-init c (:wat::string::concat tag "-refused") 0)))

(:wat::core::defn :s6::report [c <- :sem::Conn name <- :wat::core::String tag <- :wat::core::String
                               limit <- :wat::core::i64 polls <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::do
    (:s6::say (:wat::string::concat name " most inside / limit      ")
      (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c (:wat::string::concat tag "-high")))
        " / " (:wat::i64::to-string limit) "   "
        (:s6::ok (:wat::core::<= (:sem::do-peek c (:wat::string::concat tag "-high")) limit))))
    (:s6::say (:wat::string::concat name " the two kinds never mixed")
      (:s6::ok (:wat::core::= 0 (:sem::do-peek c (:wat::string::concat tag "-violation")))))
    (:s6::say (:wat::string::concat name " through / turned away    ")
      (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c (:wat::string::concat tag "-through")))
        " / " (:wat::i64::to-string (:sem::do-peek c (:wat::string::concat tag "-refused")))))
    (:s6::say (:wat::string::concat name " poll round-trips         ") (:wat::i64::to-string polls))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [h (:sem::sem/start :locus (:wat::spawn::thread)
         :record (:sem::sem::Record :counts (:wat::core::PersistentMap :- [:wat::core::String :wat::core::i64])))
     addr (:sem::sem::Handle/addr h)
     c0 (:sem::connect-to addr)

     ;; ---- search-insert-delete
     _a (:sem::do-init c0 "sid-mutex" 1)
     _b (:sem::do-init c0 "insert-mutex" 1)
     _c (:sem::do-init c0 "no-searcher" 1)
     _c2 (:sem::do-init c0 "no-inserter" 1)
     _c3 (:sem::do-init c0 "sid-gaveup" 0)
     _c4 (:sem::do-init c0 "v-search-saw-del" 0)
     _c5 (:sem::do-init c0 "v-two-inserters" 0)
     _c6 (:sem::do-init c0 "v-insert-saw-del" 0)
     _c7 (:sem::do-init c0 "v-del-saw-others" 0)
     _c8 (:sem::do-init c0 "v-del-saw-s" 0)
     _c9 (:sem::do-init c0 "v-del-saw-i" 0)
     _d (:sem::do-init c0 "searchers" 0)
     _e (:sem::do-init c0 "inserters" 0)
     _f (:sem::do-init c0 "deleter-in" 0)
     _g (:sem::do-init c0 "sid-violation" 0)
     _g2 (:sem::do-init c0 "search-switch-mutex" 1)
     _g3 (:sem::do-init c0 "search-switch-count" 0)
     _g4 (:sem::do-init c0 "insert-switch-mutex" 1)
     _g5 (:sem::do-init c0 "insert-switch-count" 0)
     sidp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
            (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s6::work addr 0 i)))
     sidv (:wat::core::+ (:sem::do-peek c0 "v-search-saw-del")
            (:wat::core::+ (:sem::do-peek c0 "v-two-inserters")
              (:wat::core::+ (:sem::do-peek c0 "v-insert-saw-del")
                             (:sem::do-peek c0 "v-del-saw-others"))))
     sidg (:sem::do-peek c0 "sid-gaveup")

     _h (:s6::init-group c0 "bath")
     bathp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 10)
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s6::work addr 1 i)))
     _i (:s6::init-group c0 "rope")
     ropep (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 12)
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s6::work addr 2 i)))
     _j (:s6::init-group c0 "hall")
     hallp (:wat::bracket::map (:wat::spawn::thread) (:wat::core::range 0 10)
             (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 (:s6::work addr 3 i)))]
    (:wat::core::do
      (:wat::kernel::println "---- Downey ch6, the not-so-classical problems ----")
      (:s6::say "SEARCH-INSERT-DELETE  all three rules held"
        (:s6::ok (:wat::core::= sidv 0)))
      (:s6::say "                      no wait timed out    "
        (:s6::ok (:wat::core::= sidg 0)))
      (:s6::say "                      searcher saw deleter "
        (:wat::i64::to-string (:sem::do-peek c0 "v-search-saw-del")))
      (:s6::say "                      two inserters at once"
        (:wat::i64::to-string (:sem::do-peek c0 "v-two-inserters")))
      (:s6::say "                      inserter saw deleter "
        (:wat::i64::to-string (:sem::do-peek c0 "v-insert-saw-del")))
      (:s6::say "                      deleter saw s / i    "
        (:wat::string::concat (:wat::i64::to-string (:sem::do-peek c0 "v-del-saw-s")) " / "
          (:wat::i64::to-string (:sem::do-peek c0 "v-del-saw-i"))))
      (:s6::say "                      poll round-trips     " (:wat::i64::to-string (:s6::sum sidp)))
      (:s6::report c0 "BATHROOM " "bath" 3 (:s6::sum bathp))
      (:s6::report c0 "ROPE     " "rope" 5 (:s6::sum ropep))
      (:s6::report c0 "HALL     " "hall" 4 (:s6::sum hallp))
      (:wat::kernel::println "---- the three exclusions are ONE function ----")
      (:wat::kernel::println "  The bathroom, the rope and the hall differ only in their limit and")
      (:wat::kernel::println "  their names, so they run through one `enter-group`. Downey presents")
      (:wat::kernel::println "  them as three puzzles because the READER has to find that; the port")
      (:wat::kernel::println "  can say it, having checked all three against the same code."))))
