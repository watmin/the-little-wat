;; quote-empty-keyword.wat: the F-004 discriminator. The same empty list, quoted with the
;; KEYWORD spelling of quote inside a keyword-spelled main. If this passes while
;; (wat.core/quote ()) is refused, F-004 lives in the Clojure-spelling path only.
;; Expected if quote is fine: "list" then true
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [e (:wat::core::quote ())]
    (:wat::core::do
      (:wat::kernel::println (:wat::core::ast-kind e))
      (:wat::kernel::println (:wat::core::empty? e)))))
