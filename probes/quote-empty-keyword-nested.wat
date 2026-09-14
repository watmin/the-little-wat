;; quote-empty-keyword-nested.wat: the F-004 companion. The keyword spelling
;; (:wat::core::quote ()) works at the top level (quote-empty-keyword.wat). Does it also work
;; with () NESTED inside quoted data, e.g. '(fig ())? If so, it is the clean way to write
;; expected values that contain empty lists.
;; Expected if it works: "list" then 2
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [l (:wat::core::quote (fig ()))]
    (:wat::core::do
      (:wat::kernel::println (:wat::core::ast-kind (:wat::core::first (:wat::core::rest l))))
      (:wat::kernel::println (:wat::core::length l)))))
