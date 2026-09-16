;; probes/telemetry/scope-splice.wat: does a record that SPLICES a surface satisfy that surface?
;;
;; wat/telemetry.wat calls itself "the first real consumer of surface-splice": `Metric` and `Log`
;; are defrecords whose field list opens with `~@:wat::telemetry::Scope`, inlining the surface's
;; four features (namespace, uuid, tags, time-ns) ahead of each record's own fields, so the
;; spliced accessors -- `Metric/namespace` and friends -- are minted for free.
;;
;; Two questions, and the second is the interesting one:
;;
;;   S1. Do the spliced accessors exist and read the right values, and is the constructor's
;;       field order splice-first as the header documents?
;;   S2. Can a function take the SURFACE and be handed a record that spliced it?
;;
;; S2 matters because F-029 is that a function generic over a surface refuses the structs that
;; implement it -- hit in two books. A splice is a different relationship from an `extend-type`:
;; the fields are physically inlined rather than declared satisfied. So it is worth knowing which
;; way this one goes, and the answer tells a user whether `Scope` is a type they can program
;; against or only a macro that saves typing.
;;
;; Note the stdlib itself never answers it: `:wat::telemetry::Metric/namespace` and friends are
;; used, and `:wat::telemetry::Scope/<anything>` has ZERO uses anywhere in wat's source.
;;
;; Run: wat probes/telemetry/scope-splice.wat

(:wat::core::defn :sp::mk [] -> :wat::telemetry::Metric
  (:wat::telemetry::Metric
    :namespace     "probe"
    :uuid          (:wat::uuid::v4)
    :tags          (:wat::core::HashMap :- [:wat::core::keyword :wat::core::String] :host "abc")
    :time-ns       1757000000000000000
    :start-time-ns 1756999999000000000
    :name          :requests
    :value         (:wat::telemetry::Numeric.I64 {:val 42})
    :unit          (:wat::telemetry::Unit.Count {})))

(:wat::core::defn :sp::say [k <- :wat::core::String v <- :wat::core::String] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String] k "  " v))))

;; S1 -- the four spliced accessors, then two of the record's own.
(:wat::core::defn :sp::s1 [] -> :wat::core::nil
  (:wat::core::let [m (:sp::mk)]
    (:wat::core::do
      (:sp::say "S1 spliced Metric/namespace    " (:wat::telemetry::Metric/namespace m))
      (:sp::say "S1 spliced Metric/time-ns      " (:wat::i64::to-string (:wat::telemetry::Metric/time-ns m)))
      (:sp::say "S1 spliced Metric/uuid present " (:wat::edn::write (:wat::telemetry::Metric/uuid m)))
      (:sp::say "S1 own     Metric/start-time-ns" (:wat::i64::to-string (:wat::telemetry::Metric/start-time-ns m)))
      (:sp::say "S1 own     Metric/unit         " (:wat::edn::write (:wat::telemetry::Metric/unit m))))))

;; S2 -- a function typed by the SURFACE, handed the record that spliced it.
(:wat::core::defn :sp::ns-of [s <- :wat::telemetry::Scope] -> :wat::core::String
  (:wat::telemetry::Scope/namespace s))

(:wat::core::defn :sp::s2 [] -> :wat::core::nil
  (:sp::say "S2 surface-typed fn on a Metric" (:sp::ns-of (:sp::mk))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do (:sp::s1) (:sp::s2)))
