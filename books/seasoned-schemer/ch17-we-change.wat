;; The Seasoned Schemer, chapter 17 (We Change, Therefore We Are!): counting conses with a
;; global counter, and measuring that an escape really abandons its pending conses. The
;; definitions live in lib/ch17-we-change.wat and lib/counter.wat; this program checks them.
;; Our own code and examples, not the book's text.
;;
;; Run: wat books/seasoned-schemer/ch17-we-change.wat   (exit 0 and a final "ok" line = pass)

(:wat::load-file! "lib/counter.wat")
(:wat::load-file! "../little-schemer/lib/ch01-toys.wat")
(:wat::load-file! "../little-schemer/lib/ch04-numbers-games.wat")
(:wat::load-file! "../little-schemer/lib/ch05-full-of-stars.wat")
(:wat::load-file! "lib/ch17-we-change.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; deep-C: 5 wrappings, 5 counted conses
    (ss/counter-reset! :ss::N 0)
    (wat.test/assert-eq (ss/deep-C 5) '(((((pizza))))))
    (wat.test/assert-eq (ss/counter-get :ss::N) 5)

    ;; supercounter: deep-C on 10, 9, ... 0 is 10+9+...+0 = 55 conses
    (ss/counter-reset! :ss::N 0)
    (wat.test/assert-eq (ss/supercounter ss/deep-C 10) 55)

    ;; The measurement. With the atom ABSENT, the escaping rember1* gives back the original
    ;; list and performs NO conses: the Err skipped every pending one...
    (ss/counter-reset! :ss::N 0)
    (wat.test/assert-eq (ss/rember1*C 'noodles '((food) more (food))) '((food) more (food)))
    (wat.test/assert-eq (ss/counter-get :ss::N) 0)

    ;; ...while the naive one rebuilds the whole list anyway: 5 conses for the same answer.
    (ss/counter-reset! :ss::N 0)
    (wat.test/assert-eq (ss/rember1*C2 'noodles '((food) more (food))) '((food) more (food)))
    (wat.test/assert-eq (ss/counter-get :ss::N) 5)

    ;; With the atom PRESENT, the escaping version conses only on the way back out: 1 here.
    (ss/counter-reset! :ss::N 0)
    (wat.test/assert-eq (ss/rember1*C 'food '((food) more (food))) '(() more (food)))
    (wat.test/assert-eq (ss/counter-get :ss::N) 1)

    (wat.kernel/println "seasoned-schemer ch17 we-change: ok")))
