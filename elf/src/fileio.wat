;; The two verbs that reach the disk, both ways.
;;
;; `prim/read-hex` and `prim/write-hex` have a wat definition in elf/lib/prim.wat for the
;; interpreter and a native implementation in the compiler. `wat.io/read-file` is wat's own verb,
;; compiled to open/read/close. So this program -- which writes a file, reads it back as bytes,
;; and reads its own source as text -- runs both ways and must agree.
;;
;; That is F-119's contract in the only two places elf/ needs it, and it is what the last
;; thirteen census occurrences were.

(:wat::load-file! "../lib/prim.wat")

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let
    [path "elf/out/fileio.bin"
     hex "7f454c4602010100000000000000000048656c6c6f2c20627974657321"
     n (prim/write-hex path hex)
     back (prim/read-hex path)]
    (wat.kernel/println n)
    (wat.kernel/println (wat.string/length back))
    (wat.kernel/println (wat.core/= back hex))
    (wat.kernel/println (wat.string/subs back 0 8)))

  ;; and wat's own read-file, on a text file, compiled to the same three syscalls
  (wat.core/let [src (wat.io/read-file "elf/src/four.wat")]
    (wat.kernel/println (wat.string/length src))
    (wat.kernel/println (wat.string/contains? src "user/main"))
    (wat.kernel/println (wat.string/starts-with? src ";;"))))
