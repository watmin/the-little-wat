;; wat's reader, written in wat, in the subset this compiler can translate.
;;
;; This is 56 of the 89 occurrences elf/census.wat counts between the compiler and compiling
;; itself: `ast->source` (33), `ast->children` (21), `ast-kind` and `read-string`. Those four are
;; Rust inside the interpreter with no ABI a compiled program can reach (F-119), so a
;; self-hosting compiler either gets an intrinsic contract or owns its reader. This owns it.
;;
;; ## The representation
;;
;; Nodes live in an ARENA -- a Vector of records -- and refer to each other by index rather than
;; by pointer. That is not a style choice: a record whose field is a Vector of that same record
;; is a recursive type, and an arena sidesteps it entirely while also making a node cheap to pass
;; around. `:rd::kind`, `:rd::text` and `:rd::kids` are then exactly `ast-kind`, `ast->source`
;; and `ast->children`.
;;
;; `text` is the node's SOURCE TEXT, quotes and escapes included, because that is what
;; `ast->source` answers and what `:c::print-string` and `:c::str-lit` are built on.
;;
;; This file is definitions only. `elf/src/reader.wat` compiles it and runs it both ways;
;; `elf/conform.wat` cross-checks it against wat's OWN reader, which is the test that says it is
;; a faithful replacement rather than merely self-consistent.

;; ---------------------------------------------------------------- the kind, as a TAG
;;
;; **`kind` was a String, and comparing it cost 27.7% of the compiler's own runtime** (F-174):
;; 18.90% of all cycles was one `jne` after a `repz cmpsb` inside `str_eq`. The kinds are a
;; closed set of nine, which is an ENUM -- and an enum variant is a small integer, so the same
;; comparison becomes a machine word compare with no call at all.
;;
;; The String stays for now and `k` is computed beside it, ONCE per node, by
;; `rd/kind-of-str`. That classification is the only string comparison left on this path, and
;; it runs once per node instead of once per comparison per walk.
(:wat::core::defenum :rd::Kind :wat::enum::Pure
  :List []
  :Vector []
  :Map []
  ;; **not `:String`** -- that spelling is the retired bare primitive (arc 109 slice 1c) and
  ;; the checker rejects it. Caught by bootstrap's stage 0, not by `tools/variant.sh`, which
  ;; seeds from the native compiler and never runs the interpreter's type checks.
  :Str []
  :Keyword []
  :Bool []
  :Nil []
  :Int []
  :Symbol [])

;; **the tag is the only stored form.** Keeping a String beside it was duplicate state that had
;; to agree, and it did not: `:c::mknode` built nodes without the tag, so every inlined node
;; read back as `:List`. The bootstrap stayed green and the fixpoint byte-identical -- only
;; `tools/emitted.sh` caught it, as 18 of 68 programs moving. Deriving the String removes the
;; possibility.
(wat.core/defn rd/str-of-kind [k :- :rd::Kind] :- wat.type/String
  (wat.core/cond
    ((wat.core/= k (:rd::Kind.List {}))    "list")
    ((wat.core/= k (:rd::Kind.Symbol {}))  "symbol")
    ((wat.core/= k (:rd::Kind.Int {}))     "int")
    ((wat.core/= k (:rd::Kind.Vector {}))  "vector")
    ((wat.core/= k (:rd::Kind.Str {}))  "string")
    ((wat.core/= k (:rd::Kind.Keyword {})) "keyword")
    ((wat.core/= k (:rd::Kind.Bool {}))    "bool")
    ((wat.core/= k (:rd::Kind.Map {}))     "map")
    (:else                                 "nil")))

(:wat::core::defrecord :rd::Node
  [k <- :rd::Kind
   text <- :wat::core::String
   kids <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::typealias :rd::Arena (:wat::core::Vector :- [:rd::Node]))
(:wat::core::typealias :rd::Kids (:wat::core::Vector :- [:wat::core::i64]))

;; the reader's whole state: what has been built, where it is, what it just made, and the
;; children it is collecting
(:wat::core::defrecord :rd::St
  [arena <- :rd::Arena  pos <- :wat::core::i64  node <- :wat::core::i64  kids <- :rd::Kids])

;; ---------------------------------------------------------------- characters

;; **A character is a BYTE here, not a one-character String.** It used to be the latter, because
;; wat has no character type (F-062) -- and `(wat.string/subs src i (+ i 1))` walks to character
;; `i` every time it is asked, so scanning was O(n^2) in the source and `perf` put
;; `Chars::advance_by` at 14.5% of the time spent reading. `byte-at` is O(1).
;;
;; **The character classes stay written as strings and are scanned as bytes.** That matters more
;; than it looks: a literal's escapes are handled one way by the interpreter and another by the
;; compiler (F-120 -- nothing unescapes, a literal compiles as its SOURCE TEXT), so `" \t\n\r,"`
;; may be five bytes or seven depending on who is running. Comparing a source byte against the
;; SET'S OWN BYTES is right either way, which is the property `wat.string/contains?` already had
;; and the reason this is a faithful swap rather than a rewrite.
(wat.core/defn rd/byte [src :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.string/byte-at src i))

;; the first byte of a literal, so a delimiter is written as itself and never as a number
(wat.core/defn rd/b1 [s :- wat.type/String] :- wat.type/i64
  (wat.string/byte-at s 0))

(wat.core/defn rd/in? [set :- wat.type/String c :- wat.type/i64 i :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((wat.core/>= i (wat.string/byte-length set)) false)
    ((wat.core/= (wat.string/byte-at set i) c) true)
    (:else (rd/in? set c (wat.core/+ i 1)))))

(wat.core/defn rd/ws? [c :- wat.type/i64] :- wat.type/bool
  (rd/in? " \t\n\r," c 0))

(wat.core/defn rd/delim? [c :- wat.type/i64] :- wat.type/bool
  (rd/in? "()[]{}\";" c 0))

(wat.core/defn rd/digit? [c :- wat.type/i64] :- wat.type/bool
  (rd/in? "0123456789" c 0))

;; ---------------------------------------------------------------- scanning

(wat.core/defn rd/eol [src :- wat.type/String n :- wat.type/i64 i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i n) i)
    ((wat.core/= (rd/byte src i) (rd/b1 "\n")) (wat.core/+ i 1))
    (:else (rd/eol src n (wat.core/+ i 1)))))

;; whitespace and `;` comments, to the next thing that matters
(wat.core/defn rd/skip [src :- wat.type/String n :- wat.type/i64 i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i n) i)
    ((rd/ws? (rd/byte src i)) (rd/skip src n (wat.core/+ i 1)))
    ((wat.core/= (rd/byte src i) (rd/b1 ";")) (rd/skip src n (rd/eol src n i)))
    (:else i)))

(wat.core/defn rd/atom-end [src :- wat.type/String n :- wat.type/i64 i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i n) i)
    ((rd/ws? (rd/byte src i)) i)
    ((rd/delim? (rd/byte src i)) i)
    (:else (rd/atom-end src n (wat.core/+ i 1)))))

;; from just after the opening quote to just after the closing one; a backslash takes the next
;; character with it, whatever it is
(wat.core/defn rd/str-end [src :- wat.type/String n :- wat.type/i64 i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i n) i)
    ((wat.core/= (rd/byte src i) (rd/b1 "\\")) (rd/str-end src n (wat.core/+ i 2)))
    ((wat.core/= (rd/byte src i) (rd/b1 "\"")) (wat.core/+ i 1))
    (:else (rd/str-end src n (wat.core/+ i 1)))))

;; ---------------------------------------------------------------- classifying an atom

(wat.core/defn rd/digits? [t :- wat.type/String i :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((wat.core/>= i (wat.string/byte-length t)) true)
    ((rd/digit? (rd/byte t i)) (rd/digits? t (wat.core/+ i 1)))
    (:else false)))

(wat.core/defn rd/int? [t :- wat.type/String] :- wat.type/bool
  (wat.core/cond
    ((wat.core/= (wat.string/byte-length t) 0) false)
    ((wat.string/starts-with? t "-")
      (wat.core/and (wat.core/> (wat.string/byte-length t) 1)
                    (rd/digits? t 1)))
    (:else (rd/digits? t 0))))

(wat.core/defn rd/classify [t :- wat.type/String] :- :rd::Kind
  (wat.core/cond
    ((wat.string/starts-with? t ":") (:rd::Kind.Keyword {}))
    ((wat.core/= t "true")  (:rd::Kind.Bool {}))
    ((wat.core/= t "false") (:rd::Kind.Bool {}))
    ((wat.core/= t "nil")   (:rd::Kind.Nil {}))
    ((rd/int? t)            (:rd::Kind.Int {}))
    (:else                  (:rd::Kind.Symbol {}))))

;; ---------------------------------------------------------------- building

(wat.core/defn rd/empty-kids [] :- :rd::Kids (wat.core/Vector :- [wat.type/i64]))

;; `n` is passed rather than taken from `arena`, so that `arena` is read exactly once here and
;; the compiler can extend it in place instead of copying the whole thing (C-127)
(wat.core/defn rd/add [arena :- :rd::Arena n :- wat.type/i64
                       kind :- :rd::Kind text :- wat.type/String
                       kids :- :rd::Kids pos :- wat.type/i64] :- :rd::St
  (:rd::St :arena (wat.core/conj arena
                    (:rd::Node :k kind :text text :kids kids))
           :pos pos :node n :kids (rd/empty-kids)))

;; ---------------------------------------------------------------- the parser

(wat.core/defn rd/form [src :- wat.type/String n :- wat.type/i64 st :- :rd::St] :- :rd::St
  (wat.core/let [i (rd/skip src n (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/cond
      ((wat.core/>= i n)
        (:rd::St :arena a :pos i :node -1 :kids (rd/empty-kids)))
      ((wat.core/= (rd/byte src i) (rd/b1 "(")) (rd/seq src n a i ")" (:rd::Kind.List {})))
      ((wat.core/= (rd/byte src i) (rd/b1 "[")) (rd/seq src n a i "]" (:rd::Kind.Vector {})))
      ((wat.core/= (rd/byte src i) (rd/b1 "{")) (rd/seq src n a i "}" (:rd::Kind.Map {})))
      ((wat.core/= (rd/byte src i) (rd/b1 "\""))
        (wat.core/let [e (rd/str-end src n (wat.core/+ i 1))]
          (rd/add a (wat.core/length a) (:rd::Kind.Str {}) (wat.string/byte-subs src i e) (rd/empty-kids) e)))
      (:else
        (wat.core/let [e (rd/atom-end src n i)
                       t (wat.string/byte-subs src i e)]
          (rd/add a (wat.core/length a) (rd/classify t) t (rd/empty-kids) e))))))

;; children up to the closing delimiter; `kids` carries the indices back out
(wat.core/defn rd/kids-of [src :- wat.type/String n :- wat.type/i64 st :- :rd::St
                           close :- wat.type/String acc :- :rd::Kids] :- :rd::St
  (wat.core/let [i (rd/skip src n (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/cond
      ((wat.core/>= i n)
        (:rd::St :arena a :pos i :node -1 :kids acc))
      ((wat.core/= (rd/byte src i) (rd/b1 close))
        (:rd::St :arena a :pos (wat.core/+ i 1) :node -1 :kids acc))
      (:else
        (wat.core/let [r (rd/form src n (:rd::St :arena a :pos i :node -1 :kids acc))]
          (rd/kids-of src n r close (wat.core/conj acc (:rd::St/node r))))))))

(wat.core/defn rd/seq [src :- wat.type/String n :- wat.type/i64 a :- :rd::Arena i :- wat.type/i64
                       close :- wat.type/String kind :- :rd::Kind] :- :rd::St
  (wat.core/let [r (rd/kids-of src n (:rd::St :arena a :pos (wat.core/+ i 1) :node -1
                                            :kids (rd/empty-kids))
                               close (rd/empty-kids))
                 ra (:rd::St/arena r)]
    (rd/add ra (wat.core/length ra) kind (wat.string/byte-subs src i (:rd::St/pos r))
            (:rd::St/kids r) (:rd::St/pos r))))

(wat.core/defn rd/tops [src :- wat.type/String n :- wat.type/i64 st :- :rd::St acc :- :rd::Kids] :- :rd::St
  (wat.core/let [i (rd/skip src n (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/if (wat.core/>= i n)
      (:rd::St :arena a :pos i :node -1 :kids acc)
      (wat.core/let [r (rd/form src n (:rd::St :arena a :pos i :node -1 :kids acc))]
        (rd/tops src n r (wat.core/conj acc (:rd::St/node r)))))))

(wat.core/defn rd/empty-arena [] :- :rd::Arena (wat.core/Vector :- [:rd::Node]))

;; read another file into the SAME arena, so that node indices from every file a program is made
;; of live in one space. That is what `load-file!` needs: two arenas would give two node 7s.
;; **`n` is the source's length, measured once and carried.** Every scanner below used to ask
;; `(wat.string/length src)` at its own bounds check -- seven sites, each inside a loop over the
;; characters. wat measures a String in CHARACTERS and the substrate holds UTF-8, so that call is
;; O(n) in the whole source: `perf` put `core::str::count::do_count_chars` at 19-31% of the time
;; spent reading, which made reading O(n^2) in the source size -- 4x the source was 8x the time.
;; The length does not change while the source is being read, so it is a parameter (F-138).
(wat.core/defn rd/read-into [a :- :rd::Arena src :- wat.type/String] :- :rd::St
  (rd/tops src (wat.string/byte-length src)
    (:rd::St :arena a :pos 0 :node -1 :kids (rd/empty-kids)) (rd/empty-kids)))

(wat.core/defn rd/read [src :- wat.type/String] :- :rd::St
  (rd/read-into (rd/empty-arena) src))

;; ---------------------------------------------------------------- the surface it replaces

(wat.core/defn rd/kind [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (rd/str-of-kind (:rd::Node/k (wat.core/nth (:rd::St/arena st) n))))
;; the same question, as a tag -- see :rd::Kind above
(wat.core/defn rd/kindv [st :- :rd::St n :- wat.type/i64] :- :rd::Kind
  (:rd::Node/k (wat.core/nth (:rd::St/arena st) n)))
(wat.core/defn rd/text [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (:rd::Node/text (wat.core/nth (:rd::St/arena st) n)))
(wat.core/defn rd/kids [st :- :rd::St n :- wat.type/i64] :- :rd::Kids
  (:rd::Node/kids (wat.core/nth (:rd::St/arena st) n)))

;; ---------------------------------------------------------------- what it read

