;; The Little Schemer, chapter 3 (Cons the Magnificent): building lists while recurring.
;; The definitions live in lib/ch03-cons-the-magnificent.wat; this program checks them.
;; Our own code and examples, not the book's text.
;;
;; Run: wat books/little-schemer/ch03-cons-the-magnificent.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch03-cons-the-magnificent.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; rember: only the FIRST occurrence goes; absent and empty leave the list alone.
    (wat.test/assert-eq (ls/rember (wat.core/quote plum) (wat.core/quote (pear plum fig plum)))
                        (wat.core/quote (pear fig plum)))
    (wat.test/assert-eq (ls/rember (wat.core/quote kiwi) (wat.core/quote (pear plum)))
                        (wat.core/quote (pear plum)))
    (wat.test/assert-eq (ls/rember (wat.core/quote kiwi) (ls/empty-list)) (ls/empty-list))

    ;; firsts: the heads of each sublist; a head may itself be a list.
    (wat.test/assert-eq (ls/firsts (wat.core/quote ((pear plum) (fig) (kiwi lime))))
                        (wat.core/quote (pear fig kiwi)))
    (wat.test/assert-eq (ls/firsts (wat.core/quote (((pear plum) fig) (kiwi))))
                        (wat.core/quote ((pear plum) kiwi)))
    (wat.test/assert-eq (ls/firsts (ls/empty-list)) (ls/empty-list))

    ;; insertR / insertL: beside the first old only.
    (wat.test/assert-eq (ls/insertR (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig plum)))
                        (wat.core/quote (pear plum x fig plum)))
    (wat.test/assert-eq (ls/insertL (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig plum)))
                        (wat.core/quote (pear x plum fig plum)))
    (wat.test/assert-eq (ls/insertR (wat.core/quote x) (wat.core/quote kiwi) (wat.core/quote (pear plum)))
                        (wat.core/quote (pear plum)))

    ;; subst / subst2: replace the first old; subst2 takes whichever of two comes first.
    (wat.test/assert-eq (ls/subst (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (pear plum fig plum)))
                        (wat.core/quote (pear x fig plum)))
    (wat.test/assert-eq (ls/subst2 (wat.core/quote x) (wat.core/quote fig) (wat.core/quote plum)
                                   (wat.core/quote (pear plum fig)))
                        (wat.core/quote (pear x fig)))

    ;; the multi- versions: every occurrence.
    (wat.test/assert-eq (ls/multirember (wat.core/quote plum) (wat.core/quote (plum pear plum fig plum)))
                        (wat.core/quote (pear fig)))
    (wat.test/assert-eq (ls/multiinsertR (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (plum pear plum)))
                        (wat.core/quote (plum x pear plum x)))
    (wat.test/assert-eq (ls/multiinsertL (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (plum pear plum)))
                        (wat.core/quote (x plum pear x plum)))
    (wat.test/assert-eq (ls/multisubst (wat.core/quote x) (wat.core/quote plum) (wat.core/quote (plum pear plum)))
                        (wat.core/quote (x pear x)))

    (wat.kernel/println "little-schemer ch03 cons-the-magnificent: ok")))
