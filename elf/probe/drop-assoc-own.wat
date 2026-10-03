;; Owning `assoc` on a record. `user/step` reads the field it replaces and never reads the
;; record again, so the update is in place: the old string has to be dropped, and the record
;; the caller still holds must keep its old field. `user/both` prints the record after the
;; update, so that update copies. Four steps, then both shapes.
(wat.core/defrecord :user::Box [s :- wat.type/String])

(wat.core/defn user/step [b :- :user::Box] :- :user::Box
  (wat.core/assoc b :s (wat.string/concat (:user::Box/s b) "!")))

(wat.core/defn user/go [b :- :user::Box n :- wat.type/i64] :- :user::Box
  (wat.core/if (wat.core/= n 0) b
    (user/go (user/step b) (wat.core/- n 1))))

(wat.core/defn user/both [b :- :user::Box] :- :user::Box
  (wat.core/let [b2 (wat.core/assoc b :s (wat.string/concat (:user::Box/s b) "z"))]
    (wat.core/do
      (wat.kernel/println (:user::Box/s b))
      b2)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [b (user/go (:user::Box :s (wat.string/concat "a" "b")) 4)
                 c (user/both b)]
    (wat.core/do
      (wat.kernel/println (:user::Box/s b))
      (wat.kernel/println (:user::Box/s c)))))
