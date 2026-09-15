;; lib-surface.wat: the rest of the book's surface as macros (prototype, namespace mk2):
;; run n, run* with one query variable or a list of them, conde with the book's paren lines.
;; fresh and defrel are lib-macros.wat's, copied under mk2.

(:wat::core::defmacro :mk2::fresh
  [vars <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? vars)
    `(rs/conj [~@goals])
    (:wat::core::let [v (:wat::core::first vars)
                      more (:wat::core::rest vars)]
      (:wat::core::if (:wat::core::empty? more)
        `(rs/fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (rs/conj [~@goals])))
        `(rs/fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (:mk2::fresh ~more ~@goals)))))))

(:wat::core::defmacro :mk2::defrel
  [head <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [name (:wat::core::first head)
                    args (:wat::core::rest head)]
    (:wat::core::if (:wat::core::empty? args)
      `(:wat::core::defn ~name [] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:mk2::defrel-params ~name (params) ~args ~@goals))))

(:wat::core::defmacro :mk2::defrel-params
  [name <- :wat::WatAST typed <- :wat::WatAST args <- :wat::WatAST
   & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [ps (:wat::core::rest typed)
                    a (:wat::core::first args)
                    more (:wat::core::rest args)]
    (:wat::core::if (:wat::core::empty? more)
      `(:wat::core::defn ~name [~@ps ~a <- :rs::Term] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:mk2::defrel-params ~name (params ~@ps ~a <- :rs::Term) ~more ~@goals))))

;; (run n q g …) or (run n (x …) g …). A program body may not introduce a literal binder
;; (hygiene gate E), so the several-variable case hands off to a template macro, whose
;; binder q0 is renamed hygienically.
(:wat::core::defmacro :mk2::run
  [n <- :wat::WatAST q <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::if (:wat::core::List? q)
    `(:mk2::run-vars ~n ~q ~@goals)
    `(rs/run ~n (:wat::core::fn [~q <- :rs::Term] -> :rs::Goal (rs/conj [~@goals])))))

(:wat::core::defmacro :mk2::run-vars
  [n <- :wat::WatAST vars <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  `(rs/run ~n (:wat::core::fn [q0 <- :rs::Term] -> :rs::Goal
                (:mk2::fresh ~vars (rs/== q0 (rs/list [~@vars])) ~@goals))))

(:wat::core::defmacro :mk2::run*
  [q <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  `(:mk2::run -1 ~q ~@goals))

;; (conde (g …) …): each line a conjunction, the lines a disjunction.
(:wat::core::defmacro :mk2::conde
  [& lines <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [conjs (:wat::core::foldl
                            (:wat::core::fn [acc <- (:wat::core::Vector :- [:wat::WatAST]) line <- :wat::WatAST]
                              -> (:wat::core::Vector :- [:wat::WatAST])
                              (:wat::core::conj acc `(rs/conj [~@line])))
                            [] lines)]
    `(rs/disj [~@conjs])))
