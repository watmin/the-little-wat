;; lib.wat: a library for probes/load/main.wat. Definitions only, no main.
(wat.core/defn u/twice [x :- wat.type/i64] :- wat.type/i64
  (wat.core/+ x x))
