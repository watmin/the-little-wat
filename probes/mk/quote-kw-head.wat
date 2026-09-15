;; quote-kw-head.wat: no macro. Is a keyword-headed list inside quote resolved as a call?
;; Expected: 3 then 3
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::core::length '(:u::whatever 1 2)))
    (:wat::kernel::println (:wat::core::length (wat.core/quote (:u::whatever 1 2))))))
