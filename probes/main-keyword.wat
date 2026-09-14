;; main-keyword.wat: under the `wat` binary, can a keyword-spelled main call a helper
;; written in the Clojure/EDN spelling? Expected output: 42

(wat.core/defn u/add
  [x :- wat.type/i64
   y :- wat.type/i64]
  :- wat.type/i64
  (wat.core/+ x y))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (u/add 40 2)))
