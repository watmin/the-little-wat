;; SICP §2.3 (symbolic data), in wat.
;;
;; Three things live here, and each says something different about the port.
;;
;; SYMBOLIC DIFFERENTIATION. SICP represents an expression as a tagged list and asks `pair?`,
;; `symbol?` and `number?` at run time. wat's counterpart is an enum, and the difference is that
;; `deriv`'s dispatch is then CHECKED EXHAUSTIVE -- SICP's version ends in `(else (error "unknown
;; expression"))`, a case the reader is told to worry about and the compiler never sees. The
;; simplifying constructors (`make-sum`, `make-product`) are the section's real lesson and port
;; unchanged: folding `0 + x` to `x` in the CONSTRUCTOR is what keeps the answers readable.
;;
;; SETS, THREE WAYS. Unordered list, ordered list, binary tree -- one interface, three costs. This
;; is Okasaki ch2 (C-051) arrived at from the other direction, and it is also where **F-057**
;; bites: wat has no persistent SET, so an unordered set is a `Vector` and membership is a scan,
;; exactly as SICP writes it by hand.
;;
;; HUFFMAN TREES. A tree whose leaves carry a symbol and a weight, decoded bit by bit. The symbols
;; are Strings here rather than interned symbols, which costs nothing because the only operation
;; is equality.
;;
;; Results are printed as the Scheme oracle's are (oracle/sicp/ch23-symbolic-data.scm, run by
;; tools/sicp-oracle.sh), and every one must match, in order.
;;
;; Run from the repository root (it reads files by path):
;;   wat sicp/ch23-symbolic-data.wat

(:wat::load-file! "lib/check.wat")

(:wat::core::typealias :sicp::Ints (:wat::core::Vector :- [:wat::core::i64]))
(:wat::core::typealias :sicp::Syms (:wat::core::Vector :- [:wat::core::String]))

;; ---- expressions as data
(:wat::core::defenum :sicp::Expr :wat::enum::Pure
  :Num  [n <- :wat::core::i64]
  :Var  [name <- :wat::core::String]
  :Sum  [a <- :sicp::Expr  b <- :sicp::Expr]
  :Prod [a <- :sicp::Expr  b <- :sicp::Expr])

(:wat::core::defn :sicp::num? [e <- :sicp::Expr n <- :wat::core::i64] -> :wat::core::bool
  (:wat::core::match e
    [:sicp::Expr.Num {:n m} (:wat::core::= m n)]
    [:sicp::Expr.Var {:name name} false]
    [:sicp::Expr.Sum {:a a :b b} false]
    [:sicp::Expr.Prod {:a a :b b} false]))

(:wat::core::defn :sicp::as-num [e <- :sicp::Expr] -> (:wat::core::Option :- [:wat::core::i64])
  (:wat::core::match e
    [:sicp::Expr.Num {:n m} (:wat::core::Option.Some {:value m})]
    [:sicp::Expr.Var {:name name} (:wat::core::Option.None {})]
    [:sicp::Expr.Sum {:a a :b b} (:wat::core::Option.None {})]
    [:sicp::Expr.Prod {:a a :b b} (:wat::core::Option.None {})]))

;; the simplifying constructors: the section's actual lesson
(:wat::core::defn :sicp::make-sum [a <- :sicp::Expr b <- :sicp::Expr] -> :sicp::Expr
  (:wat::core::if (:sicp::num? a 0) b
    (:wat::core::if (:sicp::num? b 0) a
      (:wat::core::match (:sicp::as-num a)
        [:wat::core::Option.Some {:value x}
          (:wat::core::match (:sicp::as-num b)
            [:wat::core::Option.Some {:value y} (:sicp::Expr.Num {:n (:wat::core::+ x y)})]
            [:wat::core::Option.None {} (:sicp::Expr.Sum {:a a :b b})])]
        [:wat::core::Option.None {} (:sicp::Expr.Sum {:a a :b b})]))))

(:wat::core::defn :sicp::make-product [a <- :sicp::Expr b <- :sicp::Expr] -> :sicp::Expr
  (:wat::core::if (:wat::core::or (:sicp::num? a 0) (:sicp::num? b 0)) (:sicp::Expr.Num {:n 0})
    (:wat::core::if (:sicp::num? a 1) b
      (:wat::core::if (:sicp::num? b 1) a
        (:wat::core::match (:sicp::as-num a)
          [:wat::core::Option.Some {:value x}
            (:wat::core::match (:sicp::as-num b)
              [:wat::core::Option.Some {:value y} (:sicp::Expr.Num {:n (:wat::core::* x y)})]
              [:wat::core::Option.None {} (:sicp::Expr.Prod {:a a :b b})])]
          [:wat::core::Option.None {} (:sicp::Expr.Prod {:a a :b b})])))))

;; exhaustive: there is no `else (error ...)` arm, because there is no fifth shape
(:wat::core::defn :sicp::deriv [e <- :sicp::Expr var <- :wat::core::String] -> :sicp::Expr
  (:wat::core::match e
    [:sicp::Expr.Num {:n n} (:sicp::Expr.Num {:n 0})]
    [:sicp::Expr.Var {:name name}
      (:sicp::Expr.Num {:n (:wat::core::if (:wat::core::= name var) 1 0)})]
    [:sicp::Expr.Sum {:a a :b b}
      (:sicp::make-sum (:sicp::deriv a var) (:sicp::deriv b var))]
    [:sicp::Expr.Prod {:a a :b b}
      (:sicp::make-sum (:sicp::make-product a (:sicp::deriv b var))
                       (:sicp::make-product (:sicp::deriv a var) b))]))

(:wat::core::defn :sicp::show-expr [e <- :sicp::Expr] -> :wat::core::String
  (:wat::core::match e
    [:sicp::Expr.Num {:n n} (:wat::i64::to-string n)]
    [:sicp::Expr.Var {:name name} name]
    [:sicp::Expr.Sum {:a a :b b}
      (:wat::string::concat "(+ " (:sicp::show-expr a) " " (:sicp::show-expr b) ")")]
    [:sicp::Expr.Prod {:a a :b b}
      (:wat::string::concat "(* " (:sicp::show-expr a) " " (:sicp::show-expr b) ")")]))

;; ---- sets, representation 1: an unordered list (F-057: there is no persistent set)
(:wat::core::defn :sicp::element-of-set? [x <- :wat::core::i64 s <- :sicp::Ints] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? s) false
    (:wat::core::if (:wat::core::= x (:wat::core::first s)) true
      (:sicp::element-of-set? x (:wat::core::rest s)))))

(:wat::core::defn :sicp::adjoin-set [x <- :wat::core::i64 s <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::if (:sicp::element-of-set? x s) s
    (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] x) s)))

(:wat::core::defn :sicp::intersection-set [s1 <- :sicp::Ints s2 <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::if (:wat::core::or (:wat::core::empty? s1) (:wat::core::empty? s2))
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::if (:sicp::element-of-set? (:wat::core::first s1) s2)
      (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] (:wat::core::first s1))
                          (:sicp::intersection-set (:wat::core::rest s1) s2))
      (:sicp::intersection-set (:wat::core::rest s1) s2))))

;; ---- representation 2: an ORDERED list, so a miss can stop early
(:wat::core::defn :sicp::element-of-oset? [x <- :wat::core::i64 s <- :sicp::Ints] -> :wat::core::bool
  (:wat::core::if (:wat::core::empty? s) false
    (:wat::core::if (:wat::core::= x (:wat::core::first s)) true
      (:wat::core::if (:wat::core::< x (:wat::core::first s)) false
        (:sicp::element-of-oset? x (:wat::core::rest s))))))

(:wat::core::defn :sicp::intersection-oset [s1 <- :sicp::Ints s2 <- :sicp::Ints] -> :sicp::Ints
  (:wat::core::if (:wat::core::or (:wat::core::empty? s1) (:wat::core::empty? s2))
    (:wat::core::Vector :- [:wat::core::i64])
    (:wat::core::let [x1 (:wat::core::first s1) x2 (:wat::core::first s2)]
      (:wat::core::if (:wat::core::= x1 x2)
        (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] x1)
                            (:sicp::intersection-oset (:wat::core::rest s1) (:wat::core::rest s2)))
        (:wat::core::if (:wat::core::< x1 x2)
          (:sicp::intersection-oset (:wat::core::rest s1) s2)
          (:sicp::intersection-oset s1 (:wat::core::rest s2)))))))

;; ---- representation 3: a binary tree, so lookup is logarithmic
(:wat::core::defenum :sicp::TSet :wat::enum::Pure
  :Empty []
  :Node  [entry <- :wat::core::i64  left <- :sicp::TSet  right <- :sicp::TSet])

(:wat::core::defn :sicp::element-of-tset? [x <- :wat::core::i64 s <- :sicp::TSet] -> :wat::core::bool
  (:wat::core::match s
    [:sicp::TSet.Empty {} false]
    [:sicp::TSet.Node {:entry e :left l :right r}
      (:wat::core::if (:wat::core::= x e) true
        (:wat::core::if (:wat::core::< x e) (:sicp::element-of-tset? x l)
          (:sicp::element-of-tset? x r)))]))

(:wat::core::defn :sicp::adjoin-tset [x <- :wat::core::i64 s <- :sicp::TSet] -> :sicp::TSet
  (:wat::core::match s
    [:sicp::TSet.Empty {} (:sicp::TSet.Node {:entry x :left (:sicp::TSet.Empty {}) :right (:sicp::TSet.Empty {})})]
    [:sicp::TSet.Node {:entry e :left l :right r}
      (:wat::core::if (:wat::core::= x e) s
        (:wat::core::if (:wat::core::< x e)
          (:sicp::TSet.Node {:entry e :left (:sicp::adjoin-tset x l) :right r})
          (:sicp::TSet.Node {:entry e :left l :right (:sicp::adjoin-tset x r)})))]))

(:wat::core::defn :sicp::tset->list [s <- :sicp::TSet] -> :sicp::Ints
  (:wat::core::match s
    [:sicp::TSet.Empty {} (:wat::core::Vector :- [:wat::core::i64])]
    [:sicp::TSet.Node {:entry e :left l :right r}
      (:wat::core::concat (:sicp::tset->list l)
        (:wat::core::concat (:wat::core::Vector :- [:wat::core::i64] e) (:sicp::tset->list r)))]))

;; ---- Huffman trees
(:wat::core::defenum :sicp::HTree :wat::enum::Pure
  :Leaf   [sym <- :wat::core::String  weight <- :wat::core::i64]
  :Branch [left <- :sicp::HTree  right <- :sicp::HTree
           syms <- :sicp::Syms  weight <- :wat::core::i64])

(:wat::core::defn :sicp::h-symbols [t <- :sicp::HTree] -> :sicp::Syms
  (:wat::core::match t
    [:sicp::HTree.Leaf {:sym s :weight w} (:wat::core::Vector :- [:wat::core::String] s)]
    [:sicp::HTree.Branch {:left l :right r :syms syms :weight w} syms]))

(:wat::core::defn :sicp::h-weight [t <- :sicp::HTree] -> :wat::core::i64
  (:wat::core::match t
    [:sicp::HTree.Leaf {:sym s :weight w} w]
    [:sicp::HTree.Branch {:left l :right r :syms syms :weight w} w]))

(:wat::core::defn :sicp::make-code-tree [l <- :sicp::HTree r <- :sicp::HTree] -> :sicp::HTree
  (:sicp::HTree.Branch {:left l :right r
                        :syms (:wat::core::concat (:sicp::h-symbols l) (:sicp::h-symbols r))
                        :weight (:wat::core::+ (:sicp::h-weight l) (:sicp::h-weight r))}))

(:wat::core::defn :sicp::choose-branch [bit <- :wat::core::i64 t <- :sicp::HTree] -> :sicp::HTree
  (:wat::core::match t
    [:sicp::HTree.Leaf {:sym s :weight w} t]
    [:sicp::HTree.Branch {:left l :right r :syms syms :weight w}
      (:wat::core::if (:wat::core::= bit 0) l r)]))

(:wat::core::defn :sicp::leaf-sym [t <- :sicp::HTree] -> (:wat::core::Option :- [:wat::core::String])
  (:wat::core::match t
    [:sicp::HTree.Leaf {:sym s :weight w} (:wat::core::Option.Some {:value s})]
    [:sicp::HTree.Branch {:left l :right r :syms syms :weight w} (:wat::core::Option.None {})]))

(:wat::core::defn :sicp::decode-1
  [bits <- :sicp::Ints current <- :sicp::HTree top <- :sicp::HTree acc <- :sicp::Syms] -> :sicp::Syms
  (:wat::core::if (:wat::core::empty? bits) acc
    (:wat::core::let [next (:sicp::choose-branch (:wat::core::first bits) current)]
      (:wat::core::match (:sicp::leaf-sym next)
        [:wat::core::Option.Some {:value s}
          (:sicp::decode-1 (:wat::core::rest bits) top top (:wat::core::conj acc s))]
        [:wat::core::Option.None {}
          (:sicp::decode-1 (:wat::core::rest bits) next top acc)]))))

(:wat::core::defn :sicp::decode [bits <- :sicp::Ints tree <- :sicp::HTree] -> :sicp::Syms
  (:sicp::decode-1 bits tree tree (:wat::core::Vector :- [:wat::core::String])))

;; ---- printing, as the Scheme oracle prints
(:wat::core::defn :sicp::b [v <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if v "#t" "#f"))

(:wat::core::defn :sicp::show-ints [xs <- :sicp::Ints] -> :wat::core::String
  (:wat::string::concat "("
    (:wat::string::join " " (:wat::core::mapv (:wat::core::fn [n <- :wat::core::i64] -> :wat::core::String
                                                (:wat::i64::to-string n)) xs)) ")"))

(:wat::core::defn :sicp::show-syms [xs <- :sicp::Syms] -> :wat::core::String
  (:wat::string::concat "(" (:wat::string::join " " xs) ")"))

(:wat::core::defn :sicp::v [name <- :wat::core::String] -> :sicp::Expr (:sicp::Expr.Var {:name name}))
(:wat::core::defn :sicp::n [k <- :wat::core::i64] -> :sicp::Expr (:sicp::Expr.Num {:n k}))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [int (:wat::core::fn [k <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string k))
                    x (:sicp::v "x") y (:sicp::v "y")
                    ;; (+ x 3), (* x y), (* (* x y) (+ x 3)), (+ x x), (* x x)
                    e1 (:sicp::Expr.Sum {:a x :b (:sicp::n 3)})
                    e2 (:sicp::Expr.Prod {:a x :b y})
                    e3 (:sicp::Expr.Prod {:a e2 :b e1})
                    e4 (:sicp::Expr.Sum {:a x :b x})
                    e5 (:sicp::Expr.Prod {:a x :b x})
                    set1 (:wat::core::Vector :- [:wat::core::i64] 1 2 3 4)
                    set2 (:wat::core::Vector :- [:wat::core::i64] 3 4 5 6)
                    set3 (:wat::core::Vector :- [:wat::core::i64] 1 2 3)
                    t1 (:sicp::adjoin-tset 1 (:sicp::adjoin-tset 9 (:sicp::adjoin-tset 3
                         (:sicp::adjoin-tset 7 (:sicp::adjoin-tset 5 (:sicp::TSet.Empty {}))))))
                    sample (:sicp::make-code-tree (:sicp::HTree.Leaf {:sym "a" :weight 4})
                             (:sicp::make-code-tree (:sicp::HTree.Leaf {:sym "b" :weight 2})
                               (:sicp::make-code-tree (:sicp::HTree.Leaf {:sym "d" :weight 1})
                                                      (:sicp::HTree.Leaf {:sym "c" :weight 1}))))
                    bits (:wat::core::Vector :- [:wat::core::i64] 0 1 1 0 0 1 0 1 0 1 1 1 0)]
    (:sicp::check-chapter "oracle/sicp/ch23-symbolic-data.expected"
                          "sicp ch23 symbolic data"
                          (:wat::core::Vector :- [:wat::core::String]
                            (:sicp::show-expr (:sicp::deriv e1 "x"))
                            (:sicp::show-expr (:sicp::deriv e2 "x"))
                            (:sicp::show-expr (:sicp::deriv e3 "x"))
                            (:sicp::show-expr (:sicp::deriv e4 "x"))
                            (:sicp::show-expr (:sicp::deriv e5 "x"))
                            (:sicp::show-expr (:sicp::deriv (:sicp::n 5) "x"))
                            (:sicp::show-expr (:sicp::deriv y "x"))
                            (:sicp::show-expr (:sicp::make-sum (:sicp::n 0) x))
                            (:sicp::show-expr (:sicp::make-product (:sicp::n 1) x))
                            (:sicp::show-expr (:sicp::make-product (:sicp::n 0) x))
                            (:sicp::show-expr (:sicp::make-sum (:sicp::n 2) (:sicp::n 3)))
                            (:sicp::b (:sicp::element-of-set? 3 set1))
                            (:sicp::b (:sicp::element-of-set? 9 set1))
                            (:sicp::show-ints (:sicp::adjoin-set 5 set3))
                            (:sicp::show-ints (:sicp::adjoin-set 2 set3))
                            (:sicp::show-ints (:sicp::intersection-set set1 set2))
                            (:sicp::b (:sicp::element-of-oset? 3 set1))
                            (:sicp::b (:sicp::element-of-oset? 9 set1))
                            (:sicp::show-ints (:sicp::intersection-oset set1 set2))
                            (:sicp::b (:sicp::element-of-tset? 3 t1))
                            (:sicp::b (:sicp::element-of-tset? 4 t1))
                            (:sicp::show-ints (:sicp::tset->list t1))
                            (int (:sicp::h-weight sample))
                            (:sicp::show-syms (:sicp::h-symbols sample))
                            (:sicp::show-syms (:sicp::decode bits sample))
                            (:sicp::show-syms (:sicp::decode (:wat::core::Vector :- [:wat::core::i64] 0 0 0) sample))
                            (:sicp::show-syms (:sicp::decode (:wat::core::Vector :- [:wat::core::i64] 1 1 1 1 1 0) sample))))))
