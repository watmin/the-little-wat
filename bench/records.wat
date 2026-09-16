;; bench/records.wat — what a field read costs, and the difference between the two aggregates.
;;
;; wat has two aggregate kinds: `defrecord` (may cross a boundary; EDN-serializable) and
;; `defstruct` (may not). They look identical at the call site -- `(:r::Box/v b)` either way --
;; and they do not cost the same.
;;
;; The control matters here: this loop passes the aggregate through every recursive call, so
;; "carry-only" measures that passing WITHOUT touching it. It comes out at or below the empty
;; loop, which is what licenses reading the rest as accessor cost.
;;
;; Run: wat bench/records.wat

(:wat::load-file! "lib/timer.wat")
(:wat::core::defrecord :r::Box [v <- :wat::core::i64])
(:wat::core::defstruct :r::SBox [v <- :wat::core::i64])
(:wat::core::defn :r::n [] -> :wat::core::i64 20000)
;; carries the record but never touches it -- the control for "is passing it the cost?"
(:wat::core::defn :r::carry [n <- :wat::core::i64 b <- :r::Box] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0 (:r::carry (:wat::core::- n 1) b)))
;; accesses it ten times per iteration
(:wat::core::defn :r::get [n <- :wat::core::i64 b <- :r::Box] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (:r::Box/v b) (:r::Box/v b) (:r::Box/v b) (:r::Box/v b) (:r::Box/v b)
                    (:r::Box/v b) (:r::Box/v b) (:r::Box/v b) (:r::Box/v b) (:r::Box/v b)
      (:r::get (:wat::core::- n 1) b))))
;; a defstruct accessor, for comparison
(:wat::core::defn :r::sget [n <- :wat::core::i64 b <- :r::SBox] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b)
                    (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b) (:r::SBox/v b)
      (:r::sget (:wat::core::- n 1) b))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n (:r::n) b (:r::Box :v 1) sb (:r::SBox :v 1)
     t0 (:bench::now) _0 (:bench::empty-loop n)  base (:bench::ns-since t0)
     t1 (:bench::now) _1 (:r::carry n b)         e1 (:bench::ns-since t1)
     t2 (:bench::now) _2 (:r::get n b)           e2 (:bench::ns-since t2)
     t3 (:bench::now) _3 (:r::sget n sb)         e3 (:bench::ns-since t3)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join " | " (:wat::core::Vector :- [:wat::core::String]
        "carry-only (no access), us" (:wat::i64::to-string (:wat::core::/ (:wat::core::- e1 base) 1000)))))
      (:bench::row "defrecord accessor" n e2 e1)
      (:bench::row "defstruct accessor" n e3 e1))))
