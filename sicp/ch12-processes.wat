;; SICP §1.2 (the processes procedures generate), in wat.
;;
;; The section's claim is that two procedures computing the SAME function can generate different
;; PROCESSES: linear recursion accumulates a chain of deferred operations, linear iteration keeps
;; its state in the arguments and needs constant space. In Scheme that difference is invisible
;; from the answers -- both give 3628800 -- and SICP asks you to believe the shape.
;;
;; In wat you can SEE it, because wat has a ceiling to hit. F-099: a non-tail recursion segfaults
;; with an empty stderr, while TCO makes tail recursion unbounded. So the two factorials below are
;; not two styles, they are two different programs at depth:
;;
;;     fact-rec    ok at 100000, SEGFAULT at 200000   (rc 139)
;;     fact-iter   ok at 100000, ok at 200000, ok at 10000000
;;
;; measured by probes/sicp/process-shape-depth.wat, each rung its own process. That is SICP §1.2.1
;; stated as a fact about the machine rather than as a diagram.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch12-processes.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch12-processes.wat

(:wat::load-file! "lib/check.wat")

;; ---- linear recursion: a chain of deferred multiplications
(:wat::core::defn :sicp::fact-rec [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 1 (:wat::core::* n (:sicp::fact-rec (:wat::core::- n 1)))))

;; ---- linear iteration: the same function, state in the arguments, constant space
(:wat::core::defn :sicp::fact-iter-inner
  [product <- :wat::core::i64 counter <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> counter n) product
    (:sicp::fact-iter-inner (:wat::core::* counter product) (:wat::core::+ counter 1) n)))

(:wat::core::defn :sicp::fact-iter [n <- :wat::core::i64] -> :wat::core::i64
  (:sicp::fact-iter-inner 1 1 n))

;; ---- tree recursion
(:wat::core::defn :sicp::fib-tree [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 2) n
    (:wat::core::+ (:sicp::fib-tree (:wat::core::- n 1)) (:sicp::fib-tree (:wat::core::- n 2)))))

(:wat::core::defn :sicp::fib-iter-inner
  [a <- :wat::core::i64 b <- :wat::core::i64 count <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= count 0) b
    (:sicp::fib-iter-inner (:wat::core::+ a b) a (:wat::core::- count 1))))

(:wat::core::defn :sicp::fib-iter [n <- :wat::core::i64] -> :wat::core::i64
  (:sicp::fib-iter-inner 1 0 n))

;; the tree has 2*fib(n+1)-1 nodes, which is the section's argument against it
(:wat::core::defn :sicp::fib-calls [n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< n 2) 1
    (:wat::core::+ 1 (:wat::core::+ (:sicp::fib-calls (:wat::core::- n 1))
                                    (:sicp::fib-calls (:wat::core::- n 2))))))

;; ---- exponentiation: linear against logarithmic
(:wat::core::defn :sicp::expt-lin [b <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 1 (:wat::core::* b (:sicp::expt-lin b (:wat::core::- n 1)))))

(:wat::core::defn :sicp::even-int? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 0 (:wat::i64::rem n 2)))

(:wat::core::defn :sicp::fast-expt [b <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0) 1
    (:wat::core::if (:sicp::even-int? n)
      (:wat::core::let [h (:sicp::fast-expt b (:wat::i64::quot n 2))] (:wat::core::* h h))
      (:wat::core::* b (:sicp::fast-expt b (:wat::core::- n 1))))))

;; ---- Euclid's gcd
(:wat::core::defn :sicp::my-gcd [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= b 0) a (:sicp::my-gcd b (:wat::i64::rem a b))))

;; ---- primality by trial division, O(sqrt n)
(:wat::core::defn :sicp::divides? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 0 (:wat::i64::rem b a)))

(:wat::core::defn :sicp::find-divisor [n <- :wat::core::i64 test <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> (:wat::core::* test test) n) n
    (:wat::core::if (:sicp::divides? test n) test
      (:sicp::find-divisor n (:wat::core::+ test 1)))))

(:wat::core::defn :sicp::smallest-divisor [n <- :wat::core::i64] -> :wat::core::i64
  (:sicp::find-divisor n 2))

(:wat::core::defn :sicp::prime? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::> n 1) (:wat::core::= n (:sicp::smallest-divisor n))))

;; ---- the Fermat test
(:wat::core::defn :sicp::square-int [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))

(:wat::core::defn :sicp::expmod
  [base <- :wat::core::i64 exp <- :wat::core::i64 m <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= exp 0) 1
    (:wat::core::if (:sicp::even-int? exp)
      (:wat::i64::rem (:sicp::square-int (:sicp::expmod base (:wat::i64::quot exp 2) m)) m)
      (:wat::i64::rem (:wat::core::* base (:sicp::expmod base (:wat::core::- exp 1) m)) m))))

(:wat::core::defn :sicp::fermat-holds? [a <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= (:sicp::expmod a n n) (:wat::i64::rem a n)))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::show-items [xs <- (:wat::core::Vector :- [:wat::core::i64])] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    candidates (:wat::core::Vector :- [:wat::core::i64] 2 3 4 5 6 7 8 9 10 11 12 13)]
    (:sicp::check-chapter "oracle/sicp/ch12-processes.expected"
                          "sicp ch12 processes"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:sicp::fact-rec 10))
                            (int (:sicp::fact-iter 10))
                            (:sicp::b (:wat::core::= (:sicp::fact-rec 20) (:sicp::fact-iter 20)))
                            (int (:sicp::fact-iter 20))
                            (int (:sicp::fib-tree 10))
                            (int (:sicp::fib-iter 10))
                            (:sicp::b (:wat::core::= (:sicp::fib-tree 20) (:sicp::fib-iter 20)))
                            (int (:sicp::fib-iter 60))
                            (int (:sicp::fib-calls 10))
                            (:sicp::b (:wat::core::= (:sicp::fib-calls 10)
                                        (:wat::core::- (:wat::core::* 2 (:sicp::fib-iter 11)) 1)))
                            (int (:sicp::expt-lin 2 10))
                            (int (:sicp::fast-expt 2 10))
                            (:sicp::b (:wat::core::= (:sicp::expt-lin 3 15) (:sicp::fast-expt 3 15)))
                            (int (:sicp::fast-expt 2 62))
                            (int (:sicp::my-gcd 206 40))
                            (int (:sicp::my-gcd 1071 462))
                            (int (:sicp::smallest-divisor 199))
                            (int (:sicp::smallest-divisor 1999))
                            (int (:sicp::smallest-divisor 19999))
                            (:sicp::b (:sicp::prime? 199))
                            (:sicp::b (:sicp::prime? 19999))
                            (:sicp::show-items (:wat::core::filterv :sicp::prime? candidates))
                            (:sicp::b (:sicp::fermat-holds? 2 199))
                            (:sicp::b (:sicp::fermat-holds? 3 199))
                            (:sicp::b (:sicp::fermat-holds? 2 19999))
                            (:sicp::b (:sicp::prime? 561))
                            (:sicp::b (:sicp::fermat-holds? 2 561))))))
