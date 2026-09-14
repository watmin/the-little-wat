;; cell-global-def.wat: a real GLOBAL mutable variable, the book's (define x ...) plus
;; (set! x ...): a top-level def whose value is a started Cell, referenced by its keyword.
;; Does a top-level def start a service at startup, and can main then use it?
;; Expected: pizza then onion
(:wat::load-file! "../books/seasoned-schemer/lib/cell.wat")
(:wat::core::def :u::x (:ss::new-cell 'pizza))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:ss::cell-get :u::x))
    (:ss::cell-put! :u::x 'onion)
    (:wat::kernel::println (:ss::cell-get :u::x))))
