;; koans/idiom/23-meta.wat: the metadata koans (koans/literal/23-meta.tsv), each said the way
;; wat says it, or marked as having no wat route. Keyword spelling throughout, so the checker
;; sees every call (F-014). Markers as in koans/idiom/01-equalities.wat.
;;
;; wat values carry no metadata. (Definitions do: :wat::runtime::metadata-of reads a name's doc
;; record; nothing attaches a map to a value.)
;;
;; Run from the repository root: wat koans/idiom/23-meta.wat

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    ;; row 1 missing: values carry no metadata
    ;; row 2 missing: values carry no metadata, and there is no ^{...} reader syntax
    ;; row 3 missing: values carry no metadata (and a thrown error is a Result, C-006)
    ;; row 4 missing: values carry no metadata for merge to keep
    ;; row 5 missing: values carry no metadata
    ;; a type hint is a declared type; a String's first character is a one-character String
    (:wat::test::assert-eq ((:wat::core::fn [s <- :wat::core::String] -> :wat::core::String (:wat::string::subs s 0 1)) "Cast me") "C") ; row 6
    ;; row 7 missing: values carry no metadata to hold state in
    ;; row 8 missing: values carry no metadata to vary
    ;; row 9 missing: values carry no metadata, so equality ignoring it has nothing to ignore
    ;; row 10 missing: values carry no metadata, so printing ignoring it has nothing to ignore
    (:wat::kernel::println "koans idiom 23-meta: ok")))
