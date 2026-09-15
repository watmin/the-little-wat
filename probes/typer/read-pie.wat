;; read-pie.wat: can wat's reader read Pie's ASCII spellings? (Unicode symbols: read-pie-unicode*.wat.) The
;; list constructor :: and vec::, quoted atoms ('ratatouille), TODO, = and ->. Reads a Pie
;; snippet with read-string and prints each form's kind and rendering.
(:wat::core::defn :u::show-each [xs <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? xs)
    nil
    (:wat::core::let [x (:wat::core::first xs)]
      (:wat::core::do
        (:wat::kernel::println (:wat::string::concat (:wat::core::ast-kind x) "  " (:wat::core::ast->source x)))
        (:u::show-each (:wat::core::rest xs))))))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::core::read-string ":: vec:: 'ratatouille TODO = -> (Pi ((x Nat)) (-> Nat Nat)) (:: 1 nil) (vec:: 'a vecnil) (the (= Nat 1 1) (same 1))")
    [:wat::core::ReadOutcome.Forms {:forms fs} (:u::show-each (:wat::core::ast->children fs))]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::println (:wat::string::concat "MALFORMED: " (:wat::core::Error/message c)))]))
