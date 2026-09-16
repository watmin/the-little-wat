;; probes/deporder/order-laws.wat: does the load-order analyzer actually catch anything?
;;
;; :wat::deporder:: is "the stdlib load-order analyzer" -- given an ordered list of
;; SourceFile{path,source}, it builds a symbol -> (file,kind) map and returns the Violations where
;; a file eval-depends on a later-loaded file. Its header states the classification rule:
;;
;;   defmacro                                        = ORDER-FREE
;;   defn/defenum/defalias/def/defprotocol/defclause/
;;   typealias/defstruct/newtype/extend-type/derive   = EVAL-DEPENDENT
;;
;; A checker that reports zero on the real corpus has proved nothing until you know it CAN report
;; something -- wat-rs's own rune for this is R59, NISI FRANGAS, NIHIL PROBAS. So the measurement
;; here is four-part:
;;
;;   D1  the real baked stdlib order            -> expect 0
;;   D2  the SAME files, order REVERSED          -> expect many. If this is 0, D1 was vacuous.
;;   D3  a two-file case, referencer first       -> expect exactly 1, with both positions
;;   D4  the same two files, definer first       -> expect 0
;;   D5  the defmacro exemption: a referencer ahead of the defmacro that defines its head -> 0
;;
;; Run: wat probes/deporder/order-laws.wat

(:wat::core::typealias :dp::Files (:wat::core::Vector :- [:wat::source::File]))
(:wat::core::typealias :dp::Viols (:wat::core::Vector :- [:wat::deporder::Violation]))

(:wat::core::defn :dp::file [path <- :wat::core::String src <- :wat::core::String] -> :wat::source::File
  (:wat::source::File :path path :source src))

(:wat::core::defn :dp::n [vs <- :dp::Viols] -> :wat::core::i64 (:wat::core::length vs))

(:wat::core::defn :dp::say [label <- :wat::core::String got <- :wat::core::i64 want <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    label "  violations=" (:wat::i64::to-string got) "   (expect " want ")"))))

;; --- the two-file pair: b defines :u::callee, a calls it -------------------------------------
(:wat::core::defn :dp::a [] -> :wat::source::File
  (:dp::file "a.wat" "(:wat::core::defn :u::caller [] -> :wat::core::i64 (:u::callee))"))
(:wat::core::defn :dp::b [] -> :wat::source::File
  (:dp::file "b.wat" "(:wat::core::defn :u::callee [] -> :wat::core::i64 1)"))

;; --- the macro pair: m is a defmacro, so a reference ahead of it is ORDER-FREE ---------------
(:wat::core::defn :dp::ma [] -> :wat::source::File
  (:dp::file "ma.wat" "(:wat::core::defn :u::usesm [] -> :wat::core::i64 (:u::m))"))
(:wat::core::defn :dp::mb [] -> :wat::source::File
  (:dp::file "mb.wat" "(:wat::core::defmacro :u::m [] (:wat::core::quote 1))"))

(:wat::core::defn :dp::show-one [v <- :wat::deporder::Violation] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    "      " (:wat::deporder::Violation/referencer v)
    " (pos " (:wat::i64::to-string (:wat::deporder::Violation/referencer-pos v)) ")"
    " -> " (:wat::deporder::Violation/definer v)
    " (pos " (:wat::i64::to-string (:wat::deporder::Violation/definer-pos v)) ")"
    "  symbol " (:wat::deporder::Violation/symbol v)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let
    [src  (:wat::deporder::stdlib-sources)
     good (:wat::core::Vector :- [:wat::source::File] (:dp::b) (:dp::a))
     bad  (:wat::core::Vector :- [:wat::source::File] (:dp::a) (:dp::b))
     macs (:wat::core::Vector :- [:wat::source::File] (:dp::ma) (:dp::mb))
     v3   (:wat::deporder::verify bad)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
        "stdlib files: " (:wat::i64::to-string (:wat::core::length src)))))
      (:dp::say "D1 real baked order          " (:dp::n (:wat::deporder::verify-stdlib)) "0")
      (:dp::say "D2 the SAME files, reversed  " (:dp::n (:wat::deporder::verify (:wat::core::reverse src))) "many")
      (:dp::say "D3 referencer before definer " (:dp::n v3) "1")
      (:wat::core::mapv :dp::show-one v3)
      (:dp::say "D4 definer before referencer " (:dp::n (:wat::deporder::verify good)) "0")
      (:dp::say "D5 defmacro is order-free    " (:dp::n (:wat::deporder::verify macs)) "0"))))
