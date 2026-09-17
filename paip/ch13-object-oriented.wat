;; PAIP chapter 13 (object-oriented programming), in wat.
;;
;; The chapter's arc goes from objects-as-closures to GENERIC FUNCTIONS that dispatch on the types
;; of ALL their arguments. This file first claimed wat could not do the second, and recommended a
;; hand-built table instead. **Both halves were wrong** (F-109), and the correction is the most
;; useful thing in the chapter:
;;
;;   `:wat::core::defclause` IS wat's multiple dispatch. It selects a clause by matching EVERY
;;   argument position, first-match-wins, on the arguments' RUNTIME types -- which is what CLOS
;;   does and what this chapter is about. And a missing combination at a concretely-typed call
;;   site is a **compile error**, where the hand-built table gives a run-time `no-method`. So the
;;   table this file used to recommend is strictly worse than the feature that already existed.
;;
;; Both are kept below, and the chapter requires them to AGREE, because the table is still the
;; right answer to a different question: `defclause` is a closed set of clauses written in one
;; place, so it cannot be extended by a later module. A table can. That is the same open-versus-
;; closed trade C-078 drew for SICP §2.5, and now it is a choice between two real mechanisms
;; rather than a workaround for a missing one.
;;
;; What went wrong is worth naming: I tested `defsurface` + `extend-type`, found a concrete type
;; may extend a surface only once, and stopped. The user-facing pages point at surfaces for
;; polymorphism and mention `defclause` three times in passing; the page that explains it is an
;; internal design document. That is the finding that survives -- see F-109.
;;
;; Objects as closures port without comment, and the port is tighter than the original in one way:
;; each message answers a NEW account rather than mutating one, so `a1` still reads 100 after a
;; deposit. Norvig's version needs `setf`; C-014 records the wat route to real mutation when it is
;; wanted.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch13-object-oriented.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch13-object-oriented.wat

(:wat::load-file! "lib/check.wat")

;; ---- objects as closures. A message is a String; the answers are Strings so one closure type
;; covers every message, which is the same fixed-answer-type constraint C-078 hit in SICP §2.4.
(:wat::core::typealias :paip::Acct [:wat::core::String :wat::core::i64 :-> :wat::core::String])

(:wat::core::defn :paip::make-account [balance <- :wat::core::i64] -> :paip::Acct
  (:wat::core::fn [msg <- :wat::core::String arg <- :wat::core::i64] -> :wat::core::String
    (:wat::core::if (:wat::core::= msg "balance") (:wat::i64::to-string balance)
      (:wat::core::if (:wat::core::= msg "deposit") (:wat::i64::to-string (:wat::core::+ balance arg))
        (:wat::core::if (:wat::core::= msg "withdraw")
          (:wat::core::if (:wat::core::> arg balance) "insufficient"
            (:wat::i64::to-string (:wat::core::- balance arg)))
          "unknown-message")))))

;; ---- single dispatch: one tag picks the method
(:wat::core::typealias :paip::Shape (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :paip::Area [:paip::Shape :-> :wat::core::i64])
(:wat::core::typealias :paip::AreaTable (:wat::core::HashMap :- [:wat::core::String :paip::Area]))

(:wat::core::defn :paip::area-table [] -> :paip::AreaTable
  (:wat::core::assoc
    (:wat::core::assoc (:wat::core::HashMap :- [:wat::core::String :paip::Area])
      "area/square" (:wat::core::fn [s <- :paip::Shape] -> :wat::core::i64
                      (:wat::core::* (:wat::core::nth s 0) (:wat::core::nth s 0))))
    "area/rect" (:wat::core::fn [s <- :paip::Shape] -> :wat::core::i64
                  (:wat::core::* (:wat::core::nth s 0) (:wat::core::nth s 1)))))

(:wat::core::defn :paip::single-dispatch [tag <- :wat::core::String s <- :paip::Shape] -> :wat::core::String
  (:wat::core::match (:wat::core::get (:paip::area-table) (:wat::string::concat "area/" tag))
    [:wat::core::Option.Some {:value f} (:wat::i64::to-string (f s))]
    [:wat::core::Option.None {} "no-method"]))

;; ---- MULTIPLE dispatch, by hand, because the language will not do it.
;; The key is the tuple of tags. This is SICP §2.4's table (C-078) reached from PAIP's side.
(:wat::core::typealias :paip::Collide [:wat::core::String :wat::core::String :-> :wat::core::String])
(:wat::core::typealias :paip::CollideTable (:wat::core::HashMap :- [:wat::core::String :paip::Collide]))

(:wat::core::defn :paip::put-c [t <- :paip::CollideTable a <- :wat::core::String b <- :wat::core::String
                                f <- :paip::Collide] -> :paip::CollideTable
  (:wat::core::assoc t (:wat::string::concat "collide/" a "/" b) f))

(:wat::core::defn :paip::collide-table [] -> :paip::CollideTable
  (:paip::put-c
    (:paip::put-c
      (:paip::put-c (:wat::core::HashMap :- [:wat::core::String :paip::Collide])
        "asteroid" "ship" (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                            "ship-destroyed"))
      "asteroid" "asteroid" (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                              "both-shatter"))
    "ship" "ship" (:wat::core::fn [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
                    "both-damaged")))

(:wat::core::defn :paip::multi-dispatch [a <- :wat::core::String b <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::core::get (:paip::collide-table)
                       (:wat::string::concat "collide/" a "/" b))
    [:wat::core::Option.Some {:value f} (f a b)]
    [:wat::core::Option.None {} "no-method"]))

;; ---- and the same thing with wat's real mechanism: dispatch on EVERY argument position.
;; The two structs carry no fields; the TYPE is the whole of the dispatch key.
(:wat::core::defstruct :paip::Asteroid [])
(:wat::core::defstruct :paip::Ship [])

(:wat::core::defclause :paip::collide
  ([a <- :paip::Asteroid  b <- :paip::Ship]     -> :wat::core::String "ship-destroyed")
  ([a <- :paip::Asteroid  b <- :paip::Asteroid] -> :wat::core::String "both-shatter")
  ([a <- :paip::Ship      b <- :paip::Ship]     -> :wat::core::String "both-damaged"))

(:wat::core::defn :paip::table-size [] -> :wat::core::i64
  (:wat::core::length (:wat::core::keys (:paip::collide-table))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    a1 (:paip::make-account 100)
                    square (:wat::core::Vector :- [:wat::core::i64] 4)
                    rect (:wat::core::Vector :- [:wat::core::i64] 3 5)
                    circle (:wat::core::Vector :- [:wat::core::i64] 2)]
    (:paip::check-chapter "oracle/paip/ch13-object-oriented.expected"
                          "paip ch13 object oriented"
                          (:wat::core::Vector :- [:wat::core::String]
                            (a1 "balance" 0)
                            (a1 "deposit" 50)
                            (a1 "withdraw" 30)
                            (a1 "withdraw" 500)
                            (a1 "fly" 0)
                            ;; the original is untouched -- each message answers a NEW account
                            (a1 "balance" 0)
                            (:paip::single-dispatch "square" square)
                            (:paip::single-dispatch "rect" rect)
                            (:paip::single-dispatch "circle" circle)
                            (:paip::multi-dispatch "asteroid" "ship")
                            (:paip::multi-dispatch "asteroid" "asteroid")
                            (:paip::multi-dispatch "ship" "ship")
                            ;; the FIRST argument is the same and the answers differ: the point
                            (:paip::b (:wat::core::= (:paip::multi-dispatch "asteroid" "ship")
                                                     (:paip::multi-dispatch "asteroid" "asteroid")))
                            (:paip::multi-dispatch "ship" "asteroid")
                            (int (:paip::table-size))
                            ;; the same three, produced by defclause rather than by the table --
                            ;; the two mechanisms must agree
                            (:paip::collide (:paip::Asteroid) (:paip::Ship))
                            (:paip::collide (:paip::Asteroid) (:paip::Asteroid))
                            (:paip::collide (:paip::Ship) (:paip::Ship))))))
