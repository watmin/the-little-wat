;; The two diagnostics, compiled.
;;
;; `assertion-failed!` and a failed `assert-eq` stop the program. The interpreter raises a
;; structured error with a span; a compiled program has neither, so these print to stderr and
;; exit 70. That means the two agree on every run that does NOT fail -- which is what this file
;; checks -- and differ only on the path that stops the program.
;;
;; Ten of the last twenty-one census occurrences were these two verbs.
;;
;; Run both ways; they must agree.

(wat.core/defn user/check [n :- wat.type/i64] :- wat.type/i64
  (wat.core/do
    (wat.test/assert-eq n n)
    (wat.test/assert-eq (wat.core/* n 2) (wat.core/+ n n))
    (wat.test/assert-eq (wat.string/concat "a" "b") "ab")
    n))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (user/check 7))
  (wat.test/assert-eq (wat.string/length "abc") 3)
  (wat.kernel/println "assertions held"))
