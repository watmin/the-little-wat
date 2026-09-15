;; probes/typer/value-copy-cost.wat: which wat values are copied when they are passed or
;; taken apart, and which are shared? Times 2000 repetitions of each operation on a big
;; value and on a small one. (ast-children-cost.wat showed ast->children copies subtrees.)
;; - a WatAST passed through an identity function, and asked its ast-kind;
;; - a native Pure enum tree whose two children are the same value: depth 16 is 65536
;;   nodes if copied, 16 if shared. Its build time and its root's match are timed.

(:wat::core::defn :probe::mk [kids <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::with-children (:wat::core::quote (t)) kids))

(:wat::core::defn :probe::leaves [n <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::WatAST])] -> (:wat::core::Vector :- [:wat::WatAST])
  (:wat::core::if (:wat::core::= n 0) acc (:probe::leaves (:wat::core::- n 1) (:wat::core::conj acc (:wat::core::symbol-node "leaf")))))

(:wat::core::defn :probe::deep [d <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= d 0)
    (:wat::core::symbol-node "bottom")
    (:probe::mk (:wat::core::conj (:probe::leaves 40 (:wat::core::Vector :- [:wat::WatAST])) (:probe::deep (:wat::core::- d 1))))))

(:wat::core::defn :probe::id [x <- :wat::WatAST] -> :wat::WatAST x)

(:wat::core::defn :probe::spin-id [n <- :wat::core::i64 node <- :wat::WatAST acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::spin-id (:wat::core::- n 1) node (:wat::core::+ acc (:wat::string::length (:wat::core::ast-kind (:probe::id node)))))))

(:wat::core::defenum :probe::T :wat::enum::Pure
  :Leaf []
  :Node [l <- :probe::T  r <- :probe::T])

(:wat::core::defn :probe::tree [d <- :wat::core::i64] -> :probe::T
  (:wat::core::if (:wat::core::= d 0)
    (:probe::T.Leaf {})
    (:wat::core::let [s (:probe::tree (:wat::core::- d 1))]
      (:probe::T.Node {:l s :r s}))))

(:wat::core::defn :probe::depth-left [t <- :probe::T] -> :wat::core::i64
  (:wat::core::match t
    [:probe::T.Leaf {} 0]
    [:probe::T.Node {:l l :r r} 1]))

(:wat::core::defn :probe::spin-match [n <- :wat::core::i64 t <- :probe::T acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::spin-match (:wat::core::- n 1) t (:wat::core::+ acc (:probe::depth-left t)))))

(:wat::core::defn :probe::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :probe::say [label <- :wat::core::String n <- :wat::core::i64 ms <- :wat::core::i64] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label " " (:wat::i64::to-string n) " in " (:wat::i64::to-string ms) " ms")))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [small (:probe::mk (:wat::core::Vector :- [:wat::WatAST] (:wat::core::symbol-node "a")))
                    big (:probe::deep 200)
                    t0 (:probe::ms)
                    a (:probe::spin-id 2000 small 0)
                    t1 (:probe::ms)
                    b (:probe::spin-id 2000 big 0)
                    t2 (:probe::ms)
                    tree (:probe::tree 16)
                    t3 (:probe::ms)
                    leaf (:probe::T.Leaf {})
                    c (:probe::spin-match 2000 leaf 0)
                    t4 (:probe::ms)
                    d (:probe::spin-match 2000 tree 0)
                    t5 (:probe::ms)]
    (:wat::core::do
      (:probe::say "WatAST id+kind, small:" a (:wat::core::- t1 t0))
      (:probe::say "WatAST id+kind, big:  " b (:wat::core::- t2 t1))
      (:probe::say "enum tree depth 16 built, depth" 16 (:wat::core::- t3 t2))
      (:probe::say "enum match, leaf:" c (:wat::core::- t4 t3))
      (:probe::say "enum match, tree:" d (:wat::core::- t5 t4)))))
