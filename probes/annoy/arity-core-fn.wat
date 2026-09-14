;; F-014 scope: a CORE function (length) called with the wrong number of arguments.
;; Caught at startup (exit 3) or only at runtime (exit 1)?
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/length [1 2] [3])))
