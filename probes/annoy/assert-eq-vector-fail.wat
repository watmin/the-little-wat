;; F-011 scope: a FAILING assert-eq on two Vectors, on purpose. Readable, or unreadable like
;; the quoted-list case? Expected: exit 2 with readable actual/expected.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.test/assert-eq [1 2 3] [1 2 4]))
