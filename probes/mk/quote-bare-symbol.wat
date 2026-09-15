;; quote-bare-symbol.wat: no macro. Is the bare symbol `quote` (Clojure's spelling) the quote
;; form? Controls: ' and wat.core/quote pass in quote-kw-head.wat.
;; Expected: 3 then 3
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::length (quote (:u::whatever 1 2))))
    (:wat::kernel::println (:wat::core::length (quote (u/whatever 1 2))))))
