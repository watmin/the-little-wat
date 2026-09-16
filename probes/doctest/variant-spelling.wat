;; probes/doctest/variant-spelling.wat: is the doc's `::Variant` an enum variant, or a keyword?
;;
;; :wat::doctest::verify-examples died comparing `:wat::edn::Validation.Valid`. But
;; probes/doctest/equals-on-enum.wat shows `=` compares enum values FINE — identical variants,
;; inline or widened, both answer true. So `=` is not refusing enums.
;;
;; The example that died is (edn.rs:255):
;;
;;   @example (:wat::edn::validate 42 :wat::core::i64) #=> :wat::edn::Validation::Valid
;;
;; written with `::Valid`. Everywhere in wat a variant is `Enum.Variant` with a DOT —
;; :wat::core::Option.Some, :eq::Colour.Red. So the expected side may be reading as an ordinary
;; KEYWORD PATH, not as a variant, which would make `=` compare an Enum against a keyword: a
;; genuinely non-comparable pair, and an example that can never match no matter what the
;; intrinsic does.
;;
;; This file only DIAGNOSES — it prints what each spelling is and checks the correctly-spelled
;; comparison. The doc's own spelling is asked in probes/doctest/variant-spelling-raises.wat,
;; because if the hypothesis is right that comparison raises and ends the program.
;;
;; Run from the repository root: wat probes/doctest/variant-spelling.wat

(:wat::core::defn :vs::show [label <- :wat::core::String s <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::concat label ": " s)))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; what KIND of node is each spelling?
    (:vs::show "kind of :wat::edn::Validation::Valid (the doc's spelling)"
               (:wat::core::ast-kind (:wat::core::quote :wat::edn::Validation::Valid)))
    (:vs::show "kind of :wat::edn::Validation.Valid (wat's spelling)"
               (:wat::core::ast-kind (:wat::core::quote :wat::edn::Validation.Valid)))
    ;; what does the intrinsic actually answer?
    (:vs::show "validate 42 :i64 renders as"
               (:wat::edn::write (:wat::edn::validate 42 :wat::core::i64)))
    ;; and the CORRECTLY spelled comparison — this is what the example meant to say
    (:vs::show "validate 42 :i64 = Validation.Valid"
               (:wat::core::if (:wat::core::= (:wat::edn::validate 42 :wat::core::i64)
                                              (:wat::edn::Validation.Valid {}))
                 "true" "false"))))
