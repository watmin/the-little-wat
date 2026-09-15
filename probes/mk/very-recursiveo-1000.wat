;; very-recursiveo-1000.wat: the book's very-recursiveo, 1000 answers, timed by the shell.
;; Compare oracle/ch06.clj's timings on the JVM. Expected: 1000
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length (rs/run 1000 q (rs/very-recursiveo)))))
