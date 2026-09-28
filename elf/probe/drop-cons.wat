(wat.core/defrecord :user::Cell [k :- wat.type/i64 nxt :- :user::Cell])

(wat.core/defn user/build [i :- wat.type/i64 n :- wat.type/i64 tip :- :user::Cell] :- :user::Cell
  (wat.core/if (wat.core/= i n) tip
    (user/build (wat.core/+ i 1) n (:user::Cell :k i :nxt tip))))

(wat.core/defn user/seed [] :- :user::Cell
  (:user::Cell :k -1 :nxt (user/seed)))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [tip (user/seed)
                 chain (user/build 0 100000 tip)]
    (wat.kernel/println "0")))
