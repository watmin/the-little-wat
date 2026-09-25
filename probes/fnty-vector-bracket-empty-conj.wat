;; F-203. A function type as a collection's type argument, spelled: bracket-empty-conj. `wat --check` accepted every
;; spelling; before the fix the RUNTIME refused the bracket forms as "malformed :wat::core::Vector".
;; Expected output: 11.
;; inline bracket function type, EMPTY Vector then conj
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [fs (wat.core/conj (wat.core/Vector :- [[wat.type/i64 :-> wat.type/i64]]) user/inc)]
    (wat.kernel/println ((wat.core/nth fs 0) 10))))
