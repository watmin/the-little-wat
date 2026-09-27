;; poke of a String is a pointer leaving the language. The compiler must refuse it.
(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let [p (wat.os/mmap 4096)
                 s (wat.string/concat "a" "b")]
    (wat.os/poke p s)
    (wat.kernel/println (wat.os/peek p))))
