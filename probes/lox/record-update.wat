;; probes/lox/record-update.wat
;;
;; Q: what does it cost to change ONE field of a `defrecord`?
;;
;; Two ways exist. Restating every field in the constructor is the one this repository has
;; written everywhere, because it is the one the documentation shows. `:wat::core::assoc` also
;; takes a record -- it is not in the user guide's container table, and the reference line for
;; `assoc` calls it "polymorphic over HashMap/Vec" -- and answers the same nominal type.
;;
;; F-096 prices a `defrecord` accessor at 6130 ns, so restating a k-field record should cost k
;; reads plus a construct, and `assoc` one construct. This measures the difference at k = 2, 5
;; and 9, which brackets every record in lox/.
;;
;; Run: wat probes/lox/record-update.wat

(:wat::core::defn :p::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :p::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

(:wat::core::defrecord :p::R2 [i <- :wat::core::i64  a <- :wat::core::i64])
(:wat::core::defrecord :p::R5 [i <- :wat::core::i64  a <- :wat::core::i64  b <- :wat::core::i64
                               c <- :wat::core::i64  d <- :wat::core::i64])
(:wat::core::defrecord :p::R9 [i <- :wat::core::i64  a <- :wat::core::i64  b <- :wat::core::i64
                               c <- :wat::core::i64  d <- :wat::core::i64  e <- :wat::core::i64
                               f <- :wat::core::i64  g <- :wat::core::i64  h <- :wat::core::i64])

;; RESTATE: read every field, build a new record -- what lox/lib/scanner.wat's `advance` does
(:wat::core::defn :p::r2-restate [r <- :p::R2 k <- :wat::core::i64] -> :p::R2
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r2-restate (:p::R2 :i (:wat::core::+ (:p::R2/i r) 1) :a (:p::R2/a r)) (:wat::core::- k 1))))

(:wat::core::defn :p::r5-restate [r <- :p::R5 k <- :wat::core::i64] -> :p::R5
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r5-restate (:p::R5 :i (:wat::core::+ (:p::R5/i r) 1) :a (:p::R5/a r) :b (:p::R5/b r)
                            :c (:p::R5/c r) :d (:p::R5/d r)) (:wat::core::- k 1))))

(:wat::core::defn :p::r9-restate [r <- :p::R9 k <- :wat::core::i64] -> :p::R9
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r9-restate (:p::R9 :i (:wat::core::+ (:p::R9/i r) 1) :a (:p::R9/a r) :b (:p::R9/b r)
                            :c (:p::R9/c r) :d (:p::R9/d r) :e (:p::R9/e r) :f (:p::R9/f r)
                            :g (:p::R9/g r) :h (:p::R9/h r)) (:wat::core::- k 1))))

;; ASSOC: one read, one update
(:wat::core::defn :p::r2-assoc [r <- :p::R2 k <- :wat::core::i64] -> :p::R2
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r2-assoc (:wat::core::assoc r :i (:wat::core::+ (:p::R2/i r) 1)) (:wat::core::- k 1))))

(:wat::core::defn :p::r5-assoc [r <- :p::R5 k <- :wat::core::i64] -> :p::R5
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r5-assoc (:wat::core::assoc r :i (:wat::core::+ (:p::R5/i r) 1)) (:wat::core::- k 1))))

(:wat::core::defn :p::r9-assoc [r <- :p::R9 k <- :wat::core::i64] -> :p::R9
  (:wat::core::if (:wat::core::= k 0) r
    (:p::r9-assoc (:wat::core::assoc r :i (:wat::core::+ (:p::R9/i r) 1)) (:wat::core::- k 1))))

(:wat::core::defn :p::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:p::pad (:wat::string::concat s " ") n)))

(:wat::core::defn :p::report [label <- :wat::core::String restate <- :wat::core::i64
                              assoc <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat (:p::pad label 12)
      " restate " (:p::pad (:wat::i64::to-string (:wat::core::/ restate k)) 7) " ns/update"
      "   assoc " (:p::pad (:wat::i64::to-string (:wat::core::/ assoc k)) 7) " ns/update"
      "   restate is " (:wat::i64::to-string (:wat::core::/ (:wat::core::* restate 100) assoc)) "%")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [k 20000
     r2 (:p::R2 :i 0 :a 0)
     r5 (:p::R5 :i 0 :a 0 :b 0 :c 0 :d 0)
     r9 (:p::R9 :i 0 :a 0 :b 0 :c 0 :d 0 :e 0 :f 0 :g 0 :h 0)
     ;; warm each arm before any of them is timed
     w1 (:p::r2-assoc r2 200) w2 (:p::r2-restate r2 200)
     w3 (:p::r5-assoc r5 200) w4 (:p::r5-restate r5 200)
     w5 (:p::r9-assoc r9 200) w6 (:p::r9-restate r9 200)
     ;; interleaved, each arm twice, each taking first position once
     a0 (:p::now) x1 (:p::r2-assoc r2 k) a1 (:p::now)
     b0 (:p::now) y1 (:p::r2-restate r2 k) b1 (:p::now)
     c0 (:p::now) x2 (:p::r2-assoc r2 k) c1 (:p::now)
     d0 (:p::now) y2 (:p::r2-restate r2 k) d1 (:p::now)
     e0 (:p::now) x3 (:p::r5-assoc r5 k) e1 (:p::now)
     f0 (:p::now) y3 (:p::r5-restate r5 k) f1 (:p::now)
     g0 (:p::now) x4 (:p::r5-assoc r5 k) g1 (:p::now)
     h0 (:p::now) y4 (:p::r5-restate r5 k) h1 (:p::now)
     i0 (:p::now) x5 (:p::r9-assoc r9 k) i1 (:p::now)
     j0 (:p::now) y5 (:p::r9-restate r9 k) j1 (:p::now)
     l0 (:p::now) x6 (:p::r9-assoc r9 k) l1 (:p::now)
     m0 (:p::now) y6 (:p::r9-restate r9 k) m1 (:p::now)]
    (:wat::core::do
      (:wat::kernel::println "changing ONE field of a defrecord, 20000 times, min of 2, interleaved")
      (:p::report "2 fields"
        (:p::imin (:wat::core::- b1 b0) (:wat::core::- d1 d0))
        (:p::imin (:wat::core::- a1 a0) (:wat::core::- c1 c0)) k)
      (:p::report "5 fields"
        (:p::imin (:wat::core::- f1 f0) (:wat::core::- h1 h0))
        (:p::imin (:wat::core::- e1 e0) (:wat::core::- g1 g0)) k)
      (:p::report "9 fields"
        (:p::imin (:wat::core::- j1 j0) (:wat::core::- m1 m0))
        (:p::imin (:wat::core::- i1 i0) (:wat::core::- l1 l0)) k)
      (:wat::kernel::println "")
      (:wat::kernel::println
        (:wat::string::concat "same answers: "
          (:wat::core::if (:wat::core::and (:wat::core::= (:p::R2/i x1) (:p::R2/i y1))
                            (:wat::core::and (:wat::core::= (:p::R5/i x3) (:p::R5/i y3))
                                             (:wat::core::= (:p::R9/i x5) (:p::R9/i y5)))) "yes" "no")
          "   (and " (:wat::i64::to-string (:p::R9/i x6)) " = " (:wat::i64::to-string (:p::R9/i y6)) ")")))))
