;; PAIP chapter 7 (STUDENT: solving algebra word problems), in wat.
;;
;; Two halves. Translation is pattern matching over word lists, which chapter 5 (C-083) already
;; did. SOLVING is the half with teeth, and it has a failure mode worth being exact about:
;;
;;   `isolate` rewrites `lhs = rhs` until the unknown stands alone, by moving operands across. It
;;   works by finding WHICH SIDE of an operator the unknown is on -- so it silently does the wrong
;;   thing when the unknown is on BOTH. `(+ x x) = 10` isolates happily to `x = 10 - x`, which is
;;   true and useless, and the chapter records this as **#f** for "did isolate fail?" rather than
;;   pretending otherwise.
;;
;;   **The guard lives in the CALLER.** `solve-system` only picks an equation when the unknown
;;   occurs exactly once, which is why the system solves and the bare `isolate` does not complain.
;;   That split -- an algorithm that is only correct under a precondition its own code never checks
;;   -- is the kind of thing a type system cannot express and a comment usually has to, and it is
;;   worth naming because wat's checker is otherwise so good at this class of thing (C-078, C-080).
;;
;; Nothing wat lacks is stressed here. `evaluate` answers an `Option` rather than Scheme's
;; `'unbound` symbol, which is the one place the port is tighter than the original: a caller cannot
;; forget to check.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch07-student.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch07-student.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::defenum :paip::Al :wat::enum::Pure
  :Num [n <- :wat::core::i64]
  :Sym [name <- :wat::core::String]
  :Op  [op <- :wat::core::String  l <- :paip::Al  r <- :paip::Al])

(:wat::core::defenum :paip::Eqn :wat::enum::Pure
  :Eq   [l <- :paip::Al  r <- :paip::Al]
  :NoEq [])

(:wat::core::defenum :paip::Bind :wat::enum::Pure
  :KNil  []
  :KCons [name <- :wat::core::String  v <- :wat::core::i64  rest <- :paip::Bind])

(:wat::core::defn :paip::known [name <- :wat::core::String b <- :paip::Bind] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match b
    [:paip::Bind.KNil {} (:wat::core::Option.None {})]
    [:paip::Bind.KCons {:name n :v v :rest rest}
      (:wat::core::if (:wat::core::= n name) (:wat::core::Option.Some {:value v}) (:paip::known name rest))]))

(:wat::core::defn :paip::occurrences [x <- :wat::core::String e <- :paip::Al] -> :wat::core::i64
  (:wat::core::match e
    [:paip::Al.Sym {:name n} (:wat::core::if (:wat::core::= n x) 1 0)]
    [:paip::Al.Num {:n n} 0]
    [:paip::Al.Op {:op op :l l :r r}
      (:wat::core::+ (:paip::occurrences x l) (:paip::occurrences x r))]))

(:wat::core::defn :paip::occ-eq [x <- :wat::core::String eq <- :paip::Eqn] -> :wat::core::i64
  (:wat::core::match eq
    [:paip::Eqn.Eq {:l l :r r} (:wat::core::+ (:paip::occurrences x l) (:paip::occurrences x r))]
    [:paip::Eqn.NoEq {} 0]))

(:wat::core::defn :paip::in? [x <- :wat::core::String e <- :paip::Al] -> :wat::core::bool
  (:wat::core::> (:paip::occurrences x e) 0))

(:wat::core::defn :paip::ap [op <- :wat::core::String a <- :paip::Al b <- :paip::Al] -> :paip::Al
  (:paip::Al.Op {:op op :l a :r b}))

;; (a OP b) = r, solving for a
(:wat::core::defn :paip::invert-right [op <- :wat::core::String r <- :paip::Al b <- :paip::Al] -> :paip::Al
  (:wat::core::if (:wat::core::= op "+") (:paip::ap "-" r b)
    (:wat::core::if (:wat::core::= op "-") (:paip::ap "+" r b)
      (:wat::core::if (:wat::core::= op "*") (:paip::ap "/" r b)
        (:paip::ap "*" r b)))))

;; (a OP b) = r, solving for b
(:wat::core::defn :paip::invert-left [op <- :wat::core::String r <- :paip::Al a <- :paip::Al] -> :paip::Al
  (:wat::core::if (:wat::core::= op "+") (:paip::ap "-" r a)
    (:wat::core::if (:wat::core::= op "*") (:paip::ap "/" r a)
      (:wat::core::if (:wat::core::= op "-") (:paip::ap "-" a r)
        (:paip::ap "/" a r)))))

;; move operands across until the unknown stands alone on the left
(:wat::core::defn :paip::isolate [eq <- :paip::Eqn x <- :wat::core::String] -> :paip::Eqn
  (:wat::core::match eq
    [:paip::Eqn.NoEq {} eq]
    [:paip::Eqn.Eq {:l l :r r}
      (:wat::core::match l
        [:paip::Al.Sym {:name n} (:wat::core::if (:wat::core::= n x) eq (:paip::Eqn.NoEq {}))]
        [:paip::Al.Num {:n n} (:paip::Eqn.NoEq {})]
        [:paip::Al.Op {:op op :l ll :r lr}
          (:wat::core::if (:paip::in? x ll)
            (:paip::isolate (:paip::Eqn.Eq {:l ll :r (:paip::invert-right op r lr)}) x)
            (:wat::core::if (:paip::in? x lr)
              (:paip::isolate (:paip::Eqn.Eq {:l lr :r (:paip::invert-left op r ll)}) x)
              (:paip::Eqn.NoEq {})))])]))

(:wat::core::defn :paip::evaluate [e <- :paip::Al b <- :paip::Bind] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match e
    [:paip::Al.Num {:n n} (:wat::core::Option.Some {:value n})]
    [:paip::Al.Sym {:name n} (:paip::known n b)]
    [:paip::Al.Op {:op op :l l :r r}
      (:wat::core::match (:paip::evaluate l b)
        [:wat::core::Option.None {} (:wat::core::Option.None {})]
        [:wat::core::Option.Some {:value a}
          (:wat::core::match (:paip::evaluate r b)
            [:wat::core::Option.None {} (:wat::core::Option.None {})]
            [:wat::core::Option.Some {:value c}
              (:wat::core::Option.Some
                {:value (:wat::core::if (:wat::core::= op "+") (:wat::core::+ a c)
                          (:wat::core::if (:wat::core::= op "-") (:wat::core::- a c)
                            (:wat::core::if (:wat::core::= op "*") (:wat::core::* a c)
                              (:wat::i64::quot a c))))})])])]))

(:wat::core::defn :paip::solve-one [eq <- :paip::Eqn x <- :wat::core::String b <- :paip::Bind] -> :wat::core::String
  (:wat::core::match (:paip::isolate eq x)
    [:paip::Eqn.NoEq {} "fail"]
    [:paip::Eqn.Eq {:l l :r r}
      (:wat::core::match (:paip::evaluate r b)
        [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
        [:wat::core::Option.None {} "unbound"])]))

(:wat::core::defn :paip::isolate-failed? [eq <- :paip::Eqn x <- :wat::core::String] -> :wat::core::bool
  (:wat::core::match (:paip::isolate eq x)
    [:paip::Eqn.NoEq {} true]
    [:paip::Eqn.Eq {:l l :r r} false]))

;; ---- solving a SYSTEM: pick an equation whose unknown occurs exactly once
(:wat::core::typealias :paip::Eqns (:wat::core::Vector :- [:paip::Eqn]))

(:wat::core::defn :paip::unknowns-in [e <- :paip::Al b <- :paip::Bind acc <- (:wat::core::Vector :- [:wat::core::String])]
  -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::match e
    [:paip::Al.Sym {:name n}
      (:wat::core::match (:paip::known n b)
        [:wat::core::Option.Some {:value v} acc]
        [:wat::core::Option.None {} (:wat::core::conj acc n)])]
    [:paip::Al.Num {:n n} acc]
    [:paip::Al.Op {:op op :l l :r r} (:paip::unknowns-in r b (:paip::unknowns-in l b acc))]))

(:wat::core::defn :paip::unknowns-eq [eq <- :paip::Eqn b <- :paip::Bind] -> (:wat::core::Vector :- [:wat::core::String])
  (:wat::core::match eq
    [:paip::Eqn.Eq {:l l :r r} (:paip::unknowns-in r b (:paip::unknowns-in l b (:wat::core::Vector :- [:wat::core::String])))]
    [:paip::Eqn.NoEq {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :paip::drop-at [v <- :paip::Eqns k <- :wat::core::i64 i <- :wat::core::i64 acc <- :paip::Eqns] -> :paip::Eqns
  (:wat::core::if (:wat::core::>= i (:wat::core::length v)) acc
    (:paip::drop-at v k (:wat::core::+ i 1)
      (:wat::core::if (:wat::core::= i k) acc (:wat::core::conj acc (:wat::core::nth v i))))))

(:wat::core::defenum :paip::SysAns :wat::enum::Pure
  :Solved [b <- :paip::Bind]
  :Stuck  [])

(:wat::core::defn :paip::solve-system [eqs <- :paip::Eqns b <- :paip::Bind] -> :paip::SysAns
  (:wat::core::if (:wat::core::empty? eqs) (:paip::SysAns.Solved {:b b})
    (:paip::try-eq eqs 0 b)))

(:wat::core::defn :paip::try-eq [eqs <- :paip::Eqns i <- :wat::core::i64 b <- :paip::Bind] -> :paip::SysAns
  (:wat::core::if (:wat::core::>= i (:wat::core::length eqs)) (:paip::SysAns.Stuck {})
    (:wat::core::let [eq (:wat::core::nth eqs i)
                      us (:paip::unknowns-eq eq b)]
      ;; the GUARD the isolation algorithm itself does not make: exactly one unknown, occurring once
      (:wat::core::if (:wat::core::and (:wat::core::= 1 (:wat::core::length us))
                        (:wat::core::= 1 (:paip::occ-eq (:wat::core::nth us 0) eq)))
        (:wat::core::let [x (:wat::core::nth us 0)
                          v (:paip::solve-one eq x b)]
          (:wat::core::if (:wat::core::or (:wat::core::= v "fail") (:wat::core::= v "unbound"))
            (:paip::SysAns.Stuck {})
            (:paip::solve-system
              (:paip::drop-at eqs i 0 (:wat::core::Vector :- [:paip::Eqn]))
              (:paip::Bind.KCons {:name x
                                  :v (:wat::core::match (:wat::string::to-i64 v)
                                       [:wat::core::Option.Some {:value k} k]
                                       [:wat::core::Option.None {} 0])
                                  :rest b}))))
        (:paip::try-eq eqs (:wat::core::+ i 1) b)))))

(:wat::core::defn :paip::sys-value [a <- :paip::SysAns name <- :wat::core::String] -> :wat::core::String
  (:wat::core::match a
    [:paip::SysAns.Stuck {} "fail"]
    [:paip::SysAns.Solved {:b b}
      (:wat::core::match (:paip::known name b)
        [:wat::core::Option.Some {:value v} (:wat::i64::to-string v)]
        [:wat::core::Option.None {} "fail"])]))

(:wat::core::defn :paip::stuck? [a <- :paip::SysAns] -> :wat::core::bool
  (:wat::core::match a [:paip::SysAns.Stuck {} true] [:paip::SysAns.Solved {:b b} false]))

;; ---- translation, by pattern
(:wat::core::defn :paip::translate [words <- (:wat::core::Vector :- [:wat::core::String])] -> :wat::core::String
  (:wat::core::if (:wat::core::and (:wat::core::>= (:wat::core::length words) 2)
                    (:wat::core::and (:wat::core::= (:wat::core::nth words 0) "what")
                                     (:wat::core::= (:wat::core::nth words 1) "is")))
    "unknown" "no-rule"))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :paip::sy [n <- :wat::core::String] -> :paip::Al (:paip::Al.Sym {:name n}))
(:wat::core::defn :paip::nu [n <- :wat::core::i64] -> :paip::Al (:paip::Al.Num {:n n}))
(:wat::core::defn :paip::eqn [l <- :paip::Al r <- :paip::Al] -> :paip::Eqn (:paip::Eqn.Eq {:l l :r r}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    x (:paip::sy "x") y (:paip::sy "y")
                    none (:paip::Bind.KNil {})
                    y4 (:paip::Bind.KCons {:name "y" :v 4 :rest none})
                    sys (:wat::core::Vector :- [:paip::Eqn]
                          (:paip::eqn (:paip::ap "+" x y) (:paip::nu 10))
                          (:paip::eqn y (:paip::nu 4)))
                    solved (:paip::solve-system sys none)
                    nosys (:wat::core::Vector :- [:paip::Eqn]
                            (:paip::eqn (:paip::ap "+" x y) (:paip::nu 10))
                            (:paip::eqn (:paip::ap "+" x (:paip::sy "z")) (:paip::nu 8)))]
    (:paip::check-chapter "oracle/paip/ch07-student.expected"
                          "paip ch07 student"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::occ-eq "x" (:paip::eqn x (:paip::nu 5))))
                            (int (:paip::occ-eq "x" (:paip::eqn (:paip::ap "+" x x) (:paip::nu 10))))
                            (int (:paip::occ-eq "x" (:paip::eqn (:paip::ap "+" y (:paip::nu 3)) (:paip::nu 10))))
                            (:paip::solve-one (:paip::eqn (:paip::ap "+" x (:paip::nu 3)) (:paip::nu 10)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "*" (:paip::nu 2) x) (:paip::nu 12)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "-" x (:paip::nu 4)) (:paip::nu 6)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "/" x (:paip::nu 3)) (:paip::nu 5)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "-" (:paip::nu 20) x) (:paip::nu 8)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "/" (:paip::nu 24) x) (:paip::nu 4)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "+" (:paip::ap "*" (:paip::nu 2) x) (:paip::nu 1))
                                                          (:paip::nu 11)) "x" none)
                            (:paip::solve-one (:paip::eqn (:paip::ap "+" x y) (:paip::nu 10)) "x" y4)
                            ;; isolate does NOT detect the double occurrence -- the guard is the caller's
                            (:paip::b (:paip::isolate-failed? (:paip::eqn (:paip::ap "+" x x) (:paip::nu 10)) "x"))
                            (:paip::b (:paip::isolate-failed? (:paip::eqn (:paip::ap "+" y (:paip::nu 3)) (:paip::nu 10)) "x"))
                            (:paip::translate (:wat::core::Vector :- [:wat::core::String] "what" "is" "3" "plus" "4"))
                            (:paip::translate (:wat::core::Vector :- [:wat::core::String] "nothing" "matches" "this"))
                            (:paip::sys-value solved "x")
                            (:paip::sys-value solved "y")
                            (:paip::b (:paip::stuck? (:paip::solve-system nosys none)))))))
