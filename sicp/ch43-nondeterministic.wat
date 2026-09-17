;; SICP §4.3 (nondeterministic computing), in wat.
;;
;; `amb` chooses, and a later `require` that fails BACKTRACKS to the next choice. The machinery is
;; two continuations: a SUCCESS continuation, taking a value and a way to ask for another, and a
;; FAILURE continuation, meaning there are no more. `amb` hands each choice to success paired with
;; a failure that moves on; `require` calls failure when its condition is false. That is the whole
;; of it, and it is why the section is really about continuations rather than about search.
;;
;; This is the first thing in this repository to need BOTH continuations at once. EOPL ch5 (C-061)
;; reified one continuation as data and drove it from a loop; C-065's exception handler was a
;; second kind of frame on that one chain. Here the two are independent, and they have to be
;; carried as ordinary closures, which means the types are the interesting part:
;;
;;     Fail    = [:-> Out]                 -- no more answers
;;     Succeed = [NVal Fail :-> Out]       -- here is one, and here is how to ask again
;;     Comp    = [Succeed Fail :-> Out]    -- a nondeterministic computation
;;
;; Those three mutually referring function types are exactly the shape a typed language is
;; supposed to make painful, and wat takes them without ceremony -- including the ZERO-ARGUMENT
;; function type `[:-> Out]`, which is the one piece of syntax most easily missed.
;;
;; The answer type has to be FIXED, though, and that is the real cost. In Scheme `first-of`
;; answers a value and `all-of` answers a list, from the same computation. Here both must answer
;; the same `Out`, so `Out` is a three-variant enum and the two runners pick different variants.
;; A polymorphic answer type would need the computation to be generic in it, which is F-029
;; territory.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch43-nondeterministic.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch43-nondeterministic.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))

;; a choice is a number, or a tuple of numbers built by `unit`
(:wat::core::defenum :sicp::NVal :wat::enum::Pure
  :N [n <- :wat::core::i64]
  :L [xs <- :sicp::Ints])

(:wat::core::defenum :sicp::Out :wat::enum::Pure
  :One  [v <- :sicp::NVal]
  :Many [vs <- (:wat::core::Vector :- [:sicp::NVal])]
  :Nil  [])

(:wat::core::typealias :sicp::Fail [:-> :sicp::Out])
(:wat::core::typealias :sicp::Succeed [:sicp::NVal :sicp::Fail :-> :sicp::Out])
(:wat::core::typealias :sicp::Comp [:sicp::Succeed :sicp::Fail :-> :sicp::Out])

;; ---- the two primitives
(:wat::core::defn :sicp::unit [x <- :sicp::NVal] -> :sicp::Comp
  (:wat::core::fn [succeed <- :sicp::Succeed fail <- :sicp::Fail] -> :sicp::Out (succeed x fail)))

;; try the choices in order; each success carries a failure that moves to the next
(:wat::core::defn :sicp::try-choices
  [cs <- :sicp::Ints i <- :wat::core::i64 succeed <- :sicp::Succeed fail <- :sicp::Fail] -> :sicp::Out
  (:wat::core::if (:wat::core::>= i (:wat::core::length cs)) (fail)
    (succeed (:sicp::NVal.N {:n (:wat::core::nth cs i)})
      (:wat::core::fn [] -> :sicp::Out (:sicp::try-choices cs (:wat::core::+ i 1) succeed fail)))))

(:wat::core::defn :sicp::amb-of [cs <- :sicp::Ints] -> :sicp::Comp
  (:wat::core::fn [succeed <- :sicp::Succeed fail <- :sicp::Fail] -> :sicp::Out
    (:sicp::try-choices cs 0 succeed fail)))

;; sequencing: run m, and for each value it yields, run (f value) with the SAME retry
(:wat::core::defn :sicp::bind [m <- :sicp::Comp f <- [:sicp::NVal :-> :sicp::Comp]] -> :sicp::Comp
  (:wat::core::fn [succeed <- :sicp::Succeed fail <- :sicp::Fail] -> :sicp::Out
    (m (:wat::core::fn [v <- :sicp::NVal retry <- :sicp::Fail] -> :sicp::Out
         ((f v) succeed retry))
       fail)))

;; require: a value that fails the test simply calls the failure continuation
(:wat::core::defn :sicp::require-that [ok? <- [:sicp::NVal :-> :wat::core::bool] m <- :sicp::Comp] -> :sicp::Comp
  (:sicp::bind m
    (:wat::core::fn [v <- :sicp::NVal] -> :sicp::Comp
      (:wat::core::fn [succeed <- :sicp::Succeed fail <- :sicp::Fail] -> :sicp::Out
        (:wat::core::if (ok? v) (succeed v fail) (fail))))))

;; ---- the two runners: the first answer, and every answer
(:wat::core::defn :sicp::first-of [m <- :sicp::Comp] -> :sicp::Out
  (m (:wat::core::fn [v <- :sicp::NVal retry <- :sicp::Fail] -> :sicp::Out (:sicp::Out.One {:v v}))
     (:wat::core::fn [] -> :sicp::Out (:sicp::Out.Nil {}))))

(:wat::core::defn :sicp::prepend [v <- :sicp::NVal o <- :sicp::Out] -> :sicp::Out
  (:wat::core::match o
    [:sicp::Out.Many {:vs vs}
      (:sicp::Out.Many {:vs (:wat::core::concat (:wat::core::Vector :- [:sicp::NVal] v) vs)})]
    [:sicp::Out.One {:v v2} (:sicp::Out.Many {:vs (:wat::core::Vector :- [:sicp::NVal] v v2)})]
    [:sicp::Out.Nil {} (:sicp::Out.Many {:vs (:wat::core::Vector :- [:sicp::NVal] v)})]))

;; asking `retry` for the rest is what turns one answer into all of them
(:wat::core::defn :sicp::all-of [m <- :sicp::Comp] -> :sicp::Out
  (m (:wat::core::fn [v <- :sicp::NVal retry <- :sicp::Fail] -> :sicp::Out (:sicp::prepend v (retry)))
     (:wat::core::fn [] -> :sicp::Out (:sicp::Out.Many {:vs (:wat::core::Vector :- [:sicp::NVal])}))))

;; ---- helpers for the searches
(:wat::core::defn :sicp::iota-from [lo <- :wat::core::i64 hi <- :wat::core::i64] -> :sicp::Ints
  (:wat::core::if (:wat::core::> lo hi) (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] lo)
      (:sicp::iota-from (:wat::core::+ lo 1) hi))))

(:wat::core::defn :sicp::nv [v <- :sicp::NVal] -> :wat::core::i64
  (:wat::core::match v
    [:sicp::NVal.N {:n n} n]
    [:sicp::NVal.L {:xs xs} 0]))

(:wat::core::defn :sicp::even-nv? [v <- :sicp::NVal] -> :wat::core::bool
  (:wat::core::= 0 (:wat::i64::rem (:sicp::nv v) 2)))

;; two ambs with a requirement between them -- the backtracking search
(:wat::core::defn :sicp::pairs-summing-to [n <- :wat::core::i64 lo <- :wat::core::i64 hi <- :wat::core::i64] -> :sicp::Out
  (:sicp::all-of
    (:sicp::bind (:sicp::amb-of (:sicp::iota-from lo hi))
      (:wat::core::fn [a <- :sicp::NVal] -> :sicp::Comp
        (:sicp::bind
          (:sicp::require-that
            (:wat::core::fn [b <- :sicp::NVal] -> :wat::core::bool
              (:wat::core::= n (:wat::core::+ (:sicp::nv a) (:sicp::nv b))))
            (:sicp::amb-of (:sicp::iota-from lo hi)))
          (:wat::core::fn [b <- :sicp::NVal] -> :sicp::Comp
            (:sicp::unit (:sicp::NVal.L {:xs (:wat::core::Vector :- [:wat::core::i64]
                                               (:sicp::nv a) (:sicp::nv b))}))))))))

(:wat::core::defn :sicp::triples [n <- :wat::core::i64] -> :sicp::Out
  (:sicp::all-of
    (:sicp::bind (:sicp::amb-of (:sicp::iota-from 1 n))
      (:wat::core::fn [a <- :sicp::NVal] -> :sicp::Comp
        (:sicp::bind (:sicp::amb-of (:sicp::iota-from (:sicp::nv a) n))
          (:wat::core::fn [b <- :sicp::NVal] -> :sicp::Comp
            (:sicp::bind
              (:sicp::require-that
                (:wat::core::fn [c <- :sicp::NVal] -> :wat::core::bool
                  (:wat::core::= (:wat::core::* (:sicp::nv c) (:sicp::nv c))
                    (:wat::core::+ (:wat::core::* (:sicp::nv a) (:sicp::nv a))
                                   (:wat::core::* (:sicp::nv b) (:sicp::nv b)))))
                (:sicp::amb-of (:sicp::iota-from (:sicp::nv b) n)))
              (:wat::core::fn [c <- :sicp::NVal] -> :sicp::Comp
                (:sicp::unit (:sicp::NVal.L {:xs (:wat::core::Vector :- [:wat::core::i64]
                                                   (:sicp::nv a) (:sicp::nv b) (:sicp::nv c))}))))))))))

;; ---- printing, as the Scheme oracle prints ('none is a symbol, so it prints bare)
(:wat::core::defn :sicp::show-ints [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :sicp::show-nval [v <- :sicp::NVal] -> :wat::core::String
  (:wat::core::match v
    [:sicp::NVal.N {:n n} (:wat::i64::to-string n)]
    [:sicp::NVal.L {:xs xs} (:sicp::show-ints xs)]))

(:wat::core::defn :sicp::show-out [o <- :sicp::Out] -> :wat::core::String
  (:wat::core::match o
    [:sicp::Out.One {:v v} (:sicp::show-nval v)]
    [:sicp::Out.Nil {} "none"]
    [:sicp::Out.Many {:vs vs}
      (:wat::string::concat "(" (:wat::string::join " " (:wat::core::mapv :sicp::show-nval vs)) ")")]))

(:wat::core::defn :sicp::out-length [o <- :sicp::Out] -> :wat::core::i64
  (:wat::core::match o
    [:sicp::Out.Many {:vs vs} (:wat::core::length vs)]
    [:sicp::Out.One {:v v} 1]
    [:sicp::Out.Nil {} 0]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    none-ints (:wat::core::Vector :- [:wat::core::i64])
                    one23 (:wat::core::Vector :- [:wat::core::i64] 1 2 3)
                    odds (:wat::core::Vector :- [:wat::core::i64] 1 3 5)
                    six (:sicp::iota-from 1 6)]
    (:sicp::check-chapter "oracle/sicp/ch43-nondeterministic.expected"
                          "sicp ch43 nondeterministic"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-out (:sicp::first-of (:sicp::unit (:sicp::NVal.N {:n 5}))))
                            (:sicp::show-out (:sicp::all-of (:sicp::amb-of one23)))
                            (:sicp::show-out (:sicp::first-of (:sicp::amb-of one23)))
                            (:sicp::show-out (:sicp::all-of (:sicp::amb-of none-ints)))
                            (:sicp::show-out (:sicp::first-of (:sicp::amb-of none-ints)))
                            (:sicp::show-out (:sicp::all-of (:sicp::require-that :sicp::even-nv? (:sicp::amb-of six))))
                            (:sicp::show-out (:sicp::first-of (:sicp::require-that :sicp::even-nv? (:sicp::amb-of odds))))
                            (:sicp::show-out (:sicp::pairs-summing-to 5 1 4))
                            (:sicp::show-out (:sicp::pairs-summing-to 8 1 4))
                            (int (:sicp::out-length (:sicp::pairs-summing-to 5 1 4)))
                            (:sicp::show-out (:sicp::triples 20))
                            (int (:sicp::out-length (:sicp::triples 20)))
                            (:sicp::show-out
                              (:sicp::all-of
                                (:sicp::bind (:sicp::amb-of (:wat::core::Vector :- [:wat::core::i64] 1 2))
                                  (:wat::core::fn [a <- :sicp::NVal] -> :sicp::Comp
                                    (:sicp::bind (:sicp::amb-of (:wat::core::Vector :- [:wat::core::i64] 10 20))
                                      (:wat::core::fn [b <- :sicp::NVal] -> :sicp::Comp
                                        (:sicp::unit (:sicp::NVal.L {:xs (:wat::core::Vector :- [:wat::core::i64]
                                                                           (:sicp::nv a) (:sicp::nv b))}))))))))))))
