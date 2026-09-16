;; probes/fmt/corpus.wat: is wat's formatter idempotent, and does it preserve meaning?
;;
;; :wat::fmt:: is at zero probes and it carries the two cleanest properties in the language:
;;
;;   idempotence   format(format(x)) == format(x)
;;   preservation  read-string(format(x)) parses to the same forms as read-string(x)
;;
;; Neither is a judgement call: a formatter that fails either is wrong, whatever its style.
;;
;; The corpus is wat-rs's OWN stdlib — the code the formatter exists to format. The 54 rules come
;; from wat-scripts/fmt/rules/, loaded here because they are deliberately not baked into the
;; binary ("Rules live in wat-scripts/fmt/rules/ and are NOT baked; a new rule is a new file").
;;
;; Each file is formatted inside its own :wat::test::run-thread, so one file that raises cannot
;; hide the rest — the mask that F-070 found in wat's own doctest runner.
;;
;; Run from the repository root: wat probes/fmt/corpus.wat
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

(:wat::core::typealias :fc::Paths (:wat::core::Vector :- [:wat::core::String]))

(:wat::core::defn :fc::paths [] -> :fc::Paths
  (:wat::core::Vector :- [:wat::core::String]
    "../wat-rs/wat/bracket.wat"
    "../wat-rs/wat/cache.wat"
    "../wat-rs/wat/capability.wat"
    "../wat-rs/wat/core.wat"
    "../wat-rs/wat/deporder.wat"
    "../wat-rs/wat/doctest.wat"
    "../wat-rs/wat/doc.wat"
    "../wat-rs/wat/edn.wat"
    "../wat-rs/wat/eval.wat"
    "../wat-rs/wat/fix.wat"
    "../wat-rs/wat/fmt.wat"
    "../wat-rs/wat/grep.wat"
    "../wat-rs/wat/holon/Amplify.wat"
    "../wat-rs/wat/holon/Bigram.wat"
    "../wat-rs/wat/holon/Circular.wat"
    "../wat-rs/wat/holon/Log.wat"
    "../wat-rs/wat/holon/Ngram.wat"
    "../wat-rs/wat/holon/Project.wat"
    "../wat-rs/wat/holon/ReciprocalLog.wat"
    "../wat-rs/wat/holon/Reject.wat"
    "../wat-rs/wat/holon/Sequential.wat"
    "../wat-rs/wat/holon/Subtract.wat"
    "../wat-rs/wat/holon/Trigram.wat"
    "../wat-rs/wat/holon.wat"
    "../wat-rs/wat/io.wat"
    "../wat-rs/wat/kernel/assertion.wat"
    "../wat-rs/wat/kernel/channel.wat"
    "../wat-rs/wat/kernel/diagnostics.wat"
    "../wat-rs/wat/kernel/outcomes.wat"
    "../wat-rs/wat/kernel/readln.wat"
    "../wat-rs/wat/kernel/services/stdio.wat"
    "../wat-rs/wat/lint.wat"
    "../wat-rs/wat/process.wat"
    "../wat-rs/wat/program.wat"
    "../wat-rs/wat/query/mem.wat"
    "../wat-rs/wat/query/sqlite-store.wat"
    "../wat-rs/wat/query.wat"
    "../wat-rs/wat/Record.wat"
    "../wat-rs/wat/repl.wat"
    "../wat-rs/wat/rete/acc.wat"
    "../wat-rs/wat/rete/compile.wat"
    "../wat-rs/wat/rete/oracle/accum-pass.wat"
    "../wat-rs/wat/rete/oracle/explain.wat"
    "../wat-rs/wat/rete/oracle/fire.wat"
    "../wat-rs/wat/rete/oracle/insert.wat"
    "../wat-rs/wat/rete/oracle/pass.wat"
    "../wat-rs/wat/rete/oracle/stratify.wat"
    "../wat-rs/wat/rete/syntax.wat"
    "../wat-rs/wat/rete.wat"
    "../wat-rs/wat/runtime-meta.wat"
    "../wat-rs/wat/runtime-typeinfo.wat"
    "../wat-rs/wat/seq.wat"
    "../wat-rs/wat/service.wat"
    "../wat-rs/wat/source.wat"
    "../wat-rs/wat/spawn.wat"
    "../wat-rs/wat/sqlite.wat"
    "../wat-rs/wat/stream.wat"
    "../wat-rs/wat/string.wat"
    "../wat-rs/wat/telemetry/journal.wat"
    "../wat-rs/wat/telemetry/span.wat"
    "../wat-rs/wat/telemetry.wat"
    "../wat-rs/wat/test.wat"
))

;; the forms of a source, normalised — read-string answers a ReadOutcome, so a malformed read
;; is reported rather than silently compared
(:wat::core::defn :fc::forms [src <- :wat::core::String] -> :wat::core::String
  (:wat::core::match (:wat::core::read-string src)
    [:wat::core::ReadOutcome.Forms {:forms f} (:wat::core::write-forms f)]
    [:wat::core::ReadOutcome.Malformed {:cause _c} "MALFORMED"]))

;; the verdict for one file, unguarded — anything here may raise
(:wat::core::defn :fc::verdict [path <- :wat::core::String rules <- (:wat::core::PersistentVector :- [:wat::rete::Rule])] -> :wat::core::String
  (:wat::core::let [src (:wat::io::read-file path)
                    one (:wat::fmt::format-source path src rules)
                    two (:wat::fmt::format-source path one rules)
                    idem (:wat::core::= one two)
                    a (:fc::forms src)
                    b (:fc::forms one)
                    same (:wat::core::= a b)]
    (:wat::core::if idem
      (:wat::core::if same "ok" "MEANING-CHANGED")
      (:wat::core::if same "NOT-IDEMPOTENT" "NOT-IDEMPOTENT+MEANING-CHANGED"))))

(:wat::core::defn :fc::known? [m <- :wat::core::String] -> :wat::core::bool
  (:wat::core::or (:wat::string::starts-with? m "ok")
    (:wat::core::or (:wat::string::starts-with? m "NOT-IDEMPOTENT")
                    (:wat::string::starts-with? m "MEANING-CHANGED"))))

;; guarded: the verdict arrives as the raise message, so a raise is a value like any other
(:wat::core::defn :fc::classify [path <- :wat::core::String rules <- (:wat::core::PersistentVector :- [:wat::rete::Rule])] -> :wat::core::String
  (:wat::core::match (:wat::test::run-thread
                       (:wat::kernel::assertion-failed! :message (:fc::verdict path rules)))
    [:wat::kernel::RunResult.Passed {} "impossible"]
    [:wat::kernel::RunResult.Failed {:failure f}
      (:wat::core::let [m (:wat::kernel::Failure/message f)]
        (:wat::core::if (:fc::known? m) m (:wat::string::concat "RAISED: " m)))]))

(:wat::core::defn :fc::walk [paths <- :fc::Paths i <- :wat::core::i64 n <- :wat::core::i64
                             rules <- (:wat::core::PersistentVector :- [:wat::rete::Rule])
                             acc <- :fc::Paths] -> :fc::Paths
  (:wat::core::if (:wat::core::>= i n)
    acc
    (:wat::core::let [p (:wat::core::nth paths i)
                      v (:fc::classify p rules)]
      (:fc::walk paths (:wat::core::+ i 1) n rules
        (:wat::core::conj acc (:wat::string::concat v "  " p))))))

(:wat::core::defn :fc::count-prefixed [xs <- :fc::Paths p <- :wat::core::String] -> :wat::core::i64
  (:wat::core::length (:wat::core::filterv
    (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool (:wat::string::starts-with? s p)) xs)))

(:wat::core::defn :fc::print [xs <- :fc::Paths i <- :wat::core::i64 n <- :wat::core::i64] -> :wat::core::nil
  (:wat::core::if (:wat::core::>= i n) nil
    (:wat::core::do (:wat::kernel::println (:wat::core::nth xs i))
                    (:fc::print xs (:wat::core::+ i 1) n))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::let [rules (:wat::rete::collect-rules :fmt)
                    ps (:fc::paths)
                    res (:fc::walk ps 0 (:wat::core::length ps) rules (:wat::core::Vector :- [:wat::core::String]))
                    bad (:wat::core::filterv
                          (:wat::core::fn [s <- :wat::core::String] -> :wat::core::bool
                            (:wat::core::not (:wat::string::starts-with? s "ok"))) res)]
    (:wat::core::do
      (:wat::kernel::println (:wat::string::concat "rules: " (:wat::i64::to-string (:wat::core::length rules))))
      (:wat::kernel::println (:wat::string::concat "files: " (:wat::i64::to-string (:wat::core::length ps))))
      (:wat::kernel::println (:wat::string::concat "  ok:              " (:wat::i64::to-string (:fc::count-prefixed res "ok"))))
      (:wat::kernel::println (:wat::string::concat "  NOT-IDEMPOTENT:  " (:wat::i64::to-string (:fc::count-prefixed res "NOT-IDEMPOTENT"))))
      (:wat::kernel::println (:wat::string::concat "  MEANING-CHANGED: " (:wat::i64::to-string (:fc::count-prefixed res "MEANING-CHANGED"))))
      (:wat::kernel::println (:wat::string::concat "  RAISED:          " (:wat::i64::to-string (:fc::count-prefixed res "RAISED"))))
      (:wat::kernel::println "---- every file that is not ok ----")
      (:fc::print bad 0 (:wat::core::length bad)))))
