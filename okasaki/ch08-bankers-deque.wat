;; okasaki/ch08-bankers-deque.wat — Chapter 8, lazy rebuilding: a structure with NO cheap end.
;;
;; Chapters 5-7 all have an easy direction — the rotation only ever moves rear into front, so a
;; spike can only appear on one side. A deque has no such asymmetry, so the technique generalises:
;; keep the halves within a factor c of each other and, when one outgrows the other, split it and
;; reverse the remainder onto the other side. Laziness makes that split incremental rather than a
;; stop-the-world rebuild.
;;
;; Three things are checked here, and the third is the chapter's point:
;;   1. it behaves as a queue (snoc + head/tail) and as a stack (cons + head/tail)
;;   2. the balance invariant lenf <= c*lenr+1 and lenr <= c*lenf+1 holds after EVERY operation
;;   3. the worst single operation is bounded at BOTH ends -- a one-sided structure would show a
;;      spike on whichever side the rebuild lands
;;
;; SKELETON FOR P-027: every cell of both halves is a `:wat::cache::Lru`, so the absolute numbers
;; are mostly the stand-in. The shape is the result.
;;
;; Run: wat okasaki/ch08-bankers-deque.wat

(:wat::load-file! "lib/deque.wat")

(:wat::core::defn :c8::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c8::n [] -> :wat::core::i64 300)
(:wat::core::defn :c8::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))
(:wat::core::defn :c8::mx [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

(:wat::core::defenum :c8::A :wat::enum::Impure
  :A [q <- :ok::DQ.D  mx <- :wat::core::i64  bad <- :wat::core::i64  unbal <- :wat::core::i64])

(:wat::core::defn :c8::start [] -> :c8::A.A
  (:c8::A.A {:q (:ok::dq-empty) :mx 0 :bad 0 :unbal 0}))

;; --- 1. as a QUEUE: snoc 0..n-1, drain from the front, expect 0..n-1 ------------------------
(:wat::core::defn :c8::queue-order [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
        (:wat::core::match a
          [:c8::A.A {:q q :mx m :bad b :unbal u}
            (:c8::A.A {:q (:ok::dq-tail q) :mx m
                       :bad (:wat::core::if (:wat::core::= (:ok::dq-head q) i) b (:wat::core::+ b 1))
                       :unbal u})]))
      (:wat::core::foldl
        (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
          (:wat::core::match a
            [:c8::A.A {:q q :mx m :bad b :unbal u} (:c8::A.A {:q (:ok::dq-snoc q i) :mx m :bad b :unbal u})]))
        (:c8::start) (:wat::core::range 0 n))
      (:wat::core::range 0 n))
    [:c8::A.A {:q q :mx m :bad b :unbal u} b]))

;; --- 2. as a STACK: cons 0..n-1, drain from the front, expect n-1..0 -------------------------
(:wat::core::defn :c8::stack-order [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match
    (:wat::core::foldl
      (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
        (:wat::core::match a
          [:c8::A.A {:q q :mx m :bad b :unbal u}
            (:wat::core::let [want (:wat::core::- (:wat::core::- n 1) i)]
              (:c8::A.A {:q (:ok::dq-tail q) :mx m
                         :bad (:wat::core::if (:wat::core::= (:ok::dq-head q) want) b (:wat::core::+ b 1))
                         :unbal u}))]))
      (:wat::core::foldl
        (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
          (:wat::core::match a
            [:c8::A.A {:q q :mx m :bad b :unbal u} (:c8::A.A {:q (:ok::dq-cons q i) :mx m :bad b :unbal u})]))
        (:c8::start) (:wat::core::range 0 n))
      (:wat::core::range 0 n))
    [:c8::A.A {:q q :mx m :bad b :unbal u} b]))

;; --- 3. BOTH ENDS: alternate cons/snoc to build, alternate tail/init to drain, time every op --
(:wat::core::defn :c8::both-ends [n <- :wat::core::i64] -> :c8::A.A
  (:wat::core::let
    [built (:wat::core::foldl
             (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
               (:wat::core::match a
                 [:c8::A.A {:q q :mx m :bad b :unbal u}
                   (:wat::core::let
                     [t0 (:c8::now)
                      q2 (:wat::core::if (:wat::core::= (:wat::core::rem i 2) 0)
                           (:ok::dq-cons q i) (:ok::dq-snoc q i))
                      dt (:wat::core::- (:c8::now) t0)]
                     (:c8::A.A {:q q2 :mx (:c8::mx m dt) :bad b
                                :unbal (:wat::core::if (:ok::dq-balanced? q2) u (:wat::core::+ u 1))}))]))
             (:c8::start) (:wat::core::range 0 n))]
    (:wat::core::foldl
      (:wat::core::fn [a <- :c8::A.A i <- :wat::core::i64] -> :c8::A.A
        (:wat::core::match a
          [:c8::A.A {:q q :mx m :bad b :unbal u}
            (:wat::core::let
              [t0 (:c8::now)
               q2 (:wat::core::if (:wat::core::= (:wat::core::rem i 2) 0)
                    (:ok::dq-tail q) (:ok::dq-init q))
               dt (:wat::core::- (:c8::now) t0)]
              (:c8::A.A {:q q2 :mx (:c8::mx m dt) :bad b
                         :unbal (:wat::core::if (:ok::dq-balanced? q2) u (:wat::core::+ u 1))}))]))
      built (:wat::core::range 0 n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [n (:c8::n) be (:c8::both-ends n)]
    (:wat::core::match be
      [:c8::A.A {:q q :mx m :bad b :unbal u}
        (:wat::core::do
          (:c8::say "as a QUEUE (snoc, drain front)"
            (:wat::core::if (:wat::core::= (:c8::queue-order n) 0) "PASS" "FAIL"))
          (:c8::say "as a STACK (cons, drain front)"
            (:wat::core::if (:wat::core::= (:c8::stack-order n) 0) "PASS" "FAIL"))
          (:c8::say "balance invariant, every op "
            (:wat::core::if (:wat::core::= u 0) "PASS" "FAIL"))
          (:c8::say "worst single op, BOTH ends  "
            (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
              (:wat::i64::to-string (:wat::core::/ m 1000)) " us"))))])))
