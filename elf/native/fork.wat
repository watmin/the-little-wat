(wat.core/defn user/child [] :- wat.type/i64
  (wat.kernel/println 2)
  (wat.os/exit 7))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println 1)
  (wat.core/let [parent (wat.os/getpid)
                 pid (wat.os/fork)]
    (wat.core/if (wat.core/= pid 0)
      (user/child)
      (wat.core/let [st (wat.os/wait)]
        (wat.kernel/println (wat.core/rem (wat.core/quot st 256) 256))
        (wat.kernel/println (wat.core/if (wat.core/> pid 0) 1 0))
        (wat.kernel/println (wat.core/if (wat.core/= (wat.os/getpid) parent) 1 0)))))
  (wat.kernel/println 4))
