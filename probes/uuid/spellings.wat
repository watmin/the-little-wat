;; probes/uuid/spellings.wat: which of the four uuid spellings the user guide names still exist?
;;
;; USER-GUIDE.md:2642-2650 carries a "Backward-compat note" that contradicts itself in five lines:
;;
;;   "The retired namespace verbs `:wat::core::uuid::v4` and `:wat::core::uuid::v5` no longer
;;    exist in the substrate; new code MUST use `Uuid/v4` and `Uuid/v5`.
;;    `:wat::telemetry::uuid::v4` still works -- it delegates to `:wat::uuid::v4` ...
;;    new code should reach for `:wat::uuid::v4` directly"
;;
;; So the same paragraph mandates `Uuid/v4` and recommends `:wat::uuid::v4`. One of them is
;; wrong, and a backward-compat note is the one piece of prose whose entire job is to be right
;; about spelling.
;;
;; All four are named below. wat reports every type error at startup in one pass, so the refusals
;; come back together -- uncomment them as a set to see the list.
;;
;; MEASURED 2026-09-16 (wat-rs a3218644d):
;;   :wat::uuid::v4            OK        <- what the examples in that same section actually use
;;   :wat::core::Uuid/v4       REFUSED   "':wat::core::Uuid/v4' is retired; use ':wat::uuid::v4'"
;;   :wat::core::uuid::v4      REFUSED   (as the note says)
;;   :wat::telemetry::uuid::v4 DOES NOT EXIST -- "not a builtin, not a registered function",
;;                             though the guide says it "still works" and that existing callers
;;                             "see no behavior change"
;;
;; The refusal is a good one -- it names the replacement and carries a :remedies entry. The gap is
;; that the guide sends you to the spelling the checker rejects.
;;
;; Run: wat probes/uuid/spellings.wat

(:wat::core::defn :us::show [label <- :wat::core::String u <- :wat::core::Uuid] -> :wat::core::nil
  (:wat::kernel::println (:wat::string::join "" (:wat::core::Vector :- [:wat::core::String]
    label "  " (:wat::uuid::to-string u)))))

(:wat::core::defn :user::main [] -> :wat::core::nil
  (:wat::core::do
    (:us::show ":wat::uuid::v4           " (:wat::uuid::v4))
    ;; (:us::show ":wat::telemetry::uuid::v4" (:wat::telemetry::uuid::v4))  ;; unresolved
    ;; the two the guide's note discusses -- both refused at startup:
    ;; (:us::show ":wat::core::Uuid/v4      " (:wat::core::Uuid/v4))
    ;; (:us::show ":wat::core::uuid::v4     " (:wat::core::uuid::v4))
    ))
