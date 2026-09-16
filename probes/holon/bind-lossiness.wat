;; probes/holon/bind-lossiness.wat: how lossy is unbinding, and does it still recognise?
;;
;; probes/holon/vsa-algebra.wat found eleven VSA laws holding exactly and one holding only
;; approximately: bind(bind(a,b),b) recovers a at cos = 0.818, not 1. That is the self-inverse
;; axiom, and it matters more than it might because there is NO unbind verb — the whole raw
;; surface is vector-bind / vector-blend / vector-bundle / vector-bytes / vector-permute. Binding
;; twice by the same vector is the only way back.
;;
;; The mechanism is sparsity: these are TERNARY vectors, so a·b·b is a wherever b is non-zero and
;; ZERO wherever b is zero. Every zero coordinate in the binder destroys that coordinate of a.
;; Sparse-ternary VSA is known to be lossy this way; dense bipolar binding is not.
;;
;; So the question is not "is the axiom broken" but "is the loss within the tolerance the
;; architecture sets for itself". wat publishes two floors at dimension d (measured: encode makes
;; 2504-byte vectors = 10000 ternary elements + a 4-byte header):
;;
;;   presence-floor   ~0.49   — "is this the same thing?"
;;   coincident-floor ~0.008  — "is this above chance?"
;;
;; 0.818 clears both by a wide margin, which would make the lossiness a designed tolerance rather
;; than a defect — but undocumented either way. Measured here:
;;   1. is the ~0.82 stable across pairs, or does it vary with the binder?
;;   2. does it compound over two bind/unbind rounds?
;;   3. does the recovered vector still WIN against a codebook — the practical test?
;;   4. do wat's own predicates accept it?
;;
;; Run from the repository root: wat probes/holon/bind-lossiness.wat

(:wat::core::defn :bl::cos [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::core::String
  (:wat::core::match (:wat::holon::cosine a b)
    [:wat::holon::CosineOutcome.Similarity {:similarity s} (:wat::f64::to-string s)]
    [:wat::holon::CosineOutcome.Degenerate {:side _s} "DEGENERATE"]
    [:wat::holon::CosineOutcome.DimensionMismatch {:expected _e :got _g} "DIM"]))

(:wat::core::defn :bl::combined [o <- :wat::holon::CombineOutcome] -> :wat::holon::Vector
  (:wat::core::match o
    [:wat::holon::CombineOutcome.Combined {:vector v} v]
    [:wat::holon::CombineOutcome.DimensionMismatch {:expected _e :got _g}
      (:wat::kernel::assertion-failed! :message "dim mismatch")]))

(:wat::core::defn :bl::bind [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::holon::Vector
  (:bl::combined (:wat::holon::vector-bind a b)))

(:wat::core::defn :bl::atom [n <- :wat::core::String] -> :wat::holon::Vector
  (:wat::holon::encode (:wat::holon::leaf n)))

(:wat::core::defn :bl::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label "  " s)))

(:wat::core::defn :bl::yn [b <- :wat::core::bool] -> :wat::core::String
  (:wat::core::if b "yes" "NO"))

;; bind through b, then unbind by b, and report what similarity survived
(:wat::core::defn :bl::trip [a <- :wat::holon::Vector b <- :wat::holon::Vector] -> :wat::core::String
  (:bl::cos (:bl::bind (:bl::bind a b) b) a))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [a (:bl::atom "alpha")  b (:bl::atom "beta")   c (:bl::atom "gamma")
     d (:bl::atom "delta")  e (:bl::atom "epsilon")
     rec (:bl::bind (:bl::bind a b) b)
     two (:bl::bind (:bl::bind (:bl::bind (:bl::bind a b) c) c) b)]
    (:wat::core::do
      (:wat::kernel::println "-- 1. stability of the loss across pairs --")
      (:bl::show "a through b" (:bl::trip a b))
      (:bl::show "a through c" (:bl::trip a c))
      (:bl::show "a through d" (:bl::trip a d))
      (:bl::show "b through a" (:bl::trip b a))
      (:bl::show "c through d" (:bl::trip c d))
      (:bl::show "d through e" (:bl::trip d e))

      (:wat::kernel::println "-- 2. does the loss compound? --")
      (:bl::show "a bound through b and c, both undone" (:bl::cos two a))

      (:wat::kernel::println "-- 3. does the recovered vector still WIN a codebook lookup? --")
      (:bl::show "cos(recovered, a)  the right answer" (:bl::cos rec a))
      (:bl::show "cos(recovered, b)" (:bl::cos rec b))
      (:bl::show "cos(recovered, c)" (:bl::cos rec c))
      (:bl::show "cos(recovered, d)" (:bl::cos rec d))
      (:bl::show "cos(recovered, e)" (:bl::cos rec e))

      (:wat::kernel::println "-- 4. do wat's own predicates accept it? --")
      ;; presence? takes HolonAST ONLY and refuses a raw Vector at startup, so the raw algebra's
      ;; own output cannot be handed to it. coincident? does accept Vectors.
      (:bl::show "coincident? recovered vs a" (:bl::yn (:wat::holon::coincident? rec a)))
      (:bl::show "coincident? recovered vs b (want no)" (:bl::yn (:wat::holon::coincident? rec b)))
      (:bl::show "coincident? a vs b          (want no)" (:bl::yn (:wat::holon::coincident? a b)))
      (:bl::show "presence-floor   @10000" (:wat::f64::to-string (:wat::holon::presence-floor 10000)))
      (:bl::show "coincident-floor @10000" (:wat::f64::to-string (:wat::holon::coincident-floor 10000))))))
