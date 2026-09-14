;; The Little Schemer, chapter 5 ("Oh My Gawd": It's Full of Stars): recursion into nested
;; lists, then S-expression equality. The definitions live in lib/ch05-full-of-stars.wat;
;; this program checks them. Our own code and examples, not the book's text.
;;
;; The test data never produces an empty sublist on purpose: an expected value such as
;; '(fig ()) cannot be written with wat.core/quote (FINDINGS.md, F-004).
;;
;; Run: wat books/little-schemer/ch05-full-of-stars.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/ch01-toys.wat")
(:wat::load-file! "lib/ch04-numbers-games.wat")
(:wat::load-file! "lib/ch05-full-of-stars.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; the starred functions reach into sublists
    (wat.test/assert-eq (ls/rember* (wat.core/quote plum)
                                    (wat.core/quote ((plum pear) (fig (kiwi plum)) plum)))
                        (wat.core/quote ((pear) (fig (kiwi)))))
    (wat.test/assert-eq (ls/insertR* (wat.core/quote x) (wat.core/quote plum)
                                     (wat.core/quote ((plum pear) (fig (plum)))))
                        (wat.core/quote ((plum x pear) (fig (plum x)))))
    (wat.test/assert-eq (ls/occur* (wat.core/quote plum)
                                   (wat.core/quote ((plum pear) (fig (plum)) plum)))
                        3)
    (wat.test/assert-eq (ls/subst* (wat.core/quote x) (wat.core/quote plum)
                                   (wat.core/quote ((plum pear) (fig (plum)))))
                        (wat.core/quote ((x pear) (fig (x)))))
    (wat.test/assert-eq (ls/insertL* (wat.core/quote x) (wat.core/quote plum)
                                     (wat.core/quote ((plum pear) (fig (plum)))))
                        (wat.core/quote ((x plum pear) (fig (x plum)))))
    (wat.test/assert-eq (ls/member* (wat.core/quote kiwi) (wat.core/quote ((pear) (fig (kiwi))))) true)
    (wat.test/assert-eq (ls/member* (wat.core/quote lime) (wat.core/quote ((pear) (fig (kiwi))))) false)
    (wat.test/assert-eq (ls/leftmost (wat.core/quote (((pear) plum) fig))) (wat.core/quote pear))

    ;; equality of whole S-expressions, including numbers inside
    (wat.test/assert-eq (ls/eqlist? (wat.core/quote (pear (plum fig))) (wat.core/quote (pear (plum fig)))) true)
    (wat.test/assert-eq (ls/eqlist? (wat.core/quote (pear (plum fig))) (wat.core/quote (pear (plum kiwi)))) false)
    (wat.test/assert-eq (ls/eqlist? (wat.core/quote (1 (2 pear))) (wat.core/quote (1 (2 pear)))) true)
    (wat.test/assert-eq (ls/equal? (wat.core/quote pear) (wat.core/quote pear)) true)
    (wat.test/assert-eq (ls/equal? (wat.core/quote 4) (wat.core/quote (4))) false)

    ;; rember with equal? removes a whole sub-list
    (wat.test/assert-eq (ls/rember-equal (wat.core/quote (plum fig))
                                         (wat.core/quote (pear (plum fig) kiwi)))
                        (wat.core/quote (pear kiwi)))

    (wat.kernel/println "little-schemer ch05 full-of-stars: ok")))
