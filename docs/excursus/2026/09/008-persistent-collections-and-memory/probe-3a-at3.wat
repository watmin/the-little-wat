(wat.core/defrecord :user::Out [code :- wat.type/String sp :- wat.type/i64])
(wat.core/defn user/emit [o :- :user::Out h :- wat.type/String] :- :user::Out
  (wat.core/assoc o :code (wat.string/concat (:user::Out/code o) h)))
(wat.core/defn user/go [o :- :user::Out i :- wat.type/i64] :- :user::Out
  (wat.core/if (wat.core/= i 0) o
    (user/go (wat.core/assoc (user/emit o "ab") :sp i) (wat.core/- i 1))))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [r (user/go (:user::Out :code "" :sp 0) 3)]
    (wat.kernel/println (:user::Out/sp r))
    (wat.kernel/println (:user::Out/code r))))
