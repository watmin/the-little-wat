;; okasaki/ch04-lazy-evaluation.wat — Okasaki chapter 4, LAZY EVALUATION.
;;
;; This chapter was the one omission inside a suite this repository had already reported as
;; complete. Found by the coverage audit of 2026-09-16, under the builder's no-skipping ruling.
;; The library was there -- okasaki/lib/llist.wat has take, drop, append and reverse -- but the
;; chapter that states and CHECKS their defining property was never written. Every later chapter's
;; header cites "ch 4 LAZINESS"; nothing had ever tested it.
;;
;; Chapter 4's content is one distinction, and the whole of Part II rests on it:
;;
;;   INCREMENTAL  a function whose every forcing does O(1) work and hands back another suspension.
;;                `++` and `take` are incremental.
;;   MONOLITHIC   a function whose FIRST forcing does all the work at once.
;;                `drop` and `reverse` are monolithic.
;;
;; Amortization by lazy evaluation only works when the expensive operation is incremental, because
;; the debt has to be payable a little at a time. That is why the banker's queue (ch 6) can defer
;; a rotation and why a monolithic `reverse` has to be paid for in advance.
;;
;; Measured here by OBSERVATION, not by clock: `:ok::forced?` reports whether a suspension has
;; been paid for, so "how much of the list did this touch?" is a count, and the same number on any
;; machine. It is also the third thing P-027's real primitive must expose, and this file is why.

(:wat::load-file! "lib/llist.wat")

(:wat::core::typealias :c4::L (:ok::Susp :- [:ok::LCell]))

;; A fresh [1 2 3 4 5], with EVERY cell's suspension handed back so it can be inspected.
;; Index 0 is the head of the list; index 5 is the nil at the end.
(:wat::core::defn :c4::build [] -> (:wat::core::Vector :- [:c4::L])
  (:wat::core::let [s6 (:ok::lnil)
                    s5 (:ok::lcons 5 s6)
                    s4 (:ok::lcons 4 s5)
                    s3 (:ok::lcons 3 s4)
                    s2 (:ok::lcons 2 s3)
                    s1 (:ok::lcons 1 s2)]
    (:wat::core::Vector :- [:c4::L] s1 s2 s3 s4 s5 s6)))

(:wat::core::defn :c4::count-forced
  [v <- (:wat::core::Vector :- [:c4::L]) i <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:c4::count-forced v (:wat::core::+ i 1)
      (:wat::core::if (:ok::forced? (:wat::core::nth v i)) (:wat::core::+ acc 1) acc))))

(:wat::core::defn :c4::forced [v <- (:wat::core::Vector :- [:c4::L])] -> :wat::core::i64
  (:c4::count-forced v 0 0))

(:wat::core::defn :c4::row
  [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label "  " (:wat::i64::to-string got) " of 6 cells forced"
      (:wat::core::if (:wat::core::= got want) "   PASS"
        (:wat::string::concat "   FAIL (want " (:wat::i64::to-string want) ")")))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "---- Okasaki ch4: INCREMENTAL vs MONOLITHIC ----")
    (:wat::kernel::println "  s = [1 2 3 4 5], built lazily; every cell is its own suspension.")

    ;; nothing is paid for until something asks
    (:wat::core::let [v (:c4::build)]
      (:c4::row "built, untouched              " (:c4::forced v) 0))

    (:wat::kernel::println "-- INCREMENTAL: one element out costs one cell --")
    ;; head of (s ++ t): `++` forces only as far as it must to produce one cons
    (:wat::core::let [v (:c4::build)
                      t (:ok::lcons 6 (:ok::lnil))
                      u (:ok::lappend (:wat::core::nth v 0) t)
                      h (:ok::lhead u)]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "  head(s ++ t) = " (:wat::i64::to-string h)))
        (:c4::row "  after head(s ++ t)         " (:c4::forced v) 1)))

    ;; take 2, then actually consume 2 -- still only what was consumed
    (:wat::core::let [v (:c4::build)
                      k (:ok::ltake (:wat::core::nth v 0) 2)
                      a (:ok::lhead k)
                      b (:ok::lhead (:ok::ltail k))]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "  take 2 consumed: "
          (:wat::i64::to-string a) " " (:wat::i64::to-string b)))
        (:c4::row "  after consuming 2 of take 2" (:c4::forced v) 2)))

    (:wat::kernel::println "-- MONOLITHIC: one element out costs the whole list --")
    ;; head of (drop s 3) -- the drop has to walk the prefix before it can answer anything
    (:wat::core::let [v (:c4::build)
                      d (:ok::ldrop (:wat::core::nth v 0) 3)
                      h (:ok::lhead d)]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "  head(drop s 3) = " (:wat::i64::to-string h)))
        (:c4::row "  after head(drop s 3)       " (:c4::forced v) 4)))

    ;; head of (reverse s) -- the last element, which cannot be known without all of them
    (:wat::core::let [v (:c4::build)
                      r (:ok::lrev (:wat::core::nth v 0))
                      h (:ok::lhead r)]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "  head(reverse s) = " (:wat::i64::to-string h)))
        (:c4::row "  after head(reverse s)      " (:c4::forced v) 6)))

    (:wat::kernel::println "-- SHARING: a second traversal pays nothing --")
    ;; this is the property :wat::stream:: deliberately does NOT have (F-100), and the reason
    ;; Okasaki's amortization needs a suspension rather than a stream
    (:wat::core::let [v (:c4::build)
                      n1 (:ok::llen (:wat::core::nth v 0))
                      after1 (:c4::forced v)
                      n2 (:ok::llen (:wat::core::nth v 0))
                      after2 (:c4::forced v)]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat "  length twice: "
          (:wat::i64::to-string n1) " then " (:wat::i64::to-string n2)))
        (:c4::row "  after first traversal      " after1 6)
        (:c4::row "  after second traversal     " after2 6)
        (:wat::kernel::println
          (:wat::core::if (:wat::core::= after1 after2)
            "  the second traversal forced NOTHING new   PASS"
            "  the second traversal re-forced cells      FAIL"))))

    (:wat::kernel::println "---- why this chapter is load-bearing ----")
    (:wat::kernel::println "  Amortization by laziness needs the expensive operation to be")
    (:wat::kernel::println "  INCREMENTAL, so the debt can be paid a little at a time. That is")
    (:wat::kernel::println "  why ch6's banker's queue may defer a rotation, and why a")
    (:wat::kernel::println "  MONOLITHIC reverse has to be paid for in advance.")
    (:wat::kernel::println "  Everything above rests on force-once-and-SHARED, which")
    (:wat::kernel::println "  :wat::stream:: deliberately does not do (F-100). P-027 is the ask.")))
