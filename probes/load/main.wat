;; main.wat: can a program run by the `wat` binary load a sibling file's definitions?
;; This decides how later chapters reuse earlier ones. Expected: 42
(:wat::load-file! "lib.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (u/twice 21)))
