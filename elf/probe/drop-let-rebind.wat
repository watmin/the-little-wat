;; A `let` that rebinds a record parameter. The outer record's last use is the
;; init; the inner record's last use is the body. Both counts reach zero.
(wat.core/defrecord :user::Box [s :- wat.type/String])

(wat.core/defn user/use [b :- :user::Box] :- wat.type/i64
  (wat.string/length (:user::Box/s b)))

(wat.core/defn user/go [b :- :user::Box] :- wat.type/nil
  (wat.core/let [b (wat.core/assoc b :s (wat.string/concat (:user::Box/s b) "z"))]
    (wat.kernel/println (user/use b))))

(wat.core/defn user/main [] :- wat.type/nil
  (user/go (:user::Box :s (wat.string/concat "a" "b"))))
