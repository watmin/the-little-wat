;; `nth` on a RECORD. HEAD's compiler had an arm for it whose answer typed as a default "i64" and was
;; never counted; the interpreter raises a runtime TypeMismatch. Stone 0a makes it a compile refusal.
(:wat::core::defrecord :user::P [a <- :wat::core::i64 b <- :wat::core::i64])
(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println (wat.core/nth (:user::P :a 7 :b 9) 0)))
