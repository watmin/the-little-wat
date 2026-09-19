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

;; **The arena is CHUNKED**, and that is the whole difference between reading a 2,600-line file
;; in 745 MB and reading it in twenty. wat has no positional vector update (F-104), so appending
;; to a flat Vector copies all of it -- n copies of an n-element arena, which is the quadratic
;; C-140 measured and C-143 failed to remove from the compiler's side. A block list makes an
;; append copy one BLOCK plus the spine, `b + n/b` words instead of `n`, and it needs nothing
;; from the compiler: it is a data structure, in our own code.
(:wat::core::typealias :rd::Block (:wat::core::Vector :- [:rd::Node]))
(:wat::core::typealias :rd::Arena (:wat::core::Vector :- [:rd::Block]))
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

(wat.core/defn rd/bsize [] :- wat.type/i64 128)
(wat.core/defn rd/empty-block [] :- :rd::Block (wat.core/Vector :- [:rd::Node]))

;; how many nodes are in the arena: full blocks, plus whatever is in the last one
(wat.core/defn rd/count [a :- :rd::Arena] :- wat.type/i64
  (wat.core/if (wat.core/= (wat.core/length a) 0) 0
    (wat.core/+ (wat.core/* (wat.core/- (wat.core/length a) 1) (rd/bsize))
                (wat.core/length (wat.core/nth a (wat.core/- (wat.core/length a) 1))))))

(wat.core/defn rd/at [a :- :rd::Arena n :- wat.type/i64] :- :rd::Node
  (wat.core/nth (wat.core/nth a (wat.core/quot n (rd/bsize))) (wat.core/rem n (rd/bsize))))

;; the spine without its last block, rebuilt -- `n/b` words
(wat.core/defn rd/spine [a :- :rd::Arena i :- wat.type/i64 acc :- :rd::Arena] :- :rd::Arena
  (wat.core/if (wat.core/>= i (wat.core/- (wat.core/length a) 1)) acc
    (rd/spine a (wat.core/+ i 1) (wat.core/conj acc (wat.core/nth a i)))))

;; a full last block, or none at all, starts a new one; otherwise the last block is rebuilt
(wat.core/defn rd/push [a :- :rd::Arena nd :- :rd::Node] :- :rd::Arena
  (wat.core/let [k (wat.core/length a)]
    (wat.core/if (wat.core/or (wat.core/= k 0)
                   (wat.core/>= (wat.core/length (wat.core/nth a (wat.core/- k 1))) (rd/bsize)))
      (wat.core/conj a (wat.core/conj (rd/empty-block) nd))
      (wat.core/conj (rd/spine a 0 (rd/empty-arena))
                     (wat.core/conj (wat.core/nth a (wat.core/- k 1)) nd)))))

;; `n` is passed rather than taken from `arena`, so that `arena` is read exactly once here --
;; which was meant to let the compiler extend it in place (C-127). It never did: the arena is
;; handed to this function as a bare parameter, `:c::push-args` counts that as a share, and the
;; count is increment-only, so `conj` copied every time. **C-143 tried to fix that in the
;; compiler and could not** -- a reference created without an increment is a hole in a
;; whole-program invariant, and there turned out to be four kinds of them. `rd/push` sidesteps
;; the question instead: a copy that is one block long is cheap however many times you do it.
(wat.core/defn rd/add [arena :- :rd::Arena n :- wat.type/i64
                       kind :- wat.type/String text :- wat.type/String
                       kids :- :rd::Kids pos :- wat.type/i64] :- :rd::St
  (:rd::St :arena (rd/push arena (:rd::Node :kind kind :text text :kids kids))
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
          (rd/add a (rd/count a) "string" (wat.string/subs src i e) (rd/empty-kids) e)))
      (:else
        (wat.core/let [e (rd/atom-end src i)
                       t (wat.string/subs src i e)]
          (rd/add a (rd/count a) (rd/classify t) t (rd/empty-kids) e))))))

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
    (rd/add ra (rd/count ra) kind (wat.string/subs src i (:rd::St/pos r))
            (:rd::St/kids r) (:rd::St/pos r))))

(wat.core/defn rd/tops [src :- wat.type/String st :- :rd::St acc :- :rd::Kids] :- :rd::St
  (wat.core/let [i (rd/skip src (:rd::St/pos st))
                 a (:rd::St/arena st)]
    (wat.core/if (wat.core/>= i (wat.string/length src))
      (:rd::St :arena a :pos i :node -1 :kids acc)
      (wat.core/let [r (rd/form src (:rd::St :arena a :pos i :node -1 :kids acc))]
        (rd/tops src r (wat.core/conj acc (:rd::St/node r)))))))

(wat.core/defn rd/empty-arena [] :- :rd::Arena (wat.core/Vector :- [:rd::Block]))

;; read another file into the SAME arena, so that node indices from every file a program is made
;; of live in one space. That is what `load-file!` needs: two arenas would give two node 7s.
(wat.core/defn rd/read-into [a :- :rd::Arena src :- wat.type/String] :- :rd::St
  (rd/tops src (:rd::St :arena a :pos 0 :node -1 :kids (rd/empty-kids)) (rd/empty-kids)))

(wat.core/defn rd/read [src :- wat.type/String] :- :rd::St
  (rd/read-into (rd/empty-arena) src))

;; ---------------------------------------------------------------- the surface it replaces

(wat.core/defn rd/kind [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (:rd::Node/kind (rd/at (:rd::St/arena st) n)))
(wat.core/defn rd/text [st :- :rd::St n :- wat.type/i64] :- wat.type/String
  (:rd::Node/text (rd/at (:rd::St/arena st) n)))
(wat.core/defn rd/kids [st :- :rd::St n :- wat.type/i64] :- :rd::Kids
  (:rd::Node/kids (rd/at (:rd::St/arena st) n)))

;; ---------------------------------------------------------------- what it read

