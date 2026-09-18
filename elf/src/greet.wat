(wat.core/defn user/main [] :- wat.type/nil
  (wat.kernel/println "compiled by wat, running on the kernel")
  (wat.kernel/println (wat.core/* 6 7)))
