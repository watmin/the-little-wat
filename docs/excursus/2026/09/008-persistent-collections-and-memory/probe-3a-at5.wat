(wat.core/defrecord :user::Out [code :- wat.type/String sp :- wat.type/i64])
(wat.core/defn user/emit [o :- :user::Out h :- wat.type/String] :- :user::Out
  (wat.core/assoc o :code (wat.string/concat (:user::Out/code o) h)))
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [o (:user::Out :code "x" :sp 0)
                 t (user/emit o "ab")
                 r (wat.core/assoc t :sp (wat.core/+ (:user::Out/sp o) 8))]
    (wat.kernel/println (:user::Out/sp r))
    (wat.kernel/println (:user::Out/code r))
    (wat.kernel/println (:user::Out/code o))))
