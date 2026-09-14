;; F-014 scope: a KEYWORD-spelled call with a wrong argument type, to a function DEFINED
;; with wat.core/defn. Does the Clojure-spelled defn register a signature the checker uses?
(wat.core/defn u/add1 [x :- wat.type/i64] :- wat.type/i64 (wat.core/+ x 1))
(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println (:u::add1 "pear")))
