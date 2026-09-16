;; SICP §3.5 (streams), in wat.
;;
;; A stream's rest is delayed, so an endless sequence can be described and only as much of it
;; computed as is asked for. wat has that: (:wat::stream::lazy body) captures a body unevaluated,
;; :wat::stream::cons puts a value in front of one, and :wat::stream::next forces one step. So
;; the book's stream operations are written here with no library behind them.
;;
;; The book defines fibs by referring to the stream being defined; here it is a function of its
;; two seeds (probes/sicp/self-referential-stream.wat asks whether the book's way is possible),
;; and the Scheme oracle describes it the same way, so the two agree on how, not only on what.
;; What a forced stream remembers is measured in probes/sicp/stream-memo.wat.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch35-streams.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch35-streams.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :sicp::IntStream (:wat::stream::Stream :- [:wat::core::i64]))

;; ---- the stream operations

(:wat::core::defn :sicp::integers-from [n <- :wat::core::i64] -> :sicp::IntStream
  (:wat::stream::cons n (:wat::stream::lazy (:sicp::integers-from (:wat::core::+ n 1)))))

(:wat::core::defn :sicp::head [s <- :sicp::IntStream n <- :wat::core::i64 acc <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} acc]
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:sicp::head r (:wat::core::- n 1) (:wat::core::conj acc v))])))

(:wat::core::defn :sicp::sref [s <- :sicp::IntStream n <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::match (:wat::stream::next s)
    [:wat::stream::NextOutcome.Exhausted {} (:wat::kernel::assertion-failed! :message "stream-ref: past the end")]
    [:wat::stream::NextOutcome.Item {:value v :rest r}
      (:wat::core::if (:wat::core::= n 0) v (:sicp::sref r (:wat::core::- n 1)))]))

(:wat::core::defn :sicp::smap [f <- [:wat::core::i64 :-> :wat::core::i64] s <- :sicp::IntStream] -> :sicp::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value v :rest r} (:wat::stream::cons (f v) (:sicp::smap f r))])))

(:wat::core::defn :sicp::sfilter [keep? <- [:wat::core::i64 :-> :wat::core::bool] s <- :sicp::IntStream] -> :sicp::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value v :rest r}
        (:wat::core::if (keep? v)
          (:wat::stream::cons v (:sicp::sfilter keep? r))
          (:sicp::sfilter keep? r))])))

(:wat::core::defn :sicp::smap2 [f <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64] a <- :sicp::IntStream b <- :sicp::IntStream] -> :sicp::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next a)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value x :rest ra}
        (:wat::core::match (:wat::stream::next b)
          [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
          [:wat::stream::NextOutcome.Item {:value y :rest rb} (:wat::stream::cons (f x y) (:sicp::smap2 f ra rb))])])))

;; ---- what the streams hold

(:wat::core::defn :sicp::divisible? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 0 (:wat::i64::rem a b)))

(:wat::core::defn :sicp::sieve [s <- :sicp::IntStream] -> :sicp::IntStream
  (:wat::stream::lazy
    (:wat::core::match (:wat::stream::next s)
      [:wat::stream::NextOutcome.Exhausted {} (:wat::stream::empty)]
      [:wat::stream::NextOutcome.Item {:value p :rest r}
        (:wat::stream::cons p
          (:sicp::sieve (:sicp::sfilter (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::bool
                                          (:wat::core::not (:sicp::divisible? n p)))
                                        r)))])))

(:wat::core::defn :sicp::fibs-from [a <- :wat::core::i64 b <- :wat::core::i64] -> :sicp::IntStream
  (:wat::stream::cons a (:wat::stream::lazy (:sicp::fibs-from b (:wat::core::+ a b)))))

(:wat::core::defn :sicp::square [n <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* n n))
(:wat::core::defn :sicp::even? [n <- :wat::core::i64] -> :wat::core::bool (:wat::core::= 0 (:wat::i64::rem n 2)))
(:wat::core::defn :sicp::plus [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))

;; ---- printing, as the Scheme oracle prints

(:wat::core::defn :sicp::show-items [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [none (:wat::core::Vector :- [:wat::core::i64])
                    integers (:sicp::integers-from 1)
                    primes (:sicp::sieve (:sicp::integers-from 2))
                    fibs (:sicp::fibs-from 0 1)
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:sicp::check-chapter "oracle/sicp/ch35-streams.expected"
                          "sicp ch35 streams"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-items (:sicp::head integers 5 none))
                            (int (:sicp::sref integers 99))
                            (:sicp::show-items (:sicp::head (:sicp::smap :sicp::square integers) 5 none))
                            (:sicp::show-items (:sicp::head (:sicp::sfilter :sicp::even? integers) 5 none))
                            (:sicp::show-items (:sicp::head primes 8 none))
                            (int (:sicp::sref (:sicp::sieve (:sicp::integers-from 2)) 20))
                            (:sicp::show-items (:sicp::head fibs 10 none))
                            (int (:sicp::sref (:sicp::fibs-from 0 1) 30))
                            (:sicp::show-items (:sicp::head (:sicp::smap2 :sicp::plus integers integers) 5 none))))))
