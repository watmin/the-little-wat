;; read-pie-unicode-accented-symbol.wat: does wat's reader accept a symbol with é in it? (Clojure allows unicode in
;; symbols; Pie prints → λ Π Σ.) Prints OK and the rendering, or the reader's error.
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::core::read-string "courgetté")
    [:wat::core::ReadOutcome.Forms {:forms fs} (:wat::kernel::println (:wat::string::concat "OK " (:wat::core::ast->source fs)))]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:wat::kernel::println (:wat::string::concat "MALFORMED: " (:wat::core::Error/message c)))]))
