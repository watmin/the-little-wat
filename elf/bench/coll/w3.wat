(:wat::load-file! "common.wat")
(wat.core/defrecord :user::Box [k :- wat.type/i64])

(wat.core/defn user/step [b :- :user::Box i :- wat.type/i64 n :- wat.type/i64] :- :user::Box
  (wat.core/if (wat.core/= i n) b
    (user/step (wat.core/assoc b :k (wat.core/+ i 1)) (wat.core/+ i 1) n)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [n (user/n-of)
                 b (user/step (:user::Box :k 0) 0 n)]
    (wat.kernel/println (wat.string/concat "ANSWER " (wat.i64/to-string (:user::Box/k b))))))
