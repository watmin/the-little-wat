;; PAIP chapter 4 (GPS: the General Problem Solver), in wat.
;;
;; MEANS-ENDS ANALYSIS: a state is a set of conditions; an operator has preconditions, an add-list
;; and a delete-list; achieving a goal means finding an operator that adds it and achieving that
;; operator's preconditions first. The recursion bottoms out at conditions already true.
;;
;; The chapter is really about the program's BUGS, so the failures below are tested as carefully
;; as the successes -- a goal no operator adds, a chain broken at its deepest link, and the
;; "prerequisite clobbers sibling goal" case where achieving one goal undoes another. The version
;; here carries PAIP's fix: after the search, every goal is re-checked against the FINAL state, so
;; a plan that spends the money on the way to school is reported as `fail` rather than as success.
;; That check is why the two goal ORDERS agree below; without it they would not, which is the
;; chapter's whole complaint about GPS 1.0.
;;
;; Nothing in wat is stressed here -- sets of conditions are Vectors and the search is ordinary
;; recursion. What is worth recording is what the port does NOT need: **F-057**'s missing
;; persistent set would be the natural representation for a state, and its absence costs a linear
;; `mem?` per condition, which at these sizes is invisible. The finding is real; this workload is
;; not the one that proves it.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch04-gps.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch04-gps.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Conds (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defstruct :paip::Op
  [name <- :wat::core::String  preconds <- :paip::Conds  add <- :paip::Conds  del <- :paip::Conds])

(:wat::core::typealias :paip::Ops (:wat::core::Vector :- [:paip::Op]))

;; `fail` has to be a distinct outcome, not an empty state: an empty state is a legitimate answer
(:wat::core::defenum :paip::Outcome :wat::enum::Pure
  :State [conds <- :paip::Conds]
  :Fail  [])

(:wat::core::defn :paip::mem? [x <- :wat::core::String s <- :paip::Conds] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? s) false
    (:wat::core::if (:wat::core::= x (:wat::core::first s)) true
      (:paip::mem? x (:wat::core::rest s)))))

(:wat::core::defn :paip::without [x <- :wat::core::String s <- :paip::Conds] -> :paip::Conds
  (:wat::core::filterv (:wat::core::fn [y <- :wat::core::String] -> :wat::core::bool
                         (:wat::core::not (:wat::core::= y x))) s))

(:wat::core::defn :paip::remove-all [xs <- :paip::Conds i <- :wat::core::i64 s <- :paip::Conds] -> :paip::Conds
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) s
    (:paip::remove-all xs (:wat::core::+ i 1) (:paip::without (:wat::core::nth xs i) s))))

(:wat::core::defn :paip::add-all [xs <- :paip::Conds i <- :wat::core::i64 s <- :paip::Conds] -> :paip::Conds
  (:wat::core::if (:wat::core::>= i (:wat::core::length xs)) s
    (:paip::add-all xs (:wat::core::+ i 1)
      (:wat::core::if (:paip::mem? (:wat::core::nth xs i) s) s
        (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] (:wat::core::nth xs i)) s)))))

;; `stack` holds the goals currently being pursued, so a cycle is a failure rather than a hang
(:wat::core::defn :paip::achieve
  [goal <- :wat::core::String state <- :paip::Conds ops <- :paip::Ops stack <- :paip::Conds] -> :paip::Outcome
  (:wat::core::if (:paip::mem? goal state) (:paip::Outcome.State {:conds state})
    (:wat::core::if (:paip::mem? goal stack) (:paip::Outcome.Fail {})
      (:paip::try-ops ops 0 goal state
        (:wat::core::concat (:wat::core::Vector :- [:wat::core::String] goal) stack)))))

(:wat::core::defn :paip::try-ops
  [ops <- :paip::Ops i <- :wat::core::i64 goal <- :wat::core::String state <- :paip::Conds stack <- :paip::Conds]
  -> :paip::Outcome
  (:wat::core::if (:wat::core::>= i (:wat::core::length ops)) (:paip::Outcome.Fail {})
    (:wat::core::let [o (:wat::core::nth ops i)]
      (:wat::core::if (:wat::core::not (:paip::mem? goal (:paip::Op/add o)))
        (:paip::try-ops ops (:wat::core::+ i 1) goal state stack)
        (:wat::core::match (:paip::apply-op o state ops stack)
          [:paip::Outcome.State {:conds s} (:paip::Outcome.State {:conds s})]
          [:paip::Outcome.Fail {} (:paip::try-ops ops (:wat::core::+ i 1) goal state stack)])))))

(:wat::core::defn :paip::apply-op
  [o <- :paip::Op state <- :paip::Conds ops <- :paip::Ops stack <- :paip::Conds] -> :paip::Outcome
  (:wat::core::match (:paip::achieve-all (:paip::Op/preconds o) 0 state ops stack)
    [:paip::Outcome.Fail {} (:paip::Outcome.Fail {})]
    [:paip::Outcome.State {:conds s}
      (:paip::Outcome.State {:conds (:paip::add-all (:paip::Op/add o) 0
                                      (:paip::remove-all (:paip::Op/del o) 0 s))})]))

(:wat::core::defn :paip::achieve-all
  [goals <- :paip::Conds i <- :wat::core::i64 state <- :paip::Conds ops <- :paip::Ops stack <- :paip::Conds]
  -> :paip::Outcome
  (:wat::core::if (:wat::core::>= i (:wat::core::length goals)) (:paip::Outcome.State {:conds state})
    (:wat::core::match (:paip::achieve (:wat::core::nth goals i) state ops stack)
      [:paip::Outcome.Fail {} (:paip::Outcome.Fail {})]
      [:paip::Outcome.State {:conds s} (:paip::achieve-all goals (:wat::core::+ i 1) s ops stack)])))

(:wat::core::defn :paip::all-in? [goals <- :paip::Conds i <- :wat::core::i64 s <- :paip::Conds] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length goals)) true
    (:wat::core::and (:paip::mem? (:wat::core::nth goals i) s)
      (:paip::all-in? goals (:wat::core::+ i 1) s))))

;; PAIP's fix: re-check every goal against the FINAL state, so a clobbered sibling is caught
(:wat::core::defn :paip::gps [state <- :paip::Conds goals <- :paip::Conds ops <- :paip::Ops] -> :wat::core::String
  (:wat::core::match (:paip::achieve-all goals 0 state ops (:wat::core::Vector :- [:wat::core::String]))
    [:paip::Outcome.Fail {} "fail"]
    [:paip::Outcome.State {:conds s} (:wat::core::if (:paip::all-in? goals 0 s) "solved" "fail")]))

;; ---- the school problem
(:wat::core::defn :paip::cs [xs <- :paip::Conds] -> :paip::Conds xs)

(:wat::core::defn :paip::school-ops [] -> :paip::Ops
  (:wat::core::Vector :- [:paip::Op]
    (:paip::Op :name "drive-son-to-school"
               :preconds (:wat::core::Vector :- [:wat::core::String] "son-at-home" "car-works")
               :add (:wat::core::Vector :- [:wat::core::String] "son-at-school")
               :del (:wat::core::Vector :- [:wat::core::String] "son-at-home"))
    (:paip::Op :name "shop-installs-battery"
               :preconds (:wat::core::Vector :- [:wat::core::String] "car-needs-battery" "shop-knows-problem" "shop-has-money")
               :add (:wat::core::Vector :- [:wat::core::String] "car-works")
               :del (:wat::core::Vector :- [:wat::core::String]))
    (:paip::Op :name "tell-shop-problem"
               :preconds (:wat::core::Vector :- [:wat::core::String] "in-communication-with-shop")
               :add (:wat::core::Vector :- [:wat::core::String] "shop-knows-problem")
               :del (:wat::core::Vector :- [:wat::core::String]))
    (:paip::Op :name "telephone-shop"
               :preconds (:wat::core::Vector :- [:wat::core::String] "know-phone-number")
               :add (:wat::core::Vector :- [:wat::core::String] "in-communication-with-shop")
               :del (:wat::core::Vector :- [:wat::core::String]))
    (:paip::Op :name "look-up-number"
               :preconds (:wat::core::Vector :- [:wat::core::String] "have-phone-book")
               :add (:wat::core::Vector :- [:wat::core::String] "know-phone-number")
               :del (:wat::core::Vector :- [:wat::core::String]))
    (:paip::Op :name "give-shop-money"
               :preconds (:wat::core::Vector :- [:wat::core::String] "have-money")
               :add (:wat::core::Vector :- [:wat::core::String] "shop-has-money")
               :del (:wat::core::Vector :- [:wat::core::String] "have-money"))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :paip::final-state [state <- :paip::Conds goals <- :paip::Conds] -> :paip::Conds
  (:wat::core::match (:paip::achieve-all goals 0 state (:paip::school-ops) (:wat::core::Vector :- [:wat::core::String]))
    [:paip::Outcome.State {:conds s} s]
    [:paip::Outcome.Fail {} (:wat::core::Vector :- [:wat::core::String])]))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [ops (:paip::school-ops)
                    start (:wat::core::Vector :- [:wat::core::String]
                            "son-at-home" "car-needs-battery" "have-money" "have-phone-book")
                    school (:wat::core::Vector :- [:wat::core::String] "son-at-school")
                    final (:paip::final-state start school)]
    (:paip::check-chapter "oracle/paip/ch04-gps.expected"
                          "paip ch04 gps"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:paip::gps start school ops)
                            (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "son-at-home") ops)
                            (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "son-at-university") ops)
                            (:paip::gps (:wat::core::Vector :- [:wat::core::String]
                                          "son-at-home" "car-needs-battery" "have-money") school ops)
                            (:paip::gps (:wat::core::Vector :- [:wat::core::String]
                                          "son-at-home" "car-needs-battery" "have-phone-book") school ops)
                            (:paip::gps (:wat::core::Vector :- [:wat::core::String] "son-at-home" "car-works") school ops)
                            ;; prerequisite clobbers sibling goal, both orders
                            (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "son-at-school" "have-money") ops)
                            (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "have-money" "son-at-school") ops)
                            (:paip::b (:wat::core::= (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "son-at-school" "have-money") ops)
                                                     (:paip::gps start (:wat::core::Vector :- [:wat::core::String] "have-money" "son-at-school") ops)))
                            ;; what the final state actually contains
                            (:paip::b (:paip::mem? "son-at-school" final))
                            (:paip::b (:paip::mem? "son-at-home" final))
                            (:paip::b (:paip::mem? "car-works" final))
                            (:paip::b (:paip::mem? "have-money" final))))))
