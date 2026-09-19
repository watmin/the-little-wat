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

(:wat::core::defrecord :rd::Node
  [kind <- :wat::core::String
   text <- :wat::core::String
   kids <- (:wat::core::Vector :- [:wat::core::i64])])

(:wat::core::typealias :rd::Arena (:wat::core::Vector :- [:rd::Node]))
(:wat::core::typealias :rd::Kids (:wat::core::Vector :- [:wat::core::i64]))

;; the reader's whole state: what has been built, where it is, what it just made, and the
;; children it is collecting
(:wat::core::defrecord :rd::St
  [arena <- :rd::Arena  pos <- :wat::core::i64  node <- :wat::core::i64  kids <- :rd::Kids])

;; ---------------------------------------------------------------- characters
;;
;; wat has no character type, so a character is a one-character String and a character class is
;; `contains?` over a literal. That is F-062 wearing its everyday clothes.

(wat.core/defn rd/ch [src :- wat.type/String i :- wat.type/i64] :- wat.type/String
  (wat.string/subs src i (wat.core/+ i 1)))

(wat.core/defn rd/ws? [c :- wat.type/String] :- wat.type/bool
  (wat.string/contains? " \t\n\r," c))

(wat.core/defn rd/delim? [c :- wat.type/String] :- wat.type/bool
  (wat.string/contains? "()[]{}\";" c))

(wat.core/defn rd/digit? [c :- wat.type/String] :- wat.type/bool
  (wat.string/contains? "0123456789" c))

;; ---------------------------------------------------------------- scanning

(wat.core/defn rd/eol [src :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i (wat.string/length src)) i)
    ((wat.core/= (rd/ch src i) "\n") (wat.core/+ i 1))
    (:else (rd/eol src (wat.core/+ i 1)))))

;; whitespace and `;` comments, to the next thing that matters
(wat.core/defn rd/skip [src :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i (wat.string/length src)) i)
    ((rd/ws? (rd/ch src i)) (rd/skip src (wat.core/+ i 1)))
    ((wat.core/= (rd/ch src i) ";") (rd/skip src (rd/eol src i)))
    (:else i)))

(wat.core/defn rd/atom-end [src :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i (wat.string/length src)) i)
    ((rd/ws? (rd/ch src i)) i)
    ((rd/delim? (rd/ch src i)) i)
    (:else (rd/atom-end src (wat.core/+ i 1)))))

;; from just after the opening quote to just after the closing one; a backslash takes the next
;; character with it, whatever it is
(wat.core/defn rd/str-end [src :- wat.type/String i :- wat.type/i64] :- wat.type/i64
  (wat.core/cond
    ((wat.core/>= i (wat.string/length src)) i)
    ((wat.core/= (rd/ch src i) "\\") (rd/str-end src (wat.core/+ i 2)))
    ((wat.core/= (rd/ch src i) "\"") (wat.core/+ i 1))
    (:else (rd/str-end src (wat.core/+ i 1)))))

;; ---------------------------------------------------------------- classifying an atom

(wat.core/defn rd/digits? [t :- wat.type/String i :- wat.type/i64] :- wat.type/bool
  (wat.core/cond
    ((wat.core/>= i (wat.string/length t)) true)
    ((rd/digit? (rd/ch t i)) (rd/digits? t (wat.core/+ i 1)))
    (:else false)))

(wat.core/defn rd/int? [t :- wat.type/String] :- wat.type/bool
  (wat.core/cond
    ((wat.core/= (wat.string/length t) 0) false)
    ((wat.string/starts-with? t "-")
      (wat.core/and (wat.core/> (wat.string/length t) 1)
                    (rd/digits? t 1)))
    (:else (rd/digits? t 0))))

(wat.core/defn rd/classify [t :- wat.type/String] :- wat.type/String
  (wat.core/cond
    ((wat.string/starts-with? t ":") "keyword")
    ((wat.core/= t "true") "bool")
    ((wat.core/= t "false") "bool")
    ((wat.core/= t "nil") "nil")
    ((rd/int? t) "int")
    (:else "symbol")))

;; ---------------------------------------------------------------- building

(wat.core/defn rd/empty-kids [] :- :rd::Kids (wat.core/Vector :- [wat.type/i64]))

;; `n` is passed rather than taken from `arena`, so that `arena` is read exactly once here and
;; the compiler can extend it in place instead of copying the whole thing (C-127)
(wat.core/defn rd/add [arena :- :rd::Arena n :- wat.type/i64
                       kind :- wat.type/String text :- wat.type/String
                       kids :- :rd::Kids pos :- wat.type/i64] :- :rd::St
  (:rd::St :arena (wat.core/conj arena (:rd::Node :kind kind :text text :kids kids))
           :pos pos :node n :kids (rd/empty-kids)))

;; ---------------------------------------------------------------- the parser

(wat.core/defn rd/form [src :- wat.type/String st :- :rd::St] :- :rd::St
  (wat.core/let [i (rd/skip src (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/cond
      ((wat.core/>= i (wat.string/length src))
        (:rd::St :arena a :pos i :node -1 :kids (rd/empty-kids)))
      ((wat.core/= (rd/ch src i) "(") (rd/seq src a i ")" "list"))
      ((wat.core/= (rd/ch src i) "[") (rd/seq src a i "]" "vector"))
      ((wat.core/= (rd/ch src i) "{") (rd/seq src a i "}" "map"))
      ((wat.core/= (rd/ch src i) "\"")
        (wat.core/let [e (rd/str-end src (wat.core/+ i 1))]
          (rd/add a (wat.core/length a) "string" (wat.string/subs src i e) (rd/empty-kids) e)))
      (:else
        (wat.core/let [e (rd/atom-end src i)
                       t (wat.string/subs src i e)]
          (rd/add a (wat.core/length a) (rd/classify t) t (rd/empty-kids) e))))))

;; children up to the closing delimiter; `kids` carries the indices back out
(wat.core/defn rd/kids-of [src :- wat.type/String st :- :rd::St
                           close :- wat.type/String acc :- :rd::Kids] :- :rd::St
  (wat.core/let [i (rd/skip src (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/cond
      ((wat.core/>= i (wat.string/length src))
        (:rd::St :arena a :pos i :node -1 :kids acc))
      ((wat.core/= (rd/ch src i) close)
        (:rd::St :arena a :pos (wat.core/+ i 1) :node -1 :kids acc))
      (:else
        (wat.core/let [r (rd/form src (:rd::St :arena a :pos i :node -1 :kids acc))]
          (rd/kids-of src r close (wat.core/conj acc (:rd::St/node r))))))))

(wat.core/defn rd/seq [src :- wat.type/String a :- :rd::Arena i :- wat.type/i64
                       close :- wat.type/String kind :- wat.type/String] :- :rd::St
  (wat.core/let [r (rd/kids-of src (:rd::St :arena a :pos (wat.core/+ i 1) :node -1
                                            :kids (rd/empty-kids))
                               close (rd/empty-kids))
                 ra (:rd::St/arena r)]
    (rd/add ra (wat.core/length ra) kind (wat.string/subs src i (:rd::St/pos r))
            (:rd::St/kids r) (:rd::St/pos r))))

(wat.core/defn rd/tops [src :- wat.type/String st :- :rd::St acc :- :rd::Kids] :- :rd::St
  (wat.core/let [i (rd/skip src (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/if (wat.core/>= i (wat.string/length src))
      (:rd::St :arena a :pos i :node -1 :kids acc)
      (wat.core/let [r (rd/form src (:rd::St :arena a :pos i :node -1 :kids acc))]
        (rd/tops src r (wat.core/conj acc (:rd::St/node r)))))))

(wat.core/defn rd/empty-arena [] :- :rd::Arena (wat.core/Vector :- [:rd::Node]))

;; read another file into the SAME arena, so that node indices from every file a program is made
;; of live in one space. That is what `load-file!` needs: two arenas would give two node 7s.
(wat.core/defn rd/read-into [a :- :rd::Arena src :- wat.type/String] :- :rd::St
  (rd/tops src (:rd::St :arena a :pos 0 :node -1 :kids (rd/empty-kids)) (rd/empty-kids)))

(wat.core/defn rd/read [src :- wat.type/String] :- :rd::St
  (rd/read-into (rd/empty-arena) src))

;; ---------------------------------------------------------------- the surface it replaces

(wat.core/defn rd/kind [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (:rd::Node/kind (wat.core/nth (:rd::St/arena st) n)))
(wat.core/defn rd/text [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (:rd::Node/text (wat.core/nth (:rd::St/arena st) n)))
(wat.core/defn rd/kids [st :- :rd::St n :- wat.type/i64] :- :rd::Kids
  (:rd::Node/kids (wat.core/nth (:rd::St/arena st) n)))

;; ---------------------------------------------------------------- what it read

