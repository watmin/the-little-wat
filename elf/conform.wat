;; Is elf/lib/reader.wat a faithful replacement for wat's own reader?
;;
;; elf/src/reader.wat shows the reader is self-consistent -- it says the same thing compiled and
;; interpreted. That is not the same as being RIGHT. This reads real wat source both ways and
;; walks the two trees in step, asserting at every node that the kinds agree, that compound
;; forms have the same number of children, and that atoms have the same text.
;;
;; Compound forms are checked structurally rather than by text, because `ast->source` is a
;; **re-printer, not a slice of the file** -- wat-rs says so where it is implemented ("DISPLAY,
;; not transport") and offers `ast-span` and `read-string-with-comments` for the other job. Feed
;; it `"(a\n  b)"` and it answers `"(a b)"`. Our reader keeps the bytes it was given, which is a
;; deliberate difference and the reason this test compares structure there.
;;
;; Interpreter-only: it needs `read-string` and `match`, which are two of the things the reader
;; exists to stop needing.
;;
;; Run from the repository root:  wat elf/conform.wat

(:wat::load-file! "lib/reader.wat")

(:wat::core::typealias :cf::Nodes (:wat::core::Vector :- [:wat::WatAST]))

(wat.core/defn cf/compound? [k :- wat.type/String] :- wat.type/bool
  (wat.core/or (wat.core/= k "list")
    (wat.core/or (wat.core/= k "vector") (wat.core/= k "map"))))

(wat.core/defn cf/node [st :- :rd::St n :- wat.type/i64 a :- :wat::WatAST
                        seen :- wat.type/i64] :- wat.type/i64
  (wat.core/let [k (rd/kind st n)]
    (wat.core/do
      (wat.test/assert-eq k (wat.core/str (wat.core/ast-kind a)))
      (wat.core/if (cf/compound? k)
        (wat.core/do
          (wat.test/assert-eq (wat.core/length (rd/kids st n))
                              (wat.core/length (wat.core/ast->children a)))
          (cf/kids st (rd/kids st n) (wat.core/ast->children a) 0 (wat.core/+ seen 1)))
        (wat.core/do
          ;; an atom's display form IS its text, so these must match exactly
          (wat.test/assert-eq (rd/text st n) (wat.core/ast->source a))
          (wat.core/+ seen 1))))))

(wat.core/defn cf/kids [st :- :rd::St mine :- :rd::Kids theirs :- :cf::Nodes
                        i :- wat.type/i64 seen :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length mine)) seen
    (cf/kids st mine theirs (wat.core/+ i 1)
      (cf/node st (wat.core/nth mine i) (wat.core/nth theirs i) seen))))

(wat.core/defn cf/tops [st :- :rd::St theirs :- :cf::Nodes i :- wat.type/i64
                        seen :- wat.type/i64] :- wat.type/i64
  (wat.core/if (wat.core/>= i (wat.core/length (:rd::St/kids st))) seen
    (cf/tops st theirs (wat.core/+ i 1)
      (cf/node st (wat.core/nth (:rd::St/kids st) i) (wat.core/nth theirs i) seen))))

(wat.core/defn cf/file [path :- wat.type/String] :- wat.type/nil
  (wat.core/let [src (wat.io/read-file path)
                 st (rd/read src)]
    (wat.core/match (wat.core/read-string src)
      [wat.core/ReadOutcome.Forms {:forms fs}
        (wat.core/let [theirs (wat.core/ast->children fs)]
          (wat.core/do
            (wat.test/assert-eq (wat.core/length (:rd::St/kids st)) (wat.core/length theirs))
            (wat.kernel/println
              (wat.string/concat "conform: " path "  "
                (wat.i64/to-string (cf/tops st theirs 0 0)) " nodes agree, "
                (wat.i64/to-string (wat.core/length theirs)) " top-level forms"))))]
      [wat.core/ReadOutcome.Malformed {:cause e}
        (wat.kernel/println (wat.string/concat "conform: UNREADABLE " path))])))

(wat.core/defn user/main [] :- wat.type/nil
  (wat.core/do
    ;; keyword spelling, hand-written assembly helpers
    (cf/file "elf/lib/asm.wat")
    ;; Clojure spelling, records, typealiases, both kinds of literal
    (cf/file "elf/src/vectors.wat")
    (cf/file "elf/src/logic.wat")
    (cf/file "elf/src/strings.wat")
    ;; the reader reading itself
    (cf/file "elf/lib/reader.wat")
    ;; and the compiler, which is the corpus that matters
    (cf/file "elf/compile.wat")))
