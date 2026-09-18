;; Crafting Interpreters chapter 20 (hash tables), in wat.
;;
;; The chapter builds a hash table: open addressing, linear probing, tombstones for deletion, a
;; 75% load factor, and a `FNV-1a` hash cached on every string. wat has `HashMap` and
;; `PersistentMap`, and C-078 measured what they cost, so writing a third one would teach nothing
;; -- NEXT.md recorded this chapter as "no portable content" on that basis.
;;
;; **That was half right, and this file is the other half.** The chapter's other job is STRING
;; INTERNING, and interning is not about hash tables -- it is a language design decision with two
;; separable consequences:
;;
;;   CORRECTNESS  `==` on two strings becomes a pointer comparison. wat gets this for free: `=`
;;                on a String is structural, so chapter 19 already answered `"ab" == "a"+"b"`
;;                with true, before the chapter that makes it true in C.
;;   COST         a comparison stops being O(length), and a constant pool stops holding one copy
;;                per occurrence.
;;
;; The correctness half is checked below and the cost half is MEASURED, because "interning makes
;; equality O(1)" is a claim about a C program and this is not one.
;;
;; Run: wat lox/ch20-hash-tables.wat

(:wat::load-file! "lib/v-intern.wat")

(:wat::core::defn :c20::now [] -> :wat::core::i64 (:wat::time::epoch-nanos (:wat::time::now)))
(:wat::core::defn :c20::imin [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::< a b) a b))

(:wat::core::defn :c20::expect [label <- :wat::core::String got <- :wat::core::String want <- :wat::core::String] -> :wat::core::i64
  (:wat::core::do
    (:wat::kernel::println
      (:wat::string::concat label "  " got
        (:wat::core::if (:wat::core::= got want) "   PASS"
          (:wat::string::concat "   FAIL (want " want ")"))))
    (:wat::core::if (:wat::core::= got want) 0 1)))

(:wat::core::defn :c20::int [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))

(:wat::core::defn :c20::pad [s <- :wat::core::String n <- :wat::core::i64] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length s) n) s
    (:c20::pad (:wat::string::concat s " ") n)))

;; a string of n characters
(:wat::core::defn :c20::big [n <- :wat::core::i64 acc <- :wat::core::String] -> :wat::core::String
  (:wat::core::if (:wat::core::>= (:wat::string::length acc) n) acc
    (:c20::big n (:wat::string::concat acc "abcdefghij"))))

;; ---- the three comparison loops. Same shape, same count, different things compared.
(:wat::core::defn :c20::cmp-str [a <- :wat::core::String b <- :wat::core::String
                                 k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:c20::cmp-str a b (:wat::core::- k 1)
      ;; BOTH branches add, so the equal and unequal arms do identical work apart from the
      ;; comparison itself -- otherwise the "differ at char 0" control measures one fewer `+`
      (:wat::core::if (:wat::core::= a b) (:wat::core::+ acc 1) (:wat::core::+ acc 2)))))

(:wat::core::defn :c20::cmp-id [a <- :wat::core::i64 b <- :wat::core::i64
                                k <- :wat::core::i64 acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= k 0) acc
    (:c20::cmp-id a b (:wat::core::- k 1)
      (:wat::core::if (:wat::core::= a b) (:wat::core::+ acc 1) (:wat::core::+ acc 2)))))

(:wat::core::defn :c20::row [len <- :wat::core::i64 k <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::let
    [a (:c20::big len "")
     ;; b is a SEPARATELY BUILT string with the same characters -- what interning would collapse
     b (:c20::big len "")
     ;; c differs at the FIRST character, so a length-aware comparison can leave immediately
     c (:wat::string::concat "Z" (:wat::string::subs a 1 (:wat::string::length a)))
     t (:loxv::intern (:loxv::intern (:loxv::new-interner) a) c)
     ia (:loxv::id-of t a) ib (:loxv::id-of t b) ic (:loxv::id-of t c)
     ;; interleaved, each arm twice, each taking first position once
     w1 (:c20::cmp-str a b 50 0) w2 (:c20::cmp-id ia ib 50 0) w3 (:c20::cmp-str a c 50 0)
     p0 (:c20::now) x1 (:c20::cmp-id ia ib k 0) p1 (:c20::now)
     q0 (:c20::now) y1 (:c20::cmp-str a b k 0) q1 (:c20::now)
     r0 (:c20::now) z1 (:c20::cmp-str a c k 0) r1 (:c20::now)
     s0 (:c20::now) x2 (:c20::cmp-id ia ib k 0) s1 (:c20::now)
     u0 (:c20::now) y2 (:c20::cmp-str a b k 0) u1 (:c20::now)
     v0 (:c20::now) z2 (:c20::cmp-str a c k 0) v1 (:c20::now)
     t-id (:c20::imin (:wat::core::- p1 p0) (:wat::core::- s1 s0))
     t-eq (:c20::imin (:wat::core::- q1 q0) (:wat::core::- u1 u0))
     t-ne (:c20::imin (:wat::core::- r1 r0) (:wat::core::- v1 v0))]
    (:wat::kernel::println
      (:wat::string::concat
        "length " (:c20::pad (:c20::int (:wat::string::length a)) 8)
        "  id " (:c20::pad (:c20::int (:wat::core::/ t-id k)) 7) " ns"
        "  equal strings " (:c20::pad (:c20::int (:wat::core::/ t-eq k)) 7) " ns"
        "  differ at char 0 " (:c20::pad (:c20::int (:wat::core::/ t-ne k)) 7) " ns"
        "  (" (:c20::int x1) "/" (:c20::int y1) "/" (:c20::int z1) ")"))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [t0 (:loxv::new-interner)
     ;; a source's worth of literals, with repeats -- what a compiler would hand an interner
     lits (:wat::core::Vector :- [:wat::core::String]
            "name" "value" "name" "left" "right" "name" "value" "operator" "left" "name")
     t1 (:loxv::intern-all t0 lits 0)]
    (:wat::core::do
      (:wat::kernel::println "---- what interning must satisfy ----")
      (:wat::core::let
        [rs
         [(:c20::expect "10 literals, 5 distinct    " (:c20::int (:loxv::interner-size t1)) "5")
          (:c20::expect "interning is idempotent    "
            (:c20::int (:loxv::interner-size (:loxv::intern t1 "name"))) "5")
          (:c20::expect "an id is stable            "
            (:c20::int (:loxv::id-of (:loxv::intern t1 "new") "name")) (:c20::int (:loxv::id-of t1 "name")))
          (:c20::expect "first literal gets id 0    " (:c20::int (:loxv::id-of t1 "name")) "0")
          (:c20::expect "and reads back             " (:loxv::text-of t1 (:loxv::id-of t1 "name")) "name")
          (:c20::expect "an absent string has no id " (:c20::int (:loxv::id-of t1 "absent")) "-1")
          (:c20::expect "a built string interns to  "
            (:c20::int (:loxv::id-of t1 (:wat::string::concat "na" "me"))) "0")
          (:c20::expect "  the SAME id as a literal "
            (:wat::core::if (:wat::core::= (:loxv::id-of t1 (:wat::string::concat "na" "me"))
                                           (:loxv::id-of t1 "name")) "yes" "no") "yes")
          (:c20::expect "the empty string interns   "
            (:c20::int (:loxv::interner-size (:loxv::intern t1 ""))) "6")]]
        (:wat::core::do
          (:wat::kernel::println "")
          (:wat::kernel::println "---- what it saves, measured (min of 2, arms interleaved) ----")
          (:c20::row 10 20000)
          (:c20::row 1000 20000)
          (:c20::row 100000 20000)
          (:wat::kernel::println "")
          (:wat::kernel::println "Read the middle column against the two beside it. In C, interning")
          (:wat::kernel::println "turns an O(length) memcmp into a pointer compare, and that is the")
          (:wat::kernel::println "reason chapter 20 does it.")
          (:wat::kernel::println "")
          (:wat::kernel::println "Here the comparison is a builtin call, and a call costs about seven")
          (:wat::kernel::println "microseconds in this loop before it looks at a single character. So")
          (:wat::kernel::println "the saving is invisible at ten characters, a few percent at a")
          (:wat::kernel::println "thousand, and roughly a quarter at a HUNDRED THOUSAND. A Lox program")
          (:wat::kernel::println "compares identifiers and short literals; interning would save it")
          (:wat::kernel::println "nothing measurable.")
          (:wat::kernel::println "")
          (:wat::kernel::println "The third column is the control, and it says the comparison is real:")
          (:wat::kernel::println "two strings differing at character 0 stay FLAT as the length grows,")
          (:wat::kernel::println "where two equal strings do not. So the walk happens and exits early --")
          (:wat::kernel::println "it is simply dwarfed by the call around it.")
          (:wat::kernel::println "")
          (:wat::kernel::println "The general form is the one C-098 and C-099 kept finding: in an")
          (:wat::kernel::println "interpreter, what a program is charged for is the NUMBER of operations,")
          (:wat::kernel::println "not what each one touches. Optimisations aimed at the second kind of")
          (:wat::kernel::println "cost -- interning, NaN boxing, cache-line layout -- are aimed past")
          (:wat::kernel::println "where the time actually goes.")
          (:wat::kernel::println "")
          (:wat::test::assert-eq
            (:wat::core::foldl (:wat::core::fn [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
                                 (:wat::core::+ a b)) 0 rs)
            0))))))
