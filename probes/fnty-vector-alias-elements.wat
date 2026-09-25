;; F-203. A function type as a collection's type argument, spelled: alias-elements. `wat --check` accepted every
;; spelling; before the fix the RUNTIME refused the bracket forms as "malformed :wat::core::Vector".
;; Expected output: 11.
;; alias element type, elements passed to the constructor
(:wat::core::typealias :user::Op [wat.type/i64 :-> wat.type/i64])
(wat.core/defn user/inc [n :- wat.type/i64] :- wat.type/i64 (wat.core/+ n 1))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [fs (wat.core/Vector :- [:user::Op] user/inc user/inc)]
    (wat.kernel/println ((wat.core/nth fs 1) 10))))
