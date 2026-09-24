;; types.wat -- F-194 as rules. Two derivations of an enum value's type, modelled exactly as
;; elf/compile.wat performs them, plus ONE constraint the compiler does not have: at a call, an
;; argument's type must equal the parameter's declared type.
;;   declared    (:c::enum-ty)             -- a type annotation naming enum E, spelled BY TIER
;;   constructor (:c::type-of-form's arm)  -- a constructor call of E, spelled by the heap flag
;;                                            alone: "henum:" whenever E has any payload
(:wat::core::defrecord :ty::Under     [anc <- :wat::core::i64 node <- :wat::core::i64])
(:wat::core::defrecord :ty::Enum      [id <- :wat::core::i64 name <- :wat::core::String])
(:wat::core::defrecord :ty::PV        [enum <- :wat::core::i64 vec <- :wat::core::i64])
(:wat::core::defrecord :ty::Other     [enum <- :wat::core::i64 vec <- :wat::core::i64])
(:wat::core::defrecord :ty::Multi     [vec <- :wat::core::i64])
(:wat::core::defrecord :ty::Heap      [name <- :wat::core::String])
(:wat::core::defrecord :ty::Tier1     [name <- :wat::core::String])
(:wat::core::defrecord :ty::Param     [fn <- :wat::core::String pos <- :wat::core::i64 ty <- :wat::core::String])
(:wat::core::defrecord :ty::ParamType [fn <- :wat::core::String pos <- :wat::core::i64 ty <- :wat::core::String])
(:wat::core::defrecord :ty::CtorType  [node <- :wat::core::i64 ty <- :wat::core::String])
(:wat::core::defrecord :ty::LetBind   [let <- :wat::core::i64 name <- :wat::core::String init <- :wat::core::i64])

;; ── containment, as can-raise.wat does it ────────────────────────────────────────────
(:wat::rete::defrule :ty::a-under
  :when [(:wat::grep::Node (?n <- :id) (?p <- :parent))]
  :then [(:ty::Under :anc ?p :node ?n)])
(:wat::rete::defrule :ty::b-under
  :when [(:ty::Under (?a <- :anc) (?mid <- :node))
         (:wat::grep::Node (?n <- :id) (?mid <- :parent))]
  :then [(:ty::Under :anc ?a :node ?n)])

;; ── what an enum IS, from its declaration ────────────────────────────────────────────
(:wat::rete::defrule :ty::c-enum
  :when [(:wat::grep::Node (?h <- :id) (?d <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?hn <- :name))
         (:wat::grep::Node (?nm <- :id) (?d <- :parent) (?ni <- :index))
         (:wat::grep::Named (?nm <- :id) (?n <- :name))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::i64::= ?ni 1))
         (:wat::rete::where (:wat::rete::string::= ?hn "wat.core/defenum"))]
  :then [(:ty::Enum :id ?d :name ?n)])
;; a PAYLOAD variant: a keyword at index >= 3 whose next sibling is a NON-EMPTY field vector
(:wat::rete::defrule :ty::d-pv
  :when [(:ty::Enum (?d <- :id))
         (:wat::grep::Node (?kw <- :id) (?d <- :parent) (?i <- :index) (?kk <- :kind))
         (:wat::grep::Node (?v <- :id) (?d <- :parent) (?j <- :index) (?vk <- :kind))
         (:wat::grep::Node (?x <- :id) (?v <- :parent) (?xi <- :index))
         (:wat::rete::where (:wat::rete::core::enum::= ?kk (:wat::grep::NodeKind.Keyword {})))
         (:wat::rete::where (:wat::rete::core::enum::= ?vk (:wat::grep::NodeKind.Vector {})))
         (:wat::rete::where (:wat::rete::i64::>= ?i 3))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?j 1 :undefined -1) ?i))
         (:wat::rete::where (:wat::rete::i64::= ?xi 0))]
  :then [(:ty::PV :enum ?d :vec ?v)])
(:wat::rete::defrule :ty::e-other
  :when [(:ty::PV (?d <- :enum) (?v1 <- :vec))
         (:ty::PV (?d <- :enum) (?v2 <- :vec))
         (:wat::rete::where (:wat::rete::i64::not= ?v1 ?v2))]
  :then [(:ty::Other :enum ?d :vec ?v1)])
;; more than one field: a field vector is name/<-/type triples, so a 2nd name sits at index 3
(:wat::rete::defrule :ty::f-multi
  :when [(:ty::PV (?v <- :vec))
         (:wat::grep::Node (?x <- :id) (?v <- :parent) (?xi <- :index))
         (:wat::rete::where (:wat::rete::i64::= ?xi 3))]
  :then [(:ty::Multi :vec ?v)])
(:wat::rete::defrule :ty::g-heap
  :when [(:ty::PV (?d <- :enum)) (:ty::Enum (?d <- :id) (?n <- :name))]
  :then [(:ty::Heap :name ?n)])
;; tier 1: exactly one payload variant, with exactly one field
(:wat::rete::defrule :ty::h-tier1
  :when [(:ty::PV (?d <- :enum) (?v <- :vec))
         (:ty::Enum (?d <- :id) (?n <- :name))
         (:wat::rete::not (:ty::Other (?d <- :enum) (?v <- :vec)))
         (:wat::rete::not (:ty::Multi (?v <- :vec)))]
  :then [(:ty::Tier1 :name ?n)])

;; ── a function's declared parameters: [name :- type ...], triples ────────────────────
(:wat::rete::defrule :ty::i-param
  :when [(:wat::grep::Node (?h <- :id) (?D <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?hn <- :name))
         (:wat::grep::Node (?fnn <- :id) (?D <- :parent) (?fi <- :index))
         (:wat::grep::Named (?fnn <- :id) (?F <- :name))
         (:wat::grep::Node (?pv <- :id) (?D <- :parent) (?pi <- :index) (?pk <- :kind))
         (:wat::grep::Node (?s <- :id) (?pv <- :parent) (?si <- :index))
         (:wat::grep::Node (?t <- :id) (?pv <- :parent) (?ti <- :index))
         (:wat::grep::Named (?t <- :id) (?tn <- :name))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::string::= ?hn "wat.core/defn"))
         (:wat::rete::where (:wat::rete::i64::= ?fi 1))
         (:wat::rete::where (:wat::rete::i64::= ?pi 2))
         (:wat::rete::where (:wat::rete::core::enum::= ?pk (:wat::grep::NodeKind.Vector {})))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::mod ?si 3 :undefined -1) 0))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?ti 2 :undefined -1) ?si))]
  :then [(:ty::Param :fn ?F :pos (:wat::rete::i64::quot ?si 3 :undefined -1) :ty ?tn)])

;; ── DERIVATION 1, declared (:c::enum-ty): spelled by tier ────────────────────────────
(:wat::rete::defrule :ty::j-ptype
  :when [(:ty::Param (?F <- :fn) (?pos <- :pos) (?tn <- :ty)) (:ty::Tier1 (?tn <- :name))]
  :then [(:ty::ParamType :fn ?F :pos ?pos :ty (:wat::rete::string::concat "penum:" ?tn))])

;; ── DERIVATION 2, constructor (:c::type-of-form): the heap flag alone, tier ignored ──
;; a constructor is a LIST whose head keyword is E.Variant -- a match arm is a VECTOR and is not
(:wat::rete::defrule :ty::k-ctor-tier1
  :when [(:wat::grep::Node (?h <- :id) (?c <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?hn <- :name))
         (:wat::grep::Node (?c <- :id) (?ck <- :kind))
         (:ty::Tier1 (?E <- :name))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::core::enum::= ?ck (:wat::grep::NodeKind.List {})))
         (:wat::rete::where (:wat::rete::string::starts-with? ?hn (:wat::rete::string::concat ?E ".")))]
  :then [(:ty::CtorType :node ?c :ty (:wat::rete::string::concat "penum:" ?E))])
(:wat::rete::defrule :ty::k-ctor-heap
  :when [(:wat::grep::Node (?h <- :id) (?c <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?hn <- :name))
         (:wat::grep::Node (?c <- :id) (?ck <- :kind))
         (:ty::Heap (?E <- :name))
         (:wat::rete::not (:ty::Tier1 (?E <- :name)))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::core::enum::= ?ck (:wat::grep::NodeKind.List {})))
         (:wat::rete::where (:wat::rete::string::starts-with? ?hn (:wat::rete::string::concat ?E ".")))]
  :then [(:ty::CtorType :node ?c :ty (:wat::rete::string::concat "henum:" ?E))])

;; ── let bindings: [name init name init ...] ──────────────────────────────────────────
(:wat::rete::defrule :ty::l-let
  :when [(:wat::grep::Node (?h <- :id) (?L <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?hn <- :name))
         (:wat::grep::Node (?B <- :id) (?L <- :parent) (?bi <- :index) (?bk <- :kind))
         (:wat::grep::Node (?nm <- :id) (?B <- :parent) (?ni <- :index))
         (:wat::grep::Named (?nm <- :id) (?name <- :name))
         (:wat::grep::Node (?init <- :id) (?B <- :parent) (?ii <- :index))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::string::= ?hn "wat.core/let"))
         (:wat::rete::where (:wat::rete::i64::= ?bi 1))
         (:wat::rete::where (:wat::rete::core::enum::= ?bk (:wat::grep::NodeKind.Vector {})))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::mod ?ni 2 :undefined -1) 0))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?ii 1 :undefined -1) ?ni))]
  :then [(:ty::LetBind :let ?L :name ?name :init ?init)])

;; ── ★ THE CONSTRAINT: an argument's type must equal its parameter's type ───────────
(:wat::rete::defrule :ty::z-conflict
  :when [(:wat::grep::Node (?h <- :id) (?K <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?F <- :name))
         (:ty::ParamType (?F <- :fn) (?pos <- :pos) (?pt <- :ty))
         (:wat::grep::Node (?a <- :id) (?K <- :parent) (?ai <- :index) (?ak <- :kind))
         (:wat::grep::Named (?a <- :id) (?aname <- :name))
         (:ty::LetBind (?L <- :let) (?aname <- :name) (?init <- :init))
         (:ty::Under (?L <- :anc) (?a <- :node))
         (:ty::CtorType (?init <- :node) (?at <- :ty))
         (:wat::grep::Span (?K <- :id) (?l <- :line) (?c <- :col) (?el <- :end-line) (?ec <- :end-col))
         (:wat::grep::Source (?f <- :file))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::core::enum::= ?ak (:wat::grep::NodeKind.Symbol {})))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?ai 1 :undefined -1) ?pos))
         (:wat::rete::where (:wat::rete::string::not= ?at ?pt))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?el :end-col ?ec
           :rule "boundary-type-conflict"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?F)
             (:wat::grep::Capture :name "arg" :value ?aname)
             (:wat::grep::Capture :name "arg-type" :value ?at)
             (:wat::grep::Capture :name "param-type" :value ?pt)))])

(:wat::rete::defrule :ty::z-agree
  :when [(:wat::grep::Node (?h <- :id) (?K <- :parent) (?hi <- :index))
         (:wat::grep::Named (?h <- :id) (?F <- :name))
         (:ty::ParamType (?F <- :fn) (?pos <- :pos) (?pt <- :ty))
         (:wat::grep::Node (?a <- :id) (?K <- :parent) (?ai <- :index) (?ak <- :kind))
         (:wat::grep::Named (?a <- :id) (?aname <- :name))
         (:ty::LetBind (?L <- :let) (?aname <- :name) (?init <- :init))
         (:ty::Under (?L <- :anc) (?a <- :node))
         (:ty::CtorType (?init <- :node) (?at <- :ty))
         (:wat::grep::Span (?K <- :id) (?l <- :line) (?c <- :col) (?el <- :end-line) (?ec <- :end-col))
         (:wat::grep::Source (?f <- :file))
         (:wat::rete::where (:wat::rete::i64::= ?hi 0))
         (:wat::rete::where (:wat::rete::core::enum::= ?ak (:wat::grep::NodeKind.Symbol {})))
         (:wat::rete::where (:wat::rete::i64::= (:wat::rete::i64::- ?ai 1 :undefined -1) ?pos))
         (:wat::rete::where (:wat::rete::string::= ?at ?pt))]
  :then [(:wat::grep::Match :file ?f :line ?l :col ?c :end-line ?el :end-col ?ec
           :rule "boundary-type-AGREES"
           :captures (:wat::rete::core::PersistentVector
             (:wat::grep::Capture :name "call" :value ?F)
             (:wat::grep::Capture :name "arg" :value ?aname)
             (:wat::grep::Capture :name "arg-type" :value ?at)
             (:wat::grep::Capture :name "param-type" :value ?pt)))])

(:wat::core::defn :user::grep [] -> (:wat::core::PersistentVector :- [:wat::rete::Rule])
  (:wat::rete::collect-rules :ty))
