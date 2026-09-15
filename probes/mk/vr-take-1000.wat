;; vr-take-1000.wat: very-recursiveo's search alone, 1000 answers counted as states, no reification.
(:wat::load-file! "../../books/little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch10-under-the-hood.wat")
(:wat::load-file! "../../books/reasoned-schemer/lib/ch06-the-fun-never-ends.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length (rs/take 1000 [] ((rs/very-recursiveo) (rs/start))))))
