;; probes/koans/bigint-compare.wat: Clojure's (< 1000000000000000000000000N (factorial 25N))
;; needs big integers and a comparison between them. wat has :wat::i64::to-bigint and bigint's
;; + - * /; does :wat::core::< compare two bigints? (The literal is probes/koans/bigint-literal.wat.)

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [a (:wat::i64::to-bigint 1000000)
                    b (:wat::bigint::* a a)
                    c (:wat::bigint::* b (:wat::bigint::* a a))]
    (:wat::core::do
      (:wat::kernel::println (:wat::edn::write c))
      (:wat::kernel::println (:wat::edn::write (:wat::core::< a c))))))
