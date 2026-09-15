;; probes/typer/ast-children-cost.wat: does taking a WatAST apart copy its whole subtree?
;; Builds a node whose one child holds a big tree (a list nested 200 deep, each level with
;; 40 leaves), then times 2000 calls of ast->children on it against 2000 on a small node.
;; If children are shared, both loops cost about the same; if copied, the big one costs
;; in proportion to the tree.

(:wat::core::defn :probe::mk [kids <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::with-children (:wat::core::quote (t)) kids))

(:wat::core::defn :probe::leaves [n <- :wat::core::i64 acc <- (:wat::core::Vector :- [:wat::WatAST])] -> (:wat::core::Vector :- [:wat::WatAST])
  (:wat::core::if (:wat::core::= n 0) acc (:probe::leaves (:wat::core::- n 1) (:wat::core::conj acc (:wat::core::symbol-node "leaf")))))

(:wat::core::defn :probe::deep [d <- :wat::core::i64] -> :wat::WatAST
  (:wat::core::if (:wat::core::= d 0)
    (:wat::core::symbol-node "bottom")
    (:probe::mk (:wat::core::conj (:probe::leaves 40 (:wat::core::Vector :- [:wat::WatAST])) (:probe::deep (:wat::core::- d 1))))))

(:wat::core::defn :probe::spin [n <- :wat::core::i64 node <- :wat::WatAST acc <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::if (:wat::core::= n 0)
    acc
    (:probe::spin (:wat::core::- n 1) node (:wat::core::+ acc (:wat::core::length (:wat::core::ast->children node))))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [small (:probe::mk (:wat::core::Vector :- [:wat::WatAST] (:wat::core::symbol-node "a") (:wat::core::symbol-node "b")))
                    big (:probe::mk (:wat::core::Vector :- [:wat::WatAST] (:wat::core::symbol-node "a") (:probe::deep 200)))
                    t0 (:wat::time::epoch-millis (:wat::time::now))
                    s (:probe::spin 2000 small 0)
                    t1 (:wat::time::epoch-millis (:wat::time::now))
                    b (:probe::spin 2000 big 0)
                    t2 (:wat::time::epoch-millis (:wat::time::now))]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "small: " (:wat::i64::to-string s) " children in " (:wat::i64::to-string (:wat::core::- t1 t0)) " ms"))
      (:wat::kernel::println (:wat::string::concat "big:   " (:wat::i64::to-string b) " children in " (:wat::i64::to-string (:wat::core::- t2 t1)) " ms")))))
