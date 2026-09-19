;; The reader, run. `elf/lib/reader.wat` is the reader itself; this compiles it and prints what
;; it made of a small program, both ways.
;;
;; `load-file!` is a compile-time include here, the same as it is in the interpreter -- which is
;; one more of the 89 census occurrences gone, and the thing that lets the reader be a library
;; two programs share.

(:wat::load-file! "../lib/reader.wat")

(wat.core/defn rd/show [st :- :rd::St n :- wat.type/i64 depth :- wat.type/i64] :- wat.type/nil
  (wat.core/do
    (wat.kernel/println (wat.string/concat (rd/indent depth "") (rd/kind st n)
                                           "  " (rd/text st n)))
    (rd/show-kids st (rd/kids st n) 0 (wat.core/+ depth 1))))

(wat.core/defn rd/indent [n :- wat.type/i64 acc :- wat.type/String] :- wat.type/String
  (wat.core/if (wat.core/= n 0) acc (rd/indent (wat.core/- n 1) (wat.string/concat acc "  "))))

(wat.core/defn rd/show-kids [st :- :rd::St ks :- :rd::Kids i :- wat.type/i64
                             depth :- wat.type/i64] :- wat.type/nil
  (wat.core/if (wat.core/>= i (wat.core/length ks)) nil
    (wat.core/do (rd/show st (wat.core/nth ks i) depth)
                 (rd/show-kids st ks (wat.core/+ i 1) depth))))

(wat.core/defn rd/show-tops [st :- :rd::St i :- wat.type/i64] :- wat.type/nil
  (wat.core/if (wat.core/>= i (wat.core/length (:rd::St/kids st))) nil
    (wat.core/do (rd/show st (wat.core/nth (:rd::St/kids st) i) 0)
                 (rd/show-tops st (wat.core/+ i 1)))))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/let
    [src (wat.string/concat
           "; a comment, skipped\n(wat.core/defn user/f [x :- wat.type/i64] :- wat.type/i64\n"
           "  (wat.core/if (wat.core/= x 0) nil [1 -2 \"a\\\"b\" :kw true]))\n")
     st (rd/read src)]
    (wat.core/do
      (wat.kernel/println (wat.core/length (:rd::St/arena st)))
      (wat.kernel/println (wat.core/length (:rd::St/kids st)))
      (rd/show-tops st 0))))
