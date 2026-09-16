;; probes/runtime/reflection.wat: USER-GUIDE.md's reflection section, run.
;;
;; "### Runtime reflection -- :wat::runtime::* (arc 143)" (USER-GUIDE.md:2986) is one of the few
;; subsystems this repository found that IS documented, so it can be checked in the direction the
;; others could not: docs against code.
;;
;; The section documents five returns. Every one of them names :wat::holon::HolonAST -- which is a
;; real type, but the WRONG one: it is the VSA holon AST that :wat::cache::HolographicLru keys on
;; (wat/cache.wat:274-320), not the wat syntax tree. The reflection verbs return :wat::WatAST.
;;
;; It also documents `:wat::runtime::lookup-callable`, which does not resolve (F-087), and line
;; 3047's "Coverage today" sentence names it again.
;;
;; And note the SHAPE that comes back: `(:u::my-add (a wat.type/i64) (b wat.type/i64) -> ...)` is
;; the retired `:wat::core::define` signature form -- the one F-087 found §4 still teaching.
;;
;; Expected: the lines below, which contradict the documented types.
;;
;; Run: wat probes/runtime/reflection.wat

(:wat::core::defn :rr::my-add [a <- :wat::core::i64 b <- :wat::core::i64] -> :wat::core::i64
  (:wat::core::+ a b))

;; If this type-checks, the return element is :wat::WatAST and not :wat::holon::HolonAST.
(:wat::core::defn :rr::as-watast [n <- :wat::WatAST] -> :wat::core::String
  (:wat::core::ast->source n))

(:wat::core::defn :rr::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::match (:wat::runtime::signature-of-defn :rr::my-add)
    [:wat::core::Option.Some {:value sig}
      (:wat::core::do
        ;; documented (L2999) as (:Option :- [:wat::holon::HolonAST])
        (:rr::say "signature-of-defn, as :wat::WatAST" (:rr::as-watast sig))
        ;; documented (L3011) as "(:Vec :- [HolonAST]) of BARE-SYMBOL arg names"
        (:rr::say "extract-arg-names                 " (:wat::edn::write (:wat::runtime::extract-arg-names sig)))
        (:rr::say "extract-arg-types                 " (:wat::edn::write (:wat::runtime::extract-arg-types sig)))
        ;; return-type-of / signature-of-fn take a FN VALUE, not a signature AST -- the
        ;; section does not say so, and handing them `sig` dies at runtime with
        ;; "expected wat::core::fn value ..., got wat::WatAST".
        (:rr::say "return-type-of (of a fn value)    "
          (:wat::edn::write (:wat::runtime::return-type-of
            (:wat::core::fn [x <- :wat::core::i64] -> :wat::core::String (:wat::i64::to-string x)))))
        (:wat::core::match (:wat::runtime::body-of :rr::my-add)
          [:wat::core::Option.Some {:value b} (:rr::say "body-of, as :wat::WatAST          " (:rr::as-watast b))]
          [:wat::core::Option.None {} (:rr::say "body-of" "None")]))]
    [:wat::core::Option.None {} (:rr::say "signature-of-defn" "None")]))
