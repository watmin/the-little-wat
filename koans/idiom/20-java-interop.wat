;; koans/idiom/20-java-interop.wat: the Java-interop koans (koans/literal/20-java-interop.tsv),
;; each said the way wat says it, or marked as having no wat route. wat is not hosted on the
;; JVM, so each row asks what stands in. Keyword spelling throughout, so the checker sees every
;; call (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; Run from the repository root: wat koans/idiom/20-java-interop.wat

(:wat::core::defn :koan::times [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64 (:wat::core::* a b))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; row 1 refused: there are no classes; a value's type is static, known at check time
    (:wat::test::assert-eq (:wat::string::to-uppercase "select * from") "SELECT * FROM") ; row 2
    (:wat::test::assert-eq (:wat::core::mapv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::String (:wat::string::to-uppercase s)) ["fig" "plum"]) ["FIG" "PLUM"]) ; row 3
    ;; row 4 refused: there are no host objects; wat's concurrency is threads, channels and services
    ;; no power function: multiply, ten times
    (:wat::test::assert-eq (:wat::core::foldl :koan::times 1 (:wat::core::mapv (:wat::core::fn [i <- :wat::core::i64] -> :wat::core::i64 2) (:wat::core::range 0 10))) 1024) ; row 5
    (:wat::kernel::println "koans idiom 20-java-interop: ok")))
