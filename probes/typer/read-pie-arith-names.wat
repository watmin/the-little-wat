;; probes/typer/read-pie-arith-names.wat: does wat's reader take the names The Little Typer's
;; chapter 3 uses (+ * step-+ step-* n-1 *n-1 +n-1 gauss-n-1) and quoted atoms 't 'nil?
;; Prints each read child's kind and source, one per line.

(:wat::core::defn :probe::show [xs <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? xs)
    nil
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat (:wat::core::ast-kind (:wat::core::first xs)) " " (:wat::core::ast->source (:wat::core::first xs))))
      (:probe::show (:wat::core::rest xs)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::core::read-string "(+ * step-+ step-* n-1 *n-1 +n-1 gauss-n-1 't 'nil)")
    [:wat::core::ReadOutcome.Forms {:forms fs}
      (:probe::show (:wat::core::ast->children (:wat::core::first (:wat::core::ast->children fs))))]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::println (:wat::core::Error/message c))]))
