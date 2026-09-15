;; probes/koans/defmacro-macroexpand.wat: two koans (koans/literal/24-macros.tsv, rows 4-5) came
;; back false rather than failing. The macro is defined in the Clojure spelling, and the koan
;; compares its macroexpansion. What does macroexpand answer, and does the macro exist?

(wat.core/defmacro infix-concise [form] `(~(wat.core/second form) ~(wat.core/first form) ~(wat.core/nth form 2)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.edn/write (wat.core/macroexpand '(infix-concise (6 * 7)))))
    (wat.kernel/println (wat.edn/write (wat.core/= '(* 6 7) (wat.core/macroexpand '(infix-concise (6 * 7))))))))
