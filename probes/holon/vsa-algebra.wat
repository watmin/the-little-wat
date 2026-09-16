;; probes/holon/vsa-algebra.wat: does wat's VSA obey the algebra it is named for?
;;
;; :wat::holon:: is the largest untouched surface in wat — 94 verbs — and it is the layer wat
;; exists for. Unlike the rete or the Store, it needs no external oracle: a vector-symbolic
;; architecture has LAWS, and the mathematics is the oracle.
;;
;; The vectors here are TERNARY (encode lowers a HolonAST "to a raw ternary vector at the
;; program's ambient dimension"), which pins down what must hold:
;;
;;   bind     element-wise multiply — SELF-INVERSE: bind(bind(a,b),b) = a. This is the axiom the
;;            whole architecture rests on; it is how a bound pair is unbound again.
;;   bundle   element-wise sum — the result stays SIMILAR to each of its parts. That is what
;;            makes a bundle a set you can query.
;;   permute  a rotation — destroys similarity with the original, and is invertible by the
;;            opposite shift. It is how order is represented.
;;
;; Distinct atoms must also be quasi-orthogonal, or nothing above carries information.
;;
;; Every comparison goes through cosine, so "identical" is a similarity of 1 and "unrelated" is
;; a similarity near 0. Values print through f64::to-string, which drops a trailing .0 (F-034),
;; so an exact 1.0 reads as "1" and an exact 0.0 as "0".
;;
;; Run from the repository root: wat probes/holon/vsa-algebra.wat

(:wat::core::typealias :h::Vecs (:wat::core::Vector :- [:wat::holon::Vector]))

;; cosine, rendered — or the reason it could not be taken
(:wat::core::defn :h::cos [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::core::String
  (:wat::core::match (:wat::holon::cosine a b)
    [:wat::holon::CosineOutcome.Similarity {:similarity s} (:wat::f64::to-string s)]
    [:wat::holon::CosineOutcome.Degenerate {:side _s} "DEGENERATE"]
    [:wat::holon::CosineOutcome.DimensionMismatch {:expected e :got g}
      (:wat::string::concat "DIM-MISMATCH " (:wat::i64::to-string e) "/" (:wat::i64::to-string g))]))

(:wat::core::defn :h::combined [o <- :wat::holon::CombineOutcome] -> :wat::holon::Vector
  (:wat::core::match o
    [:wat::holon::CombineOutcome.Combined {:vector v} v]
    [:wat::holon::CombineOutcome.DimensionMismatch {:expected e :got g}
      (:wat::kernel::assertion-failed! :message
        (:wat::string::concat "combine dimension mismatch "
                              (:wat::i64::to-string e) "/" (:wat::i64::to-string g)))]))

(:wat::core::defn :h::bind [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::holon::Vector
  (:h::combined (:wat::holon::vector-bind a b)))

(:wat::core::defn :h::bundle [vs <- :h::Vecs] -> :wat::holon::Vector
  (:h::combined (:wat::holon::vector-bundle vs)))

(:wat::core::defn :h::atom [name <- :wat::core::String] -> :wat::holon::Vector
  (:wat::holon::encode (:wat::holon::leaf name)))

(:wat::core::defn :h::law [name <- :wat::core::String expect <- :wat::core::String got <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat name "  expect " expect "  got " got)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [a (:h::atom "alpha")
     b (:h::atom "beta")
     c (:h::atom "gamma")

     ab   (:h::bind a b)
     ba   (:h::bind b a)
     abb  (:h::bind ab b)          ;; bind(bind(a,b),b) — must recover a
     bun  (:h::bundle (:wat::core::Vector :- [:wat::holon::Vector] a b c))
     bun2 (:h::bundle (:wat::core::Vector :- [:wat::holon::Vector] c b a))
     p1   (:wat::holon::vector-permute a 1)
     pm1  (:wat::holon::vector-permute p1 -1)
     pab  (:wat::holon::vector-permute ab 1)
     pa_pb (:h::bind (:wat::holon::vector-permute a 1) (:wat::holon::vector-permute b 1))]

    (:wat::core::do
      (:wat::kernel::println "-- identity and orthogonality --")
      (:h::law "cos(a,a)              " "1"    (:h::cos a a))
      (:h::law "cos(a,b)  distinct    " "~0"   (:h::cos a b))
      (:h::law "cos(a,c)  distinct    " "~0"   (:h::cos a c))

      (:wat::kernel::println "-- bind --")
      (:h::law "cos(bind(bind(a,b),b), a)  SELF-INVERSE" "1"  (:h::cos abb a))
      (:h::law "cos(bind(a,b), bind(b,a))  commutative " "1"  (:h::cos ab ba))
      (:h::law "cos(bind(a,b), a)          new vector  " "~0" (:h::cos ab a))

      (:wat::kernel::println "-- bundle --")
      (:h::law "cos(bundle(a,b,c), a)      similar     " ">0" (:h::cos bun a))
      (:h::law "cos(bundle(a,b,c), b)      similar     " ">0" (:h::cos bun b))
      (:h::law "cos(bundle(abc), bundle(cba)) commut.  " "1"  (:h::cos bun bun2))

      (:wat::kernel::println "-- permute --")
      (:h::law "cos(permute(a,1), a)       dissimilar  " "~0" (:h::cos p1 a))
      (:h::law "cos(permute(permute(a,1),-1), a) invert" "1"  (:h::cos pm1 a))
      (:h::law "permute distributes over bind         " "1"  (:h::cos pab pa_pb)))))
