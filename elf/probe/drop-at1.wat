(wat.core/defrecord :user::Out [code :- wat.type/String sp :- wat.type/i64])
(wat.core/defn user/mk [n :- wat.type/i64] :- :user::Out
  (:user::Out :code (wat.i64/to-string n) :sp n))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [r (wat.core/assoc (user/mk 3) :sp 5)]
    (wat.kernel/println (:user::Out/sp r))
    (wat.kernel/println (:user::Out/code r))))
