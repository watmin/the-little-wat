;; okasaki/ch07-realtime-queue.wat — amortized is not the same as worst-case, and this measures it.
;;
;; Chapter 6 pays the rotation once, but it pays it ALL AT ONCE, on whichever unlucky operation
;; forces it. Chapter 7 spreads that work across the operations that caused it by forcing one
;; schedule cell per call, so no single call is slow. Averages cannot tell those apart; the
;; MAXIMUM single-operation time can, and that is what this file reports.
;;
;; Both queues are driven identically: n snocs then n tails, timing EVERY operation and keeping
;; the largest.
;;
;; SKELETON FOR P-027. The lazy list is one `:wat::cache::Lru` per cons cell (lib/llist.wat), so
;; the absolute numbers here are mostly the stand-in and are not worth quoting. What survives the
;; substitution is the SHAPE: a bounded worst case against a spike.
;;
;; Run: wat okasaki/ch07-realtime-queue.wat

(:wat::load-file! "lib/realtime.wat")
(:wat::load-file! "lib/bankers.wat")

(:wat::core::defn :c7::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c7::n [] -> :wat::core::i64 300)
(:wat::core::defn :c7::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))
(:wat::core::defn :c7::mx [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> a b) a b))

;; --- real-time queue: max single op over n snocs then n tails -------------------------------
(:wat::core::defenum :c7::R :wat::enum::Impure :R [q <- :ok::RTQ.Q  mx <- :wat::core::i64  bad <- :wat::core::i64])

(:wat::core::defn :c7::rt-run [n <- :wat::core::i64] -> :c7::R.R
  (:wat::core::let
    [filled (:wat::core::foldl
              (:wat::core::fn [a <- :c7::R.R i <- :wat::core::i64] -> :c7::R.R
                (:wat::core::match a
                  [:c7::R.R {:q q :mx m :bad b}
                    (:wat::core::let [t0 (:c7::now) q2 (:ok::rtq-snoc q i) dt (:wat::core::- (:c7::now) t0)]
                      (:c7::R.R {:q q2 :mx (:c7::mx m dt) :bad b}))]))
              (:c7::R.R {:q (:ok::rtq-empty) :mx 0 :bad 0}) (:wat::core::range 0 n))]
    (:wat::core::foldl
      (:wat::core::fn [a <- :c7::R.R i <- :wat::core::i64] -> :c7::R.R
        (:wat::core::match a
          [:c7::R.R {:q q :mx m :bad b}
            (:wat::core::let [t0 (:c7::now)
                              h (:ok::rtq-head q)
                              q2 (:ok::rtq-tail q)
                              dt (:wat::core::- (:c7::now) t0)]
              (:c7::R.R {:q q2 :mx (:c7::mx m dt)
                         :bad (:wat::core::if (:wat::core::= h i) b (:wat::core::+ b 1))}))]))
      filled (:wat::core::range 0 n))))

;; --- banker's queue: the same drive ----------------------------------------------------------
(:wat::core::defenum :c7::B :wat::enum::Impure :B [q <- :ok::BQ.Q  mx <- :wat::core::i64  bad <- :wat::core::i64])

(:wat::core::defn :c7::bq-run [n <- :wat::core::i64] -> :c7::B.B
  (:wat::core::let
    [filled (:wat::core::foldl
              (:wat::core::fn [a <- :c7::B.B i <- :wat::core::i64] -> :c7::B.B
                (:wat::core::match a
                  [:c7::B.B {:q q :mx m :bad b}
                    (:wat::core::let [t0 (:c7::now) q2 (:ok::bq-snoc q i) dt (:wat::core::- (:c7::now) t0)]
                      (:c7::B.B {:q q2 :mx (:c7::mx m dt) :bad b}))]))
              (:c7::B.B {:q (:ok::bq-empty) :mx 0 :bad 0}) (:wat::core::range 0 n))]
    (:wat::core::foldl
      (:wat::core::fn [a <- :c7::B.B i <- :wat::core::i64] -> :c7::B.B
        (:wat::core::match a
          [:c7::B.B {:q q :mx m :bad b}
            (:wat::core::let [t0 (:c7::now)
                              h (:ok::bq-head q)
                              q2 (:ok::bq-tail q)
                              dt (:wat::core::- (:c7::now) t0)]
              (:c7::B.B {:q q2 :mx (:c7::mx m dt)
                         :bad (:wat::core::if (:wat::core::= h i) b (:wat::core::+ b 1))}))]))
      filled (:wat::core::range 0 n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n (:c7::n)
     r (:c7::rt-run n)
     b (:c7::bq-run n)]
    (:wat::core::do
      (:wat::core::match r
        [:c7::R.R {:q q :mx rm :bad rb}
          (:wat::core::match b
            [:c7::B.B {:q q2 :mx bm :bad bb}
              (:wat::core::do
                (:c7::say "real-time FIFO over 300 " (:wat::core::if (:wat::core::= rb 0) "PASS" "FAIL"))
                (:c7::say "banker's  FIFO over 300 " (:wat::core::if (:wat::core::= bb 0) "PASS" "FAIL"))
                (:wat::kernel::println "---- WORST-CASE single operation (us) ----")
                (:c7::say "  banker's  (ch6, amortized) " (:wat::i64::to-string (:wat::core::/ bm 1000)))
                (:c7::say "  real-time (ch7, worst-case)" (:wat::i64::to-string (:wat::core::/ rm 1000)))
                (:c7::say "  ratio (banker's / real-time)"
                  (:wat::i64::to-string (:wat::core::/ bm (:c7::mx rm 1)))))])]))))
