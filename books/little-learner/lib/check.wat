;; books/little-learner/lib/check.wat: compare a chapter's computed values with malt's.
;; The oracle (oracle/learner/NAME.rkt, run by tools/learner-oracle.sh) writes one value per
;; line: a number in Racket's shortest round-trip digits, (tensor ...) or (list ...). Each
;; line is read with wat's reader and compared with the computed value structurally, every
;; number by exact f64 equality: no tolerance, and not by printed text, since wat prints
;; floats differently (F-034).
;; Needs lib/malt.wat.

(:wat::core::typealias :ll::Lines (:wat::core::Vector :- [:wat::core::String]))

;; A value as text, for failure messages only (numbers in wat's printing, F-034).
(:wat::core::defn :ll::show [v <- :ll::V] -> :wat::core::String
  (:wat::core::match v
    [:ll::V.Num {:x x} (:wat::f64::to-string x)]
    [:ll::V.Dual {:r r :k k} (:wat::f64::to-string r)]
    [:ll::V.Ten {:es es} (:wat::string::concat "(tensor" (:ll::show-all es) ")")]
    [:ll::V.Lst {:es es} (:wat::string::concat "(list" (:ll::show-all es) ")")]))

(:wat::core::defn :ll::show-all [es <- :ll::Vs] -> :wat::core::String
  (:wat::core::foldl (:wat::core::fn [acc <- :wat::core::String e <- :ll::V] -> :wat::core::String
                       (:wat::string::concat acc " " (:ll::show e)))
                     "" es))

;; Does value v match the oracle's form e?
(:wat::core::defn :ll::matches? [v <- :ll::V e <- :wat::WatAST] -> :wat::core::bool
  (:wat::core::if (:wat::core::= (:wat::core::ast-kind e) "list")
    (:wat::core::let [ks (:wat::core::ast->children e)
                      h (:wat::core::ast->source (:wat::core::first ks))]
      (:wat::core::match v
        [:ll::V.Num {:x x} false]
        [:ll::V.Dual {:r r :k k} false]
        [:ll::V.Ten {:es es} (:wat::core::if (:wat::core::= h "tensor") (:ll::all-match? es (:wat::core::rest ks)) false)]
        [:ll::V.Lst {:es es} (:wat::core::if (:wat::core::= h "list") (:ll::all-match? es (:wat::core::rest ks)) false)]))
    (:wat::core::if (:ll::scalar? v)
      (:wat::core::match (:wat::string::to-f64 (:wat::core::ast->source e))
        [:wat::core::Option.Some {:value x} (:wat::core::= (:ll::rho v) x)]
        [:wat::core::Option.None {} false])
      false)))

(:wat::core::defn :ll::all-match? [vs <- :ll::Vs es <- (:wat::core::Vector :- [:wat::WatAST])] -> :wat::core::bool
  (:wat::core::cond
    ((:wat::core::empty? vs) (:wat::core::empty? es))
    ((:wat::core::empty? es) false)
    ((:ll::matches? (:wat::core::first vs) (:wat::core::first es)) (:ll::all-match? (:wat::core::rest vs) (:wat::core::rest es)))
    (:else false)))

(:wat::core::defn :ll::read-one [line <- :wat::core::String] -> :wat::WatAST
  (:wat::core::match (:wat::core::read-string line)
    [:wat::core::ReadOutcome.Forms {:forms fs} (:wat::core::first (:wat::core::ast->children fs))]
    [:wat::core::ReadOutcome.Malformed {:cause c} (:ll::fail (:wat::string::concat "cannot read the oracle's line " line))]))

(:wat::core::defn :ll::non-empty [xs <- :ll::Lines] -> :ll::Lines
  (:wat::core::filterv (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::core::not (:wat::core::= s ""))) xs))

(:wat::core::defn :ll::compare [got <- :ll::Vs want <- :ll::Lines i <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::empty? got)
    nil
    (:wat::core::if (:ll::matches? (:wat::core::first got) (:ll::read-one (:wat::core::first want)))
      (:ll::compare (:wat::core::rest got) (:wat::core::rest want) (:wat::core::+ i 1))
      (:ll::fail (:wat::string::concat "value " (:wat::i64::to-string i) ": wat computed " (:ll::show (:wat::core::first got))
                                      ", malt gave " (:wat::core::first want))))))

;; Every computed value, in order, must be malt's.
(:wat::core::defn :ll::check-chapter [expected <- :wat::core::String label <- :wat::core::String got <- :ll::Vs] -> :wat::core::nil
  (:wat::core::let [want (:ll::non-empty (:wat::string::split (:wat::io::read-file expected) "\n"))]
    (:wat::core::do
      (:wat::test::assert-eq (:wat::core::length got) (:wat::core::length want))
      (:ll::compare got want 0)
      (:wat::kernel::println (:wat::string::concat label ": ok (" (:wat::i64::to-string (:wat::core::length got)) " values match malt)")))))
