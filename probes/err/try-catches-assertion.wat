;; probes/err/try-catches-assertion.wat: does Result/try survive an assertion-failed!?
;;
;; This is the question that decides whether wat has error RECOVERY or only an escape hatch.
;; :wat::kernel::assertion-failed! is how a wat program reports that something went wrong — it
;; is what every check in this repository raises, and what :wat::core::nth, :wat::string::subs
;; and friends raise on bad input.
;;
;; If Result/try answers an Err for it, a program can recover. If the death goes straight
;; through, then the only way to survive a fault is :wat::test::run-thread — a verb from the
;; TEST namespace — and that is a finding.
;;
;; Reading wat-rs first sharpens the expectation: Result/try is a SPECIAL FORM
;; (src/special_forms.rs:111, beside Option/try, Result/expect and Option/expect), and the
;; lowercase :wat::core::try is RETIRED in its favour (src/remedy/retirement.rs:120). A form that
;; unwraps an Err and propagates it outward is the `?` operator, not a catch — so the likely
;; answer is that this death goes straight through. The probe is here to confirm that rather
;; than to assume it.
;;
;; Its own file, because a death that is not caught ends the program: if nothing prints, the
;; answer is that Result/try did not catch it.
;;
;; Run from the repository root: wat probes/err/try-catches-assertion.wat

(:wat::core::defn :probe::dies [] -> :wat::core::i64
  (:wat::kernel::assertion-failed! :message "probe: expected failure"))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:wat::kernel::println "before")
    (:wat::core::match (:wat::core::Result/try (:probe::dies))
      [:wat::core::Result.Ok {:value v} (:wat::kernel::println (:wat::string::concat "Ok " (:wat::i64::to-string v)))]
      [:wat::core::Result.Err {:error e} (:wat::kernel::println "Err — Result/try caught the assertion")])
    (:wat::kernel::println "after")))
