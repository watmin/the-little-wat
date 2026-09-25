;; tools/rules/check.wat -- the compiler must agree with itself at every boundary.
;;
;; Excursus 002 stone 1. `elf/compile.wat`, asked (`:c::compile-as ... true`), SAYS what it
;; decided: at each call to a user function the type it gave each argument (`CArg`), and for each
;; `defn` the type it gave each parameter (`CParam`), each at the source position wat-grep gives
;; the same node. This program reads those lines on stdin, puts them in ONE fact base with
;; wat-grep's own facts for every file the program was read from, and lets wat-rs's rete join
;; them.
;;
;; **The rules derive no type.** Every type below arrives in a `CArg` or `CParam` fact, and the
;; rules only compare two of them. What the rules DO supply is the syntactic join the compiler's
;; facts do not state: that the argument at index i of the call written at line:col feeds the
;; parameter written at index i of the `defn` its head names. Writing a type derivation here would
;; put the same logic in two languages -- which is the disease F-194 was.
;;
;; stdin, one EDN string per line (what the compiler's `println` prints), grouped per program:
;;   "PROG <path>"  "FILE <path>"...  "CArg ..."...  "CParam ..."...  "END"
;; `tools/rules.sh` produces exactly that. Anything else on stdin is ignored.
;;
;; **Stone 2 -- the compiler knows what the language knows.** The same compile also SAYS, at its
;; type waist (`:c::type-of`), the type it gave every node it typed (`CType`), in wat's spelling
;; through its one translation function (`:c::wat-ty`). wat-rs's checker, asked
;; (`WAT_CHECK_TYPES=1 wat --check`), says the type its `infer` gave every node (`KType`; `KUnres`
;; where a type variable survived). The rules join the two BY POSITION and nothing else, and
;; compare the strings -- again deriving no type:
;;   type-conflict      the compiler's type is neither the checker's type nor that type with its
;;                      variants widened to their enum                        (a FINDING)
;;   type-AGREES        equal to the checker's type                        (counted)
;;   type-refined       equal only once the checker's variant is widened to its enum -- the
;;                      compiler knows the enum, the language knows the variant (counted)
;;   type-partial       the compiler's spelling is not a whole wat type (a function type: arity
;;                      and return only) -- joined, not compared            (counted)
;;   type-untranslatable  the one translation did not know the spelling    (printed)
;;   type-unresolved    the checker's type at the node kept a variable (STOP-4) (printed)
;;   checker-multi      one position, two checker types (STOP-3)           (printed)
;;   compiler-multi     one position, two compiler types                   (printed)
;;   ctype-unjoined     the compiler typed a node the checker did not      (counted)
;;   ktype-unjoined     the checker typed a node the compiler did not      (counted)
;;
;; **Stone 5 -- the language's subtyping, stated ONCE.** A value of a VARIANT is a value of its
;; enum: a function that wants an `Opt` accepts a `Some`. So an argument's type need not EQUAL its
;; parameter's; it must be ASSIGNABLE to it, and `:ck::a-fits` is the whole of that rule, in the
;; language's own terms and nothing more: the same type, or a variant `E.V` of the enum `E` the
;; parameter names, at the same instantiation. It reads the two exported types -- the compiler
;; spells `(:E.V :- [A])` as `<tier>:E.V;A` beside `<tier>:E;A` -- and derives no type.
;;
;; Reported, per program and in total:
;;   boundary-type-conflict   an argument's type is not assignable to its parameter's (a FINDING)
;;   boundary-type-AGREES     the same join, types equal -- counted, the witness that a
;;                            silent run reached its sites and is not merely empty
;;   boundary-type-VARIANT    the same join, a variant passed where its enum is wanted -- counted
;;   carg-unplaced            a CArg whose position is not a List node with that argument
;;   cparam-unplaced          a CParam whose position is not that parameter of a `defn`
;;   arg-unjoined             a placed argument whose head names no `defn` parameter at its index
;;   callee-mismatch          the join reached a `defn` the compiler did not say it called

;; ── the compiler's facts ─────────────────────────────────────────────────────────────
;; `tn` and `ti` are `ty` read in two: the name it spells and the instantiation after it --
;; `penum::user::Opt.Some;str` is `penum::user::Opt.Some` and `;str` (`:ck::ty-name`)
(:wat::core::defrecord :ck::CArg
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64
   idx <- :wat::core::i64  callee <- :wat::core::String  in <- :wat::core::String
   ty <- :wat::core::String  tn <- :wat::core::String  ti <- :wat::core::String])
(:wat::core::defrecord :ck::CParam
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64
   idx <- :wat::core::i64  fn <- :wat::core::String  ty <- :wat::core::String
   tn <- :wat::core::String  ti <- :wat::core::String])

;; ── stone 2: the type each side gave each node, at its position ──────────────────────
;; `seq` is the line's order within its program -- only so a pair of facts at one position can
;; be named once rather than twice. `kind` is "type", "partial" or "untranslatable", read off the
;; translation's own marker.
(:wat::core::defrecord :ck::CType
  [seq <- :wat::core::i64  file <- :wat::core::String  line <- :wat::core::i64
   col <- :wat::core::i64  in <- :wat::core::String  raw <- :wat::core::String
   wat <- :wat::core::String  kind <- :wat::core::String])
(:wat::core::defrecord :ck::KType
  [seq <- :wat::core::i64  file <- :wat::core::String  line <- :wat::core::i64
   col <- :wat::core::i64  ty <- :wat::core::String  wide <- :wat::core::String])
(:wat::core::defrecord :ck::KUnres
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64
   ty <- :wat::core::String])

;; ── wat-grep's facts, one fact base for every file of a program ──────────────────────
;; wat-grep numbers each file's nodes from 1, so a program of several files needs its ids moved
;; apart; `At` is wat-grep's Span with the file it belongs to, which a bare Span does not carry.
(:wat::core::defrecord :ck::At
  [id <- :wat::core::i64  file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])

;; ── what the rules derive: joins, never types ────────────────────────────────────────
(:wat::core::defrecord :ck::Arg
  [name <- :wat::core::String  idx <- :wat::core::i64  callee <- :wat::core::String
   in <- :wat::core::String  ty <- :wat::core::String  tn <- :wat::core::String  ti <- :wat::core::String
   file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])
(:wat::core::defrecord :ck::Param
  [name <- :wat::core::String  idx <- :wat::core::i64  fn <- :wat::core::String
   ty <- :wat::core::String  tn <- :wat::core::String  ti <- :wat::core::String
   file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])
;; this argument's type is assignable to the parameter it feeds (`:ck::a-fits`)
(:wat::core::defrecord :ck::Fits
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64  idx <- :wat::core::i64])

;; a CArg lands on a LIST node starting at its position, whose head is a name and which has an
;; argument at that index. The head's name is wat-grep's, so the defn it names is found by
;; wat-grep's spelling on both sides.
(:wat::rete::defrule :ck::a-arg
  :when [(:ck::CArg (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx)
                    (?callee <- :callee) (?in <- :in) (?t <- :ty) (?tn <- :tn) (?ti <- :ti))
         (:ck::At (?K <- :id) (?f <- :file) (?l <- :line) (?c <- :col))
         (:wat::grep::Node (?K <- :id) (?kk <- :kind))
         (:wat::grep::Node (?h <- :id) (?K <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?F <- :name))
         (:wat::grep::Node (?x <- :id) (?K <- :parent) (?xi <- :index))
         (:wat::rete::where (:wat::rete::core::enum::= ?kk (:wat::grep::NodeKind.List {})))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?xi 1 :undefined -1) ?i))]
  :then [(:ck::Arg :name ?F :idx ?i :callee ?callee :in ?in :ty ?t :tn ?tn :ti ?ti :file ?f :line ?l :col ?c)])

;; a CParam lands on the name of parameter i of a `defn`: index 3i of the vector at index 2,
;; the defn's name at index 1
(:wat::rete::defrule :ck::b-param
  :when [(:ck::CParam (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx) (?fn <- :fn) (?t <- :ty)
                      (?tn <- :tn) (?ti <- :ti))
         (:ck::At (?P <- :id) (?f <- :file) (?l <- :line) (?c <- :col))
         (:wat::grep::Node (?P <- :id) (?V <- :parent) (?pi <- :index))
         (:wat::grep::Node (?V <- :id) (?D <- :parent) (?vi <- :index) (?vk <- :kind))
         (:wat::grep::Node (?hd <- :id) (?D <- :parent) (?hi <- :index))
         (:wat::grep::Named (?hd <- :id) (?hn <- :name))
         (:wat::grep::Node (?nm <- :id) (?D <- :parent) (?ni <- :index))
         (:wat::grep::Named (?nm <- :id) (?F <- :name))
         (:wat::rete::where (:wat::rete::core::enum::= ?vk (:wat::grep::NodeKind.Vector {})))
         (:wat::rete::where (:wat::rete::i64::= ?vi 2))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::string::= ?hn "wat.core/defn"))
         (:wat::rete::where (:wat::rete::i64::= ?ni 1))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::mod ?pi 3 :undefined -1) 0))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::quot ?pi 3 :undefined -1) ?i))]
  :then [(:ck::Param :name ?F :idx ?i :fn ?fn :ty ?t :tn ?tn :ti ?ti :file ?f :line ?l :col ?c)])

;; ── ★ THE LANGUAGE'S RULE, once: may this argument go where that parameter is ───────────
;; the same type -- or `E.V` where `E` is wanted, at the same instantiation: the argument's name
;; is the parameter's followed by `.` and one variant name, and what follows the names is equal.
;; Nothing else: not a sibling variant, not an enum where a variant is wanted, not another
;; instantiation, nothing inside a Vector.
(:wat::rete::defrule :ck::a-fits
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?at <- :ty) (?an <- :tn) (?ai <- :ti)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?pt <- :ty) (?pn <- :tn) (?pi <- :ti))
         (:wat::rete::where
           (:wat::rete::core::or
             (:wat::rete::string::= ?at ?pt)
             (:wat::rete::core::and
               (:wat::rete::string::= ?ai ?pi)
               (:wat::rete::core::and
                 (:wat::rete::string::starts-with? ?an (:wat::rete::string::concat ?pn "."))
                 (:wat::rete::core::not
                   (:wat::rete::string::contains?
                     (:wat::rete::string::subs ?an
                       (:wat::rete::i64::+ (:wat::rete::string::length ?pn) 1 :undefined -1)
                       (:wat::rete::string::length ?an)
                       :undefined ".")
                     "."))))))]
  :then [(:ck::Fits :file ?f :line ?l :col ?c :idx ?i)])

;; ── ★ THE CONSTRAINT: this argument feeds that parameter, so its type must fit ────────────
(:wat::rete::defrule :ck::z-conflict
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee) (?in <- :in) (?at <- :ty)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?pt <- :ty) (?pf <- :file) (?pl <- :line))
         (:wat::rete::not (:ck::Fits (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "boundary-type-conflict"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "arg" :value (:wat::rete::i64::to-string ?i))
             (:wat::grep::Capture :name "arg-type" :value ?at)
             (:wat::grep::Capture :name "param-type" :value ?pt)
             (:wat::grep::Capture :name "param-at" :value (:wat::rete::string::concat ?pf (:wat::rete::string::concat ":" (:wat::rete::i64::to-string ?pl))))))])

;; the witness: the same join, the same sites, types equal
(:wat::rete::defrule :ck::z-agree
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee) (?in <- :in) (?at <- :ty)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?pt <- :ty))
         (:wat::rete::where (:wat::rete::string::= ?at ?pt))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "boundary-type-AGREES"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "arg" :value (:wat::rete::i64::to-string ?i))
             (:wat::grep::Capture :name "type" :value ?at)))])

;; the witness for the rule's second half: a variant where its enum is wanted
(:wat::rete::defrule :ck::z-variant
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee) (?in <- :in) (?at <- :ty)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?pt <- :ty))
         (:ck::Fits (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx))
         (:wat::rete::where (:wat::rete::string::not= ?at ?pt))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "boundary-type-VARIANT"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "arg" :value (:wat::rete::i64::to-string ?i))
             (:wat::grep::Capture :name "arg-type" :value ?at)
             (:wat::grep::Capture :name "param-type" :value ?pt)))])

;; ── the join is exact, or it says where it is not ────────────────────────────────────
(:wat::rete::defrule :ck::y-carg-unplaced
  :when [(:ck::CArg (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx) (?callee <- :callee)
                    (?in <- :in))
         (:wat::rete::not (:ck::Arg (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "carg-unplaced"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "arg" :value (:wat::rete::i64::to-string ?i))))])

(:wat::rete::defrule :ck::y-cparam-unplaced
  :when [(:ck::CParam (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx) (?fn <- :fn))
         (:wat::rete::not (:ck::Param (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "cparam-unplaced"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "fn" :value ?fn)
             (:wat::grep::Capture :name "param" :value (:wat::rete::i64::to-string ?i))))])

(:wat::rete::defrule :ck::y-arg-unjoined
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee) (?in <- :in)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:wat::rete::not (:ck::Param (?F <- :name) (?i <- :idx)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "arg-unjoined"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "head" :value ?F)
             (:wat::grep::Capture :name "arg" :value (:wat::rete::i64::to-string ?i))))])

(:wat::rete::defrule :ck::y-callee-mismatch
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?fn <- :fn))
         (:wat::rete::where (:wat::rete::string::not= ?callee ?fn))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "callee-mismatch"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?callee)
             (:wat::grep::Capture :name "defn" :value ?fn)))])

;; ── stone 2 ★ THE CONSTRAINT: the compiler's type for a node is the language's ─────────
(:wat::rete::defrule :ck::t-agree
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat) (?k <- :kind))
         (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :ty))
         (:wat::rete::where (:wat::rete::string::= ?k "type"))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-AGREES"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "type" :value ?w)))])

(:wat::rete::defrule :ck::t-refined
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat) (?k <- :kind))
         (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?kt <- :ty) (?w <- :wide))
         (:wat::rete::where (:wat::rete::string::= ?k "type"))
         (:wat::rete::where (:wat::rete::string::not= ?kt ?w))
         (:wat::rete::not (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :ty)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-refined"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "compiler" :value ?w)
             (:wat::grep::Capture :name "checker" :value ?kt)))])

(:wat::rete::defrule :ck::t-conflict
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?in <- :in) (?r <- :raw)
                     (?w <- :wat) (?k <- :kind))
         (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?kt <- :ty))
         (:wat::rete::where (:wat::rete::string::= ?k "type"))
         (:wat::rete::not (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :ty)))
         (:wat::rete::not (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wide)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-conflict"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "compiler" :value ?w)
             (:wat::grep::Capture :name "checker" :value ?kt)
             (:wat::grep::Capture :name "raw" :value ?r)))])

(:wat::rete::defrule :ck::t-partial
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat) (?k <- :kind))
         (:wat::rete::where (:wat::rete::string::= ?k "partial"))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-partial"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "compiler" :value ?w)))])

(:wat::rete::defrule :ck::t-untranslatable
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat) (?k <- :kind))
         (:wat::rete::where (:wat::rete::string::= ?k "untranslatable"))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-untranslatable"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "compiler" :value ?w)))])

(:wat::rete::defrule :ck::t-unresolved
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat))
         (:ck::KUnres (?f <- :file) (?l <- :line) (?c <- :col) (?kt <- :ty))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "type-unresolved"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "compiler" :value ?w)
             (:wat::grep::Capture :name "checker" :value ?kt)))])

;; STOP-3: one position, two checker types -- both named, neither chosen
(:wat::rete::defrule :ck::t-checker-multi
  :when [(:ck::KType (?s1 <- :seq) (?f <- :file) (?l <- :line) (?c <- :col) (?a <- :ty))
         (:ck::KType (?s2 <- :seq) (?f <- :file) (?l <- :line) (?c <- :col) (?b <- :ty))
         (:wat::rete::where (:wat::rete::i64::< ?s1 ?s2))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "checker-multi"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "one" :value ?a)
             (:wat::grep::Capture :name "two" :value ?b)))])

(:wat::rete::defrule :ck::t-compiler-multi
  :when [(:ck::CType (?s1 <- :seq) (?f <- :file) (?l <- :line) (?c <- :col) (?a <- :wat))
         (:ck::CType (?s2 <- :seq) (?f <- :file) (?l <- :line) (?c <- :col) (?b <- :wat))
         (:wat::rete::where (:wat::rete::i64::< ?s1 ?s2))
         (:wat::rete::where (:wat::rete::string::not= ?a ?b))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "compiler-multi"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "one" :value ?a)
             (:wat::grep::Capture :name "two" :value ?b)))])

;; one side only: counted per fact
(:wat::rete::defrule :ck::t-ctype-unjoined
  :when [(:ck::CType (?f <- :file) (?l <- :line) (?c <- :col) (?w <- :wat) (?in <- :in))
         (:wat::rete::not (:ck::KType (?f <- :file) (?l <- :line) (?c <- :col)))
         (:wat::rete::not (:ck::KUnres (?f <- :file) (?l <- :line) (?c <- :col)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "ctype-unjoined"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "in" :value ?in)
             (:wat::grep::Capture :name "compiler" :value ?w)))])

(:wat::rete::defrule :ck::t-ktype-unjoined
  :when [(:ck::KType (?f <- :file) (?l <- :line) (?c <- :col) (?kt <- :ty))
         (:wat::rete::not (:ck::CType (?f <- :file) (?l <- :line) (?c <- :col)))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?l :end-col ?c
           :rule "ktype-unjoined"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "checker" :value ?kt)))])

;; ── reading the compiler's lines ─────────────────────────────────────────────────────
(:wat::core::defn :ck::int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::Option/expect (:wat::string::to-i64 s) "rules: not an integer in a fact line"))

(:wat::core::defn :ck::word [ws <- (:wat::core::Vector :- [:wat::core::String]) i <- :wat::core::i64]
    -> :wat::core::String
  (:wat::core::nth ws i))

(:wat::core::defrecord :ck::Tally
  [progs <- :wat::core::i64  cargs <- :wat::core::i64  cparams <- :wat::core::i64
   agree <- :wat::core::i64  variant <- :wat::core::i64  conflict <- :wat::core::i64  unplaced <- :wat::core::i64
   unjoined <- :wat::core::i64  mismatch <- :wat::core::i64  lists <- :wat::core::i64
   ;; stone 2
   ctypes <- :wat::core::i64  ktypes <- :wat::core::i64  kunres <- :wat::core::i64
   tagree <- :wat::core::i64  trefined <- :wat::core::i64  tconflict <- :wat::core::i64
   tpartial <- :wat::core::i64  tuntrans <- :wat::core::i64  tunres <- :wat::core::i64
   kmulti <- :wat::core::i64  cmulti <- :wat::core::i64
   conly <- :wat::core::i64  konly <- :wat::core::i64])

(:wat::core::defn :ck::zero [] -> :ck::Tally
  (:ck::Tally :progs 0 :cargs 0 :cparams 0 :agree 0 :variant 0 :conflict 0 :unplaced 0 :unjoined 0
              :mismatch 0 :lists 0
              :ctypes 0 :ktypes 0 :kunres 0 :tagree 0 :trefined 0 :tconflict 0 :tpartial 0
              :tuntrans 0 :tunres 0 :kmulti 0 :cmulti 0 :conly 0 :konly 0))

;; one program's records: every file's wat-grep facts, ids moved apart, then the compiler's
(:wat::core::defn :ck::grep-file
  [acc <- (:wat::core::PersistentVector :- [:wat::core::Record])
   path <- :wat::core::String
   off <- :wat::core::i64]
  -> (:wat::core::PersistentVector :- [:wat::core::Record])
  (:wat::core::let
    [facts (:wat::grep::facts-of path (:wat::io::read-file path))
     bad (:wat::grep::Facts/unreadable facts)
     acc1 (:wat::core::foldl
            (:wat::core::fn [a <- (:wat::core::PersistentVector :- [:wat::core::Record])
                             n <- :wat::grep::Node]
              -> (:wat::core::PersistentVector :- [:wat::core::Record])
              (:wat::vector::conj a
                (:wat::grep::Node :id (:wat::i64::+ (:wat::grep::Node/id n) off)
                                  :parent (:wat::i64::+ (:wat::grep::Node/parent n) off)
                                  :index (:wat::grep::Node/index n)
                                  :kind (:wat::grep::Node/kind n))))
            acc (:wat::grep::Facts/nodes facts))
     acc2 (:wat::core::foldl
            (:wat::core::fn [a <- (:wat::core::PersistentVector :- [:wat::core::Record])
                             nm <- :wat::grep::Named]
              -> (:wat::core::PersistentVector :- [:wat::core::Record])
              (:wat::vector::conj a
                (:wat::grep::Named :id (:wat::i64::+ (:wat::grep::Named/id nm) off)
                                   :name (:wat::grep::Named/name nm))))
            acc1 (:wat::grep::Facts/named facts))
     acc3 (:wat::core::foldl
            (:wat::core::fn [a <- (:wat::core::PersistentVector :- [:wat::core::Record])
                             sp <- :wat::grep::Span]
              -> (:wat::core::PersistentVector :- [:wat::core::Record])
              (:wat::vector::conj a
                (:ck::At :id (:wat::i64::+ (:wat::grep::Span/id sp) off) :file path
                         :line (:wat::grep::Span/line sp) :col (:wat::grep::Span/col sp))))
            acc2 (:wat::grep::Facts/spans facts))]
    (:wat::core::if (:wat::core::empty? bad) acc3
      (:wat::kernel::assertion-failed!
        :message (:wat::string::concat "rules: wat-grep cannot read " path)))))

(:wat::core::defrecord :ck::Prog
  [recs <- (:wat::core::PersistentVector :- [:wat::core::Record])
   files <- :wat::core::i64  cargs <- :wat::core::i64  cparams <- :wat::core::i64
   ctypes <- :wat::core::i64  ktypes <- :wat::core::i64  kunres <- :wat::core::i64])

(:wat::core::defn :ck::bump-prog [p <- :ck::Prog field <- :wat::core::keyword] -> :ck::Prog
  (:wat::core::cond
    ((:wat::core::= field :cargs) (:wat::core::assoc p :cargs (:wat::i64::+ (:ck::Prog/cargs p) 1)))
    ((:wat::core::= field :cparams) (:wat::core::assoc p :cparams (:wat::i64::+ (:ck::Prog/cparams p) 1)))
    ((:wat::core::= field :ctypes) (:wat::core::assoc p :ctypes (:wat::i64::+ (:ck::Prog/ctypes p) 1)))
    ((:wat::core::= field :ktypes) (:wat::core::assoc p :ktypes (:wat::i64::+ (:ck::Prog/ktypes p) 1)))
    (:else (:wat::core::assoc p :kunres (:wat::i64::+ (:ck::Prog/kunres p) 1)))))

(:wat::core::defn :ck::add-rec [p <- :ck::Prog r <- :wat::core::Record field <- :wat::core::keyword]
    -> :ck::Prog
  (:ck::bump-prog (:wat::core::assoc p :recs (:wat::vector::conj (:ck::Prog/recs p) r)) field))

;; words i.. of a line, joined again by the spaces they were split on -- a wat type holds spaces
(:wat::core::defn :ck::rest [ws <- (:wat::core::Vector :- [:wat::core::String]) i <- :wat::core::i64]
    -> :wat::core::String
  (:wat::core::cond
    ((:wat::core::>= i (:wat::core::length ws)) "")
    ((:wat::core::= i (:wat::i64::- (:wat::core::length ws) 1)) (:wat::core::nth ws i))
    (:else (:wat::string::concat (:wat::core::nth ws i) " " (:ck::rest ws (:wat::i64::+ i 1))))))

;; a compiler type read in two, lexically -- the name it spells runs to its first `;`, and the
;; instantiation is the rest: `henum::user::Box;penum::user::Opt;str` is `henum::user::Box` and
;; `;penum::user::Opt;str`. Reading, not typing: nothing here knows what a name means.
(:wat::core::defn :ck::ty-name [t <- :wat::core::String] -> :wat::core::String
  (:wat::core::nth (:wat::string::split t ";") 0))

(:wat::core::defn :ck::ty-inst [t <- :wat::core::String] -> :wat::core::String
  (:wat::string::subs t (:wat::string::length (:ck::ty-name t)) (:wat::string::length t)))

;; the translation's own marker, read back, anywhere in the type -- a Vector of functions is
;; as partial as a function: "partial:" and "untranslatable:" are not wat types
(:wat::core::defn :ck::kind-of [w <- :wat::core::String] -> :wat::core::String
  (:wat::core::cond
    ((:wat::string::contains? w "untranslatable:") "untranslatable")
    ((:wat::string::contains? w "partial:") "partial")
    (:else "type")))

(:wat::core::defn :ck::seq-of [p <- :ck::Prog] -> :wat::core::i64
  (:wat::i64::+ (:ck::Prog/ctypes p) (:ck::Prog/ktypes p)))

(:wat::core::defn :ck::add-line [p <- :ck::Prog s <- :wat::core::String] -> :ck::Prog
  (:wat::core::let [ws (:wat::string::split s " ")
                    tag (:ck::word ws 0)
                    ts (:wat::string::split s "\t")
                    ttag (:ck::word ts 0)]
    (:wat::core::cond
      ((:wat::core::= tag "FILE")
        (:wat::core::assoc
          (:wat::core::assoc p :recs (:ck::grep-file (:ck::Prog/recs p) (:ck::word ws 1)
                                       (:wat::i64::* (:wat::i64::+ (:ck::Prog/files p) 1) 100000000)))
          :files (:wat::i64::+ (:ck::Prog/files p) 1)))
      ((:wat::core::= tag "CArg")
        (:ck::add-rec p (:ck::CArg :file (:ck::word ws 1) :line (:ck::int (:ck::word ws 2))
                                   :col (:ck::int (:ck::word ws 3)) :idx (:ck::int (:ck::word ws 4))
                                   :callee (:ck::word ws 5) :in (:ck::word ws 6)
                                   :ty (:ck::word ws 7) :tn (:ck::ty-name (:ck::word ws 7))
                                   :ti (:ck::ty-inst (:ck::word ws 7)))
          :cargs))
      ((:wat::core::= tag "CParam")
        (:ck::add-rec p (:ck::CParam :file (:ck::word ws 1) :line (:ck::int (:ck::word ws 2))
                                     :col (:ck::int (:ck::word ws 3)) :idx (:ck::int (:ck::word ws 4))
                                     :fn (:ck::word ws 5) :ty (:ck::word ws 6)
                                     :tn (:ck::ty-name (:ck::word ws 6)) :ti (:ck::ty-inst (:ck::word ws 6)))
          :cparams))
      ((:wat::core::= tag "CType")
        (:wat::core::let [w (:ck::rest ws 6)]
          (:ck::add-rec p (:ck::CType :seq (:ck::seq-of p) :file (:ck::word ws 1)
                                      :line (:ck::int (:ck::word ws 2)) :col (:ck::int (:ck::word ws 3))
                                      :in (:ck::word ws 4) :raw (:ck::word ws 5)
                                      :wat w :kind (:ck::kind-of w))
            :ctypes)))
      ((:wat::core::= ttag "KType")
        (:ck::add-rec p (:ck::KType :seq (:ck::seq-of p) :file (:ck::word ts 1)
                                    :line (:ck::int (:ck::word ts 2)) :col (:ck::int (:ck::word ts 3))
                                    :ty (:ck::word ts 4) :wide (:ck::word ts 5))
          :ktypes))
      ((:wat::core::= ttag "KUnres")
        (:ck::add-rec p (:ck::KUnres :file (:ck::word ts 1)
                                     :line (:ck::int (:ck::word ts 2)) :col (:ck::int (:ck::word ts 3))
                                     :ty (:ck::word ts 4))
          :kunres))
      (:else p))))

(:wat::core::defn :ck::empty-prog [] -> :ck::Prog
  (:ck::Prog :recs (:wat::core::PersistentVector :- [:wat::core::Record]) :files 0 :cargs 0 :cparams 0
             :ctypes 0 :ktypes 0 :kunres 0))

;; ── reporting ────────────────────────────────────────────────────────────────────────
(:wat::core::defn :ck::cap [cs <- (:wat::core::PersistentVector :- [:wat::grep::Capture])] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [acc <- :wat::core::String c <- :wat::grep::Capture] -> :wat::core::String
      (:wat::string::concat acc "  " (:wat::grep::Capture/name c) "=" (:wat::grep::Capture/value c)))
    "" cs))

(:wat::core::defn :ck::bump [t <- :ck::Tally rule <- :wat::core::String] -> :ck::Tally
  (:wat::core::cond
    ((:wat::core::= rule "boundary-type-AGREES") (:wat::core::assoc t :agree (:wat::i64::+ (:ck::Tally/agree t) 1)))
    ((:wat::core::= rule "boundary-type-VARIANT") (:wat::core::assoc t :variant (:wat::i64::+ (:ck::Tally/variant t) 1)))
    ((:wat::core::= rule "boundary-type-conflict") (:wat::core::assoc t :conflict (:wat::i64::+ (:ck::Tally/conflict t) 1)))
    ((:wat::core::= rule "arg-unjoined") (:wat::core::assoc t :unjoined (:wat::i64::+ (:ck::Tally/unjoined t) 1)))
    ((:wat::core::= rule "callee-mismatch") (:wat::core::assoc t :mismatch (:wat::i64::+ (:ck::Tally/mismatch t) 1)))
    ((:wat::core::= rule "type-AGREES") (:wat::core::assoc t :tagree (:wat::i64::+ (:ck::Tally/tagree t) 1)))
    ((:wat::core::= rule "type-refined") (:wat::core::assoc t :trefined (:wat::i64::+ (:ck::Tally/trefined t) 1)))
    ((:wat::core::= rule "type-conflict") (:wat::core::assoc t :tconflict (:wat::i64::+ (:ck::Tally/tconflict t) 1)))
    ((:wat::core::= rule "type-partial") (:wat::core::assoc t :tpartial (:wat::i64::+ (:ck::Tally/tpartial t) 1)))
    ((:wat::core::= rule "type-untranslatable") (:wat::core::assoc t :tuntrans (:wat::i64::+ (:ck::Tally/tuntrans t) 1)))
    ((:wat::core::= rule "type-unresolved") (:wat::core::assoc t :tunres (:wat::i64::+ (:ck::Tally/tunres t) 1)))
    ((:wat::core::= rule "checker-multi") (:wat::core::assoc t :kmulti (:wat::i64::+ (:ck::Tally/kmulti t) 1)))
    ((:wat::core::= rule "compiler-multi") (:wat::core::assoc t :cmulti (:wat::i64::+ (:ck::Tally/cmulti t) 1)))
    ((:wat::core::= rule "ctype-unjoined") (:wat::core::assoc t :conly (:wat::i64::+ (:ck::Tally/conly t) 1)))
    ((:wat::core::= rule "ktype-unjoined") (:wat::core::assoc t :konly (:wat::i64::+ (:ck::Tally/konly t) 1)))
    (:else (:wat::core::assoc t :unplaced (:wat::i64::+ (:ck::Tally/unplaced t) 1)))))

(:wat::core::defn :ck::add [a <- :ck::Tally b <- :ck::Tally] -> :ck::Tally
  (:ck::Tally :progs (:wat::i64::+ (:ck::Tally/progs a) (:ck::Tally/progs b))
    :cargs (:wat::i64::+ (:ck::Tally/cargs a) (:ck::Tally/cargs b))
    :cparams (:wat::i64::+ (:ck::Tally/cparams a) (:ck::Tally/cparams b))
    :agree (:wat::i64::+ (:ck::Tally/agree a) (:ck::Tally/agree b))
    :variant (:wat::i64::+ (:ck::Tally/variant a) (:ck::Tally/variant b))
    :conflict (:wat::i64::+ (:ck::Tally/conflict a) (:ck::Tally/conflict b))
    :unplaced (:wat::i64::+ (:ck::Tally/unplaced a) (:ck::Tally/unplaced b))
    :unjoined (:wat::i64::+ (:ck::Tally/unjoined a) (:ck::Tally/unjoined b))
    :mismatch (:wat::i64::+ (:ck::Tally/mismatch a) (:ck::Tally/mismatch b))
    :lists (:wat::i64::+ (:ck::Tally/lists a) (:ck::Tally/lists b))
    :ctypes (:wat::i64::+ (:ck::Tally/ctypes a) (:ck::Tally/ctypes b))
    :ktypes (:wat::i64::+ (:ck::Tally/ktypes a) (:ck::Tally/ktypes b))
    :kunres (:wat::i64::+ (:ck::Tally/kunres a) (:ck::Tally/kunres b))
    :tagree (:wat::i64::+ (:ck::Tally/tagree a) (:ck::Tally/tagree b))
    :trefined (:wat::i64::+ (:ck::Tally/trefined a) (:ck::Tally/trefined b))
    :tconflict (:wat::i64::+ (:ck::Tally/tconflict a) (:ck::Tally/tconflict b))
    :tpartial (:wat::i64::+ (:ck::Tally/tpartial a) (:ck::Tally/tpartial b))
    :tuntrans (:wat::i64::+ (:ck::Tally/tuntrans a) (:ck::Tally/tuntrans b))
    :tunres (:wat::i64::+ (:ck::Tally/tunres a) (:ck::Tally/tunres b))
    :kmulti (:wat::i64::+ (:ck::Tally/kmulti a) (:ck::Tally/kmulti b))
    :cmulti (:wat::i64::+ (:ck::Tally/cmulti a) (:ck::Tally/cmulti b))
    :conly (:wat::i64::+ (:ck::Tally/conly a) (:ck::Tally/conly b))
    :konly (:wat::i64::+ (:ck::Tally/konly a) (:ck::Tally/konly b))))

(:wat::core::defn :ck::show [label <- :wat::core::String t <- :ck::Tally] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label
      "  CArg " (:wat::i64::to-string (:ck::Tally/cargs t))
      "  CParam " (:wat::i64::to-string (:ck::Tally/cparams t))
      "  pairs " (:wat::i64::to-string (:wat::i64::+ (:ck::Tally/agree t)
                                          (:wat::i64::+ (:ck::Tally/variant t) (:ck::Tally/conflict t))))
      "  agree " (:wat::i64::to-string (:ck::Tally/agree t))
      "  variant " (:wat::i64::to-string (:ck::Tally/variant t))
      "  CONFLICT " (:wat::i64::to-string (:ck::Tally/conflict t))
      "  unplaced " (:wat::i64::to-string (:ck::Tally/unplaced t))
      "  unjoined " (:wat::i64::to-string (:ck::Tally/unjoined t))
      "  mismatch " (:wat::i64::to-string (:ck::Tally/mismatch t)))))

;; stone 2's counts. `joined` is every compiler type that met a checker type at its node:
;; agree + refined + conflict (a node with two checker types can be counted once per type).
(:wat::core::defn :ck::show-types [label <- :wat::core::String t <- :ck::Tally] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label
      "  CType " (:wat::i64::to-string (:ck::Tally/ctypes t))
      "  KType " (:wat::i64::to-string (:ck::Tally/ktypes t))
      "  KUnres " (:wat::i64::to-string (:ck::Tally/kunres t))
      "  joined " (:wat::i64::to-string (:wat::i64::+ (:ck::Tally/tagree t)
                                           (:wat::i64::+ (:ck::Tally/trefined t) (:ck::Tally/tconflict t))))
      "  agree " (:wat::i64::to-string (:ck::Tally/tagree t))
      "  refined " (:wat::i64::to-string (:ck::Tally/trefined t))
      "  TYPE-CONFLICT " (:wat::i64::to-string (:ck::Tally/tconflict t))
      "  partial " (:wat::i64::to-string (:ck::Tally/tpartial t))
      "  untranslatable " (:wat::i64::to-string (:ck::Tally/tuntrans t))
      "  unresolved " (:wat::i64::to-string (:ck::Tally/tunres t))
      "  checker-multi " (:wat::i64::to-string (:ck::Tally/kmulti t))
      "  compiler-multi " (:wat::i64::to-string (:ck::Tally/cmulti t))
      "  compiler-only " (:wat::i64::to-string (:ck::Tally/conly t))
      "  checker-only " (:wat::i64::to-string (:ck::Tally/konly t)))))

;; counted, and printed only to the detail stream: the lines that are witnesses, not findings
(:wat::core::defn :ck::quiet? [rule <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::core::= rule "boundary-type-AGREES")
    (:wat::core::or (:wat::core::= rule "boundary-type-VARIANT")
    (:wat::core::or (:wat::core::= rule "type-AGREES")
      ;; `type-refined` is a finding since stone 5 -- printed, not quiet
        (:wat::core::or (:wat::core::= rule "type-partial")
          (:wat::core::or (:wat::core::= rule "ctype-unjoined")
                          (:wat::core::= rule "ktype-unjoined")))))))

(:wat::rete::defquery :ck::q-match
  :params []
  :when [(?fact <- :wat::grep::Match)])

;; one program through the compiled network: every finding printed, every agreement counted
(:wat::core::defn :ck::run-prog [overlay <- :wat::rete::Overlay name <- :wat::core::String
                                 p <- :ck::Prog] -> :ck::Tally
  (:wat::core::let
    [fired (overlay (:ck::Prog/recs p))
     t (:wat::core::foldl
         (:wat::core::fn [t <- :ck::Tally b <- :wat::core::PersistentMap] -> :ck::Tally
           (:wat::core::let [m (:wat::core::Option/expect (:wat::map::get b "?fact") "rules: no ?fact")
                             rule (:wat::grep::Match/rule m)]
             (:wat::core::do
               (:wat::core::if (:wat::core::= rule "boundary-type-AGREES") nil
                 (:wat::kernel::println
                   (:wat::string::concat (:wat::core::if (:ck::quiet? rule) "  ~" "  ") rule "  "
                     (:wat::grep::Match/file m) ":"
                     (:wat::i64::to-string (:wat::grep::Match/line m)) ":"
                     (:wat::i64::to-string (:wat::grep::Match/col m))
                     (:ck::cap (:wat::grep::Match/captures m)))))
               (:ck::bump t rule))))
         (:wat::core::assoc
           (:wat::core::assoc
             (:wat::core::assoc
               (:wat::core::assoc
                 (:wat::core::assoc (:wat::core::assoc (:ck::zero) :progs 1) :cargs (:ck::Prog/cargs p))
                 :cparams (:ck::Prog/cparams p))
               :ctypes (:ck::Prog/ctypes p))
             :ktypes (:ck::Prog/ktypes p))
           :kunres (:ck::Prog/kunres p))
         (:wat::rete::query fired (:ck::q-match)))]
    (:wat::core::do (:ck::show (:wat::string::concat "rules: " name) t)
                    (:ck::show-types (:wat::string::concat "types: " name) t)
                    t)))

(:wat::core::defn :ck::read-line [] -> :wat::core::String
  (:wat::core::match (:wat::kernel::readln)
    [:wat::kernel::ReadlnOutcome.Datum {:v d} d]
    [:wat::kernel::ReadlnOutcome.Eof {} ""]
    [:wat::kernel::ReadlnOutcome.Stopped {} ""]))

(:wat::core::defn :ck::loop [overlay <- :wat::rete::Overlay name <- :wat::core::String
                             p <- :ck::Prog total <- :ck::Tally] -> :ck::Tally
  (:wat::core::let [s (:ck::read-line)]
    (:wat::core::cond
      ((:wat::core::= s "") total)
      ((:wat::string::starts-with? s "PROG ")
        (:ck::loop overlay (:wat::string::subs s 5 (:wat::string::length s)) (:ck::empty-prog) total))
      ((:wat::core::= s "END")
        (:ck::loop overlay "" (:ck::empty-prog) (:ck::add total (:ck::run-prog overlay name p))))
      (:else (:ck::loop overlay name (:ck::add-line p s) total)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [total (:wat::rete::with-overlay (:wat::rete::collect-rules :ck)
             (:wat::core::PersistentVector :- [:wat::rete::Query] (:ck::q-match))
             (:wat::core::fn [overlay <- :wat::rete::Overlay] -> :ck::Tally
               (:ck::loop overlay "" (:ck::empty-prog) (:ck::zero))))]
    (:wat::core::do
      (:ck::show (:wat::string::concat "rules: TOTAL over " (:wat::i64::to-string (:ck::Tally/progs total))
                   " programs") total)
      (:ck::show-types (:wat::string::concat "types: TOTAL over " (:wat::i64::to-string (:ck::Tally/progs total))
                         " programs") total)
      nil)))
