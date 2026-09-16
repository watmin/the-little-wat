;; probes/fmt/throughput.wat: what does formatting cost, per byte and per file?
;;
;; probes/fmt/corpus.wat established that :wat::fmt:: is IDEMPOTENT across all 62 files of wat's
;; own stdlib. This measures what that costs. A formatter is an interactive tool — format-on-save
;; wants to be imperceptible — so the figure matters as much as the correctness.
;;
;; Five files spanning two orders of magnitude of size, each formatted once and timed with wat's
;; own clock. `forms-equal` reports whether the parse changed: the formatter also performs the
;; param-spec migration (a bare unit variant `:Exhausted` gains its `[]`), which is deliberate —
;; enums will require a param-spec — so "no" here means the file still carries the old spelling,
;; not that anything is wrong.
;;
;; Run from the repository root: wat probes/fmt/throughput.wat
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/atoms.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/cond.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defn-args.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defn.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defrecord-fields.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/defrecord.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/if.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/kwargs.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let-bindings.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let-blank.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/let.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/match.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/siblings.wat")
(:wat::load-file! "../../../wat-rs/wat-scripts/fmt/rules/table.wat")

(:wat::core::defn :t::forms [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::core::read-string src)
    [:wat::core::ReadOutcome.Forms {:forms f} (:wat::core::write-forms f)]
    [:wat::core::ReadOutcome.Malformed {:cause _c} "MALFORMED"]))

(:wat::core::defn :t::ms [] -> :wat::core::i64 (:wat::time::epoch-millis (:wat::time::now)))

(:wat::core::defn :t::one [path <- :wat::core::String rules <- (:wat::core::PersistentVector :- [:wat::rete::Rule])] -> :wat::core::nil
  (:wat::core::let [src (:wat::io::read-file path)
                    t0 (:t::ms)
                    fmt (:wat::fmt::format-source path src rules)
                    t1 (:t::ms)
                    ms (:wat::core::- t1 t0)
                    n (:wat::string::length src)]
    (:wat::kernel::println
      (:wat::string::concat path
        "  bytes " (:wat::i64::to-string n)
        "  format-ms " (:wat::i64::to-string ms)
        "  bytes-per-ms " (:wat::i64::to-string (:wat::core::/ n (:wat::core::if (:wat::core::= ms 0) 1 ms)))
        "  forms-equal " (:wat::core::if (:wat::core::= (:t::forms src) (:t::forms fmt)) "yes" "no")))))

(:wat::core::defn :t::walk [ps <- (:wat::core::Vector :- [:wat::core::String]) i <- :wat::core::i64 n <- :wat::core::i64
                            rules <- (:wat::core::PersistentVector :- [:wat::rete::Rule])] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i n) nil
    (:wat::core::do (:t::one (:wat::core::nth ps i) rules) (:t::walk ps (:wat::core::+ i 1) n rules))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [rules (:wat::rete::collect-rules :fmt)
                    ps (:wat::core::Vector :- [:wat::core::String]
                         "../wat-rs/wat/stream.wat"
                         "../wat-rs/wat/io.wat"
                         "../wat-rs/wat/rete/compile.wat"
                         "../wat-rs/wat/core.wat"
                         "../wat-rs/wat/service.wat")]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "rules: " (:wat::i64::to-string (:wat::core::length rules))))
      (:t::walk ps 0 (:wat::core::length ps) rules))))
