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
;; Reported, per program and in total:
;;   boundary-type-conflict   an argument's type differs from its parameter's      (a FINDING)
;;   boundary-type-AGREES     the same join, types equal -- counted, the witness that a
;;                            silent run reached its sites and is not merely empty
;;   carg-unplaced            a CArg whose position is not a List node with that argument
;;   cparam-unplaced          a CParam whose position is not that parameter of a `defn`
;;   arg-unjoined             a placed argument whose head names no `defn` parameter at its index
;;   callee-mismatch          the join reached a `defn` the compiler did not say it called

;; ── the compiler's facts ─────────────────────────────────────────────────────────────
(:wat::core::defrecord :ck::CArg
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64
   idx <- :wat::core::i64  callee <- :wat::core::String  in <- :wat::core::String
   ty <- :wat::core::String])
(:wat::core::defrecord :ck::CParam
  [file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64
   idx <- :wat::core::i64  fn <- :wat::core::String  ty <- :wat::core::String])

;; ── wat-grep's facts, one fact base for every file of a program ──────────────────────
;; wat-grep numbers each file's nodes from 1, so a program of several files needs its ids moved
;; apart; `At` is wat-grep's Span with the file it belongs to, which a bare Span does not carry.
(:wat::core::defrecord :ck::At
  [id <- :wat::core::i64  file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])

;; ── what the rules derive: joins, never types ────────────────────────────────────────
(:wat::core::defrecord :ck::Arg
  [name <- :wat::core::String  idx <- :wat::core::i64  callee <- :wat::core::String
   in <- :wat::core::String  ty <- :wat::core::String
   file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])
(:wat::core::defrecord :ck::Param
  [name <- :wat::core::String  idx <- :wat::core::i64  fn <- :wat::core::String
   ty <- :wat::core::String
   file <- :wat::core::String  line <- :wat::core::i64  col <- :wat::core::i64])

;; a CArg lands on a LIST node starting at its position, whose head is a name and which has an
;; argument at that index. The head's name is wat-grep's, so the defn it names is found by
;; wat-grep's spelling on both sides.
(:wat::rete::defrule :ck::a-arg
  :when [(:ck::CArg (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx)
                    (?callee <- :callee) (?in <- :in) (?t <- :ty))
         (:ck::At (?K <- :id) (?f <- :file) (?l <- :line) (?c <- :col))
         (:wat::grep::Node (?K <- :id) (?kk <- :kind))
         (:wat::grep::Node (?h <- :id) (?K <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?F <- :name))
         (:wat::grep::Node (?x <- :id) (?K <- :parent) (?xi <- :index))
         (:wat::rete::where (:wat::rete::core::enum::= ?kk (:wat::grep::NodeKind.List {})))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?xi 1 :undefined -1) ?i))]
  :then [(:ck::Arg :name ?F :idx ?i :callee ?callee :in ?in :ty ?t :file ?f :line ?l :col ?c)])

;; a CParam lands on the name of parameter i of a `defn`: index 3i of the vector at index 2,
;; the defn's name at index 1
(:wat::rete::defrule :ck::b-param
  :when [(:ck::CParam (?f <- :file) (?l <- :line) (?c <- :col) (?i <- :idx) (?fn <- :fn) (?t <- :ty))
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
  :then [(:ck::Param :name ?F :idx ?i :fn ?fn :ty ?t :file ?f :line ?l :col ?c)])

;; ── ★ THE CONSTRAINT: this argument feeds that parameter, so their types are one type ─
(:wat::rete::defrule :ck::z-conflict
  :when [(:ck::Arg (?F <- :name) (?i <- :idx) (?callee <- :callee) (?in <- :in) (?at <- :ty)
                   (?f <- :file) (?l <- :line) (?c <- :col))
         (:ck::Param (?F <- :name) (?i <- :idx) (?pt <- :ty) (?pf <- :file) (?pl <- :line))
         (:wat::rete::where (:wat::rete::string::not= ?at ?pt))]
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

;; ── reading the compiler's lines ─────────────────────────────────────────────────────
(:wat::core::defn :ck::int [s <- :wat::core::String] -> :wat::core::i64
  (:wat::core::Option/expect (:wat::string::to-i64 s) "rules: not an integer in a fact line"))

(:wat::core::defn :ck::word [ws <- (:wat::core::Vector :- [:wat::core::String]) i <- :wat::core::i64]
    -> :wat::core::String
  (:wat::core::nth ws i))

(:wat::core::defrecord :ck::Tally
  [progs <- :wat::core::i64  cargs <- :wat::core::i64  cparams <- :wat::core::i64
   agree <- :wat::core::i64  conflict <- :wat::core::i64  unplaced <- :wat::core::i64
   unjoined <- :wat::core::i64  mismatch <- :wat::core::i64  lists <- :wat::core::i64])

(:wat::core::defn :ck::zero [] -> :ck::Tally
  (:ck::Tally :progs 0 :cargs 0 :cparams 0 :agree 0 :conflict 0 :unplaced 0 :unjoined 0
              :mismatch 0 :lists 0))

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
   files <- :wat::core::i64  cargs <- :wat::core::i64  cparams <- :wat::core::i64])

(:wat::core::defn :ck::add-line [p <- :ck::Prog s <- :wat::core::String] -> :ck::Prog
  (:wat::core::let [ws (:wat::string::split s " ")
                    tag (:ck::word ws 0)]
    (:wat::core::cond
      ((:wat::core::= tag "FILE")
        (:ck::Prog :recs (:ck::grep-file (:ck::Prog/recs p) (:ck::word ws 1)
                           (:wat::i64::* (:wat::i64::+ (:ck::Prog/files p) 1) 100000000))
                   :files (:wat::i64::+ (:ck::Prog/files p) 1)
                   :cargs (:ck::Prog/cargs p) :cparams (:ck::Prog/cparams p)))
      ((:wat::core::= tag "CArg")
        (:ck::Prog :recs (:wat::vector::conj (:ck::Prog/recs p)
                           (:ck::CArg :file (:ck::word ws 1) :line (:ck::int (:ck::word ws 2))
                                      :col (:ck::int (:ck::word ws 3)) :idx (:ck::int (:ck::word ws 4))
                                      :callee (:ck::word ws 5) :in (:ck::word ws 6)
                                      :ty (:ck::word ws 7)))
                   :files (:ck::Prog/files p)
                   :cargs (:wat::i64::+ (:ck::Prog/cargs p) 1) :cparams (:ck::Prog/cparams p)))
      ((:wat::core::= tag "CParam")
        (:ck::Prog :recs (:wat::vector::conj (:ck::Prog/recs p)
                           (:ck::CParam :file (:ck::word ws 1) :line (:ck::int (:ck::word ws 2))
                                        :col (:ck::int (:ck::word ws 3)) :idx (:ck::int (:ck::word ws 4))
                                        :fn (:ck::word ws 5) :ty (:ck::word ws 6)))
                   :files (:ck::Prog/files p)
                   :cargs (:ck::Prog/cargs p) :cparams (:wat::i64::+ (:ck::Prog/cparams p) 1)))
      (:else p))))

(:wat::core::defn :ck::empty-prog [] -> :ck::Prog
  (:ck::Prog :recs (:wat::core::PersistentVector :- [:wat::core::Record]) :files 0 :cargs 0 :cparams 0))

;; ── reporting ────────────────────────────────────────────────────────────────────────
(:wat::core::defn :ck::cap [cs <- (:wat::core::PersistentVector :- [:wat::grep::Capture])] -> :wat::core::String
  (:wat::core::foldl
    (:wat::core::fn [acc <- :wat::core::String c <- :wat::grep::Capture] -> :wat::core::String
      (:wat::string::concat acc "  " (:wat::grep::Capture/name c) "=" (:wat::grep::Capture/value c)))
    "" cs))

(:wat::core::defn :ck::bump [t <- :ck::Tally rule <- :wat::core::String] -> :ck::Tally
  (:wat::core::cond
    ((:wat::core::= rule "boundary-type-AGREES") (:wat::core::assoc t :agree (:wat::i64::+ (:ck::Tally/agree t) 1)))
    ((:wat::core::= rule "boundary-type-conflict") (:wat::core::assoc t :conflict (:wat::i64::+ (:ck::Tally/conflict t) 1)))
    ((:wat::core::= rule "arg-unjoined") (:wat::core::assoc t :unjoined (:wat::i64::+ (:ck::Tally/unjoined t) 1)))
    ((:wat::core::= rule "callee-mismatch") (:wat::core::assoc t :mismatch (:wat::i64::+ (:ck::Tally/mismatch t) 1)))
    (:else (:wat::core::assoc t :unplaced (:wat::i64::+ (:ck::Tally/unplaced t) 1)))))

(:wat::core::defn :ck::add [a <- :ck::Tally b <- :ck::Tally] -> :ck::Tally
  (:ck::Tally :progs (:wat::i64::+ (:ck::Tally/progs a) (:ck::Tally/progs b))
              :cargs (:wat::i64::+ (:ck::Tally/cargs a) (:ck::Tally/cargs b))
              :cparams (:wat::i64::+ (:ck::Tally/cparams a) (:ck::Tally/cparams b))
              :agree (:wat::i64::+ (:ck::Tally/agree a) (:ck::Tally/agree b))
              :conflict (:wat::i64::+ (:ck::Tally/conflict a) (:ck::Tally/conflict b))
              :unplaced (:wat::i64::+ (:ck::Tally/unplaced a) (:ck::Tally/unplaced b))
              :unjoined (:wat::i64::+ (:ck::Tally/unjoined a) (:ck::Tally/unjoined b))
              :mismatch (:wat::i64::+ (:ck::Tally/mismatch a) (:ck::Tally/mismatch b))
              :lists (:wat::i64::+ (:ck::Tally/lists a) (:ck::Tally/lists b))))

(:wat::core::defn :ck::show [label <- :wat::core::String t <- :ck::Tally] -> :wat::core::nil
  (:wat::kernel::println
    (:wat::string::concat label
      "  CArg " (:wat::i64::to-string (:ck::Tally/cargs t))
      "  CParam " (:wat::i64::to-string (:ck::Tally/cparams t))
      "  pairs " (:wat::i64::to-string (:wat::i64::+ (:ck::Tally/agree t) (:ck::Tally/conflict t)))
      "  agree " (:wat::i64::to-string (:ck::Tally/agree t))
      "  CONFLICT " (:wat::i64::to-string (:ck::Tally/conflict t))
      "  unplaced " (:wat::i64::to-string (:ck::Tally/unplaced t))
      "  unjoined " (:wat::i64::to-string (:ck::Tally/unjoined t))
      "  mismatch " (:wat::i64::to-string (:ck::Tally/mismatch t)))))

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
                   (:wat::string::concat "  " rule "  " (:wat::grep::Match/file m) ":"
                     (:wat::i64::to-string (:wat::grep::Match/line m)) ":"
                     (:wat::i64::to-string (:wat::grep::Match/col m))
                     (:ck::cap (:wat::grep::Match/captures m)))))
               (:ck::bump t rule))))
         (:ck::Tally :progs 1 :cargs (:ck::Prog/cargs p) :cparams (:ck::Prog/cparams p)
                     :agree 0 :conflict 0 :unplaced 0 :unjoined 0 :mismatch 0 :lists 0)
         (:wat::rete::query fired (:ck::q-match)))]
    (:wat::core::do (:ck::show (:wat::string::concat "rules: " name) t) t)))

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
      nil)))
