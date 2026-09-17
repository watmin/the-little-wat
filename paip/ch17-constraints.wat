;; PAIP chapter 17 (labeling by constraint satisfaction), in wat.
;;
;; Waltz filtering. Lines are variables, their possible labels are domains, and each junction is a
;; catalogue of the label combinations it permits. Filtering removes from every domain the labels
;; that no permitted combination supports, and repeats until nothing changes.
;;
;; The chapter's claim is that propagation ALONE -- no search, no backtracking -- often decides the
;; problem, and the three outcomes are all tested:
;;
;;     decided       12 possibilities collapse to 3: a=+, b=R, c=-, one interpretation
;;     impossible    a diagram with no consistent labeling empties every domain, total 0
;;     ambiguous     a diagram propagation cannot decide leaves 2x2 standing, and would need search
;;
;; The third is the honest one. A single junction on its own removes nothing here -- the domains
;; are still (4 4 4) after it -- because every label is supported by some pair. Propagation earns
;; its keep from the INTERACTION of constraints, not from any one of them.
;;
;; **F-104, seventh workload.** Narrowing a domain means replacing one element of a vector of
;; domains, and neither vector type has a positional update, so `set-dom` rebuilds the whole
;; vector. Constraint propagation is a loop whose entire job is *change one cell, repeat*, which
;; makes it the purest example yet -- and it joins the list in C-086: a game board, a store, a
;; collector's memory, a register machine's stack, two EOPL stores, and now a constraint network.
;;
;; Results are printed as the Scheme oracle's are (oracle/paip/ch17-constraints.scm, run by
;; tools/paip-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat paip/ch17-constraints.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :paip::Labels (:wat::core::Vector :- [:wat::core::String]))
(:wat::core::typealias :paip::Doms (:wat::core::Vector :- [:paip::Labels]))
(:wat::core::typealias :paip::LineIdx (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :paip::Tuples (:wat::core::Vector :- [:paip::Labels]))

(:wat::core::defstruct :paip::Junction [lines <- :paip::LineIdx  tuples <- :paip::Tuples])
(:wat::core::typealias :paip::Diagram (:wat::core::Vector :- [:paip::Junction]))

(:wat::core::defn :paip::all-labels [] -> :paip::Labels
  (:wat::core::Vector :- [:wat::core::String] "+" "-" "L" "R"))

(:wat::core::defn :paip::member-s? [x <- :wat::core::String v <- :paip::Labels] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? v) false
    (:wat::core::if (:wat::core::= x (:wat::core::first v)) true (:paip::member-s? x (:wat::core::rest v)))))

;; F-104: replacing one domain rebuilds the whole vector
(:wat::core::defn :paip::set-dom [d <- :paip::Doms i <- :wat::core::i64 labels <- :paip::Labels] -> :paip::Doms
  (:paip::set-loop d i labels 0 (:wat::core::Vector :- [:paip::Labels])))

(:wat::core::defn :paip::set-loop [d <- :paip::Doms i <- :wat::core::i64 labels <- :paip::Labels
                                   k <- :wat::core::i64 acc <- :paip::Doms] -> :paip::Doms
  (:wat::core::if (:wat::core::>= k (:wat::core::length d)) acc
    (:paip::set-loop d i labels (:wat::core::+ k 1)
      (:wat::core::conj acc (:wat::core::if (:wat::core::= k i) labels (:wat::core::nth d k))))))

(:wat::core::defn :paip::initial-domains [n <- :wat::core::i64 k <- :wat::core::i64 acc <- :paip::Doms] -> :paip::Doms
  (:wat::core::if (:wat::core::>= k n) acc
    (:paip::initial-domains n (:wat::core::+ k 1) (:wat::core::conj acc (:paip::all-labels)))))

;; a tuple is still possible if every line's label is still in that line's domain
(:wat::core::defn :paip::tuple-ok? [d <- :paip::Doms lines <- :paip::LineIdx tuple <- :paip::Labels i <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::if (:wat::core::>= i (:wat::core::length lines)) true
    (:wat::core::and (:paip::member-s? (:wat::core::nth tuple i)
                       (:wat::core::nth d (:wat::core::nth lines i)))
      (:paip::tuple-ok? d lines tuple (:wat::core::+ i 1)))))

;; the labels this junction still supports for its i-th line
(:wat::core::defn :paip::supported [d <- :paip::Doms j <- :paip::Junction i <- :wat::core::i64] -> :paip::Labels
  (:paip::sup-loop d j i 0 (:wat::core::Vector :- [:wat::core::String])))

(:wat::core::defn :paip::sup-loop [d <- :paip::Doms j <- :paip::Junction i <- :wat::core::i64
                                   t <- :wat::core::i64 acc <- :paip::Labels] -> :paip::Labels
  (:wat::core::let [ts (:paip::Junction/tuples j)]
    (:wat::core::if (:wat::core::>= t (:wat::core::length ts)) acc
      (:wat::core::let [tuple (:wat::core::nth ts t)
                        lab (:wat::core::nth tuple i)]
        (:paip::sup-loop d j i (:wat::core::+ t 1)
          (:wat::core::if (:wat::core::and (:paip::tuple-ok? d (:paip::Junction/lines j) tuple 0)
                            (:wat::core::not (:paip::member-s? lab acc)))
            (:wat::core::conj acc lab) acc))))))

(:wat::core::defn :paip::intersect [a <- :paip::Labels b <- :paip::Labels] -> :paip::Labels
  (:wat::core::filterv (:wat::core::fn [x <- :wat::core::String] -> :wat::core::bool
                         (:paip::member-s? x b)) a))

;; one pass over one junction: narrow each of its lines
(:wat::core::defn :paip::narrow [d <- :paip::Doms j <- :paip::Junction i <- :wat::core::i64] -> :paip::Doms
  (:wat::core::let [ls (:paip::Junction/lines j)]
    (:wat::core::if (:wat::core::>= i (:wat::core::length ls)) d
      (:wat::core::let [line (:wat::core::nth ls i)]
        (:paip::narrow (:paip::set-dom d line
                         (:paip::intersect (:wat::core::nth d line) (:paip::supported d j i)))
          j (:wat::core::+ i 1))))))

(:wat::core::defn :paip::pass [d <- :paip::Doms js <- :paip::Diagram i <- :wat::core::i64] -> :paip::Doms
  (:wat::core::if (:wat::core::>= i (:wat::core::length js)) d
    (:paip::pass (:paip::narrow d (:wat::core::nth js i) 0) js (:wat::core::+ i 1))))

(:wat::core::defn :paip::show-doms [d <- :paip::Doms] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [x <- :paip::Labels] -> :wat::core::String
                                                (:wat::i64::to-string (:wat::core::length x))) d)) ")"))

(:wat::core::defn :paip::fingerprint [d <- :paip::Doms] -> :wat::core::String
  (:wat::string::join "|" (:wat::core::mapv (:wat::core::fn [x <- :paip::Labels] -> :wat::core::String
                                              (:wat::string::join "," x)) d)))

(:wat::core::defn :paip::propagate [d <- :paip::Doms js <- :paip::Diagram] -> :paip::Doms
  (:wat::core::let [d2 (:paip::pass d js 0)]
    (:wat::core::if (:wat::core::= (:paip::fingerprint d) (:paip::fingerprint d2)) d
      (:paip::propagate d2 js))))

(:wat::core::defn :paip::total [d <- :paip::Doms i <- :wat::core::i64 s <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::>= i (:wat::core::length d)) s
    (:paip::total d (:wat::core::+ i 1) (:wat::core::+ s (:wat::core::length (:wat::core::nth d i))))))

(:wat::core::defn :paip::show-labels [x <- :paip::Labels] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " x) ")"))

;; ---- the catalogue
(:wat::core::defn :paip::tup2 [a <- :wat::core::String b <- :wat::core::String] -> :paip::Labels
  (:wat::core::Vector :- [:wat::core::String] a b))
(:wat::core::defn :paip::tup3 [a <- :wat::core::String b <- :wat::core::String c <- :wat::core::String] -> :paip::Labels
  (:wat::core::Vector :- [:wat::core::String] a b c))

(:wat::core::defn :paip::L-pairs [] -> :paip::Tuples
  (:wat::core::Vector :- [:paip::Labels]
    (:paip::tup2 "+" "R") (:paip::tup2 "-" "L") (:paip::tup2 "L" "+") (:paip::tup2 "R" "-")))

;; the fork's third triple is the one consistent with two L junctions in a row:
;; (a,b) = (+ R) is an L pair, and (b,c) = (R -) is an L pair, so (+ R -) can survive
(:wat::core::defn :paip::fork-triples [] -> :paip::Tuples
  (:wat::core::Vector :- [:paip::Labels]
    (:paip::tup3 "+" "+" "+") (:paip::tup3 "-" "-" "-") (:paip::tup3 "+" "R" "-")))

(:wat::core::defn :paip::diagram [] -> :paip::Diagram
  (:wat::core::Vector :- [:paip::Junction]
    (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 0 1) :tuples (:paip::L-pairs))
    (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 1 2) :tuples (:paip::L-pairs))
    (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 0 1 2) :tuples (:paip::fork-triples))))

(:wat::core::defn :paip::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    start (:paip::initial-domains 3 0 (:wat::core::Vector :- [:paip::Labels]))
                    one-j (:wat::core::Vector :- [:paip::Junction] (:wat::core::nth (:paip::diagram) 0))
                    final (:paip::propagate start (:paip::diagram))
                    two (:paip::initial-domains 2 0 (:wat::core::Vector :- [:paip::Labels]))
                    impossible (:wat::core::Vector :- [:paip::Junction]
                                 (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 0 1)
                                                  :tuples (:wat::core::Vector :- [:paip::Labels] (:paip::tup2 "+" "+")))
                                 (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 0 1)
                                                  :tuples (:wat::core::Vector :- [:paip::Labels] (:paip::tup2 "-" "-"))))
                    bad (:paip::propagate two impossible)
                    ambiguous (:wat::core::Vector :- [:paip::Junction]
                                (:paip::Junction :lines (:wat::core::Vector :- [:wat::core::i64] 0 1)
                                                 :tuples (:wat::core::Vector :- [:paip::Labels]
                                                           (:paip::tup2 "+" "+") (:paip::tup2 "-" "-"))))
                    amb (:paip::propagate two ambiguous)]
    (:paip::check-chapter "oracle/paip/ch17-constraints.expected"
                          "paip ch17 constraints"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:paip::total start 0 0))
                            (:paip::show-doms start)
                            ;; one junction alone removes nothing here
                            (:paip::show-doms (:paip::pass start one-j 0))
                            (:paip::show-doms final)
                            (int (:paip::total final 0 0))
                            (:paip::show-labels (:wat::core::nth final 0))
                            (:paip::show-labels (:wat::core::nth final 1))
                            (:paip::show-labels (:wat::core::nth final 2))
                            (:paip::b (:wat::core::< (:paip::total final 0 0) (:paip::total start 0 0)))
                            (:paip::b (:wat::core::= 3 (:paip::total final 0 0)))
                            ;; no consistent labeling: every domain empties
                            (:paip::show-doms bad)
                            (int (:paip::total bad 0 0))
                            (:paip::b (:wat::core::= 0 (:paip::total bad 0 0)))
                            ;; propagation cannot decide this one
                            (:paip::show-doms amb)
                            (:paip::show-labels (:wat::core::nth amb 0))
                            (:paip::b (:wat::core::> (:paip::total amb 0 0) 2))))))
