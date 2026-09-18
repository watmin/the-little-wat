;; Advent of Code's bit-transmission shape, in wat: a hexadecimal string expands to bits, and the
;; bits are a nest of packets. A packet is 3 bits of version, 3 bits of type, and then either a
;; literal (4-bit groups, each with a continue bit) or an operator carrying sub-packets, counted
;; either by how many there are or by how many bits they occupy.
;;
;; Part one: the sum of every version number. Part two: the value of the expression.
;;
;; **This puzzle was chosen to press F-035 — wat has no bit operations — and it half refuted the
;; expectation, which is the useful part.**
;;
;;   SHIFTING AND MASKING NEED NO BIT OPERATIONS. Reading a 15-bit field is a fold that doubles
;;   and adds; `acc * 16 + nibble` is a shift by four; `quot`/`rem` by a power of two is a mask.
;;   The whole decoder below — the part that looks most like bit-twiddling — uses ordinary
;;   arithmetic and is no harder to write than the Clojure, which calls `bit-shift-right` and
;;   `bit-and` only because they are there.
;;
;;   XOR AND AND DO. They are not expressible as `+ - * quot` on whole numbers, so `:aoc::xor`
;;   and `:aoc::band` below walk the two numbers a bit at a time — a loop per operation, where
;;   Clojure calls `bit-xor`. That is where F-035 actually costs something.
;;
;; So F-035's real weight is narrower than "no bit operations" suggests: a program that *extracts
;; fields* does not need them, and a program that *combines* values bitwise does. The finding is
;; unchanged; what this file adds is which half of the work it falls on.
;;
;; F-062 shows up too, mildly: a hex digit is read with `:wat::string::subs` a character at a time,
;; because a String has no characters.
;;
;; The puzzle and its input are ours (aoc/input/day07-packets.txt); Advent of Code's own texts and
;; inputs are not redistributable. The answers must be the reference implementation's
;; (oracle/aoc/day07-packets.clj).
;;
;; Run from the repository root (it reads files by path):
;;   wat aoc/day07-packets.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :aoc::Bits (:wat::core::Vector :- [:wat::core::i64]))

;; ---- hex to bits. F-062: a String has no characters, so a digit is a one-character `subs`.
(:wat::core::defn :aoc::hex-val [c <- :wat::core::String] -> :wat::core::i64
  (:wat::core::match (:wat::string::to-i64 c)
    [:wat::core::Option.Some {:value v} v]
    [:wat::core::Option.None {}
      (:wat::core::if (:wat::core::= c "A") 10
        (:wat::core::if (:wat::core::= c "B") 11
          (:wat::core::if (:wat::core::= c "C") 12
            (:wat::core::if (:wat::core::= c "D") 13
              (:wat::core::if (:wat::core::= c "E") 14
                (:wat::core::if (:wat::core::= c "F") 15 0))))))]))

;; four bits of one nibble, most significant first -- quot and rem stand in for shift and mask
(:wat::core::defn :aoc::nibble-bits [v <- :wat::core::i64 acc <- :aoc::Bits] -> :aoc::Bits
  (:wat::core::conj
    (:wat::core::conj
      (:wat::core::conj
        (:wat::core::conj acc (:wat::i64::rem (:wat::i64::quot v 8) 2))
        (:wat::i64::rem (:wat::i64::quot v 4) 2))
      (:wat::i64::rem (:wat::i64::quot v 2) 2))
    (:wat::i64::rem v 2)))

(:wat::core::defn :aoc::to-bits [hex <- :wat::core::String i <- :wat::core::i64 acc <- :aoc::Bits] -> :aoc::Bits
  (:wat::core::if (:wat::core::>= i (:wat::string::length hex)) acc
    (:aoc::to-bits hex (:wat::core::+ i 1)
      (:aoc::nibble-bits (:aoc::hex-val (:wat::string::subs hex i (:wat::core::+ i 1))) acc))))

;; a field is a fold that doubles -- this is the shift F-035 does not provide, and does not need to
(:wat::core::defn :aoc::bval [b <- :aoc::Bits a <- :wat::core::i64 z <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= a z) acc
    (:aoc::bval b (:wat::core::+ a 1) z (:wat::core::+ (:wat::core::* acc 2) (:wat::core::nth b a)))))

;; ---- the parser
(:wat::core::defenum :aoc::Pk :wat::enum::Pure
  :R [vsum <- :wat::core::i64  value <- :wat::core::i64  next <- :wat::core::i64])

(:wat::core::defn :aoc::lit-body [b <- :aoc::Bits j <- :wat::core::i64 acc <- :wat::core::i64] -> :aoc::Pk
  (:wat::core::let [more (:wat::core::nth b j)
                    nib (:aoc::bval b (:wat::core::+ j 1) (:wat::core::+ j 5) 0)
                    acc2 (:wat::core::+ (:wat::core::* acc 16) nib)]
    (:wat::core::if (:wat::core::= more 1)
      (:aoc::lit-body b (:wat::core::+ j 5) acc2)
      (:aoc::Pk.R {:vsum 0 :value acc2 :next (:wat::core::+ j 5)}))))

(:wat::core::defn :aoc::apply-op [t <- :wat::core::i64 vs <- :aoc::Bits] -> :wat::core::i64
  (:wat::core::if (:wat::core::= t 0) (:aoc::fold-sum vs 0 0)
    (:wat::core::if (:wat::core::= t 1) (:aoc::fold-prod vs 0 1)
      (:wat::core::if (:wat::core::= t 2) (:aoc::fold-min vs 1 (:wat::core::nth vs 0))
        (:wat::core::if (:wat::core::= t 3) (:aoc::fold-max vs 1 (:wat::core::nth vs 0))
          (:wat::core::if (:wat::core::= t 5)
            (:wat::core::if (:wat::core::> (:wat::core::nth vs 0) (:wat::core::nth vs 1)) 1 0)
            (:wat::core::if (:wat::core::= t 6)
              (:wat::core::if (:wat::core::< (:wat::core::nth vs 0) (:wat::core::nth vs 1)) 1 0)
              (:wat::core::if (:wat::core::= (:wat::core::nth vs 0) (:wat::core::nth vs 1)) 1 0))))))))

(:wat::core::defn :aoc::fold-sum [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::fold-sum vs (:wat::core::+ i 1) (:wat::core::+ a (:wat::core::nth vs i)))))
(:wat::core::defn :aoc::fold-prod [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::fold-prod vs (:wat::core::+ i 1) (:wat::core::* a (:wat::core::nth vs i)))))
(:wat::core::defn :aoc::fold-min [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::fold-min vs (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::< (:wat::core::nth vs i) a) (:wat::core::nth vs i) a))))
(:wat::core::defn :aoc::fold-max [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::fold-max vs (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::> (:wat::core::nth vs i) a) (:wat::core::nth vs i) a))))

(:wat::core::defenum :aoc::Subs :wat::enum::Pure
  :S [vs <- :aoc::Bits  vsum <- :wat::core::i64  next <- :wat::core::i64])

(:wat::core::defn :aoc::subs-until [b <- :aoc::Bits j <- :wat::core::i64 stop <- :wat::core::i64
                                    vs <- :aoc::Bits vsum <- :wat::core::i64] -> :aoc::Subs
  (:wat::core::if (:wat::core::>= j stop) (:aoc::Subs.S {:vs vs :vsum vsum :next j})
    (:wat::core::match (:aoc::parse b j)
      [:aoc::Pk.R {:vsum sv :value v :next nxt}
        (:aoc::subs-until b nxt stop (:wat::core::conj vs v) (:wat::core::+ vsum sv))])))

(:wat::core::defn :aoc::subs-count [b <- :aoc::Bits j <- :wat::core::i64 k <- :wat::core::i64 n <- :wat::core::i64
                                    vs <- :aoc::Bits vsum <- :wat::core::i64] -> :aoc::Subs
  (:wat::core::if (:wat::core::>= k n) (:aoc::Subs.S {:vs vs :vsum vsum :next j})
    (:wat::core::match (:aoc::parse b j)
      [:aoc::Pk.R {:vsum sv :value v :next nxt}
        (:aoc::subs-count b nxt (:wat::core::+ k 1) n (:wat::core::conj vs v) (:wat::core::+ vsum sv))])))

(:wat::core::defn :aoc::parse [b <- :aoc::Bits i <- :wat::core::i64] -> :aoc::Pk
  (:wat::core::let [ver (:aoc::bval b i (:wat::core::+ i 3) 0)
                    typ (:aoc::bval b (:wat::core::+ i 3) (:wat::core::+ i 6) 0)]
    (:wat::core::if (:wat::core::= typ 4)
      (:wat::core::match (:aoc::lit-body b (:wat::core::+ i 6) 0)
        [:aoc::Pk.R {:vsum s :value v :next nxt} (:aoc::Pk.R {:vsum ver :value v :next nxt})])
      (:wat::core::if (:wat::core::= 0 (:wat::core::nth b (:wat::core::+ i 6)))
        (:wat::core::let [len (:aoc::bval b (:wat::core::+ i 7) (:wat::core::+ i 22) 0)]
          (:wat::core::match (:aoc::subs-until b (:wat::core::+ i 22) (:wat::core::+ (:wat::core::+ i 22) len)
                               (:wat::core::Vector :- [:wat::core::i64]) ver)
            [:aoc::Subs.S {:vs vs :vsum vsum :next nxt}
              (:aoc::Pk.R {:vsum vsum :value (:aoc::apply-op typ vs) :next nxt})]))
        (:wat::core::let [n (:aoc::bval b (:wat::core::+ i 7) (:wat::core::+ i 18) 0)]
          (:wat::core::match (:aoc::subs-count b (:wat::core::+ i 18) 0 n
                               (:wat::core::Vector :- [:wat::core::i64]) ver)
            [:aoc::Subs.S {:vs vs :vsum vsum :next nxt}
              (:aoc::Pk.R {:vsum vsum :value (:aoc::apply-op typ vs) :next nxt})]))))))

;; every literal in the transmission, in order
(:wat::core::defn :aoc::lits [b <- :aoc::Bits i <- :wat::core::i64 acc <- :aoc::Bits] -> :aoc::Subs
  (:wat::core::let [typ (:aoc::bval b (:wat::core::+ i 3) (:wat::core::+ i 6) 0)]
    (:wat::core::if (:wat::core::= typ 4)
      (:wat::core::match (:aoc::lit-body b (:wat::core::+ i 6) 0)
        [:aoc::Pk.R {:vsum s :value v :next nxt}
          (:aoc::Subs.S {:vs (:wat::core::conj acc v) :vsum 0 :next nxt})])
      (:wat::core::if (:wat::core::= 0 (:wat::core::nth b (:wat::core::+ i 6)))
        (:wat::core::let [len (:aoc::bval b (:wat::core::+ i 7) (:wat::core::+ i 22) 0)]
          (:aoc::lits-until b (:wat::core::+ i 22) (:wat::core::+ (:wat::core::+ i 22) len) acc))
        (:wat::core::let [n (:aoc::bval b (:wat::core::+ i 7) (:wat::core::+ i 18) 0)]
          (:aoc::lits-count b (:wat::core::+ i 18) 0 n acc))))))

(:wat::core::defn :aoc::lits-until [b <- :aoc::Bits j <- :wat::core::i64 stop <- :wat::core::i64 acc <- :aoc::Bits] -> :aoc::Subs
  (:wat::core::if (:wat::core::>= j stop) (:aoc::Subs.S {:vs acc :vsum 0 :next j})
    (:wat::core::match (:aoc::lits b j acc)
      [:aoc::Subs.S {:vs vs :vsum s :next nxt} (:aoc::lits-until b nxt stop vs)])))

(:wat::core::defn :aoc::lits-count [b <- :aoc::Bits j <- :wat::core::i64 k <- :wat::core::i64 n <- :wat::core::i64 acc <- :aoc::Bits] -> :aoc::Subs
  (:wat::core::if (:wat::core::>= k n) (:aoc::Subs.S {:vs acc :vsum 0 :next j})
    (:wat::core::match (:aoc::lits b j acc)
      [:aoc::Subs.S {:vs vs :vsum s :next nxt} (:aoc::lits-count b nxt (:wat::core::+ k 1) n vs)])))

;; ---- the two things arithmetic CANNOT stand in for (F-035), built a bit at a time
(:wat::core::defn :aoc::xor [a <- :wat::core::i64 b <- :wat::core::i64 bit <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::and (:wat::core::= a 0) (:wat::core::= b 0)) acc
    (:wat::core::let [ab (:wat::i64::rem a 2) bb (:wat::i64::rem b 2)]
      (:aoc::xor (:wat::i64::quot a 2) (:wat::i64::quot b 2) (:wat::core::* bit 2)
        (:wat::core::if (:wat::core::= ab bb) acc (:wat::core::+ acc bit))))))

(:wat::core::defn :aoc::band [a <- :wat::core::i64 b <- :wat::core::i64 bit <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::or (:wat::core::= a 0) (:wat::core::= b 0)) acc
    (:wat::core::let [ab (:wat::i64::rem a 2) bb (:wat::i64::rem b 2)]
      (:aoc::band (:wat::i64::quot a 2) (:wat::i64::quot b 2) (:wat::core::* bit 2)
        (:wat::core::if (:wat::core::and (:wat::core::= ab 1) (:wat::core::= bb 1))
          (:wat::core::+ acc bit) acc)))))

(:wat::core::defn :aoc::xor-all [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::xor-all vs (:wat::core::+ i 1) (:aoc::xor a (:wat::core::nth vs i) 1 0))))

(:wat::core::defn :aoc::and-all [vs <- :aoc::Bits i <- :wat::core::i64 a <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length vs)) a
    (:aoc::and-all vs (:wat::core::+ i 1) (:aoc::band a (:wat::core::+ 8 (:wat::core::nth vs i)) 1 0))))

;; ---- printing
(:wat::core::defn :aoc::show-bits [b <- :aoc::Bits n <- :wat::core::i64 i <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= i n) acc
    (:aoc::show-bits b n (:wat::core::+ i 1)
      (:wat::string::concat acc (:wat::i64::to-string (:wat::core::nth b i))))))

;; Clojure prints a vector with square brackets
(:wat::core::defn :aoc::show-vec [vs <- :aoc::Bits] -> :wat::core::String
  (:wat::string::concat "["
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) vs)) "]"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [hex (:wat::string::trim (:wat::io::read-file "aoc/input/day07-packets.txt"))
                    b (:aoc::to-bits hex 0 (:wat::core::Vector :- [:wat::core::i64]))
                    r (:aoc::parse b 0)
                    ls (:wat::core::match (:aoc::lits b 0 (:wat::core::Vector :- [:wat::core::i64]))
                         [:aoc::Subs.S {:vs vs :vsum s :next n} vs])
                    int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))]
    (:aoc::check-answers "oracle/aoc/day07-packets.expected"
                         "aoc day07 packets"
                         (:wat::core::Vector :- [:wat::core::String]
                           (int (:wat::string::length hex))
                           (int (:wat::core::length b))
                           (:aoc::show-bits b 12 0 "")
                           (int (:wat::core::match r [:aoc::Pk.R {:vsum v :value x :next n} v]))
                           (int (:wat::core::match r [:aoc::Pk.R {:vsum v :value x :next n} x]))
                           (int (:aoc::bval b 0 3 0))
                           (int (:aoc::bval b 3 6 0))
                           (int (:aoc::bval b 7 22 0))
                           (:aoc::show-vec ls)
                           (int (:aoc::xor-all ls 1 (:wat::core::nth ls 0)))
                           (int (:aoc::and-all ls 1 (:wat::core::+ 8 (:wat::core::nth ls 0))))
                           (int (:aoc::xor 6 7 1 0))
                           (int (:aoc::band 12 10 1 0))))))
