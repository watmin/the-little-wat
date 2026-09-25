(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println (:wat::keyword::to-string :foo))
    (:wat::kernel::println (:wat::core::str :foo))
    (:wat::kernel::println (:wat::keyword::to-string :user::ns::i64))
    (:wat::kernel::println (:wat::keyword::name :foo))
    (:wat::kernel::println (:wat::keyword::name :user::ns::i64))
    (:wat::kernel::println (:wat::keyword::name :user::E.V))
    (:wat::kernel::println (:wat::keyword::to-string :user::E.V))))
