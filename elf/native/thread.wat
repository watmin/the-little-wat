(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [shared (wat.os/mmap 4096)
                 stack (wat.os/mmap 65536)]
    (wat.os/poke shared 11)
    (wat.kernel/println (wat.os/peek shared))
    (wat.core/if (wat.core/= (wat.os/clone (wat.core/+ stack 65536)) 0)
      (wat.core/do
        (wat.os/poke shared 22)
        (wat.os/exit 0))
      (wat.core/do
        (wat.os/wait)
        (wat.kernel/println (wat.os/peek shared))))))
