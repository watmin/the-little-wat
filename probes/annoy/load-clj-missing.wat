;; The Clojure/EDN-spelled load of a file that does NOT exist. If this exits 0, the
;; symbol-headed load form is silently ignored: no load, and no error.
(wat/load-file! "no-such-file.wat")
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println "ran"))
