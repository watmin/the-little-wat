;; A cond clause whose test mentions a record and whose body does not.
;; The next clause still uses the record, so the test is not the last use
;; and the call shares. Taking this clause skips that later use. The record
;; is :c::Prog so the clause drop's type test sees it.
(wat.core/defrecord :c::Prog [s :- wat.type/String])

(wat.core/defn user/look [a :- wat.type/i64 pg :- :c::Prog] :- wat.type/bool
  (wat.core/cond
    ((wat.core/= a 0) (wat.core/= (wat.string/length (:c::Prog/s pg)) 1))
    ((wat.core/and (wat.core/not= a 7)
                   (wat.core/not= (wat.string/length (:c::Prog/s pg)) 99)) false)
    (:else (wat.core/= (wat.string/length (:c::Prog/s pg)) 2))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println
      (wat.core/if (user/look 0 (:c::Prog :s (wat.string/concat "a" "b"))) 1 0))
    (wat.kernel/println
      (wat.core/if (user/look 1 (:c::Prog :s (wat.string/concat "a" "b"))) 1 0))
    (wat.kernel/println
      (wat.core/if (user/look 7 (:c::Prog :s (wat.string/concat "a" "b"))) 1 0))))
