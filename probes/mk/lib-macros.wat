;; lib-macros.wat: the book's surface forms as wat macros over the ch 10 engine's functions.
;; Loaded by macros.wat (keyword-headed calls) and macros-symbol-head.wat (symbol-headed).
;; The book's own paren syntax is kept, (fresh (x y) g …), (defrel (name arg …) g …).
;;
;; Rules learned the hard way (probes/mk/macro-*.wat):
;; - A computed unquote ~(expr) in a template has the macro's params SUBSTITUTED into expr as
;;   code, so ~(first form) evaluates form. Take arguments apart in a PROGRAM body (a let
;;   outside the template), where params are bound as data; the template then uses only
;;   plain ~x and ~@xs.
;; - A macro may not call a user defn at expansion time (the F5 purity gate), so a helper
;;   that walks a list is a second macro that recurses by expanding to itself.
;; - Never emit an empty () into code (F-004): each recursion stops one element early.

;; (run* q g …)
(:wat::core::defmacro :mk::run*
  [q <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  `(rs/run* (:wat::core::fn [~q <- :rs::Term] -> :rs::Goal (rs/conj [~@goals]))))

;; (fresh (x …) g …): one rs/fresh per variable, nested.
(:wat::core::defmacro :mk::fresh
  [vars <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::if (:wat::core::empty? vars)
    `(rs/conj [~@goals])
    (:wat::core::let [v (:wat::core::first vars)
                      more (:wat::core::rest vars)]
      (:wat::core::if (:wat::core::empty? more)
        `(rs/fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (rs/conj [~@goals])))
        `(rs/fresh (:wat::core::fn [~v <- :rs::Term] -> :rs::Goal (:mk::fresh ~more ~@goals)))))))

;; (defrel (name arg …) g …): a defn whose body is built only when the goal runs.
(:wat::core::defmacro :mk::defrel
  [head <- :wat::WatAST & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [name (:wat::core::first head)
                    args (:wat::core::rest head)]
    (:wat::core::if (:wat::core::empty? args)
      `(:wat::core::defn ~name [] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:mk::defrel-params ~name (params) ~args ~@goals))))

;; Moves one arg at a time from args into the typed parameter list, then emits the defn.
;; The typed list is (params x <- :rs::Term …): a list form with a marker head, because in a
;; program body ~@ splices a list form but not a vector form [...] (F-021).
(:wat::core::defmacro :mk::defrel-params
  [name <- :wat::WatAST typed <- :wat::WatAST args <- :wat::WatAST
   & goals <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::WatAST
  (:wat::core::let [ps (:wat::core::rest typed)
                    a (:wat::core::first args)
                    more (:wat::core::rest args)]
    (:wat::core::if (:wat::core::empty? more)
      `(:wat::core::defn ~name [~@ps ~a <- :rs::Term] -> :rs::Goal
         (rs/delay (:wat::core::fn [] -> :rs::Goal (rs/conj [~@goals]))))
      `(:mk::defrel-params ~name (params ~@ps ~a <- :rs::Term) ~more ~@goals))))
