;; probes/typer/read-pie-equality-names.wat: does wat's reader take the names The Little Typer's
;; chapter 8 uses (+1=add1, incr=add1, =), and what is +1? (1+ fails to lex at all, as in Clojure)
;; Prints each read child's kind and source, one per line.

(:wat::core::defn :probe::show [xs <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? xs)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat (:wat::core::ast-kind (:wat::core::first xs)) " " (:wat::core::ast->source (:wat::core::first xs))))
      (:probe::show (:wat::core::rest xs)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::core::read-string "(+1=add1 incr=add1 +1 = mot-incr=add1)")
    [:wat::core::ReadOutcome.Forms {:forms fs}
      (:probe::show (:wat::core::ast->children (:wat::core::first (:wat::core::ast->children fs))))]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::println (:wat::core::Error/message c))]))
