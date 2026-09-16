;; bench/dispatch.wat — what one call costs.
;;
;; This is the number a byte-code / jump-DAG change moves most: the cost of getting from a call
;; site to the callee and back. Five shapes, each against the same empty-loop control:
;;
;;   user-fn     a :user:: defn of one argument
;;   builtin     a :wat::core:: intrinsic (i64::+)
;;   closure     an inline fn value, called through a binding
;;   match       a two-arm match on an Option
;;   record-get  a defrecord accessor
;;
;; Run: wat bench/dispatch.wat

(:wat::load-file! "lib/timer.wat")

(:wat::core::defn :d::n [] -> :wat::core::i64 20000)

(:wat::core::defrecord :d::Box [v <- :wat::core::i64])

(:wat::core::defn :d::id [x <- :wat::core::i64] -> :wat::core::i64 x)

(:wat::core::defn :d::loop-userfn [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::id n) (:d::loop-userfn (:wat::core::- n 1)))))

(:wat::core::defn :d::loop-builtin [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:wat::i64::+ n 1) (:d::loop-builtin (:wat::core::- n 1)))))

(:wat::core::defn :d::loop-closure [n <- :wat::core::i64 f <- [:wat::core::i64 :-> :wat::core::i64]] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (f n) (f n) (f n) (f n) (f n) (f n) (f n) (f n) (f n) (f n) (:d::loop-closure (:wat::core::- n 1) f))))

(:wat::core::defn :d::loop-match [n <- :wat::core::i64 o <- (:wat::core::Option :- [:wat::core::i64])] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:wat::core::match o
        [:wat::core::Option.Some {:value v} v]
        [:wat::core::Option.None {} 0])
      (:d::loop-match (:wat::core::- n 1) o))))

(:wat::core::defn :d::loop-record [n <- :wat::core::i64 b <- :d::Box] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 0
    (:wat::core::do (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::Box/v b) (:d::loop-record (:wat::core::- n 1) b))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [n  (:d::n)
     b0 (:bench::now)  _b (:bench::empty-loop n)              base (:bench::ns-since b0)
     t1 (:bench::now)  _1 (:d::loop-userfn n)                 e1 (:bench::ns-since t1)
     t2 (:bench::now)  _2 (:d::loop-builtin n)                e2 (:bench::ns-since t2)
     t3 (:bench::now)  _3 (:d::loop-closure n (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::i64 x)) e3 (:bench::ns-since t3)
     t4 (:bench::now)  _4 (:d::loop-match n (:wat::core::Option.Some {:value 1})) e4 (:bench::ns-since t4)
     t5 (:bench::now)  _5 (:d::loop-record n (:d::Box :v 1))  e5 (:bench::ns-since t5)]
    (:wat::core::do
      (:bench::row "dispatch/user-fn"   n e1 base)
      (:bench::row "dispatch/builtin"   n e2 base)
      (:bench::row "dispatch/closure"   n e3 base)
      (:bench::row "dispatch/match-2"   n e4 base)
      (:bench::row "dispatch/record-get" n e5 base))))
