;; probes/lox/char-access-cost.wat
;;
;; Q: what does it cost to walk a String one character at a time in wat?
;;
;; wat has no char-indexed sequence: `:wat::string::subs` is the only way to reach character i,
;; and `:wat::string::split` refuses an empty separator (so a String cannot be exploded into a
;; Vector of characters). So a scanner -- Crafting Interpreters chapter 16 -- has exactly two
;; shapes available, and this probe prices both against source length.
;;
;;   INDEX     `(subs s i (i+1))`, the direct translation of Nystrom's `scanner.current`
;;   CONSUME   carry the unscanned remainder, `(subs rest 1 n)` to advance
;;
;; A third column walks a Vector of the same length with `nth`, which IS O(1) -- the control that
;; separates the cost of character access from the cost of the interpreted loop around it. Run: wat probes/lox/char-access-cost.wat

(:wat::core::defn :p::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))

;; a source of n characters
(:wat::core::defn :p::src [n <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length acc) n) acc
    (:p::src n (:wat::string::concat acc "abcdefghij"))))

;; INDEX: reach character i by index, count the 'a's
(:wat::core::defn :p::index-walk [s <- :wat::core::String n <- :wat::core::i64
                                  i <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n) k
    (:p::index-walk s n (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= (:wat::string::subs s i (:wat::core::+ i 1)) "a")
        (:wat::core::+ k 1) k))))

;; CONTROL: the same loop over a Vector, where `nth` IS O(1). This separates the cost of
;; character access from the cost of the interpreted loop around it.
(:wat::core::defn :p::vec [n <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::core::i64])]
  -> (:wat::core::Vector :- [:wat::core::i64])
  (:wat::core::if (:wat::core::>= (:wat::core::length acc) n) acc
    (:p::vec n (:wat::core::conj acc 97))))

(:wat::core::defn :p::vec-walk [v <- (:wat::core::Vector :- [:wat::core::i64]) n <- :wat::core::i64
                                i <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i n) k
    (:p::vec-walk v n (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= (:wat::core::nth v i) 97) (:wat::core::+ k 1) k))))

;; CONSUME: carry the remainder
(:wat::core::defn :p::consume-walk [rest <- :wat::core::String k <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [n (:wat::string::length rest)]
    (:wat::core::if (:wat::core::= n 0) k
      (:p::consume-walk (:wat::string::subs rest 1 n)
        (:wat::core::if (:wat::core::= (:wat::string::subs rest 0 1) "a")
          (:wat::core::+ k 1) k)))))

(:wat::core::defn :lox::p-pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:lox::p-pad (:wat::string::concat s " ") n)))

;; F-112: `:wat::f64::min` exists and `:wat::i64::min` does not, so the smaller of two integers
;; is hand-written here -- as it has been in every timing harness in this repository.
(:wat::core::defn :p::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

(:wat::core::defn :p::min3 [a <- :wat::core::i64 b <- :wat::core::i64 c <- :wat::core::i64] -> :wat::core::i64
  (:p::imin a (:p::imin b c)))

;; time one arm three times and keep the smallest, as every other measurement here does
(:wat::core::defn :p::time-index [s <- :wat::core::String m <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [a0 (:p::now) _a (:p::index-walk s m 0 0) a1 (:p::now)
                    b0 (:p::now) _b (:p::index-walk s m 0 0) b1 (:p::now)
                    c0 (:p::now) _c (:p::index-walk s m 0 0) c1 (:p::now)]
    (:p::min3 (:wat::core::- a1 a0) (:wat::core::- b1 b0) (:wat::core::- c1 c0))))

(:wat::core::defn :p::time-consume [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::let [a0 (:p::now) _a (:p::consume-walk s 0) a1 (:p::now)
                    b0 (:p::now) _b (:p::consume-walk s 0) b1 (:p::now)
                    c0 (:p::now) _c (:p::consume-walk s 0) c1 (:p::now)]
    (:p::min3 (:wat::core::- a1 a0) (:wat::core::- b1 b0) (:wat::core::- c1 c0))))

(:wat::core::defn :p::time-vec [v <- (:wat::core::Vector :- [:wat::core::i64]) m <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::let [a0 (:p::now) _a (:p::vec-walk v m 0 0) a1 (:p::now)
                    b0 (:p::now) _b (:p::vec-walk v m 0 0) b1 (:p::now)
                    c0 (:p::now) _c (:p::vec-walk v m 0 0) c1 (:p::now)]
    (:p::min3 (:wat::core::- a1 a0) (:wat::core::- b1 b0) (:wat::core::- c1 c0))))

(:wat::core::defn :p::row [n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [s (:p::src n "")
     m (:wat::string::length s)
     v (:p::vec m (:wat::core::Vector :- [:wat::core::i64]))
     ;; vector first this time, so the string arms do not get the cold cache every row
     tv (:p::time-vec v m)
     ti (:p::time-index s m)
     tc (:p::time-consume s)
     per (:wat::core::fn [t <- :wat::core::i64] -> :wat::core::String
           (:wat::i64::to-string (:wat::core::/ t m)))]
    (:wat::kernel::println
      (:wat::string::concat
        "n=" (:lox::p-pad (:wat::i64::to-string m) 6)
        "  vector " (:lox::p-pad (per tv) 5) " ns/elem"
        "  index " (:lox::p-pad (per ti) 5) " ns/char"
        "  consume " (:lox::p-pad (per tc) 6) " ns/char"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "walking a String one character at a time")
    (:p::row 1000)
    (:p::row 2000)
    (:p::row 4000)
    (:p::row 8000)
    (:p::row 16000)
    (:wat::kernel::println "")
    (:wat::kernel::println "per-character cost, min of 3. A flat column is linear; a rising one is not.")))
