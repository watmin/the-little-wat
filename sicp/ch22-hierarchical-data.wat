;; SICP §2.2 (hierarchical data and the closure property), in wat.
;;
;; The section's subject is the CLOSURE PROPERTY: a means of combining that produces things which
;; can themselves be combined, so `((1 2) (3 4) 5)` is a list whose elements are sometimes numbers
;; and sometimes lists.
;;
;; That is the one place SICP's Scheme and wat genuinely differ, and it is worth stating plainly
;; rather than working around quietly. In Scheme the closure property comes for free because a
;; list is untyped -- `car` may answer a number or another list and nothing checks. wat's
;; collections are monomorphic and `:Any` is banned (C-004), so the same structure has to be named:
;;
;;     Tree  ::= Leaf i64 | Node Trees
;;     Trees ::= TNil | TCons Tree Trees
;;
;; This is not a workaround. It is the closure property WRITTEN DOWN -- "an element may itself be
;; a combination" is exactly what the recursive enum says -- and the gain is that `count-leaves`
;; is checked exhaustive, where Scheme's version leans on `pair?` at run time and would answer
;; nonsense for a string. The cost is that the shape must be declared before it can be used, and
;; a genuinely heterogeneous list (numbers and strings together) still needs the quoted-form route
;; of C-004.
;;
;; Flat sequences stay Vectors, since that is what wat's own conventional interface (`mapv`,
;; `filterv`) is built for.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch22-hierarchical-data.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch22-hierarchical-data.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :sicp::IntLists (:wat::core::Vector :- [:sicp::Ints]))

;; ---- the closure property, written down
(:wat::core::defenum :sicp::Tree :wat::enum::Pure
  :Leaf [n <- :wat::core::i64]
  :Node [kids <- :sicp::Trees])

(:wat::core::defenum :sicp::Trees :wat::enum::Pure
  :TNil  []
  :TCons [t <- :sicp::Tree  rest <- :sicp::Trees])

(:wat::core::defn :sicp::count-leaves [t <- :sicp::Tree] -> :wat::core::i64
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} 1]
    [:sicp::Tree.Node {:kids kids} (:sicp::count-leaves* kids)]))

(:wat::core::defn :sicp::count-leaves* [ts <- :sicp::Trees] -> :wat::core::i64
  (:wat::core::match ts
    [:sicp::Trees.TNil {} 0]
    [:sicp::Trees.TCons {:t t :rest rest}
      (:wat::core::+ (:sicp::count-leaves t) (:sicp::count-leaves* rest))]))

(:wat::core::defn :sicp::kid-count [t <- :sicp::Tree] -> :wat::core::i64
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} 1]
    [:sicp::Tree.Node {:kids kids} (:sicp::len* kids)]))

(:wat::core::defn :sicp::len* [ts <- :sicp::Trees] -> :wat::core::i64
  (:wat::core::match ts
    [:sicp::Trees.TNil {} 0]
    [:sicp::Trees.TCons {:t t :rest rest} (:wat::core::+ 1 (:sicp::len* rest))]))

;; fringe: every leaf, left to right, however deep
(:wat::core::defn :sicp::fringe [t <- :sicp::Tree] -> :sicp::Ints
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} (:wat::core::Vector :- [:wat::core::i64] n)]
    [:sicp::Tree.Node {:kids kids} (:sicp::fringe* kids)]))

(:wat::core::defn :sicp::fringe* [ts <- :sicp::Trees] -> :sicp::Ints
  (:wat::core::match ts
    [:sicp::Trees.TNil {} (:wat::core::Vector :- [:wat::core::i64])]
    [:sicp::Trees.TCons {:t t :rest rest}
      (:wat::core::concat (:sicp::fringe t) (:sicp::fringe* rest))]))

;; deep-reverse: reverse at every level
(:wat::core::defn :sicp::rev* [ts <- :sicp::Trees acc <- :sicp::Trees] -> :sicp::Trees
  (:wat::core::match ts
    [:sicp::Trees.TNil {} acc]
    [:sicp::Trees.TCons {:t t :rest rest}
      (:sicp::rev* rest (:sicp::Trees.TCons {:t (:sicp::deep-reverse t) :rest acc}))]))

(:wat::core::defn :sicp::deep-reverse [t <- :sicp::Tree] -> :sicp::Tree
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} t]
    [:sicp::Tree.Node {:kids kids} (:sicp::Tree.Node {:kids (:sicp::rev* kids (:sicp::Trees.TNil {}))})]))

(:wat::core::defn :sicp::scale-tree [t <- :sicp::Tree factor <- :wat::core::i64] -> :sicp::Tree
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} (:sicp::Tree.Leaf {:n (:wat::core::* n factor)})]
    [:sicp::Tree.Node {:kids kids} (:sicp::Tree.Node {:kids (:sicp::scale* kids factor)})]))

(:wat::core::defn :sicp::scale* [ts <- :sicp::Trees factor <- :wat::core::i64] -> :sicp::Trees
  (:wat::core::match ts
    [:sicp::Trees.TNil {} ts]
    [:sicp::Trees.TCons {:t t :rest rest}
      (:sicp::Trees.TCons {:t (:sicp::scale-tree t factor) :rest (:sicp::scale* rest factor)})]))

;; ---- flat sequences: the conventional interface
(:wat::core::defn :sicp::square [x <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* x x))
(:wat::core::defn :sicp::odd-int? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 1 (:wat::i64::rem n 2)))

(:wat::core::defn :sicp::accumulate
  [op <- [:wat::core::i64 :wat::core::i64 :-> :wat::core::i64] init <- :wat::core::i64 seq <- :sicp::Ints]
  -> :wat::core::i64
  (:wat::core::if (:wat::core::empty? seq) init
    (op (:wat::core::first seq) (:sicp::accumulate op init (:wat::core::rest seq)))))

(:wat::core::defn :sicp::plus [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::+ a b))
(:wat::core::defn :sicp::times [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b))

(:wat::core::defn :sicp::enumerate-interval [low <- :wat::core::i64 high <- :wat::core::i64] -> :sicp::Ints
  (:wat::core::if (:wat::core::> low high) (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] low)
      (:sicp::enumerate-interval (:wat::core::+ low 1) high))))

(:wat::core::defn :sicp::sum-odd-squares [seq <- :sicp::Ints] -> :wat::core::i64
  (:sicp::accumulate :sicp::plus 0 (:wat::core::mapv :sicp::square (:wat::core::filterv :sicp::odd-int? seq))))

;; ---- nested mappings
(:wat::core::defn :sicp::divides? [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::= 0 (:wat::i64::rem b a)))

(:wat::core::defn :sicp::find-div [n <- :wat::core::i64 t <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::> (:wat::core::* t t) n) n
    (:wat::core::if (:sicp::divides? t n) t (:sicp::find-div n (:wat::core::+ t 1)))))

(:wat::core::defn :sicp::prime? [n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::and (:wat::core::> n 1) (:wat::core::= n (:sicp::find-div n 2))))

;; pairs (i,j) with i>j, drawn from 1..n
(:wat::core::defn :sicp::pairs-for [i <- :wat::core::i64 j <- :wat::core::i64 acc <- :sicp::IntLists] -> :sicp::IntLists
  (:wat::core::if (:wat::core::>= j i) acc
    (:sicp::pairs-for i (:wat::core::+ j 1)
      (:wat::core::conj acc (:wat::core::Vector :- [:wat::core::i64] i j)))))

(:wat::core::defn :sicp::unique-pairs-from [i <- :wat::core::i64 n <- :wat::core::i64 acc <- :sicp::IntLists] -> :sicp::IntLists
  (:wat::core::if (:wat::core::> i n) acc
    (:sicp::unique-pairs-from (:wat::core::+ i 1) n (:sicp::pairs-for i 1 acc))))

(:wat::core::defn :sicp::unique-pairs [n <- :wat::core::i64] -> :sicp::IntLists
  (:sicp::unique-pairs-from 1 n (:wat::core::Vector :- [:sicp::Ints])))

(:wat::core::defn :sicp::pair-sum-prime? [p <- :sicp::Ints] -> :wat::core::bool
  (:sicp::prime? (:wat::core::+ (:wat::core::nth p 0) (:wat::core::nth p 1))))

(:wat::core::defn :sicp::with-sum [p <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::conj p (:wat::core::+ (:wat::core::nth p 0) (:wat::core::nth p 1))))

(:wat::core::defn :sicp::prime-sum-pairs [n <- :wat::core::i64] -> :sicp::IntLists
  (:wat::core::mapv :sicp::with-sum (:wat::core::filterv :sicp::pair-sum-prime? (:sicp::unique-pairs n))))

;; permutations
(:wat::core::defn :sicp::without [x <- :wat::core::i64 seq <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::filterv (:wat::core::fn [y <- :wat::core::i64] -> :wat::core::bool
                         (:wat::core::not (:wat::core::= y x))) seq))

(:wat::core::defn :sicp::prepend-all [x <- :wat::core::i64 ps <- :sicp::IntLists] -> :sicp::IntLists
  (:wat::core::mapv (:wat::core::fn [p <- :sicp::Ints] -> :sicp::Ints
                      (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] x) p)) ps))

(:wat::core::defn :sicp::perms-from [s <- :sicp::Ints i <- :wat::core::i64 acc <- :sicp::IntLists] -> :sicp::IntLists
  (:wat::core::if (:wat::core::>= i (:wat::core::length s)) acc
    (:wat::core::let [x (:wat::core::nth s i)]
      (:sicp::perms-from s (:wat::core::+ i 1)
        (:wat::core::concat acc (:sicp::prepend-all x (:sicp::permutations (:sicp::without x s))))))))

(:wat::core::defn :sicp::permutations [s <- :sicp::Ints] -> :sicp::IntLists
  (:wat::core::if (:wat::core::empty? s)
    (:wat::core::Vector :- [:sicp::Ints] (:wat::core::Vector :- [:wat::core::i64]))
    (:sicp::perms-from s 0 (:wat::core::Vector :- [:sicp::Ints]))))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::show-ints [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :sicp::show-lists [xs <- :sicp::IntLists] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv :sicp::show-ints xs)) ")"))

(:wat::core::defn :sicp::show-tree [t <- :sicp::Tree] -> :wat::core::String
  (:wat::core::match t
    [:sicp::Tree.Leaf {:n n} (:wat::i64::to-string n)]
    [:sicp::Tree.Node {:kids kids} (:wat::string::concat "(" (:sicp::show* kids) ")")]))

(:wat::core::defn :sicp::show* [ts <- :sicp::Trees] -> :wat::core::String
  (:wat::core::match ts
    [:sicp::Trees.TNil {} ""]
    [:sicp::Trees.TCons {:t t :rest rest}
      (:wat::core::match rest
        [:sicp::Trees.TNil {} (:sicp::show-tree t)]
        [:sicp::Trees.TCons {:t t2 :rest r2}
          (:wat::string::concat (:sicp::show-tree t) " " (:sicp::show* rest))])]))

;; ---- builders for the two test trees
(:wat::core::defn :sicp::leaf [n <- :wat::core::i64] -> :sicp::Tree (:sicp::Tree.Leaf {:n n}))

(:wat::core::defn :sicp::node2 [a <- :sicp::Tree b <- :sicp::Tree] -> :sicp::Tree
  (:sicp::Tree.Node {:kids (:sicp::Trees.TCons {:t a :rest (:sicp::Trees.TCons {:t b :rest (:sicp::Trees.TNil {})})})}))

(:wat::core::defn :sicp::node1 [a <- :sicp::Tree] -> :sicp::Tree
  (:sicp::Tree.Node {:kids (:sicp::Trees.TCons {:t a :rest (:sicp::Trees.TNil {})})}))

(:wat::core::defn :sicp::node3 [a <- :sicp::Tree b <- :sicp::Tree c <- :sicp::Tree] -> :sicp::Tree
  (:sicp::Tree.Node {:kids (:sicp::Trees.TCons {:t a :rest (:sicp::Trees.TCons {:t b :rest (:sicp::Trees.TCons {:t c :rest (:sicp::Trees.TNil {})})})})}))

;; ((1 2) (3 4) 5)
(:wat::core::defn :sicp::t1 [] -> :sicp::Tree
  (:sicp::node3 (:sicp::node2 (:sicp::leaf 1) (:sicp::leaf 2))
                (:sicp::node2 (:sicp::leaf 3) (:sicp::leaf 4))
                (:sicp::leaf 5)))

;; (1 (2 (3 (4 (5)))))
(:wat::core::defn :sicp::t2 [] -> :sicp::Tree
  (:sicp::node2 (:sicp::leaf 1)
    (:sicp::node2 (:sicp::leaf 2)
      (:sicp::node2 (:sicp::leaf 3)
        (:sicp::node2 (:sicp::leaf 4) (:sicp::node1 (:sicp::leaf 5)))))))

;; ((1 2) (3 4))
(:wat::core::defn :sicp::t3 [] -> :sicp::Tree
  (:sicp::node2 (:sicp::node2 (:sicp::leaf 1) (:sicp::leaf 2))
                (:sicp::node2 (:sicp::leaf 3) (:sicp::leaf 4))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string n))
                    five (:sicp::enumerate-interval 1 5)
                    seven (:sicp::enumerate-interval 1 7)]
    (:sicp::check-chapter "oracle/sicp/ch22-hierarchical-data.expected"
                          "sicp ch22 hierarchical data"
                          (:wat::core::Vector :- [:wat::core::String]
                            (int (:wat::core::length five))
                            (:sicp::show-ints (:wat::core::concat (:sicp::enumerate-interval 1 3)
                                                                    (:sicp::enumerate-interval 4 5)))
                            (:sicp::show-ints (:wat::core::Vector :- [:wat::core::i64] 5 4 3 2 1))
                            (int (:sicp::count-leaves (:sicp::t1)))
                            (int (:sicp::count-leaves (:sicp::t2)))
                            (int (:sicp::kid-count (:sicp::t1)))
                            (:sicp::show-ints (:sicp::fringe (:sicp::t1)))
                            (:sicp::show-ints (:sicp::fringe (:sicp::t2)))
                            (:sicp::show-tree (:sicp::deep-reverse (:sicp::t3)))
                            (:sicp::show-tree (:sicp::scale-tree (:sicp::t1) 10))
                            (:sicp::show-ints (:wat::core::mapv :sicp::square five))
                            (:sicp::show-ints (:wat::core::filterv :sicp::odd-int? five))
                            (int (:sicp::accumulate :sicp::plus 0 five))
                            (int (:sicp::accumulate :sicp::times 1 five))
                            (:sicp::show-ints (:sicp::enumerate-interval 2 7))
                            (int (:sicp::sum-odd-squares seven))
                            (:sicp::show-lists (:sicp::unique-pairs 4))
                            (:sicp::show-lists (:sicp::prime-sum-pairs 6))
                            (:sicp::show-lists (:sicp::permutations (:sicp::enumerate-interval 1 3)))
                            (int (:wat::core::length (:sicp::permutations (:sicp::enumerate-interval 1 4))))))))
