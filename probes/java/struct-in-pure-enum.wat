;; probes/java/struct-in-pure-enum.wat: can a Pure enum hold a defstruct of two i64s?
;; A Little Java ch 9's shapes hold a point: Trans [q <- CartesianPt  s <- ShapeD]. With the
;; point as a defstruct, the enum is refused; the chapter declares it with defrecord instead.

(:wat::core::defstruct :probe::Pt [x <- :wat::core::i64  y <- :wat::core::i64])

(:wat::core::defenum :probe::ShapeD :wat::enum::Pure
  :Circle [r <- :wat::core::i64]
  :Trans [q <- :probe::Pt  s <- :probe::ShapeD])

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::kernel::println "a Pure enum holds a defstruct"))
