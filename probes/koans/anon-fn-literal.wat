;; probes/koans/anon-fn-literal.wat: Clojure's #(...) is an anonymous function literal. Does
;; wat's reader take it, refuse it, or read the # as a symbol?

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:wat::edn::write (#(:wat::core::+ % 1) 2))))
